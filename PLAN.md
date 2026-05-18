# PLAN: costablr Full R Port

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
Build a production-grade pure-R package named `costablr` inside this repository that ports the current Python STABL implementation with full glmnet-ecosystem compatibility and no tidymodels runtime dependency.

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
- Package name: `costablr`
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

Current parity baseline includes Python-aligned FDP+ defaults: the R
`fdr_threshold_range` default is `seq(0, 0.99, by = 0.01)`, matching the
original Python `np.arange(0., 1., .01)` sweep.  The core selector also
exposes Python's `bootstrap_threshold` control with the upstream effective
default `1e-5` and sklearn-style per-bootstrap `>=` coefficient thresholding.
The parity contract in `STABL.md` was source-audited on 2026-05-13 against
upstream Python commit `1d07f85a13cfbecb4f08ce21075bf4fbb8e34678`; no new
core parity work item was opened.

## Active Dependencies

- R environment reproducibility in `R4_51` is required for reliable benchmark smoke checks.
- Python reference scripts remain the behavior anchor for parity checks where tests are not yet frozen.
- Current workspace scope (2026-05-03): CI workflow implementation is deferred; validation is performed via local R test suites.

## Vignette Status (as of 2026-05-12) — Rewrite Render Validation Complete

All 6 costablr vignette sources have canonical source under
`vignettes/`.  Generated `doc/` output is build output, not the
edit source.  The five non-nested-CV vignettes previously rebuilt successfully
via `devtools::build_vignettes('.')`; after the 2026-05-12
narrative rewrite, parallel render validation completed as SLURM array job
`24752130` with HTML output created for all five non-nested-CV vignettes.

- `costablr-intro.Rmd` ✅ — simulated-data introduction with clearer input
  contract, selected-feature interpretation, and single-omic scope boundaries.
- `costablr-multiomic.Rmd` ✅ — bounded real OOL multi-omic workflow.
- `costablr-python-parity.Rmd` ✅ — bounded Python-to-R workflow mapping with
  high-fidelity parity settings documented as an extended run.
- `costablr-tcga.Rmd` ✅ — TCGA Breast Cancer multi-omic workflow.
- `costablr-cooperative.Rmd` ✅ — bounded cooperative fusion workflow; outer CV
  shown but not evaluated during vignette builds.
- `costablr-tcga-nestedcv.Rmd` ⏸ — HPC-backed nested-CV research vignette;
  source rewritten, but excluded from the vignette render array because the
  benchmark cache is managed by the separate TCGA nested-CV SLURM workflow.

## Documentation Website Status (as of 2026-05-10) — Complete

- Root README now distinguishes the current R package from the original Python
  reference code.
- Package README now documents current workflows, optional dependencies, API
  groups, vignettes, and pkgdown build commands.
- Package-level Rd/API reference has been regenerated from roxygen and reflects
  the current exported API.
- `_pkgdown.yml` defines grouped reference sections and vignette
  navigation.
- pkgdown site builds to `docs/costablr` with clean metadata checks.

## Current Planning Focus (Forward Only)

0. ~~**[ACTIVE] Vignette render validation after narrative rewrite.**~~
   **CLOSED 2026-05-12.** SLURM array `24752130` created HTML output for all
   five non-nested-CV vignettes; see `PROGRESS.md`.
1. **[ACTIVE] TCGA nested-CV head-to-head analysis.** Full SLURM job submitted
   for cached costablr-vs-DIABLO three-class TCGA benchmark; monitor job
   `24750538` and render `costablr-tcga-nestedcv.Rmd` from the resulting cache.
