#!/usr/bin/env python3
"""Generate frozen Python reference fixtures for cross-language parity tests.

This script creates deterministic synthetic datasets and fits the Python STABL
implementation, then writes fixture files consumed by the R test suite.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.linear_model import ElasticNet, Lasso, LogisticRegression
from sklearn.utils.validation import check_X_y

from stabl.stabl import Stabl
from stabl import metrics as stabl_metrics


if not hasattr(Stabl, "_validate_data"):
    def _validate_data_compat(self, X, y, reset=True, validate_separately=False):
        del reset, validate_separately
        return check_X_y(X, y, accept_sparse=False)

    Stabl._validate_data = _validate_data_compat


def _softmax(logits: np.ndarray) -> np.ndarray:
    shifted = logits - logits.max(axis=1, keepdims=True)
    exps = np.exp(shifted)
    return exps / exps.sum(axis=1, keepdims=True)


def _write_case(
    case_dir: Path,
    x: np.ndarray,
    y: np.ndarray,
    feature_names: list[str],
    sample_names: list[str],
    stabl: Stabl,
) -> None:
    case_dir.mkdir(parents=True, exist_ok=True)

    x_df = pd.DataFrame(x, index=sample_names, columns=feature_names)
    x_df.to_csv(case_dir / "x.csv")

    y_df = pd.DataFrame({"y": y}, index=sample_names)
    y_df.to_csv(case_dir / "y.csv")

    mean_scores = stabl.stabl_scores_.mean(axis=1)
    max_scores = stabl.stabl_scores_.max(axis=1)
    score_df = pd.DataFrame(
        {
            "feature": feature_names,
            "python_mean_score": mean_scores,
            "python_max_score": max_scores,
        }
    )
    score_df.to_csv(case_dir / "python_feature_scores.csv", index=False)

    selected = stabl.get_feature_names_out(input_features=np.array(feature_names))
    pd.DataFrame({"feature": selected}).to_csv(
        case_dir / "python_selected_features.csv", index=False
    )

    top_order = (
        score_df.sort_values("python_mean_score", ascending=False)["feature"]
        .reset_index(drop=True)
        .to_frame(name="feature")
    )
    top_order.to_csv(case_dir / "python_ranked_features.csv", index=False)

    meta_df = pd.DataFrame(
        {
            "key": ["fdr_min_threshold", "min_fdr", "n_bootstraps"],
            "value": [
                float(stabl.fdr_min_threshold_),
                float(stabl.min_fdr_),
                int(stabl.n_bootstraps),
            ],
        }
    )
    meta_df.to_csv(case_dir / "python_meta.csv", index=False)


def _write_metrics_reference(output_dir: Path) -> None:
    pair_pred = ["f1", "f2", "f5"]
    pair_true = ["f2", "f3", "f6"]
    list_of_lists = [
        ["f1", "f2", "f3"],
        ["f2", "f3", "f4"],
        ["f1", "f4"],
        [],
    ]
    nb_total = 8
    d = 8

    adj_median_stat, adj_median_err = stabl_metrics.adjusted_similarity_measure(
        list_of_lists, nb_total, stat="median"
    )
    adj_mean_stat, adj_mean_err = stabl_metrics.adjusted_similarity_measure(
        list_of_lists, nb_total, stat="mean"
    )

    pear_median_stat, pear_median_err = stabl_metrics.pearson_similarity_measure(
        list_of_lists, d, stat="median"
    )
    pear_mean_stat, pear_mean_err = stabl_metrics.pearson_similarity_measure(
        list_of_lists, d, stat="mean"
    )

    scalars = {
        "jaccard_similarity_pair": stabl_metrics.jaccard_similarity(pair_pred, pair_true),
        "adjusted_similarity_pair": stabl_metrics.adjusted_similarity(pair_pred, pair_true, nb_total),
        "pearson_similarity_pair": stabl_metrics.pearson_similarity(pair_pred, pair_true, d),
        "fdr_similarity_pair": stabl_metrics.fdr_similarity(pair_pred, pair_true),
        "tpr_similarity_pair": stabl_metrics.tpr_similarity(pair_pred, pair_true),
        "fscore_similarity_beta1_pair": stabl_metrics.fscore_similarity(pair_pred, pair_true, beta=1),
        "fscore_similarity_beta2_pair": stabl_metrics.fscore_similarity(pair_pred, pair_true, beta=2),
        "adjusted_similarity_measure_median_stat": float(adj_median_stat),
        "adjusted_similarity_measure_median_err_q25": float(adj_median_err[0]),
        "adjusted_similarity_measure_median_err_q75": float(adj_median_err[1]),
        "adjusted_similarity_measure_mean_stat": float(adj_mean_stat),
        "adjusted_similarity_measure_mean_err_sd": float(adj_mean_err),
        "pearson_similarity_measure_median_stat": float(pear_median_stat),
        "pearson_similarity_measure_median_err_q25": float(pear_median_err[0]),
        "pearson_similarity_measure_median_err_q75": float(pear_median_err[1]),
        "pearson_similarity_measure_mean_stat": float(pear_mean_stat),
        "pearson_similarity_measure_mean_err_sd": float(pear_mean_err),
    }

    scalars_df = pd.DataFrame(
        {
            "metric": list(scalars.keys()),
            "value": list(scalars.values()),
        }
    )
    scalars_df.to_csv(output_dir / "metrics_scalars.csv", index=False)

    jaccard_rm_diag = stabl_metrics.jaccard_matrix(list_of_lists, remove_diag=True)
    adjusted_vals = stabl_metrics.adjusted_similarity_values(list_of_lists, nb_total)
    pearson_vals = stabl_metrics.pearson_similarity_values(list_of_lists, d)

    vectors_df = pd.concat(
        [
            pd.DataFrame(
                {
                    "metric": "jaccard_matrix_remove_diag_rowmajor",
                    "index": np.arange(jaccard_rm_diag.size, dtype=int),
                    "value": jaccard_rm_diag.ravel(order="C"),
                }
            ),
            pd.DataFrame(
                {
                    "metric": "adjusted_similarity_values",
                    "index": np.arange(adjusted_vals.size, dtype=int),
                    "value": adjusted_vals,
                }
            ),
            pd.DataFrame(
                {
                    "metric": "pearson_similarity_values",
                    "index": np.arange(pearson_vals.size, dtype=int),
                    "value": pearson_vals,
                }
            ),
        ],
        ignore_index=True,
    )
    vectors_df.to_csv(output_dir / "metrics_vectors.csv", index=False)


def _build_gaussian(seed: int) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    rng = np.random.default_rng(seed)
    n, p = 110, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))
    y = 1.6 * x[:, 0] - 1.1 * x[:, 1] + rng.normal(scale=0.8, size=n)

    stabl = Stabl(
        base_estimator=Lasso(max_iter=int(1e6), random_state=seed),
        lambda_grid={"alpha": np.geomspace(0.3, 0.01, 6)},
        n_bootstraps=60,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def _build_binomial(seed: int) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    rng = np.random.default_rng(seed)
    n, p = 120, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))
    logits = 1.4 * x[:, 0] - 1.0 * x[:, 1] + 0.2 * x[:, 2] - 0.4
    probs = 1.0 / (1.0 + np.exp(-logits))
    y = rng.binomial(n=1, p=probs, size=n)

    stabl = Stabl(
        base_estimator=LogisticRegression(
            penalty="l1",
            solver="liblinear",
            class_weight="balanced",
            max_iter=int(1e6),
            random_state=seed,
        ),
        lambda_grid={"C": np.geomspace(0.05, 3.0, 6)},
        n_bootstraps=60,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def _build_multinomial(seed: int) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    rng = np.random.default_rng(seed)
    n, p = 150, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))

    logits = np.column_stack(
        [
            1.1 * x[:, 0] - 0.5 * x[:, 1],
            -1.0 * x[:, 0] + 1.2 * x[:, 1],
            -0.3 * x[:, 0] - 0.7 * x[:, 1],
        ]
    )
    probs = _softmax(logits)
    classes = np.array(["A", "B", "C"])
    y = classes[[rng.choice(3, p=probs[i, :]) for i in range(n)]]

    stabl = Stabl(
        base_estimator=LogisticRegression(
            penalty="l1",
            solver="saga",
            multi_class="multinomial",
            class_weight="balanced",
            max_iter=5000,
            random_state=seed,
        ),
        lambda_grid={"C": np.geomspace(0.05, 3.0, 6)},
        n_bootstraps=50,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def _build_gaussian_elastic_net(
    seed: int,
) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    rng = np.random.default_rng(seed)
    n, p = 110, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))
    y = 1.5 * x[:, 0] - 1.0 * x[:, 1] + 0.3 * x[:, 2] + rng.normal(scale=0.8, size=n)

    stabl = Stabl(
        base_estimator=ElasticNet(l1_ratio=0.6, max_iter=int(1e6), random_state=seed),
        lambda_grid={"alpha": np.geomspace(0.3, 0.01, 6)},
        n_bootstraps=60,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def _build_binomial_elastic_net(
    seed: int,
) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    rng = np.random.default_rng(seed)
    n, p = 120, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))
    logits = 1.3 * x[:, 0] - 1.1 * x[:, 1] + 0.3 * x[:, 2] - 0.4
    probs = 1.0 / (1.0 + np.exp(-logits))
    y = rng.binomial(n=1, p=probs, size=n)

    stabl = Stabl(
        base_estimator=LogisticRegression(
            penalty="elasticnet",
            solver="saga",
            l1_ratio=0.6,
            class_weight="balanced",
            max_iter=10000,
            random_state=seed,
        ),
        lambda_grid={"C": np.geomspace(0.05, 3.0, 6)},
        n_bootstraps=60,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def _build_multinomial_elastic_net(
    seed: int,
) -> tuple[np.ndarray, np.ndarray, list[str], list[str], Stabl]:
    """Three-class multinomial with elastic-net penalty (l1_ratio=0.6).

    Uses the same DGP as ``_build_multinomial`` but with an elastic-net
    LogisticRegression, mirroring the binomial_elastic_net pattern.
    """
    rng = np.random.default_rng(seed)
    n, p = 150, 10
    feature_names = [f"f{i + 1}" for i in range(p)]
    sample_names = [f"s{i + 1}" for i in range(n)]

    x = rng.normal(size=(n, p))
    logits = np.column_stack(
        [
            1.1 * x[:, 0] - 0.5 * x[:, 1],
            -1.0 * x[:, 0] + 1.2 * x[:, 1],
            -0.3 * x[:, 0] - 0.7 * x[:, 1],
        ]
    )
    probs = _softmax(logits)
    classes = np.array(["A", "B", "C"])
    y = classes[[rng.choice(3, p=probs[i, :]) for i in range(n)]]

    stabl = Stabl(
        base_estimator=LogisticRegression(
            penalty="elasticnet",
            solver="saga",
            l1_ratio=0.6,
            multi_class="multinomial",
            class_weight="balanced",
            max_iter=5000,
            random_state=seed,
        ),
        lambda_grid={"C": np.geomspace(0.05, 3.0, 6)},
        n_bootstraps=50,
        artificial_type="random_permutation",
        random_state=seed,
        n_jobs=1,
    )
    stabl.fit(x, y)
    return x, y, feature_names, sample_names, stabl


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("r-pkg/stablr/tests/testthat/fixtures/python_parity"),
        help="Destination directory for parity fixtures",
    )
    args = parser.parse_args()

    builders = {
        "gaussian": _build_gaussian,
        "binomial": _build_binomial,
        "multinomial": _build_multinomial,
        "gaussian_elastic_net": _build_gaussian_elastic_net,
        "binomial_elastic_net": _build_binomial_elastic_net,
        "multinomial_elastic_net": _build_multinomial_elastic_net,
    }

    for idx, (name, builder) in enumerate(builders.items(), start=1):
        seed = 100 + idx
        x, y, feature_names, sample_names, stabl = builder(seed)
        _write_case(
            case_dir=args.output_dir / name,
            x=x,
            y=y,
            feature_names=feature_names,
            sample_names=sample_names,
            stabl=stabl,
        )
        print(f"Wrote fixture: {name}")

    _write_metrics_reference(args.output_dir)
    print("Wrote fixture: metrics")


if __name__ == "__main__":
    main()
