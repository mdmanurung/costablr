# 04 Performance Findings

Status reviewed: 2026-05-13. PERF-001, PERF-002, PERF-003, PERF-005,
and PERF-006 are FIXED by the profiling-gated optimization pass. PERF-004,
PERF-007, and PERF-008 remain DEFERRED low-severity optimization
opportunities. Validation used `scripts/profile_audit_performance.R` with
old-reference parity helpers and a strict 10% runtime-or-allocation gate.

## Finding PERF-001: Binary/regression stacking reallocates loop invariants

- Status: FIXED 2026-05-13. The loop now precomputes missingness and
  zero-filled prediction matrices and evaluates random weights in deterministic
  chunks.
- Severity: MEDIUM
- Locations: `R/multiomic_workflows.R:1257`, `R/multiomic_workflows.R:1258`,
  `R/multiomic_workflows.R:1261`, `R/multiomic_workflows.R:1262`,
  `R/multiomic_workflows.R:1166`
- Observation: each `n_iter` random-search iteration rebuilds weight matrices,
  recomputes missingness, calls `ifelse()`, and for binary tasks reranks scores
  through `.r_auc()`.
- Risk: constant-factor cost grows quickly for many samples and high
  `n_iter_lf`.
- Expected win: constant-factor.
- Implementation risk: LOW for regression, MEDIUM for binary due AUC tie
  behavior.
- Pure-R suggestion: precompute `is_obs` and zero-filled predictions outside
  the loop; evaluate random weights in chunks with matrix operations.
- Native needed: optional NAT-001 only after pure-R batching is profiled.
- Validation: old/new parity passed at tolerance `1e-12`; profiling gate kept
  the implementation (`0.476s -> 0.227s`, 52.31% median runtime improvement;
  `541.27MB -> 142.85MB`, 73.61% allocation improvement).

## Finding PERF-002: Multiclass stacking loops samples and rescans rows per draw

- Status: FIXED 2026-05-13. Multiclass stacking now precomputes observed
  omic masks and uses vectorized per-omic accumulation plus row-sum log-loss
  checks.
- Severity: MEDIUM
- Locations: `R/multiomic_workflows.R:1335`, `R/multiomic_workflows.R:1404`,
  `R/multiomic_workflows.R:1408`, `R/multiomic_workflows.R:1421`
- Observation: each random draw calls `.weighted_multiclass_probabilities()`,
  which loops over samples and uses `apply()` per row, then
  `.multiclass_log_loss()` scans rows again.
- Risk: constant-factor overhead in multiclass late fusion.
- Expected win: constant-factor.
- Implementation risk: MEDIUM due missing-probability handling and probability
  renormalization.
- Pure-R suggestion: precompute observed omic masks and combine weighting plus
  loss in one pass per random weight draw.
- Native needed: optional NAT-001 only after pure-R simplification.
- Validation: old/new parity passed at tolerance `1e-12`; profiling gate kept
  the implementation by runtime (`6.179s -> 0.204s`, 96.70% median runtime
  improvement). Allocation increased in this target case, so the keep decision
  is runtime-based.

## Finding PERF-003: Coefficients are extracted one lambda at a time

- Status: FIXED 2026-05-13. Batch adapters now try vector `s = lambda_seq`
  coefficient extraction first, with guarded fallback to the old per-lambda
  path when a family/backend shape is unsupported.
- Severity: MEDIUM
- Locations: `R/learner_adapters.R:421`, `R/learner_adapters.R:427`,
  `R/learner_adapters.R:430`, `R/learner_adapters.R:432`
- Observation: batch adapters fit one full path but still call coefficient
  extraction once per lambda.
- Risk: avoidable R dispatch overhead, especially across many bootstraps and
  lambda grids.
- Expected win: constant-factor.
- Implementation risk: MEDIUM because `glmnet`/`sparsegl` coefficient return
  shapes vary for Cox and multinomial.
- Pure-R suggestion: attempt vector `s = lambda_seq` extraction once, with
  explicit handling and tests for each supported family.
- Native needed: no.
- Validation: old/new parity passed at tolerance `1e-12` for glmnet gaussian,
  binomial, multinomial, Cox, and sparsegl when installed; profiling gate kept
  the gaussian extraction path (`0.082s -> 0.004s`, 95.12% median runtime
  improvement; `1.73MB -> 0.42MB`, 75.43% allocation improvement).

## Finding PERF-004: Sparse-group ordering is recomputed inside alpha batches

- Status: DEFERRED / NOT FIXED. Sparse-group ordering/slicing is still built
  inside each alpha batch.
- Severity: LOW
- Locations: `R/learner_adapters.R:540`, `R/learner_adapters.R:544`
- Observation: `.make_sgl_batch_adapter()` computes feature ordering and
  slices `x` inside every alpha batch.
