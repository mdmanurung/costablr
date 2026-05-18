# HANDOFF: Session Bootstrap and Parity Ledger

**Purpose:** Live operator snapshot and immediate executable queue for fresh Copilot sessions.

**This document owns:**
- Current workspace state (what is live right now).
- Immediate next 3 executable tasks.
- Command entrypoints and expected signals.
- Runtime constraints that must be preserved.
- Lightweight parity status delta.

**This document does NOT own:**
- Completed work history and evidence (→ PROGRESS.md)
- Future scope and acceptance gates (→ PLAN.md)
- Algorithm semantics and parity rules (→ STABL.md)
- Workflow policy and governance (→ AGENTS.md)

**Cross-reference pattern:** For detailed evidence and past work, check PROGRESS.md. For planning context and future priorities, check PLAN.md.

## Purpose

This file is the first-stop operational handoff for fresh Copilot sessions.

- Use this file first to recover current execution state.
- Use `PLAN.md` for roadmap sequencing and acceptance gates.
- Use `PROGRESS.md` for validated completed work and command evidence.
- Use `STABL.md` for parity-critical algorithm semantics.

## Operator Runbook

### What this file owns

- Live operator snapshot for the next session.
- Immediate executable queue (top 3 tasks only).
- Command entrypoints and pass/fail signals.

For details that must not be duplicated here:

- Future scope and acceptance gates: `PLAN.md`.
- Completed work and validation evidence: `PROGRESS.md`.
- Algorithm/parity semantics: `STABL.md`.

### Current state snapshot (live)

- Vignette narrative rewrite is in place across all six canonical sources under
  `vignettes/`.  The rewrite used an original, curiosity-driven
  scientific narrative voice and preserved executable code chunks and runtime
  settings.
- Parallel render validation for the five non-nested-CV vignettes completed as
  SLURM array job `24752130` using
  `inst/analysis/render_vignettes.slurm`.
  - Per-task resources: 6 CPUs, 128 GB RAM, 24H walltime.
  - Array targets: `costablr-intro.Rmd`, `costablr-multiomic.Rmd`,
    `costablr-python-parity.Rmd`, `costablr-tcga.Rmd`, and
    `costablr-cooperative.Rmd`.
  - `costablr-tcga-nestedcv.Rmd` was intentionally excluded from this render
    array because its benchmark cache is managed by the separate nested-CV
    workflow.
  - Log check: HTML output was created for all five array targets; no failed
    render signal was observed in
    `inst/analysis/cache/vignette-renders/`.
- TCGA nested-CV head-to-head scaffold is in place:
  - exported `stabl_multiomic_nested_cv()` supports stratified folds,
    custom categorical strata, numeric-strata quantile binning, and
    outer-fold parallelism via `cv_workers` on the shared `future`/`furrr`
    backend;
  - `vignettes/costablr-tcga-nestedcv.Rmd` renders from cache or
    prints the SLURM command when the cache is absent;
  - `inst/analysis/run_tcga_nestedcv.R` now runs the cached
    costablr-vs-DIABLO TCGA benchmark with resumable per-fold checkpoints for
    both arms and arm-level RDS files;
  - full SLURM job `24750538` timed out after `2-00:00:10` before writing
    `inst/analysis/cache/tcga_nestedcv_results.rds`;
  - checkpointed rerun job `24812727` was submitted on 2026-05-18 and was
    initially `RUNNING` on `res-hpc-exe101`.
- Workspace mode: May 13 audit remediation is closed; local package checks now
  have 0 errors, with only environment/toolchain warning/note items remaining.
- Latest package robustness audit signal: `audit/PACKAGE_ROBUSTNESS_AUDIT.md`
  was added. CRIT-001 is fixed in `stacked_multi_omic()` so binary stacking
  now normalizes numeric/logical 0/1 and two-level factor/character outcomes,
  preserving missing-outcome skip behavior. Targeted audit tests and the full
  local suite pass; final `rcmdcheck --no-manual --as-cran` has 0 errors, 1
  qpdf warning, and 3 notes (new submission/dev version, conda
  `-march=nocona`, and `stabl_fit()` example elapsed time). `lintr` currently
  reports 847 backlog findings; `goodpractice` is unavailable in `R4_51`.
- Latest audit-document signal: all files under `audit/` now explicitly state
  whether each finding is fixed, deferred, or not planned. INT-001 through
  INT-006, IMPL-001 through IMPL-007, and medium performance findings
  PERF-001, PERF-002, PERF-003, PERF-005, and PERF-006 are marked fixed.
  NAT-002 is fixed by `corr_groups_from_corr_cpp()`; PERF-004, PERF-007,
  PERF-008, NAT-001, and NAT-003 remain deferred, and NAT-004 through NAT-006
  remain not planned for first-pass native work. Audit test subset passes with
  only the two intentional NAT skips.
