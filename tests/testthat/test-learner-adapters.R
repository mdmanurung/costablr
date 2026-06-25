# Tests for the three public single-lambda adapter factories (Item 15).
# stabl_fit() uses the batch variants internally; these factories are the
# user-facing single-lambda equivalents exported for custom loop usage.

.make_adapter_data <- function(n = 20L, p = 6L, seed = 1L) {
  set.seed(seed)
  x <- matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("v", seq_len(p))))
  y <- rnorm(n)
  list(x = x, y = y, lambda_val = data.frame(lambda = 0.1))
}

# ---- make_glmnet_adapter -----------------------------------------------------

test_that("make_glmnet_adapter returns a selection mask of correct type/length", {
  skip_if_not_installed("glmnet")
  d <- .make_adapter_data()
  adapter <- make_glmnet_adapter(family = "gaussian")
  mask <- adapter(d$x, d$y, d$lambda_val)
  expect_type(mask, "logical")
  expect_length(mask, ncol(d$x))
})

test_that("make_glmnet_adapter alpha_fixed overrides lambda_val alpha column", {
  skip_if_not_installed("glmnet")
  d <- .make_adapter_data()
  d$lambda_val$alpha <- 0.5
  adapter_fixed <- make_glmnet_adapter(family = "gaussian", alpha_fixed = 0.0)
  adapter_col   <- make_glmnet_adapter(family = "gaussian")
  mask_fixed <- adapter_fixed(d$x, d$y, d$lambda_val)
  mask_col   <- adapter_col(d$x, d$y, d$lambda_val)
  expect_false(identical(mask_fixed, mask_col))
})

test_that("make_glmnet_adapter bootstrap_threshold controls sparsity", {
  skip_if_not_installed("glmnet")
  d <- .make_adapter_data()
  lax    <- make_glmnet_adapter(bootstrap_threshold = 1e-10)
  strict <- make_glmnet_adapter(bootstrap_threshold = 1e3)
  expect_gte(sum(lax(d$x, d$y, d$lambda_val)), sum(strict(d$x, d$y, d$lambda_val)))
})

# ---- make_adaptive_lasso_adapter ---------------------------------------------

test_that("make_adaptive_lasso_adapter returns a selection mask", {
  skip_if_not_installed("glmnet")
  d <- .make_adapter_data()
  adapter <- make_adaptive_lasso_adapter(family = "gaussian")
  mask <- adapter(d$x, d$y, d$lambda_val)
  expect_type(mask, "logical")
  expect_length(mask, ncol(d$x))
})

test_that("make_adaptive_lasso_adapter rejects non-positive gamma", {
  expect_error(make_adaptive_lasso_adapter(gamma = -1), "gamma")
  expect_error(make_adaptive_lasso_adapter(gamma = 0),  "gamma")
})

test_that("make_adaptive_lasso_adapter rejects non-positive epsilon", {
  expect_error(make_adaptive_lasso_adapter(epsilon = 0),  "epsilon")
  expect_error(make_adaptive_lasso_adapter(epsilon = -1), "epsilon")
})

# ---- make_sgl_adapter --------------------------------------------------------

test_that("make_sgl_adapter returns a selection mask", {
  skip_if_not_installed("sparsegl")
  d <- .make_adapter_data()
  groups  <- rep(1:3, each = 2L)
  adapter <- make_sgl_adapter(family = "gaussian", feature_groups = groups)
  mask <- adapter(d$x, d$y, d$lambda_val)
  expect_type(mask, "logical")
  expect_length(mask, ncol(d$x))
})

test_that("make_sgl_adapter rejects cox family", {
  expect_error(
    make_sgl_adapter(family = "cox", feature_groups = 1:3),
    "Cox family is not supported"
  )
})

test_that("make_sgl_adapter requires feature_groups", {
  expect_error(make_sgl_adapter(), "feature_groups")
})
