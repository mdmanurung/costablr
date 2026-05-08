# Audit H-2 (reclassified TEST-ONLY): Python random-permutation artificial
# feature generation samples source columns without replacement.
#
# Python reference: stabl/stabl.py uses rng.choice(..., replace=False).
# This test pins the same invariant for the R implementation.

test_that("make_rp_features samples source columns without replacement", {
  withr::local_seed(1)
  x <- matrix(rnorm(20 * 8), nrow = 20,
               dimnames = list(paste0("s", 1:20), paste0("f", 1:8)))

  out <- make_rp_features(x, n_injected = 8L)

  expect_length(out$noise_col_indices, 8L)
  expect_equal(sort(out$noise_col_indices), seq_len(8L))
  expect_equal(length(unique(out$noise_col_indices)), 8L)
})

test_that("make_artificial_features random_permutation preserves no-duplicate source invariant", {
  withr::local_seed(2)
  x <- matrix(rnorm(30 * 10), nrow = 30,
               dimnames = list(paste0("s", 1:30), paste0("f", 1:10)))

  out <- make_artificial_features(
    x = x,
    n_injected = 6L,
    type = "random_permutation",
    random_state = 11L
  )

  expect_length(out$noise_col_indices, 6L)
  expect_equal(length(unique(out$noise_col_indices)), 6L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= ncol(x)))
})
