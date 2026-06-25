# Characterization gate for the stabl_fit() decomposition (clean-code M4/M5).
# Pins exact stabl_scores_ and FDP+ outputs so any extraction of sub-helpers
# must produce bit-identical results.

test_that("stabl_fit decomposition: stabl_scores_ and FDP+ outputs are bit-identical", {
  set.seed(0L)
  n <- 40L; p <- 6L
  x <- matrix(rnorm(n * p), n, p,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))
  lam <- data.frame(lambda = c(0.2, 0.1, 0.05))

  fit <- stabl_fit(x, y, lambda_grid = lam, n_bootstraps = 8L,
                   artificial_type = "random_permutation",
                   random_state = 42L, workers = 1L)

  expected_scores <- matrix(
    c(0.125, 0.125, 0.000, 0.375, 0.375, 0.125,
      0.500, 0.500, 0.250, 0.625, 0.625, 0.500,
      0.875, 0.875, 0.875, 0.875, 0.500, 0.500),
    nrow = 6L, ncol = 3L,
    dimnames = list(paste0("f", seq_len(6L)), NULL)
  )

  expect_equal(fit$stabl_scores_, expected_scores, tolerance = 0)
  expect_equal(fit$fdr_min_threshold_, 1.0, tolerance = 0)
  expect_equal(fit$min_fdr_, 7/6, tolerance = 1e-14)
})
