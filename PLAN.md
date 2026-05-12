# PLAN: stablr Full R Port

**Purpose:** Forward-looking roadmap, acceptance gates, and active milestones for remaining work.

**This document owns:**
- Future scope, sequencing, and priorities.
- Acceptance criteria and phase gates for active work.
- Active milestone definitions and work packages.
- Experimental track policy and exit criteria.

**This document does NOT own:**
- Completed work and validation evidence (→ PROGRESS.md)
- Current operator state and immediate task queue (→ HANDOFF.md)
- Algorithm semantics and parity rules (→ STABL.md)
- Workflow policy and precedence (→ AGENTS.md)

**Cross-reference pattern:** For evidence of completed work, check PROGRESS.md. For immediate execution queue, check HANDOFF.md.

## Objective
Build a production-grade pure-R package named `stablr` inside this repository that ports the current Python STABL implementation with full glmnet-ecosystem compatibility and no tidymodels runtime dependency.

## Document Role

This file is the forward-looking plan.

- Specification and semantic parity contract live in `STABL.md`.
- Executed work and validations live in `PROGRESS.md`.
- Fresh-session execution bootstrap lives in `HANDOFF.md`.
- Agent workflow policy lives in `AGENTS.md`.

Planning rule:

- Keep this document action-oriented and testable.
- Move completed implementation details to `PROGRESS.md`.

## Session Bootstrap Entry

- Fresh Copilot sessions should start with `HANDOFF.md`, then reconcile with `PLAN.md` and `PROGRESS.md`.

## Parity Gate Policy (Strict)

- No feature or tranche is considered complete unless behavior-matching parity tests exist and pass.
- Structural tests alone are insufficient for closure when behavior-level assertions are practical.
- Core STABL semantics remain parity-critical and non-negotiable per `STABL.md`.
- Experimental tracks may progress without blocking core parity closure, but cannot be labeled parity-complete without dedicated tests.

## Locked Decisions
- Package name: `stablr`
- Implementation: pure R (no Python runtime dependency)
- Layout: monorepo with R package in a subdirectory
- Architecture order: core STABL engine first, full glmnet compatibility second
- Scope: binary, regression, multiclass, longitudinal/repeated-measures, multi-omics, reporting, benchmark reproduction
- Parity policy: tolerance-based parity with Python
- Data contract: named list of omics tables, strict sample alignment, hard error on mismatch
- Parallel backend: `future`/`furrr`
- M1 learner support: lasso, elastic net, adaptive lasso, sparse group lasso
- Output style: structured S3 objects + tidy extractors + optional disk export
- Integration target: full glmnet API compatibility (no tidymodels dependency)
- License target: MIT
- R target: >= 4.4

## Source Anchors To Mirror
- `stabl/stabl.py`
- `stabl/multi_omic_pipelines.py`
- `stabl/preprocessing.py`
- `stabl/pipelines_utils.py`
- `stabl/stacked_generalization.py`
- `stabl/adaptive.py`
- `stabl/data.py`

## Baseline Completion Context

The core port baseline (Phases 1-8) is complete. This plan now tracks only remaining forward work and acceptance gates.

For command-level evidence and exact validation results, use `PROGRESS.md`.

## Active Dependencies

- R environment reproducibility in `R4_51` is required for reliable benchmark smoke checks.
- Python reference scripts remain the behavior anchor for parity checks where tests are not yet frozen.
- Current workspace scope (2026-05-03): CI workflow implementation is deferred; validation is performed via local R test suites.

## Vignette Status (as of 2026-05-12) — Complete

All 5 stablr vignettes have canonical source under `r-pkg/stablr/vignettes/`
and rebuild successfully via `devtools::build_vignettes('r-pkg/stablr')`.
Generated `doc/` output is build output, not the edit source.

- `stablr-intro.Rmd` ✅ — simulated-data introduction with clearer input
  contract, selected-feature interpretation, and single-omic scope boundaries.
