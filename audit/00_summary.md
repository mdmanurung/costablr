# 00 Summary

Audit status: complete through Phase 7. No functional code in `R/` or `src/`
was modified.

## Baseline status

- `devtools::load_all('.', quiet = TRUE)`: PASS with package-build-version
  warning for `testthat`.
- Phase 1 `devtools::test('.')`: `PASS 1458`, `FAIL 0`, `WARN 2`, `SKIP 0`.
- Phase 6 `devtools::test('.')` with `NOT_CRAN=true` so snapshots run:
  `PASS 1475`, `FAIL 0`, `WARN 2`, `SKIP 3`.
- The three skips are intentional native parity placeholders.
- `devtools::check('.', error_on = 'never')`: FAIL in both baseline and
  post-safety-net runs at `costablr-python-parity.Rmd` vignette rebuild.
- `pkgdown::check_pkgdown()`: FAIL in baseline because
  `_pkgdown.yml` omits `costablr-tcga-nestedcv`.

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

1. NAT-001: stack-weight scoring loops. Try pure-R batching first; port only
   after profiling confirms the loop remains hot.
2. NAT-002: correlation-group union step. Try vectorized edge extraction first.
3. NAT-003: MVR rank-update solver. Highest risk; keep pure-R fallback and
   current native solver until parity tests justify changes.

Do not port glmnet/sparsegl fitting, bootstrap samplers, FDP+, or similarity
metrics before simpler pure-R improvements are attempted.

## Draft NEWS bullets

Draft only; `NEWS.md` was not edited because fixes are not approved yet.

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

- If `make_rp_features()` or `make_modelx_knockoff_features()` remain internal,
  remove them from `_pkgdown.yml`.
- If they become exported, update `NAMESPACE`, roxygen docs, and `_pkgdown.yml`
  intentionally.
- Add or explicitly exclude `costablr-tcga-nestedcv` in `_pkgdown.yml`.

## UNCERTAIN items

- The exact cause of `devtools::check()` using a `stablr::stabl_fit()`
  backtrace while the current `costablr-python-parity.Rmd` source loads
  `costablr` is UNCERTAIN. Stale vignette cache is plausible because ignored
  `vignettes/costablr-python-parity-cache/` exists, but this was not modified
  during the audit.
- Cooperative-fusion outcome misalignment is inferred from positional call
  sites but was not dynamically verified.
- Sparse-group missing-dependency behavior was not dynamically verified because
  `sparsegl` is installed in the audit environment.

## Not audited

- Full performance benchmarks were not run; Phase 4 findings are static
  evidence and qualitative estimates.
- No CRAN-like clean library matrix was created.
- No external Python parity reruns were performed.
- Heavy vignettes and SLURM workflows were not executed beyond the requested
  `devtools::check()` and pkgdown diagnostics.

## Gate

Audit complete. Safety net is in place. devtools::test() and
devtools::check() status: test PASS with WARN 2 and SKIP 3; check NOT PASS due
the baseline `costablr-python-parity.Rmd` vignette-build failure. Awaiting
approval to proceed with fixes - please specify which findings (by ID) to
address and in what order, and whether to attempt any Phase 5 Rcpp ports.

