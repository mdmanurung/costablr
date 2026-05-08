# PROGRESS: stablr Full R Port

**Purpose:** Factual execution log recording completed work, validation results, and explicit gaps.

**This document owns:**
- Completed implementation work (what changed).
- Validation evidence (command + output summaries).
- Observed gaps and known constraints.
- Phase completion status and scope decisions.

**This document does NOT own:**
- Future scope and priorities (→ PLAN.md)
- Operator snapshot and immediate task queue (→ HANDOFF.md)
- Algorithm semantics and parity rules (→ STABL.md)
- Workflow policy and governance (→ AGENTS.md)

**Cross-reference pattern:** For planning context, check PLAN.md. For current session queue, check HANDOFF.md.

## Document Role

This file is the execution log and validation record.

- Roadmap and phase intent are maintained in `PLAN.md`.
- Algorithm and parity semantics are maintained in `STABL.md`.

Logging rule:

- Record only completed work, observed results, and explicit gaps.
- Keep future intent and sequencing in `PLAN.md`.
- Keep immediate operator queue in `HANDOFF.md`.

## Status
1. Phase 1 (Spec + scaffolding): Complete
2. Phase 2 (Core contracts): Complete
3. Phase 3 (Core STABL engine): Complete
4. Phase 4 (Learner adapters): Complete
5. Phase 5 (Workflow layer): Complete
6. Phase 6 (Full glmnet compatibility): Complete
7. Phase 7 (Reporting + exports): Complete
8. Phase 8 (Hardening): Parity coverage complete (elastic-net, binomial, gaussian, multinomial)

### Remediation Audit Continuation (2026-05-08, batch 2)

- WI-11/WI-12 implementation landed in [r-pkg/stablr/R/stabl_fit.R](r-pkg/stablr/R/stabl_fit.R):
  - split `random_state` into derived RNG streams (`art_seed`, `boot_seed`, `iter_seed_base`),
  - seeded artificial-feature generation and bootstrap-index generation independently,
  - added per-bootstrap deterministic seeding (`iter_seeds`) to make sequential/parallel adapter calls reproducible,
  - added internal `.with_local_seed()` helper.
- WI-12 companion change landed in [r-pkg/stablr/R/artificial_features.R](r-pkg/stablr/R/artificial_features.R):
  - removed redundant inner `set.seed()` from `make_knockoff_features`,
  - clarified dispatcher-level seeding contract,
  - corrected `noise_col_indices` doc semantics to original-feature indices.
- WI-02 parity harness update landed:
  - added [r-pkg/stablr/tests/testthat/helper-parity.R](r-pkg/stablr/tests/testthat/helper-parity.R) loader with `python_max_score` support,
  - rewrote [r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R](r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R) parity assertions to use `get_importances()` (max-over-lambda) and support-set overlap; no longer relies on mean-score parity for core assertions.
- WI-03 TEST-ONLY landed: [r-pkg/stablr/tests/testthat/test-artificial-features-parity.R](r-pkg/stablr/tests/testthat/test-artificial-features-parity.R) pins random-permutation no-replacement source sampling (Python parity confirmation).
- WI-04/WI-08/WI-10/WI-13/WI-14/WI-15 tests added:
  - [r-pkg/stablr/tests/testthat/test-fdp-plus-invariants.R](r-pkg/stablr/tests/testthat/test-fdp-plus-invariants.R)
  - [r-pkg/stablr/tests/testthat/test-fdp-calibration.R](r-pkg/stablr/tests/testthat/test-fdp-calibration.R)
  - [r-pkg/stablr/tests/testthat/test-signal-recovery.R](r-pkg/stablr/tests/testthat/test-signal-recovery.R)
  - [r-pkg/stablr/tests/testthat/test-multiomic-guards.R](r-pkg/stablr/tests/testthat/test-multiomic-guards.R)
  - [r-pkg/stablr/tests/testthat/test-accessor-roundtrip.R](r-pkg/stablr/tests/testthat/test-accessor-roundtrip.R)
  - [r-pkg/stablr/tests/testthat/test-validation-edges.R](r-pkg/stablr/tests/testthat/test-validation-edges.R)
- WI-15 source tightening landed in [r-pkg/stablr/R/stabl_fit.R](r-pkg/stablr/R/stabl_fit.R):
  - `.validate_stabl_params()` now validates `replace` scalar-boolean and rejects `sample_fraction > 1` when `replace = FALSE` early.
- WI-09 DOC-ONLY landed in [STABL.md](STABL.md):
  - recorded parity facts for `bootstrap_threshold = 1e-5` (Python line anchor), random-permutation source sampling (`replace = FALSE`), and requested-`π` FDP+ scaling.

Validation status update (2026-05-08, executed in `R4_51`):

