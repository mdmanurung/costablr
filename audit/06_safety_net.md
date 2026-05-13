# 06 Regression Safety Net

## Formatting

- Required command attempted: `air format .`
- Result: not run. The escalation request was rejected because formatting the
  whole repository could rewrite files outside the audit write scope.
- `air` was also not found in the `R4_51` runtime preflight.

## Tests added

### `tests/testthat/test-audit-stabl-accessors.R`

- Guards: INT-001 / IMPL-001.
- Coverage:
  - `get_support()` currently returns an all-`NA` mask for
    `new_hard_threshold = NA_real_`.
  - `get_support()` currently recycles a length-two threshold vector.
- Seeds/tolerance: none.

### `tests/testthat/test-audit-stabl-fit.R`

- Guards: IMPL-002, IMPL-003.
- Coverage:
  - zero artificial-feature count currently errors during score accumulation.
  - positive `sample_fraction` that floors to zero currently fails after
    bootstrap class-diversity retries.
- Seeds/tolerance:
  - `withr::local_seed(101)` for zero artificial-feature count.
  - `withr::local_seed(102)` for zero subsample count.
- Snapshots:
  - `tests/testthat/_snaps/audit-stabl-fit.md`

### `tests/testthat/test-audit-input-validation.R`

- Guards: INT-001.
- Coverage:
  - duplicate sample IDs currently pass `validate_sample_alignment()`.
  - `.subset_outcome_by_ids()` currently reuses the first duplicate outcome
    match.
- Seeds/tolerance: none.

### `tests/testthat/test-audit-multiomic-workflows.R`

- Guards: INT-002, INT-003, INT-004, INT-005.
- Coverage:
  - no-colname selected features currently fail selected-matrix construction.
  - shuffled named `y_train` currently preserves selected features but changes
    late-fusion predictions.
  - validation predictors without `y_valid` currently return
    `logical(0)` late-fusion validation predictions.
  - binary `stacked_multi_omic()` currently accepts a recycled short outcome.
- Seeds/tolerance:
  - `withr::local_seed(201)`, `202`, and `203`.
- Snapshots:
  - `tests/testthat/_snaps/audit-multiomic-workflows.md`

### `tests/testthat/test-audit-artificial-features.R`

- Guards: IMPL-004.
- Coverage:
  - direct `make_modelx_knockoff_features(..., random_state = 123L)` currently
    is not reproducible when global RNG state differs.
- Seeds/tolerance:
  - `withr::local_seed(301)`.
  - Uses `skip_if_not_installed("knockoff")`.

### `tests/testthat/test-audit-mvr-boundary.R`

- Guards: INT-006.
- Coverage:
  - direct `costablr:::mvr_solve_ungrouped_cpp()` currently accepts a
    non-permutation update order.
  - guarded `.solve_mvr()` rejects the same update order.
- Seeds/tolerance: none.
- Snapshots:
  - `tests/testthat/_snaps/audit-mvr-boundary.md`

### `tests/testthat/test-audit-native-candidates.R`

- Guards: NAT-001, NAT-002, NAT-003.
- Coverage:
  - required skipped parity placeholders for future native ports.
- Seeds/tolerance: none.
- Expected skips:
  - `NAT-001 pending - see audit/05_native_candidates.md`
  - `NAT-002 pending - see audit/05_native_candidates.md`
  - `NAT-003 pending - see audit/05_native_candidates.md`

## Validation

Snapshot generation:

```r
Sys.setenv(TESTTHAT_UPDATE = "true", NOT_CRAN = "true")
devtools::load_all(".", quiet = TRUE)
testthat::test_file("tests/testthat/test-audit-stabl-fit.R")
testthat::test_file("tests/testthat/test-audit-multiomic-workflows.R")
testthat::test_file("tests/testthat/test-audit-mvr-boundary.R")
```

- Result: snapshots generated successfully. testthat reported snapshot-addition
  warnings during generation, as expected.

Full test suite with snapshots active:

```r
Sys.setenv(NOT_CRAN = "true")
devtools::test(".")
```

- Result: `FAIL 0`, `WARN 2`, `SKIP 3`, `PASS 1475`.
- Warnings: same two `future` package build-version warnings observed in the
  Phase 1 baseline.
- Skips: three intentional NAT parity placeholders.

Post-safety-net check:

```r
devtools::check(".", error_on = "never")
```

- Result: failed at the same vignette-build stage as Phase 1 baseline, before
  R CMD check completed.
- Failure: `costablr-python-parity.Rmd` chunk `ool-fit`, stale
  `stablr::stabl_fit()` backtrace rejecting `modelx_knockoff`.
- Status versus baseline: no worse observed; same blocking failure.

