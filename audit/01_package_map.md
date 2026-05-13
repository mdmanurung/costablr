# 01 Package Map

Audit date: 2026-05-13

Status reviewed: 2026-05-13. This document is an inventory and baseline
diagnostic map, not a defect list. The two actionable baseline diagnostics
recorded here are fixed in the post-remediation state:

> **Re-review note (2026-05-13 evening).** This inventory was sealed before
> commits `ed84166` (multinomial cooperative fusion) and `5c11faa` (new
> `stabl_refit()` API) landed. The inline addenda below mark items that have
> drifted. See `00_summary.md` "Drift since audit closure" for the full list.

- `devtools::check('.', error_on = 'never')`: FIXED relative to the baseline
  vignette-build failure. Current recorded closure is `0 errors`, with only
  local `qpdf`, timestamp, and conda toolchain warning/note items.
- `pkgdown::check_pkgdown()`: FIXED after adding the missing
  `costablr-tcga-nestedcv` article index entry.

## Package metadata

- Package: `costablr`
- Version: `0.0.0.9000`
- Title: Sparse and Reliable Biomarker Discovery in R
- R dependency: `R (>= 4.4.0)`
- Imports: `glmnet`, `Rcpp`, `stats`, `utils`
- LinkingTo: `Rcpp`, `RcppArmadillo`
- Suggests: `furrr`, `future`, `ggplot2`, `knockoff`, `knitr`,
  `mixOmics`, `multiview`, `pkgdown`, `rmarkdown`, `sparsegl`, `survival`,
  `testthat (>= 3.0.0)`, `withr`
  - DRIFT 2026-05-13: `nnet` was added to `Suggests` by commit `5c11faa` for
    the multinomial branch of `stabl_refit()`. `DESCRIPTION` now lists 13
    suggested packages.
- Encoding: UTF-8
- testthat edition: `3`

Runtime preflight in `R4_51`:

- R version: `4.5.1`
- `.libPaths()`:
  - `/exports/para-lipg-hpc/mdmanurung/R/4.5`
  - `/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/lib/R/library`
- Installed optional audit deps observed: `devtools`, `testthat`, `pkgdown`,
  `Rcpp`, `RcppArmadillo`, `glmnet`, `withr`, `furrr`, `future`, `knockoff`,
  `mixOmics`, `multiview`, `sparsegl`, `survival`, `bench`
- `hedgehog`: not installed
- `air`: not available; `air format .` was not run because approval was
  rejected as outside the audit write scope.

## Exported API

`NAMESPACE` exports:

- Core: `stabl_fit`, `auto_lambda_grid`, `compute_fdp_plus`
  - DRIFT 2026-05-13: `stabl_refit` was added to `NAMESPACE` by commit
    `5c11faa`. It is the end-to-end selector-plus-unpenalized-refit entry
    point and is documented in `man/stabl_refit.Rd`. It is **absent from
    `_pkgdown.yml`** — recurrence of the IMPL-007 pattern.
- Artificial features: `make_artificial_features`
- Learner adapters: `make_glmnet_adapter`, `make_adaptive_lasso_adapter`,
  `make_sgl_adapter`
- Bootstrap and validation: `classic_bootstrap_indices`,
  `group_bootstrap_indices`, `validate_sample_alignment`,
  `validate_multiomic_inputs`
- Accessors: `get_support`, `get_stabl_scores`, `get_feature_names_out`,
  `get_importances`, `get_cooperative_features`,
  `get_cooperative_diagnostics`
- Multi-omic workflows: `stabl_multiomic_train_validate`,
  `stabl_multiomic_cv`, `stabl_multiomic_nested_cv`, `stacked_multi_omic`
- Metrics: `jaccard_similarity`, `jaccard_matrix`, `adjusted_similarity`,
  `adjusted_similarity_values`, `adjusted_similarity_measure`,
  `pearson_similarity`, `pearson_similarity_values`,
  `pearson_similarity_measure`, `fdr_similarity`, `tpr_similarity`,
  `fscore_similarity`
- Visualization/export/data: `plot_stabl_path`, `plot_fdr_graph`,
  `plot_roc`, `plot_prc`, `boxplot_features`, `scatterplot_features`,
  `export_stabl_to_csv`, `save_stabl_results`, `load_ool_data`

S3 registrations:

- `stabl_fit`: `get_support`, `get_stabl_scores`, `get_feature_names_out`,
  `get_importances`, `print`
- `stabl_multiomic_fit`: `get_cooperative_features`,
  `get_cooperative_diagnostics`, `print`