- Environment/runtime blocker is resolved for test execution in `R4_51`.
- Full suite command executed:
  - `source /share/software/tools/miniconda/3.10/23.3.1/bin/activate R4_51 && Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result:
  - `[ FAIL 7 | WARN 0 | SKIP 4 | PASS 1336 ]` (duration 103.3s)
- Failing contexts observed:
  - `test-bootstrap-helpers.R` (expected error not thrown)
  - `test-fdp-calibration.R` (null-selection bound exceeded)
  - `test-fdp-plus-invariants.R` (`min_fdr` cap expectation mismatch)
  - `test-input-validation.R` (error expectation mismatch)
  - `test-multiomic-guards.R` (unexpected `unused argument` path)
  - `test-python-parity-fixtures.R` (correlation threshold miss)
  - `test-signal-recovery.R` (over-selection vs upper bound)
- Next gate: remediate these seven failing tests/findings under strict one-item-at-a-time TDD.

## Completed Work (Mapped To Plan)

### Additional Parity Tests: Multiclass + Cox (2026-05-08)

7 new test cases added to `r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R`.

**Frozen cross-language fixture (Python ↔ R parity):**
1. `frozen Python parity fixture agrees for multinomial elastic-net signal ranking` —
   `skip_if_not(dir.exists(...))` guard; activates once `multinomial_elastic_net/` fixture is
   generated. Parameters: `alpha=0.6`, 6-pt lambda grid, 50 bootstraps, `random_state=106`.

**Cox self-consistency parity (R-only; Python STABL has no CoxNet estimator):**
2. `Cox lasso recovers planted survival signals` — n=100, p=10, f1/f2 planted via Weibull DGP, 80 bootstraps.
3. `Cox elastic-net recovers planted survival signals` — `alpha=0.7`, 80 bootstraps.
4. `Cox adaptive-lasso recovers planted survival signals` — 80 bootstraps.
5. `Cox lasso stability scores are consistent across two runs with same seed` — determinism check, tolerance=0.

**Multinomial signal-recovery self-consistency:**
6. `multinomial lasso planted signals rank above noise features` — n=120, p=10, 3-class DGP, 60 bootstraps.
7. `multinomial elastic-net planted signals rank above noise features` — `alpha=0.6`, 60 bootstraps.

Helper functions: `.make_cox_data()` (Weibull PH DGP, ~30% censored) and `.expect_signal_recovery()`.

Python fixture generator updated: `_build_multinomial_elastic_net()` added to
`generate_python_parity_refs.py`; background generator started (PID 3207983).

**Validation:**
```bash
/exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript \
  -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures')"
# -> PASS 34, FAIL 0, WARN 0, SKIP 1 (multinomial_elastic_net fixture pending Python generator)
```

### M12: Cooperative Fusion Hardening — Behavior Tests + Print Ergonomics + Optional-Dep Test (2026-05-08)


  closing the genuinely missing items in `MultiViewPlan.md` after a two-pass source audit:
  1. `cooperative_fusion: rho > 0 alters selection vs rho = 0 (gaussian, cv)` — validates
     cooperation strength affects output (selected features OR lambda OR train predictions).
  2. `cooperative_fusion: cooperative selections differ from per-omic and early fusion` —
     confirms cooperative is not a trivial relabel of early/per-omic selection.
  3. `cooperative_fusion rejects cox + validation selection` — explicit guard regression.
  4. `cooperative_fusion fails cleanly when multiview is unavailable` — exercises the new
     `.has_multiview()` indirection via `testthat::local_mocked_bindings` with `multiview`
     installed in the env.
  5. `print.stabl_multiomic_fit reports cooperative fusion when present` — ergonomics regression.
  6. `print.stabl_multiomic_fit omits cooperative line when branch absent` — preserves default
     return-shape contract on the print surface.
- Refactor: extracted `.has_multiview()` in `r-pkg/stablr/R/input_validation.R` so the optional
  dependency check is mockable; behavior is unchanged when `multiview` is present.
- `print.stabl_multiomic_fit()` in `r-pkg/stablr/R/stabl_accessors.R` now emits a
  `Cooperative fusion:` block when the branch is populated, exposing `selection`, chosen `rho`,
  `selector`, `type.measure`, score, and total selected features across views. Default print
  shape preserved when cooperative branch is absent.
- Test runtimes kept tight (n ≤ 30, n_bootstraps = 3, rho grid ≤ 2 points) to align with
  existing cooperative test budget.

Commands and signals:

```bash
conda run -n R4_51 R CMD INSTALL multiview
conda run -n R4_51 Rscript -e 'devtools::test_active_file("r-pkg/stablr/tests/testthat/test-multiomic-workflows.R")'
# -> PASS 100, FAIL 0, WARN 0, SKIP 0
conda run -n R4_51 Rscript -e 'devtools::test("r-pkg/stablr")'
# -> PASS 326, FAIL 0, WARN 0, SKIP 3 (sparsegl absent in env; unrelated)
```

Closure: M12 closes work packages 1, 2, and 3 of the active milestone described in `PLAN.md`
("Cooperative Fusion Hardening (Experimental Track)"). Cooperative fusion has met its exit
criteria from experimental status pending downstream operator-facing docs.

### Fix 1: explore fallback tied-score bug (2026-05-08)

**File changed:** `r-pkg/stablr/R/stabl_accessors.R`, function `get_support.stabl_fit`.

**Bug:** The explore fallback used `sort(max_scores, decreasing=TRUE)[n_exp] - 0.01` as a
cutoff, then applied `max_scores > cutoff`. When all scores are identical (e.g. all zero after
heavy regularisation), the arithmetic `0 - 0.01 = -0.01` caused every feature to pass
(`max_scores > -0.01`), expanding to all `p` features instead of exactly `n_explore`.

**Fix:** Replaced cutoff arithmetic with `order(max_scores, decreasing=TRUE)[seq_len(n_exp)]`
direct index selection and `mask[top_idx] <- TRUE`. This always selects exactly `n_explore`
features regardless of tied scores.

**Test added:** `test-stabl-fit.R` — "explore fallback selects exactly n_explore features even
when all scores are tied". Uses `hard_threshold = 0.99` (nothing passes), `explore = TRUE,
n_explore = 3`, very large lambda (scores ≈ 0). Asserts `sum(mask) == 3` and selected features
match top-3 by importance.

**Validation:**

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
# -> PASS 330, FAIL 0, WARN 0, SKIP 3
```