2. ~~**[ACTIVE] Bug-fix milestone — audit findings (2026-05-08).**~~ **CLOSED 2026-05-08. All 7 fixes landed; PASS 356, FAIL 0, SKIP 3.**
3. ~~Harden cooperative fusion behavior.~~ **CLOSED 2026-05-08 (M12).**
4. ~~Promote cooperative fusion before CRAN-prep hardening.~~ **CLOSED 2026-05-10. Public cooperative accessors added and targeted suite green.**
5. ~~Additional parity tests for multiclass (multinomial) and Cox families.~~ **CLOSED 2026-05-08. 7 new test cases added; see PROGRESS.md.**
6. ~~Initial CRAN-prep hardening pass.~~ **CLOSED 2026-05-10. Package-code `R CMD check --no-manual` is `Status: OK`; full manual check has only local TeX `inconsolata.sty` warning.**
7. ~~FDR graph vignette mismatch: documented horizontal FDP target line missing from `plot_fdr_graph()`.~~ **CLOSED 2026-05-12. Helper now draws `fdr_target = 0.05` by default; targeted plotting tests green.**
8. ~~Intro-vignette toy simulations over-selected in regression because low-penalty lambda values made noise features stable.~~ **CLOSED 2026-05-12. Binary and regression examples now use independent planted-support simulations and compact strong-penalty lambda grids; render green.**
9. ~~Intro-vignette clarity pass for new users while preserving introductory scope.~~ **CLOSED 2026-05-12. Added input-shape orientation, smoother selected-feature interpretation, explicit plot-saving pattern, and less formulaic prose; single-vignette render green.**
10. ~~Post-audit `stabl_refit()` / multinomial cooperative-fusion gaps from `audit/00_summary.md`.~~ **CLOSED 2026-05-14. Added `stabl_refit` to pkgdown, centralized refit-argument validation, hardened `predict.stabl_refit()` newdata row IDs, improved class-loss/two-class cooperative diagnostics, and added audit-level guards; full local suite `FAIL 0`, `WARN 2`, `SKIP 2`, `PASS 1596`.**
11. Keep local deterministic validation green for every forward change.
12. Keep Python-path API compatibility in source (`stabl/`) without notebook-local monkeypatching.
13. Next CRAN-prep priority: decide whether to install/fix local TeX manual tooling or defer manual PDF validation to CI/CRAN-like builders.
14. For the AURORA baseline scratch analysis, treat
    `scratch/01_costablr_core_basemalvac.ipynb` as feasibility only. The current
    notebook uses multinomial elastic net to classify study group
    (`EG`, `GA`, `TU`) for the `cytof_celltype` pilot and core three-view
    extension; any promoted analysis must rerun with an explicit
    validation/resampling design and a parameter grid justified for inference.
    The feasibility notebook uses `bootstrap_strata = data.frame(study_group)`
    to preserve target-class composition during bootstrap subsampling. P/NP
    status is retained only for QC tables and descriptive plot point shapes.
    The CyTOF pilot also includes a descriptive top-5-per-study-group predictor
    plot that overlays class-specific elastic-net betas on global STABL
    stability scores; this is not inferential validation.
14. For the guided AURORA all-view baseline analysis, use
    `scratch/01_costablr_baseline_groups_test.ipynb` as the full baseline
    SLURM control center, not as an in-kernel execution notebook. It now
    audits expected caches, plans reruns, submits guarded nonblocking `sbatch`
    jobs, tails logs, loads caches only, and renders report sections that skip
    when artifacts are absent. Heavy execution remains centralized in
    `scratch/scripts/run_costablr_baseline_groups_branch.R` and the paired
    SLURM wrappers. The branch array now covers the current public
    `family = "multinomial", cooperative_fusion = TRUE` automatic OVR
    cooperative workflow in addition to the older CyTOF, single-view,
    early-fusion, late-fusion, manual cooperative OVR, and nested-CV branches.
    Baseline branch fits enforce stratified bootstraps through
    `stratify_bootstrap = TRUE` with explicit study-group bootstrap strata
    (plus outcome strata for one-vs-rest branches). As of 2026-05-14 the
    notebook and paired SLURM wrappers default to a publication-scale rerun
    envelope (`1000` bootstraps, `50` lambdas, `mvr_knockoff`, full artificial
    proportion, and `10000` late-fusion draws).  Single-view and early-fusion
    branches now cache `stabl_refit()` final models and refit prediction
    tables in addition to the selector object.  Before treating results as
    biological evidence, launch the guarded rerun from the notebook dashboard,
    monitor all dependent jobs there, and document nested-CV and sensitivity
    results in `PROGRESS.md`.
