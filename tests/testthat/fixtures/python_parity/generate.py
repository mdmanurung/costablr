#!/usr/bin/env python3
"""Regenerate deterministic parity fixtures from the pinned Python source.

The script deliberately separates exact, solver-independent algorithm parity
(score accumulation, FDP+, support and stacking) from solver-level parity.
It imports the metric and stacking implementations directly from the pinned
checkout and extracts the FDP+ method from its abstract syntax tree, avoiding
an unnecessary dependency on knockoff generation during regeneration.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import ElasticNet, Lasso, LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.utils.validation import check_is_fitted


REFERENCE_COMMIT = "1d07f85a13cfbecb4f08ce21075bf4fbb8e34678"
REFERENCE_URL = "https://github.com/gregbellan/Stabl"
FIXTURE_VERSION = 1
HERE = Path(__file__).resolve().parent


def csv_write(frame: pd.DataFrame, name: str) -> None:
    frame.to_csv(
        HERE / name,
        index=False,
        lineterminator="\n",
        float_format="%.17g",
    )


def load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def checked_reference(path: Path) -> Path:
    commit = subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()
    if commit != REFERENCE_COMMIT:
        raise RuntimeError(
            f"Reference checkout is {commit}; expected {REFERENCE_COMMIT}."
        )
    return path


def extracted_stabl_class(stabl_path: Path):
    """Compile the exact pinned FDP+/support method bodies without imports."""
    tree = ast.parse(stabl_path.read_text(encoding="utf-8"), filename=str(stabl_path))
    source_class = next(
        node for node in tree.body if isinstance(node, ast.ClassDef) and node.name == "Stabl"
    )
    wanted = {"_compute_FDPplus", "_get_support_mask"}
    methods = [
        node
        for node in source_class.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name in wanted
    ]
    if {method.name for method in methods} != wanted:
        raise RuntimeError("Pinned source does not expose the expected FDP+/support methods.")
    parity_class = ast.ClassDef(
        name="PinnedStablMethods",
        bases=[],
        keywords=[],
        body=methods,
        decorator_list=[],
    )
    module = ast.fix_missing_locations(ast.Module(body=[parity_class], type_ignores=[]))
    namespace = {"np": np, "check_is_fitted": check_is_fitted}
    exec(compile(module, str(stabl_path), "exec"), namespace)
    parity_type = namespace["PinnedStablMethods"]
    # sklearn's check_is_fitted requires an estimator-shaped object.  The
    # extracted support method only needs the fitted attributes, but retaining
    # this small fit sentinel keeps its original guard active.
    parity_type.fit = lambda self, *args, **kwargs: self
    return parity_type


def make_inputs() -> None:
    sample_ids = [f"s{i:02d}" for i in range(1, 13)]
    t = np.arange(1, 13, dtype=float)
    matrix = pd.DataFrame(
        {
            "sample_id": sample_ids,
            "signal_a": (t - 6.5) / 3.5,
            "signal_b": np.sin(t / 2.0),
            "gene_c": np.cos(t / 3.0),
            "gene_d": ((t.astype(int) * 3) % 7 - 3) / 3.0,
            "gene_e": ((t.astype(int) * 5) % 11 - 5) / 5.0,
            "noise_f": np.sin(t * 1.7),
            "noise_g": np.cos(t * 1.3),
            "noise_h": ((t.astype(int) * 7) % 13 - 6) / 6.0,
        }
    )
    outcome = 2.0 * matrix["signal_a"] - 1.25 * matrix["signal_b"] + np.array(
        [0.10, -0.05, 0.00, 0.08, -0.03, 0.02, -0.07, 0.04, 0.00, 0.06, -0.02, 0.03]
    )
    csv_write(matrix, "input_matrix.csv")
    csv_write(pd.DataFrame({"sample_id": sample_ids, "outcome": outcome}), "outcomes.csv")

    bootstrap_rows = []
    schedules = [
        [1, 2, 3, 7, 8, 9],
        [2, 3, 4, 8, 9, 10],
        [3, 4, 5, 9, 10, 11],
        [4, 5, 6, 10, 11, 12],
        [1, 5, 6, 7, 11, 12],
        [1, 2, 6, 7, 8, 12],
        [2, 4, 6, 8, 10, 12],
        [1, 3, 5, 7, 9, 11],
    ]
    for bootstrap_id, samples in enumerate(schedules, 1):
        for position, sample in enumerate(samples, 1):
            bootstrap_rows.append((bootstrap_id, position, sample_ids[sample - 1]))
    csv_write(
        pd.DataFrame(bootstrap_rows, columns=["bootstrap_id", "position", "sample_id"]),
        "bootstrap_schedule.csv",
    )

    lambdas = pd.DataFrame(
        {
            "lambda_id": ["lambda_1", "lambda_2", "lambda_3"],
            "lambda": [0.04, 0.10, 0.25],
            "l1_ratio": [1.0, 1.0, 1.0],
        }
    )
    csv_write(lambdas, "lambda_grid.csv")

    sources = ["gene_c", "gene_e", "noise_f", "noise_h"]
    shifts = [2, 5, 7, 9]
    artificial = pd.DataFrame({"sample_id": sample_ids})
    provenance_rows = []
    for index, (source, shift) in enumerate(zip(sources, shifts), 1):
        art_name = f"artificial_{index}"
        source_values = matrix[source].to_numpy()
        source_rows = np.roll(np.arange(len(sample_ids)), shift)
        artificial[art_name] = source_values[source_rows]
        for target_row, source_row in enumerate(source_rows):
            provenance_rows.append(
                (art_name, source, sample_ids[target_row], sample_ids[source_row])
            )
    csv_write(artificial, "artificial_matrix.csv")
    csv_write(
        pd.DataFrame(
            provenance_rows,
            columns=["artificial_feature", "source_feature", "sample_id", "source_sample_id"],
        ),
        "artificial_provenance.csv",
    )


def make_selection_and_fdp(reference: Path) -> None:
    real_counts = {
        "signal_a": [8, 8, 7],
        "signal_b": [7, 6, 5],
        "gene_c": [4, 5, 3],
        "gene_d": [2, 1, 4],
        "gene_e": [1, 2, 1],
        "noise_f": [0, 1, 2],
        "noise_g": [0, 0, 1],
        "noise_h": [0, 0, 0],
    }
    artificial_counts = {
        "artificial_1": [2, 1, 0],
        "artificial_2": [1, 2, 1],
        "artificial_3": [0, 1, 0],
        "artificial_4": [0, 0, 1],
    }
    lambda_ids = ["lambda_1", "lambda_2", "lambda_3"]
    rows = []
    for feature_type, counts_by_feature in (
        ("real", real_counts),
        ("artificial", artificial_counts),
    ):
        for feature, counts in counts_by_feature.items():
            for lambda_index, count in enumerate(counts):
                for bootstrap_id in range(1, 9):
                    rows.append(
                        (
                            bootstrap_id,
                            lambda_ids[lambda_index],
                            feature_type,
                            feature,
                            int(bootstrap_id <= count),
                        )
                    )
    masks = pd.DataFrame(
        rows,
        columns=["bootstrap_id", "lambda_id", "feature_type", "feature", "selected"],
    )
    csv_write(masks, "selection_masks.csv")

    scores = (
        masks.groupby(["feature_type", "feature", "lambda_id"], sort=False)["selected"]
        .mean()
        .rename("stability_score")
        .reset_index()
    )
    scores["lambda_id"] = pd.Categorical(scores["lambda_id"], lambda_ids, ordered=True)
    scores = scores.sort_values(["feature_type", "feature", "lambda_id"])
    scores["lambda_id"] = scores["lambda_id"].astype("object")
    csv_write(scores, "stability_scores.csv")

    def score_matrix(feature_type: str, order: list[str]) -> np.ndarray:
        subset = scores[scores["feature_type"] == feature_type]
        return np.array(
            [
                [
                    subset.loc[
                        (subset["feature"] == feature) & (subset["lambda_id"] == lambda_id),
                        "stability_score",
                    ].iloc[0]
                    for lambda_id in lambda_ids
                ]
                for feature in order
            ]
        )

    real_features = list(real_counts)
    artificial_features = list(artificial_counts)
    real_scores = score_matrix("real", real_features)
    artificial_scores = score_matrix("artificial", artificial_features)
    thresholds = np.arange(0.0, 1.0001, 0.125)

    methods = extracted_stabl_class(reference / "stabl" / "stabl.py")()
    methods.stabl_scores_ = real_scores
    methods.stabl_scores_artificial_ = artificial_scores
    methods.artificial_proportion = 0.5
    methods.fdr_threshold_range = thresholds
    methods.hard_threshold = None
    methods.explore = False
    methods._compute_FDPplus()
    support = methods._get_support_mask()

    max_real = real_scores.max(axis=1)
    ranking = pd.Series(max_real).rank(method="min", ascending=False).astype(int)
    csv_write(
        pd.DataFrame(
            {
                "feature": real_features,
                "max_stability_score": max_real,
                "rank": ranking,
                "selected": support.astype(int),
            }
        ),
        "stabl_fit_reference.csv",
    )
    max_artificial = artificial_scores.max(axis=1)
    curve = pd.DataFrame(
        {
            "threshold": thresholds,
            "fdp_plus": methods.FDRs_,
            "n_real_strictly_above": [(max_real > value).sum() for value in thresholds],
            "n_artificial_strictly_above": [
                (max_artificial > value).sum() for value in thresholds
            ],
            "is_first_minimum": [
                int(index == int(np.argmin(methods.FDRs_))) for index in range(len(thresholds))
            ],
        }
    )
    csv_write(curve, "fdp_plus_curve.csv")
    table_rows = []
    for lambda_index, lambda_id in enumerate(lambda_ids):
        for threshold_index, threshold in enumerate(thresholds):
            table_rows.append(
                (lambda_id, threshold, methods.fdrs_table[lambda_index, threshold_index])
            )
    csv_write(
        pd.DataFrame(table_rows, columns=["lambda_id", "threshold", "fdp_plus"]),
        "fdp_plus_by_lambda.csv",
    )


class _FixedUniform:
    def __init__(self, candidates: np.ndarray):
        self.candidates = candidates
        self.index = 0

    def uniform(self, low, high, size):
        if tuple(np.atleast_1d(size)) != (self.candidates.shape[1],):
            raise RuntimeError(f"Unexpected random draw shape: {size}")
        row = self.candidates[self.index].copy()
        self.index += 1
        return row


class _NumpyProxy:
    def __init__(self, candidates: np.ndarray):
        self.random = _FixedUniform(candidates)

    def __getattr__(self, name):
        return getattr(np, name)


def make_stacking(reference: Path) -> None:
    predictions = pd.DataFrame(
        {
            "sample_id": [f"stack_s{i}" for i in range(1, 9)],
            "rna": [0.10, 0.90, 0.40, 0.60, 0.30, 0.70, 0.45, 0.55],
            "protein": [0.20, 0.80, 0.30, 0.70, np.nan, 0.60, 0.20, 0.90],
            "metabolite": [0.90, 0.10, 0.70, 0.20, 1.00, np.nan, 0.90, 0.10],
        }
    )
    outcomes = pd.DataFrame(
        {
            "sample_id": predictions["sample_id"],
            "outcome": [0, 1, 0, 1, 0, 1, 0, 1],
        }
    )
    candidates = pd.DataFrame(
        {
            "candidate_id": [1, 2, 3, 4, 5, 6],
            "rna": [1.0, 8.0, 4.0, 0.0, 0.0, 7.0],
            "protein": [1.0, 2.0, 1.0, 6.0, 0.0, 2.0],
            "metabolite": [1.0, 0.0, 0.0, 4.0, 5.0, 1.0],
        }
    )
    csv_write(predictions, "stacking_predictions.csv")
    csv_write(outcomes, "stacking_outcomes.csv")
    csv_write(candidates, "stacking_candidate_weights.csv")

    pred_frame = predictions.drop(columns="sample_id")
    y = pd.Series(outcomes["outcome"].to_numpy(), index=pred_frame.index, name="outcome")
    weights = candidates.drop(columns="candidate_id").to_numpy()
    candidate_scores = []
    candidate_predictions = []
    best_score = -100.0
    best_id = None
    for candidate_id, row in zip(candidates["candidate_id"], weights):
        stacked = (pred_frame * row).sum(axis=1) / ((~pred_frame.isna()) * row).sum(axis=1)
        try:
            score = roc_auc_score(y, stacked)
        except ValueError:
            # This is the pinned stacker's broad scoring-exception behaviour:
            # an invalid candidate (for example a zero observed-weight row) is
            # skipped and can never become the incumbent.
            score = np.nan
        candidate_scores.append(score)
        candidate_predictions.append(stacked.to_numpy())
        if np.isfinite(score) and score > best_score:
            best_score = score
            best_id = int(candidate_id)

    stacking_module = load_module(
        reference / "stabl" / "stacked_generalization.py", "pinned_stacking"
    )
    stacking_module.np = _NumpyProxy(weights)
    python_predictions, python_weights = stacking_module.stacked_multi_omic(
        pred_frame.copy(), y, "binary", n_iter=len(weights)
    )
    chosen_weights = python_weights["Associated weight"].to_numpy()
    chosen_id = int(
        candidates.loc[
            np.all(np.isclose(weights, chosen_weights, rtol=0.0, atol=0.0), axis=1),
            "candidate_id",
        ].iloc[0]
    )
    if chosen_id != best_id:
        raise RuntimeError("Pinned stacker and explicit candidate evaluation disagree.")

    score_frame = pd.DataFrame(
        {
            "candidate_id": candidates["candidate_id"],
            "score": candidate_scores,
            "is_chosen": (candidates["candidate_id"] == chosen_id).astype(int),
            "ties_chosen_score": np.isclose(candidate_scores, best_score, rtol=0.0, atol=1e-15).astype(int),
        }
    )
    csv_write(score_frame, "stacking_candidate_scores.csv")
    normalized = chosen_weights / chosen_weights.sum()
    csv_write(
        pd.DataFrame(
            {
                "omic": pred_frame.columns,
                "raw_weight": chosen_weights,
                "weight": normalized,
                "candidate_id": chosen_id,
                "score": best_score,
            }
        ),
        "stacked_multi_omic_reference.csv",
    )
    csv_write(
        pd.DataFrame(
            {
                "sample_id": predictions["sample_id"],
                "outcome": outcomes["outcome"],
                "stacked_prediction": python_predictions["Stacked Gen. Predictions"],
            }
        ),
        "stacking_predictions_reference.csv",
    )


def make_metrics(reference: Path) -> None:
    metrics = load_module(reference / "stabl" / "metrics.py", "pinned_metrics")
    pair_pred = ["f1", "f2", "f5"]
    pair_true = ["f2", "f3", "f6"]
    sets = [["f1", "f2", "f3"], ["f2", "f3", "f4"], ["f1", "f4"], []]
    nb_total = 8
    adj_median = metrics.adjusted_similarity_measure(sets, nb_total, stat="median")
    adj_mean = metrics.adjusted_similarity_measure(sets, nb_total, stat="mean")
    pear_median = metrics.pearson_similarity_measure(sets, nb_total, stat="median")
    pear_mean = metrics.pearson_similarity_measure(sets, nb_total, stat="mean")
    scalars = [
        ("jaccard_similarity_pair", metrics.jaccard_similarity(pair_pred, pair_true)),
        ("adjusted_similarity_pair", metrics.adjusted_similarity(pair_pred, pair_true, nb_total)),
        ("pearson_similarity_pair", metrics.pearson_similarity(pair_pred, pair_true, nb_total)),
        ("fdr_similarity_pair", metrics.fdr_similarity(pair_pred, pair_true)),
        ("tpr_similarity_pair", metrics.tpr_similarity(pair_pred, pair_true)),
        ("fscore_similarity_beta1_pair", metrics.fscore_similarity(pair_pred, pair_true, beta=1)),
        ("fscore_similarity_beta2_pair", metrics.fscore_similarity(pair_pred, pair_true, beta=2)),
        ("adjusted_similarity_measure_median_stat", adj_median[0]),
        ("adjusted_similarity_measure_median_err_q25", adj_median[1][0]),
        ("adjusted_similarity_measure_median_err_q75", adj_median[1][1]),
        ("adjusted_similarity_measure_mean_stat", adj_mean[0]),
        ("adjusted_similarity_measure_mean_err_sd", adj_mean[1]),
        ("pearson_similarity_measure_median_stat", pear_median[0]),
        ("pearson_similarity_measure_median_err_q25", pear_median[1][0]),
        ("pearson_similarity_measure_median_err_q75", pear_median[1][1]),
        ("pearson_similarity_measure_mean_stat", pear_mean[0]),
        ("pearson_similarity_measure_mean_err_sd", pear_mean[1]),
    ]
    csv_write(pd.DataFrame(scalars, columns=["metric", "value"]), "metrics_scalars.csv")
    vectors = []
    values = {
        "jaccard_matrix_remove_diag_rowmajor": metrics.jaccard_matrix(sets, remove_diag=True).ravel(),
        "adjusted_similarity_values": metrics.adjusted_similarity_values(sets, nb_total),
        "pearson_similarity_values": metrics.pearson_similarity_values(sets, nb_total),
    }
    for metric, metric_values in values.items():
        vectors.extend((metric, index, value) for index, value in enumerate(metric_values, 1))
    csv_write(pd.DataFrame(vectors, columns=["metric", "index", "value"]), "metrics_vectors.csv")


def make_solver_parity() -> None:
    """Generate backend-aware ranking/support references on shared bootstraps."""
    rng = np.random.default_rng(20260722)
    n_samples = 72
    n_features = 12
    x = rng.normal(size=(n_samples, n_features))
    # Add mild correlation without obscuring the three planted signals.
    x[:, 3] = 0.35 * x[:, 0] + np.sqrt(1 - 0.35**2) * x[:, 3]
    x[:, 4] = -0.30 * x[:, 1] + np.sqrt(1 - 0.30**2) * x[:, 4]
    x = (x - x.mean(axis=0)) / x.std(axis=0, ddof=0)
    feature_names = [f"signal_{i}" for i in range(1, 4)] + [
        f"noise_{i}" for i in range(1, n_features - 2)
    ]
    sample_ids = [f"solver_s{i:02d}" for i in range(1, n_samples + 1)]
    matrix = pd.DataFrame(x, columns=feature_names)
    matrix.insert(0, "sample_id", sample_ids)
    csv_write(matrix, "solver_input_matrix.csv")

    gaussian = 3.5 * x[:, 0] - 3.0 * x[:, 1] + 2.5 * x[:, 2] + rng.normal(0, 0.25, n_samples)
    binary_latent = 2.8 * x[:, 0] - 2.4 * x[:, 1] + 2.0 * x[:, 2] + rng.normal(0, 0.35, n_samples)
    binary = (binary_latent > np.median(binary_latent)).astype(int)
    logits = np.column_stack(
        [
            3.0 * x[:, 0] - 1.2 * x[:, 1],
            3.0 * x[:, 1] - 1.2 * x[:, 2],
            3.0 * x[:, 2] - 1.2 * x[:, 0],
        ]
    ) + rng.normal(0, 0.20, size=(n_samples, 3))
    multinomial = np.array(["A", "B", "C"])[np.argmax(logits, axis=1)]
    csv_write(
        pd.DataFrame(
            {
                "sample_id": sample_ids,
                "gaussian": gaussian,
                "binomial": binary,
                "multinomial": multinomial,
            }
        ),
        "solver_outcomes.csv",
    )

    bootstrap_rng = np.random.RandomState(2607)
    schedules = []
    for bootstrap_id in range(1, 41):
        indices = bootstrap_rng.choice(n_samples, size=48, replace=False)
        for position, index in enumerate(indices, 1):
            schedules.append((bootstrap_id, position, sample_ids[index]))
    csv_write(
        pd.DataFrame(schedules, columns=["bootstrap_id", "position", "sample_id"]),
        "solver_bootstrap_schedule.csv",
    )

    cases = [
        {
            "case": "gaussian_lasso",
            "family": "gaussian",
            "base_learner": "lasso",
            "l1_ratio": 1.0,
            "hard_threshold": 0.50,
            "spearman_min": 0.80,
            "top5_overlap_min": 4,
            "jaccard_min": 0.60,
        },
        {
            "case": "binomial_lasso",
            "family": "binomial",
            "base_learner": "lasso",
            "l1_ratio": 1.0,
            "hard_threshold": 0.50,
            "spearman_min": 0.80,
            "top5_overlap_min": 4,
            "jaccard_min": 0.60,
        },
        {
            "case": "multinomial_lasso",
            "family": "multinomial",
            "base_learner": "lasso",
            "l1_ratio": 1.0,
            "hard_threshold": 0.50,
            "spearman_min": 0.70,
            "top5_overlap_min": 3,
            "jaccard_min": 0.50,
        },
        {
            "case": "gaussian_elastic_net",
            "family": "gaussian",
            "base_learner": "elastic_net",
            "l1_ratio": 0.70,
            "hard_threshold": 0.50,
            "spearman_min": 0.70,
            "top5_overlap_min": 3,
            "jaccard_min": 0.50,
        },
    ]
    csv_write(pd.DataFrame(cases), "solver_cases.csv")

    regression_lambdas = [0.03, 0.07, 0.14, 0.28]
    classification_lambdas = [0.01, 0.025, 0.05, 0.10]
    lambda_rows = []
    for case in cases:
        values = regression_lambdas if case["family"] == "gaussian" else classification_lambdas
        for index, value in enumerate(values, 1):
            # sklearn's logistic objective uses inverse regularization C;
            # with fixed bootstrap size, 1/(n*C) is the corresponding
            # average-loss lambda used by glmnet.
            python_parameter = "alpha" if case["family"] == "gaussian" else "C"
            python_value = value if case["family"] == "gaussian" else 1.0 / (48.0 * value)
            lambda_rows.append(
                (
                    case["case"],
                    f"lambda_{index}",
                    python_parameter,
                    python_value,
                    value,
                    case["l1_ratio"],
                )
            )
    lambda_frame = pd.DataFrame(
        lambda_rows,
        columns=["case", "lambda_id", "python_parameter", "python_value", "r_lambda", "alpha"],
    )
    csv_write(lambda_frame, "solver_lambda_grid.csv")

    schedule_frame = pd.DataFrame(schedules, columns=["bootstrap_id", "position", "sample_id"])
    id_to_index = {sample_id: index for index, sample_id in enumerate(sample_ids)}
    bootstrap_indices = [
        np.array([id_to_index[value] for value in group["sample_id"]], dtype=int)
        for _, group in schedule_frame.groupby("bootstrap_id", sort=True)
    ]
    outcome_map = {
        "gaussian": gaussian,
        "binomial": binary,
        "multinomial": multinomial,
    }
    reference_rows = []
    for case in cases:
        case_lambdas = lambda_frame[lambda_frame["case"] == case["case"]]
        scores = np.zeros((n_features, len(case_lambdas)))
        y_case = outcome_map[case["family"]]
        for lambda_index, lambda_row in case_lambdas.reset_index(drop=True).iterrows():
            selections = []
            for bootstrap_index, indices in enumerate(bootstrap_indices):
                if case["family"] == "gaussian" and case["base_learner"] == "lasso":
                    estimator = Lasso(
                        alpha=lambda_row["python_value"],
                        max_iter=100000,
                        tol=1e-10,
                        random_state=bootstrap_index,
                    )
                elif case["family"] == "gaussian":
                    estimator = ElasticNet(
                        alpha=lambda_row["python_value"],
                        l1_ratio=case["l1_ratio"],
                        max_iter=100000,
                        tol=1e-10,
                        random_state=bootstrap_index,
                    )
                else:
                    estimator = LogisticRegression(
                        penalty="l1",
                        C=lambda_row["python_value"],
                        solver="saga",
                        multi_class="multinomial" if case["family"] == "multinomial" else "auto",
                        max_iter=100000,
                        tol=1e-8,
                        random_state=bootstrap_index,
                    )
                estimator.fit(x[indices, :], y_case[indices])
                coefficients = np.asarray(estimator.coef_)
                if coefficients.ndim == 1:
                    importance = np.abs(coefficients)
                else:
                    importance = np.max(np.abs(coefficients), axis=0)
                selections.append(importance > 1e-5)
            scores[:, lambda_index] = np.vstack(selections).mean(axis=0)
        max_scores = scores.max(axis=1)
        ranks = pd.Series(max_scores).rank(method="min", ascending=False).astype(int)
        for feature_index, feature in enumerate(feature_names):
            reference_rows.append(
                (
                    case["case"],
                    feature,
                    max_scores[feature_index],
                    ranks.iloc[feature_index],
                    int(max_scores[feature_index] > case["hard_threshold"]),
                    int(feature_index < 3),
                )
            )
    csv_write(
        pd.DataFrame(
            reference_rows,
            columns=["case", "feature", "max_stability_score", "rank", "selected", "planted_signal"],
        ),
        "solver_reference.csv",
    )


def make_provenance() -> None:
    provenance = {
        "fixture_version": FIXTURE_VERSION,
        "python_reference": {
            "repository": REFERENCE_URL,
            "commit": REFERENCE_COMMIT,
            "package_version_at_commit": "1.0.0",
        },
        "environment": {
            "python": "3.11.9",
            "numpy": "1.26.4",
            "pandas": "2.1.4",
            "scikit_learn": "1.3.2",
            "scipy": "1.11.4",
            "joblib": "1.3.2",
        },
        "contracts": {
            "selection": "frozen boolean masks accumulated exactly over eight bootstraps",
            "fdp_plus": "pinned Stabl._compute_FDPplus method extracted from source AST",
            "support": "pinned Stabl._get_support_mask method extracted from source AST",
            "stacking": "pinned stacked_multi_omic evaluated with committed candidate weights",
            "metrics": "pinned stabl.metrics functions",
            "solver": "pinned scikit-learn estimators on committed inputs and bootstrap schedules",
        },
        "limitations": [
            "Selection masks are committed solver-independent inputs, not outputs of glmnet or scikit-learn fits.",
            "Solver parity uses ranking and support contracts because exact coefficients are backend dependent.",
            "These small deterministic fixtures are integrity and algorithm parity evidence, not statistical calibration evidence.",
        ],
    }
    (HERE / "provenance.json").write_text(
        json.dumps(provenance, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def make_manifest() -> None:
    excluded = {"README.md", "manifest.sha256", "__pycache__"}
    files = sorted(
        path
        for path in HERE.iterdir()
        if path.is_file() and path.name not in excluded and not path.name.endswith("~")
    )
    lines = []
    for path in files:
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.name}\n")
    (HERE / "manifest.sha256").write_text("".join(lines), encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--reference-checkout",
        required=True,
        type=Path,
        help="Checkout of gregbellan/Stabl at the pinned commit.",
    )
    args = parser.parse_args()
    reference = checked_reference(args.reference_checkout.resolve())
    make_inputs()
    make_selection_and_fdp(reference)
    make_stacking(reference)
    make_metrics(reference)
    make_solver_parity()
    make_provenance()
    make_manifest()
    print(f"Regenerated fixtures in {HERE}")


if __name__ == "__main__":
    main()
