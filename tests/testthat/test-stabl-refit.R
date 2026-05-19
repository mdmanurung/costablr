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

  selector <- stabl_fit(
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
  fit <- stabl_refit(selector, x = x, y = y)

  expect_s3_class(fit, "stabl_refit")
  expect_s3_class(fit$stabl_fit, "stabl_fit")
  expect_identical(fit$stabl_fit, selector)
  expect_equal(selector$family, "gaussian")
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

  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.01, 0.005)),
    family = "binomial",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 2L
  )
  fit <- suppressWarnings(stabl_refit(selector, x = x, y = y))

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

  selector <- stabl_fit(
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
  fit <- stabl_refit(selector, x = x, y = y)

  expect_length(fit$selected_features, 0L)
  expect_equal(ncol(fit$selected_train), 0L)
  expect_s3_class(fit$final_model, "lm")
  expect_equal(unname(predict(fit, x)), rep(mean(y), n), tolerance = 1e-8)
})

test_that("stabl_refit requires a fitted stabl_fit object", {
  set.seed(9004)
  n <- 16L
  p <- 4L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))

  expect_error(
    stabl_refit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.1)
    ),
    "requires `object`, a fitted `stabl_fit` object"
  )
  expect_error(
    stabl_refit(
      x,
      y,
      data.frame(lambda = 0.1)
    ),
    "`object` must be a fitted `stabl_fit` object"
  )
})

test_that("stabl_refit rejects stale selector arguments", {
  set.seed(9005)
  n <- 18L
  p <- 4L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))
  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = 0.01),
    family = "gaussian",
    n_bootstraps = 1L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 5L
  )

  expect_error(
    stabl_refit(
      selector,
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.01),
      family = "gaussian",
      new_hard_threshold = 0.5
    ),
    "no longer accepts selector arguments"
  )
})

test_that("stabl_refit requires family metadata on the selector", {
  set.seed(9006)
  n <- 18L
  p <- 4L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))
  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = 0.01),
    family = "gaussian",
    n_bootstraps = 1L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 6L
  )
  selector$family <- NULL

  expect_error(
    stabl_refit(selector, x = x, y = y),
    "must contain `family` metadata"
  )
})

test_that("stabl_refit matches selected training columns by name", {
  set.seed(9007)
  n <- 24L
  p <- 5L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(1.1 * x[, 1L] - 0.6 * x[, 2L] + rnorm(n, sd = 0.2), rownames(x))
  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.01, 0.005)),
    family = "gaussian",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 7L
  )

  x_wide <- cbind(extra = rnorm(n), x[, rev(seq_len(ncol(x))), drop = FALSE])
  rownames(x_wide) <- rownames(x)
  fit <- stabl_refit(selector, x = x_wide, y = y)

  expect_equal(colnames(fit$selected_train), fit$selected_features)
  expect_equal(rownames(fit$selected_train), rownames(x))

  missing_selected <- x[, setdiff(colnames(x), fit$selected_features[[1L]]),
                        drop = FALSE]
  expect_error(
    stabl_refit(selector, x = missing_selected, y = y),
    "missing selected feature columns"
  )
})

test_that("print.stabl_refit summarizes selector and final refit", {
  set.seed(9008)
  n <- 20L
  p <- 4L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))
  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = 0.01),
    family = "gaussian",
    n_bootstraps = 1L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 8L
  )
  fit <- stabl_refit(selector, x = x, y = y)

  expect_output(print(fit), "Selector family:.*gaussian")
  expect_output(print(fit), "Final refit:.*lm")
  expect_output(print(fit), "Selected biomarkers:")
})
