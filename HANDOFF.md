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
- **Phases 1–7 are complete.** Full suite: `PASS 309`, `FAIL 0`, `WARN 0`, `SKIP 0`.
- Phase 8 (hardening): Parity coverage complete for lasso, elastic-net (gaussian/binomial), multinomial. All parity tests pass (`PASS 20`).
- Real-data export hardening is implemented: Biobank SSI-backed assertions now cover `export_stabl_to_csv()` and `save_stabl_results()` artifact schema/layout.
- Python sklearn API compatibility is now source-level for validation paths (`stabl/stabl.py`, `stabl/preprocessing.py`); tutorial notebook setup no longer depends on local `_validate_data` monkeypatching.
- Metrics parity hardening is implemented: frozen Python `stabl.metrics` fixtures and regression assertions are now active (`PASS 89` on `phase7|python-parity-fixtures`).
- Experimental cooperative fusion is implemented in the workflow layer:
	- `stabl_multiomic_train_validate()` and `stabl_multiomic_cv()` now accept `cooperative_fusion`, `rho`, `cooperation_selection`, `cooperation_selector`, `cooperation_type_measure`, and `cooperation_nfolds`.
	- Cooperative CV tuning is available for gaussian/binomial/poisson/cox; validation-mode cooperative tuning is available for gaussian/binomial/poisson and intentionally rejected for cox.
	- Default non-cooperative behavior remains unchanged and is covered by regression tests.

### Cooperative touchpoints

- Workflow entry points and helper block: `r-pkg/stablr/R/multiomic_workflows.R`
- Cooperative argument normalization and family guards: `r-pkg/stablr/R/input_validation.R`
- Existing multi-omic/cooperative regression coverage: `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`
- Next ergonomics surface for print/report polish: `r-pkg/stablr/R/stabl_accessors.R`
- Cooperative planning/evidence bridge: `MultiView.md`

### Known constraints

- `cooperative_fusion = FALSE` must leave the current top-level return shape unchanged.
- `multiview` remains optional; cooperative mode must fail cleanly when the package is unavailable.
- `cooperation_selection = "validation"` is intentionally unsupported for `family = "cox"`.
- `cooperation_selector = "lambda.1se"` is valid only for `cooperation_selection = "cv"`.
- Outer CV fold construction must remain the current `.make_multiomic_cv_folds()` behavior; cooperative diagnostics are additive only.

### Next 3 executable tasks

1. Cooperative hardening: in `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`, add behavior-level comparative fixtures for early/cooperative/late fusion so the experimental branch has ranking/effect assertions, not only structure/regression checks.
2. Cooperative ergonomics: in `r-pkg/stablr/R/stabl_accessors.R`, add print/report coverage for the cooperative branch and keep existing non-cooperative output unchanged; extend tests in `test-multiomic-workflows.R` accordingly.
3. Environment hardening: verify the optional-dependency failure mode in a clean R library where `multiview` is absent, then document the observed failure signal and recovery command here if it differs from the current expectation.

### Commands

Run full suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

Run focused STABL fit suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'stabl-fit')"
```

Run frozen Python parity fixture suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'python-parity-fixtures')"
```

Run focused Phase 7 + parity fixture suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'phase7|python-parity-fixtures')"
```

Run multi-omic workflow suite:

```bash
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"
```

Install local multiview package for cooperative validation:

```bash
conda run -n R4_51 R CMD INSTALL multiview
```

### Expected signals

- Pass condition: zero failures and no unexpected skips.
- Regression signal: changed dimensions, lambda-grid row alignment drift, threshold/support-mask behavior drift.
- Documentation hygiene signal: if plan/progress/handoff disagree, update all three before ending the task.

## Parity Ledger

| Python anchor | R scope | Status | Evidence | Next action |
|---|---|---|---|---|
| `stabl/stabl.py` core loop and threshold semantics | `r-pkg/stablr/R/stabl_fit.R`, `fdp_control.R` | Complete for gaussian/binomial/multinomial frozen fixtures; Cox treated as non-applicable for Python-frozen parity and validated via R-native hardening tests | `PROGRESS.md` Latest Validation Snapshot (`PASS 309`, full suite; `python-parity-fixtures` pass) plus Cox behavior/determinism coverage in `test-stabl-fit.R` | Maintain Cox regression tests only (no Python-frozen Cox anchor) |
| `stabl/adaptive.py` adaptive behavior | `r-pkg/stablr/R/learner_adapters.R` | Complete | Tranche C deterministic mixed-alpha tests + behavior-level multinomial/Cox tests | Maintain regression tests only |
| `stabl/metrics.py` similarity measures | `r-pkg/stablr/R/metrics.R` | Complete with frozen-fixture parity checks | `phase7|python-parity-fixtures` focused run (`PASS 89`) plus fixture-backed assertions in `test-phase7.R` and references under `tests/testthat/fixtures/python_parity/metrics_*.csv` | Maintain regression tests + regenerate fixtures only when metric semantics intentionally change |
| `stabl/stabl.py` export functions | `r-pkg/stablr/R/exports.R` | Complete | Phase 7 (`PASS 247`); structure tests plus Biobank SSI real-data stress assertions in `test-phase7.R` (`PASS 62` under `filter = 'phase7'`) | Maintain regression tests only |
| `stabl/visualization.py` + `stabl/stabl.py` plot functions | `r-pkg/stablr/R/visualization.R` | Complete (ggplot2 port) | Phase 7 (`PASS 247`); smoke tests confirm ggplot object return | Phase 8 visual regression (optional) |
| `stabl/multi_omic_pipelines.py` workflow orchestration | `r-pkg/stablr/R/multiomic_workflows.R` | Complete for early/late + CV/train-validate slices; cooperative branch is intentionally `stablr`-only and experimental | Multi-omic workflow tests (documented in `PROGRESS.md`; `PASS 88` focused workflow suite) | Maintain early/late regressions and harden cooperative behavior assertions |
| `stabl/stacked_generalization.py` late fusion | `stacked_multi_omic()` in `multiomic_workflows.R` | Complete | Phase 5 completion log in `PROGRESS.md` | Maintain regression tests only |
| Cooperative middle-fusion equivalent (not in core Python package modules listed above) | Experimental `stablr` workflow extension backed by `multiview/` | Initial implementation complete; remains non-parity-blocking | `multiomic-workflows` focused suite (`PASS 88`) and full suite (`PASS 309`); cooperative arguments and guards now live in `R/multiomic_workflows.R` and `R/input_validation.R` | Harden behavior-level comparative tests and optional-dependency ergonomics |

## Update Protocol

After each implementation step:

1. Update `PROGRESS.md` with only factual completed work and validation results.
2. Update `PLAN.md` if priorities, sequencing, or acceptance gates changed.
3. Update this handoff file: current snapshot, next 3 tasks, and any parity-ledger status changes.