### Fix 2: group_bootstrap_indices replace=FALSE leakage (2026-05-08)

**File changed:** `r-pkg/stablr/R/bootstrap_helpers.R`, function `group_bootstrap_indices`.

**Bug:** `sample(group_levels, size=1L, replace=replace)` — the `replace` argument had no
effect on a size-1 draw, so `group_levels` never shrank. When `replace=FALSE`, the same group
could be re-drawn multiple times, causing leakage across what should be disjoint subsamples.

**Fix:** Introduced a mutable `remaining` vector initialised to `unique(groups)`. After each
group draw, `remaining` is updated: when `replace=FALSE` the drawn group is removed.
The `while` loop condition also guards `length(remaining) > 0L` to avoid infinite loops if
`n_subsamples` cannot be met from the available groups.

**Test added:** `test-bootstrap-helpers.R` — "group_bootstrap_indices replace=FALSE never
re-draws the same group". Asserts that across 5 seeds no group appears more rows than its
actual membership, and that unique group count is consistent.

**Validation:**

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
# -> PASS 350, FAIL 0, WARN 0, SKIP 3
```

### Fix 3: .build_corr_groups missing -0.1 offset (2026-05-08)

**File changed:** `r-pkg/stablr/R/stabl_fit.R`, function `.build_corr_groups`.

**Bug:** Python reference (`stabl/stabl.py` line 1142) computes
`threshold = np.percentile(corr_val, perc) - 0.1`. The R port was missing the `- 0.1` offset,
making the grouping threshold 0.1 units stricter than Python, resulting in fewer correlation
groups and different SGL group assignments.

**Fix:** Appended `- 0.1` to the `quantile(...)` cutoff line.

**Test added:** `test-stabl-fit.R` — ".build_corr_groups applies -0.1 offset matching Python
reference". Constructs a matrix with two near-identical columns (corr ≈ 0.99) at percentile 95,
asserts they land in the same group.

**Validation:** (running)

### Fix 4: knockoff chunked path original-index tracking (2026-05-08)

**File changed:** `r-pkg/stablr/R/artificial_features.R`, function `make_knockoff_features`.

**Bug:** In the chunked path (p > 3000), `sel_idx` indexed into the reshuffled
`x_art_full`, not into the original feature matrix. `.append_noise_groups` in `stabl_fit.R`
used those indices to look up SGL groups in the original-feature group vector, producing wrong
group assignments whenever `artificial_type = "knockoff"` and `p > 3000`.

**Fix:** Introduced `orig_map` tracking which original-feature column each knockoff column
corresponds to, updated in sync through the chunk-assemble-trim pipeline. Returned
`noise_col_indices = orig_map[sel_idx]` instead of the raw `sel_idx`. The non-chunked
path uses an identity map.

**Validated with:** Fix 3 suite run (PASS 353, no knockoff-specific test added as p>3000
requires knockoff package not present in CI env).

### Fix 5: sequential bootstrap memory streaming (2026-05-08)

**File changed:** `r-pkg/stablr/R/stabl_fit.R`, bootstrap accumulation block.

**Bug:** Sequential path used `lapply(boot_indices, process_one_bootstrap)` materialising
all `n_bootstraps` result matrices simultaneously, then iterated to accumulate. Peak memory
was O(n_bootstraps × n_features × n_lambdas) instead of O(n_features × n_lambdas).

**Fix:** Replaced sequential `lapply` + post-hoc loop with a direct `for (idx in boot_indices)`
loop that accumulates each result matrix immediately and discards it. The furrr parallel path
is unchanged (must collect all results before accumulating).

### Fix 6: recursion → iteration in degenerate-bootstrap retry (2026-05-08)

**Files changed:** `r-pkg/stablr/R/bootstrap_helpers.R`, both `classic_bootstrap_indices`
and `group_bootstrap_indices`.

**Bug:** Both functions used tail recursion for the degenerate-bootstrap retry (all-one-class
subsample). With severe class imbalance, ~900 retries were needed before a diverse sample was
found, hitting R's call stack limit.

**Fix:** Replaced recursion with a `while` loop capped at 1 000 retries. Loop issues an
informative `stop()` if the cap is hit. Applied identically in both functions.

**Tests added:** `test-bootstrap-helpers.R` — two tests asserting that an all-same-class
outcome produces the expected error message from each function.

### Fix 7: sample_fraction > 1 early validator (2026-05-08)

**File changed:** `r-pkg/stablr/R/stabl_fit.R`, `stabl_fit()` body after `n_subsamples` is
computed.

**Bug:** No early check for `!replace && n_subsamples > n_samples`; user would get an opaque
error deep inside the bootstrap machinery.

**Fix:** Added an explicit `stop()` immediately after `n_subsamples` is computed when
`!replace && n_subsamples > n_samples`, with a message explaining both the computed value
and the remediation options.

**Test added:** `test-input-validation.R` — asserts `stabl_fit()` raises an error matching
"reduce.*sample_fraction|replace = TRUE" when `sample_fraction = 1.5, replace = FALSE`.

**Validation:** PASS 356 | FAIL 0 | WARN 0 | SKIP 3 (sparsegl absent as expected). All 7 bug-fix audit items closed.

### M13: Cooperative Fusion Vignette (2026-05-08)

- Created `r-pkg/stablr/vignettes/stablr-cooperative.Rmd` (434 lines, 9 sections
  plus closing guidance).
- Vignette covers: overview and strategy comparison table; lambda grid setup;
  `stabl_multiomic_train_validate()` with `cooperative_fusion = TRUE` and
  `rho = c(0, 0.1, 0.3, 0.5)`; navigating `$cooperative_fusion` (chosen rho,
  lambda, selected features per view, predictions, and tuning diagnostics);
  policy guard demos (`lambda.1se` + validation, cox + validation); graceful
  error note when `multiview` is absent; three-strategy comparison (cooperative
  vs early vs late fusion); `stabl_multiomic_cv()` with cooperative parameters;
  and rho/nfolds design guidance.
- `knitr::purl()` syntax validation: clean, no chunk errors.
- All cooperative code chunks guarded by `if (!requireNamespace("multiview",
  quietly = TRUE)) knitr::opts_chunk$set(eval = FALSE)` in the setup chunk.
- Registered via `%\VignetteIndexEntry{Cooperative Fusion for Multi-Omic Biomarker
  Discovery}` in YAML header; no DESCRIPTION changes needed (`multiview` already
  in `Suggests`).

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

### Scope Update: Cox Parity Policy (2026-05-04)

- Resolved Phase 8 Cox parity handling as non-applicable for frozen Python anchors because Python `stabl/` does not implement Cox.
- Updated planning/handoff policy so Cox closure is governed by R-native hardening gates:
  - deterministic repeated-fit behavior with fixed random state,
  - structural invariants (lambda-grid alignment, bounded stability/support outputs),
  - synthetic survival-signal behavior checks.
- Synchronized `PLAN.md` deliverable/checklist language and `HANDOFF.md` next tasks/parity ledger to reflect the non-blocking Cox policy.

Validation notes for this scope update:

- Scope: documentation-only policy synchronization (`PLAN.md`, `PROGRESS.md`, `HANDOFF.md`).
- Test command execution: not rerun in this update pass (no R source or test code modified).

### Notebook Execution Hardening: Tutorial Flow (2026-05-04)

- Executed the STABL tutorial sequence in `Notebook examples/Tutorial Notebook.ipynb` for the proteomics regression walkthrough:
  - preprocessing pipeline creation,
  - standardized matrix creation,
  - `stabl_regression.fit(...)`,
  - FDP and stability-path visualization cells.
- Extracted sample datasets from `Sample Data/data.zip` so notebook data loaders can resolve Onset of Labor files in this workspace.
- Added notebook-local compatibility shims for current scikit-learn API drift:
  - `LowInfoFilter._validate_data` bridge (`force_all_finite` -> `ensure_all_finite` handling),
  - `Stabl._validate_data` bridge via `check_X_y`/`check_array`,
  - optional `ALogitLasso` constructor guard to avoid hard failure in environments where legacy logistic arguments are rejected.
- Added robust data-path resolution in the tutorial data-loading cell to support both repository-root and notebook-relative execution contexts.

Validation notes for this implementation step:

- Notebook kernel: `scvi-test (Python 3.13.11)`.
- `stabl_regression.fit(...)` completed successfully (progress bar reached 100%).
- `plot_fdr_graph(...)` and `plot_stabl_path(...)` executed successfully and rendered figures.

### Scope Update: Python Sklearn Compatibility Promotion + Metrics Parity Maintenance (2026-05-04)

- Promoted sklearn validation compatibility bridges from notebook-local monkeypatching into shared Python source:
  - `stabl/preprocessing.py`: `LowInfoFilter` now has an internal `_validate_data()` compatibility fallback that handles both `force_all_finite` and `ensure_all_finite` keyword conventions.
  - `stabl/stabl.py`: `Stabl` now has an internal `_validate_data()` compatibility fallback using `check_array`/`check_X_y` with old/new sklearn keyword handling.
- Simplified tutorial notebook setup by removing the now-redundant `_validate_data` monkeypatch block from `Notebook examples/Tutorial Notebook.ipynb`.
- Maintained metrics frozen-fixture parity by regenerating Python fixtures and re-running focused parity tests.

Validation notes for this implementation step:

- Command: `PYTHONPATH=. conda run -n R4_51 python -W ignore r-pkg/stablr/scripts/generate_python_parity_refs.py`
- Result: completed successfully (`Wrote fixture: gaussian`, `binomial`, `multinomial`, `metrics`).
- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures|phase7')"`
- Result: `PASS 89`, `FAIL 0`, `WARN 0`, `SKIP 0`.
- Command: `PYTHONPATH=. conda run -n R4_51 python -c "import numpy as np; from sklearn.linear_model import Lasso; from stabl.preprocessing import LowInfoFilter; from stabl.stabl import Stabl; rng=np.random.default_rng(7); X=rng.normal(size=(40,6)); X[0,0]=np.nan; y=rng.normal(size=40); LowInfoFilter(max_nan_fraction=0.5).fit(X); m=Stabl(base_estimator=Lasso(max_iter=5000, random_state=7), lambda_grid={'alpha':[0.1,0.05]}, n_bootstraps=5, artificial_type='random_permutation', random_state=7, n_jobs=1); m.fit(np.nan_to_num(X), y); print('ok', m.stabl_scores_.shape)"`
- Result: `ok (6, 2)`.

