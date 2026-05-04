# HANDOFF: Session Bootstrap and Parity Ledger

## Purpose

This file is the first-stop operational handoff for fresh Copilot sessions.

- Use this file first to recover current execution state.
- Use `PLAN.md` for roadmap sequencing and acceptance gates.
- Use `PROGRESS.md` for validated completed work and command evidence.
- Use `STABL.md` for parity-critical algorithm semantics.

## Operator Runbook

### Current state snapshot

- Primary mode: parity-first execution.
- Parity gate policy: strict (no feature is complete without behavior-matching tests).
- Cooperative fusion status: experimental, non-parity-blocking track.
- Validation scope in this workspace: local R suite only (CI implementation deferred).
- **Phases 1–7 are complete.** Full suite: `PASS 247`, `FAIL 0`, `WARN 0`, `SKIP 0`.
- Phase 8 (hardening) is the only remaining active track.

### Next 3 executable tasks

1. Phase 8 hardening: parity regression tests against frozen Python references for selected features under known synthetic fixtures (binary, gaussian, multinomial, Cox paths).
2. Phase 8: stress-test `save_stabl_results()` and `export_stabl_to_csv()` with real datasets from `Sample Data/` to validate column naming and file layout end-to-end.
3. Phase 8 (optional): sparsegl-enabled CI leg to unskip sparse-group tests in a CI environment.

### Commands

Run full suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

Run focused STABL fit suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'stabl-fit')"
```

Run multi-omic workflow suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"
```

### Expected signals

- Pass condition: zero failures and no unexpected skips.
- Regression signal: changed dimensions, lambda-grid row alignment drift, threshold/support-mask behavior drift.
- Documentation hygiene signal: if plan/progress/handoff disagree, update all three before ending the task.

## Parity Ledger

| Python anchor | R scope | Status | Evidence | Next action |
|---|---|---|---|---|
| `stabl/stabl.py` core loop and threshold semantics | `r-pkg/stablr/R/stabl_fit.R`, `fdp_control.R` | Complete (structural + behavior-level parity coverage across all families) | `PROGRESS.md` Latest Validation Snapshot (`PASS 247`, full suite) | Phase 8 parity regression tests against frozen Python outputs |
| `stabl/adaptive.py` adaptive behavior | `r-pkg/stablr/R/learner_adapters.R` | Complete | Tranche C deterministic mixed-alpha tests + behavior-level multinomial/Cox tests | Maintain regression tests only |
| `stabl/metrics.py` similarity measures | `r-pkg/stablr/R/metrics.R` | Complete | Phase 7 (`PASS 247`); 53 new tests in `test-phase7.R` | Phase 8 parity checks against Python metric values |
| `stabl/stabl.py` export functions | `r-pkg/stablr/R/exports.R` | Complete | Phase 7 (`PASS 247`); structure tests in `test-phase7.R` | Stress-test with real datasets from `Sample Data/` |
| `stabl/visualization.py` + `stabl/stabl.py` plot functions | `r-pkg/stablr/R/visualization.R` | Complete (ggplot2 port) | Phase 7 (`PASS 247`); smoke tests confirm ggplot object return | Phase 8 visual regression (optional) |
| `stabl/multi_omic_pipelines.py` workflow orchestration | `r-pkg/stablr/R/multiomic_workflows.R` | Complete for early/late + CV/train-validate slices | Multi-omic workflow tests (documented in `PROGRESS.md`) | Phase 8 parity regression and cooperative RFC |
| `stabl/stacked_generalization.py` late fusion | `stacked_multi_omic()` in `multiomic_workflows.R` | Complete | Phase 5 completion log in `PROGRESS.md` | Maintain regression tests only |
| Cooperative middle-fusion equivalent (not in core Python package modules listed above) | Future `stablr` workflow extension backed by `multiview/` | Experimental (non-blocking; RFC checklist drafted) | `MultiView.md` claim/action matrix + CF-RFC checklist | Execute CF-RFC-01 two-view gaussian tranche with strict gate tests |

## Update Protocol

After each implementation step:

1. Update `PROGRESS.md` with only factual completed work and validation results.
2. Update `PLAN.md` if priorities, sequencing, or acceptance gates changed.
3. Update this handoff file: current snapshot, next 3 tasks, and any parity-ledger status changes.