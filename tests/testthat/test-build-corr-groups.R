# Characterization tests for .build_corr_groups (Item 11).
# These pin the exact integer group partition produced by the current O(p²)
# double-loop implementation so that the vectorised-edge-list refactoring can be
# verified to produce bit-identical output.

.make_corr_test_matrix <- function() {
  set.seed(42L)
  n <- 200L; p <- 12L
  x <- matrix(rnorm(n * p), n, p)
  colnames(x) <- paste0("f", seq_len(p))
  # Group A: f1, f2 — near-perfect correlation
  x[, 2L] <- x[, 1L] * 0.99 + rnorm(n) * 0.01
  # Group B: f5, f6, f7 — moderate shared factor
  base    <- rnorm(n)
  x[, 5L] <- base * 0.9 + rnorm(n) * 0.1
  x[, 6L] <- base * 0.9 + rnorm(n) * 0.1
  x[, 7L] <- base * 0.9 + rnorm(n) * 0.1
  x
}

test_that(".build_corr_groups produces expected partition at percentile 95", {
  x    <- .make_corr_test_matrix()
  grps <- stablr:::.build_corr_groups(x, percentile = 95)
  expect_identical(grps, c(1L, 1L, 2L, 3L, 4L, 4L, 4L, 5L, 6L, 7L, 8L, 9L))
})

test_that(".build_corr_groups produces expected partition at percentile 99", {
  x    <- .make_corr_test_matrix()
  grps <- stablr:::.build_corr_groups(x, percentile = 99)
  expect_identical(grps, c(1L, 1L, 2L, 3L, 4L, 4L, 4L, 5L, 6L, 7L, 8L, 9L))
})

test_that(".build_corr_groups: correlated features end up in same group", {
  x    <- .make_corr_test_matrix()
  grps <- stablr:::.build_corr_groups(x, percentile = 95)
  # f1 and f2 must share a group
  expect_equal(grps[[1L]], grps[[2L]])
  # f5, f6, f7 must share a group
  expect_equal(grps[[5L]], grps[[6L]])
  expect_equal(grps[[5L]], grps[[7L]])
  # f1+f2 and f5+f6+f7 must be distinct groups
  expect_false(grps[[1L]] == grps[[5L]])
})

test_that(".build_corr_groups: p=1 returns single-group vector", {
  x <- matrix(rnorm(10L), ncol = 1L)
  expect_identical(stablr:::.build_corr_groups(x, percentile = 90), 1L)
})
