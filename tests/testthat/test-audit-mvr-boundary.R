test_that("AUDIT INT-006: direct Rcpp MVR boundary rejects non-permutation order", {
  sigma <- diag(4L)
  bad_order <- matrix(c(1L, 1L, 2L, 3L), nrow = 1L)

  expect_error(
    costablr:::mvr_solve_ungrouped_cpp(
      sigma,
      num_iter = 1L,
      update_order = bad_order
    ),
    "permutation"
  )
  expect_error(
    costablr:::.solve_mvr(sigma, num_iter = 1L, update_order = bad_order),
    "permutation"
  )
})