- `stabl_multiomic_cv`: `get_cooperative_features`,
  `get_cooperative_diagnostics`, `print`
- `stabl_multiomic_nested_cv`: `print`
- DRIFT 2026-05-13: `stabl_refit` now also has `S3method(predict, stabl_refit)`
  and `S3method(print, stabl_refit)` registrations (commit `5c11faa`).

Native registration:

- `useDynLib(costablr, .registration=TRUE)`
- `importFrom(Rcpp, evalCpp)`
- Registered routines as of 2026-05-13:
  - `_costablr_mvr_solve_ungrouped_cpp` (MVR knockoff S-matrix solver)
  - `_costablr_corr_groups_from_corr_cpp` (NAT-002 correlation-union helper;
    added by commit `6207d6a`)

## R inventory

- `R/artificial_features.R`: random-permutation, model-X knockoff, and
  artificial-feature dispatch helpers.
- `R/bootstrap_helpers.R`: classic, stratified, grouped, and grouped-stratified
  bootstrap samplers.
- `R/data_helpers.R`: bundled Onset of Labor data loader.
- `R/exports.R`: CSV and full result export helpers.
- `R/fdp_control.R`: FDP+ threshold sweep.
- `R/input_validation.R`: sample alignment, multi-omic input validation, and
  cooperative argument normalization.
- `R/learner_adapters.R`: glmnet, adaptive lasso, sparse-group lasso, auto
  lambda grids, and batch coefficient extraction.
- `R/metrics.R`: feature-set similarity and simulation metrics.
- `R/multiomic_workflows.R`: train/validation, CV, late fusion, cooperative
  fusion, and stacking.
- `R/mvr_knockoff.R`: R wrapper and pure-R fallback for Gaussian MVR knockoffs.
- `R/nested_cv.R`: repeated nested CV for multi-omic STABL workflows.
- `R/RcppExports.R`: generated `.Call` wrappers for the native MVR solver and
  (post-audit) the `corr_groups_from_corr_cpp` union helper.
- `R/stabl_accessors.R`: S3 accessors and print methods.
- `R/stabl_fit.R`: core STABL orchestration.
- `R/stabl_refit.R`: end-to-end selector + unpenalized final refit (gaussian
  via `lm`, binomial/poisson via `glm`, cox via `survival::coxph`, multinomial
  via `nnet::multinom`), plus `predict.stabl_refit()` and
  `print.stabl_refit()`. ADDED post-audit by commit `5c11faa`.
- `R/visualization.R`: stability, FDP, ROC/PRC, and selected-feature plots.

## Native inventory

- `src/mvr_knockoff.cpp`: RcppArmadillo ungrouped MVR S-matrix coordinate
  descent solver.
- `src/corr_groups.cpp`: small Rcpp union-find that performs the NAT-002
  thresholded correlation-union step (~55 lines). Uses `std::vector<int>` for
  parent pointers and `std::map<int,int>` to renumber roots to 1-indexed
  group IDs. Pure header-only `Rcpp.h`; does NOT link RcppArmadillo.
  ADDED post-audit by commit `6207d6a`.
- `src/RcppExports.cpp`: generated registration for
  `_costablr_mvr_solve_ungrouped_cpp` and `_costablr_corr_groups_from_corr_cpp`.
- No `src/Makevars` file observed.

## Tests and fixtures

- 17 pre-existing test files under `tests/testthat/`.
- Python parity fixtures under `tests/testthat/fixtures/python_parity/` for
  binomial, gaussian, multinomial, elastic-net variants, and metrics.
- No pre-existing snapshot directory was tracked before Phase 6.
- DRIFT 2026-05-13: `tests/testthat/test-stabl-refit.R` (~100 lines) was added
  by commit `5c11faa`. It covers happy-path gaussian, binomial, and
  empty-support intercept-only cases. It does NOT exercise multinomial, cox,
  poisson, or `predict.stabl_refit()` `newdata` schema mismatch — those
  branches in `R/stabl_refit.R` are currently untested.

## Documentation inventory

- Man pages are present for all exported functions and for internal artificial
  feature helpers `make_rp_features()` and `make_modelx_knockoff_features()`.
- Vignettes:
  - `costablr-intro.Rmd`
  - `costablr-multiomic.Rmd`
  - `costablr-python-parity.Rmd`
  - `costablr-tcga.Rmd`
  - `costablr-cooperative.Rmd`
  - `costablr-tcga-nestedcv.Rmd`