- Latest performance-gate signal: `scripts/profile_audit_performance.R`
  compares old-reference helpers against current implementations with fixed
  seeds, `system.time()`, `Rprofmem()`, and a strict 10% runtime-or-allocation
  gate. KEEP decisions were recorded for PERF-001, PERF-002, PERF-003,
  PERF-005, and PERF-006; NAT-003 is info-only and still deferred.
- R4_51 install status: local `costablr` source package installed from
  `.` into the conda env library; exact-location load check reports
  version `0.0.0.9000`.
- Latest plotting fix: `plot_fdr_graph()` now draws the documented horizontal
  FDP target line by default at `fdr_target = 0.05`; local source was
  reinstalled into the default `R4_51` library after the fix.
- Latest artificial-feature signal: the old `"knockoff"` option was removed
  and replaced by `"modelx_knockoff"`; `"mvr_knockoff"` uses a
  RcppArmadillo-backed Gaussian MVR solver with a pure-R reference fallback.
  The direct model-X helper now honors its `random_state` argument with scoped
  RNG restoration. Refactoring PR-7 is closed: artificial-feature generators
  now add `type_requested`, `type_used`, and `fallback_used`, and `stabl_fit()`
  persists `artificial_type_used_`; targeted artificial/MVR/STABL tests pass.
- Latest refactoring-roadmap signal: PR-5 is closed. Private
  `.resolve_threshold()` now owns support-threshold fallback and validation for
  `get_support.stabl_fit()` and `plot_stabl_path()`. Targeted accessor,
  visualization, and audit tests pass in `R4_51`.
- Nested-CV parallelism signal: refactoring PR-8 is closed. Nested CV documents
  and warns about combining outer-fold `cv_workers` with STABL bootstrap
  `workers`.
- CV-helper refactoring signal: PR-9 is closed. Shared private fold helpers
  now live in `R/cv_helpers.R`; `tests/testthat/test-cv-helpers.R` pins
  fixed-seed assignments for multiomic, grouped, nested, and repeated folds.
- Late-fusion refactoring signal: PR-10 is closed. Exported
  `stacked_multi_omic()` and private stacking helpers now live in
  `R/late_fusion.R`; `multiomic_workflows.R` is down to 1436 lines.
- Cooperative-fusion refactoring signal: PR-11 is closed. Cooperative helpers
  now live in `R/cooperative_fusion.R`; `multiomic_workflows.R` is down to
  754 lines while public workflow APIs are unchanged.
- Maintainer-docs signal: PR-2A is closed. `ARCHITECTURE.md`, `TODO.md`, and
  `CONTRIBUTING.md` provide the human-facing codebase map and contribution
  rules without moving canonical agent/session docs. `rcmdcheck --no-manual`
  is clean with 0 errors, 0 warnings, and 0 notes.
- Parallelism signal: PR-12 is closed. `stabl_fit()` and
  `stabl_multiomic_nested_cv()` now share a scoped `future`/`furrr`
  multisession backend for `workers > 1` and `cv_workers > 1`; the old
  nested-CV `parallel::mclapply()` path is gone. Determinism tests, full
  `devtools::test()`, `pkgdown::check_pkgdown()`, and `git diff --check` are
  green, with only the existing NAT skips and future build-version warnings.
- Latest bootstrap-threshold parity signal: `stabl_fit()` now exposes
  `bootstrap_threshold` with Python STABL's effective default `1e-5`.  The
  learner adapters use sklearn-style `>=` per-bootstrap coefficient
  thresholding and accept `NULL`, numeric thresholds, `"mean"`, `"median"`,
  and scaled forms such as `"1.25*mean"`.  Focused `test-stabl-fit.R` passes.
- Latest STABL parity-audit signal: `STABL.md` was checked against upstream
  Python commit `1d07f85a13cfbecb4f08ce21075bf4fbb8e34678`. The audit
  confirmed core selector/FDP+ parity and refreshed documentation for stale
  upstream line anchors, Python `"knockoff"` versus R `"modelx_knockoff"`,
  and the intentional R `explore = TRUE` tie-handling hardening difference.
