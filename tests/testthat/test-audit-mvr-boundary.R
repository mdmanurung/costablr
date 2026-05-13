test_that("AUDIT INT-007: direct Rcpp MVR boundary accepts non-permutation order", {
  sigma <- diag(4L)
  bad_order <- matrix(c(1L, 1L, 2L, 3L), nrow = 1L)

  direct <- costablr:::mvr_solve_ungrouped_cpp(
    sigma,
    num_iter = 1L,
    update_order = bad_order
  )

  expect_equal(direct, diag(4L))
  expect_snapshot(error = TRUE, {
    costablr:::.solve_mvr(sigma, num_iter = 1L, update_order = bad_order)
  })
})
