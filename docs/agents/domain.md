# Domain Docs

How engineering skills should consume costablr's domain documentation when exploring the codebase.

## Before exploring, read these

- `AGENTS.md` for workflow policy and documentation discipline.
- `STABL.md` for algorithm semantics and Python-to-R parity rules.
- `ARCHITECTURE.md` for package structure, module ownership, and runtime flows.
- `PLAN.md` for forward roadmap and acceptance gates.
- `PROGRESS.md` for completed work and validation evidence.
- `HANDOFF.md` for current operator snapshot and validation commands.
- `REFACTORING.md` for active refactoring status.
- `audit/` for prior package maps, findings, resolved items, deferred items, and safety net.

## Precedence

When docs conflict, follow the precedence order in `AGENTS.md`. In particular:

- Treat `STABL.md` as authoritative for algorithm behavior.
- Treat `REFACTORING.md` as the current cleanup baseline, not as a separate roadmap to ignore.
- Use `PROGRESS.md` only for factual completed work and validation evidence.

## Area-specific follow-up

After the required docs, read the source, tests, and user-facing docs relevant to the task:

- Core STABL: `R/stabl_fit.R`, `R/stabl_refit.R`, `R/artificial_features.R`, `R/fdp_control.R`.
- Multi-omic workflows: `R/multiomic_workflows.R`, `R/late_fusion.R`, `R/cooperative_fusion.R`.
- Cross-validation: `R/cv_helpers.R`, `R/nested_cv.R`.
- Public contracts: `R/stabl_accessors.R`, `NAMESPACE`, `README.md`, vignettes.
- Validation: `tests/testthat/`, parity fixtures, and documented commands in `HANDOFF.md`.

Do not infer architectural intent from file names alone. Verify behavior against implementation, tests, docs, and entry points.
