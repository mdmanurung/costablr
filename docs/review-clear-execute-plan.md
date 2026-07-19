# stablr Review-Clear-Execute Frozen Plan

Date: 2026-06-27
Repository: /exports/para-lipg-hpc/mdmanurung/stablr
Status: frozen for fresh-session execution

## Objective

Harden stablr for release across API completeness, validation, FDP+/decoy semantics, performance, methodology, documentation, and reproducible verification.

## Frozen Plan

1. Preserve the current release-hygiene diff and re-read `DESCRIPTION`, `NAMESPACE`, `R/`, `tests/`, `README.md`, `_pkgdown.yml`, and `docs/` before editing. Do not revert prior or user changes.
2. Audit every exported function in `NAMESPACE` for validation, documented arguments, examples or usage docs, return shape, and presence in API/pkgdown docs.
3. Add shared argument validators for scalar integer-like and numeric parameters, then apply them across core fitting, nested CV, multi-omic workflows, cooperative options, plotting, and export helpers. Reject `NA`, `Inf`, length greater than 1, fractional integer inputs, zero or negative counts, invalid proportions, and numeric strings where numeric input is required.
4. Reject duplicate sample IDs and duplicate feature names before any `setequal()`, `match()`, subsetting, train/validation split, multi-omic concatenation, or validation-data alignment.
5. Fix FDP+ decoy injection: when `artificial_type` is non-`NULL`, inject at least one artificial feature and cap at `ncol(x)`. FDP+ scaling must use the effective proportion `n_injected / n_features`; retain the requested value separately if needed for reporting.
6. Document all supported decoy strategies everywhere public users see them: `random_permutation`, `knockoff`, `knockoff_equi`, and `knockoff_mvr`.
7. Add `transform_stabl(object, x, new_hard_threshold = NULL)` in `R/stabl_accessors.R`, export it, and document it. It returns the selected columns of matrix/data.frame `x` in fitted feature order, preserves rows, returns a two-dimensional object, errors on duplicate or missing column names, and supports threshold override. Do not change existing accessor signatures except to correct stale docs.
8. Move socket probing out of production code. If `.can_open_server_socket()` has no runtime callers, delete it from `R/stabl_fit.R`, add a test helper, and update RNG determinism tests to skip only when PSOCK/server sockets are unavailable.
9. Add `matrixStats` as a hard `Imports` dependency and keep the package-local `rowMaxs()` wrapper, delegating to `matrixStats::rowMaxs()` while preserving zero-row and one-column behavior.
10. Before vectorizing `stacked_multi_omic()`, add characterization tests for seeded binary, regression, and multiclass behavior, including missing rows, all-NA rows, tie behavior, exact weights, predictions, probability shapes, and invalid `n_iter`.
11. Vectorize or batch `stacked_multi_omic()` only where seeded output parity is preserved. Preserve strict `score > best_score`, RNG order, finite-value masking, multiclass per-sample renormalization, and public return shapes. If exact multiclass parity cannot be preserved cleanly, leave that path scalar and document the benchmark result.
12. Add committed Python-parity fixtures under `tests/testthat/fixtures/python_parity/` with provenance or a generation script. Tests must fail, not skip, if bundled fixtures are missing.
13. Add release-gated correctness tests for validation, FDP+ edge cases, `transform_stabl()`, row maxima, parity fixtures, and stacking behavior. Add broader non-CRAN methodology and benchmark scripts with fixed seeds and artifact output under `/tmp`.
14. Update `README.md`, vignettes, `docs/API_REFERENCE.md`, `docs/PYTHON_TO_R_MAPPING.md`, `docs/CODEMAPS/architecture.md`, `_pkgdown.yml`, `NEWS.md`, `cran-comments.md`, generated `.Rd`, `DESCRIPTION`, and `NAMESPACE` as required.

## Constraints and Non-Goals

- Preserve existing release-hygiene edits and unrelated user changes.
- Do not perform destructive git or filesystem operations.
- Keep existing public API names stable; breaking changes should be limited to stricter validation errors.
- Do not rely on CodeRabbit, credentials, production systems, or restricted network access.
- Do not broaden the work into new modeling features beyond the listed hardening tasks.

## Validation Commands

- `Rscript -e "devtools::test()"`
- `Rscript -e "devtools::test(filter = 'rng-determinism|input-validation|fdp|multiomic|accessor|phase7')"`
- `Rscript -e "roxygen2::roxygenise(roclets = 'rd')"`
- `cd /tmp && R CMD build /exports/para-lipg-hpc/mdmanurung/stablr`
- `R CMD check --as-cran /tmp/stablr_0.1.0.tar.gz`
- `Rscript -e "pkgdown::build_site('/exports/para-lipg-hpc/mdmanurung/stablr', install = FALSE, override = list(destination = '/tmp/stablr-pkgdown'))"`
- `Rscript /exports/para-lipg-hpc/mdmanurung/stablr/inst/analysis/run_methodology_validation.R --out /tmp/stablr-methodology-validation`
- `Rscript /exports/para-lipg-hpc/mdmanurung/stablr/bench/stacked_multi_omic_benchmark.R --out /tmp/stablr-benchmarks`

## Stop Conditions

- Stop if repository state has drifted in a way that invalidates this plan.
- Stop if an implementation decision is ambiguous after inspecting the named files.
- Stop before destructive git or filesystem operations.
- Stop before credentials, production systems, or restricted network access.
- Stop if required R dependencies or data are unavailable and cannot be installed without permission.

## Required Artifacts

- `docs/review-clear-execute-plan.md`
- `docs/review-clear-execute-tasks.md`
- Updated R code, tests, docs, metadata, and generated `.Rd`
- Bundled parity fixtures with provenance
- Methodology validation and benchmark scripts
- Final report summarizing changes, validation results, skipped checks, and residual risks
