# costablr API Reference

This file is a human-readable map of the exported `costablr` API. The canonical
function documentation is generated from roxygen comments in `R/` and lives in
`man/`; the documentation website groups the same functions through
`_pkgdown.yml`.

## Core STABL Engine

- `stabl_fit()` fits the core bootstrap stability-selection procedure.
- `auto_lambda_grid()` builds data-driven `glmnet` lambda grids.
- `compute_fdp_plus()` computes FDP+ threshold diagnostics.

## Learner Adapters

- `make_glmnet_adapter()` creates a single-lambda glmnet learner adapter.
- `make_adaptive_lasso_adapter()` creates a single-lambda adaptive-lasso
  adapter.
- `make_sgl_adapter()` creates a single-lambda sparse-group-lasso adapter.

The core fitting path uses internal batch adapters for efficiency, but the
exported factories remain available for adapter-level workflows and tests.

## Artificial Features

- `make_artificial_features()` dispatches artificial-feature generation.

The lower-level random-permutation, model-X, and MVR helper functions are
internal implementation details; use `make_artificial_features()` or
`stabl_fit(artificial_type = ...)` from user code.

## Input Validation and Bootstrapping

- `validate_sample_alignment()` validates single-matrix sample alignment.
- `validate_multiomic_inputs()` validates named multi-omic input lists.
- `classic_bootstrap_indices()` draws ordinary bootstrap/subsample indices.
- `group_bootstrap_indices()` draws group-aware bootstrap/subsample indices.

## Accessors

- `get_support()` returns a named logical support mask.
- `get_feature_names_out()` returns selected feature names.
- `get_stabl_scores()` returns the feature-by-lambda stability-score matrix.
- `get_importances()` returns maximum-over-lambda feature scores.
- `get_cooperative_features()` returns cooperative-fusion selected features.
- `get_cooperative_diagnostics()` returns cooperative-fusion tuning diagnostics.

## Multi-Omic Workflows

- `stabl_multiomic_train_validate()` runs per-omic STABL plus optional early,
  late, and cooperative fusion on train/validation splits.
- `stabl_multiomic_cv()` runs outer cross-validation over named multi-omic
  inputs.
- `stacked_multi_omic()` performs random-search late-fusion weight selection.
- `load_ool_data()` loads the bundled OOL example subset.

## Visualization

- `plot_stabl_path()` plots stability scores over the lambda path.
- `plot_fdr_graph()` plots FDP+ over candidate thresholds.
- `plot_roc()` plots ROC curves for downstream binary predictors.
- `plot_prc()` plots precision-recall curves.
- `boxplot_features()` plots selected features by class.
- `scatterplot_features()` plots selected features against a continuous
  outcome.

## Export

- `export_stabl_to_csv()` writes STABL score matrices and max-score tables.
- `save_stabl_results()` writes score tables, selected features, diagnostic
  plots, and feature distribution plots.

## Selection Similarity Metrics

- `jaccard_similarity()` and `jaccard_matrix()`
- `adjusted_similarity()`, `adjusted_similarity_values()`, and
  `adjusted_similarity_measure()`
- `pearson_similarity()`, `pearson_similarity_values()`, and
  `pearson_similarity_measure()`
- `fdr_similarity()`, `tpr_similarity()`, and `fscore_similarity()`