- Validation policy: local R suite is authoritative for this workspace (CI deferred by scope).
- Cooperative fusion: promoted workflow-layer extension (non-parity-blocking). Hardening milestone CLOSED 2026-05-08 (M12); promotion accessor milestone CLOSED 2026-05-10. Public inspection surface now includes `get_cooperative_features()` and `get_cooperative_diagnostics()`.
- Latest verified full-suite signal after post-audit `stabl_refit()` /
  cooperative-fusion hardening: `Sys.setenv(NOT_CRAN='true'); devtools::test('.')`
  passes locally in `R4_51` with `FAIL 0`, `WARN 2`, `SKIP 2`, `PASS 1596`;
  warnings are the two existing `future` package build-version warnings, and
  skips are the intentional NAT-001 and NAT-003 placeholders.
- Latest recent-changes robustness follow-up: committed `src/*.o` and
  `src/*.so` artifacts were removed from the git index and working tree,
  matching ignore patterns were added to `.gitignore` and `.Rbuildignore`, and
  nested-CV final refit/predict now falls back to the training majority class
  when the shared final-refit helper errors. Targeted validation passed:
  `testthat::test_file('tests/testthat/test-nested-cv.R', reporter = 'summary')`
  in `R4_51` with only the existing testthat build-version warning.
- Latest verified package-check signal: `devtools::check('.', error_on =
  'never')` has `0 errors`, `1 WARNING`, and `2 NOTEs`; remaining items are
  missing local `qpdf`, timestamp verification, and the conda `-march=nocona`
  compile flag.
- Latest verified vignette signal: all 5 non-nested canonical source vignettes
  rendered successfully in SLURM array job `24752130` after the narrative
  rewrite (`costablr-cooperative`, `costablr-intro`, `costablr-multiomic`,
  `costablr-python-parity`, `costablr-tcga`).
- Latest verified documentation-site signal: `pkgdown::check_pkgdown()` reports
  no problems after adding the post-audit `stabl_refit` reference topic to
  `_pkgdown.yml`.
- Latest agent-skills setup signal: `AGENTS.md` now points engineering skills
  to `docs/agents/issue-tracker.md`, `docs/agents/triage-labels.md`, and
  `docs/agents/domain.md`. The configured defaults are GitHub Issues for
  `mdmanurung/costablr`, the canonical five triage labels, and a
  single-context domain-doc layout.
- Latest targeted plotting signal: `test-phase7.R` passes against local source
  (`PASS 83`, `FAIL 0`, `WARN 0`, `SKIP 0`).
- Latest intro-vignette signal: `costablr-intro.Rmd` renders successfully after a
  new-user clarity pass. It now includes an explicit input-shape section,
  clearer selected-feature interpretation, displayed diagnostic plots with
  optional save examples, and prose tightened to avoid formulaic tutorial style.
- Latest Python-parity vignette signal: `costablr-python-parity.Rmd` renders all
  42 chunks against repository tutorial data in `R4_51` with fresh cache
  rebuild after the `modelx_knockoff` and FDP-threshold text refresh.
- Latest scratch relocation signal: the moved AURORA scratch notebooks,
  helpers, runner scripts, SLURM scripts, cache roots, and output roots have
  been renamed from `stablr_*` to `costablr_*` under
  `/exports/para-lipg-hpc/mdmanurung/costablr`.  Active scratch files no
  longer contain functional references to the old repo root or standalone
  `stablr` package name.  The renamed SLURM scripts use
  `${CONDA_EXE:-/share/software/tools/miniconda/3.10/23.3.1/bin/conda}` so
  batch jobs do not depend on `conda` being on `PATH`.  All four renamed
  notebooks execute from cache to `/tmp/costablr_notebook_exec` with zero error
  outputs.
- Latest scratch-analysis signal: ignored notebook
  `scratch/01_costablr_core_basemalvac.ipynb` now runs the STABL-only AURORA
  baseline study-group feasibility workflow with multinomial elastic net. It
  predicts `EG`, `GA`, and `TU` across all eligible baseline samples,
  regardless of P/NP status, using a `cytof_celltype` pilot followed by a
  no-imputation core three-view extension (`cytof_celltype`,
  `exvivo_celltype`, `exvivo_enzyme`) with per-view fits and early fusion.
  The notebook includes a parameter audit table and passes
  `bootstrap_strata = data.frame(study_group)` so bootstraps preserve target
  class composition. P/NP status is QC-only context in tables and plot point
  shapes. The CyTOF pilot includes a top-5-per-study-group predictor plot that
  refits full-data multinomial elastic net on the same lambda grid, extracts
  class-specific betas, and overlays beta sign/magnitude on STABL stability.
  Notebook JSON, nbformat validation, R syntax parsing, baseline/core balance
  checks, and the CyTOF beta-overlay smoke fit pass in `R4_51`; observed
  warnings are package build-version warnings and the known small-class glmnet
  bootstrap warnings.