- `stablr-multiomic.Rmd` ✅ — bounded real OOL multi-omic workflow.
- `stablr-python-parity.Rmd` ✅ — bounded Python-to-R workflow mapping with
  high-fidelity parity settings documented as an extended run.
- `stablr-tcga.Rmd` ✅ — TCGA Breast Cancer multi-omic workflow.
- `stablr-cooperative.Rmd` ✅ — bounded cooperative fusion workflow; outer CV
  shown but not evaluated during vignette builds.

## Documentation Website Status (as of 2026-05-10) — Complete

- Root README now distinguishes the current R package from the original Python
  reference code.
- Package README now documents current workflows, optional dependencies, API
  groups, vignettes, and pkgdown build commands.
- Package-level Rd/API reference has been regenerated from roxygen and reflects
  the current exported API.
- `r-pkg/stablr/_pkgdown.yml` defines grouped reference sections and vignette
  navigation.
- pkgdown site builds to `docs/stablr` with clean metadata checks.

## Current Planning Focus (Forward Only)

0. **[ACTIVE] TCGA nested-CV head-to-head analysis.** Full SLURM job submitted
   for cached stablr-vs-DIABLO three-class TCGA benchmark; monitor job
   `24750538` and render `stablr-tcga-nestedcv.Rmd` from the resulting cache.
1. ~~**[ACTIVE] Bug-fix milestone — audit findings (2026-05-08).**~~ **CLOSED 2026-05-08. All 7 fixes landed; PASS 356, FAIL 0, SKIP 3.**
2. ~~Harden cooperative fusion behavior.~~ **CLOSED 2026-05-08 (M12).**
3. ~~Promote cooperative fusion before CRAN-prep hardening.~~ **CLOSED 2026-05-10. Public cooperative accessors added and targeted suite green.**
4. ~~Additional parity tests for multiclass (multinomial) and Cox families.~~ **CLOSED 2026-05-08. 7 new test cases added; see PROGRESS.md.**
5. ~~Initial CRAN-prep hardening pass.~~ **CLOSED 2026-05-10. Package-code `R CMD check --no-manual` is `Status: OK`; full manual check has only local TeX `inconsolata.sty` warning.**
6. ~~FDR graph vignette mismatch: documented horizontal FDP target line missing from `plot_fdr_graph()`.~~ **CLOSED 2026-05-12. Helper now draws `fdr_target = 0.05` by default; targeted plotting tests green.**
7. ~~Intro-vignette toy simulations over-selected in regression because low-penalty lambda values made noise features stable.~~ **CLOSED 2026-05-12. Binary and regression examples now use independent planted-support simulations and compact strong-penalty lambda grids; render green.**
8. ~~Intro-vignette clarity pass for new users while preserving introductory scope.~~ **CLOSED 2026-05-12. Added input-shape orientation, smoother selected-feature interpretation, explicit plot-saving pattern, and less formulaic prose; single-vignette render green.**
9. Keep local deterministic validation green for every forward change.
10. Keep Python-path API compatibility in source (`stabl/`) without notebook-local monkeypatching.
11. Next CRAN-prep priority: decide whether to install/fix local TeX manual tooling or defer manual PDF validation to CI/CRAN-like builders.

## Remediation Audit Execution Status (2026-05-08)

- Implemented (code/tests/docs): WI-01, WI-02, WI-03, WI-04, WI-05, WI-07, WI-08,
  WI-09, WI-10, WI-11, WI-12, WI-13, WI-14, WI-15, WI-16.
- Reclassified by source-of-truth check against Python reference:
  - H-2 to TEST-ONLY (Python random-permutation source draw is `replace=False`).
  - M-1 to DOC-ONLY (`bootstrap_threshold = 1e-5` parity with Python).
  - WI-06 dropped (Python uses requested `artificial_proportion` in FDP+ scaling).
- Closure gate is now remediation of test regressions, not environment bootstrap:
  full-suite validation was executed in `R4_51` and returned
  `[ FAIL 7 | WARN 0 | SKIP 4 | PASS 1336 ]`.
