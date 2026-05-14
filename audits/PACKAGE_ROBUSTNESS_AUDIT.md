# Package Robustness Audit

## Executive summary

This audit inspected the package structure, R sources, exported API, Rd files, vignettes, README, DESCRIPTION, NAMESPACE, tests, and the existing `audit/` trail. The current package is substantially tested: the full local `testthat` suite has no failures after this pass, and the core STABL, refit, multi-omic, artificial-feature, FDP+, bootstrap, accessor, plotting/export, nested-CV, and parity-fixture workflows all have direct coverage.

One correctness defect was found and fixed: binary late fusion could silently compute the wrong AUC when the outcome was a two-level factor instead of numeric `0`/`1`. This affects `stacked_multi_omic(task_type = "binary")` directly and `stabl_multiomic_train_validate(family = "binomial", late_fusion = TRUE)` transitively. The fix is backward-compatible: binary stacking now accepts numeric/logical `0`/`1` or two-level factor/character outcomes, maps the second factor/character level to the positive class, preserves the previous missing-outcome skip behavior during scoring, and rejects malformed labels clearly.

The package is safe for the documented workflows covered by the local test suite. It is not yet CRAN-clean: final `rcmdcheck --no-manual --as-cran` has `0 errors`, `1 warning`, and `3 notes`, all environmental/release-hygiene items listed below.

## Critical issues

### CRIT-001: Binary late fusion scored factor outcomes incorrectly

- Status: fixed.
- Affected functions: `stacked_multi_omic()`, downstream binomial late fusion in `stabl_multiomic_train_validate()`.
- Intended behavior: binary stacking should optimize the same AUC whether the binary outcome is supplied as documented numeric `0`/`1` labels or as ordinary R two-level factor labels accepted elsewhere in the binomial workflow.
- Previous behavior: factor outcomes were passed through to `.r_auc()`, where `which(y == 1L)` did not identify the positive factor class correctly. A perfectly ranked toy example scored `0.5` with `factor(c("no", "yes", "no", "yes"))` but `1.0` with `c(0, 1, 0, 1)`.
- Fix: added `.coerce_binary_stack_outcome()` in `R/multiomic_workflows.R`; binary labels are validated and normalized before random-search scoring.
- Tests added: `AUDIT CRIT-001` tests in `tests/testthat/test-audit-multiomic-workflows.R` for factor/numeric equivalence, malformed labels, and missing-outcome skip behavior.
- API classification: safe/backward-compatible hardening.

## High-priority issues

### HIGH-001: CRAN/release metadata is not clean

- Status: partially fixed.
- Evidence: final `rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"))` reports `0 errors`, `1 warning`, `3 notes`.
- Fixed during this pass: `.Rbuildignore` now excludes analysis-only `scratch/`, `audit/`, `audits/`, `Sample Data/`, `Notebook examples/`, `.claude/`, and `.vscode/` from package builds; `DESCRIPTION` no longer advertises the dead pkgdown URL that returned 404.
- Remaining warning: local `qpdf` is unavailable, so PDF size-reduction checks are skipped.
- Remaining notes: CRAN incoming sees a new submission with dev version `0.0.0.9000`; conda compiler flags include non-portable `-march=nocona`; `stabl_fit` example elapsed time exceeded 5 seconds in the local AS-CRAN run.
- Recommended fix: install `qpdf` in the check image, set a CRAN release version before submission, use a CRAN-like compiler image, and consider further shortening `stabl_fit` examples if CRAN timing remains high.

### HIGH-002: Static style and usage debt remains broad

- Status: reported, not fixed in this pass.
- Evidence: `lintr::lint_package()` reports 847 lints, dominated by line length, indentation, semicolons in tests/vignettes, long internal helper names, and analysis-script object-usage warnings.
- Evidence: `codetools::checkUsageEnv(asNamespace("costablr"), all = TRUE)` reports many non-fatal diagnostics, mostly parameter reassignment, S3 generic placeholders, closure-local helper binding, and ggplot NSE global-variable warnings. `R CMD check` dependency and code checks are OK.
- Recommended fix: decide whether style cleanup is part of CRAN prep. Do not mix broad lint churn with algorithmic changes.

## Medium-priority issues

### MED-001: Some exported helpers still rely on downstream errors for invalid inputs

