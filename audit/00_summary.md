# 00 Summary

Audit status: complete through Phase 7. The original read-only audit did not
modify functional code in `R/` or `src/`.

Remediation status: implemented 2026-05-13 for INT-001 through INT-006,
IMPL-001 through IMPL-007, and the medium-severity performance tranche
PERF-001, PERF-002, PERF-003, PERF-005, and PERF-006. NAT-002 is fixed by the
profiling-gated correlation-union helper; NAT-001 and NAT-003 remain deferred
skipped placeholders.

Status annotation update: reviewed 2026-05-13. All audit documents now carry
explicit fixed/deferred/not-planned status notes. The audit regression subset
passes with the expected NAT placeholder skips.

## Per-document status

- `01_package_map.md`: INVENTORY. Baseline diagnostics that failed during the
  audit (`devtools::check()` vignette rebuild and pkgdown index metadata) are
  fixed in the post-remediation state.
- `02_interface_findings.md`: FIXED. INT-001 through INT-006 have code fixes
  and audit regression assertions.
- `03_intent_findings.md`: FIXED. IMPL-001 through IMPL-007 have code or
  documentation fixes and audit regression assertions where behavior changed.
- `04_performance_findings.md`: PARTIAL FIXED. PERF-001, PERF-002, PERF-003,
  PERF-005, and PERF-006 have profiling-gated fixes; PERF-004, PERF-007, and
  PERF-008 remain deferred low-severity opportunities.
- `05_native_candidates.md`: PARTIAL FIXED / NOT PLANNED. NAT-002 is fixed;
  NAT-001 and NAT-003 remain deferred with skipped parity placeholders;
  NAT-004 through NAT-006 are explicitly rejected for first-pass native
  implementation.
- `06_safety_net.md`: CURRENT. The listed audit tests are the active closure
  safety net, with NAT-001 and NAT-003 skipped intentionally.

## Baseline status

- `devtools::load_all('.', quiet = TRUE)`: PASS with package-build-version
  warning for `testthat`.
- Phase 1 `devtools::test('.')`: `PASS 1458`, `FAIL 0`, `WARN 2`, `SKIP 0`.
- Phase 6 `devtools::test('.')` with `NOT_CRAN=true` so snapshots run:
  `PASS 1475`, `FAIL 0`, `WARN 2`, `SKIP 3`.
- Current full local test-directory skips are NAT-001, NAT-003, and two
  CRAN-gated tests.
- `devtools::check('.', error_on = 'never')`: FAIL in both baseline and
  post-safety-net runs at `costablr-python-parity.Rmd` vignette rebuild.
- `pkgdown::check_pkgdown()`: FAIL in baseline because
  `_pkgdown.yml` omits `costablr-tcga-nestedcv`.

## Remediation status

- Fixed duplicate sample-ID rejection, named outcome alignment in multi-omic
  workflows, fallback feature-name propagation for unnamed matrices,
  validation-prediction row counts without `y_valid`, recycled stacking
  outcomes, scalar/derived parameter validation, direct model-X helper
  seeding, and the direct MVR C++ update-order boundary.
- Removed stale bug snapshots after converting audit tests to fixed-behavior
  assertions.
- Refreshed Python-parity source/generated vignette text for
  `modelx_knockoff` and `seq(0, 0.99, by = 0.01)`.
- Removed internal artificial helpers from public-facing API/pkgdown indexes.
- Added `costablr-tcga-nestedcv` and `stabl_multiomic_nested_cv` to pkgdown
  metadata.
- Added `.Rbuildignore` rules so R source builds exclude repository-only
  sample data, notebooks, audit reports, and planning docs.
- Closure validation:
  - Audit safety net: pass, with NAT-001/002/003 skipped intentionally.
  - Full test directory after the performance tranche: pass, with `WARN 2`
    from existing `future` package build-version warnings and `SKIP 4`
    (NAT-001, NAT-003, and two CRAN-gated tests).
  - `devtools::check('.', error_on = 'never')`: `0 errors`, `1 WARNING`,
    `2 NOTEs`; remaining items are local `qpdf`, timestamp, and conda
    toolchain warnings/notes.
  - `pkgdown::check_pkgdown()`: no problems found.

## Top findings

1. INT-003: late fusion can use shuffled named `y_train` positionally after
   core STABL aligned by names. Severity HIGH, confidence HIGH.
2. INT-001: duplicate sample IDs pass validation and are first-matched.
   Severity HIGH, confidence HIGH.
3. INT-002: fallback feature names are not propagated to unnamed matrices,
   breaking selected-matrix construction. Severity HIGH, confidence HIGH.
