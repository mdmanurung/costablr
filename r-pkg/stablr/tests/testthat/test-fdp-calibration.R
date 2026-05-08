# Audit V-4: under the null (X is pure noise, no signal in y), STABL with
# random-permutation artificial features and FDP+ control should select
# essentially nothing.  This protects against any future regression in the
# FDP+ pipeline that lets noise features through (e.g. wrong comparator,
# inverted scaling, mis-aligned artificial-vs-real masks).
#
# Statistical justification: with p uncorrelated noise features the
# stability scores of real and artificial blocks are exchangeable, so the
# (1/pi) * |art>t| + 1 numerator dominates the denominator at every
# threshold.  We bound the empirical false-discovery rate at 0.05 * p
# (very loose to accommodate Monte Carlo variability with a small B).

test_that("FDP+ control yields ~zero selections under the null", {
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

  expect_lte(sum(get_support(fit)), ceiling(0.05 * p))
  # FDP+-optimal threshold should land high on noise (well above 0.5).
  expect_gte(fit$fdr_min_threshold_, 0.5)
})