- Affected areas: `compute_fdp_plus()`, `auto_lambda_grid()`, learner-adapter factories, plotting helpers, and metric helpers.
- Current status: core workflows validate enough to pass documented tests, but direct helper calls can still produce base-R or backend errors for malformed matrices, empty grids, non-finite values, invalid `n_iter`, invalid `l1_ratio`, or non-binary ROC/PRC labels.
- Recommendation: add a future validation tranche with focused tests for direct helper APIs. This is hardening work, not a newly observed workflow breakage.

### MED-002: Native/performance candidate placeholders remain intentionally deferred

- Affected tests: `NAT-001` and `NAT-003` in `test-audit-native-candidates.R`.
- Current status: skipped by design; full suite reports these as the only skips.
- Recommendation: keep them deferred unless native rewrites become a release target.

## Function-by-function audit

### Core STABL

- `stabl_fit()`
  - Intended purpose: core bootstrap stability-selection over a lambda grid with optional artificial-feature FDP+ threshold control.
  - Current behavior: aligns samples by names, generates artificial features, supports lasso/elastic-net/adaptive-lasso/sparse-group-lasso, supports grouped and stratified bootstrapping, and returns an S3 `"stabl_fit"` object consumed by accessors and plotting/export helpers.
  - Arguments audited: all formal arguments are used directly or forwarded to learner/bootstrap/artificial-feature paths. `verbose` only controls progress messages. `workers` activates the `furrr` path only when optional packages are installed.
  - Validation status: good for alignment, thresholds, bootstrap controls, artificial-feature count, group sampling, and sparse-group settings; weaker for direct finite-value checks and malformed lambda-grid values.
  - Output status: structured object fields match accessors; roxygen return docs were restored for `bootstrap_threshold`.
  - Tests: extensive coverage in `test-stabl-fit.R`, parity fixtures, RNG determinism, validation edges, signal recovery, FDP+ invariants, and audit tests.

- `stabl_refit()`, `predict.stabl_refit()`, `print.stabl_refit()`
  - Intended purpose: run STABL selection then fit an unpenalized final model.
  - Current behavior: supports gaussian, binomial, multinomial, Poisson, and Cox final refits; intercept-only fallback is explicit when no features pass.
  - Arguments audited: `final_model_args` is validated as a named list and forwarded; `...` is forwarded to `stabl_fit()` and is intentional.
  - Validation status: good for newdata class, row IDs, selected columns, outcome family, and class-loss after alignment.
  - Tests: `test-stabl-refit.R` and `test-audit-stabl-fit.R`.

### Learner adapters and lambda grids

- `make_glmnet_adapter()`, `make_adaptive_lasso_adapter()`, `make_sgl_adapter()`
  - Intended purpose: create per-bootstrap feature-selection closures.
  - Current behavior: exported factories remain usable directly, while `stabl_fit()` uses batch internal adapters for performance.
  - Arguments audited: `family`, alpha controls, adaptive weights, feature groups, and `bootstrap_threshold` are used. Optional dependencies are checked before use.
  - Validation status: good for adaptive parameters, sparse-group feature groups, sparse-group Cox rejection, and bootstrap thresholds; family/lambda details mostly rely on backends.
  - Tests: core learner tests in `test-stabl-fit.R` plus performance equivalence tests.

- `auto_lambda_grid()`
  - Intended purpose: derive glmnet lambda sequences, optionally across `l1_ratio` alpha values.
  - Current behavior: returns a data frame with `lambda`, plus `alpha` when `l1_ratio` is supplied.
  - Validation status: backend-driven for invalid family, data, alpha, and `n_lambda`.
  - Tests: lasso, mixed-alpha, Cox, multinomial, and binomial coverage.

### Artificial features and FDP+

- `make_artificial_features()`
  - Intended purpose: dispatch random-permutation, model-X knockoff, or MVR knockoff artificial features.
  - Current behavior: returns `x_augmented` plus source `noise_col_indices`; old `"knockoff"` label is rejected.
  - Validation status: high-level `stabl_fit()` prevents zero injected count; direct helper validation remains minimal.
  - Tests: random-permutation parity, model-X direct seed, MVR schema/fallback, old-name rejection.

