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
- Cooperative fusion: implemented and experimental (non-parity-blocking) in workflow layer. Hardening milestone CLOSED 2026-05-08 (M12). Vignette authored 2026-05-08 (M13, `stablr-cooperative.Rmd`, 434 lines, syntax clean).
- Latest verified full-suite signal: `PASS 326`, `FAIL 0`, `WARN 0`, `SKIP 3` (sparsegl absent in env; see `PROGRESS.md` for command trail).
- Latest verified vignette signal: 4 of 5 vignettes built in `R4_51`; `stablr-cooperative.Rmd` authored and syntax-validated but not yet rendered (pending full build, ~10 min due to n_bootstraps=50 cooperative fits).

### Remediation continuation snapshot (2026-05-08)

- Audit remediation implementation batch is in place (WI-01/02/03/04/05/07/08/09/10/11/12/13/14/15/16).
- Option-1 decision for WI-13 is applied: API-level guards are pinned via
	[r-pkg/stablr/tests/testthat/test-multiomic-guards.R](r-pkg/stablr/tests/testthat/test-multiomic-guards.R)
	against the real public entrypoint `stabl_multiomic_train_validate()`.
- Test execution blocker is cleared in `R4_51`; full suite has been executed.
- Current closure blocker is failing tests:
	- `[ FAIL 7 | WARN 0 | SKIP 4 | PASS 1336 ]` from
	  `Rscript -e "testthat::test_local('r-pkg/stablr')"`.
	- Failures are in `bootstrap-helpers`, `fdp-calibration`, `fdp-plus-invariants`,
	  `input-validation`, `multiomic-guards`, `python-parity-fixtures`, and
	  `signal-recovery`.
- Next operator action is strict one-item-at-a-time TDD remediation for these seven
	failing contexts; do not append audit closure mapping until suite is green.

### Immediate next tasks (updated)

1. Triage and fix failing context 1 (`bootstrap-helpers`) with strict TDD:
```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'bootstrap-helpers')"
```
2. After each fix, re-run full suite and record delta:
```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```
3. Only when green (`FAIL 0`), append final audit-closure mapping in
	 [audits/2026-05-08-full-package.md](audits/2026-05-08-full-package.md)
	 and sync summary lines in [PROGRESS.md](PROGRESS.md).

### Immediate next tasks — Bug-fix audit milestone (2026-05-08)

Work through fixes in order; run the full suite after each fix; do not batch.

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

Expected baseline before starting: `PASS 326, FAIL 0, WARN 0, SKIP 3`.

**Fix 1 — DONE** (`PASS 330`): `stabl_accessors.R` explore fallback replaced with `order()`-based
direct indexing. New test "explore fallback selects exactly n_explore features even when all
scores are tied" added to `test-stabl-fit.R`.

**Fix 2 — DONE** (`PASS 350`): `bootstrap_helpers.R` `group_bootstrap_indices` — mutable
`remaining` pool introduced; `replace=FALSE` now correctly removes each drawn group from the
pool. Test "group_bootstrap_indices replace=FALSE never re-draws the same group" added.

**Fix 3 — DONE** (`PASS 353`): `stabl_fit.R` `.build_corr_groups` —
appended `- 0.1` to the `quantile()` cutoff to match Python parity. Test added.

**Fix 4 — DONE** (`PASS 353`, code validated with Fix 3 run): `artificial_features.R`
kockoff chunked path — `orig_map` tracks original-feature indices through chunk/trim pipeline;
`noise_col_indices` now returns original-feature indices.

**Fix 5 — DONE** (`PASS 356`): `stabl_fit.R` sequential bootstrap loop — replaced
`lapply` + post-hoc accumulation with in-loop streaming; furrr path unchanged.

**Fix 6 — DONE** (`PASS 356`): `bootstrap_helpers.R` degenerate retry — tail recursion
replaced with bounded iterative loop (1 000 retries) in both `classic_bootstrap_indices`
and `group_bootstrap_indices`. Two new tests.

**Fix 7 — DONE** (`PASS 356`): `stabl_fit.R` early validator — explicit `stop()` when
`!replace && n_subsamples > n_samples`. New test in `test-input-validation.R`.

All 7 bug-fix audit items closed. PASS 356 | FAIL 0 | SKIP 3 (sparsegl absent, expected).
Next milestone: decide Phase 3 priorities (multiview integration, CRAN prep, or additional parity tests).
Full spec: `PLAN.md` → Fix 1.

**Fix 2 (correctness — do second):**  
File: `r-pkg/stablr/R/bootstrap_helpers.R`, function `group_bootstrap_indices`.  
Replace `sample(group_levels, size=1L, replace=replace)` with a mutable `remaining` vector that shrinks when `replace=FALSE`.  
Add test: verify no group appears more than once per call when `replace=FALSE`.  
Full spec: `PLAN.md` → Fix 2.

**Fix 3 (parity — do third):**  
File: `r-pkg/stablr/R/stabl_fit.R`, function `.build_corr_groups`.  
Append `- 0.1` to the `quantile(...)` cutoff to match Python (`stabl/stabl.py` line 1142).  
Full spec: `PLAN.md` → Fix 3.

**Fix 4 (correctness, p>3000 only — do fourth):**  
File: `r-pkg/stablr/R/artificial_features.R`, function `make_knockoff_features`, chunked branch.  
Track original-feature indices through the chunk-assemble-trim pipeline; return those as `noise_col_indices`.  
Full spec: `PLAN.md` → Fix 4.

**Fix 5 (memory — do fifth):**  
File: `r-pkg/stablr/R/stabl_fit.R`, the `result_list` + accumulation pattern.  
Replace sequential `lapply` + post-hoc loop with in-loop streaming accumulation; keep `furrr` path unchanged.  
Full spec: `PLAN.md` → Fix 5.

**Fix 6 (robustness — do sixth):**  
File: `r-pkg/stablr/R/bootstrap_helpers.R`, degenerate-bootstrap retry in both `classic_bootstrap_indices` and `group_bootstrap_indices`.  
Replace tail-recursion with an iterative loop capped at 1000 retries with an informative error.  
Full spec: `PLAN.md` → Fix 6.

**Fix 7 (validation — do last):**  
File: `r-pkg/stablr/R/stabl_fit.R`, in `stabl_fit()` after `n_subsamples` is computed.  
Add early `stop()` when `!replace && n_subsamples > n_samples`.  
Full spec: `PLAN.md` → Fix 7.

After all 7 fixes, record in `PROGRESS.md` and update this handoff to the next milestone.

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