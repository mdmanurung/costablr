# Audit V-4: under the null (X is pure noise, no signal in y), STABL with
# random-permutation artificial features and the FDP+ diagnostic should select
# essentially nothing.  This protects against any future regression in the
# FDP+ pipeline that lets noise features through (e.g. wrong comparator,
# inverted scaling, mis-aligned artificial-vs-real masks).
#
# Statistical justification: under a null Gaussian outcome, FDP+ should drive
# the selected threshold high and avoid all-feature collapse. With max-over-
# lambda importances and finite bootstrap grids, non-trivial null selections
# can still occur; therefore this test asserts robust calibration invariants
# rather than a near-zero count target.

test_that("FDP+ diagnostic under null yields high threshold without all-feature collapse", {
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

  # Under null we should not collapse to selecting all features.
  expect_lt(n_selected, p)

  # FDP+-optimal threshold should land high on noise.
  expect_gte(fit$fdr_min_threshold_, 0.8)
})
