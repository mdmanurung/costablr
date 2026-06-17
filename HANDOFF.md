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

- **Application Note track started 2026-06-17.** Multi-panel review completed;
  revised plan in `PUBLICATION_PLAN.md`; manuscript outline in
  `papers/application-note/OUTLINE.md`.
- `r-pkg/stablr/` restored from git HEAD after working-tree deletion.
- Package bumped to **0.1.0** with `inst/CITATION`, `NEWS.md`, and real
  maintainer metadata.
- Bundled OOL tutorial subset generated under `inst/extdata/`.
- Python parity fixtures restored under `tests/testthat/fixtures/python_parity/`.
- Latest verified full-suite signal: `PASS 1435`, `FAIL 0`, `SKIP 1`, `WARN 78`
  after cooperative-Cox test hardening.
- Vignette narrative rewrite is in place across all six canonical sources under
  `r-pkg/stablr/vignettes/`.  The rewrite used an original, curiosity-driven
  scientific narrative voice and preserved executable code chunks and runtime
  settings.
- Parallel render validation for the five non-nested-CV vignettes completed as
  SLURM array job `24752130` using
  `r-pkg/stablr/inst/analysis/render_vignettes.slurm`.
  - Per-task resources: 6 CPUs, 128 GB RAM, 24H walltime.
  - Array targets: `stablr-intro.Rmd`, `stablr-multiomic.Rmd`,
    `stablr-python-parity.Rmd`, `stablr-tcga.Rmd`, and
    `stablr-cooperative.Rmd`.
  - `stablr-tcga-nestedcv.Rmd` was intentionally excluded from this render
    array because its benchmark cache is managed by the separate nested-CV
    workflow.
  - Log check: HTML output was created for all five array targets; no failed
    render signal was observed in
    `r-pkg/stablr/inst/analysis/cache/vignette-renders/`.
- TCGA nested-CV head-to-head scaffold is in place:
  - exported `stabl_multiomic_nested_cv()` supports stratified folds,
    custom categorical strata, numeric-strata quantile binning, and
    outer-fold parallelism via `cv_workers`;
  - `r-pkg/stablr/vignettes/stablr-tcga-nestedcv.Rmd` renders from cache or
    prints the SLURM command when the cache is absent;
  - `r-pkg/stablr/inst/analysis/run_tcga_nestedcv.R` runs the cached
    stablr-vs-DIABLO TCGA benchmark with stablr knockoff artificial features;
  - full SLURM job `24750538` was submitted and was pending for `Priority` at
    the submission check.
- Workspace mode: initial CRAN-prep hardening pass complete; local manual-PDF tooling remains the only package-check warning.
- R4_51 install status: local `stablr` source package installed from
  `r-pkg/stablr` into the conda env library; exact-location load check reports
  version `0.0.0.9000`.
- Latest plotting fix: `plot_fdr_graph()` now draws the documented horizontal
  FDP target line by default at `fdr_target = 0.05`; local source was
  reinstalled into the default `R4_51` library after the fix.
- Validation policy: local R suite is authoritative for this workspace (CI deferred by scope).
- Cooperative fusion: promoted workflow-layer extension (non-parity-blocking). Hardening milestone CLOSED 2026-05-08 (M12); promotion accessor milestone CLOSED 2026-05-10. Public inspection surface now includes `get_cooperative_features()` and `get_cooperative_diagnostics()`.
- Latest verified full-suite signal: `PASS 1359`, `FAIL 0`, `WARN 2`, `SKIP 0` (see `PROGRESS.md` for command trail).
- Latest verified package-check signal: `R CMD check --no-manual` `Status: OK`; full `R CMD check` has `Status: 1 WARNING` from missing local LaTeX package `inconsolata.sty`.
- Latest verified vignette signal: all 5 non-nested canonical source vignettes
  rendered successfully in SLURM array job `24752130` after the narrative
  rewrite (`stablr-cooperative`, `stablr-intro`, `stablr-multiomic`,
  `stablr-python-parity`, `stablr-tcga`).
- Latest verified documentation-site signal: pkgdown site builds to
  `docs/stablr` with clean metadata checks (URLs, favicons, Open Graph,
  articles, reference metadata all OK).
- Latest targeted plotting signal: `test-phase7.R` passes against local source
  (`PASS 83`, `FAIL 0`, `WARN 0`, `SKIP 0`).
- Latest intro-vignette signal: `stablr-intro.Rmd` renders successfully after a
  new-user clarity pass. It now includes an explicit input-shape section,
  clearer selected-feature interpretation, displayed diagnostic plots with
  optional save examples, and prose tightened to avoid formulaic tutorial style.