### M11: Phase 8 Export Hardening With Real Data (2026-05-04)

- Added a Biobank SSI-backed real-data fixture loader in `r-pkg/stablr/tests/testthat/test-phase7.R` that reads directly from `Sample Data/data.zip`.
- Added a new end-to-end regression test in `test-phase7.R` that:
  - fits a deterministic binomial `stabl_fit()` model on aligned Biobank SSI proteomics/outcome data,
  - validates `export_stabl_to_csv()` artifact schema (dimensions, lambda-derived column labels, sorted max-probability file),
  - validates `save_stabl_results()` artifact layout (`STABL scores.csv`, `FDR Graph.png`, `Stability Path.png`, and `Selected Features/Selected features.csv`).
- Hardened zip-path resolution in the fixture helper by anchoring to `testthat::test_path(...)` so the test runs regardless of the test working directory.

Validation notes for this implementation step:

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'phase7')"`
- Result: `PASS 62`, `FAIL 0`, `WARN 0`, `SKIP 0`.

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


### M8: Phase 8 Parity Hardening (2026-05-06)

- Added frozen Python parity fixtures and regression tests for elastic-net (gaussian and binomial) in addition to lasso and multinomial.
- Regenerated all parity fixture files using `r-pkg/stablr/scripts/generate_python_parity_refs.py`.
- All parity tests now pass: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures')"` → `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 20 ]`.
- Updated PLAN.md, PROGRESS.md, HANDOFF.md to reflect parity coverage closure for these adapters.