- `compute_fdp_plus()`
  - Intended purpose: compute FDP+ over strict `>` threshold sweep and return selected threshold diagnostics.
  - Current behavior: vectorized implementation matches documented STABL parity invariants.
  - Validation status: no explicit direct validation for malformed score matrices or threshold grids.
  - Tests: strict tie behavior, `(1 / pi)` scaling, denominator floor, threshold cap, structural tests.

### Bootstrapping and validation

- `classic_bootstrap_indices()`, `group_bootstrap_indices()`
  - Intended purpose: sample independent rows or whole groups, with optional stratification.
  - Current behavior: preserves group integrity, retries class-degenerate samples, supports arbitrary strata, and protects the length-one numeric `sample()` pitfall.
  - Arguments audited: `class_weights` is used only in classic unstratified sampling and is intentionally incompatible with `strata`; `stratify` is outcome-strata shorthand.
  - Validation status: good for sizes, strata shape, group length, group-strata purity; future hardening could validate `class_weights` numeric finiteness.
  - Tests: bootstrap helper suites and group-type regression tests.

- `validate_sample_alignment()`, `validate_multiomic_inputs()`
  - Intended purpose: enforce name-based sample alignment.
  - Current behavior: rejects missing, duplicate, or mismatched sample IDs and validates group name sets.
  - Validation status: strong for alignment; direct numeric-content validation is left to fitting functions.
  - Tests: input-validation and audit duplicate-ID tests.

### Accessors and S3 methods

- `get_support()`, `get_stabl_scores()`, `get_feature_names_out()`, `get_importances()`
  - Intended purpose: stable public read surface for `"stabl_fit"` objects.
  - Current behavior: validates fitted structure, resolves thresholds, supports strict `>` selection and explore fallback.
  - Arguments audited: `new_hard_threshold` is used in support/name accessors only; generic arguments appear unused to `codetools` by S3 design.
  - Tests: accessor round-trip, invalid threshold audit, hard-threshold override, print smoke tests.

- `get_cooperative_features()`, `get_cooperative_diagnostics()`
  - Intended purpose: public access to cooperative-fusion selected features and diagnostics.
  - Current behavior: validates cooperative branch presence, supports multiomic CV objects and one-vs-rest class-specific features.
  - Tests: cooperative accessor tests and absent-branch errors.

- Print methods for `stabl_fit`, `stabl_refit`, `stabl_multiomic_fit`, `stabl_multiomic_cv`, `stabl_multiomic_nested_cv`
  - Intended purpose: concise object summaries.
  - Current behavior: side-effectful by design through `cat()`.
  - Tests: print smoke coverage exists for major classes.

### Multi-omic workflows

- `stabl_multiomic_train_validate()`
  - Intended purpose: run per-omic STABL with optional early, late, and cooperative fusion.
  - Current behavior: aligns named outcomes, validates validation sets, refits final per-omic models, supports validation predictions without `y_valid`, and supports cooperative multinomial one-vs-rest.
  - Arguments audited: `...` is intentionally forwarded to `stabl_fit()`; `n_iter_lf` is used only when late fusion is enabled; cooperative arguments are normalized only when requested.
  - Tests: broad workflow suite plus this audit's CRIT-001 regression tests.

- `stabl_multiomic_cv()`
  - Intended purpose: fold wrapper around train/validation workflow.
  - Current behavior: deterministic folds under `random_state`, grouped fold preservation, bootstrap-strata forwarding, cooperative diagnostics.
  - Validation status: good for fold count and group count; stratification is bootstrap-only here, not assessment-fold stratification.
  - Tests: deterministic CV, grouped CV, strata, cooperative diagnostics.

- `stabl_multiomic_nested_cv()`
  - Intended purpose: repeated nested candidate comparison for multi-omic STABL candidates.
  - Current behavior: supports default and custom candidates, stratified folds, custom strata, final refit fallback, and classification metrics.
  - Tests: nested-CV suite covers deterministic diagnostics, custom strata, invalid folds, fallback, and lambda forwarding.

- `stacked_multi_omic()`
  - Intended purpose: optimize omic weights for binary, regression, or multiclass predictions.
  - Current behavior after fix: binary labels are validated/coerced; missing predictions and missing binary/regression outcomes are skipped during scoring; multiclass probability matrices are shape-checked and row-normalized.
  - Tests: binary/regression performance parity, multiclass stacking, missing predictions, malformed multiclass labels, and new CRIT-001 tests.