- Latest scratch dashboard refresh: all five active notebooks under `scratch/`
  are now guarded SLURM launchpad/monitor dashboards rather than in-kernel
  heavy runners. They share publication-scale defaults (`1000` bootstraps,
  `50` lambdas, `mvr_knockoff`, artificial proportion `1`, and `10000`
  late-fusion draws), expected-artifact dashboards, missing-output audits,
  `squeue`/`sacct` monitors, guarded `sbatch` chains, bounded log tailing,
  refit/metric/confusion summaries, feature plots, and generated-figure
  galleries. The guarded submit cell remains dry-run unless
  `COSTABLR_SUBMIT_JOBS=true`; `COSTABLR_FORCE_RECOMPUTE=TRUE` is exported by
  default when reruns are launched.
- Latest scratch API signal: scratch single-matrix branches now call
  `stabl_refit()` instead of selector-only `stabl_fit()`. Existing
  `stabl_fit_bundle.rds` cache names are preserved, but bundles now include
  both `fit` and `refit`, and classification branches export
  `stabl_refit_train_predictions.csv`, `stabl_refit_confusion_matrix.csv`, and
  `stabl_refit_metrics.csv`. The six-label direct OVR path now prefers these
  cached refit predictions, with the old selected-feature `glmnet` path left
  only for legacy cache fallback.
- Latest scratch SLURM submission signal: after the user fixed raw-data file
  paths, the publication-scale scratch workflows were resubmitted from
  preprocessing. Baseline `24773426` -> `24773427` -> `24773428`, group
  protection `24773429` -> `24773430`, and binary comparisons `24773434` ->
  `24773435` -> `24773436` completed. Study protection `24773431` ->
  `24773432` had branch `24773432_26` (`nested_cv`) fail immediately because
  glmnet saw a multinomial/binomial class with 1 or 0 observations; dependent
  visualization job `24773433` was cancelled. The manifest is recorded at
  `scratch/cache/slurm-submissions/resubmission_all_scratch_20260514_230003.tsv`
  and mirrored under `scratch/outputs/slurm-submissions/`. Do not patch or
  resubmit the study-protection nested-CV branch without user confirmation.
- Latest guided all-view scratch notebook:
  `scratch/01_costablr_baseline_groups_test.ipynb` is now the active
  nonblocking SLURM control center for the full AURORA baseline study-group
  workflow. It no longer runs heavy STABL, late-fusion, cooperative,
  nested-CV, preprocessing, or visualization work in the notebook kernel.
  Instead it provides dashboard, missing-output audit, guarded `sbatch`,
  queue/log monitoring, cache-only loading, and reports that skip cleanly when
  caches are absent. Heavy execution is centralized in
  `scratch/scripts/run_costablr_baseline_groups_branch.R` plus
  `scratch/slurm/costablr_baseline_preprocess.slurm` and
  `scratch/slurm/costablr_baseline_branches.slurm`.
  The branch array now has 19 tasks (`--array=0-18`) and includes the current
  package-level automatic multinomial OVR cooperative branch
  (`cooperative_multinomial_ovr`) in addition to CyTOF, all 11 single-view
  branches, early fusion, late fusion, manual cooperative OVR for `EG/GA/TU`,
  and nested CV. The shared baseline helper now passes
  `stratify_bootstrap = TRUE` explicitly for single-view and early-fusion
  `stabl_refit()` calls; all baseline fit paths use study-group bootstrap
  strata, with one-vs-rest branches also carrying outcome strata.
  The earlier `mvr_knockoff`, 500-bootstrap, 20-lambda rerun chain
  (`24766504` -> `24766506` -> `24766507`) is historical context; future
  reruns should use the refreshed dashboard defaults above. Latest validation:
  notebook JSON OK, nbformat OK, extracted R parse OK, helper and runner parse
  OK, SLURM `bash -n` OK, all five notebooks dry-run with submit disabled, and
  a tiny synthetic `stabl_refit` branch smoke exits 0.
