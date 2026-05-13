test_that("stabl_refit fits unpenalized linear model after gaussian selection", {
  set.seed(9001)
  n <- 36L
  p <- 6L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(1.2 * x[, 1L] - 0.8 * x[, 2L] + rnorm(n, sd = 0.2), rownames(x))

  fit <- stabl_refit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.01, 0.005)),
    family = "gaussian",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 1L
  )

  expect_s3_class(fit, "stabl_refit")
  expect_s3_class(fit$stabl_fit, "stabl_fit")
  expect_s3_class(fit$final_model, "lm")
  expect_equal(fit$task_type, "regression")
  expect_gt(length(fit$selected_features), 0L)

  pred <- predict(fit, x)
  expect_type(pred, "double")
  expect_length(pred, n)
})

test_that("stabl_refit fits unpenalized logistic model after binomial selection", {
  set.seed(9002)
  n <- 40L
  p <- 6L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  eta <- x[, 1L] - 0.7 * x[, 2L]
  y <- setNames(factor(ifelse(eta + rnorm(n, sd = 0.4) > 0, "case", "control")),
                rownames(x))

  fit <- suppressWarnings(stabl_refit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.01, 0.005)),
    family = "binomial",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 2L
  ))

  expect_s3_class(fit$final_model, "glm")
  expect_equal(fit$final_model_type, "glm_binomial")
  expect_equal(fit$outcome_levels, levels(y))

  prob <- predict(fit, x, type = "response")
  cls <- predict(fit, x, type = "class")
  expect_true(all(prob >= 0 & prob <= 1))
  expect_s3_class(cls, "factor")
  expect_equal(levels(cls), levels(y))
})

test_that("stabl_refit uses an intercept-only final model when support is empty", {
  set.seed(9003)
  n <- 24L
  p <- 5L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_refit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = 100),
    family = "gaussian",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 0.99,
    sample_fraction = 1,
    random_state = 3L
  )

  expect_length(fit$selected_features, 0L)
  expect_equal(ncol(fit$selected_train), 0L)
  expect_s3_class(fit$final_model, "lm")
  expect_equal(unname(predict(fit, x)), rep(mean(y), n), tolerance = 1e-8)
})