15. For AURORA baseline binary study-group comparisons, use
    `scratch/04_costablr_baseline_binary_comparisons.ipynb`. It is the
    SLURM-cached companion to the multinomial notebook and evaluates
    `EG_vs_GA_TU`, `GA_vs_EG`, and `TU_vs_EG` as explicit binomial contrasts.
    Branch artifacts are isolated under
    `scratch/cache/costablr_baseline_binary_comparisons/<contrast>/` and
    `scratch/outputs/costablr_baseline_binary_comparisons/<contrast>/`.
    Heavy branches should run through
    `scratch/scripts/run_costablr_baseline_comparisons_branch.R` and
    `scratch/slurm/costablr_baseline_comparisons_*.slurm`; the notebook defaults
    to cached branch consumption and should not replace the original
    multinomial workflow. The notebook has been executed end-to-end in
    `R4_51`; keep the helper fallback rooted on `COSTABLR_REPO_ROOT` so
    notebook-directory execution does not create nested `scratch/scratch`
    paths. As of 2026-05-14 it has the same guarded SLURM dashboard,
    publication-scale defaults, refit-artifact audit, metrics, feature plots,
    and figure gallery as the multinomial notebook. The old visualization
    array `24758968` failed because `conda` was not on the batch-job `PATH`;
    the renamed SLURM scripts now use an explicit `${CONDA_EXE:-.../conda}`
    fallback and visualization rerun `24766406` completed all three contrast
    tasks with exit code `0:0`.
16. For crossed AURORA study-by-protection exploration, use
    `scratch/03_costablr_baseline_study_protection_test.ipynb`. It is a copied
    cache-first all-view workflow targeting six labels (`EG_P`, `EG_NP`,
    `TU_P`, `TU_NP`, `GA_P`, `GA_NP`) with default `SAMPLE_FRACTION = 0.9`,
    six-class multinomial branches, direct binomial OVR branches, and
    cooperative OVR branches. Heavy work should run through
    `scratch/scripts/run_costablr_baseline_study_protection_branch.R` or
    `scratch/slurm/costablr_baseline_study_protection_*.slurm`; the notebook
    is now a guarded SLURM launchpad/monitor and direct OVR prediction uses the
    current `stabl_refit()` cache path. Treat this workflow as exploratory
    because `TU_NP` has only 3 baseline samples, so its nested/cooperative fold
    defaults remain smaller than the main three-class workflow.
17. For the focused AURORA study-group plus P/NP request, use
    `scratch/02_costablr_baseline_group_protection_test.ipynb`. It keeps the
    exact six-class order `EG_P`, `EG_NP`, `TU_P`, `TU_NP`, `GA_P`, `GA_NP`
    and adds per-study `P` vs `NP` comparisons for `EG`, `TU`, and `GA`.
    Heavy branches should run through
    `scratch/scripts/run_costablr_baseline_group_protection_branch.R` or
    `scratch/slurm/costablr_baseline_group_protection_*.slurm`. As of
    2026-05-14 it is also a guarded SLURM dashboard with refit prediction
    audits and cache-only visualization summaries. This workflow is
    intentionally narrower than the six-group study-protection notebook:
    single-view, early-fusion, and late-fusion caches only; no cooperative OVR
    or nested CV by default.
18. ~~Add MVR knockoffs and rename the model-X artificial-feature option.~~
    **CLOSED 2026-05-13.** The old `"knockoff"` option was intentionally
    removed for pre-release costablr and replaced by `"modelx_knockoff"`;
    `"mvr_knockoff"` now provides a RcppArmadillo-backed MVR Gaussian
    knockoff path with a pure-R reference fallback.
    Acceptance criteria: old option errors with valid choices, model-X path
    still uses optional `knockoff`, MVR S matrices satisfy PSD feasibility, MVR
    artificial features preserve the `x_augmented`/`noise_col_indices` schema,
    targeted artificial-feature tests pass, and the native solver matches the
    installed `knockpy` reference on a fixed coordinate-update path.
19. ~~Remediate the May 13 comprehensive audit findings.~~
    **CLOSED 2026-05-13.** Fixed INT-001 through INT-006 and IMPL-001 through
    IMPL-007 in dependency order. The follow-up performance tranche fixed
    PERF-001, PERF-002, PERF-003, PERF-005, PERF-006, and NAT-002; NAT-001
    and NAT-003 remain deferred skipped placeholders. Latest closure signal
    after post-audit hardening: full local test directory passes with
    `FAIL 0`, `WARN 2`, `SKIP 2`, `PASS 1596`;
    `devtools::check()` has `0 errors`, with only local
    `qpdf`/timestamp/toolchain warnings/notes; `pkgdown::check_pkgdown()`
    reports no problems after indexing `stabl_refit`.