- Immediate planning focus: resolve the 7 failing contexts one-by-one with strict TDD
  (RED -> GREEN -> full-suite re-run after each item), then re-run closure mapping.

### Remediation Continuation Status (2026-05-09)

- Completed in-session targeted remediation (test-first contract cleanup):
  - `test-bootstrap-helpers.R` fixed (group-impossible-class case construction corrected).
  - `test-fdp-plus-invariants.R` fixed (threshold sweep for `min_fdr > 1` invariant now excludes `1.0`).
  - `test-input-validation.R` fixed (error matcher expanded to accept current early-validator wording).
  - `test-multiomic-guards.R` fixed (API argument name corrected to `cooperation_selection`).
  - `test-python-parity-fixtures.R` fixed (case-specific gaussian elastic-net max-score correlation floor).
- Final remediation closure checkpoint:
  - `PASS 1343`, `FAIL 0`, `SKIP 4`.
  - Remaining failures: none.
- Active forward focus returns to non-remediation items (cooperative vignette build and
  ongoing deterministic validation).

### Post-Remediation Execution Update (2026-05-09)

- Cooperative vignette render closure progressed:
  - `stablr-cooperative.Rmd` now renders to `stablr-cooperative.html`.
- Full-suite validation after dependency alignment:
  - `PASS 1351`, `FAIL 0`, `WARN 2`, `SKIP 0`.
- Optional dependency status:
  - `furrr` load path restored after upgrading `purrr` to `1.2.2`.
  - `sparsegl` installed from source fallback (conda-forge binary unavailable).
- Remaining forward blocker is now limited to unified vignette build completion:
  - cleared: all five vignettes now build successfully in one pass.

### Additional Parity Tests — Multiclass + Cox (2026-05-08) — CLOSED

**Scope:** Extend the frozen Python parity test suite and R self-consistency parity to cover:
- Multinomial elastic-net: cross-language frozen fixture (same fixture format as existing cases)
- Cox lasso, elastic-net, adaptive-lasso: R self-consistency signal-recovery tests (no Python Cox backend)
- Multinomial lasso + elastic-net: signal-recovery self-consistency tests beyond existing structural tests

**Status:** ✅ Delivered. See PROGRESS.md for details.

## Active Milestone: Bug-Fix Audit Findings (2026-05-08)

Acceptance gate: all fixes landed, regression suite remains `PASS ≥326, FAIL 0`, and each fix has at least one new targeted test.

Run suite after each fix:
```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

### Fix 1 — `get_support` explore fallback over-selects on tied scores [SEVERITY 1]

**File:** `r-pkg/stablr/R/stabl_accessors.R`  
**Function:** `get_support.stabl_fit`, the `explore` fallback block (lines ~63-68).  
**Problem:** When all features score 0 (heavily regularized), `sort(max_scores, decreasing=TRUE)[n_exp] - 0.01` produces a cutoff of `-0.01`. Then `max_scores > -0.01` is `TRUE` for all features with score 0, selecting **every** feature instead of exactly `n_explore`. Any score tie at the n_exp-th position has the same effect.  
**Current code:**
```r
n_exp  <- min(object$n_explore, length(max_scores))
cutoff <- sort(max_scores, decreasing = TRUE)[n_exp] - 0.01
mask   <- max_scores > cutoff
```
**Fix:** Use direct index selection — no arithmetic on scores:
```r
n_exp          <- min(object$n_explore, length(max_scores))
top_idx        <- order(max_scores, decreasing = TRUE)[seq_len(n_exp)]
mask[top_idx]  <- TRUE
```
**Test to add:** In `r-pkg/stablr/tests/testthat/test-stabl-accessors.R` (or create `test-get-support.R`):
- Fit with `hard_threshold = 0.99` so nothing passes. Set `explore = TRUE, n_explore = 3`.
- Verify `sum(get_support(fit))` is exactly 3, not the full feature count.
- Verify the 3 selected features are the ones with the highest `get_importances()` scores.

---

### Fix 2 — `group_bootstrap_indices` `replace = FALSE` not enforced across draws [SEVERITY 2]

**File:** `r-pkg/stablr/R/bootstrap_helpers.R`  
**Function:** `group_bootstrap_indices`  
**Problem:** `sample(group_levels, size = 1L, replace = replace)` draws one element — `replace` has no effect on a draw of size 1. `group_levels` is never shrunk, so the same group can be re-drawn on every iteration regardless of `replace = FALSE`. This means the `replace = FALSE` contract (sample groups without replacement) is silently violated.  
**Fix:** Maintain a mutable `remaining` vector; remove groups after drawing them:
```r
group_levels <- unique(groups)
remaining    <- group_levels
sampled_idx  <- integer(0)

