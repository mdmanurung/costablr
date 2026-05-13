# 05 Native Candidates

Existing native toolchain:

- `DESCRIPTION` already declares `LinkingTo: Rcpp, RcppArmadillo`.
- `NAMESPACE` already has `useDynLib(costablr, .registration=TRUE)` and
  `importFrom(Rcpp, evalCpp)`.
- Registered native routine:
  `_costablr_mvr_solve_ungrouped_cpp` in `src/RcppExports.cpp`.
- No `src/Makevars` was observed.

## Candidate NAT-001: Stack-weight scoring loops

- Location: `R/multiomic_workflows.R:1257`, `R/multiomic_workflows.R:1335`,
  `R/multiomic_workflows.R:1404`, `R/multiomic_workflows.R:1421`
- Status: GOOD after pure-R optimization is attempted.
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
- Pure-R fallback: implement PERF-001/PERF-002 first.

## Candidate NAT-002: Correlation-group union step

- Location: `R/stabl_fit.R:584`, `R/stabl_fit.R:587`
- Status: GOOD only if profiling shows the pure-R vectorized edge extraction
  remains hot.
- Why it qualifies: the union-find threshold scan is self-contained and
  quadratic in feature count.
- Proposed target: Rcpp with integer vectors for edge endpoints and parent
  array; do not port `stats::cor()`.
- Expected win: ESTIMATE constant-factor.
- FFI boundary design: pass integer edge arrays or a logical/numeric adjacency
  representation; return integer group IDs. No RNG.
- DESCRIPTION/NAMESPACE impact: no new dependencies.
- CRAN/packaging risk: low.
- Pure-R fallback: `which(..., arr.ind = TRUE)` plus R union-find over only
  above-threshold edges.

## Candidate NAT-003: MVR solver rank-update improvement

- Location: `src/mvr_knockoff.cpp:119`, `src/mvr_knockoff.cpp:148`,
  `src/mvr_knockoff.cpp:162`, `R/mvr_knockoff.R:89`
- Status: CONDITIONAL GOOD, high risk.
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
- Status: BAD.
- Reason: model fitting already delegates to optimized native package code.
  Reimplementing glmnet/sparsegl behavior is out of scope and high risk.
- Pure-R fallback: improve coefficient extraction batching only.

## Candidate NAT-005: Bootstrap samplers

- Location: `R/bootstrap_helpers.R:423`, `R/bootstrap_helpers.R:507`
- Status: BAD for first pass.
- Reason: exact R `sample()`/`sample.int()` behavior, group leakage
  invariants, and reproducibility are more important than native speed here.
- Pure-R fallback: precompute group index maps as in PERF-005.

## Candidate NAT-006: FDP+ and similarity metrics

- Location: `R/fdp_control.R:49`, `R/fdp_control.R:60`, `R/metrics.R:67`,
  `R/metrics.R:75`
- Status: BAD for first pass.
- Reason: simpler base-R algorithms can remove the main overhead without
  native maintenance.
- Pure-R fallback: sorted threshold counts for FDP+ and incidence matrices for
  feature-set metrics.

