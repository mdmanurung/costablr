# MultiView: Cooperative Fusion Integration Plan for stablr

## Role of this document

This file is the cooperative-fusion planning and evidence bridge between the maintained `multiview/` package and the `r-pkg/stablr` workflow layer.

- `STABL.md` remains the parity contract for core STABL semantics.
- `PLAN.md` controls milestone sequencing and acceptance gates.
- `PROGRESS.md` records completed implementation and validation facts.
- `HANDOFF.md` is the fresh-session execution entrypoint.

## Scope decision (active)

- Cooperative fusion is tracked as an experimental, non-parity-blocking extension.
- Cooperative source-of-truth is restricted to the in-repo `multiview/` implementation.
- Historical references to removed `cooperative-learning/` paths are out of active scope.

## Active source anchors (multiview)

- `multiview/R/multiview.R`
- `multiview/R/multiview.path.R`
- `multiview/R/cv.multiview.R`
- `multiview/R/predict.cv.multiview.R`
- `multiview/R/coxpath.R`
- `multiview/R/get_start.R`
- `multiview/R/view.contribution.R`

## Verified capabilities from active source

1. Cooperative learning is exposed via `multiview()` and `cv.multiview()` with explicit `rho` (cooperation strength) argument.
2. `cv.multiview()` does not automatically tune `rho`; tuning requires repeated calls with shared `foldid`.
3. `cv.multiview` objects expose both `lambda.min` and `lambda.1se` selectors.
4. `predict.cv.multiview()` supports `s = c("lambda.1se", "lambda.min")`.
5. Cooperative objective coupling terms are explicit in `get_start.R` and `coxpath.R` internals.
6. Family coverage in active sources includes gaussian, binomial, poisson, and cox paths.
7. `view.contribution.R` already provides a comparative framing utility for cooperative versus other view setups.

## Integration target for stablr

Add a middle-fusion option to `stabl_multiomic_train_validate()` and `stabl_multiomic_cv()` while preserving backward-compatible defaults and keeping core STABL parity work unblocked.

Suggested API direction (RFC draft):

- `cooperative_fusion = FALSE`
- `cooperation_strength` (scalar or grid; maps to multiview `rho`)
- `cooperation_selector = c("lambda.min", "lambda.1se")`
- `cooperation_selection = c("cv", "validation")`

## Strict claim labeling

Legend:

- Verified: directly supported by inspected active source files.
- Inference: consistent interpretation of active source behavior.
- Proposal: forward-looking change for `stablr`.

### Claim matrix

| ID | Type | Claim (short) | Evidence anchor | Confidence | Implementation action | Priority |
|---|---|---|---|---|---|---|
| MV01 | Verified | Cooperative API uses `rho` in `multiview` and `cv.multiview`. | `multiview/R/multiview.R`, `multiview/R/cv.multiview.R` | High | Reuse naming in `stablr` API | P1 |
| MV02 | Verified | `cv.multiview` does not tune `rho` automatically. | roxygen in `multiview/R/cv.multiview.R` | High | Add explicit `rho` grid loop in wrapper | P1 |
| MV03 | Verified | `lambda.min` and `lambda.1se` are returned in `cv.multiview`. | return docs and object fields in `multiview/R/cv.multiview.R` | High | Expose selector policy in workflow API | P1 |
| MV04 | Verified | Prediction selector supports `lambda.min`/`lambda.1se`. | `multiview/R/predict.cv.multiview.R` | High | Wire selector through cooperative outputs | P1 |
| MV05 | Verified | Cooperative terms are explicit in optimization internals. | `multiview/R/get_start.R`, `multiview/R/coxpath.R` | High | Keep algorithm naming and diagnostics consistent | P1 |
| MV06 | Verified | Active family paths include gaussian/binomial/poisson/cox. | `multiview/R/cv.multiview.R`, `multiview/R/coxpath.R` | High | Stage rollout: gaussian first, then binomial | P2 |
| MV07 | Verified | View-comparison utility exists for contribution analysis. | `multiview/R/view.contribution.R` | Medium | Add comparable `stablr` diagnostics output | P3 |
| MV08 | Proposal | Add cooperative mode to `stablr` train/validate and CV workflows. | Derived from MV01-MV07 | Medium | Draft RFC + tests | P1 |
| MV09 | Proposal | Add explicit `cooperation_selector` policy (`lambda.min`/`lambda.1se`). | Derived from MV03-MV04 | Medium | API + validation-path plumbing | P1 |
| MV10 | Proposal | Keep cooperative fusion as experimental until behavior tests stabilize. | Execution policy decision | High | Mark non-parity-blocking in plan/handoff | P1 |