- Latest Python-parity vignette signal: `stablr-python-parity.Rmd` renders all
  42 chunks against repository tutorial data in `R4_51` with fresh cache
  rebuild. OOL recovered all 7 Python tutorial selected features
  (`Overlap count: 7 of 7`); COVID-19 recovered all 6 Python tutorial selected
  features (`Overlap count: 6 of 6`).
- Latest scratch-analysis signal: ignored notebook
  `scratch/01_stablr_core_basemalvac.ipynb` now runs the STABL-only AURORA
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
- Latest guided all-view scratch notebook:
  `scratch/01_stablr_baseline_groups_test.ipynb` is now the active guided
  AURORA baseline study-group notebook. It uses all 11 RaJIVE-style
  preprocessed immune views, predicts `EG`, `GA`, and `TU`, keeps P/NP as
  descriptive QC only, writes artifacts through branch-aware helpers under
  `scratch/cache/stablr_baseline_groups_test/` and
  `scratch/outputs/stablr_baseline_groups_test/`, and includes reader guidance
  under every major section heading. The notebook adds CyTOF sanity-check
  STABL, per-view STABL, all-view early fusion, true multiclass late-fusion
  scaffolding, auxiliary cooperative one-vs-rest branches,
  top-5-per-study-group predictor tables, beta/stability interpretation,
  feature-value plots, selected-feature heatmaps, cluster-purity summaries,
  PCA/UMAP companions, feature-overlap plots, cross-view contribution
  summaries, and disabled-by-default publication nested-CV scaffolding.
  Heavy branches can be run with
  `scratch/scripts/run_stablr_baseline_groups_branch.R` or the paired SLURM
  scripts in `scratch/slurm/` (128 GB, 8 CPUs, 24H per task). Validation
  passed in `R4_51`: nbformat OK, R parse OK, SLURM `bash -n` OK,
  preprocessing OK with 11 views and 38 baseline samples (`EG=10`, `GA=16`,
  `TU=12`, missing=0), isolated reduced CyTOF branch smoke OK, and heatmap
  export smoke OK.
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
  classes contributing 0 rather than being dropped. Cooperative multinomial
  remains rejected; use explicit one-vs-rest binomial branches.
- Vignette source policy: edit `r-pkg/stablr/vignettes/*.Rmd`; `doc/` is
  generated by `devtools::build_vignettes()` / `R CMD build` and is ignored.

### Remediation continuation snapshot (2026-05-08)

- Audit remediation implementation batch is in place (WI-01/02/03/04/05/07/08/09/10/11/12/13/14/15/16).
- Option-1 decision for WI-13 is applied: API-level guards are pinned via
	[r-pkg/stablr/tests/testthat/test-multiomic-guards.R](r-pkg/stablr/tests/testthat/test-multiomic-guards.R)
	against the real public entrypoint `stabl_multiomic_train_validate()`.
- Test execution blocker is cleared in `R4_51`; full suite has been executed.
- Remediation closure is complete in this continuation:
	- `[ FAIL 0 | WARN 0 | SKIP 4 | PASS 1343 ]` from
	  `Rscript -e "devtools::load_all('.'); testthat::test_local('.')"`.
	- Resolved contexts: `bootstrap-helpers`, `fdp-plus-invariants`,
	  `input-validation`, `multiomic-guards`, `python-parity-fixtures`,
	  `fdp-calibration`, `signal-recovery`.

### Immediate next tasks (updated)

1. Monitor SLURM job `24750538`; when it finishes, confirm
   `r-pkg/stablr/inst/analysis/cache/tcga_nestedcv_results.rds` is complete
   and re-render `stablr-tcga-nestedcv.Rmd` from cache.
2. Use the nested-CV benchmark cache to update the research vignette outputs
   and then refresh the pkgdown site if the article output changes.
3. Decide whether to install/fix local TeX manual tooling (`inconsolata.sty`) or defer manual PDF validation to CI/CRAN-like builders.

### Vignette runtime profile (2026-05-10)

- `stablr-intro.Rmd` is the single-omic introductory vignette: simulated data
  with explicit planted supports, compact strong-penalty lambda grids,
  40-50 bootstraps, and concise interpretation guidance for new users.
- Real-data vignettes remain realistic; most are bounded, while
  `stablr-python-parity.Rmd` intentionally uses notebook-scale settings when
  repository tutorial data are available:
  - OOL multi-omic: 80 bootstraps, 15 lambda values, 500 late-fusion iterations.
  - Python-to-R mapping: OOL renders with 500 bootstraps, 10 lambda values, and
    knockoffs; COVID-19 renders with 1000 bootstraps, 10 lambda values, and
    random-permutation artificial features. Package builds without repository
    tutorial data fall back to the bundled OOL subset and skip COVID-19.
  - Cooperative fusion: compact OOL lambda/rho/fold settings; outer CV displayed
    but not evaluated by default.
  - TCGA: restored as `stablr-tcga.Rmd`, with 30 bootstraps, 12 lambda values,
    and tempdir exports.