- Latest baseline binary comparison notebook:
  `scratch/04_costablr_baseline_binary_comparisons.ipynb` is the SLURM-cached
  companion for explicit binomial contrasts. It evaluates `EG_vs_GA_TU`
  (`GA_TU` reference vs `EG` positive), `GA_vs_EG` (`EG` reference vs `GA`
  positive), and `TU_vs_EG` (`EG` reference vs `TU` positive). The notebook
  sources `scratch/scripts/costablr_baseline_comparisons_helpers.R`, defaults to
  cached branch consumption, and stores canonical artifacts under
  `scratch/cache/costablr_baseline_binary_comparisons/<contrast>/` and
  `scratch/outputs/costablr_baseline_binary_comparisons/<contrast>/`. The
  execution entrypoint is
  `scratch/scripts/run_costablr_baseline_comparisons_branch.R`, with paired SLURM
  scripts `scratch/slurm/costablr_baseline_comparisons_preprocess.slurm` and
  `scratch/slurm/costablr_baseline_comparisons_branches.slurm`. Full SLURM jobs
  completed for preprocessing `24758964` and model branches `24758967`. The old
  visualization array `24758968` failed immediately with `conda: command not
  found`; the renamed/hardened visualization rerun `24766406` completed all
  three contrast tasks with exit code `0:0` and produced per-contrast visualize
  caches, figures, and tables.
  Full local notebook execution now passes in `R4_51` via nbconvert with 18
  cells and no error outputs after fixing the comparison helper fallback to
  honor `COSTABLR_REPO_ROOT` before `getwd()`.
- Latest crossed-label AURORA scratch notebook:
  `scratch/03_costablr_baseline_study_protection_test.ipynb` is the copied
  six-group study-by-protection workflow. It targets `EG_P`, `EG_NP`, `TU_P`,
  `TU_NP`, `GA_P`, and `GA_NP` across the same 11 all-view baseline immune
  matrices, defaults to cached SLURM branch consumption, and keeps heavy local
  refits disabled. New branch helpers live in
  `scratch/scripts/run_costablr_baseline_study_protection_branch.R` and
  `scratch/scripts/costablr_baseline_study_protection_helpers.R`, with paired
  SLURM scripts under `scratch/slurm/`. The new preprocessing cache is present
  under `scratch/cache/costablr_baseline_study_protection_test/preprocess/` with
  38 samples, 11 views, counts `EG_P=6`, `EG_NP=4`, `TU_P=9`, `TU_NP=3`,
  `GA_P=8`, `GA_NP=8`, and zero missing values. Raw AURORA CSV paths were not
  available in this workspace, so the six-label preprocess branch derived this
  cache from the existing all-view preprocessing cache and recorded that source.
  Validation passed: SLURM `bash -n`, notebook JSON, extracted R parse,
  branch-runner help, preprocess smoke, reduced `ovr_stabl:TU_NP` smoke, and
  cache-loading notebook smoke with heavy branches skipped and no refits.
- Latest focused group-protection AURORA notebook:
  `scratch/02_costablr_baseline_group_protection_test.ipynb` is the requested
  focused cache-first workflow. It keeps the six-class order
  `EG_P`, `EG_NP`, `TU_P`, `TU_NP`, `GA_P`, `GA_NP`, and adds within-study
  `P` vs `NP` comparisons for `EG`, `TU`, and `GA`. New helpers live in
  `scratch/scripts/costablr_baseline_group_protection_helpers.R` and
  `scratch/scripts/run_costablr_baseline_group_protection_branch.R`, with
  paired SLURM scripts
  `scratch/slurm/costablr_baseline_group_protection_preprocess.slurm` and
  `scratch/slurm/costablr_baseline_group_protection_branches.slurm`. The
  workflow reuses the existing baseline study-group preprocessing cache, then
  writes isolated artifacts under
  `scratch/cache/costablr_baseline_group_protection_test/` and
  `scratch/outputs/costablr_baseline_group_protection_test/`. Validation passed:
  SLURM `bash -n`, notebook JSON, extracted R parse, runner help, reduced
  preprocess smoke with counts `EG_P=6`, `EG_NP=4`, `TU_P=9`, `TU_NP=3`,
  `GA_P=8`, `GA_NP=8`, reduced joint CyTOF single-view smoke, reduced
  `within:TU:single_view:cytof_celltype` smoke, reduced
  `within:TU:late_fusion` smoke, and notebook cache-loading smoke with heavy
  local branch execution disabled. The notebook now also displays cached
  early-fusion selected-feature boxplots in separate sections for `EG_P` vs
  `EG_NP`, `TU_P` vs `TU_NP`, and `GA_P` vs `GA_NP`; helper validation found
  4, 10, and 3 selected features respectively. Full branch arrays `24759581`
  and `24759594` completed.