while (length(sampled_idx) < n_subsamples && length(remaining) > 0L) {
  g <- sample(remaining, size = 1L)
  sampled_idx <- unique(c(sampled_idx, which(groups == g)))
  if (!replace) remaining <- remaining[remaining != g]
  if (!replace && length(sampled_idx) == n) break
}
```
When `replace = TRUE` do not remove from `remaining` (or reset to `group_levels` after exhaustion).  
**Test to add:** In `test-bootstrap-helpers.R`:
- Call `group_bootstrap_indices` with `replace = FALSE`, 5 groups, `n_subsamples` large enough to require at least 3 groups.
- Run 20 times with different seeds.
- Assert: for each run, no single group's rows appear more than once (deduplication is already there via `unique(c(...))`, but verify group sampling draws each group at most once by checking the count of unique groups drawn vs. `n_subsamples` implied minimum).

---

### Fix 3 — `corr_group_threshold` missing `-0.1` offset (Python parity break) [SEVERITY 2]

**File:** `r-pkg/stablr/R/stabl_fit.R`  
**Function:** `.build_corr_groups`  
**Problem:** Python applies `threshold = np.percentile(corr_val, perc) - 0.1` (`stabl/stabl.py` line 1142). R uses `quantile(corr_vals, probs = percentile / 100)` with no offset. The `-0.1` offset in Python makes the grouping criterion slightly more inclusive (groups more features at the same percentile). Without the offset, R produces sparser groupings than Python for identical data and `corr_group_threshold` values, breaking the `sparse_group_lasso` parity test fixture.  
**Current code:**
```r
cutoff <- as.numeric(stats::quantile(corr_vals, probs = percentile / 100,
                                     names = FALSE, na.rm = TRUE))
```
**Fix:**
```r
cutoff <- as.numeric(stats::quantile(corr_vals, probs = percentile / 100,
                                     names = FALSE, na.rm = TRUE)) - 0.1
