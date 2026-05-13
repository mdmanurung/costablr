test_that("NAT-001: stacked_multi_omic R-vs-Cpp parity placeholder", {
  skip("NAT-001 pending - see audit/05_native_candidates.md")
})

test_that("NAT-002: correlation grouping R-vs-Cpp parity", {
  skip_if_not(exists("corr_groups_from_corr_cpp", mode = "function"))

  same_partition <- function(a, b) {
    identical(outer(a, a, "=="), outer(b, b, "=="))
  }

  set.seed(20260513)
  n <- 60L
  block <- matrix(rnorm(n * 5L), nrow = n)
  x <- cbind(
    block,
    block[, 1L:3L, drop = FALSE] + matrix(rnorm(n * 3L, sd = 0.02), nrow = n),
    matrix(rnorm(n * 8L), nrow = n)
  )
  x[seq(1L, n, by = 7L), 2L] <- NA_real_
  x[, ncol(x)] <- 1

  corr <- suppressWarnings(stats::cor(x, use = "pairwise.complete.obs"))
  corr[is.na(corr)] <- 0
  corr_vals <- corr[upper.tri(corr, diag = FALSE)]
  cutoff <- as.numeric(stats::quantile(corr_vals, probs = 0.9,
                                       names = FALSE, na.rm = TRUE)) - 0.1

  r_groups <- costablr:::.corr_groups_from_corr_r(corr, cutoff)
  cpp_groups <- costablr:::corr_groups_from_corr_cpp(corr, cutoff)
  expect_true(same_partition(r_groups, cpp_groups))
  expect_true(same_partition(costablr:::.build_corr_groups(x, 90), cpp_groups))
})

test_that("NAT-003: MVR rank-update solver parity placeholder", {
  skip("NAT-003 pending - see audit/05_native_candidates.md")
})
