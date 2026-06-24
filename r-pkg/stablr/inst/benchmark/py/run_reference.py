#!/usr/bin/env python3
"""
run_reference.py — B2: Python STABL reference runner for the parity benchmark.

Mirrors the published run_cv_*.py protocol verbatim for all 6 datasets and
writes normalised output CSVs to scratch/benchmark/reference/<dataset_id>/.

Output schema (per dataset):
  predictions.csv  — sample × model: predicted scores (probability or linear pred)
  selected.csv     — feature × model: binary (1/0) selection flags (STABL models)
  max_scores.csv   — feature × model: max selection probability over lambda grid
  folds.csv        — fold_id × sample_id: split indicator ('train'/'test')
  summary.csv      — model × metric: held-out performance (AUC or R²)

Usage (from repo root):
  .venv-parity/bin/python \\
    r-pkg/stablr/inst/benchmark/py/run_reference.py \\
    [--data-dir scratch/benchmark/data] \\
    [--out-dir  scratch/benchmark/reference] \\
    [--datasets COVID-19,CFRNA,SSI,DREAM,OOL-CyPr,OOL-CyPrMe] \\
    [--dry-run]  # parse args + load data only; skip fit

Notes:
  - np.random.seed(42) is set globally before any dataset loop.
  - The outer CV splits are generated with random_state=42 and saved to
    folds.csv so the R side can reproduce the exact same splits (Tier A parity).
  - DREAM uses random_permutation (not knockoff) due to high dimensionality.
  - OOL and DREAM outer CVs are GroupShuffleSplit; others RepeatedStratifiedKFold.
"""

import argparse
import json
import os
import sys
import warnings

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.linear_model import (
    ElasticNet, Lasso, LogisticRegression
)
from sklearn.model_selection import (
    GridSearchCV, GroupShuffleSplit,
    RepeatedKFold, RepeatedStratifiedKFold
)

# Repo-root on sys.path so `stabl` is importable
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", "..", "..", "..", ".."))
sys.path.insert(0, REPO_ROOT)

from stabl import data as stabl_data
from stabl.adaptive import ALogitLasso, ALasso
from stabl.multi_omic_pipelines import multi_omic_stabl_cv
from stabl.stabl import Stabl

warnings.filterwarnings("ignore", category=FutureWarning)
warnings.filterwarnings("ignore", category=UserWarning)


# ── Argument parsing ──────────────────────────────────────────────────────────

def parse_args():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--data-dir",   default="scratch/benchmark/data",
                   help="Staged data root (default: scratch/benchmark/data)")
    p.add_argument("--out-dir",    default="scratch/benchmark/reference",
                   help="Output root (default: scratch/benchmark/reference)")
    p.add_argument("--datasets",   default=None,
                   help="Comma-separated dataset IDs to run "
                        "(default: all 6). Available: "
                        "COVID-19,CFRNA,SSI,DREAM,OOL-CyPr,OOL-CyPrMe")
    p.add_argument("--dry-run",    action="store_true",
                   help="Load data but skip fitting; write folds.csv only")
    return p.parse_args()


# ── Shared CV parameters ──────────────────────────────────────────────────────

INNER_STRAT_CV = RepeatedStratifiedKFold(n_splits=5, n_repeats=5, random_state=42)
INNER_REGR_CV  = RepeatedKFold(n_splits=5, n_repeats=5, random_state=42)


def _binary_estimators(stabl_n=1000, lasso_C=(-2, 2, 30),
                       alasso_C=(-2, 2, 20), en_C=(-2, 1, 10),
                       stabl_lasso_C=(0.01, 1, 10),
                       stabl_alasso_C=(0.01, 10, 10),
                       stabl_en_grid=None,
                       artificial_type="knockoff"):
    """Return estimators dict for binary (logistic) datasets."""
    inner = INNER_STRAT_CV

    lasso = LogisticRegression(penalty="l1", class_weight="balanced",
                               max_iter=int(1e6), solver="liblinear", random_state=42)
    en    = LogisticRegression(penalty="elasticnet", solver="saga",
                               class_weight="balanced", max_iter=int(1e4), random_state=42)
    alasso = ALogitLasso(penalty="l1", solver="liblinear", max_iter=int(1e6),
                         class_weight="balanced", random_state=42)

    lasso_cv  = GridSearchCV(lasso,  {"C": np.logspace(*lasso_C)},
                             scoring="roc_auc", cv=inner, n_jobs=-1)
    alasso_cv = GridSearchCV(alasso, {"C": np.logspace(*alasso_C)},
                             scoring="roc_auc", cv=inner, n_jobs=-1)
    en_cv     = GridSearchCV(en,     {"C": np.logspace(*en_C),
                                      "l1_ratio": [0.5, 0.7, 0.9]},
                             scoring="roc_auc", cv=inner, n_jobs=-1)

    # STABL base — uses linspace for lasso/alasso C
    stabl = Stabl(
        base_estimator=lasso,
        n_bootstraps=stabl_n,
        artificial_type=artificial_type,
        artificial_proportion=1.0,
        replace=False,
        fdr_threshold_range=np.arange(0.1, 1, 0.01),
        sample_fraction=0.5,
        random_state=42,
        lambda_grid={"C": np.linspace(stabl_lasso_C[0], stabl_lasso_C[1],
                                       int(stabl_lasso_C[2]))},
        verbose=0,
    )
    stabl_alasso = clone(stabl).set_params(
        base_estimator=alasso,
        lambda_grid={"C": np.linspace(stabl_alasso_C[0], stabl_alasso_C[1],
                                       int(stabl_alasso_C[2]))},
    )
    if stabl_en_grid is None:
        stabl_en_grid = [{"C": np.logspace(-2, 1, 5), "l1_ratio": [0.9]}]
    stabl_en = clone(stabl).set_params(
        base_estimator=en,
        n_bootstraps=100,
        lambda_grid=stabl_en_grid,
    )

    return {
        "lasso":        lasso_cv,
        "alasso":       alasso_cv,
        "en":           en_cv,
        "stabl_lasso":  stabl,
        "stabl_alasso": stabl_alasso,
        "stabl_en":     stabl_en,
    }