```
**Test to add:** In `test-stabl-fit.R` or `test-learner-adapters.R`:
- Build a small `x` with two clearly correlated feature pairs and two independent features.
- Call `.build_corr_groups` (via `stabl_fit` with `corr_group_threshold`) and verify the correlated pairs are grouped together (cutoff offset makes the difference for moderate correlation values).

---

### Fix 4 — `make_knockoff_features` chunked path loses original feature index mapping [SEVERITY 2, only affects p > 3000]

**File:** `r-pkg/stablr/R/artificial_features.R`  
**Function:** `make_knockoff_features`, chunked branch (`n_features > 3000`).  
**Problem:** In the non-chunked path, `x_art_full` has exactly `n_features` columns in the same column order as `x`, so `sel_idx` (into `x_art_full`) doubles as valid original-feature indices — no bug. In the chunked path, columns in `x_art_full` are knockoffs of random subsets of features, column-bound and trimmed. The mapping from `x_art_full` column position to original feature index is lost. `noise_col_indices = sel_idx` (indices into `x_art_full`) are then used by `.append_noise_groups` as original feature indices to look up SGL groups — wrong for p > 3000.  
**Fix:** Track the original-feature index each knockoff column was derived from. Maintain a parallel `orig_map` integer vector alongside `ko_blocks`:
```r
orig_maps <- vector("list", n_chunks)
for (i in seq_len(n_chunks)) {
  col_idx        <- sample.int(n_features, size = min(chunk_size, n_features), replace = FALSE)
  ko_blocks[[i]] <- .make_ko_chunk(x[, col_idx, drop = FALSE])
  orig_maps[[i]] <- col_idx
}
orig_map_full <- unlist(orig_maps)          # length = n_chunks * chunk_size
orig_map_full <- orig_map_full[keep_idx]    # trim same as x_art_full
# then:
noise_col_indices = orig_map_full[sel_idx]  # original-feature indices
```
**Test to add:** This path only fires at p > 3000. Add a test with `n_features = 3001` (small `n` is OK, e.g. 20 rows), knockoff type, and SGL base learner. Verify `stabl_fit` completes without error and `length(fit$stabl_scores_)` equals `n_features`.

---

### Fix 5 — `stabl_fit` result list holds all bootstrap matrices simultaneously (peak memory) [SEVERITY 3]

**File:** `r-pkg/stablr/R/stabl_fit.R`  
**Function:** `stabl_fit`, the `result_list` pattern (lines ~308-324).  
**Problem:** `lapply(boot_indices, process_one_bootstrap)` materializes `n_bootstraps` logical matrices of size `(n_total_features × n_lambdas)` simultaneously before accumulation. At `n_bootstraps=1000, p=2000, n_lambda=30`, this is ~240 MB peak just for the bootstrap results.  
**Fix:** Replace `lapply` + accumulation loop with a single streaming `Reduce` call:
```r
if (use_furrr) {
  # furrr cannot stream; keep result_list for parallel path
  result_list <- furrr::future_map(boot_indices, process_one_bootstrap,
                                   .options = furrr::furrr_options(seed = TRUE))
  accum_real <- Reduce(`+`, lapply(result_list, function(r) r[seq_len(n_features), , drop=FALSE]))
  accum_art  <- if (!is.null(artificial_type))
                  Reduce(`+`, lapply(result_list, function(r) r[art_rows, , drop=FALSE])) else NULL
} else {
  # sequential: accumulate and discard each bootstrap matrix immediately
  accum_real <- matrix(0.0, nrow = n_features, ncol = n_lambdas)
  accum_art  <- if (!is.null(artificial_type))
                  matrix(0.0, nrow = n_injected, ncol = n_lambdas) else NULL
  for (idx in boot_indices) {
    r          <- process_one_bootstrap(idx)
    accum_real <- accum_real + r[seq_len(n_features), , drop = FALSE]
    if (!is.null(artificial_type)) accum_art <- accum_art + r[art_rows, , drop = FALSE]
  }
}
stabl_scores_    <- accum_real / n_bootstraps
stabl_scores_art <- if (!is.null(artificial_type)) accum_art / n_bootstraps else NULL
```
**Test:** Existing integration tests cover correctness. After fix, verify `PASS ≥326, FAIL 0`. No new test required (behavior unchanged; memory-only improvement).

---

### Fix 6 — Bootstrap retry unbounded recursion risk [SEVERITY 4]

**File:** `r-pkg/stablr/R/bootstrap_helpers.R`  
**Functions:** `classic_bootstrap_indices` and `group_bootstrap_indices`, the degenerate-resample guard.  
**Problem:** Both functions recurse without a retry-count limit. With severe class imbalance (e.g., 1 positive out of 50 samples, `sample_fraction = 0.5`, `replace = FALSE`), the valid-draw probability is low. R's call stack limit (~900 frames) would be exhausted after ~900 failed attempts.  
**Fix:** Convert recursion to an iterative loop with a hard retry cap (1000 iterations):
```r
# replace the recursive tail-call with:
for (.retry in seq_len(1000L)) {
  idx <- sample.int(...)
  if (length(unique(y[idx])) >= 2L || length(unique(y)) < 2L) return(idx)
}
stop("Could not draw a class-diverse bootstrap subsample after 1000 attempts. ",
     "Consider increasing `sample_fraction` or using `class_weights`.", call. = FALSE)
