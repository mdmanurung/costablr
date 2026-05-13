test_that("solve_mvr S-matrix is PSD and feasible", {
  withr::local_seed(7)
  p <- 20L
  rho <- 0.7
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))

  S <- costablr:::.solve_mvr(Sigma, num_iter = 5L)

  expect_equal(dim(S), c(p, p))
  expect_equal(S[upper.tri(S)], rep(0, p * (p - 1L) / 2L))
  expect_true(costablr:::.calc_mineig(S) > -1e-6)
  expect_true(costablr:::.calc_mineig(2 * Sigma - S) > -1e-6)
})

test_that("make_artificial_features supports mvr_knockoff", {
  withr::local_seed(42)
  n <- 60L
  p <- 24L
  rho <- 0.5
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))
  L <- chol(Sigma)
  x <- matrix(rnorm(n * p), nrow = n) %*% L
  dimnames(x) <- list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))

  out <- make_artificial_features(
    x,
    n_injected = 10L,
    type = "mvr_knockoff",
    random_state = 99L
  )

  expect_equal(dim(out$x_augmented), c(n, p + 10L))
  expect_length(out$noise_col_indices, 10L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= p))
  expect_false(isTRUE(all.equal(
    out$x_augmented[, seq.int(p + 1L, p + 10L), drop = FALSE],
    x[, out$noise_col_indices, drop = FALSE],
    check.attributes = FALSE
  )))
})

test_that("make_mvr_knockoff_features falls back with stable schema", {
  withr::local_seed(13)
  x <- matrix(rnorm(30 * 6), nrow = 30)

  expect_warning(
    out <- make_mvr_knockoff_features(
      x,
      n_injected = 3L,
      max_p_r = 1L
    ),
    "falling back to random permutation"
  )

  expect_equal(dim(out$x_augmented), c(30L, 9L))
  expect_length(out$noise_col_indices, 3L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= 6L))
})
