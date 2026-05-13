# 03 Intent-vs-Implementation Findings

> **Re-review note (2026-05-13 evening).** A new pkgdown drift mirroring
> IMPL-007 has appeared since the audit closed: `stabl_refit()` is exported
> in `NAMESPACE` and documented at `man/stabl_refit.Rd`, but is absent from
> `_pkgdown.yml` reference sections. See IMPL-007 below for the existing
> pattern and the post-audit drift candidates at the bottom of this file.

## Finding IMPL-001: `get_support()` does not validate documented threshold shape

- Status: FIXED 2026-05-13. `new_hard_threshold` now resolves to a single
  non-missing numeric value in `(0, 1]`; guarded by
  `tests/testthat/test-audit-stabl-accessors.R`.
- Severity: MEDIUM
- Locations: `R/stabl_accessors.R:27`, `R/stabl_accessors.R:44`,
  `R/stabl_accessors.R:60`, `man/get_support.Rd:12`
- Observation: docs state `new_hard_threshold` is numeric in `(0, 1]` or
  `NULL`. The method resolves the threshold and directly evaluates
  `max_scores > threshold` without scalar, finite, range, or `NA` validation.
- Dynamic verification: `new_hard_threshold = NA_real_` returned an all-`NA`
  support mask; `new_hard_threshold = c(0.3, 0.7)` returned a recycled
  comparison.
- Risk: downstream code receives non-logical/partly missing support masks or
  silently recycled thresholds.
- Confidence: HIGH.
- Suggested fix: validate `new_hard_threshold` as a single non-missing numeric
  in `(0, 1]`.

## Finding IMPL-002: Small artificial proportions can produce zero artificial features

- Status: FIXED 2026-05-13. Artificial-feature settings that round to
  `n_injected = 0` now fail early with a parameter error; guarded by
  `tests/testthat/test-audit-stabl-fit.R`.
- Severity: HIGH
- Locations: `STABL.md:42`, `STABL.md:53`, `R/stabl_fit.R:268`,
  `R/stabl_fit.R:366`, `R/stabl_fit.R:369`, `R/stabl_fit.R:407`
- Observation: `artificial_proportion` is allowed in `(0, 1]`, and R uses
  `round(p * artificial_proportion)`. For small `p`, this can be zero.
  `stabl_fit()` still constructs `art_rows` with
  `seq(n_features + 1L, n_features + n_injected)`, which is a descending
  two-element sequence when `n_injected = 0`.
- Dynamic verification: `p = 2`, `artificial_proportion = 0.1` errored during
  accumulation with `subscript out of bounds`.
- Risk: valid documented parameters fail late with an internal indexing error.
- Confidence: HIGH.
- Suggested fix: either require `n_injected >= 1L` when artificial features are
  enabled, or handle zero artificial features explicitly with `seq_len(0L)` and
  a clear threshold-control policy.

## Finding IMPL-003: Positive `sample_fraction` can floor to zero subsamples

- Status: FIXED 2026-05-13. `sample_fraction` values that imply
  `n_subsamples = 0` now fail early before bootstrap sampling; guarded by
  `tests/testthat/test-audit-stabl-fit.R`.
- Severity: MEDIUM
- Locations: `STABL.md:27`, `R/stabl_fit.R:326`,
  `R/stabl_fit.R:473`, `R/bootstrap_helpers.R:27`,
  `R/bootstrap_helpers.R:110`
- Observation: validation only requires `sample_fraction > 0`. The STABL
  contract uses `floor(sample_fraction * n)`, so small positive fractions can
  produce `n_subsamples = 0` even though bootstrap docs call for a positive
  integer.
- Dynamic verification: binomial `stabl_fit()` with `sample_fraction = 0.01`
  and `n = 10` failed after 1000 class-diversity retry attempts instead of
  failing early on zero subsamples.
- Risk: users receive a misleading bootstrap-diversity error rather than a
  parameter validation error.
- Confidence: HIGH.
- Suggested fix: after computing `n_subsamples`, reject values below one, and
  for stratified classification reject values that cannot satisfy realised
  strata before entering retries.

## Finding IMPL-004: Direct `make_modelx_knockoff_features(random_state=...)` ignores its seed argument

- Status: FIXED 2026-05-13. Direct helper calls now honor `random_state` with
  scoped RNG restoration; guarded by
  `tests/testthat/test-audit-artificial-features.R`.
- Severity: LOW
- Locations: `R/artificial_features.R:79`, `R/artificial_features.R:84`,
  `R/artificial_features.R:93`, `R/artificial_features.R:210`,
  `man/make_modelx_knockoff_features.Rd:14`
- Observation: the internal helper documents `random_state` but intentionally
  does not seed; the dispatcher seeds at `make_artificial_features()`.
- Dynamic verification: two direct calls to `make_modelx_knockoff_features()`
  with the same `random_state = 123L` but different global seeds produced
  different augmented matrices and different `noise_col_indices`.
- Risk: generated man page suggests direct reproducibility that does not hold.
- Confidence: HIGH.
- Suggested fix: either remove the helper's `random_state` argument/docs or
  implement scoped seeding inside direct helper calls without double-seeding the
  dispatcher path.

## Finding IMPL-005: Documentation treats internal artificial helpers as public API

- Status: FIXED 2026-05-13. Public-facing API/pkgdown indexes no longer list
  the internal artificial helpers as exported API.
- Severity: LOW
- Locations: `docs/API_REFERENCE.md:27`, `docs/API_REFERENCE.md:28`,
  `_pkgdown.yml:59`, `_pkgdown.yml:60`, `NAMESPACE:33`