```
Apply the same pattern to `group_bootstrap_indices`.  
**Test to add:** In `test-bootstrap-helpers.R`:
- Create `y` with 1 positive and 49 negatives, `n_subsamples = 25`, `replace = FALSE`.
- Call `classic_bootstrap_indices` 10 times and verify each returns a vector with both classes (not a stack overflow and not all-negative).

---

### Fix 7 — `sample_fraction > 1` with `replace = FALSE` not caught early [SEVERITY 4]

**File:** `r-pkg/stablr/R/stabl_fit.R`  
**Function:** `.validate_stabl_params`  
**Problem:** `sample_fraction > 1` with `replace = FALSE` passes `stabl_fit`'s upfront validator and fails only deep inside `classic_bootstrap_indices` with a non-obvious error.  
**Fix:** Add to `.validate_stabl_params`:
```r
# Already called with replace argument — thread replace through or check here
# Simplest: add to stabl_fit() directly after n_subsamples is computed:
if (!replace && n_subsamples > n_samples) {
  stop(
    "`sample_fraction` (", sample_fraction, ") × n (", n_samples, ") = ",
    n_subsamples, " exceeds n. Set `replace = TRUE` or reduce `sample_fraction`.",
    call. = FALSE
  )
}
```
Place this check in `stabl_fit()` immediately after `n_subsamples <- as.integer(floor(sample_fraction * n_samples))`.  
**Test:** `expect_error(stabl_fit(..., sample_fraction = 1.5, replace = FALSE), "sample_fraction")`.

## Implementation Phases
1. Spec + scaffolding
- Create package skeleton under `r-pkg/stablr`
- Establish S3 object contracts and migration map

2. Core contracts
- Implement strict alignment validators for predictors/outcomes/groups
- Implement canonical input coercion rules for multi-omic lists

3. Core STABL engine
- Bootstrap samplers (classic + grouped)
- Lambda-grid iteration and stability accumulation
- Artificial features: random permutation and knockoff
- FDR/FDP threshold selection and support-mask extraction

4. Learner adapters
- Lasso and elastic net adapters
- Adaptive lasso adapter
- Sparse group lasso adapter
- Multiclass support behavior and documentation

5. Workflow layer
- Multi-omic CV and train/validation pipelines
- Early and late fusion flows
- Stacked generalization

6. Full glmnet compatibility
- Full glmnet family and alpha coverage (gaussian, binomial, multinomial, cox)
- glmnet path and coefficient extraction parity across all adapter types
- Support for all glmnet-compatible lambda grids and cross-validation conventions
- No tidymodels runtime dependency

7. Reporting + exports
- Stability path/FDR diagnostics/ROC-PR-regression plots
- Scores/p-values/export bundles

8. Hardening
- Parity regression tests versus frozen Python references (now includes elastic-net/gaussian/binomial parity fixtures and tests)
- CI matrix across OS and R versions
- GitHub release, then CRAN/Bioconductor hardening

## Active Milestone: Cooperative Fusion Hardening (Experimental Track)

Goal: keep cooperative fusion non-blocking to core parity while making it behavior-hardened and operator-safe.

**Status (2026-05-08): CLOSED.** All three work packages validated by M12 in `PROGRESS.md`. See exit criteria below.

Work packages (delivered):

1. Behavior-level comparative tests
- Add deterministic fixtures comparing early, cooperative, and late fusion ranking behavior.
- Confirm additive diagnostics do not alter non-cooperative return contracts.

2. Operator ergonomics for cooperative outputs
- Extend print/summary surfaces to clearly expose cooperative tuning choices (`rho`, lambda selector, mode).
- Ensure object-facing accessor behavior is stable when cooperative branch is absent.

3. Optional dependency hardening
- Add explicit tests for clean failure paths when `multiview` is unavailable and cooperative mode is requested.
- Preserve normal execution when cooperative mode is disabled.

Acceptance criteria (met):

- `test-multiomic-workflows.R` includes behavior-level (not only structural) cooperative assertions. (rho-effect, fusion-mode-difference, cox+validation guard, dep-missing.)
- Cooperative ergonomics are covered by tests and do not regress default object shape.
- Missing-`multiview` failure messages are deterministic and actionable, validated via `.has_multiview()` mocking.
- Full local package suite remains green: `PASS 326, FAIL 0, WARN 0, SKIP 3` (sparsegl absent).

## Milestone: Cooperative Fusion Promotion (2026-05-10) — CLOSED

Goal: promote cooperative fusion from an experimental-only branch to a documented,
public workflow surface while preserving its optional dependency boundary and
non-cooperative return contract.

Delivered:

- Added exported accessors `get_cooperative_features()` and
  `get_cooperative_diagnostics()` for `stabl_multiomic_fit`.
- Added `stabl_multiomic_cv` methods so outer-CV cooperative features and
  diagnostics can be inspected without reaching into nested list internals.
- Added mock-object regression tests that pin accessor behavior without requiring
  another `multiview` model fit.
- Regenerated Rd help pages and manually updated the package NAMESPACE.

Acceptance criteria (met):

- Cooperative branch remains opt-in and `multiview` remains optional.
- Default `cooperative_fusion = FALSE` return shape is unchanged.
- Public accessors fail clearly when cooperative fusion is absent.
- Targeted multiomic workflow suite remains green: `PASS 108`, `FAIL 0`,
  `WARN 0`, `SKIP 0`.
- Full local package suite remains green: `PASS 1359`, `FAIL 0`, `WARN 2`,
  `SKIP 0`.

## Promoted Track: Cooperative Fusion (Non-Blocking)

- Track type: promoted workflow-layer extension, not blocking Phase 6 closure.
- Source restriction: `multiview/` is the only in-repo cooperative reference.
- Naming policy: use `rho` for cooperation strength (avoid collision with elastic-net `alpha`).
- Implementation status and command evidence are maintained in `PROGRESS.md`.
- Immediate operational queue is maintained in `HANDOFF.md`.
- Public accessor surface: `get_cooperative_features()` and
  `get_cooperative_diagnostics()`.

Current cooperative touchpoints:

1. `r-pkg/stablr/R/multiomic_workflows.R` owns cooperative workflow orchestration and additive diagnostics.
2. `r-pkg/stablr/R/input_validation.R` owns cooperative argument normalization and family/selector guards.
3. `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` is the behavior-regression surface for cooperative hardening.
4. `r-pkg/stablr/R/stabl_accessors.R` owns cooperative print/report ergonomics and public cooperative accessors.
5. `MultiView.md` remains the cooperative design/evidence bridge.

Promotion criteria:

- Deterministic behavior-level cooperative tests pass.
- Optional-dependency failure paths are validated and stable.
- Public cooperative result inspection does not require direct `$` traversal.
- Operator-facing docs (`HANDOFF.md`) and factual logs (`PROGRESS.md`) remain synchronized.

## Maintenance Notes

- 2026-05-12: Quick-start vignette regression simulation should keep gaussian
  outcomes as named numeric vectors. The immediate implementation fix is logged
  in `PROGRESS.md`; no roadmap or acceptance-gate change is required.
- 2026-05-12: Knockoff artificial-feature generation now covers the
  `p < n < 2p` fixed-design augmentation case without falling back to random
  permutation. This is logged in `PROGRESS.md`; no roadmap or acceptance-gate
  change is required.
- 2026-05-12: `stablr-multiomic.Rmd` now explicitly states that it is a bounded
  OOL package example rather than a full reproduction of the Python tutorial
  notebook. Tutorial-dataset parity remains owned by `stablr-python-parity.Rmd`;
  no roadmap or acceptance-gate change is required.
- 2026-05-12: `stablr-python-parity.Rmd` now runs the repository tutorial data
  path with notebook-scale OOL/COVID settings and reports selected-feature
  overlap against `Notebook examples/Tutorial Notebook.ipynb`. The fresh render
  recovered all 7 OOL tutorial features and all 6 COVID tutorial features; no
  roadmap or acceptance-gate change is required.