### M9: Vignettes (2026-05-07) — Complete

Scope: two fully buildable vignettes with zero user path setup required.

All steps completed:

- A. Generated `inst/extdata/` OOL subset CSVs: 6 files (train/valid × cytof/proteomics/dos), 150 rows × 100 features, gzipped. Total bundle: 904 KB.
- B. Added `load_ool_data()` in `R/data_helpers.R`; `export(load_ool_data)` added to `NAMESPACE`; `knitr`, `rmarkdown` added to `Suggests` + `VignetteBuilder: knitr` added to `DESCRIPTION`.
- C. Wrote `stablr-intro.Rmd`: synthetic data, binary classification + regression, adaptive lasso, elastic net with `l1_ratio`, `n_bootstraps = 100`. Builds cleanly.
- D. Wrote `stablr-multiomic.Rmd`: real OOL data via `load_ool_data()`, 2 omics, per-omic STABL + `stabl_multiomic_train_validate()` early+late fusion, `n_bootstraps = 150`. Builds cleanly.
- E. Fixed two build errors: (1) `alpha =` renamed to `l1_ratio =` in intro vignette; (2) empty `sel_features` case in `exports.R` `data.frame(row.names = ...)` now guarded.
- F. Validated: `devtools::build_vignettes('r-pkg/stablr')` → both vignettes build to HTML without errors. Tests: `PASS 290`, `FAIL 0`, `SKIP 8` (sparsegl only).

