# 05 Native Candidates

Status reviewed: 2026-05-13. NAT-002 is FIXED by the profiling-gated
correlation-union native helper. NAT-001 and NAT-003 remain DEFERRED / NOT
FIXED and are represented by intentional skipped parity placeholders in
`tests/testthat/test-audit-native-candidates.R`. NAT-004 through NAT-006 are
NOT PLANNED for first-pass native implementation because the audit classified
them as bad native candidates.

Existing native toolchain:

- `DESCRIPTION` already declares `LinkingTo: Rcpp, RcppArmadillo`.
- `NAMESPACE` already has `useDynLib(costablr, .registration=TRUE)` and
  `importFrom(Rcpp, evalCpp)`.
- Registered native routines:
  `_costablr_corr_groups_from_corr_cpp` in `src/RcppExports.cpp`
  (implementation in `src/corr_groups.cpp`, ~55 lines, header-only Rcpp).
  `_costablr_mvr_solve_ungrouped_cpp` in `src/RcppExports.cpp`
  (implementation in `src/mvr_knockoff.cpp`, RcppArmadillo).
- No `src/Makevars` was observed.
- POST-AUDIT NOTE 2026-05-13: the NAT-002 native helper is a small union-find
  with `std::vector<int>` parent pointers and `std::map<int,int>` for root →
  group-id renumbering. It does not link RcppArmadillo (good — keeps build
  surface area minimal). The pure-R fallback in `R/stabl_fit.R` is still
  callable when the registered routine cannot be reached.

## Candidate NAT-001: Stack-weight scoring loops

- Location: `R/multiomic_workflows.R:1257`, `R/multiomic_workflows.R:1335`,
  `R/multiomic_workflows.R:1404`, `R/multiomic_workflows.R:1421`
- Status: DEFERRED / NOT NEEDED after the 2026-05-13 profiling gate. Pure-R
  PERF-001/PERF-002 changes cleared the strict runtime-or-allocation gate, so
  no stack-weight native port was attempted.
- Why it qualifies: late fusion can run thousands of random weight draws over
  dense prediction matrices/arrays. The current implementation is
  interpreter-bound arithmetic and missingness checks.
- Proposed target: Rcpp for binary/regression scoring; RcppArmadillo is
  optional for multiclass array-style arithmetic.
- Expected win: ESTIMATE constant-factor.
- FFI boundary design: pass `NumericMatrix` for predictions, `NumericVector`
  for outcomes, and return best score/weights/predictions. Preserve R RNG
  stream with `Rcpp::RNGScope` and match `stats::runif()` draw order if parity
  requires native RNG. For AUC, duplicate current tie handling exactly.
- DESCRIPTION/NAMESPACE impact: no new dependencies.
- CRAN/packaging risk: low to medium; RNG and floating-point reduction order
  are the main risks.
- Pure-R fallback: implemented through PERF-001/PERF-002 and kept by profiling.

## Candidate NAT-002: Correlation-group union step

- Location: `R/stabl_fit.R:584`, `R/stabl_fit.R:587`
- Status: FIXED 2026-05-13. The pure-R union refactor did not clear the
  strict 10% profiling gate, so a small Rcpp helper now performs only the
  thresholded union step over the already-computed correlation matrix.
- Why it qualifies: the union-find threshold scan is self-contained and
  quadratic in feature count.
- Proposed target: Rcpp parent-array union over the numeric correlation
  matrix; do not port `stats::cor()`.
- Expected win: ESTIMATE constant-factor.
- FFI boundary design: pass the numeric correlation matrix and cutoff; return
  integer group IDs. No RNG.
- DESCRIPTION/NAMESPACE impact: no new dependencies.
- CRAN/packaging risk: low.
- Pure-R fallback: column-wise threshold scan plus R union-find.
- Validation: `tests/testthat/test-audit-native-candidates.R` now asserts
  R-vs-C++ partition parity for NAT-002; `scripts/profile_audit_performance.R`
  kept the helper (`0.444s -> 0.017s`, 96.17% median runtime improvement;
  `0.027MB -> 0.004MB`, 85.79% allocation improvement).

## Candidate NAT-003: MVR solver rank-update improvement

- Location: `src/mvr_knockoff.cpp:119`, `src/mvr_knockoff.cpp:148`,
  `src/mvr_knockoff.cpp:162`, `R/mvr_knockoff.R:89`
- Status: DEFERRED / NOT FIXED. Conditional good candidate, high risk.
- Why it qualifies: the MVR S-matrix solver is already native and recomputes
  Cholesky factorizations inside coordinate updates.
- Proposed target: continue RcppArmadillo, but replace repeated full Cholesky
  with a numerically stable rank-one update/downdate strategy if profiling
  justifies it.
- Expected win: ESTIMATE constant-factor to asymptotic improvement within the
  solver loop.
- FFI boundary design: keep current `arma::mat` inputs/outputs. Preserve
  current error propagation via `Rcpp::stop`. No RNG except update-order
  sampling when no order is supplied; current C++ calls R `sample.int()`.
- DESCRIPTION/NAMESPACE impact: none.
- CRAN/packaging risk: high due numerical stability, platform BLAS/LAPACK
  differences, and PSD feasibility.
- Pure-R fallback: keep current `.solve_mvr_ungrouped_r()` as a reference.

## Candidate NAT-004: glmnet/sparsegl fitting and coefficient traversal

- Location: `R/learner_adapters.R:454`, `R/learner_adapters.R:465`,
  `R/learner_adapters.R:490`, `R/learner_adapters.R:498`,
  `R/learner_adapters.R:552`, `R/learner_adapters.R:562`
- Status: NOT PLANNED. BAD native candidate.
- Reason: model fitting already delegates to optimized native package code.
  Reimplementing glmnet/sparsegl behavior is out of scope and high risk.
- Pure-R fallback: improve coefficient extraction batching only.

## Candidate NAT-005: Bootstrap samplers

- Location: `R/bootstrap_helpers.R:423`, `R/bootstrap_helpers.R:507`
- Status: NOT PLANNED for first pass. BAD native candidate.
- Reason: exact R `sample()`/`sample.int()` behavior, group leakage
  invariants, and reproducibility are more important than native speed here.
- Pure-R fallback: precompute group index maps as in PERF-005.

## Candidate NAT-006: FDP+ and similarity metrics

- Location: `R/fdp_control.R:49`, `R/fdp_control.R:60`, `R/metrics.R:67`,
  `R/metrics.R:75`
- Status: NOT PLANNED for first pass. BAD native candidate.
- Reason: simpler base-R algorithms can remove the main overhead without
  native maintenance.
- Pure-R fallback: sorted threshold counts for FDP+ and incidence matrices for
  feature-set metrics.
