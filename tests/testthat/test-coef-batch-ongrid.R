# Characterization tests for .feature_abs_coefs_batch on-grid fast path (Item 10).
# These tests verify that when all requested lambdas are on fit$lambda, the fast
# path (reading fit$beta directly) produces bit-identical output to the current
# per-lambda coef() implementation (the slow reference path).

# Reference slow-path implementation — mirrors the original code before Item 10.
# Used only in these tests to confirm the fast path is parity-equivalent.
.slow_feature_abs_coefs_batch <- function(fit, lambda_seq, family = "gaussian") {
  col_list <- lapply(lambda_seq, function(s) {
    .feature_abs_coefs(fit = fit, s = s, family = family)
  })
  do.call(cbind, col_list)
}

.local_count_feature_abs_coefs <- function(counter_env) {
  ns <- environment(.feature_abs_coefs_batch)
  original <- get(".feature_abs_coefs", envir = ns)
  wrapper <- function(...) {
    counter_env$n <- counter_env$n + 1L
    original(...)
  }
  unlockBinding(".feature_abs_coefs", ns)
  assign(".feature_abs_coefs", wrapper, envir = ns)
  lockBinding(".feature_abs_coefs", ns)

  withr::defer({
    unlockBinding(".feature_abs_coefs", ns)
    assign(".feature_abs_coefs", original, envir = ns)
    lockBinding(".feature_abs_coefs", ns)
  }, testthat::teardown_env())
}

test_that("on-grid coef batch fast path is bit-identical: gaussian", {
  skip_if_not_installed("glmnet")
  set.seed(42L)
  n <- 30L; p <- 8L
  x <- matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("v", seq_len(p))))
  y <- rnorm(n)
  lambda_seq <- c(0.5, 0.3, 0.1)
  fit <- glmnet::glmnet(x, y, family = "gaussian", alpha = 1,
                        lambda = sort(lambda_seq, decreasing = TRUE))
  expect_identical(
    .feature_abs_coefs_batch(fit, lambda_seq, family = "gaussian"),
    .slow_feature_abs_coefs_batch(fit, lambda_seq, family = "gaussian")
  )
})

test_that("on-grid coef batch fast path is bit-identical: binomial", {
  skip_if_not_installed("glmnet")
  set.seed(43L)
  n <- 30L; p <- 8L
  x <- matrix(rnorm(n * p), n, p)
  y <- rbinom(n, 1L, 0.5)
  lambda_seq <- c(0.4, 0.2, 0.05)
  fit <- glmnet::glmnet(x, y, family = "binomial", alpha = 1,
                        lambda = sort(lambda_seq, decreasing = TRUE))
  expect_identical(
    .feature_abs_coefs_batch(fit, lambda_seq, family = "binomial"),
    .slow_feature_abs_coefs_batch(fit, lambda_seq, family = "binomial")
  )
})

test_that("on-grid coef batch fast path is bit-identical: multinomial", {
  skip_if_not_installed("glmnet")
  set.seed(44L)
  n <- 30L; p <- 8L
  x <- matrix(rnorm(n * p), n, p)
  y <- factor(rep(c("A", "B", "C"), each = 10L))
  lambda_seq <- c(0.3, 0.15, 0.05)
  fit <- glmnet::glmnet(x, y, family = "multinomial", alpha = 1,
                        lambda = sort(lambda_seq, decreasing = TRUE))
  expect_identical(
    .feature_abs_coefs_batch(fit, lambda_seq, family = "multinomial"),
    .slow_feature_abs_coefs_batch(fit, lambda_seq, family = "multinomial")
  )
})

test_that("off-grid lambda falls back to per-lambda coef path", {
  skip_if_not_installed("glmnet")
  set.seed(45L)
  n <- 30L; p <- 8L
  x <- matrix(rnorm(n * p), n, p)
  y <- rnorm(n)
  lambda_seq <- c(0.5, 0.3, 0.1)
  fit <- glmnet::glmnet(x, y, family = "gaussian", alpha = 1,
                        lambda = sort(lambda_seq, decreasing = TRUE))
  off_grid <- c(0.4, 0.2)
  result <- .feature_abs_coefs_batch(fit, off_grid, family = "gaussian")
  ref    <- .slow_feature_abs_coefs_batch(fit, off_grid, family = "gaussian")
  expect_equal(result, ref, tolerance = 1e-12)
})

test_that("near-on-grid lambdas use batch path and match slow glmnet coef extraction", {
  skip_if_not_installed("glmnet")
  set.seed(46L)
  n <- 40L; p <- 10L
  x <- matrix(rnorm(n * p), n, p)
  y <- rnorm(n)
  lambda_seq <- sort(c(0.8, 0.5, 0.2, 0.08), decreasing = TRUE)
  fit <- glmnet::glmnet(x, y, family = "gaussian", alpha = 1, lambda = lambda_seq)
  near_lambda <- fit$lambda +
    c(1, -1, 1, -1) * .Machine$double.eps * pmax(1, abs(fit$lambda))
  expect_true(any(is.na(match(near_lambda, fit$lambda))))

  ref <- .slow_feature_abs_coefs_batch(fit, near_lambda, family = "gaussian")
  slow_calls <- new.env(parent = emptyenv())
  slow_calls$n <- 0L
  .local_count_feature_abs_coefs(slow_calls)

  result <- .feature_abs_coefs_batch(fit, near_lambda, family = "gaussian")

  expect_equal(result, ref, tolerance = 1e-12)
  expect_identical(slow_calls$n, 0L)
})