20. ~~Monitor renamed scratch visualization rerun.~~ **CLOSED 2026-05-13.**
    Scratch AURORA notebooks, helpers, SLURM scripts, cache roots, and output
    roots are now `costablr_*` namespaced under the standalone repository. All
    four renamed notebooks execute from cache without error outputs. Binary
    comparison visualization rerun `24766406` completed all three contrast
    tasks with exit code `0:0`, and per-contrast visualize caches, figures, and
    tables are present.
21. ~~Annotate comprehensive-audit finding closure across `audit/`.~~
    **CLOSED 2026-05-13.** Each audit document now states whether its findings
    are fixed, deferred, or not planned. Closure signal: audit test subset
    passes fixed INT/IMPL/performance assertions with only the two intentional
    NAT-001/NAT-003 placeholder skips.
22. ~~Run the profiling-gated medium performance optimization tranche.~~
    **CLOSED 2026-05-13.** Added old-reference performance tests and
    `scripts/profile_audit_performance.R`; kept only optimizations clearing the
    strict 10% runtime-or-allocation gate. Implemented chunked binary stacking,
    vectorized multiclass stacking, vector `glmnet`/`sparsegl` coefficient
    extraction with fallback, prepared grouped-bootstrap samplers, and the
    NAT-002 Rcpp correlation-union helper. PERF-004, PERF-007, and PERF-008
    remain deferred low-severity opportunities.
23. ~~Complete package robustness audit and binary stacking hardening.~~
    **CLOSED 2026-05-14.** Added
    `audits/PACKAGE_ROBUSTNESS_AUDIT.md`, fixed binary
    `stacked_multi_omic()` outcome coercion for factor/character/logical
    labels, added CRIT-001 regression tests, cleaned package-build excludes,
    and removed the dead DESCRIPTION URL. Acceptance signal: full local tests
    pass with no failures; final `rcmdcheck --no-manual --as-cran` has
    `0 errors`, with only local/release hygiene warning-note items remaining.

## Remediation Audit Execution Status (2026-05-08)

- Implemented (code/tests/docs): WI-01, WI-02, WI-03, WI-04, WI-05, WI-07, WI-08,
  WI-09, WI-10, WI-11, WI-12, WI-13, WI-14, WI-15, WI-16.
