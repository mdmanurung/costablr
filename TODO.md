# costablr TODO

This is the short maintainer queue. Detailed scope remains in `PLAN.md`;
completed evidence remains in `PROGRESS.md`.

## Active Refactoring

- PR-12 decision: parallelism unification is still high risk. Safety tests now
  exist in `tests/testthat/test-parallel-determinism.R`; backend migration
  still needs explicit maintainer confirmation.
- PR-2B decision: only archive or compress canonical session docs after
  explicit maintainer confirmation.
- Keep `R/multiomic_workflows.R` focused on orchestration; new helper code
  should live in the domain module that owns it.

## Validation

- Run the full package suite after structural refactors:
  `conda run -n R4_51 Rscript -e "Sys.setenv(NOT_CRAN='true'); devtools::test('.', reporter = 'summary')"`
- Run audit tests after behavior-sensitive changes:
  `conda run -n R4_51 Rscript -e "devtools::load_all('.', quiet = TRUE); testthat::test_dir('tests/testthat', filter = 'audit', reporter = 'summary')"`
- Run `rcmdcheck --no-manual` before release-facing changes.
- Run `pkgdown::check_pkgdown()` after reference or vignette changes.

## Deferred Work

- Native candidates NAT-001 and NAT-003 remain profiling-driven follow-ups.
- Broad lint cleanup remains deferred until behavior refactors settle.
- CRAN metadata still needs release-owner review before any CRAN submission.
- Scratch/HPC notebooks and SLURM scripts are operational assets, not package
  runtime code; do not mix scratch workflow fixes with package refactors.