- Latest bootstrap API signal: `stabl_fit()` now accepts `bootstrap_strata`
  for arbitrary categorical bootstrap stratification designs; defaults remain
  unstratified, and `stratify_bootstrap = TRUE` is retained as outcome-only
  shorthand. Grouped `replace = TRUE` sampling can now reuse whole groups
  without stalling under stratified targets. Targeted helper, `stabl_fit`, and
  multiomic workflow tests are green.
- Latest FDP+ parity signal: the R default `fdr_threshold_range` is now
  `seq(0, 0.99, by = 0.01)`, matching Python STABL's
  `np.arange(0., 1., .01)`. The active scratch notebook is the study-group
  multinomial elastic-net analysis noted above.
- Latest multi-omic API signal: auto-lambda calls now forward `l1_ratio`
  through `stabl_fit()`, `stabl_multiomic_train_validate()`,
  `stabl_multiomic_cv()`, and nested CV. Multiclass late fusion is supported
  through per-view class-probability stacking and log-loss optimization, with
  class-prior fallback when a view selects no features. Stacking now errors
  when multiclass outcome labels are absent from probability columns, and
  `stabl_multiomic_cv()` now accepts unnamed full-length bootstrap strata
  aligned to input row order before per-fold subsetting. The active AURORA
  notebook and branch helper now compute macro F1 with omitted predicted
  classes contributing 0 rather than being dropped. Cooperative fusion now
  supports `family = "multinomial"` through an automatic one-vs-rest binomial
  `multiview` wrapper; native multinomial `multiview` optimization remains
  out of scope. The copied notebook
  `scratch/05_costablr_baseline_groups_multinomial_ovr_test.ipynb` is now a
  nonblocking SLURM control center for only the automatic multinomial OVR
  cooperative branch. It audits missing outputs, builds a dry-run submission
  plan, uses a guarded `sbatch` cell with `SUBMIT_JOBS <- FALSE` by default,
  tails SLURM logs, loads caches only, and skips reports cleanly when the
  cooperative cache is absent. The scratch runner exposes
  `cooperative_multinomial_ovr`, and the helper can reuse
  `costablr_baseline_groups_test` preprocessing through
  `COSTABLR_SOURCE_CACHE_DIR`.
- Vignette source policy: edit `vignettes/*.Rmd`; `doc/` is
  generated by `devtools::build_vignettes()` / `R CMD build` and is ignored.

### Remediation continuation snapshot (2026-05-08)

- Audit remediation implementation batch is in place (WI-01/02/03/04/05/07/08/09/10/11/12/13/14/15/16).
- Option-1 decision for WI-13 is applied: API-level guards are pinned via
	[tests/testthat/test-multiomic-guards.R](tests/testthat/test-multiomic-guards.R)
	against the real public entrypoint `stabl_multiomic_train_validate()`.
- Test execution blocker is cleared in `R4_51`; full suite has been executed.
- Remediation closure is complete in this continuation:
	- `[ FAIL 0 | WARN 0 | SKIP 4 | PASS 1343 ]` from
	  `Rscript -e "devtools::load_all('.'); testthat::test_local('.')"`.
	- Resolved contexts: `bootstrap-helpers`, `fdp-plus-invariants`,
	  `input-validation`, `multiomic-guards`, `python-parity-fixtures`,
	  `fdp-calibration`, `signal-recovery`.

### Immediate next tasks (updated)

1. Monitor checkpointed TCGA nested-CV SLURM job `24812727` with
   `squeue -j 24812727` / `sacct -j 24812727`. Logs are
   `inst/analysis/cache/tcga_nestedcv-24812727.out` and
   `inst/analysis/cache/tcga_nestedcv-24812727.err`.
2. When job `24812727` finishes, confirm
   `inst/analysis/cache/tcga_nestedcv_results.rds`,
   `tcga_nestedcv_costablr.rds`, `tcga_nestedcv_diablo.rds`, and the CSV
   exports are complete.
3. Render `vignettes/costablr-tcga-nestedcv.Rmd` from the completed TCGA
   nested-CV cache and record the output path and result signal in
   `PROGRESS.md`.

### Vignette runtime profile (2026-05-10)

- `costablr-intro.Rmd` is the single-omic introductory vignette: simulated data
  with explicit planted supports, compact strong-penalty lambda grids,
  40-50 bootstraps, and concise interpretation guidance for new users.
