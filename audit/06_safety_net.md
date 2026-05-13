# 06 Regression Safety Net

Remediation update: the audit tests were converted on 2026-05-13 from
"current bug" snapshots to fixed-behavior assertions. The old bug snapshot
files were removed because the corresponding tests no longer snapshot errors.

Status reviewed: 2026-05-13. The safety net is CURRENT. Running
`testthat::test_dir('tests/testthat', filter = 'audit', reporter = 'summary')`
passes all fixed INT/IMPL/performance audit assertions and reports exactly the
two expected NAT placeholder skips.

> **Re-review note (2026-05-13 evening).** Two post-audit code areas are NOT
> covered by any `test-audit-*.R` file:
>
> 1. `stabl_refit()` (`R/stabl_refit.R`, commit `5c11faa`). Only the
>    happy-path tests in `tests/testthat/test-stabl-refit.R` exercise it.
>    No audit-level guard pins the `family` → task-type table, the
>    multinomial `nnet::multinom` path, the cox `survival::coxph` path, the
>    Poisson path, or `predict.stabl_refit()`'s `newdata` schema validation.
> 2. Multinomial cooperative fusion one-vs-rest dispatch
>    (`R/multiomic_workflows.R`, commit `ed84166`). The audit's INT-003
>    cooperative-fusion misalignment risk now applies to this branch too,
>    but `tests/testthat/test-audit-multiomic-workflows.R` does not exercise
>    it. The relevant coverage lives in (non-audit)
>    `tests/testthat/test-multiomic-workflows.R`.
>
> If the audit safety-net contract should be extended to cover these areas,
> add new `test_that()` blocks to the existing audit files rather than
> creating new files — same convention as the original audit suite.

## Formatting

- Required command attempted: `air format .`
- Result: not run. The escalation request was rejected because formatting the
  whole repository could rewrite files outside the audit write scope.
- `air` was also not found in the `R4_51` runtime preflight.

## Tests added

### `tests/testthat/test-audit-stabl-accessors.R`

- Guards: INT-001 / IMPL-001.
- Coverage:
  - `get_support()` rejects `new_hard_threshold = NA_real_`.
  - `get_support()` rejects a length-two threshold vector.
  - `get_support()` rejects a user-supplied threshold of zero but accepts an
    FDP+-derived threshold of zero from the default sweep grid.
- Seeds/tolerance: none.

### `tests/testthat/test-audit-stabl-fit.R`

- Guards: IMPL-002, IMPL-003.
- Coverage:
  - zero artificial-feature count is rejected before score accumulation.
  - positive `sample_fraction` that floors to zero is rejected before
    bootstrap sampling.
- Seeds/tolerance:
  - `withr::local_seed(101)` for zero artificial-feature count.
  - `withr::local_seed(102)` for zero subsample count.
- Snapshots: none; stale bug snapshots were removed.

### `tests/testthat/test-audit-input-validation.R`

- Guards: INT-001.
- Coverage:
  - duplicate sample IDs are rejected by `validate_sample_alignment()`.
  - `.subset_outcome_by_ids()` rejects duplicate direct `sample_ids`.
  - duplicate outcome and group sample IDs are rejected.
- Seeds/tolerance: none.

### `tests/testthat/test-audit-multiomic-workflows.R`

- Guards: INT-002, INT-003, INT-004, INT-005.
- Coverage:
  - no-colname selected features propagate fallback names into selected-matrix
    construction.
  - shuffled named `y_train` is aligned before late fusion.
  - validation predictors without `y_valid` return validation-row predictions.
  - binary `stacked_multi_omic()` rejects a recycled short outcome.
- Seeds/tolerance:
  - `withr::local_seed(201)`, `202`, and `203`.
- Snapshots: none; stale bug snapshots were removed.

### `tests/testthat/test-audit-artificial-features.R`

- Guards: IMPL-004.
- Coverage:
  - direct `make_modelx_knockoff_features(..., random_state = 123L)` is
    reproducible when global RNG state differs.
- Seeds/tolerance:
  - `withr::local_seed(301)`.
  - Uses `skip_if_not_installed("knockoff")`.

### `tests/testthat/test-audit-mvr-boundary.R`

- Guards: INT-006.
- Coverage:
  - direct `costablr:::mvr_solve_ungrouped_cpp()` now rejects a
    non-permutation update order.
  - guarded `.solve_mvr()` rejects the same update order.
- Seeds/tolerance: none.
- Snapshots: none; stale bug snapshots were removed.

### `tests/testthat/test-audit-native-candidates.R`

- Guards: NAT-001, NAT-002, NAT-003.
- Coverage:
  - required skipped parity placeholders for NAT-001 and NAT-003.
  - R-vs-C++ partition parity for the NAT-002 correlation-union helper.
- Seeds/tolerance: none.
- Expected skips:
  - `NAT-001 deferred; pure-R stack-weight optimizations cleared the profiling gate`
  - `NAT-003 pending - see audit/05_native_candidates.md`

### `tests/testthat/test-audit-performance-optimizations.R`

- Guards: PERF-001, PERF-002, PERF-003, PERF-005, PERF-006.
- Coverage:
  - old-reference parity for binary/regression and multiclass stacking.
  - glmnet/sparsegl coefficient-batch extraction parity.
  - grouped-bootstrap fixed-seed index identity and prepared-sampler parity.
  - correlation-group partition parity and preallocated noise-group append
    identity.
- Seeds/tolerance:
  - fixed seeds per scenario.
  - numeric tolerance `1e-12`; exact checks for sampled indices, names,
    labels, and partition membership.

## Validation

Initial snapshot generation during the read-only audit:

```r
Sys.setenv(TESTTHAT_UPDATE = "true", NOT_CRAN = "true")
devtools::load_all(".", quiet = TRUE)
testthat::test_file("tests/testthat/test-audit-stabl-fit.R")
testthat::test_file("tests/testthat/test-audit-multiomic-workflows.R")
testthat::test_file("tests/testthat/test-audit-mvr-boundary.R")
```

- Result: snapshots generated successfully during the read-only audit.
  These stale bug snapshots were removed during remediation after the tests
  were converted to fixed-behavior assertions.

Full test suite after performance remediation:

```r
devtools::load_all(".", quiet = TRUE)
testthat::test_dir("tests/testthat", reporter = "summary")
```

- Result: passed.
- Warnings: same two `future` package build-version warnings observed in the
  Phase 1 baseline.
- Skips: NAT-001 and NAT-003 placeholders plus the two CRAN-gated tests.

Post-remediation check:

```r
devtools::check(".", error_on = "never")
```

- Result: `0 errors`, `1 WARNING`, `2 NOTEs`.
- `costablr-python-parity.Rmd` rebuilds successfully.
- Remaining warning/note items are local `qpdf` availability, timestamp
  verification, and the conda `-march=nocona` compile flag.

Pkgdown metadata check:

```r
pkgdown::check_pkgdown()
```

- Result: no problems found.
- POST-AUDIT NOTE 2026-05-13: this check was last run BEFORE commit `5c11faa`
  exported `stabl_refit()`. The function is not present in `_pkgdown.yml`,
  so a fresh `pkgdown::check_pkgdown()` may reproduce the IMPL-007 missing-
  topic pattern. Re-run is recommended before the next release.
