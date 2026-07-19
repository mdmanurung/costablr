## R CMD check results

0 errors | 0 warnings | 1 note

Checked with:

```sh
R CMD build .
R CMD check --as-cran stablr_0.1.0.tar.gz
```

The full local `--as-cran` check completed with `Status: 1 NOTE`.
The remaining NOTE is the expected CRAN incoming feasibility note for a first
submission:

- New submission

Installed testthat result in the `--as-cran` check:
`FAIL 0 | WARN 0 | SKIP 4 | PASS 1657`.

Documentation review builds:

- All six source vignettes rendered to `/tmp/stablr-vignette-review`.
- The pkgdown site built to `/tmp/stablr-pkgdown`.

## Submission notes

### Vendored cooperative S3 registrations

The package vendors a parity-locked subset of the cooperative-learning engine.
Seven cooperative S3 registrations are maintained manually in `NAMESPACE`
because the vendored source files (`R/cooperative-*.R`) cannot carry roxygen
`@export` tags without breaking parity provenance: `coef.multiview`,
`coef.cv.multiview`, `family.multiview`, `family.cv.multiview`,
`plot.multiview`, `predict.multiview`, and `predict.cv.multiview`.
`R CMD check --as-cran` reports S3 registration as OK.

### Tests skipped on CRAN (3)

`tests/testthat/test-fdp-calibration.R`,
`tests/testthat/test-methodology-validation-runner.R`, and
`tests/testthat/test-signal-recovery.R` carry `skip_on_cran()` guards. These
tests run long-form FDP calibration, deterministic methodology-validation, and
signal-recovery sweeps that take several minutes. They run in CI (GitHub
Actions) on push and pull-request events; they are skipped on CRAN to stay
within check time limits.

### Additional local skips (1)

The local `--as-cran` check also skipped one environment-dependent real-data
test because `Sample Data/data.zip` is not available in this workspace
(`tests/testthat/test-phase7.R`). This explicit environment guard does not
affect the no-failure release-check result.

Source-tree metadata and vignette-readiness tests run under `devtools::test()`
but are excluded from the built tarball because their inputs (`cran-comments.md`,
`.Rbuildignore`, and source `vignettes/`) are not installed test artifacts.

### Compiled code (C++17)

The package vendors a subset of the multiview cooperative-learning engine
(glmnetpp headers + `wls_exp`) under `src/`. This has been tested to compile
cleanly with GCC >= 9 (Ubuntu 20.04+) and AppleClang >= 13 (macOS 12+).
`SystemRequirements: C++17` is declared in DESCRIPTION.
