# CRAN submission comments — DRAFT

This file is intentionally provisional. Do not submit it until the exact
`stablr_0.1.1.tar.gz` release candidate has completed current R release/devel,
Windows, macOS, Win-builder, and sanitizer checks. Final error, warning, note,
test, and skip counts will be copied from those immutable-candidate results.

This will be the first CRAN submission of `stablr`.

## Vendored cooperative S3 registrations

The package vendors a parity-locked subset of the cooperative-learning engine.
Seven cooperative S3 registrations are maintained manually in `NAMESPACE`
because the vendored source files (`R/cooperative-*.R`) cannot carry roxygen
`@export` tags without breaking parity provenance: `coef.multiview`,
`coef.cv.multiview`, `family.multiview`, `family.cv.multiview`,
`plot.multiview`, `predict.multiview`, and `predict.cv.multiview`.

## Tests skipped on CRAN (3)

`tests/testthat/test-fdp-calibration.R`,
`tests/testthat/test-methodology-validation-runner.R`, and
`tests/testthat/test-signal-recovery.R` carry `skip_on_cran()` guards. These
long-form calibration, methodology-validation, and signal-recovery sweeps run
in CI and are skipped on CRAN to keep check time within policy limits.

## Compiled code

The package vendors a GPL-2 cooperative-learning implementation and glmnetpp
headers under `src/`, declares `SystemRequirements: C++17`, and therefore is
R-native without requiring a Python runtime rather than pure R.