def _regression_estimators(stabl_n=300, lasso_a=(-2, 2, 30),
                            alasso_a=(-2, 2, 30), en_a=(-2, 2, 10),
                            stabl_lasso_a=(0, 2, 10),
                            stabl_alasso_a=(0, 2, 10),
                            stabl_en_grid=None,
                            artificial_type="knockoff"):
    """Return estimators dict for regression datasets."""
    inner = INNER_REGR_CV

    lasso  = Lasso(max_iter=int(1e6), random_state=42)
    en     = ElasticNet(max_iter=int(1e6), random_state=42)
    alasso = ALasso(max_iter=int(1e6), random_state=42)

    lasso_cv  = GridSearchCV(lasso,  {"alpha": np.logspace(*lasso_a)},
                             scoring="r2", cv=inner, n_jobs=-1)
    alasso_cv = GridSearchCV(alasso, {"alpha": np.logspace(*alasso_a)},
                             scoring="r2", cv=inner, n_jobs=-1)
    en_cv     = GridSearchCV(en,     {"alpha": np.logspace(*en_a),
                                      "l1_ratio": [0.5, 0.7, 0.9]},
                             scoring="r2", cv=inner, n_jobs=-1)

    stabl = Stabl(
        base_estimator=lasso,
        n_bootstraps=stabl_n,
        artificial_type=artificial_type,
        artificial_proportion=1.0,
        replace=False,
        fdr_threshold_range=np.arange(0.1, 1, 0.01),
        sample_fraction=0.5,
        random_state=42,
        lambda_grid={"alpha": np.logspace(*stabl_lasso_a)},
        verbose=0,
    )
    stabl_alasso = clone(stabl).set_params(
        base_estimator=alasso,
        lambda_grid={"alpha": np.logspace(*stabl_alasso_a)},
    )
    if stabl_en_grid is None:
        stabl_en_grid = [{"alpha": np.logspace(0.5, 2, 5), "l1_ratio": [0.9]}]
    stabl_en = clone(stabl).set_params(
        base_estimator=en,
        lambda_grid=stabl_en_grid,
    )

    return {
        "lasso":        lasso_cv,
        "alasso":       alasso_cv,
        "en":           en_cv,
        "stabl_lasso":  stabl,
        "stabl_alasso": stabl_alasso,
        "stabl_en":     stabl_en,
    }


# ── Save folds helper ─────────────────────────────────────────────────────────

def save_folds(splitter, X, y, groups, out_dir):
    """Write folds.csv: fold_id → list of test sample indices (as JSON rows)."""
    rows = []
    for fold_id, (train_idx, test_idx) in enumerate(splitter.split(X, y, groups)):
        rows.append({
            "fold_id":        fold_id,
            "n_train":        len(train_idx),
            "n_test":         len(test_idx),
            "train_samples":  json.dumps(list(X.index[train_idx])),
            "test_samples":   json.dumps(list(X.index[test_idx])),
        })
    pd.DataFrame(rows).to_csv(os.path.join(out_dir, "folds.csv"), index=False)


# ── Dataset runners ───────────────────────────────────────────────────────────

