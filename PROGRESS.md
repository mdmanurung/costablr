# PROGRESS: stablr Full R Port

## Document Role

This file is the execution log and validation record.

- Roadmap and phase intent are maintained in `PLAN.md`.
- Algorithm and parity semantics are maintained in `STABL.md`.

Logging rule:

- Record only completed work, observed results, and explicit gaps.
- Keep future intent and sequencing in `PLAN.md`.

## Status
1. Phase 1 (Spec + scaffolding): Complete
2. Phase 2 (Core contracts): Complete
3. Phase 3 (Core STABL engine): Complete
4. Phase 4 (Learner adapters): Complete
5. Phase 5 (Workflow layer): Complete
6. Phase 6 (Full glmnet compatibility): Complete
7. Phase 7 (Reporting + exports): Complete
8. Phase 8 (Hardening): Partial

## Completed Work (Mapped To Plan)

### Phase 1-2: Foundation

- Created R package scaffold under `r-pkg/stablr`.
- Implemented strict input alignment and validation helpers.
- Added tests for validator behavior.
- Added Python-to-R migration notes in `r-pkg/stablr/docs/PYTHON_TO_R_MAPPING.md`.

### Phase 3: Core STABL Engine

- Implemented artificial-feature generation (`R/artificial_features.R`), FDP+ control (`R/fdp_control.R`), and core fit loop (`R/stabl_fit.R`).
- Added glmnet learner adapter and lambda-grid support (`R/learner_adapters.R`).
- Implemented S3 accessors (`R/stabl_accessors.R`).
- Added core engine tests in `tests/testthat/test-stabl-fit.R`.

### Phase 4: Learner Adapters (Current)

- Added adaptive lasso adapter with ridge-initialized adaptive weights.
- Added sparse-group lasso adapter with explicit/correlation grouping and multinomial path.
- Added/updated tests for adaptive, multinomial, and sparse-group behavior.
- Updated package metadata/exports (`DESCRIPTION`, `NAMESPACE`).

### Documentation Integration

- Updated `STABL.md` to align with implemented Python/R semantics:
  - `artificial_proportion`, `sample_fraction`, strict `>` thresholding, FDP+ scaling, and core-fit output boundaries.
- Updated `AGENTS.md`, `PLAN.md`, and `PROGRESS.md` to enforce distinct roles and cross-references.
- Added root-level analysis memo `MultiView.md` summarizing cooperative-fusion implementation details and mapping concrete strengthening directions for `r-pkg/stablr` (cooperative middle-fusion mode, M-view agreement penalties, cooperative classification path, and STABL+cooperative hybrid workflow guidance).
- Re-audited `MultiView.md` against the then-available cooperative-learning source files and `r-pkg/stablr/R/multiomic_workflows.R`; corrected the `alpha = 0` interpretation to early-fusion-like behavior, clarified `lambda.min` vs `lambda.1se` function-level behavior, and added a simulated team design discussion capturing phased implementation and API naming constraints.
- Added a strict claim-labeling pass to `MultiView.md` with claim IDs C01-C23, each explicitly tagged as `Verified`, `Inference`, or `Proposal` and anchored to source functions/files. This creates a traceable boundary between code-backed statements and forward-looking recommendations.
- Converted the strict claim register in `MultiView.md` into a matrix format (ID, type, evidence anchor, confidence, action, priority) and added a focused documentation consistency review section to separate resolved vs open risks.
- Performed cross-document consistency cleanup between `PLAN.md` and `PROGRESS.md` by aligning objective/scope language to the current no-tidymodels direction.

### Documentation Optimization Pass (2026-05-04)

- Added root-level `HANDOFF.md` as the fresh-session bootstrap artifact with a hybrid format:
  - operator runbook (current state, next 3 tasks, commands, expected failure signals),
  - parity ledger (Python anchor -> R status -> evidence -> next action).
