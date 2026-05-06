# PLAN: stablr Full R Port

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

## Phase Status Snapshot

1. Phase 1 (Spec + scaffolding): Completed
2. Phase 2 (Core contracts): Completed
3. Phase 3 (Core STABL engine): Completed
4. Phase 4 (Learner adapters): Complete
5. Phase 5 (Workflow layer): Complete (train/validate, CV, early fusion, late fusion/stacked generalization all implemented)
6. Phase 6 (Full glmnet compatibility): Complete
7. Phase 7 (Reporting + exports): Complete (metrics, exports, visualization fully implemented and tested)
8. Phase 8 (Hardening): Parity coverage complete (elastic-net, binomial, gaussian, multinomial; see below)

## Active Dependencies

- `sparsegl` availability in at least one CI leg is required to unskip sparse-group tests.
- R environment reproducibility in `R4_51` is required for reliable benchmark smoke checks.
- Python reference scripts remain the behavior anchor for parity checks where tests are not yet frozen.
- Current workspace scope (2026-05-03): CI workflow implementation is deferred; validation is performed via local R test suites.

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

## Near-Term Milestones

### M1: Phase 4 Closure (Adapters Hardening)

- Add grouped longitudinal leakage tests.
- Add adapter-focused documentation for adaptive lasso, sparse-group, and multinomial usage.
- Add sparsegl-enabled CI leg to run non-skipped sparse-group tests.

Acceptance criteria:

- All current tests pass in default environment.
- Sparse-group tests run (not skipped) in at least one CI job.
- Adapter docs include at least one executable example per adapter family.
- Grouped longitudinal leakage tests cover both grouped and ungrouped sampling behavior.

### M2: Minimal R End-to-End Benchmark Path

- Add one end-to-end smoke benchmark in R that exercises core fit and support extraction.
- Keep runtime modest and deterministic enough for repeated validation.

Acceptance criteria:

- Script runs successfully in `R4_51` environment.
- Produces expected object outputs without requiring full heavy benchmark settings.
- Runtime is short enough for routine local smoke validation.

### M3: Workflow Layer Completion (Phase 5)

- Implemented multi-omic train/validation orchestration path.
- Implemented multi-omic CV orchestration with deterministic grouped fold handling.
- Implemented early fusion path.
- Implemented late fusion with stacked generalization parity semantics.

Acceptance criteria:

- Tested workflow paths exist for per-omic, early-fusion, and late-fusion modes.
- Failure modes for sample misalignment are explicit and documented.
- Full local package test suite remains green after workflow additions.

## Current Planning Focus

1. Maintain local hardening through deterministic local test-suite validation.
2. Keep Phase 8 Cox hardening under R-native validation gates (determinism, structural invariants, synthetic-signal behavior) as a maintained regression target.
3. Keep `HANDOFF.md` synchronized after each implementation step so fresh sessions can execute without extra context.
4. Harden the implemented cooperative fusion workflow branch as an experimental, non-parity-blocking `stablr` extension sourced only from `multiview/`.
5. Keep cooperative CV selection available for gaussian/binomial/poisson/cox, and keep validation-mode cooperative tuning restricted to gaussian/binomial/poisson until a source-backed Cox holdout criterion is defined.
6. Keep Python-path compatibility under current scikit-learn APIs by maintaining source-level validation shims in `stabl/` and minimizing notebook-local monkeypatching.

## Experimental Track: Cooperative Fusion (Non-Blocking)

- Track type: experimental workflow-layer extension, not blocking Phase 6 closure.
- Source restriction: `multiview/` is the only in-repo cooperative reference.
- Naming policy: use `rho` for cooperation strength (avoid collision with elastic-net `alpha`).
- Current implementation status:
	1. Additive `cooperative_fusion` branch is implemented in `stabl_multiomic_train_validate()` and `stabl_multiomic_cv()`.
	2. Optional dependency path is active via local/installed `multiview`.
	3. `rho` grid tuning and `lambda.min` / `lambda.1se` selector handling are implemented for CV mode.
	4. Validation-mode cooperative tuning is implemented for gaussian/binomial/poisson; Cox remains intentionally restricted to CV mode.
- Remaining hardening sequence:
	1. Add behavior-level comparative tests for early/cooperative/late ranking effects on synthetic fixtures.
	2. Add cooperative ergonomics and diagnostics polish (print/reporting/accessor coverage) without perturbing default paths.
	3. Validate optional-dependency behavior in clean environments where `multiview` is absent.