def run_covid(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_covid_19(os.path.join(data_dir, "COVID-19"))
    y_train = y_train.astype(int)
    X_train = list(X_train_dict.values())[0]  # mono-omic

    outer_cv = RepeatedStratifiedKFold(n_splits=5, n_repeats=20, random_state=42)
    save_folds(outer_cv, X_train, y_train, None, out_dir)
    if dry_run: return

    estimators = _binary_estimators(artificial_type="knockoff")
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=None, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


def run_cfrna(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_cfrna(os.path.join(data_dir, "CFRNA"))
    y_train = y_train.astype(int)
    X_train = list(X_train_dict.values())[0]

    outer_cv = RepeatedStratifiedKFold(n_splits=5, n_repeats=20, random_state=42)
    save_folds(outer_cv, X_train, y_train, ids, out_dir)
    if dry_run: return

    estimators = _binary_estimators(artificial_type="knockoff")
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=ids, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


def run_ssi(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_ssi(os.path.join(data_dir, "Biobank SSI"))
    y_train = y_train.astype(int)
    X_ref = list(X_train_dict.values())[0]

    outer_cv = RepeatedStratifiedKFold(n_splits=5, n_repeats=20, random_state=42)
    save_folds(outer_cv, X_ref, y_train, None, out_dir)
    if dry_run: return

    estimators = _binary_estimators(
        artificial_type="knockoff",
        stabl_en_grid=[
            {"C": np.logspace(-2, 0, 5), "l1_ratio": [0.5]},
            {"C": np.logspace(-2, 0, 5), "l1_ratio": [0.7]},
            {"C": np.logspace(-2, 0, 5), "l1_ratio": [0.9]},
        ],
    )
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=None, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


def run_dream(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_dream(os.path.join(data_dir, "Dream"))
    y_train = y_train.astype(int)
    # Sanitise column names (replace "/" with "_")
    for name, df in list(X_train_dict.items()):
        df.columns = df.columns.str.replace("/", "_", regex=False)
        X_train_dict[name] = df
    X_ref = list(X_train_dict.values())[0]

    outer_cv = GroupShuffleSplit(n_splits=100, test_size=0.2, random_state=42)
    save_folds(outer_cv, X_ref, y_train, ids, out_dir)
    if dry_run: return

    estimators = _binary_estimators(
        artificial_type="random permutation",
        lasso_C=(-3, 0, 30),
        alasso_C=(-3, 0, 30),
    )
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=ids, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


def run_ool_cypr(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_onset_of_labor(os.path.join(data_dir, "Onset of Labor"))
    X_ref = list(X_train_dict.values())[0]

    outer_cv = GroupShuffleSplit(n_splits=100, test_size=0.2, random_state=42)
    save_folds(outer_cv, X_ref, y_train, ids, out_dir)
    if dry_run: return

    estimators = _regression_estimators(artificial_type="knockoff")
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=ids, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


def run_ool_cyprme(data_dir, out_dir, dry_run=False):
    X_train_dict, _, y_train, _, ids, task_type = \
        stabl_data.load_onset_of_labor_cv(os.path.join(data_dir, "Onset of Labor"))
    X_ref = list(X_train_dict.values())[0]

    outer_cv = GroupShuffleSplit(n_splits=100, test_size=0.2, random_state=42)
    save_folds(outer_cv, X_ref, y_train, ids, out_dir)
    if dry_run: return

    estimators = _regression_estimators(artificial_type="knockoff")
    models = ["STABL Lasso", "Lasso", "STABL ALasso", "ALasso",
              "STABL ElasticNet", "ElasticNet"]
    multi_omic_stabl_cv(
        data_dict=X_train_dict, y=y_train,
        outer_splitter=outer_cv, estimators=estimators,
        task_type=task_type, save_path=out_dir,
        outer_groups=ids, early_fusion=True, late_fusion=True,
        n_iter_lf=1000, models=models,
    )


# ── Main ──────────────────────────────────────────────────────────────────────

DATASET_RUNNERS = {
    "COVID-19":    run_covid,
    "CFRNA":       run_cfrna,
    "SSI":         run_ssi,
    "DREAM":       run_dream,
    "OOL-CyPr":   run_ool_cypr,
    "OOL-CyPrMe": run_ool_cyprme,
}


def main():
    args = parse_args()

    # Resolve paths relative to repo root
    data_dir = args.data_dir if os.path.isabs(args.data_dir) \
               else os.path.join(REPO_ROOT, args.data_dir)
    out_dir  = args.out_dir  if os.path.isabs(args.out_dir) \
               else os.path.join(REPO_ROOT, args.out_dir)

    datasets = list(DATASET_RUNNERS.keys()) if args.datasets is None \
               else [d.strip() for d in args.datasets.split(",")]

    unknown = [d for d in datasets if d not in DATASET_RUNNERS]
    if unknown:
        sys.exit(f"Unknown dataset IDs: {unknown}. "
                 f"Choose from: {list(DATASET_RUNNERS)}")

    np.random.seed(42)

    for ds_id in datasets:
        ds_out = os.path.join(out_dir, ds_id)
        os.makedirs(ds_out, exist_ok=True)
        print(f"\n{'='*60}")
        print(f"Dataset: {ds_id}  {'[DRY RUN]' if args.dry_run else ''}")
        print(f"  data:   {data_dir}")
        print(f"  output: {ds_out}")
        print(f"{'='*60}")

        try:
            DATASET_RUNNERS[ds_id](data_dir=data_dir, out_dir=ds_out,
                                   dry_run=args.dry_run)
            print(f"  ✓ {ds_id} complete")
        except Exception as exc:
            print(f"  ✗ {ds_id} FAILED: {exc}", file=sys.stderr)
            import traceback
            traceback.print_exc(file=sys.stderr)

    print("\nDone.")


if __name__ == "__main__":
    main()