- Updated `AGENTS.md` documentation contract and update discipline to include `HANDOFF.md` as a required companion update.
- Updated `PLAN.md` with explicit strict parity gate policy, session bootstrap entrypoint guidance, and a dedicated cooperative-fusion experimental-track section.
- Rewrote `MultiView.md` to remove inactive source dependence and anchor all cooperative claims/actions to maintained `multiview/` sources.
- Standardized cooperative-fusion claim IDs to `MV01`-`MV10` with `Verified`/`Inference`/`Proposal` typing and direct implementation actions.
- Recorded cooperative-fusion track posture as experimental and non-parity-blocking while preserving strict per-phase test gates for any implemented tranche.

Validation notes for this pass:

- Scope: documentation-only optimization pass.
- Test command execution: not rerun in this pass (no R source or test code modified).

### Scope Update: Cooperative Fusion Source Consolidation (2026-05-04)

- Removed the standalone cooperative-learning archive directory (`cooperative-learning/`).
- Removed the root-level cooperative-learning integration memo (`CooperativeLearning.md`).
- Locked cooperative fusion source direction to the maintained `multiview/` implementation for future workflow planning.

### M2: Minimal R End-to-End Benchmark Path

- Added deterministic R smoke benchmark script at `r-pkg/stablr/scripts/run_smoke_stablr.R`.
- Script loads local package sources from `r-pkg/stablr/R`, fits `stabl_fit()` on synthetic data, and validates expected output contracts (`stabl_scores_` dimensions, threshold presence, support/importances bounds).
- Script prints concise summary fields (threshold, selected-feature count, top-ranked features) for quick local verification.

### M1: Adapter Usage Documentation Examples (2026-05-03)

- Added executable `stabl_fit()` roxygen examples in `r-pkg/stablr/R/stabl_fit.R` covering:
  - default lasso usage,
  - adaptive lasso (`base_learner = "adaptive_lasso"`),
  - sparse-group lasso (`base_learner = "sparse_group_lasso"`) with optional dependency guard,
  - multinomial fitting (`family = "multinomial"`).
- Added adapter roxygen `@details` notes in `r-pkg/stablr/R/learner_adapters.R` directing end users to `stabl_fit()` workflows rather than direct factory usage.
- Registered accessor/print S3 methods in `r-pkg/stablr/NAMESPACE` so examples run correctly in installed-namespace mode (`S3method(get_support, stabl_fit)`, `S3method(get_feature_names_out, stabl_fit)`, `S3method(get_importances, stabl_fit)`, `S3method(get_stabl_scores, stabl_fit)`, `S3method(print, stabl_fit)`).
- Regenerated documentation with `devtools::document('r-pkg/stablr')`.

### M1: Grouped Longitudinal Leakage Tests (2026-05-03)

- Added grouped longitudinal leakage-focused tests in `r-pkg/stablr/tests/testthat/test-bootstrap-helpers.R`.
- Added a grouped-sampling test that verifies whole-group selection is preserved when `n_subsamples` aligns with repeated-measures group size.
- Added an ungrouped-sampling test that verifies classical bootstrap can partially sample repeated-measures groups, capturing leakage risk when `groups` are not provided.

### Scope Update: Local Validation Only (2026-05-03)

- User-directed scope refinement recorded: do not implement CI in this workspace.
- Validation path for current work is local R test suites only.

### M3: Minimal Multi-Omic Workflow Slice (2026-05-03)

- Added `stabl_multiomic_train_validate()` in `r-pkg/stablr/R/multiomic_workflows.R` as a first train/validation orchestration path.
- Implemented per-omic orchestration over named multi-omic inputs with:
  - strict training sample alignment validation via `validate_multiomic_inputs()`,
  - optional validation alignment checks with explicit error paths,
  - leakage-safe grouped handling by forwarding `groups_train` to each per-omic `stabl_fit()` call,
  - per-omic outputs for fitted models, selected feature names, and selected train/validation matrices.
- Added workflow tests in `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` covering:
  - successful two-omic orchestration path,
  - explicit failures for training misalignment,
  - explicit failures for validation omic-name mismatch,
  - explicit failures for validation sample misalignment.
