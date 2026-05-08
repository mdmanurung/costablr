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

## Vignette Status (as of 2026-05-08) — Complete

All 4 stablr vignettes are built and in `doc/`:
- `stablr-intro.html` (335K) ✅
- `stablr-multiomic.html` (1.4M) ✅
- `stablr-python-parity.html` (561K) ✅ — OOL regression + COVID-19 binary classification
- `stablr-tcga.html` (787K) ✅ — TCGA Breast Cancer multi-omic (M15 stablr-native version)

## Current Planning Focus (Forward Only)

1. Harden cooperative fusion behavior (comparative behavior tests, not only structure tests).
2. Improve cooperative branch operator ergonomics (print/summary/reporting surfaces).
3. Validate optional-dependency failure modes for cooperative paths in clean environments.
4. Keep local deterministic validation green for every forward change.
5. Keep Python-path API compatibility in source (`stabl/`) without notebook-local monkeypatching.

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

## Experimental Track: Cooperative Fusion (Non-Blocking)

- Track type: experimental workflow-layer extension, not blocking Phase 6 closure.
- Source restriction: `multiview/` is the only in-repo cooperative reference.
- Naming policy: use `rho` for cooperation strength (avoid collision with elastic-net `alpha`).
- Implementation status and command evidence are maintained in `PROGRESS.md`.
- Immediate operational queue is maintained in `HANDOFF.md`.

Current cooperative touchpoints:

1. `r-pkg/stablr/R/multiomic_workflows.R` owns cooperative workflow orchestration and additive diagnostics.
2. `r-pkg/stablr/R/input_validation.R` owns cooperative argument normalization and family/selector guards.
3. `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R` is the behavior-regression surface for cooperative hardening.
4. `r-pkg/stablr/R/stabl_accessors.R` is the next surface for cooperative print/report ergonomics.
5. `MultiView.md` remains the cooperative design/evidence bridge.

Exit criteria from experimental status:

- Deterministic behavior-level cooperative tests pass.
- Optional-dependency failure paths are validated and stable.
- Operator-facing docs (`HANDOFF.md`) and factual logs (`PROGRESS.md`) remain synchronized.