### Metrics, plotting, exports, and data

- Metrics: `jaccard_similarity()`, `jaccard_matrix()`, `adjusted_similarity()`, `adjusted_similarity_values()`, `adjusted_similarity_measure()`, `pearson_similarity()`, `pearson_similarity_values()`, `pearson_similarity_measure()`, `fdr_similarity()`, `tpr_similarity()`, `fscore_similarity()`
  - Intended purpose: selection-set similarity and simulation recovery metrics.
  - Current behavior: matches frozen Python references for set-like inputs; duplicates are de-duplicated for set metrics.
  - Validation status: good for common edge cases; direct `d`/`nb_total_elements` validation could be clearer.
  - Tests: `test-phase7.R` and parity scalar fixtures.

- Plotting: `plot_stabl_path()`, `plot_fdr_graph()`, `plot_roc()`, `plot_prc()`, `boxplot_features()`, `scatterplot_features()`
  - Intended purpose: ggplot diagnostics and selected-feature visualizations.
  - Current behavior: optional `ggplot2` is checked at call time; FDR graph requires artificial-feature diagnostics.
  - Validation status: good for package presence and basic shape errors; ROC/PRC binary-label validation is minimal.
  - Tests: plotting class/error coverage in `test-phase7.R`.

- Export helpers: `export_stabl_to_csv()`, `save_stabl_results()`
  - Intended purpose: persist stability scores, selected features, and plots.
  - Current behavior: writes expected artifact schema and uses plotting helpers.
  - Validation status: good for object and path basics; depends on `ggplot2` through plot calls.
  - Tests: export file schema and directory conflict tests.

- `load_ool_data()`
  - Intended purpose: load bundled OOL train/validation example data.
  - Current behavior: intersects IDs and returns aligned numeric matrices and outcome vector.
  - Tests: covered indirectly by vignettes and examples; direct shape tests would be useful.

## Internal helper audit

Key internal helpers were source-inspected by subsystem:

- STABL internals: `.validate_stabl_params()`, `.resolve_sgl_feature_groups()`, `.build_corr_groups()`, `.append_noise_groups()`, `.with_local_seed()`.
- Bootstrap internals: `.bootstrap_strata_ids()`, `.subset_bootstrap_strata_by_ids()`, `.stratified_counts()`, `.stratified_bootstrap_indices()`, `.make_group_bootstrap_sampler()`, grouped stratified/unstratified samplers.
- Learner internals: coefficient extraction, bootstrap-threshold parser/resolver, batch adapter factories.
- Refit internals: `.fit_stabl_final_model()`, `.predict_stabl_final_model()`, selected-matrix/newdata validators.
- Multi-omic internals: fold builders, cooperative-fusion fit/predict/diagnostic helpers, OVR probability normalization, multiclass stacking helpers.
- MVR internals: PSD shifting/scaling, pure-R and Rcpp solvers, Gaussian knockoff producer.

No additional workflow-breaking internal defect was found beyond CRIT-001. Remaining `codetools` diagnostics are mostly style/design-level and should be handled as a separate cleanup tranche.

## Interoperability audit

Verified chains:

```r
fit <- stabl_fit(x, y, ...)
support <- get_support(fit)
features <- get_feature_names_out(fit)
scores <- get_stabl_scores(fit)
importances <- get_importances(fit)
plot <- plot_stabl_path(fit)
export_stabl_to_csv(fit, path)
```

Status: works in tests for gaussian, binomial, multinomial, Cox, hard-threshold, FDP+, artificial-feature, grouped, stratified, and mixed-alpha paths.

```r
fit <- stabl_refit(x, y, ...)
pred <- predict(fit, newdata)
```

Status: works in tests for gaussian, binomial, multinomial, Poisson, Cox, selected features, empty support, and invalid newdata schema.

```r
multi <- stabl_multiomic_train_validate(
  x_train_list, y_train,
  late_fusion = TRUE,
  family = "binomial"
)
lf <- multi$late_fusion
```

Status: fixed for factor outcomes through `stacked_multi_omic()` normalization. Regression tests now verify factor/numeric binary equivalence directly at the stacking layer.