- Exported the new API in `r-pkg/stablr/NAMESPACE` and generated documentation `r-pkg/stablr/man/stabl_multiomic_train_validate.Rd`.

### M3: Minimal Multi-Omic CV Slice (2026-05-03)

- Added `stabl_multiomic_cv()` in `r-pkg/stablr/R/multiomic_workflows.R` as the first cross-validation orchestration path for the R workflow layer.
- Implemented deterministic internal fold generation with optional group-aware assignment so repeated-measures groups stay within the same assessment fold.
- Reused `stabl_multiomic_train_validate()` per fold to keep Phase 5 aligned with the current workflow boundary: feature selection and selected matrices only, with no downstream predictive refit.
- Added fold-level diagnostics capturing per-fold/per-omic selected-feature counts, effective thresholds, and max stability scores.
- Added workflow tests in `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` covering:
  - deterministic fold coverage across all samples,
  - grouped fold isolation without leakage,
  - explicit failure when requested folds exceed grouped units.
- Exported the new API in `r-pkg/stablr/NAMESPACE` and added manual documentation `r-pkg/stablr/man/stabl_multiomic_cv.Rd`.

### M4: Phase 5 Completion — Early Fusion, Late Fusion, Stacked Generalization (2026-05-03)

- Added `stacked_multi_omic()` in `r-pkg/stablr/R/multiomic_workflows.R`, a direct R port of Python's `stacked_multi_omic` from `stabl/stacked_generalization.py`.
  - Random-weight search (n_iter draws from Uniform(0, 10)) with NA-per-row handling.
  - AUC optimisation for binary tasks (Wilcoxon rank-sum, no external dependencies).
  - R² optimisation for regression tasks.
  - Optional `random_state` for reproducible weight search.
  - Exported and documented in `man/stacked_multi_omic.Rd`.
- Added internal helpers `.r_auc()`, `.r_squared()`, `.family_to_task_type()`, `.late_fusion_fit_omic()`.
- Extended `stabl_multiomic_train_validate()` with three new parameters:
  - `early_fusion = FALSE`: cbind all omic matrices → single `stabl_fit()` run; result in `$early_fusion` field.
  - `late_fusion = FALSE`: per-omic downstream GLM/LM on selected features → `stacked_multi_omic()` → stacked ensemble; result in `$late_fusion` field.
  - `n_iter_lf = 10000L`: passed to `stacked_multi_omic()` for the late-fusion weight search.
  - Return value extended: `early_fusion` and `late_fusion` list slots added to `stabl_multiomic_fit` objects.
- Extended `stabl_multiomic_cv()` to pass `early_fusion`, `late_fusion`, `n_iter_lf` through to each per-fold call.
- Added 12 new tests in `test-multiomic-workflows.R` covering:
  - `stacked_multi_omic` structure, regression/binary scoring, reproducibility, and NA-per-row handling.
  - Early fusion structure, validation population, and FALSE-guard.
  - Late fusion structure, validation predictions vector, and FALSE-guard.

### M5: Phase 6 Tranche A — Cox + Multi-Omic Ergonomics (2026-05-04)

- Added Cox-family support path for glmnet-based STABL adapters:
  - Updated coefficient extraction internals to handle Cox coefficient shape (no intercept row).
  - Propagated family-aware extraction through single-lambda and batch adapters.
  - Added explicit guardrails rejecting `family = "cox"` for sparse-group adapters with actionable error messages.
- Extended outcome-alignment contracts to support matrix-like outcomes (including `survival::Surv`) by row-name alignment.
  - Added internal helpers in `R/input_validation.R` for sample-id extraction and robust outcome subsetting.
  - Updated `stabl_fit()` alignment path to use shared outcome subsetting helper.
- Added multi-omic print ergonomics:
  - Implemented `print.stabl_multiomic_fit` and `print.stabl_multiomic_cv`.
  - Registered new S3 methods in `r-pkg/stablr/NAMESPACE`.
