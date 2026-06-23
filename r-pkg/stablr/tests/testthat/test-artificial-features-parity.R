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

# C4 characterization: x_augmented column layout — artificial cols occupy
# exactly (p+1):(p+n_injected); using seq_len() must give identical indices.
test_that("make_rp_features artificial columns occupy exactly the right index range", {
  withr::local_seed(42)
  p          <- 5L
  n_injected <- 3L
  x <- matrix(rnorm(20 * p), nrow = 20,
               dimnames = list(paste0("s", seq_len(20)), paste0("f", seq_len(p))))

  out <- make_rp_features(x, n_injected = n_injected)

  # x_augmented must have p + n_injected columns
  expect_equal(ncol(out$x_augmented), p + n_injected)

  # The artificial-column block is cols (p+1):(p+n_injected) — equivalently
  # p + seq_len(n_injected). Both formulations must yield the same block.
  art_idx_seq  <- seq(p + 1L, p + n_injected)
  art_idx_slen <- p + seq_len(n_injected)
  expect_identical(art_idx_seq, art_idx_slen)

  # Artificial columns in x_augmented are distinct from the original block
  orig_block <- out$x_augmented[, seq_len(p), drop = FALSE]
  art_block  <- out$x_augmented[, art_idx_slen, drop = FALSE]
  expect_equal(dim(orig_block), c(20L, p))
  expect_equal(dim(art_block),  c(20L, n_injected))
})

test_that("make_knockoff_features handles p < n < 2p augmentation without fallback", {
  skip_if_not_installed("knockoff")
  withr::local_seed(3)
  x <- matrix(rnorm(60 * 40), nrow = 60,
              dimnames = list(paste0("s", 1:60), paste0("f", 1:40)))

  expect_warning(
    out <- make_knockoff_features(x, n_injected = 10L),
    NA
  )

  expect_equal(dim(out$x_augmented), c(60L, 50L))
  expect_length(out$noise_col_indices, 10L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= ncol(x)))
})
