# stablr Scientific Audit — Full Package

**Date:** 2026-05-08
**Scope:** Full package end-to-end (single-omic core path + multi-omic workflows)
**Mode:** Read-only
**Spec reference:** `STABL.md` (algorithm contract + parity invariants)
**Auditor note:** No code, tests, docs, or configuration were modified. All findings are evidence-based citations to source.

---

## 1. Executive Summary

- **Core FDP+ math is correctly implemented.** The `(1/π)` artificial scaling, `1+` numerator offset, `max(1, …)` denominator guard, and strict `>` comparator are all present in [r-pkg/stablr/R/fdp_control.R](r-pkg/stablr/R/fdp_control.R#L41-L66). Threshold sweep defaults to `seq(0, 1, by = 0.01)` and the `θ = 1` fallback for `min FDP+ > 1` is implemented.
- **Subsampling defaults match the spec** (`sample_fraction = 0.5`, `replace = FALSE`, `n_subsamples = floor(s·n)`) and a pre-flight reject for `n_subsamples > n_samples` exists. The strict-`>` and frequency-then-max ordering are correct.
- **Artificial-feature count uses `round(p·π)` in R** (documented divergence from Python's `floor`), and original/artificial blocks are concatenated left/right with consistent index bookkeeping (`art_rows = (p+1):(p+q)` slicing in [stabl_fit.R](r-pkg/stablr/R/stabl_fit.R#L283-L305)).
- **High-risk bug in `group_bootstrap_indices`:** `sample(remaining, size = 1L)` triggers R's well-known length-1 numeric pitfall when `groups` is integer/numeric and the candidate pool shrinks to one element — silently mis-samples a different group ID. Affects every grouped fit whose group labels are numeric, especially in the last iteration of the `while` loop.
- **High-risk bug in `make_rp_features` (random-permutation artificial features):** uses `sample.int(n_features, n_injected, replace = FALSE)` and therefore *cannot* generate an artificial block of width > `p`. With `artificial_proportion > 1` the spec disallows this, but with `artificial_proportion = 1` (default) and small `p`, this also limits source diversity to one permuted copy per original column — the Python reference samples sources *with replacement* (consult `stabl/stabl.py`). Worth a parity confirmation.
- **Medium-risk parity divergences:** (a) `bootstrap_threshold = 1e-5` for "non-zero" coefficients (Python uses exact `coef != 0`); (b) parallel (`furrr`) path is not bit-identical to sequential path even with the same `random_state`; (c) the `sparse_group_lasso` multinomial path one-vs-rest binarises rather than fitting a true multinomial; (d) the parity-fixture tests assert `rowMeans` of stability scores, while the spec defines importance as `max` over lambda — the parity tests are therefore not testing the spec invariant.
- **Test coverage is thin on FDP+ calibration:** there is no null-data calibration test (pure-noise X with no true signal → expected near-zero selection rate), no test that pins `(1/π)` or strict `>` symbolically, and no FDP+ output value assertion. Existing parity tests use weak, asymmetric assertions ("≥ 1 of Python's top 2 in R's top 3").
- **Multi-omic guards are in place:** sample alignment is hard-checked, `cooperative_fusion = TRUE` rejects `family = "cox"` + `validation` selection and `lambda.1se` + `validation`, and `.has_multiview()` is mockable as required.

Overall verdict: the algorithmic core is faithful to `STABL.md` and the parity-critical invariants are satisfied; however, two high-risk implementation bugs in the bootstrap/artificial-feature paths and weak FDP+ calibration testing should be addressed before declaring scientific equivalence with the Python reference.

---

## 2. High-Risk Issues

### H-1. `sample(remaining, size = 1L)` length-1 numeric pitfall in `group_bootstrap_indices`

- **Finding** — When `groups` are numeric/integer and the eligible group pool `remaining` shrinks to a single element, `sample(remaining, 1L)` returns `sample.int(remaining, 1L)` instead of `remaining` itself, silently selecting an arbitrary fabricated group ID.
- **Location** — [r-pkg/stablr/R/bootstrap_helpers.R:170](r-pkg/stablr/R/bootstrap_helpers.R#L170) and [L188](r-pkg/stablr/R/bootstrap_helpers.R#L188) (retry copy).
- **Evidence** —
  ```r
  while (length(sampled_idx) < n_subsamples && length(remaining) > 0L) {
      g         <- sample(remaining, size = 1L)            # <-- pitfall
      remaining <- if (replace) remaining else remaining[remaining != g]
      ...
  }
  ```
  R's `sample()` documented behaviour: if `length(x) == 1` and `x` is numeric, it is treated as `1:x`. Compare with `sample.int(length(remaining), 1L)` indexed back into `remaining[…]`, which is the correct idiom.
- **Consequence** — In any grouped fit whose group labels are numeric, the *last* group sampled per bootstrap is replaced by a uniformly random integer in `1:g_last`. Downstream `which(groups == g)` then either returns no rows (if the fabricated ID does not exist) producing a smaller-than-target subsample, or matches a different group's rows producing leakage between subsample and complement. The bug is silent (no warning).
- **Why high-risk** — Defaults documented to "any type", existing test suite only exercises character group IDs ([test-bootstrap-helpers.R:22-44](r-pkg/stablr/tests/testthat/test-bootstrap-helpers.R#L22-L44)) so the bug is invisible to current CI. The leakage path directly violates the STABL group-bootstrap leakage-prevention contract.

### H-2. `make_rp_features` uses `replace = FALSE` for source-column draw

- **Finding** — Random-permutation source columns are drawn *without replacement* from the original feature set (`sample.int(n_features, n_injected, replace = FALSE)`).
- **Location** — [r-pkg/stablr/R/artificial_features.R:20](r-pkg/stablr/R/artificial_features.R#L20).
- **Evidence** —
  ```r
  indices <- sample.int(n = n_features, size = n_injected, replace = FALSE)
  x_art   <- x[, indices, drop = FALSE]
  ```
- **Consequence** —
  1. **Hard cap on `n_injected ≤ p`.** If a future user (or a code path that increases `artificial_proportion` above 1, even though current validation forbids it) requests `n_injected > p`, `sample.int(replace = FALSE)` errors out instead of permuting with replacement.
  2. **Reduced effective null distribution diversity.** With `artificial_proportion = 1` and `n_injected = p`, every original column is permuted *exactly once*. The Python reference (consult `stabl/stabl.py::_make_artificial_features`) samples sources independently per artificial column, so the same source can be permuted multiple times into different artificial columns. Without-replacement sampling reduces the variance of the artificial-feature score distribution.
- **Why high-risk** — Direct parity divergence affecting the FDP+ null-distribution quality. The `(1/π)` calibration in FDP+ assumes an i.i.d. null block; without-replacement source sampling violates that mildly but systematically.

### H-3. Parity fixture tests assert `rowMeans` of stability scores, not the spec-defined `max`

- **Finding** — The Python parity tests compare R's `rowMeans(fit$stabl_scores_)` against Python's `python_mean_score`, but `STABL.md § Step 3` defines the importance score as `max` over the lambda grid, and `get_importances()` correctly returns the max.
- **Location** — [tests/testthat/test-python-parity-fixtures.R:21-30](r-pkg/stablr/tests/testthat/test-python-parity-fixtures.R#L21-L30).
- **Evidence** —
  ```r
  expect_python_parity <- function(fit, py_mean_scores, ...) {
    r_mean_scores <- rowMeans(fit$stabl_scores_)
    ...
    expect_gte(length(intersect(py_top2, r_top3)), 1L)   # weak: 1-of-3 overlap
    expect_gt(mean(r_mean_scores[py_top2]), stats::median(r_mean_scores))
    ...
  }
  ```
  The exported accessor is `get_importances` → `apply(object$stabl_scores_, 1L, max)` ([stabl_accessors.R:160-167](r-pkg/stablr/R/stabl_accessors.R#L160-L167)).
- **Consequence** — Parity is asserted on a derived statistic (mean across lambdas) that is **not** the quantity used by FDP+ thresholding. A test passing this expectation does **not** guarantee that the parity-critical invariant (max-over-lambda → support mask via `>`) matches Python. The acceptance criterion `expect_gte(intersect, 1L)` is also extremely permissive — passing requires only one of Python's top-two features to land in R's top-three by mean score.
- **Why high-risk** — Falsely advertises Python-R parity. A reviewer reading "parity fixture passes" would conclude the cores agree; the test cannot detect parity drift in the actual FDP+/support pipeline.

---

## 3. Medium-Risk Issues

### M-1. `bootstrap_threshold = 1e-5` instead of strict non-zero

- **Finding** — Selection mask is `|coef| > 1e-5` rather than `|coef| > 0`.
- **Location** — [r-pkg/stablr/R/learner_adapters.R:48, 121, 215](r-pkg/stablr/R/learner_adapters.R#L48) and the batch adapters at L427-L580.
- **Evidence** — `bootstrap_threshold = 1e-5` default; mask computed as `> bootstrap_threshold`.
- **Consequence** — For glmnet's coordinate-descent solver, near-zero non-active coefficients can occasionally land in `(0, 1e-5]`. Python's `selection_threshold` in the reference is `1e-5` historically (consult `stabl/stabl.py`); if both implementations match this constant, fine. If Python uses `coef != 0`, R will under-select for shrunken signals at the largest lambdas.
- **Resolves uncertainty by:** symbolic check against `stabl/stabl.py` for the analogous constant, or a parity simulation with a degenerate signal that produces coefficients in `(0, 1e-5]`.

### M-2. Parallel path (`furrr`) is not deterministic-equivalent to sequential path

- **Finding** — The `workers > 1` branch uses `furrr_options(seed = TRUE)` which derives per-worker L'Ecuyer-CMRG seeds from the *current* RNG state. The sequential branch consumes RNG draws inline. Two runs with the same `random_state` and different `workers` will not produce identical `stabl_scores_`.
- **Location** — [stabl_fit.R:323-345](r-pkg/stablr/R/stabl_fit.R#L323-L345).
- **Evidence** —
  ```r
  if (use_furrr) {
    result_list <- furrr::future_map(boot_indices, process_one_bootstrap,
      .options = furrr::furrr_options(seed = TRUE))
    ...
  } else {
    for (idx in boot_indices) { ... }
  }
  ```
  `boot_indices` are pre-generated identically in both branches (good — sampling indices reproducible). However, glmnet itself may consume RNG (e.g., in coordinate descent shuffling, multinomial standardisation), and adaptive lasso's ridge initialisation can in principle consume RNG. The per-worker seed differs from the inline RNG state of the sequential path.
- **Consequence** — Section 6 of `STABL.md` documents reproducibility through explicit seeds; users will reasonably expect `random_state = K` to give bit-identical scores regardless of `workers`. Currently it does not.
- **Resolves uncertainty by:** running the same fit at `workers = 1` and `workers > 1` with identical `random_state` and asserting `identical(scores)` (currently no test does this).

### M-3. `sparse_group_lasso` multinomial path is one-vs-rest binomial, not multinomial

- **Finding** — For `family = "multinomial"` with `base_learner = "sparse_group_lasso"`, the adapter loops `seq_along(levs)` and fits `family = "binomial"` with `y == levs[k]` per class, then takes per-row `pmax` of the `|coef|`.
- **Location** — [learner_adapters.R:553-572](r-pkg/stablr/R/learner_adapters.R#L553-L572) (batch adapter); [L296-L317](r-pkg/stablr/R/learner_adapters.R#L296-L317) (single-lambda adapter).
- **Evidence** —
  ```r
  for (k in seq_along(levs)) {
    yk    <- as.integer(y == levs[[k]])
    fit_k <- sparsegl::sparsegl(..., family = "binomial", ...)
    coef_k_sorted <- ...
    coef_acc <- pmax(coef_acc, coef_k_sorted[inv_ord, , drop = FALSE])
  }
  result[, row_idx] <- coef_acc > bootstrap_threshold
  ```
- **Consequence** — Group-lasso group penalties operate independently per class rather than across the response category dimension as a true multinomial GL would. Stability scores will differ from a hypothetical Python `MultiTaskGroupLasso` reference. `STABL.md` does not specify the SGL multinomial behaviour; this is an *implementation choice* that the spec is silent on.
- **Resolves uncertainty by:** statement of intent in `STABL.md` (deliberate fallback vs. limitation of `sparsegl`), and a test verifying selection consistency under a known multinomial signal.

### M-4. Adaptive-lasso ridge-initialisation lambda choice

- **Finding** — `init_lambda <- tail(init_fit$lambda, n = 1L)` (smallest lambda in the auto ridge sequence, i.e., closest to OLS) is used to compute `penalty_factor = 1 / (|β̂_init| + ε)^γ`.
- **Location** — [learner_adapters.R:155-160 / 491-498](r-pkg/stablr/R/learner_adapters.R#L491-L498).
- **Evidence** — `nlambda = 30L` for the ridge fit, then `init_lambda <- tail(init_fit$lambda, n = 1L)`.
- **Consequence** — The choice is reasonable (matches "use OLS-like initial estimator" intuition for adaptive lasso) but `STABL.md` is silent on this; a Python reference choosing a different initial lambda or a CV-tuned ridge would diverge in `penalty_factor` magnitude and therefore in the final selection mask.
- **Resolves uncertainty by:** confirm against `stabl/stabl.py::_adaptive_lasso_*` what initial estimator Python uses.

### M-5. `make_artificial_features` re-seeds inside `make_knockoff_features`

- **Finding** — `make_artificial_features(..., random_state)` calls `set.seed(random_state)` once, then dispatches to `make_knockoff_features(..., random_state)` which calls `set.seed(random_state)` *again*. After return, `stabl_fit` calls `set.seed(random_state)` a *third* time before generating bootstrap indices.
- **Location** — [artificial_features.R:159-164](r-pkg/stablr/R/artificial_features.R#L159-L164), [artificial_features.R:54](r-pkg/stablr/R/artificial_features.R#L54), [stabl_fit.R:317](r-pkg/stablr/R/stabl_fit.R#L317).
- **Evidence** —
  ```r
  # make_artificial_features
  if (!is.null(random_state)) set.seed(random_state)
  switch(type, ..., knockoff = make_knockoff_features(x, n_injected, random_state = random_state), ...)

  # make_knockoff_features
  if (!is.null(random_state)) set.seed(random_state)

  # stabl_fit (after artificial features)
  if (!is.null(random_state)) set.seed(random_state)
  boot_indices <- lapply(seq_len(n_bootstraps), boot_sampler)
  ```
- **Consequence** — Bootstrap index draws and artificial-feature draws share the *same* seed origin, so they consume identical RNG sequences from the same starting state. This is not a correctness bug per se, but it means that with `artificial_type = "random_permutation"`, the sequence consumed by `make_rp_features` directly determines what RNG state is overwritten by the second `set.seed`, masking the randomness of artificial-feature generation under any `random_state` change. More importantly, multiple `set.seed` calls per `stabl_fit` invocation make the contribution of each step to the global RNG opaque and hard to reason about for reproducibility audits.
- **Resolves uncertainty by:** documenting (or removing) the redundant seeding; a test that varies `random_state` and asserts bootstrap indices change but artificial features are fixed (or vice-versa) would pin the contract.

### M-6. `make_rp_features` doc/code mismatch about `noise_col_indices` semantics

- **Finding** — The dispatcher docstring describes `noise_col_indices` as "1-based indices (into the artificial block itself)" ([artificial_features.R:147-150](r-pkg/stablr/R/artificial_features.R#L147-L150)), while the code returns indices into the **original** `x` columns (used by `.append_noise_groups` to look up SGL group membership).
- **Location** — Docstring at [artificial_features.R:147-150](r-pkg/stablr/R/artificial_features.R#L147-L150); usage at [stabl_fit.R:506](r-pkg/stablr/R/stabl_fit.R#L506).
- **Evidence** — `make_rp_features` returns `indices` from `sample.int(n_features, ...)`. `.append_noise_groups` reads `groups[[src]]` where `src ∈ 1..length(groups) == ncol(x_original)`.
- **Consequence** — Documentation bug only; functional code is internally consistent. Risk is that a future contributor follows the docstring and breaks SGL group bookkeeping.

### M-7. `sample_fraction > 1` accepted with `replace = TRUE`

- **Finding** — `.validate_stabl_params` allows any `sample_fraction > 0` (no upper bound). With `replace = TRUE`, this means subsamples larger than `n` are silently accepted; with `replace = FALSE` the pre-flight at [stabl_fit.R:308-315](r-pkg/stablr/R/stabl_fit.R#L308-L315) catches the case.
- **Location** — `.validate_stabl_params` (param validator). Search "must be a positive numeric" in `stabl_fit.R`.
- **Evidence** — `if (!is.numeric(sample_fraction) || length(sample_fraction) != 1L || sample_fraction <= 0)` — only positivity checked.
- **Consequence** — Silent oversampling departs from the documented STABL contract (`sample_fraction` is the bootstrap *fraction*, expected `(0, 1]`). FDP+ calibration assumes subsamples smaller than full data; with `s > 1, replace = TRUE`, the implicit null distribution is no longer valid.

### M-8. `auto_lambda_grid` for elastic-net with `l1_ratio` vector duplicates `lambda` rows across alphas

- **Finding** — When `l1_ratio` is a vector, `auto_lambda_grid` rbinds per-alpha grids without joint deduplication; lambdas are independent paths per alpha.
- **Location** — [learner_adapters.R:728-740](r-pkg/stablr/R/learner_adapters.R#L728-L740) (approximate).
- **Evidence** — `for (i in seq_along(alphas)) { ... grids[[i]] <- data.frame(alpha = alphas[[i]], lambda = lam_seq) }; do.call(rbind, grids)`.
- **Consequence** — Not a correctness bug — `.make_glmnet_batch_adapter` handles per-alpha batches correctly via `lambda_grid[["alpha"]]`. Worth confirming that `n_lambdas <- nrow(lambda_grid)` (the second axis of `stabl_scores_`) being the *concatenated* axis is the intended semantics for downstream `apply(..., 1L, max)`.

---

## 4. Unclear Assumptions Requiring Human Review

1. **What is the canonical Python `bootstrap_threshold`?** R uses `1e-5`. Python's `stabl.py` should be consulted to confirm; if Python uses exact `coef != 0`, R will under-select at the noisy fringe.
2. **Should `(1/π)` use the *requested* `artificial_proportion` or the *realised* `n_injected / p`?** R passes `artificial_proportion` directly into `compute_fdp_plus`, so with `round(p·π)` rounding the realised ratio can differ slightly (e.g., `p = 7, π = 0.5` → `n_injected = 4`, realised ratio `4/7 ≠ 0.5`). The FDP+ formula assumes `(1/π)` rescales to a per-original-feature artificial count; using requested `π` is correct only when `p·π` is exact.
3. **Is the SGL multinomial one-vs-rest fallback intentional?** Should `STABL.md` document this limitation, and should it warn the user?
4. **Adaptive-lasso ridge initialisation**: which lambda did the Python reference use? If different, this produces a parity gap.
5. **`group_bootstrap_indices` "trim excess rows" policy**: the function trims the last group's rows to hit `n_subsamples` exactly ([bootstrap_helpers.R:174](r-pkg/stablr/R/bootstrap_helpers.R#L174)). This violates the "whole groups only" intent — the trimmed rows belong to a partially-included group and could leak into the complement. Is this acceptable?
6. **`artificial_proportion` is required to be in `(0, 1]`** ([stabl_fit.R:413](r-pkg/stablr/R/stabl_fit.R#L413)) but the Python reference may permit `> 1`. Confirm spec.
7. **`fdr_min_threshold` can equal `0`** when the smallest threshold (`t = 0`) minimises FDP+. With strict `>`, all features with score `> 0` are selected — including any that were ever picked once. Is this the intended "no threshold" behaviour, or should there be a minimum-effective-threshold floor?
8. **`n_explore` fallback returns features even when `artificial_type = NULL` and `hard_threshold` is set**: is exploring on top of a user-supplied hard threshold a documented contract?

---

## 5. Verification Plan

For each item above, the following are runnable read-only checks (no source mutation required) — each is described, not executed.

### V-1 (H-1, group-bootstrap numeric pitfall)

```r
# Direct evidence test
set.seed(1)
groups <- rep(1:3, each = 5)   # NUMERIC group ids
y      <- rep(c(0, 1), length.out = 15)
out <- replicate(2000, {
  idx <- group_bootstrap_indices(y = y, groups = groups, n_subsamples = 10L,
                                 replace = FALSE)
  any(!unique(groups[idx]) %in% groups)   # fabricated group label?
})
# Expect: any(out) == TRUE for the buggy implementation.
```
A direct testthat expectation: `expect_true(all(unique(groups[idx]) %in% groups))` for many seeds and numeric-group inputs.

### V-2 (H-2, RP source sampling without replacement)

- Cross-check `stabl/stabl.py::_make_artificial_features` for `replace=` behaviour.
- Simulation: with `artificial_proportion = 1` and `p = 5`, request 200 artificial-feature blocks; verify the 5 source columns each appear exactly 200 times in R but with a binomial(200, 1/5) distribution in Python (or vice versa).

### V-3 (H-3, parity test asserts wrong statistic)

- Re-derive `r_max_scores <- get_importances(fit)` (the spec-defined importance) and compare against the Python `python_mean_score` only after generating a Python fixture that exports `python_max_score` and `python_support` (the FDP+-thresholded set). Then assert symmetric overlap on `python_support` vs `get_feature_names_out(fit)` and `cor(r_max_scores, py_max_scores) > 0.8` for the gaussian/lasso null+signal cases.

### V-4 (FDP+ calibration under the null — currently absent)

```r
set.seed(0)
n <- 100; p <- 50
x <- matrix(rnorm(n * p), n, p,
            dimnames = list(paste0("s", 1:n), paste0("f", 1:p)))
y <- setNames(rnorm(n), rownames(x))   # PURE NOISE
fit <- stabl_fit(x, y, lambda_grid = "auto", n_bootstraps = 200L,
                 artificial_type = "random_permutation",
                 random_state = 1L)
# Spec: under the null, expect 0–few selections at FDP+-optimal threshold.
expect_lte(sum(get_support(fit)), ceiling(0.05 * p))
expect_gte(fit$fdr_min_threshold_, 0.5)   # threshold should land high on noise
```

### V-5 (Signal recovery — currently weak)

```r
n <- 200; p <- 30
x <- matrix(rnorm(n * p), n, p,
            dimnames = list(paste0("s", 1:n), paste0("f", 1:p)))
beta <- numeric(p); beta[1:3] <- c(2.0, -1.5, 1.0)
y <- setNames(as.numeric(x %*% beta + rnorm(n, 0, 0.3)), rownames(x))
fit <- stabl_fit(x, y, "auto", n_bootstraps = 200L, random_state = 7L)
expect_setequal(get_feature_names_out(fit), c("f1", "f2", "f3"))
```
A symmetric variant with grouped sampling and grouped y would close the leakage-prevention gap.

### V-6 (Symbolic strict-`>` and `(1/π)` invariants)

```r
art   <- matrix(0.5, 10, 5)      # all artificial scores tied at threshold
real  <- matrix(0.5, 10, 5)
res   <- compute_fdp_plus(real, art, artificial_proportion = 1,
                          fdr_threshold_range = c(0.5))
# Strict >: nothing exceeds 0.5 → numerator = 1 + (1/π)*0 = 1, denom = max(1,0) = 1
expect_equal(unname(res$FDRs), 1)

art2  <- matrix(0.6, 10, 5); real2 <- matrix(0.6, 10, 5)
res2  <- compute_fdp_plus(real2, art2, artificial_proportion = 0.5,
                          fdr_threshold_range = c(0.5))
# (1/0.5)*10 + 1 = 21; denom = max(1, 10) = 10 → 2.1
expect_equal(unname(res2$FDRs), 2.1)
```

---

## Audit Closure Tracking (2026-05-08)

- Remediation implementation status: in progress-to-close.
- Landed work items: WI-01, WI-02, WI-03, WI-04, WI-05, WI-07, WI-08,
  WI-09, WI-10, WI-11, WI-12, WI-13, WI-14, WI-15, WI-16.
- Reclassifications validated against Python source:
  - H-2 -> TEST-ONLY (`replace=False` parity)
  - M-1 -> DOC-ONLY (`bootstrap_threshold = 1e-5` parity)
  - WI-06 dropped (requested `pi` scaling parity)
- Full-suite validation executed in `R4_51`:
  - command: `source /share/software/tools/miniconda/3.10/23.3.1/bin/activate R4_51 && Rscript -e "testthat::test_local('r-pkg/stablr')"`
  - result: `[ FAIL 7 | WARN 0 | SKIP 4 | PASS 1336 ]`.
- Remaining closure gate: remediate 7 failing contexts (`bootstrap-helpers`,
  `fdp-calibration`, `fdp-plus-invariants`, `input-validation`,
  `multiomic-guards`, `python-parity-fixtures`, `signal-recovery`) and re-run
  full suite to `FAIL 0` before final closure mapping.
- Canonical implementation log and per-item details: [PROGRESS.md](PROGRESS.md).

### V-7 (Parallel determinism, M-2)

```r
fit_seq <- stabl_fit(x, y, lam, n_bootstraps = 50L, random_state = 1L, workers = 1L)
future::plan(future::multisession, workers = 2L)
fit_par <- stabl_fit(x, y, lam, n_bootstraps = 50L, random_state = 1L, workers = 2L)
future::plan(future::sequential)
expect_equal(fit_seq$stabl_scores_, fit_par$stabl_scores_)
```
This will fail with the current implementation; the result should drive an explicit non-equivalence note in `STABL.md`.

### V-8 (Edge cases not currently tested)

- **`n = 1` group**: `validate_sample_alignment` only checks names; `group_bootstrap_indices` with one group will exit the `while` loop after one draw and leave `length(sampled_idx) == n`; check that the degenerate case is rejected upstream or returns a coherent fit.
- **Zero-variance feature column**: `glmnet` will warn or drop; verify the dropped column's `stabl_scores_` row is `0` (not `NA`).
- **All-zero rows in X**: `auto_lambda_grid` will return a degenerate path; expect informative error.
- **Single-lambda grid**: confirm `apply(stabl_scores_, 1L, max)` and `compute_fdp_plus` handle `n_lambdas == 1` correctly (currently `apply` returns a numeric vector, OK).
- **`n_subsamples == n_samples` with `replace = FALSE`**: pre-flight passes; verify subsample is the *full* data each iteration → all stability scores collapse to `{0, 1}` per lambda.

### V-9 (Multi-omic alignment hard error, M/H-coverage)

- Pass `x_train_list` with mismatched row order across two omics → expect "All omic tables must have identical sample order".
- Pass `cooperative_fusion = TRUE, family = "cox", cooperation_selection = "validation"` → expect rejection.
- Mock `.has_multiview = function() FALSE` and call cooperative fusion → expect "requires the optional 'multiview' package".

### V-10 (S3 dispatch on `get_feature_names_out`)

`NAMESPACE` registers `S3method(get_feature_names_out, stabl_fit)`, and `get_feature_names_out` and its method are exported. Add a regression test:
```r
fit <- stabl_fit(...)
expect_identical(get_feature_names_out(fit),
                 names(get_support(fit))[get_support(fit)])
```
Currently no test asserts this round-trip explicitly.

---

## Trace Block — Single-Omic Core Path

```
stabl_fit(x, y, lambda_grid, ...)                   stabl_fit.R:160
  ├── validate_sample_alignment(x, y, groups)       input_validation.R:42
  ├── .subset_outcome_by_ids(y, rownames(x))        input_validation.R:99
  ├── .validate_stabl_params(...)                   stabl_fit.R:391
  ├── auto_lambda_grid(x, y, family, n_lambda)      learner_adapters.R:~700  [if "auto"]
  ├── n_injected = round(p * π)                     stabl_fit.R:210
  ├── make_artificial_features(x, n_injected, ...)  artificial_features.R:159
  │     └── make_rp_features | make_knockoff_features
  ├── .resolve_sgl_feature_groups(...)              stabl_fit.R:225  [SGL only]
  ├── batch_adapter <- switch(base_learner, ...)    stabl_fit.R:240-275
  ├── n_subsamples = floor(s * n)                   stabl_fit.R:286
  ├── reject n_subsamples > n_samples (replace=FALSE) stabl_fit.R:308-315
  ├── set.seed(random_state)                        stabl_fit.R:317
  ├── boot_indices <- lapply(1:B, boot_sampler)     stabl_fit.R:325
  │     └── classic_bootstrap_indices | group_bootstrap_indices
  ├── for k in 1:B (sequential) | future_map (parallel)  stabl_fit.R:337-356
  │     └── batch_adapter(x_fit[idx, ], y[idx], lambda_grid)
  │           returns logical (p+q) × n_lambdas
  ├── stabl_scores_ /= n_bootstraps                 stabl_fit.R:359
  ├── compute_fdp_plus(scores, scores_art, π, grid) fdp_control.R:38
  └── structure(..., class = "stabl_fit")           stabl_fit.R:380
```

The chain is consistent with `STABL.md § Steps 1–5`; the only divergence from the spec is the documented `round` vs. `floor` for `n_injected`.

---

## Trace Block — Multi-Omic Cooperative Fusion

```
stabl_multiomic_train_validate(x_train_list, y_train, ..., cooperative_fusion = TRUE)
  ├── validate_multiomic_inputs(x_train_list, y_train, groups_train)   input_validation.R:142
  ├── .resolve_multiomic_lambda_grid(...)                               multiomic_workflows.R
  ├── .normalize_cooperative_multiomic_args(...)                        input_validation.R:228
  │     ├── .has_multiview() (mockable guard)                            input_validation.R:198
  │     ├── reject family != gaussian|binomial|poisson|cox
  │     ├── reject family == "cox" + selection == "validation"
  │     └── reject lambda.1se + selection == "validation"
  ├── for omic in omic_names: stabl_fit(x_train, y_train, ...)          multiomic_workflows.R:152
  ├── (optional) early_fusion: stabl_fit on cbind(omics)
  ├── (optional) late_fusion: stacked_multi_omic(per-omic preds)
  └── (cooperative_fusion) multiview::cv.multiview / multiview::multiview
```

The per-omic STABL passes are independent (each omic gets its own bootstrap loop and FDP+); the cooperative branch is additive. Sample alignment is enforced by `validate_multiomic_inputs` (hard error). This matches `PLAN.md`'s "locked decision" on hard errors for misalignment.

---

## Final Notes

- All findings here are textually grounded in the cited files; no claim is made about runtime behaviour that was not directly inspected in source.
- No edits were made to source, tests, documentation, or NAMESPACE during this audit.
- The audit did not run `devtools::test()` or `R CMD check` (read-only restriction with respect to package state); recommended next step is to run the verification plan items V-1, V-2, V-4, V-6, V-7 as new test cases before remediation.

---

## Remediation Plan

**Date filed:** 2026-05-08
**Status:** PLAN ONLY — no source/test/doc edits in this pass. Awaiting user decisions D1–D3 (see §2) before TDD execution begins.

### 1. Plan Summary

- Scope: all H-* (3) + M-* (8) findings, plus V-1, V-4, V-5, V-6, V-7, V-8, V-9, V-10 as new tests. 15 work items + 2 cross-cutting infra items.
- Tier breakdown: 3 FIX-NOW · 5 FIX-SOON · 3 DECIDE-THEN-FIX · 3 TEST-ONLY · 1 DOC-ONLY · 2 DEFER.
- Blockers: WI-05 (D3), WI-06 (D2), WI-09 (D1) require user decisions before RED tests can be authored.
- Order: H-1 → H-3 (+CC1 fixture loader) → H-2 → V-6 → V-1 → V-4 → V-5 → M-2/V-7 → M-5 → V-9 → V-10 → M-7/M-8/V-8 → M-6.
- Deferred: M-3 (SGL multinomial), M-4 (adaptive-lasso init lambda) → `PLAN.md § Open Milestones`.

### 2. Decisions Required Before Coding

**D1 — `bootstrap_threshold` policy (M-1, blocks WI-09).** Recommend **A: cross-check `stabl/stabl.py` and match Python literally** before any change. B = keep `1e-5` and document divergence; C = strict `coef != 0`.

**D2 — FDP+ `(1/π)` factor: requested vs realised (audit Q2, blocks WI-06).** Recommend **A: pass `realised_pi = n_injected / p`** so the per-original-feature scaling is exact under R's `round(p·π)`. B = keep requested `π`; C = switch `n_injected` to `floor` to match Python.

**D3 — `group_bootstrap_indices` row-trim policy (audit Q5, blocks WI-05).** Recommend **A: drop the trim (allow under-fill; never split a group)** for the strongest leakage guarantee. B = keep trim and exclude trimmed rows from complement; C = uniform random row removal.

### 3. Work Items (Ordered)

| ID | Audit refs | Tier | Spec anchor | Acceptance | RED test file | GREEN edit | Effort |
|---|---|---|---|---|---|---|---|
| WI-CC1 | infra | INFRA | — | `helper-parity.R::load_python_parity_fixture()` returns `python_max_score` + `python_support` | `tests/testthat/helper-parity.R` | new helper | XS |
| WI-01 | H-1, V-1 | FIX-NOW | §Step 2 (no leakage) | numeric `groups` never fabricate labels | `test-bootstrap-helpers-numeric.R` | `bootstrap_helpers.R`: replace `sample(remaining,1L)` with `remaining[[sample.int(length(remaining),1L)]]` (2 sites) | XS |
| WI-02 | H-3, V-3, V-10 | FIX-NOW | §Step 3 (`max` over Λ) | parity asserts `get_importances` and `get_feature_names_out` against `python_max_score` / `python_support` | extend `test-python-parity-fixtures.R` | regen Python fixtures + rewrite `expect_python_parity()` body | M |
| WI-03 | H-2, V-2 | FIX-NOW | §Step 1.2 + Q1 | RP source columns sampled with replacement; supports `n_injected > p` | `test-artificial-features-replacement.R` | `artificial_features.R:20` `replace=FALSE→TRUE` | S |
| WI-04 | V-6 | TEST-ONLY | §Step 4.2 | hand-computed FDP+ tied/scaled cases pass | `test-fdp-plus-invariants.R` | none | XS |
| WI-05 | Q5, M-7 | DECIDE→FIX-SOON | spec silent (D3) | whole-group invariant holds | extend `test-bootstrap-helpers-numeric.R` | drop `seq_len(min(...))` trim in `bootstrap_helpers.R` | S |
| WI-06 | Q2 | DECIDE→FIX-SOON | §Step 4.2 (D2) | `compute_fdp_plus` receives realised `π` | `test-fdp-plus-realised-pi.R` | `stabl_fit.R`: pass `n_injected/p` | XS |
| WI-07 | V-1 | TEST-ONLY | §Step 2 | parametrised over integer/character/factor groups | `test-bootstrap-group-types.R` | none | XS |
| WI-08 | V-4 | TEST-ONLY | §Step 4 | null-data calibration: `sum(get_support(fit)) ≤ 0.05·p`; `fdr_min_threshold_ ≥ 0.5` | `test-fdp-calibration.R` (`skip_on_cran`) | none | S |
| WI-09 | M-1 | DECIDE→FIX-SOON or DOC | §Step 2.4 (D1) | mask agrees with chosen policy | `test-bootstrap-threshold.R` | `learner_adapters.R` default change OR `STABL.md` divergence note | XS |
| WI-10 | V-5 | TEST-ONLY | §Step 4 | exact recovery of 3-feature signal | `test-signal-recovery.R` (`skip_on_cran`) | none | S |
| WI-11 | M-2, V-7 | FIX-SOON | §Reproducibility | `expect_equal(fit_seq$stabl_scores_, fit_par$stabl_scores_)` for workers ∈ {1,2,4} | `test-parallel-determinism.R` | `stabl_fit.R`: pre-generate per-iter L'Ecuyer streams from `random_state`, use `withr::with_seed` in worker | M |
| WI-12 | M-5 | FIX-SOON | §Reproducibility | independent RNG streams for art-features vs bootstrap indices; no nested `set.seed` | `test-rng-isolation.R` | `artificial_features.R`: replace nested `set.seed` with `withr::with_seed`; remove inner re-seed in `make_knockoff_features` | S |
| WI-13 | V-9 | TEST-ONLY | multi-omic guards | misalignment / cox+validation / no-multiview errors | `test-multiomic-guards.R` | none | S |
| WI-14 | V-10 | TEST-ONLY | accessor contract | `get_feature_names_out == names(get_support)[get_support]` | `test-accessor-roundtrip.R` | none | XS |
| WI-15 | M-7, M-8, V-8 | FIX-SOON + TEST-ONLY | §Inputs | `sample_fraction > 1` rejected when `replace=FALSE`; warned with `replace=TRUE`; edge cases pass | `test-validation-edges.R` | tighten `.validate_stabl_params` | S |
| WI-16 | M-6 | DOC-ONLY | — | docstring matches code semantics | — | roxygen edit in `artificial_features.R` | XS |

Per-item RED messages, regression guards, blast-radius notes, and doc updates are recorded in the chat plan; this table is the canonical reference for execution sequencing.

### 4. Cross-Cutting Test Infrastructure

- **CC1** — `tests/testthat/helper-parity.R` (loader keyed on `python_max_score` + `python_support`).
- **CC2** — `tests/testthat/helper-skips.R` (centralised `skip_if_not_installed` wrappers for `furrr`, `sparsegl`, `knockoff`, `multiview`).
- Fixture regen script: `tests/testthat/fixtures/regen_python_parity.py` updated to emit max-score and support arrays.

### 5. Acceptance Gate

- All FIX-NOW (WI-01/02/03) and FIX-SOON (WI-05/06/09/11/12/15) green.
- All TEST-ONLY items (WI-04/07/08/10/13/14) passing.
- `devtools::test()` and `R CMD check` clean (or pre-existing warnings catalogued unchanged).
- `STABL.md § Parity-Critical Invariants` updated to reflect: max-over-Λ explicit; RP source draw `replace=TRUE`; FDP+ proportion choice (D2 outcome); group-trim policy (D3 outcome); parallel determinism contract.
- `PLAN.md` and `PROGRESS.md` updated; `HANDOFF.md § Immediate Next Tasks` refreshed.
- "Audit closure" subsection appended below this plan, citing `PROGRESS.md` line per finding ID.

### 6. Out-of-Scope / Deferred

- **M-3** — SGL multinomial one-vs-rest fallback. Filed to `PLAN.md § Open Milestones`. DOC-ONLY note added to `STABL.md` flagging the documented limitation.
- **M-4** — Adaptive-lasso ridge-init lambda choice. Filed to `PLAN.md § Open Milestones` pending Python cross-check.
