# costablr Architecture

This document is the maintainer-facing map of `costablr`. Algorithm semantics
and parity rules live in `STABL.md`; this file explains where the code lives
and how the main runtime paths fit together.

## Package Purpose

`costablr` is a pure-R implementation of STABL for sparse, reliable biomarker
discovery in high-dimensional clinical and omic data. The core selector uses
bootstrap stability selection with artificial-feature FDP+ control. Predictive
workflows layer unpenalized final refits, multi-omic Early Fusion,
canonical prediction-level Late Fusion, STABL-Selected Late Fusion,
Multi-Omic STABL, Cooperative Fusion through `multiview`, and nested
cross-validation on top of that selector.

The package has no Python runtime dependency and no tidymodels runtime
dependency.

## Public API

Core selector and refit:

- `stabl_fit()` - core STABL selector boundary.
- `stabl_refit()` - final unpenalized predictive refit after a fitted
  `stabl_fit()` selector.
- `predict.stabl_refit()` - predictions from the final refit.

Accessors:

- `get_support()`, `get_feature_names_out()`, `get_importances()`,
  `get_stabl_scores()`.
- `get_cooperative_features()`, `get_cooperative_diagnostics()`.

Multi-omic workflows:

- `stabl_multiomic_train_validate()`.
- `stabl_multiomic_cv()`.
- `stabl_multiomic_nested_cv()`.
- `stacked_multi_omic()`.

Utilities:

- `auto_lambda_grid()`, bootstrap helpers, artificial-feature helpers,
  FDP+ helpers, similarity metrics, plots, and export functions.

## S3 Classes

| Class | Constructor | Main fields |
|---|---|---|
| `stabl_fit` | `stabl_fit()` | `stabl_scores_`, `stabl_scores_artificial_`, `fitted_lambda_grid`, `family`, `fdr_min_threshold_`, `FDRs_`, `min_fdr_`, `hard_threshold`, `artificial_type`, `artificial_type_used_`, `feature_names` |
| `stabl_refit` | `stabl_refit()` | `stabl_fit`, `selected_features`, `selected_train`, `final_model`, `final_model_type`, `family`, `task_type`, `training_predictions`, `call` |
| `stabl_multiomic_fit` | `stabl_multiomic_train_validate()` | `fits`, `refits`, `selected_features`, `early_fusion`, `late_fusion`, `stabl_selected_late_fusion`, optional `multiomic_stabl`, optional `cooperative_fusion` |
| `stabl_multiomic_cv` | `stabl_multiomic_cv()` | `fold_results`, `diagnostics`, `performance`, `folds` |
| `stabl_multiomic_nested_cv` | `stabl_multiomic_nested_cv()` | `outer_folds`, `fold_results`, `diagnostics`, `outer_predictions`, `performance` |

Public code should use accessors when possible. Internal tests may inspect
fields directly when they are pinning object contracts.

## Module Responsibility Table

| File | Responsibility |
|---|---|
| `R/stabl_fit.R` | Core selector, lambda preparation, artificial-feature injection, bootstrap loop, FDP+ result assembly |
| `R/stabl_refit.R` | Single-matrix final unpenalized predictive refit from an existing selector and prediction |
| `R/learner_adapters.R` | Glmnet, adaptive-lasso, elastic-net, and sparse-group-lasso adapter surfaces |
| `R/bootstrap_helpers.R` | Classic and grouped bootstrap sampling with alignment and strata checks |
| `R/artificial_features.R` | Random-permutation and model-X artificial-feature generation dispatcher |
| `R/mvr_knockoff.R` | Gaussian MVR knockoff construction and R/Rcpp solver bridge |
| `R/fdp_control.R` | FDP+ threshold computation |
| `R/input_validation.R` | Matrix/outcome/multiomic alignment validation |
| `R/stabl_accessors.R` | S3 accessors, print methods, cooperative accessors, threshold resolver |
| `R/multiomic_workflows.R` | Multi-omic train/validation and CV orchestration |
| `R/cv_helpers.R` | Shared fold and fold-ID helpers |
| `R/stacked_generalization.R` | `stacked_multi_omic()` and prediction-stacking helpers |
| `R/cooperative_fusion.R` | Multiview cooperative-fusion internals |
| `R/nested_cv.R` | Nested cross-validation orchestration and nested result summaries |
| `R/metrics.R` | Similarity and prediction metrics |
| `R/visualization.R` | ggplot2 diagnostics and selected-feature plots |
| `R/exports.R` | CSV/RDS export helpers and packaged data loading |
| `src/` | Rcpp native helpers for correlation grouping and MVR S-matrix solving |