- Current cooperative touchpoints:
	1. `r-pkg/stablr/R/multiomic_workflows.R` owns the cooperative branch, tuning helpers, and additive diagnostics.
	2. `r-pkg/stablr/R/input_validation.R` owns cooperative argument normalization and family/selector guards.
	3. `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` is the current regression surface and should absorb the next behavior-level assertions.
	4. `r-pkg/stablr/R/stabl_accessors.R` is the next surface for cooperative print/report ergonomics.
	5. `MultiView.md` is the evidence bridge and should stay synchronized with any contract changes.
- Exit criteria from experimental status:
	- behavior tests pass for agreed synthetic and deterministic fixtures,
	- docs and handoff artifacts fully reflect execution commands and failure signals.


## Deliverable Checklist

- [x] Grouped longitudinal leakage tests added. (`r-pkg/stablr/tests/testthat/test-bootstrap-helpers.R`)
- [x] R smoke benchmark script added and documented. (`r-pkg/stablr/scripts/run_smoke_stablr.R`)
- [x] Adapter usage documentation examples added. (`r-pkg/stablr/R/stabl_fit.R`, `r-pkg/stablr/R/learner_adapters.R`)
- [ ] Sparsegl-enabled CI job added. (Deferred in this workspace; local suite coverage is the active validation path.)
- [x] Bootstrap loop optimized: bootstrap-outer, single path call per bootstrap, vectorized FDP+. (`r-pkg/stablr/R/stabl_fit.R`, `learner_adapters.R`, `fdp_control.R`)
- [x] Minimal multi-omic train/validation orchestration path added with alignment and grouped-handling tests. (`r-pkg/stablr/R/multiomic_workflows.R`, `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`)
- [x] Minimal multi-omic CV orchestration path added with deterministic fold generation, grouped fold isolation, and fold diagnostics. (`r-pkg/stablr/R/multiomic_workflows.R`, `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`)
- [x] Early fusion and late fusion/stacked generalization implemented and covered by tests. (`r-pkg/stablr/R/multiomic_workflows.R`, `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`, `r-pkg/stablr/man/stacked_multi_omic.Rd`)
- [x] Phase 6 focused coverage added for Cox auto-lambda mixed-alpha grids and elastic-net Cox mixed-alpha path consumption. (`r-pkg/stablr/tests/testthat/test-stabl-fit.R`)
- [x] Phase 6 Tranche C structural parity coverage added for multinomial/binomial mixed-alpha auto-lambda grids and deterministic adapter behavior across elastic-net, adaptive lasso, and lasso. (`r-pkg/stablr/tests/testthat/test-stabl-fit.R`)
- [x] Phase 6 edge-regime parity coverage added for high collinearity, near-zero lambda tails, and class-imbalance binomial stress. (`r-pkg/stablr/tests/testthat/test-stabl-fit.R`)
- [x] Fresh-session bootstrap artifact added with operator runbook + parity ledger. (`HANDOFF.md`)
- [x] Cooperative-fusion RFC checklist drafted from `MultiView.md` Proposal-tagged claims with explicit strict-parity test gates. (`MultiView.md`)
- [x] Experimental cooperative-fusion workflow branch added to `stabl_multiomic_train_validate()` and `stabl_multiomic_cv()` with optional `multiview` dependency, family-aware guards, and deterministic workflow tests. (`r-pkg/stablr/R/multiomic_workflows.R`, `r-pkg/stablr/R/input_validation.R`, `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`)
- [x] Frozen Python parity fixtures + regression tests added for gaussian/binomial/multinomial/elastic-net signal ranking parity. (`r-pkg/stablr/scripts/generate_python_parity_refs.py`, `r-pkg/stablr/tests/testthat/fixtures/python_parity/*`, `r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R`)
- [x] Cox parity policy resolved as non-applicable for frozen Python anchors; Phase 8 closure uses R-native Cox hardening gates (determinism, structural invariants, synthetic-signal behavior). (Python `stabl/` reference does not implement Cox.)
- [x] Real-data export hardening added for `export_stabl_to_csv()` and `save_stabl_results()` using Biobank SSI files from `Sample Data/data.zip`, including schema/layout assertions. (`r-pkg/stablr/tests/testthat/test-phase7.R`)
- [x] Phase 8 metrics parity fixtures + assertions added against frozen Python `stabl.metrics` outputs, including upper-triangle ordering and mean-error semantics parity. (`r-pkg/stablr/R/metrics.R`, `r-pkg/stablr/scripts/generate_python_parity_refs.py`, `r-pkg/stablr/tests/testthat/fixtures/python_parity/metrics_*.csv`, `r-pkg/stablr/tests/testthat/test-phase7.R`)