- `_pkgdown.yml` defines reference sections and five article index entries.
- `NEWS.md` was not present in the tracked file list.

## Public call graph summary

> **Re-review note (2026-05-13 evening).** Line numbers cited in the
> per-finding files (`02`–`06`) refer to the state when the audit was sealed.
> `R/multiomic_workflows.R` has since grown from ~1430 to ~1870 lines after
> commit `ed84166`'s multinomial cooperative fusion patch. The findings still
> point at the correct code paths but the absolute offsets have drifted; use
> the function names and grep markers (e.g. `.cooperative_multiomic_fit`,
> `stacked_multi_omic`) rather than the line numbers when re-verifying.

- `stabl_fit()` -> `validate_sample_alignment()` ->
  `.subset_outcome_by_ids()` -> optional `.subset_bootstrap_strata_by_ids()` ->
  `.validate_stabl_params()` -> optional `auto_lambda_grid()` ->
  optional `make_artificial_features()` -> optional
  `.resolve_sgl_feature_groups()` -> batch learner adapter ->
  `classic_bootstrap_indices()` or `group_bootstrap_indices()` ->
  `compute_fdp_plus()`.
- `make_artificial_features()` dispatches to `make_rp_features()`,
  `make_modelx_knockoff_features()`, or `make_mvr_knockoff_features()`.
- `make_mvr_knockoff_features()` -> `.estimate_gaussian_moments()` ->
  `.solve_mvr()` -> `mvr_solve_ungrouped_cpp()` or `.solve_mvr_ungrouped_r()`
  -> `.produce_mx_gaussian_knockoffs()`.
- `stabl_multiomic_train_validate()` -> `validate_multiomic_inputs()` ->
  per-omic `stabl_fit()` -> accessors -> optional early fusion `stabl_fit()`
  -> optional late fusion `.late_fusion_fit_omic()` and `stacked_multi_omic()`
  -> optional `.cooperative_multiomic_fit()`.
- `stabl_multiomic_cv()` -> `.make_multiomic_cv_folds()` ->
  fold-specific `stabl_multiomic_train_validate()` ->
  `.summarize_multiomic_fold()`.
- `stabl_multiomic_nested_cv()` -> `.make_repeated_cv_folds()` ->
  `.evaluate_stabl_candidates_inner()` -> `.fit_stabl_nested_candidate()` ->
  `stabl_fit()` and selected-feature prediction helpers.
- POST-AUDIT (commit `5c11faa`): `stabl_refit()` ->
  `validate_sample_alignment()` -> `.subset_outcome_by_ids()` ->
  `stabl_fit()` -> `get_feature_names_out()` -> `.stabl_subset_selected_matrix()`
  -> `.fit_stabl_final_model()` dispatched on `.stabl_refit_task_type(family)`.
  `R/multiomic_workflows.R` and `R/nested_cv.R` both call
  `.stabl_refit_task_type()` internally to share the family-to-task-type map.

Dispatch paths that simple grep can miss:

- S3 methods for `get_support`, `get_stabl_scores`, `get_feature_names_out`,
  `get_importances`, cooperative accessors, and print methods.
- `glmnet::coef.glmnet()` return-shape dispatch in coefficient helpers.
- Optional `multiview`, `sparsegl`, and `knockoff` code paths.
- Native `.Call` from generated Rcpp wrappers.

## Baseline diagnostics

Commands run in `conda run -n R4_51`.

- `devtools::load_all('.', quiet = TRUE)`: PASS.
  - Warning: package `testthat` was built under R version 4.5.2.
- `devtools::test('.')`: PASS with existing warnings.
  - `PASS 1458`, `FAIL 0`, `WARN 2`, `SKIP 0`.
  - Both warnings came from `future` package build-version warnings in
    `test-rng-determinism.R`.
- `devtools::check('.', error_on = 'never')`: FAIL during vignette build.
  - Failure occurred while rebuilding `costablr-python-parity.Rmd` chunk
    `ool-fit`.
  - Error text: `` `type` must be "random_permutation" or "knockoff", got:
    modelx_knockoff ``.
  - Backtrace printed `stablr::stabl_fit(...)` even though the current source
    Rmd uses `library(costablr)` and `render_artificial_type_ool <-
    "modelx_knockoff"`.
  - Inference: likely stale vignette cache or stale generated artifact, but
    UNCERTAIN - needs human review.
- `pkgdown::check_pkgdown()`: FAIL.
  - Error: `_pkgdown.yml` is missing vignette index entry
    `"costablr-tcga-nestedcv"`.