- Risk: repeated work for elastic-net style sparse-group grids.
- Expected win: constant-factor.
- Implementation risk: LOW.
- Pure-R suggestion: precompute `sort_ord`, `inv_ord`, and `grp_s` in the
  closure and slice `x_s` once per bootstrap call.
- Native needed: no.

## Finding PERF-005: Grouped bootstrap repeatedly scans groups and grows vectors

- Status: FIXED 2026-05-13. `stabl_fit()` now builds a grouped-bootstrap
  sampler closure once, with precomputed group index and group-stratum maps.
  The exported one-shot sampler uses the same closure.
- Severity: MEDIUM
- Locations: `R/bootstrap_helpers.R:210`, `R/bootstrap_helpers.R:444`,
  `R/bootstrap_helpers.R:455`, `R/bootstrap_helpers.R:478`,
  `R/bootstrap_helpers.R:507`, `R/stabl_fit.R:341`
- Observation: grouped bootstrap uses repeated `which(groups == g)` and grows
  sampled index vectors with `c()`/`unique()` inside loops.
- Risk: overhead when many bootstraps operate over repeated-measures data.
- Expected win: constant-factor.
- Implementation risk: MEDIUM because replacement and whole-group semantics
  must remain exact.
- Pure-R suggestion: precompute `idx_by_group <- split(seq_along(groups),
  groups)` and group-to-stratum maps in the sampler closure.
- Native needed: no first pass.
- Validation: fixed-seed old/new sampled indices are identical across
  replacement and stratified cases; profiling gate kept the sampler
  (`0.5695s -> 0.3365s`, 40.91% median runtime improvement;
  `346.72MB -> 188.78MB`, 45.55% allocation improvement).

## Finding PERF-006: Correlation grouping scans all pairs in R

- Status: FIXED 2026-05-13. The correlation calculation remains in
  `stats::cor()`, but the thresholded union step now uses the registered
  `corr_groups_from_corr_cpp()` native helper with a pure-R fallback.
- Severity: MEDIUM
- Locations: `R/stabl_fit.R:561`, `R/stabl_fit.R:584`,
  `R/stabl_fit.R:587`, `R/stabl_fit.R:601`, `R/stabl_fit.R:608`
- Observation: after native `stats::cor()`, `.build_corr_groups()` scans
  every upper-triangle pair in nested R loops and `.append_noise_groups()`
  grows vectors.
- Risk: quadratic R-loop overhead for high-dimensional sparse-group lasso.
- Expected win: constant-factor, potentially large when the threshold removes
  most edges.
- Implementation risk: LOW to MEDIUM.
- Pure-R suggestion: use `which(corr > cutoff & upper.tri(corr), arr.ind=TRUE)`
  and preallocate appended groups.
- Native needed: NAT-002 was implemented after the pure-R union refactor failed
  the strict 10% gate.
- Validation: old/new partition parity passed; profiling gate kept the native
  union helper (`0.444s -> 0.017s`, 96.17% median runtime improvement;
  `0.027MB -> 0.004MB`, 85.79% allocation improvement).

## Finding PERF-007: Similarity matrices repeat set operations in nested loops

- Status: DEFERRED / NOT FIXED. Pairwise metric helpers have not been replaced
  with incidence-matrix implementations.
- Severity: LOW
- Locations: `R/metrics.R:64`, `R/metrics.R:79`, `R/metrics.R:146`,
  `R/metrics.R:166`, `R/metrics.R:257`, `R/metrics.R:275`
- Observation: pairwise metric helpers repeatedly call set operations for each
  pair.
- Risk: slow benchmarking summaries when many folds/repeats are compared.
- Expected win: constant-factor.
- Implementation risk: MEDIUM around duplicate inputs, empty sets, and
  universe-size validation.
- Pure-R suggestion: build a logical incidence matrix once, then use
  `tcrossprod()` to compute intersections.
- Native needed: no.

## Finding PERF-008: FDP+ threshold counts allocate dense logical `outer()` matrices

- Status: DEFERRED / NOT FIXED. FDP+ still uses the dense threshold-counting
  approach pending a separate optimization pass.
- Severity: LOW
- Locations: `R/fdp_control.R:49`, `R/fdp_control.R:60`
- Observation: `compute_fdp_plus()` builds `features x thresholds` logical
  matrices for real and artificial scores, plus per-lambda repeats.
- Risk: memory overhead for very wide feature matrices and dense threshold
  grids.
- Expected win: constant-factor memory/time.
- Implementation risk: LOW, but strict `>` thresholding must be preserved.
- Pure-R suggestion: sort score vectors and count scores greater than each
  threshold with interval/search logic.
- Native needed: no first pass.
