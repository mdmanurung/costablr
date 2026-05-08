# Audit V-10: assert that the public accessors round-trip consistently.
# Specifically, get_feature_names_out(fit) must equal
# names(get_support(fit))[get_support(fit)] for any threshold-resolution path.

test_that("get_feature_names_out equals names(get_support())[get_support()]", {
  withr::local_seed(0)
  n <- 40L; p <- 6L
  x <- matrix(rnorm(n * p), nrow = n,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_fit(x, y,
                   lambda_grid = data.frame(lambda = c(0.2, 0.1, 0.05)),
                   n_bootstraps = 8L,
                   artificial_type = "random_permutation",
                   random_state = 1L)

  mask <- get_support(fit)
  expect_identical(get_feature_names_out(fit), names(mask)[mask])
})

test_that("accessor round-trip holds with hard_threshold override", {
  withr::local_seed(0)
  n <- 40L; p <- 6L
  x <- matrix(rnorm(n * p), nrow = n,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_fit(x, y,
                   lambda_grid = data.frame(lambda = c(0.2, 0.1, 0.05)),
                   n_bootstraps = 8L,
                   artificial_type = "random_permutation",
                   random_state = 1L)

  mask_at_zero <- get_support(fit, new_hard_threshold = 0.001)
  expect_identical(get_feature_names_out(fit, new_hard_threshold = 0.001),
                   names(mask_at_zero)[mask_at_zero])
})