```r
cv <- stabl_multiomic_cv(x_list, y, ...)
diagnostics <- cv$diagnostics
features <- get_cooperative_features(cv)
```

Status: works in tests for fold diagnostics and cooperative accessors when optional `multiview` is installed; tests skip cleanly otherwise.

```r
nested <- stabl_multiomic_nested_cv(x_list, y, ...)
perf <- nested$performance
features <- nested$selected_features
```

Status: works in nested-CV tests, including final-refit fallback and custom strata.

## Test coverage improvements

Added to `tests/testthat/test-audit-multiomic-workflows.R`:

- `AUDIT CRIT-001: binary stacking treats factor outcomes like 0/1 labels`
- `AUDIT CRIT-001: binary stacking rejects malformed outcome labels`
- `AUDIT CRIT-001: binary stacking skips missing outcomes after validation`

Existing coverage remains broad. Remaining gaps worth adding later:

- Direct invalid-input tests for `compute_fdp_plus()`, `auto_lambda_grid()`, `plot_roc()`, and `plot_prc()`.
- Direct shape/content tests for `load_ool_data()`.
- More direct tests for optional dependency absence paths under clean-library simulation.

## Recommended API changes

- Safe/backward-compatible: completed factor/character/logical binary outcome support in `stacked_multi_omic()`.
- Safe/backward-compatible: completed `.Rbuildignore` cleanup for analysis-only directories and hidden editor/tool directories.
- Safe/backward-compatible: completed removal of invalid DESCRIPTION URL.
- Backward-compatible future hardening: add direct validation for helper APIs that currently rely on backend errors.
- Deprecating: none recommended from this pass.
- Breaking: none recommended from this pass.

## Validation evidence

Commands run:

```r
devtools::document()
```

Result: completed. `NAMESPACE`, `stacked_multi_omic.Rd`, and `stabl_multiomic_nested_cv.Rd` are hand-maintained and were skipped by roxygen; `stacked_multi_omic.Rd` was updated manually to match source docs.

```r
testthat::test_file("tests/testthat/test-audit-multiomic-workflows.R")
testthat::test_file("tests/testthat/test-audit-performance-optimizations.R")
```

Result: both targeted files passed after the fix.

```r
Sys.setenv(NOT_CRAN = "true")
devtools::test(".", reporter = "summary")
```

Result: no failures; two existing `future` build-version warnings; two intentional native-candidate skips (`NAT-001`, `NAT-003`).

```r
lintr::lint_package()
```

Result: 847 lints, mostly pre-existing style issues across R files, tests, vignettes, and analysis scripts.

```r
devtools::load_all(".", quiet = TRUE)
codetools::checkUsageEnv(asNamespace("costablr"), all = TRUE)
```

Result: non-fatal usage diagnostics, mainly S3 generic placeholders, parameter reassignment, local closure bindings, and ggplot NSE symbols. `R CMD check` code/dependency checks are OK.

```r
requireNamespace("goodpractice", quietly = TRUE)
```

Result: `FALSE`; `goodpractice::gp()` could not be run in this environment.

```r
devtools::check(".", error_on = "never")
```

Result before build-ignore cleanup: `0 errors`, `1 warning`, `4 notes`; the warning/notes were packaging/toolchain hygiene, not test failures.

```r
rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "never")
```

Final result after build-ignore and DESCRIPTION cleanup: `0 errors`, `1 warning`, `3 notes`.

Remaining warning/note details:

- Warning: local `qpdf` is needed for PDF size-reduction checks.
- Note: CRAN incoming feasibility sees a new submission and dev version `0.0.0.9000`.
- Note: local conda toolchain uses non-portable `-march=nocona`.
- Note: `stabl_fit` example elapsed time was above 5 seconds in this environment.

## Final checklist

- [x] Every exported function inventoried
- [x] Every key internal helper family inspected
- [x] Every argument checked for actual use at the exported API level
- [x] Main function chains tested
- [x] Examples run during package checks
- [x] Documentation updated for changed behavior
- [x] R CMD check-equivalent checks run
- [x] No newly observed unused required arguments remain
- [ ] No undocumented return structures remain
- [ ] CRAN checks are warning/note clean