Scratch notebooks, SLURM scripts, and cache-producing analysis scripts live
outside package runtime responsibilities.

## Runtime Flows

Single-matrix STABL:

`stabl_fit()` -> validate/alignment -> lambda grid -> artificial features ->
bootstrap indices -> learner adapter path fits -> stability scores -> FDP+ ->
`stabl_fit` object.

Final refit:

`stabl_refit(stabl_fit, x, y)` -> `get_feature_names_out()` -> selected
matrix -> `.fit_stabl_final_model()` -> `stabl_refit` object.

Multi-omic train/validation:

`stabl_multiomic_train_validate()` -> per-omic `stabl_fit()` and
`stabl_refit()` -> optional early fusion -> optional canonical late fusion
through full-view per-omic glmnet predictors and `stacked_multi_omic()` ->
optional STABL-selected late fusion through `stacked_multi_omic()` -> optional
cooperative fusion through `multiview`.

Multi-omic CV:

`stabl_multiomic_cv()` -> `.make_multiomic_cv_folds()` -> repeated
`stabl_multiomic_train_validate()` -> fold diagnostics and summaries.

Nested CV:

`stabl_multiomic_nested_cv()` -> repeated outer folds -> inner candidate
evaluation -> selected candidate fit on outer training split -> held-out
prediction and aggregate performance.

Artificial features and FDP+:

`make_artificial_features()` appends known-noise columns. `compute_fdp_plus()`
compares real and artificial stability paths over candidate thresholds. Support
uses the paper-method `>=` rule; per-bootstrap coefficient masks use
`>= bootstrap_threshold`.

Canonical late fusion:

Independent per-omic penalized glmnet predictors are fitted on full omic
matrices and their predictions are stacked by `stacked_multi_omic()`. This
branch is exposed as `late_fusion` and does not use STABL-selected features.

STABL-selected late fusion:

Per-omic STABL-selected Final Refit predictions are stacked by
`stacked_multi_omic()`, which uses random-search weights and task-specific
scoring. This branch is exposed as `stabl_selected_late_fusion`, not
canonical Late Fusion.

Cooperative fusion:

`R/cooperative_fusion.R` wraps optional `multiview` model fitting, tuning,
coefficient extraction, one-vs-rest multinomial support, and diagnostics.

## Dependency Boundaries

| Dependency | Type | Used for |
|---|---|---|
| `glmnet` | Import | Core penalized learners |
| `Rcpp`, `RcppArmadillo` | Import/LinkingTo | Native correlation grouping and MVR solver |
| `sparsegl` | Suggests | Sparse-group-lasso adapter |
| `knockoff` | Suggests | Gaussian model-X knockoff artificial features |
| `future`, `furrr` | Suggests | Scoped optional parallelism for STABL bootstraps and nested-CV outer folds |
| `multiview` | Suggests | Cooperative fusion only |
| `nnet` | Suggests | Multinomial final refit |
| `survival` | Suggests | Cox final refit |
| `ggplot2` | Suggests | Plotting helpers |
| `knitr`, `rmarkdown`, `pkgdown` | Suggests | Vignettes and site checks |
| `withr` | Suggests | Test-time seed control |

Optional dependencies must remain optional. Guard with `requireNamespace()`
and give clear installation messages.

## Native Code

- `src/corr_groups.cpp` computes thresholded correlation groups using
  union-find.
- `src/mvr_knockoff.cpp` solves the ungrouped MVR S matrix with RcppArmadillo.
- `R/RcppExports.R` and `src/RcppExports.cpp` are generated glue.

Do not commit local `src/*.o` or `src/*.so` artifacts.

## Validation Commands

Use the repository-local R environment:

```bash
conda run -n R4_51 Rscript -e "Sys.setenv(NOT_CRAN='true'); devtools::test('.', reporter = 'summary')"
conda run -n R4_51 Rscript -e "devtools::load_all('.', quiet = TRUE); testthat::test_dir('tests/testthat', filter = 'audit', reporter = 'summary')"
conda run -n R4_51 Rscript -e 'res <- rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "never"); print(res)'
conda run -n R4_51 Rscript -e "pkgdown::check_pkgdown()"
```

For focused refactors, run the nearest targeted tests first, then the full
suite before handoff.