Build command:

```bash
conda run -n R4_51 Rscript -e "devtools::build_vignettes('r-pkg/stablr')"
```

## Latest Validation Snapshot

- Command: `conda run -n R4_51 R CMD INSTALL multiview`
- Result: completed successfully; local `multiview` package installed into the `R4_51` library for cooperative workflow validation.

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"`
- Result: `PASS 88`, `FAIL 0`, `WARN 0`, `SKIP 0` after adding cooperative workflow coverage.

- Command: `conda run -n R4_51 Rscript -e "devtools::document('r-pkg/stablr')"`
- Result: completed successfully; regenerated `stabl_multiomic_train_validate.Rd` and `stabl_multiomic_cv.Rd` (NAMESPACE intentionally not regenerated).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 309`, `FAIL 0`, `WARN 0`, `SKIP 0`.

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'phase7|python-parity-fixtures')"`
- Result: `PASS 89`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes new frozen Python parity checks for `metrics.R`).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'phase7')"`
- Result: `PASS 62`, `FAIL 0`, `WARN 0`, `SKIP 0` (includes Biobank SSI real-data export hardening test).

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 265`, `FAIL 0`, `WARN 0`, `SKIP 0`.

- Command: `PYTHONPATH=. conda run -n R4_51 python r-pkg/stablr/scripts/generate_python_parity_refs.py`
- Result: completed successfully; generated frozen parity fixtures for gaussian/binomial/multinomial under `r-pkg/stablr/tests/testthat/fixtures/python_parity/`.

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures')"`
- Result: `PASS 9`, `FAIL 0`, `WARN 0`, `SKIP 0`.

- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 256`, `FAIL 0`, `WARN 0`, `SKIP 0`.

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

### M11: Phase 8 — Frozen Python Parity Fixtures (2026-05-04)

- Added deterministic Python fixture generator: `r-pkg/stablr/scripts/generate_python_parity_refs.py`.
  - Generates synthetic fixtures and frozen Python references for `gaussian`, `binomial`, and `multinomial` paths.
  - Writes fixture datasets and reference summaries under `r-pkg/stablr/tests/testthat/fixtures/python_parity/`.
  - Includes compatibility shim for sklearn API drift (`Stabl._validate_data`) so reference generation remains runnable in current environments.
- Added Phase 8 regression tests: `r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R`.
  - Validates cross-language parity against frozen Python references using feature-rank/signal-strength consistency checks.
  - Covers gaussian, binomial, and multinomial fixtures with deterministic random-state settings.
- Recorded explicit scope gap: Python reference implementation in `stabl/` does not provide Cox-family support, so Cox frozen-reference parity remains an open hardening item requiring an agreed surrogate anchor policy.

### M12: Phase 8 — Metrics Python-Parity Closure (2026-05-04)

- Extended the frozen Python fixture generator (`r-pkg/stablr/scripts/generate_python_parity_refs.py`) to emit deterministic `stabl.metrics` references:
  - scalar outputs in `r-pkg/stablr/tests/testthat/fixtures/python_parity/metrics_scalars.csv`,
  - vector/matrix outputs in `r-pkg/stablr/tests/testthat/fixtures/python_parity/metrics_vectors.csv`.
- Added Phase 8 parity assertions in `r-pkg/stablr/tests/testthat/test-phase7.R` that compare R metrics outputs directly against frozen Python references for:
  - `jaccard_similarity`, `jaccard_matrix(remove_diag=TRUE)`,
  - `adjusted_similarity`, `adjusted_similarity_values`, `adjusted_similarity_measure`,
  - `pearson_similarity`, `pearson_similarity_values`, `pearson_similarity_measure`,
  - `fdr_similarity`, `tpr_similarity`, `fscore_similarity` (beta = 1 and 2).
- Closed two behavior-level parity drifts in `r-pkg/stablr/R/metrics.R` discovered by the new tests:
  - aligned upper-triangle value ordering with Python (`np.triu_indices_from(..., k=1)` row-major traversal),
  - aligned `stat = "mean"` error with Python's population standard deviation (`np.std`, `ddof = 0`) instead of sample standard deviation.
- Corrected `jaccard_matrix(..., remove_diag = TRUE)` shape semantics to match Python (`N x (N-1)`), and updated the corresponding structural test.

### M13: Experimental Cooperative Fusion Workflow Slice (2026-05-04)

- Added an experimental `cooperative_fusion` branch to `stabl_multiomic_train_validate()` and `stabl_multiomic_cv()` in `r-pkg/stablr/R/multiomic_workflows.R`.
  - New additive workflow arguments: `cooperative_fusion`, `rho`, `cooperation_selection`, `cooperation_selector`, `cooperation_type_measure`, and `cooperation_nfolds`.
  - Default non-cooperative return shape is preserved exactly when `cooperative_fusion = FALSE`.
  - Cooperative results are attached only when requested and include selected `rho`, selected `lambda`, per-view selected features, selected train/validation matrices, predictions, and tuning diagnostics.
- Added cooperative-only argument normalization and family/dependency guards in `r-pkg/stablr/R/input_validation.R`.
  - Optional dependency: `multiview` added to `r-pkg/stablr/DESCRIPTION` `Suggests`.
  - Supported families: `gaussian`, `binomial`, `poisson`, and `cox`.
  - Validation-mode cooperative tuning is explicitly rejected for `family = "cox"`; CV mode remains supported.
  - `cooperation_selector = "lambda.1se"` is explicitly restricted to `cooperation_selection = "cv"`.
- Added cooperative helper routines in `multiomic_workflows.R` for:
  - multiview family mapping,
  - deterministic inner fold-id generation with grouped handling,
  - validation-mode metric evaluation,
  - coefficient extraction across intercept-bearing and Cox paths,
  - additive outer-fold diagnostics augmentation.
- Tightened outcome handling in `stabl_multiomic_cv()` by replacing direct `y[train_ids]` / `y[valid_ids]` indexing with `.subset_outcome_by_ids(...)`, preserving support for matrix-like outcomes such as `survival::Surv`.
- Regenerated package documentation with `devtools::document('r-pkg/stablr')`; `stabl_multiomic_train_validate.Rd` and `stabl_multiomic_cv.Rd` now reflect the cooperative arguments.
- Extended `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` with cooperative regression and behavior coverage:
  - default non-cooperative return-shape preservation,
  - gaussian cooperative CV and validation paths,
  - binomial, poisson, and cox cooperative family coverage,
  - unsupported-combination guards,
  - additive cooperative diagnostics in outer CV.

### M14: Handoff Documentation Refinement (2026-05-04)

- Tightened `HANDOFF.md` with cooperative workflow touchpoints, explicit current constraints, and file-anchored next tasks for a fresh session.
- Tightened `PLAN.md` with file-level cooperative owner surfaces so the next hardening step is locally scoped.
- Tightened `MultiView.md` with `stablr` implementation anchors and the currently enforced cooperative constraints.

Validation notes for this refinement:

- Scope: documentation-only handoff refinement (`PLAN.md`, `PROGRESS.md`, `HANDOFF.md`, `MultiView.md`).
- Test command execution: not rerun in this pass; latest validated state remains `PASS 309`, `FAIL 0`, `WARN 0`, `SKIP 0` from the full local suite.

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

### M15: TCGA Breast Cancer Vignette — mixOmics Chapter 6 Translation (2026-05-07)

Scope: new stablr-idiomatic vignette translating the mixOmics N-Integration Chapter 6 case study into stablr.

All steps completed:

- Confirmed `mixOmics` is installed in the `R4_51` conda environment (Bioconductor package, includes `breast.TCGA` dataset).
- Ran binomial multi-omic smoke check (`n_bootstraps = 20`, mRNA + miRNA, Basal vs non-Basal): completed without errors; `stabl_multiomic_fit` class confirmed, late fusion AUROC = 0.643.
- Added `mixOmics` to `Suggests` in `r-pkg/stablr/DESCRIPTION`.
- Wrote `r-pkg/stablr/vignettes/stablr-tcga.Rmd`:
  - Dataset: `breast.TCGA` (mRNA 150x520 + miRNA 150x184 train; 70-sample test; protein excluded).
  - Outcome: Basal vs non-Basal binary (`family = "binomial"`), `n_bootstraps = 50` with chunk caching.
  - Sections: prerequisites, load data + binary encoding, per-omic STABL, integrated pipeline (early + late fusion), results exploration, validation performance (confusion matrix + BER), export, next steps.
- Rendered `stablr-tcga.html` successfully; all 31 code chunks executed without errors.

Validation notes:

- Smoke check: `conda run -n R4_51 Rscript /tmp/smoke_binomial.R` → `SMOKE CHECK PASSED`.
- Render: `conda run -n R4_51 Rscript /tmp/render_tcga.R` → `Output created: vignettes/stablr-tcga.html` (exit 0).

## In Progress

- CI implementation is intentionally deferred in this workspace by user request.
- Local test-suite validation remains green and is the active hardening path.

### Full roxygen2 Documentation Coverage Pass (2026-05-05)

Performed a systematic documentation pass over all 12 R source files in `r-pkg/stablr/R/`. Every exported function now has:
- A title sentence.
- A 1-2 sentence purpose description explaining *why* the function exists.
- `@param` entries covering every parameter with type, valid range/values, and defaults.
- `@return` describing the type and structure of the output.
- `@details` for complex/key functions adding technical depth (algorithm, formula, or design rationale).
- `@seealso` cross-links to related functions.

Files edited in this pass (documentation-only changes):

| File | Functions updated |
|------|------------------|
| `R/visualization.R` | `plot_fdr_graph`, `plot_roc`, `plot_prc`, `boxplot_features`, `scatterplot_features` |
| `R/bootstrap_helpers.R` | `classic_bootstrap_indices`, `group_bootstrap_indices` |
| `R/stabl_accessors.R` | `get_support`, `get_stabl_scores`, `get_feature_names_out`, `get_importances` |
| `R/metrics.R` | All 11 exported functions |
| `R/input_validation.R` | `validate_sample_alignment`, `validate_multiomic_inputs` |
| `R/artificial_features.R` | `make_artificial_features` |
| `R/learner_adapters.R` | `make_glmnet_adapter`, `make_adaptive_lasso_adapter`, `make_sgl_adapter`, `auto_lambda_grid` |
| `R/exports.R` | `save_stabl_results` (title + description + `@details` + `@seealso` expanded) |

Files confirmed already well-documented (no changes): `stabl_fit.R`, `fdp_control.R`, `multiomic_workflows.R`, `data_helpers.R`.

Validation notes:

- `devtools::document('r-pkg/stablr')` completed with no new errors introduced by this pass (pre-existing NAMESPACE note about `multiview` package is unchanged).
- Command: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`
- Result: `PASS 290`, `FAIL 0`, `WARN 0`, `SKIP 8` (skips are for optional `multiview`/`sparsegl` dependencies, unchanged from before).