## Step-by-step implementation plan (experimental track)

1. Phase CF-0: RFC and interface lock
- Write RFC for cooperative parameters and return contract.
- Keep defaults off to preserve existing workflow behavior.
- Gate: API schema review complete and documented in `PLAN.md`.

2. Phase CF-1: Two-view gaussian cooperative path
- Add cooperative execution branch in workflow layer.
- Implement deterministic synthetic tests comparing early/cooperative/late outputs.
- Gate: behavior tests pass, no regressions in existing workflow tests.

3. Phase CF-2: Selector and tuning policy
- Add `lambda.min`/`lambda.1se` selector wiring.
- Add CV-over-`rho` orchestration using shared fold assignments.
- Gate: deterministic selector-path tests and fold-consistency checks.

4. Phase CF-3: Binomial extension
- Extend cooperative path to binomial tasks.
- Add metrics checks for deviance/AUC behavior under fixed seeds.
- Gate: binomial cooperative tests pass with deterministic fixtures.

5. Phase CF-4: Optional multi-view generalization
- Extend from two-view workflows to named multi-view lists.
- Add pairwise agreement and diagnostics summaries.
- Gate: multi-view synthetic behavior tests pass and docs are updated.

## Acceptance and handoff discipline

- No CF phase is marked complete without passing tests for that phase.
- After each cooperative implementation step, update:
  1. `PROGRESS.md` with facts and validation results,
  2. `PLAN.md` with changed sequencing or gates,
  3. `HANDOFF.md` with current state and next 3 executable tasks.

## RFC Checklist (from Proposal Claims)

Checklist scope: converts proposal claims `MV08`-`MV10` into an execution-ready
RFC gate list for `stablr` cooperative fusion.

### CF-RFC-00: Interface lock (maps to MV08, MV09, MV10)

- [ ] Document parameter schema in `stablr` workflow API:
  - `cooperative_fusion` (default `FALSE`),
  - `rho` (scalar or grid),
  - `cooperation_selector` (`lambda.min`/`lambda.1se`),
  - `cooperation_selection` (`cv`/`validation`).
- [ ] Define return contract for cooperative outputs (weights, selector used,
  fold diagnostics, failure signals).
- [ ] Backward-compatibility gate: existing workflow defaults produce identical
  outputs when cooperative mode is disabled.

Strict parity gate (required before CF-RFC-00 closure):

- [ ] Deterministic API-level tests pass under fixed seeds with no changes to
  non-cooperative workflow outputs.

### CF-RFC-01: Two-view gaussian cooperative tranche (maps to MV08, MV10)

- [ ] Add two-view cooperative branch in workflow layer using `multiview` as
  the only source anchor.
- [ ] Add deterministic synthetic comparison tests:
  - early fusion vs cooperative vs late fusion on same folds,
  - fixed-seed reproducibility checks.
- [ ] Add failure-mode checks for misaligned samples, invalid `rho`, and
  unsupported family routing.

Strict parity gate (required before CF-RFC-01 closure):

- [ ] Behavioral assertions pass for synthetic fixtures (not only structural
  shape assertions), including expected ranking/order effects under
  cooperation changes.

### CF-RFC-02: Selector policy + rho tuning (maps to MV09, MV10)

- [ ] Wire `lambda.min` and `lambda.1se` through cooperative predict/extract
  path.
- [ ] Add explicit `rho`-grid CV loop with shared fold ids.
- [ ] Persist fold-level diagnostics and chosen selector/rho in outputs.

Strict parity gate (required before CF-RFC-02 closure):

- [ ] Deterministic selector-path tests pass for both `lambda.min` and
  `lambda.1se`, with fold-consistency checks across repeated runs.