- Observation: `NAMESPACE` exports `make_artificial_features()` but not
  `make_rp_features()` or `make_modelx_knockoff_features()`. The API reference
  and pkgdown reference section list the internal helpers as if they were
  public.
- Risk: users can see reference topics for helpers they cannot call with
  `costablr::`.
- Confidence: HIGH.
- Suggested fix: either export and support the helpers intentionally, or remove
  them from the public API docs/pkgdown reference.

## Finding IMPL-006: Python-parity docs have stale threshold and artificial-type text

- Status: FIXED 2026-05-13 for the canonical source/generated parity docs
  listed below. Ignored historical HTML build artifacts may still contain stale
  rendered text until regenerated.
- Severity: LOW
- Locations: `STABL.md:58`, `R/artificial_features.R:218`,
  `vignettes/costablr-python-parity.Rmd:39`,
  `vignettes/costablr-python-parity.Rmd:207`,
  `vignettes/costablr-python-parity.knit.md:49`,
  `docs/PYTHON_TO_R_MAPPING.md:33`
- Observation: source semantics support `"modelx_knockoff"` and
  `"mvr_knockoff"` and reject old `"knockoff"`. Some docs/generated artifacts
  still mention `"knockoff"` or show `seq(0, 1, by = 0.01)` even though
  `STABL.md` and `stabl_fit()` default to `seq(0, 0.99, by = 0.01)`.
- Risk: users following generated docs can pass a rejected artificial type or
  believe the R default includes threshold `1`.
- Confidence: HIGH for stale text. The `devtools::check()` failure involving
  stale `stablr::stabl_fit()` is related but its exact cause is UNCERTAIN.
- Suggested fix: refresh source docs and regenerate generated vignette outputs
  after the option rename and threshold default change.

## Finding IMPL-007: pkgdown article index omits an existing vignette

- Status: FIXED 2026-05-13. `_pkgdown.yml` now indexes
  `costablr-tcga-nestedcv`, and `pkgdown::check_pkgdown()` reports no
  problems in the post-remediation record.
- Severity: LOW
- Locations: `_pkgdown.yml:113`, `_pkgdown.yml:116`,
  `vignettes/costablr-tcga-nestedcv.Rmd:1`
- Observation: `_pkgdown.yml` indexes five workflow articles. The source tree
  also contains `costablr-tcga-nestedcv.Rmd`.
- Dynamic verification: `pkgdown::check_pkgdown()` failed with
  `1 vignette missing from index: "costablr-tcga-nestedcv"`.
- Risk: pkgdown metadata checks fail until the article is either indexed or
  intentionally excluded using pkgdown-supported configuration.
- Confidence: HIGH.
- Suggested fix: add the nested-CV article to `_pkgdown.yml`, or document and
  configure its exclusion if it is intentionally off-site.

## Post-audit intent drift (NOT YET FILED AS NUMBERED FINDINGS)

Candidates identified during the 2026-05-13 evening re-review.

### IMPL-CAND-A: `stabl_refit()` is exported but not indexed in `_pkgdown.yml`

- Severity: LOW (recurrence of IMPL-007).
- Locations: `NAMESPACE` (`export(stabl_refit)`), `man/stabl_refit.Rd:1`,
  `_pkgdown.yml:40-110` (no reference entry).
- Observation: `stabl_refit()` is a new top-level public API added by commit
  `5c11faa`. It is documented and tested, but `_pkgdown.yml` does not list
  it under any reference section. `pkgdown::check_pkgdown()` was clean at
  audit closure; running it now would either succeed (because pkgdown is
  permissive about exported topics missing from the reference list) or
  reproduce the IMPL-007 missing-topic warning, depending on configuration.
- Risk: built site lacks the new function's reference page even though the
  function is exported.
- Confidence: HIGH from inspection. Not dynamically verified against
  `pkgdown::check_pkgdown()` post-`5c11faa`.
- Suggested fix: add `stabl_refit` to the `Core STABL Engine` section of
  `_pkgdown.yml` (its `STABL.md`/`README.md` framing treats it as the
  end-to-end equivalent of `stabl_fit`).

### IMPL-CAND-B: `stabl_refit()` documented `(0, 1]` threshold not validated end-to-end

- Severity: LOW.
- Locations: `R/stabl_refit.R:33-35` (docs), `R/stabl_refit.R:100-104`
  (delegation).
- Observation: `stabl_refit()` forwards `new_hard_threshold` to
  `get_feature_names_out()`, which uses `get_support()`, which now has the
  IMPL-001 scalar-finite-range guard. The IMPL-001 fix therefore *does*
  cover this entry point. However, `stabl_refit()`'s own docstring re-states
  the `(0, 1]` contract without referencing the upstream validator. If the
  upstream validation ever loosens, this docstring becomes a silent
  contract drift.
- Risk: contract drift in the future, not a current defect.
- Confidence: HIGH from inspection.

### IMPL-CAND-C: `stabl_refit()` binomial path silently calls `droplevels()`

- Severity: LOW.
- Location: `R/stabl_refit.R:227`.
- Observation: binomial dispatch calls `droplevels(factor(y_train))` before
  asserting `length(levels(...)) == 2L`. When `y_train` is already a
  two-level factor with one level having zero rows after alignment, the
  caller sees the "exactly two outcome classes" error rather than a more
  diagnostic "outcome lost a class during alignment" message. The audit's
  INT-001 duplicate-ID rejection reduces this risk but does not eliminate
  it (e.g. validation-only outcomes restricted by `train_ids`).
- Risk: confusing error in alignment-failure scenarios.
- Confidence: HIGH from inspection; no dynamic check.