4. IMPL-002: small artificial proportions can produce zero artificial features
   and fail with internal subscript errors. Severity HIGH, confidence HIGH.
5. INT-005: `stacked_multi_omic()` accepts recycled short outcomes. Severity
   MEDIUM, confidence HIGH.
6. INT-004: late-fusion validation predictors without `y_valid` return
   `logical(0)`. Severity MEDIUM, confidence HIGH.
7. IMPL-003: positive `sample_fraction` can floor to zero and fail late.
   Severity MEDIUM, confidence HIGH.

## Dependency-ordered fix plan

1. Fix name alignment first:
   - INT-001 duplicate ID rejection.
   - INT-003 align `y_train`/`y_valid` once in multi-omic workflows.
   - INT-005 length-check `stacked_multi_omic()` for binary/regression.
2. Fix selected-feature shape contracts:
   - INT-002 propagate fallback feature names to matrices.
   - INT-004 allocate validation predictions from validation row count.
3. Fix scalar and derived parameter validation:
   - IMPL-001 validate `new_hard_threshold`.
   - IMPL-002 reject or explicitly handle zero artificial-feature counts.
   - IMPL-003 reject zero `n_subsamples` early.
4. Fix documentation/tooling drift:
   - IMPL-004 model-X helper seed docs/behavior.
   - IMPL-005 public/internal artificial-helper docs.
   - IMPL-006 stale parity docs/generated artifacts.
   - IMPL-007 pkgdown nested-CV article index.
5. Re-run full tests, then address `devtools::check()` vignette failure.

## Rcpp roadmap

1. NAT-001: stack-weight scoring loops. Pure-R batching/vectorization cleared
   the profiling gate, so no native port is currently needed.
2. NAT-002: correlation-group union step. Fixed with
   `corr_groups_from_corr_cpp()` after the pure-R union refactor missed the
   strict 10% profiling gate.
3. NAT-003: MVR rank-update solver. Highest risk; keep pure-R fallback and
   current native solver until parity tests justify changes.

Do not port glmnet/sparsegl fitting, bootstrap samplers, FDP+, or similarity
metrics before simpler pure-R improvements are attempted.

## Implemented NEWS bullets

- `get_support()` now validates `new_hard_threshold` as a single non-missing
  numeric value in `(0, 1]`.
- `make_modelx_knockoff_features()` now documents and applies its direct
  `random_state` behavior consistently.
- `stacked_multi_omic()` now rejects binary/regression outcomes whose length
  does not match the number of prediction rows.
- `stabl_fit()` now rejects artificial-feature settings that would generate
  zero artificial features.
- `stabl_fit()` now rejects bootstrap settings whose `sample_fraction` floors
  to zero sampled rows.
- `stabl_multiomic_train_validate()` now aligns named training and validation
  outcomes before late-fusion and cooperative-fusion branches.
- `stabl_multiomic_train_validate()` now preserves generated fallback feature
  names for unnamed matrices when constructing selected-feature matrices.
- `stabl_multiomic_train_validate()` now returns validation predictions with
  the correct row count when validation predictors are supplied without
  validation outcomes.
- `validate_sample_alignment()` now rejects duplicate sample IDs in predictors,
  outcomes, and groups.

## pkgdown impact

- `make_rp_features()` and `make_modelx_knockoff_features()` remain internal
  and were removed from `_pkgdown.yml`.
- If they become exported, update `NAMESPACE`, roxygen docs, and `_pkgdown.yml`
  intentionally.
- `costablr-tcga-nestedcv` was added to `_pkgdown.yml`.

## Residual notes

- The original `devtools::check()` failure using a stale `stablr::stabl_fit()`
  backtrace is resolved after removing ignored vignette caches and rerendering
  `costablr-python-parity.Rmd`.
- Cooperative-fusion outcome misalignment is inferred from positional call
  sites but was not dynamically verified.
- Sparse-group missing-dependency behavior was not dynamically verified because
  `sparsegl` is installed in the audit environment.

## Not audited

- Full package-wide performance benchmarks were not run; the medium-severity
  performance tranche was validated with targeted old-vs-new profiling gates.
- No CRAN-like clean library matrix was created.
- No external Python parity reruns were performed.
- Heavy vignettes and SLURM workflows were not executed beyond the requested
  `devtools::check()` and pkgdown diagnostics.

## Gate

Audit remediation complete. Safety net is updated to assert the fixed
contracts. The full local test directory passes with WARN 2 and SKIP 4;
`devtools::check()` has 0 errors and no longer fails at
`costablr-python-parity.Rmd`; pkgdown metadata checks are clean. NAT-001 and
NAT-003 remain deferred.
