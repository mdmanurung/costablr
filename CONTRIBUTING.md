# Contributing to costablr

This package prioritizes STABL parity, reproducibility, and small
behavior-preserving changes. Read `STABL.md` before changing selector
semantics.

## Documentation Order

- `STABL.md` owns algorithm semantics and Python-to-R parity rules.
- `PLAN.md` owns forward scope.
- `PROGRESS.md` owns completed work and validation evidence.
- `HANDOFF.md` owns current operator state.
- `AGENTS.md` owns agent workflow policy.
- `ARCHITECTURE.md` is the human maintainer map.

When behavior changes, update the canonical document first.

## Refactoring Rules

- Preserve public APIs and S3 object contracts unless a migration plan is
  explicitly accepted.
- Add characterization tests before moving code.
- Keep optional dependencies optional with `requireNamespace()` guards.
- Do not change random-state behavior silently.
- Do not mix scratch/HPC workflow changes with package runtime refactors.
- Use accessors in public-facing examples; direct field access is acceptable
  in internal characterization tests.

## Parity Rules

These invariants are not cleanup candidates:

- `stabl_fit()` remains the core STABL selector boundary.
- `stabl_refit()` owns selection plus final unpenalized predictive refit.
- FDP+ and support thresholding use strict `>`.
- Per-bootstrap coefficient masks use `>= bootstrap_threshold`.
- FDP+ artificial-feature scaling uses `(1 / pi)`.
- Default subsampling remains `sample_fraction = 0.5`, `replace = FALSE`.
- Sample alignment is name-based and rejects duplicate IDs.
- No Python or tidymodels runtime dependency.
- Cooperative fusion uses `multiview` only.

## Adding a Learner Adapter

1. Add the adapter in `R/learner_adapters.R`.
2. Keep the adapter return contract as a logical selection matrix with rows
   matching the fitted feature matrix and columns matching the lambda grid.
3. Apply `bootstrap_threshold` using `>=`.
4. Preserve deterministic behavior under per-bootstrap seeds.
5. Add focused adapter tests and at least one `stabl_fit()` integration test.

## Validation Commands

```bash
conda run -n R4_51 Rscript -e "Sys.setenv(NOT_CRAN='true'); devtools::test('.', reporter = 'summary')"
conda run -n R4_51 Rscript -e "devtools::load_all('.', quiet = TRUE); testthat::test_dir('tests/testthat', filter = 'audit', reporter = 'summary')"
conda run -n R4_51 Rscript -e 'res <- rcmdcheck::rcmdcheck(args = c("--no-manual"), error_on = "never"); print(res)'
conda run -n R4_51 Rscript -e "pkgdown::check_pkgdown()"
```

For narrow changes, run the nearest targeted test file first, then the full
suite before handoff.

## Vignettes and Site

- Vignettes live in `vignettes/`.
- Generated HTML and caches should not be part of package runtime changes.
- Use `pkgdown::check_pkgdown()` after reference structure changes.

## Pull Request Shape

Keep PRs small enough for one maintainer to review:

- Explain the behavior being preserved or changed.
- List files touched by module.
- Include targeted validation commands and outcomes.
- Update `PLAN.md`, `PROGRESS.md`, and `HANDOFF.md` when implementation scope
  changes or completes.