- Real-data vignettes remain realistic; most are bounded, while
  `costablr-python-parity.Rmd` intentionally uses notebook-scale settings when
  repository tutorial data are available:
  - OOL multi-omic: 80 bootstraps, 15 lambda values, 500 late-fusion iterations.
  - Python-to-R mapping: OOL renders with 500 bootstraps, 10 lambda values, and
    knockoffs; COVID-19 renders with 1000 bootstraps, 10 lambda values, and
    random-permutation artificial features. Package builds without repository
    tutorial data fall back to the bundled OOL subset and skip COVID-19.
  - Cooperative fusion: compact OOL lambda/rho/fold settings; outer CV displayed
    but not evaluated by default.
  - TCGA: restored as `costablr-tcga.Rmd`, with 30 bootstraps, 12 lambda values,
    and tempdir exports.

### Cooperative touchpoints (implementation surfaces)

- Workflow orchestration: `R/multiomic_workflows.R`
- Cooperative guards/normalization: `R/input_validation.R`
- Regression surface: `tests/testthat/test-multiomic-workflows.R`
- Accessor/print ergonomics surface: `R/stabl_accessors.R`
- Design/evidence bridge: `MultiView.md`

### Runtime constraints to preserve

- `cooperative_fusion = FALSE` must preserve current top-level return shape.
- `multiview` remains optional and cooperative mode must fail cleanly when absent.
- `cooperation_selection = "validation"` is unsupported for `family = "cox"`.
- `cooperation_selector = "lambda.1se"` is valid only with `cooperation_selection = "cv"`.
- Outer fold construction behavior (`.make_multiomic_cv_folds()`) is stable; cooperative diagnostics are additive only.
- Cooperative result inspection should use `get_cooperative_features()` and
  `get_cooperative_diagnostics()` instead of relying on nested list internals.

### Command entrypoints

Run full suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('.')"
```

Run cooperative workflow suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('.', filter = 'multiomic-workflows')"
```

