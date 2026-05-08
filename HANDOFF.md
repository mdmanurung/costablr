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

- Workspace mode: post-M9 hardening and polish.
- Validation policy: local R suite is authoritative for this workspace (CI deferred by scope).
- Cooperative fusion: implemented and experimental (non-parity-blocking) in workflow layer. Hardening milestone CLOSED on 2026-05-08 (M12 in `PROGRESS.md`).
- Latest verified full-suite signal: `PASS 326`, `FAIL 0`, `WARN 0`, `SKIP 3` (sparsegl absent in env; see `PROGRESS.md` for command trail).
- Latest verified vignette signal: all active vignettes build cleanly in `R4_51` (see `PROGRESS.md` vignette entries for exact commands/results).

### Immediate next 3 tasks

1. Promote cooperative fusion out of experimental status by drafting an operator-facing vignette section covering print output, `cooperation_selection`/`selector` policy, and the `rho` grid pattern.
2. Re-validate `PASS 326` baseline after any subsequent edits (target: zero new skips beyond `sparsegl`).
3. Decide whether to lift the `sparsegl` skip by installing it in `R4_51`, or leave skip as documented optional-dep behavior.

### Cooperative touchpoints (implementation surfaces)

- Workflow orchestration: `r-pkg/stablr/R/multiomic_workflows.R`
- Cooperative guards/normalization: `r-pkg/stablr/R/input_validation.R`
- Regression surface: `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`
- Accessor/print ergonomics surface: `r-pkg/stablr/R/stabl_accessors.R`
- Design/evidence bridge: `MultiView.md`

### Runtime constraints to preserve

- `cooperative_fusion = FALSE` must preserve current top-level return shape.
- `multiview` remains optional and cooperative mode must fail cleanly when absent.
- `cooperation_selection = "validation"` is unsupported for `family = "cox"`.
- `cooperation_selector = "lambda.1se"` is valid only with `cooperation_selection = "cv"`.
- Outer fold construction behavior (`.make_multiomic_cv_folds()`) is stable; cooperative diagnostics are additive only.

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

Build vignettes:

```bash
conda run -n R4_51 Rscript -e "devtools::build_vignettes('r-pkg/stablr')"
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
- Cooperative fusion remains `stablr`-native and experimental; hardening tasks above are the active closure path.

## Update protocol

After each implementation step:

1. Record completed facts and validation outputs in `PROGRESS.md`.
2. Update `PLAN.md` only if forward scope/priority/acceptance changed.
3. Refresh this file with only live snapshot deltas and immediate next tasks.