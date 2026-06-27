# stablr Robustness, Methodology, Performance, and API Hardening Plan

Date: 2026-06-27
Project: /exports/para-lipg-hpc/mdmanurung/stablr
Status: planned

## Objective

Harden `stablr` for release by addressing correctness, methodological
validation, performance/vectorization, and public API clarity.

## Plan

1. Reject ambiguous inputs: duplicate sample IDs in `x`, `y`, `groups`, omic
   matrices, and validation data; reject duplicate user-supplied feature names.
2. Add shared validators for integer-like and scalar arguments, including
   `n_bootstraps`, `n_lambda`, `n_explore`, `workers`, `n_iter`, CV fold counts,
   thresholds, and proportions.
3. Fix FDP+ decoy handling so non-NULL `artificial_type` always injects at
   least one decoy, capped at `ncol(x)`.
4. Document all decoy strategies consistently: `random_permutation`,
   `knockoff`, `knockoff_equi`, and `knockoff_mvr`.
5. Add `transform_stabl()` for selected-column transformation, matching the
   Python `Stabl.transform()` migration gap.
6. Move the socket probe out of production code into test helpers unless
   runtime code needs it.
7. Add `matrixStats` and use it for row-wise maxima while preserving edge-case
   behavior.
8. Vectorize or batch `stacked_multi_omic()` weight evaluation and multiclass
   probability stacking.
9. Add non-CRAN methodological simulations for null FDP+ calibration, signal
   recovery, correlated predictors, class imbalance, Cox, and multi-omic
   workflows.
10. Embed a small stable parity fixture so core parity checks do not depend only
    on `stablr-experiments`.

## Validation

Run:

- `devtools::test()`
- `R CMD build --no-build-vignettes`
- `R CMD check --no-manual --ignore-vignettes --no-build-vignettes`
- `pkgdown::build_site('.', install = FALSE, override = list(destination = '/tmp/stablr-pkgdown'))`

## Notes

CodeRabbit was not run because agent authentication was blocked. Existing core
API names should remain stable; breaking changes should be limited to stricter
validation for invalid or ambiguous inputs.