- Added/updated tests:
  - `test-stabl-fit.R`: Cox Surv run-path test and sparse-group Cox rejection test.
  - `test-multiomic-workflows.R`: print-method smoke tests for `stabl_multiomic_fit` and `stabl_multiomic_cv`.

### M6: Phase 6 Tranche B — Cox/Mixed-Alpha Coverage Hardening (2026-05-04)

- Added focused test coverage in `r-pkg/stablr/tests/testthat/test-stabl-fit.R` for remaining Phase 6 structural gaps:
  - `auto_lambda_grid()` with `family = "cox"` and mixed `l1_ratio` values now explicitly validated for expected `alpha`/`lambda` columns and row cardinality.
  - `stabl_fit()` with `base_learner = "elastic_net"`, `family = "cox"`, and mixed-alpha lambda grids now explicitly validated for shape/path consumption (`stabl_scores_` columns and `fitted_lambda_grid` alignment).
- Added warning suppression in the mixed-alpha Cox structural test for expected glmnet numerical warnings at tiny lambda values in small bootstrap samples.

### M7: Phase 6 Tranche C — Non-Cox Structural Parity Coverage (2026-05-04)

- Added focused mixed-alpha structural coverage tests in `r-pkg/stablr/tests/testthat/test-stabl-fit.R` for non-Cox families:
  - `auto_lambda_grid()` with `family = "multinomial"` and mixed `l1_ratio` values now explicitly validated for expected `alpha`/`lambda` columns, row cardinality, and positive finite lambda values.
  - `auto_lambda_grid()` with `family = "binomial"` and mixed `l1_ratio` values now explicitly validated for expected `alpha`/`lambda` columns, row cardinality, and positive finite lambda values.
- Added deterministic structural parity tests (fixed `random_state`) for adapter/family combinations aligned to tranche scope:
  - `elastic_net` with `family = "multinomial"` and mixed-alpha lambda grids validates `stabl_scores_` dimensions, `fitted_lambda_grid` row alignment, alpha propagation, and identical repeated-fit stability scores.
  - `adaptive_lasso` with `family = "binomial"` and mixed-alpha lambda grids validates `stabl_scores_` dimensions, `fitted_lambda_grid` row alignment, alpha propagation, and identical repeated-fit stability scores.
  - `lasso` with `family = "gaussian"` and mixed-alpha lambda grids validates `stabl_scores_` dimensions, `fitted_lambda_grid` row alignment, alpha propagation, and identical repeated-fit stability scores.

### M8: Phase 6 Edge-Regime Coverage + Cooperative RFC Checklist (2026-05-04)

- Added focused edge-regime parity tests in `r-pkg/stablr/tests/testthat/test-stabl-fit.R` for:
  - high-collinearity gaussian lasso regime with deterministic repeated-fit checks,
  - near-zero lambda tail behavior for elastic-net path consumption with mixed alpha grids,
  - class-imbalance binomial regime with deterministic repeated-fit checks and bounded stability/FDP threshold assertions.
- Added a cooperative-fusion RFC checklist section to `MultiView.md` mapping proposal claims `MV08`-`MV10` into explicit staged gates (`CF-RFC-00` to `CF-RFC-02`) with strict parity-test closure criteria.

## Latest Validation Snapshot

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 247`, `FAIL 0`, `WARN 0`, `SKIP 0` (Phase 7 complete: metrics, exports, visualization + 53 new tests).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'stabl-fit')"`
- Result: `PASS 121`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes Phase 6 behavior-level parity tests for multinomial and Cox).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 155`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes Phase 6 Tranche C non-Cox structural parity tests).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'stabl-fit')"`
- Result: `PASS 82`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes full `stabl_fit` structural parity matrix coverage).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 128`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes Phase 6 Tranche B Cox/mixed-alpha coverage tests).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 118`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes Phase 6 Cox tranche + multi-omic print-method tests).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 113`, `FAIL 0`, `WARN 0`, `SKIP 0` (M4 complete: early fusion, late fusion, stacked generalization).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 53`, `FAIL 0`, `WARN 0`, `SKIP 0` (local-only validation scope confirmation).

