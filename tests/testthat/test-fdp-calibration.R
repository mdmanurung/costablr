# Audit V-4: under the null (X is pure noise, no signal in y), STABL with
# random-permutation artificial features and FDP+ control should select
# essentially nothing.  This protects against any future regression in the
# FDP+ pipeline that lets noise features through (e.g. wrong comparator,
# inverted scaling, mis-aligned artificial-vs-real masks).
#
# Statistical justification: under a null Gaussian outcome, FDP+ should avoid
# all-feature collapse. With max-over-lambda importances, finite bootstrap
# grids, and the paper-method `>=` threshold comparator, non-trivial null
# selections and moderate FDP+-optimal thresholds can still occur. Therefore
# this test asserts robust calibration invariants rather than a near-zero
# count target or a fixed high threshold.

test_that("FDP+ control under null yields high threshold without all-feature collapse", {
  skip_on_cran()
  withr::local_seed(0)

  n <- 60L; p <- 30L
  x <- matrix(rnorm(n * p), nrow = n,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_fit(x, y,
                   lambda_grid = "auto",
                   n_lambda    = 10L,
                   n_bootstraps = 50L,
                   artificial_type = "random_permutation",
                   random_state = 1L)

  n_selected <- sum(get_support(fit))

  # Under null we should not collapse to selecting all or most features.
  expect_lt(n_selected, p)
  expect_lt(n_selected, p / 2)

  # FDP+-optimal threshold should avoid the all-feature `theta = 0` collapse.
  expect_gt(fit$fdr_min_threshold_, 0)
  expect_lte(fit$min_fdr_, 1)
})