- Reclassified by source-of-truth check against Python reference:
  - H-2 to TEST-ONLY (Python random-permutation source draw is `replace=False`).
  - M-1 closed after implementation parity hardening
    (`bootstrap_threshold` exposed with Python's effective `1e-5` default and
    sklearn-style threshold syntax/comparator).
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
  - `costablr-cooperative.Rmd` now renders to `costablr-cooperative.html`.
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
conda run -n R4_51 Rscript -e "testthat::test_local('.')"
```

### Fix 1 — `get_support` explore fallback over-selects on tied scores [SEVERITY 1]

**File:** `R/stabl_accessors.R`  
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
**Test to add:** In `tests/testthat/test-stabl-accessors.R` (or create `test-get-support.R`):
- Fit with `hard_threshold = 0.99` so nothing passes. Set `explore = TRUE, n_explore = 3`.
- Verify `sum(get_support(fit))` is exactly 3, not the full feature count.
- Verify the 3 selected features are the ones with the highest `get_importances()` scores.

---

### Fix 2 — `group_bootstrap_indices` `replace = FALSE` not enforced across draws [SEVERITY 2]

**File:** `R/bootstrap_helpers.R`  
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

**File:** `R/stabl_fit.R`  
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

### Fix 4 — `make_modelx_knockoff_features` chunked path loses original feature index mapping [SEVERITY 2, only affects p > 3000]

**File:** `R/artificial_features.R`  
**Function:** `make_modelx_knockoff_features`, chunked branch (`n_features > 3000`).
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
**Test to add:** This path only fires at p > 3000. Add a test with `n_features = 3001` (small `n` is OK, e.g. 20 rows), `modelx_knockoff` type, and SGL base learner. Verify `stabl_fit` completes without error and `length(fit$stabl_scores_)` equals `n_features`.

---

### Fix 5 — `stabl_fit` result list holds all bootstrap matrices simultaneously (peak memory) [SEVERITY 3]

**File:** `R/stabl_fit.R`  
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

**File:** `R/bootstrap_helpers.R`  
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

**File:** `R/stabl_fit.R`  
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
- Create package skeleton under `.`
- Establish S3 object contracts and migration map

2. Core contracts
- Implement strict alignment validators for predictors/outcomes/groups
- Implement canonical input coercion rules for multi-omic lists

3. Core STABL engine
- Bootstrap samplers (classic + grouped)
- Lambda-grid iteration and stability accumulation
- Artificial features: random permutation, model-X knockoff, and MVR knockoff
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

1. `R/multiomic_workflows.R` owns cooperative workflow orchestration and additive diagnostics.
2. `R/input_validation.R` owns cooperative argument normalization and family/selector guards.
3. `tests/testthat/test-multiomic-workflows.R` is the behavior-regression surface for cooperative hardening.
4. `R/stabl_accessors.R` owns cooperative print/report ergonomics and public cooperative accessors.
5. `MultiView.md` remains the cooperative design/evidence bridge.

Promotion criteria:

- Deterministic behavior-level cooperative tests pass.
- Optional-dependency failure paths are validated and stable.
- Public cooperative result inspection does not require direct `$` traversal.
- Operator-facing docs (`HANDOFF.md`) and factual logs (`PROGRESS.md`) remain synchronized.

## Maintenance Notes

- 2026-05-18: Refactoring roadmap PR-5 is closed. Threshold resolution for
  STABL support selection now lives in private `.resolve_threshold()` and is
  shared by `get_support.stabl_fit()` and `plot_stabl_path()`. The next
  roadmap item remains the additive artificial-feature fallback diagnostic
  (PR-7); no algorithm-semantic change is open.
- 2026-05-18: Refactoring roadmap PR-7 is closed. Artificial-feature
  generators now preserve existing return fields and add diagnostic metadata;
  `stabl_fit()` records the actual method as `artificial_type_used_`. The next
  roadmap item is PR-8 nested-CV parallelism documentation/warning.
- 2026-05-18: Refactoring roadmap PR-8 is closed. Nested CV now documents and
  warns about combining fold-level `cv_workers` with STABL bootstrap
  `workers` or a non-sequential active `future` plan. The next roadmap item
  is PR-9 extraction of shared CV helpers after characterization tests.
- 2026-05-18: Refactoring roadmap PR-9 is closed. Shared multiomic and nested
  fold helpers now live in `R/cv_helpers.R`, with fixed-seed characterization
  tests in `tests/testthat/test-cv-helpers.R`. The next roadmap item is PR-10
  extraction of late-fusion/stacking helpers.
- 2026-05-18: Refactoring roadmap PR-10 is closed. Exported
  `stacked_multi_omic()` and late-fusion/stacking helpers now live in
  `R/late_fusion.R`. The next roadmap item is PR-11 cooperative-fusion
  extraction.
- 2026-05-18: Refactoring roadmap PR-11 is closed. Cooperative-fusion helpers
  now live in `R/cooperative_fusion.R`, and `R/multiomic_workflows.R` is below
  the <800-line target. The next documentation step is the safer PR-2A
  architecture/TODO/contributing consolidation without moving canonical agent
  docs.
- 2026-05-18: Refactoring roadmap PR-2A is closed. `ARCHITECTURE.md`,
  `TODO.md`, and `CONTRIBUTING.md` now provide human-facing maintainer docs,
  and source-package check is clean with 0 errors, 0 warnings, and 0 notes.
  Physical archiving of canonical session docs remains deferred pending
  explicit maintainer confirmation.
- 2026-05-18: PR-12 safety prep is complete. Parallel determinism tests now
  pin `stabl_fit()` `workers = 1` vs `workers = 2` and nested CV
  `cv_workers = 1` vs `cv_workers = 2`. No backend migration has been made;
  PR-12 remains pending explicit confirmation because it is high risk.
- 2026-05-18: Final validation for the refactoring roadmap pass is complete:
  full `devtools::test()` has no failures, `pkgdown::check_pkgdown()` reports
  no problems, `rcmdcheck --no-manual` is clean with 0 errors, 0 warnings, and
  0 notes, and `git diff --check` is clean.
- 2026-05-18: Agent-skills repository configuration is in place for future
  engineering-skill runs. Skills such as `to-issues`, `triage`, `to-prd`,
  `diagnose`, `tdd`, `improve-codebase-architecture`, and `zoom-out` should
  read `docs/agents/` for the GitHub issue tracker, default triage labels,
  and single-context domain-doc layout; no roadmap gate is open from this
  setup-only change.
- 2026-05-14: All active scratch costablr SLURM workflows were resubmitted
  from preprocessing after raw-data file paths were fixed. Track the fresh
  job chain `24773426` through `24773436` from the notebook dashboards or
  Slurm directly. No new roadmap gate is open; any failed job requires user
  confirmation before patching, cancellation, or resubmission.
- 2026-05-14: Recent-changes robustness follow-up is closed for the two
  actionable items. Compiled `src/*.o` and `src/*.so` artifacts were removed
  from the git index and working tree, then ignored for both git and R source
  builds. Nested-CV selected-candidate final refit now restores the
  majority-class fallback when final refit or final prediction fails. The
  optional OVR fold-stratification warning and MVR discriminant edge remain
  deferred; no roadmap gate is open.
- 2026-05-13: Predictive STABL workflows now include a compulsory
  unpenalized final refit after selection. `stabl_fit()` remains the
  low-level selector; `stabl_refit()` owns the single-matrix end-to-end
  workflow; multi-omic train/validate results now carry per-omic `$refits`,
  early fusion carries `$early_fusion$refit`, late fusion reuses the same
  refits, and nested CV selected-candidate evaluation uses the shared refit
  helper. Implementation evidence is logged in `PROGRESS.md`; no additional
  roadmap gate is open.
- 2026-05-13: The R package moved from the previous monorepo package
  subdirectory into the standalone repository
  `/exports/para-lipg-hpc/mdmanurung/costablr`, with `DESCRIPTION` at the
  repository root and package identity renamed to `costablr`.
  Public STABL function/class names such as `stabl_fit()` remain unchanged.
- 2026-05-12: Quick-start vignette regression simulation should keep gaussian
  outcomes as named numeric vectors. The immediate implementation fix is logged
  in `PROGRESS.md`; no roadmap or acceptance-gate change is required.
- 2026-05-13: Knockoff artificial-feature generation now uses Gaussian
  model-X construction via `knockoff::create.gaussian()` with estimated,
  regularized moments. This supersedes the previous constructor note and is
  logged in `PROGRESS.md`; no roadmap or acceptance-gate change is required.
- 2026-05-13: Public artificial-feature option names are now
  `"random_permutation"`, `"modelx_knockoff"`, and `"mvr_knockoff"`. The old
  `"knockoff"` option was removed while costablr remains pre-release. The MVR
  implementation now uses a RcppArmadillo solver by default and retains the
  pure-R solver as a reference fallback.
- 2026-05-12: `costablr-multiomic.Rmd` now explicitly states that it is a bounded
  OOL package example rather than a full reproduction of the Python tutorial
  notebook. Tutorial-dataset parity remains owned by `costablr-python-parity.Rmd`;
  no roadmap or acceptance-gate change is required.
- 2026-05-12: `costablr-python-parity.Rmd` now runs the repository tutorial data
  path with notebook-scale OOL/COVID settings and reports selected-feature
  overlap against `Notebook examples/Tutorial Notebook.ipynb`. The fresh render
  recovered all 7 OOL tutorial features and all 6 COVID tutorial features; no
  roadmap or acceptance-gate change is required.
- 2026-05-12: Ignored scratch notebook
  `scratch/01_costablr_core_basemalvac.ipynb` was repurposed from baseline P vs
  NP adaptive lasso to baseline study-group multinomial elastic net
  (`EG`, `GA`, `TU`) while retaining P/NP only for QC displays. This is a
  scratch analysis update; no roadmap or acceptance-gate change is required.
- 2026-05-13: Review follow-up narrowed scratch ignore rules so workflow
  notebooks/scripts/SLURM files are trackable while generated artifact
  directories remain ignored, and hardened bootstrap-strata alignment for
  numeric-looking sample IDs. This is a maintenance patch; no roadmap or
  acceptance-gate change is required.
- 2026-05-13: `scratch/02_costablr_baseline_group_protection_test.ipynb` now
  shows early-fusion selected-feature boxplots separately for `EG_P` vs
  `EG_NP`, `TU_P` vs `TU_NP`, and `GA_P` vs `GA_NP`. This is a scratch
  notebook presentation update; no roadmap or acceptance-gate change is
  required.
- 2026-05-13: The comprehensive audit remediation is closed.  The additive
  audit tests now assert fixed behavior; stale bug snapshots were removed; the
  Python-parity vignette and pkgdown metadata were refreshed; and package
  build ignores now exclude repository-only sample/notebook/audit assets from
  R source builds.  Remaining native candidates NAT-001 through NAT-003 are
  deferred to a separate profiling-driven track.