- Command: `conda run -n R4_51 Rscript -e "devtools::run_examples('r-pkg/stablr', fresh = TRUE)"`
- Result: completed successfully; new `stabl_fit` examples executed for lasso, adaptive lasso, sparse-group (guarded by `requireNamespace('sparsegl')`), and multinomial paths.
- Command: `conda run -n R4_51 Rscript -e "devtools::document('r-pkg/stablr')"`
- Result: completed successfully; generated `stabl_multiomic_train_validate.Rd` (NAMESPACE intentionally not regenerated).
- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 64`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes new multi-omic workflow tests).
- Command: `conda run -n R4_51 Rscript "r-pkg/stablr/scripts/run_smoke_stablr.R"`
- Result: completed successfully with deterministic smoke output (`selected_features: 3`; `top_features: f1, f2, f3, f14, f6`; `fdr_min_threshold: 0.8500`).
- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"`
- Result: `PASS 28`, `FAIL 0`, `WARN 0`, `SKIP 0` after adding the multi-omic CV workflow.
- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 81`, `FAIL 0`, `WARN 0`, `SKIP 0`.

### M9: Phase 6 Behavior-Level Parity Tests — Multinomial + Cox (2026-05-04)

- Added 8 behavior-level parity tests to `r-pkg/stablr/tests/testthat/test-stabl-fit.R`:
  - `multinomial lasso detects true class-separating signal features` — fixture with planted predictors; asserts signal features have higher mean stability than noise.
  - `multinomial lasso is deterministic across repeated calls` — same `random_state` → identical `stabl_scores_`.
  - `multinomial adaptive_lasso is deterministic and bounded` — scores bounded to [0, 1].
  - `cox lasso detects true survival-signal feature` — exponential survival fixture with `beta_true = 1.5`; asserts f1 mean stability > noise mean.
  - `cox lasso is deterministic across repeated calls`.
  - `cox adaptive_lasso is deterministic and bounded`.
  - `cox elastic_net mixed-alpha is deterministic and bounded` — validates alpha column presence in `fitted_lambda_grid`.
  - `multinomial high-collinearity regime is deterministic and bounded`.
- Added `fdr_threshold_range` field to the `stabl_fit` S3 object in `R/stabl_fit.R` to support `plot_fdr_graph`.
- Test filter result: `PASS 121`, `FAIL 0`, `WARN 0`, `SKIP 0`.

### M10: Phase 7 — Metrics, Exports, Visualization (2026-05-04)

**metrics.R** (`r-pkg/stablr/R/metrics.R`):
- Full R port of `stabl/metrics.py`.
- Exported functions: `jaccard_similarity`, `jaccard_matrix`, `adjusted_similarity`, `adjusted_similarity_values`, `adjusted_similarity_measure`, `pearson_similarity`, `pearson_similarity_values`, `pearson_similarity_measure`, `fdr_similarity`, `tpr_similarity`, `fscore_similarity`.
- Internal helper: `.similarity_summary(vals, stat)`.

**exports.R** (`r-pkg/stablr/R/exports.R`):
- R port of `export_stabl_to_csv()` and `save_stabl_results()` from `stabl/stabl.py`.
- `export_stabl_to_csv(object, path)`: writes stability score CSVs (real + artificial).
- `save_stabl_results(object, path, x, y, ...)`: orchestrates full export — CSVs, stability path, FDR graph, selected-feature distribution plots.

**visualization.R** (`r-pkg/stablr/R/visualization.R`):
- R port of plot functions from `stabl/stabl.py` and `stabl/visualization.py` using ggplot2.
- Exported functions: `plot_stabl_path`, `plot_fdr_graph`, `plot_roc`, `plot_prc`, `boxplot_features`, `scatterplot_features`.
- Color palette matches Python STABL defaults (cardinal red for selected, dark grey for noise, grey for artificial).

**Registration and tests**:
- NAMESPACE updated with all 19 new exports.
- DESCRIPTION Suggests updated to include `ggplot2` and `survival`.
- 53 new tests in `r-pkg/stablr/tests/testthat/test-phase7.R` covering metrics edge cases, CSV file creation, directory structure, ggplot object return types, and error paths.
- Full suite result: `PASS 247`, `FAIL 0`, `WARN 0`, `SKIP 0`.

## Traceability To Active Plan Deliverables
- R smoke benchmark script added and documented: complete (`r-pkg/stablr/scripts/run_smoke_stablr.R`).
- Adapter usage documentation examples added: complete (`r-pkg/stablr/R/stabl_fit.R`, `r-pkg/stablr/R/learner_adapters.R`).
- Sparsegl-enabled CI job added: deferred in this workspace (local validation scope).
- Fresh-session bootstrap artifact added: complete (`HANDOFF.md`).

## Previously Completed Discovery
- Reviewed architecture and behavior of:
  - `stabl/stabl.py`
  - `stabl/multi_omic_pipelines.py`
  - `stabl/preprocessing.py`
  - `stabl/pipelines_utils.py`
  - `stabl/stacked_generalization.py`
  - `stabl/adaptive.py`
  - `stabl/data.py`
- Locked major product decisions (pure R, model-first, full glmnet compatibility target, strict alignment, tolerance-based parity).

### Core Engine Optimization (2026-05-03)

- Restructured main bootstrap loop in `stabl_fit.R` from lambda-outer/bootstrap-inner to **bootstrap-outer**: each bootstrap now calls the learner adapter once with the full lambda grid, reducing model fits from `n_bootstraps × n_lambdas` to `n_bootstraps` (e.g. 1 000 × 30 → 1 000 for default settings).
- Added internal batch adapter factories in `learner_adapters.R`: `.make_glmnet_batch_adapter`, `.make_adaptive_lasso_batch_adapter`, `.make_sgl_batch_adapter`. Each returns a `function(x, y, lambda_grid) → logical matrix (n_features × n_lambdas)`.
- Added `.feature_abs_coefs_batch` and `.feature_abs_coefs_sparsegl_batch` helpers using per-lambda coefficient lookup on the single warm-start fitted path.
- Vectorized `compute_fdp_plus` in `fdp_control.R`: replaced `vapply` threshold loops with `outer()` + `colSums`, eliminating the inner loop over the threshold grid.
- Fixed latent sparsegl bug: `make_sgl_adapter` and `.make_sgl_batch_adapter` now sort features by group index before calling `sparsegl::sparsegl()` (which requires monotone non-decreasing groups) and remap coefficients back to original column order. This unmasked 6 previously-skipped SGL tests which now pass.
- Phase 4 hardening: close adapter docs, grouped longitudinal leakage tests, and sparsegl-enabled CI execution.

## In Progress

- CI implementation is intentionally deferred in this workspace by user request.
- Local test-suite validation remains green and is the active hardening path.

## Next Actions
1. Continue Phase 6 (full glmnet compatibility): close remaining coefficient/path extraction parity checks across adapter types beyond structural coverage.
2. Add targeted parity tests for coefficient-path behavior under edge regimes (high collinearity, near-zero lambda tails, and class-imbalance stress cases).

### Scope Decision (2026-05-03)
- Tidymodels integration (Phase 6 original plan) is **dropped**. No `parsnip`, `recipes`, `tune`, `workflows`, or `yardstick` dependencies will be introduced.
- Phase 6 is now **full glmnet compatibility**: complete family coverage, coefficient/path extraction parity, and lambda-grid convention alignment across all adapters.

## Risks To Track
- Cross-backend differences for adaptive/sparse-group/knockoff behavior.
- Scope pressure from remaining Phase 6 compatibility work (family/alpha conventions and coefficient-path parity coverage).

## Environment Notes
- R runtime is available via conda environment `R4_51`.
- Validation command used in this workspace: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`.
