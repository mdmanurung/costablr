#!/usr/bin/env python3
"""Export Python tutorial max stability scores for OOL proteomics parity.

Replicates the Onset of Labor proteomics regression block from the official
STABL tutorial notebook (500 bootstraps, knockoffs, seed 42).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.base import clone
from sklearn.feature_selection import VarianceThreshold
from sklearn.impute import SimpleImputer
from sklearn.linear_model import Lasso
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from stabl.preprocessing import LowInfoFilter
from stabl.stabl import Stabl


def find_repo_root(start: Path) -> Path:
    path = start.resolve()
    while True:
        if (path / "r-pkg" / "stablr" / "DESCRIPTION").exists():
            return path
        parent = path.parent
        if parent == path:
            break
        path = parent
    raise FileNotFoundError("Could not locate repository root.")


def build_preprocessing() -> Pipeline:
    return Pipeline(
        steps=[
            ("variance_threshold", VarianceThreshold(threshold=0)),
            ("low_info_filter", LowInfoFilter(max_nan_fraction=0.2)),
            ("imputer", SimpleImputer(strategy="median")),
            ("std", StandardScaler()),
        ]
    )


def load_ool_training(repo: Path) -> tuple[pd.DataFrame, pd.Series]:
    data_dir = repo / "Sample Data" / "Onset of Labor" / "Training"
    if not data_dir.exists():
        raise FileNotFoundError(f"Missing tutorial data: {data_dir.parent}")

    prot_train = pd.read_csv(data_dir / "Proteomics.csv", index_col=0)
    y_train = pd.read_csv(data_dir / "DOS.csv", index_col=0)["DOS"]
    common = prot_train.index.intersection(y_train.index)
    return prot_train.loc[common], y_train.loc[common]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Output CSV path (default: inst/analysis/data/ool_python_tutorial_scores.csv)",
    )
    parser.add_argument("--n-jobs", type=int, default=1)
    args = parser.parse_args()

    repo = find_repo_root(Path(__file__).parent)
    if not (repo / "Sample Data" / "Onset of Labor").exists():
        raise FileNotFoundError(
            f"Missing tutorial data: {repo / 'Sample Data' / 'Onset of Labor'}"
        )

    out_path = args.out or (
        repo / "r-pkg" / "stablr" / "inst" / "analysis" / "data" / "ool_python_tutorial_scores.csv"
    )

    random_state = 42
    prot_raw, y_train_ool = load_ool_training(repo)

    preprocessing = build_preprocessing()
    prot_std = pd.DataFrame(
        data=preprocessing.fit_transform(prot_raw),
        index=prot_raw.index,
        columns=preprocessing.get_feature_names_out(),
    )

    lasso = Lasso(max_iter=int(1e6), random_state=random_state)
    stabl_regression = Stabl(
        base_estimator=clone(lasso),
        lambda_grid="auto",
        n_lambda=10,
        artificial_type="knockoff",
        artificial_proportion=1,
        n_bootstraps=500,
        random_state=random_state,
        n_jobs=args.n_jobs,
        verbose=1,
    )
    stabl_regression.fit(prot_std, y_train_ool)

    feature_names = prot_std.columns.to_numpy()
    max_scores = np.max(stabl_regression.stabl_scores_, axis=1)
    score_df = pd.DataFrame(
        {"feature": feature_names, "python_max_score": max_scores}
    ).sort_values("python_max_score", ascending=False)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    score_df.to_csv(out_path, index=False)

    selected = stabl_regression.get_feature_names_out(input_features=feature_names)
    print(f"Wrote {len(score_df)} feature scores to {out_path}")
    print(f"Selected features (n={len(selected)}): {list(selected)}")


if __name__ == "__main__":
    main()