### Cooperative touchpoints (implementation surfaces)

- Workflow orchestration: `r-pkg/stablr/R/multiomic_workflows.R`
- Cooperative guards/normalization: `r-pkg/stablr/R/input_validation.R`
- Regression surface: `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`
- Accessor/print ergonomics surface: `r-pkg/stablr/R/stabl_accessors.R`
- Design/evidence bridge: `MultiView.md`

### Runtime constraints to preserve

- `cooperative_fusion = FALSE` must preserve current top-level return shape.
- Cooperative fusion uses the native vendored multiview engine (gaussian and
  binomial in v1); no external `multiview` install is required at runtime.
- `stabl_multiomic_nested_cv()` does not support cooperative fusion.
- `cooperation_selection = "validation"` is unsupported for `family = "cox"`.
- Cooperative fusion with `family = "cox"` or `"poisson"` is rejected in native v1.
- `cooperation_selector = "lambda.1se"` is valid only with `cooperation_selection = "cv"`.
- Outer fold construction behavior (`.make_multiomic_cv_folds()`) is stable; cooperative diagnostics are additive only.
- Cooperative result inspection should use `get_cooperative_features()` and
  `get_cooperative_diagnostics()` instead of relying on nested list internals.

### Command entrypoints

Run full suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

Run cooperative workflow suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"
```

Run parity fixture suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures')"
```

Run artificial-feature regression suite:

```bash
conda run -n R4_51 Rscript -e "setwd('r-pkg/stablr'); devtools::load_all(quiet = TRUE); testthat::test_file('tests/testthat/test-artificial-features-parity.R')"
```

Build vignettes:

```bash
conda run -n R4_51 Rscript -e "devtools::build_vignettes('r-pkg/stablr')"
```

Run TCGA nested-CV smoke workflow:

```bash
conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/run_tcga_nestedcv.R --cache /tmp/tcga_nestedcv_smoke.rds --force --smoke --cv-workers 1 --stabl-workers 1 --diablo-workers 1
```

Submit full TCGA nested-CV benchmark:

```bash
sbatch r-pkg/stablr/inst/analysis/tcga_nestedcv.slurm
```

Submit parallel render validation for rewritten non-nested vignettes:

```bash
sbatch r-pkg/stablr/inst/analysis/render_vignettes.slurm
```

Build pkgdown documentation website:

```bash
conda run -n R4_51 Rscript -e "pkgdown::build_site('r-pkg/stablr', examples = FALSE, install = FALSE)"
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
- Cooperative fusion remains `stablr`-native, optional, and non-parity-blocking; it now has a promoted public inspection surface.
- Knockoff artificial-feature generation handles `p < n < 2p` fixed-design
  augmentation without random-permutation fallback; evidence is in
  `PROGRESS.md`.
- The multiomic vignette is a bounded OOL package workflow, not the Python
  tutorial parity workflow. For the tutorial datasets and preprocessing
  contract, use `stablr-python-parity.Rmd`; the multiomic vignette now states
  this boundary explicitly.
- Ignored scratch notebook `scratch/01_stablr_core_basemalvac.ipynb` is now
  configured for baseline study-group multinomial elastic-net classification
  (`EG`, `GA`, `TU`) and treats P/NP status as QC-only context.
- Scratch workflow sources are no longer blanket-ignored; generated scratch
  artifact directories remain ignored. Bootstrap-strata data-frame/matrix row
  names are now aligned by sample ID when numeric-looking IDs match the sample
  set but appear in a different order.
- Current AURORA baseline execution chain:
  - preprocess `24757561` completed successfully;
  - branch array `24757562` is running by remaining heavy tasks
    (`late_fusion`, cooperative one-vs-rest, `nested_cv`), with completed
    single-view and early-fusion artifacts already appearing under
    `scratch/cache/stablr_baseline_groups_test/` and
    `scratch/outputs/stablr_baseline_groups_test/`;
  - visualization `24757563` is pending on the full branch array;
  - notebook execution `24757565` is pending on visualization and will write
    `scratch/01_stablr_baseline_groups_test.executed.ipynb`.

## Update protocol

After each implementation step:

1. Record completed facts and validation outputs in `PROGRESS.md`.
2. Update `PLAN.md` only if forward scope/priority/acceptance changed.
3. Refresh this file with only live snapshot deltas and immediate next tasks.
