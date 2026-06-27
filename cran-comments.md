## R CMD check results

0 errors | 0 warnings | 0 notes

Checked with:

```sh
R CMD build --no-build-vignettes .
R CMD check --no-manual --ignore-vignettes --no-build-vignettes stablr_0.1.0.tar.gz
```

Local testthat result: `FAIL 0 | WARN 0 | SKIP 1 | PASS 1611`.
The no-manual/no-vignette release check completed with `Status: OK`.

Documentation review builds:

- All six source vignettes rendered to `/tmp/stablr-vignette-review`.
- The pkgdown site built to `/tmp/stablr-pkgdown`.

## Submission notes

### Package-level startup messages (6)

When the package loads, 6 informational messages are emitted by the vendored
cooperative-learning engine. These arise because the S3 method registrations for
`coef.multiview`, `coef_ordered.multiview`, `predict.multiview`,
`predict.cv.multiview`, `coef.cv.multiview`, and `family.multiview` live in
parity-locked vendored source files (`R/cooperative-*.R`) that cannot carry
`@export` roxygen tags without breaking Python-parity guarantees. The NAMESPACE
entries for these six S3 methods are maintained manually with an explanatory
comment block. The messages are benign and do not affect functionality.

### Tests skipped on CRAN (2)

`tests/testthat/test-fdp-calibration.R` and
`tests/testthat/test-signal-recovery.R` carry `skip_on_cran()` guards. These
tests run long-form FDP calibration sweeps and signal-recovery benchmarks that
take several minutes. They run in CI (GitHub Actions) on push and pull-request
events; they are skipped on CRAN to stay within check time limits.

### Tests skipped in the local sandbox (1)

The local release check skipped one environment-dependent test because
`Sample Data/data.zip` is not available in this workspace
(`tests/testthat/test-phase7.R`). This does not affect the no-failure
release-check result.

### Compiled code (C++17)

The package vendors a subset of the multiview cooperative-learning engine
(glmnetpp headers + `wls_exp`) under `src/`. This has been tested to compile
cleanly with GCC >= 9 (Ubuntu 20.04+) and AppleClang >= 13 (macOS 12+).
`SystemRequirements: C++17` is declared in DESCRIPTION.