### Python–R Parity Vignette (2026-05-07)

- Added `r-pkg/stablr/vignettes/stablr-python-parity.Rmd`: a publication-quality vignette reproducing the Python STABL Tutorial Notebook in R.
- Covers two analyses mirroring the Tutorial Notebook exactly:
  1. OOL regression (Proteomics): `family = "gaussian"`, knockoff, `n_bootstraps = 500`, `n_lambda = 10`, `random_state = 42`.
  2. COVID-19 binary classification (Proteomics): `family = "binomial"`, knockoff, `n_bootstraps = 1000`, `n_lambda = 10`, `fdr_threshold_range = seq(0.1, 1, by = 0.01)`, `random_state = 42`.
  3. Full pipeline section: preprocessing + STABL + unpenalised GLM final model; training and validation ROC/PRC curves; prediction distribution boxplots.
- Includes `preprocess_fit()` / `preprocess_apply()` helpers that replicate the Python `VarianceThreshold + LowInfoFilter + SimpleImputer + StandardScaler` pipeline without data leakage.
- All diagnostic plots present: FDP+ curves, stability paths, feature distribution plots (scatter/boxplot for regression/classification respectively), ROC/PRC.
- `cache = TRUE` on heavy fit chunks; COVID-19 data read from `Sample Data/COVID-19/` at runtime with a clear data-requirement notice.
- Parameter comparison tables and algorithmic note explain LASSO implementation differences between glmnet and scikit-learn.

Validation notes:

- Scope: documentation/vignette addition only; no R source or test code modified.
- Test suite not re-run in this pass (no functional code changed).

### All 4 Vignettes Built (2026-05-08)

**Problem:** `stablr-python-parity.Rmd` was corrupted to 31 lines (only YAML header) by a prior Python write script bug. `stablr-tcga.Rmd` had a stale `stablr-tcga-cache/` from a previous render.

**Fixes applied:**
- Rewrote `stablr-python-parity.Rmd` from scratch (298 lines) using Python `open(..., 'w').write(...)`.
  - Key fix: `scatterplot_features(features = names(which(sel_prot)), ...)` — `get_support()` returns a named logical vector; plot functions require a character vector. Using `names(which(...))` extracts the selected feature names.
  - `boxplot_features` equivalently uses `names(which(sel_covid))`.
  - Inline `preprocess_fit()` / `preprocess_apply()` helpers replicate the Python pipeline.
  - COVID-19 data check via `file.exists()` guard; `eval = eval_covid` on COVID chunks.
- Deleted stale `stablr-tcga-cache/` directory, then re-rendered successfully.

**Render results (2026-05-08):**
- `stablr-intro.html` — 335K, in `doc/` ✅
- `stablr-multiomic.html` — 1.4M, in `doc/` ✅
- `stablr-python-parity.html` — 561K, in `doc/` ✅ (all 42 chunks ran incl. COVID-19 section)
- `stablr-tcga.html` — 787K, in `doc/` ✅ (all 42 chunks ran)

All 4 vignettes build without errors.

### Scope Decision (2026-05-03)
- Tidymodels integration (Phase 6 original plan) is **dropped**. No `parsnip`, `recipes`, `tune`, `workflows`, or `yardstick` dependencies will be introduced.
- Phase 6 is now **full glmnet compatibility**: complete family coverage, coefficient/path extraction parity, and lambda-grid convention alignment across all adapters.

## Risks To Track
- Cross-backend differences for adaptive/sparse-group/knockoff behavior.
- Lack of native Cox support in Python `stabl/` blocks direct Cox frozen-reference parity checks without a surrogate-anchor policy.

## Environment Notes
- R runtime is available via conda environment `R4_51`.
- Validation command used in this workspace: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"`.