Run parity fixture suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('.', filter = 'python-parity-fixtures')"
```

Run artificial-feature regression suite:

```bash
conda run -n R4_51 Rscript -e "setwd('.'); devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-artificial-features-parity.R')"
```

Build vignettes:

```bash
conda run -n R4_51 Rscript -e "devtools::build_vignettes('.')"
```

Run TCGA nested-CV smoke workflow:

```bash
conda run -n R4_51 Rscript inst/analysis/run_tcga_nestedcv.R --cache /tmp/tcga_nestedcv_smoke.rds --force --smoke --cv-workers 1 --stabl-workers 1 --diablo-workers 1
```

Submit full TCGA nested-CV benchmark:

```bash
sbatch inst/analysis/tcga_nestedcv.slurm
```

Submit parallel render validation for rewritten non-nested vignettes:

```bash
sbatch inst/analysis/render_vignettes.slurm
```

Build pkgdown documentation website:

```bash
conda run -n R4_51 Rscript -e "pkgdown::build_site('.', examples = FALSE, install = FALSE)"
```

Install local `multiview` for cooperative validation:

```bash
conda run -n R4_51 R CMD INSTALL multiview
```

### Expected signals

- Pass: zero failures and no unexpected skips.
- Regression alert: dimension drift, lambda-grid row misalignment, threshold/support-mask behavior drift.
- Documentation hygiene: if `PLAN.md`, `PROGRESS.md`, and this handoff diverge, reconcile all three before ending the task.

## Lightweight parity delta ledger

- Core Python-frozen parity closure (gaussian/binomial/multinomial + elastic-net metrics/exports/visuals) is complete; authoritative evidence remains in `PROGRESS.md`.
- Cox remains non-applicable for Python-frozen parity anchors and is maintained through R-native hardening gates only.
- Cooperative fusion remains `costablr`-native, optional, and non-parity-blocking; it now has a promoted public inspection surface.
- Artificial-feature generation supports random permutation, model-X
  knockoffs via `knockoff::create.gaussian()`, and RcppArmadillo-backed MVR
  Gaussian knockoffs. The legacy `"knockoff"` option name is intentionally
  removed in favor of `"modelx_knockoff"` while costablr is pre-release;
  evidence is in `PROGRESS.md`.
- The multiomic vignette is a bounded OOL package workflow, not the Python
  tutorial parity workflow. For the tutorial datasets and preprocessing
  contract, use `costablr-python-parity.Rmd`; the multiomic vignette now states
  this boundary explicitly.
- Ignored scratch notebook `scratch/01_costablr_core_basemalvac.ipynb` is now
  configured for baseline study-group multinomial elastic-net classification
  (`EG`, `GA`, `TU`) and treats P/NP status as QC-only context.
- `scratch/` remains blanket-ignored by `.gitignore` in this checkout, so
  notebook/helper/SLURM edits under `scratch/` are live on disk but do not
  appear in plain `git status`. Bootstrap-strata data-frame/matrix row names
  are now aligned by sample ID when numeric-looking IDs match the sample set
  but appear in a different order.
- Current AURORA baseline execution chain:
  - fresh publication-scale SLURM jobs are active for the baseline,
    group-protection, study-protection, and binary-comparison scratch
    workflows: `24773426` through `24773436`;
  - cached artifacts from earlier runs remain present for preprocessing,
    CyTOF, all 11 single-view branches, early fusion, late fusion,
    cooperative OVR `EG/GA/TU`, visualization, and nested CV under
    `scratch/cache/costablr_baseline_groups_test/`;
  - the active notebooks now load branch artifacts by default and submit heavy
    work only through guarded `sbatch` cells when `COSTABLR_SUBMIT_JOBS=true`;
  - future reruns should use the refreshed `1000`-bootstrap, `50`-lambda,
    `mvr_knockoff` defaults and should expect new `stabl_refit_*` prediction,
    confusion, and metric exports for single-matrix branches;
  - binary comparison artifacts are generated through SLURM jobs
    `24758964` -> `24758967`, with failed visualization job `24758968`
    superseded by completed rerun `24766406`; artifacts land under
    `scratch/cache/costablr_baseline_binary_comparisons/` plus
    `scratch/outputs/costablr_baseline_binary_comparisons/`;
  - generated output directories under `scratch/scratch/outputs/` are local
    notebook-run artifacts and are not part of the canonical cache path.
- Current AURORA crossed-label execution chain:
  - preprocessing cache is present for `EG_P`, `EG_NP`, `TU_P`, `TU_NP`,
    `GA_P`, and `GA_NP` under
    `scratch/cache/costablr_baseline_study_protection_test/preprocess/`;
  - publication-scale branch array `24773432` completed tasks 0-25 and failed
    task 26 (`nested_cv`) because one resampling split left a class with 1 or
    0 observations for glmnet; dependent visualization job `24773433` was
    cancelled;
  - use the refreshed `scratch/03_costablr_baseline_study_protection_test.ipynb`
    dashboard for cache review, but do not resubmit the nested-CV or dependent
    visualization branch without user confirmation;
    direct OVR branch predictions now come from `stabl_refit` caches.
- Current audit gate:
  - May 13 audit remediation is closed for INT-001 through INT-006 and
    IMPL-001 through IMPL-007; May 14 post-audit hardening closes the
    `stabl_refit()` pkgdown/test gaps and cooperative-fusion alignment
    audit-coverage gaps;
  - additive audit tests now assert fixed behavior in
    `tests/testthat/test-audit-*.R`; stale bug snapshots were removed;
  - latest full-suite validation is `FAIL 0`, `WARN 2`, `SKIP 2`, `PASS 1596`
    with `NOT_CRAN=true`;
  - the two skips are intentional NAT-001 and NAT-003 placeholders;
  - `devtools::check(error_on = 'never')` now rebuilds vignettes successfully
    and reports 0 errors, with only local `qpdf`/timestamp/toolchain
    warning/note items;
  - `pkgdown::check_pkgdown()` reports no problems;
  - defer NAT-001 and NAT-003 implementation until a separate profiling pass
    justifies native work; NAT-002 is fixed.
- Current final-refit workflow:
  - `stabl_fit()` remains the selector boundary for stability scores, FDP+
    diagnostics, and support masks;
  - `stabl_refit()` is the single-matrix end-to-end API and performs the
    compulsory unpenalized final model after selection;
  - `stabl_multiomic_train_validate()` now always returns per-omic `$refits`,
    adds `$early_fusion$refit` when early fusion is enabled, and late fusion
    reuses those same refits for stacking;
  - nested CV selected-candidate evaluation now uses the same final-refit
    helper;
  - latest validation after the follow-up hardening is `FAIL 0`, `WARN 2`,
    `SKIP 2`, `PASS 1596` under `NOT_CRAN=true`; the earlier `R CMD INSTALL .`
    check completed after the initial refit implementation.

## Update protocol

## Current relocation note

- The active repository is now `/exports/para-lipg-hpc/mdmanurung/costablr`.
- `DESCRIPTION` is at the repository root; use `.` for `devtools`, `testthat`,
  `pkgdown`, and `R CMD INSTALL` commands.
- The package name is `costablr`. STABL algorithm APIs such as `stabl_fit()`
  and S3 classes such as `stabl_fit` remain intentionally unchanged.

After each implementation step:

1. Record completed facts and validation outputs in `PROGRESS.md`.
2. Update `PLAN.md` only if forward scope/priority/acceptance changed.
3. Refresh this file with only live snapshot deltas and immediate next tasks.
