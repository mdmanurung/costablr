test_that("AUDIT INT-002: unnamed features propagate fallback names", {
  withr::local_seed(201)
  ids <- paste0("s", seq_len(20L))
  x <- matrix(rnorm(20L * 3L), nrow = 20L, dimnames = list(ids, NULL))
  y <- setNames(x[, 1L] + rnorm(20L, sd = 0.1), ids)

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(view = x),
    y_train = y,
    lambda_grid = data.frame(lambda = 1e-4),
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 2L,
    sample_fraction = 1,
    random_state = 1L
  )

  expect_equal(fit$fits$view$feature_names, paste0("x.", seq_len(3L)))
  expect_true(all(fit$selected_features$view %in% fit$fits$view$feature_names))
  expect_equal(ncol(fit$selected_train$view), length(fit$selected_features$view))
})

test_that("AUDIT INT-003: shuffled named y is aligned before late fusion", {
  withr::local_seed(202)
  ids <- paste0("s", seq_len(30L))
  x_a <- matrix(
    rnorm(30L * 4L),
    nrow = 30L,
    dimnames = list(ids, paste0("a", seq_len(4L)))
  )
  x_b <- matrix(
    rnorm(30L * 4L),
    nrow = 30L,
    dimnames = list(ids, paste0("b", seq_len(4L)))
  )
  y <- setNames(2 * x_a[, 1L] - x_b[, 2L] + rnorm(30L, sd = 0.1), ids)
  y_shuffled <- y[sample(seq_along(y))]

  args <- list(
    x_train_list = list(a = x_a, b = x_b),
    lambda_grid = data.frame(lambda = 1e-4),
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 2L,
    sample_fraction = 1,
    family = "gaussian",
    late_fusion = TRUE,
    n_iter_lf = 20L,
    random_state = 7L
  )
  fit_ordered <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = y))
  ))
  fit_shuffled <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = y_shuffled))
  ))

  expect_equal(fit_ordered$selected_features, fit_shuffled$selected_features)
  expect_equal(
    fit_ordered$late_fusion$train_predictions,
    fit_shuffled$late_fusion$train_predictions,
    ignore_attr = TRUE
  )
})

test_that("AUDIT INT-004: validation predictors without y_valid return late predictions", {
  withr::local_seed(203)
  ids <- paste0("s", seq_len(12L))
  x_a <- matrix(
    rnorm(12L * 3L),
    nrow = 12L,
    dimnames = list(ids, paste0("a", seq_len(3L)))
  )
  x_b <- matrix(
    rnorm(12L * 3L),
    nrow = 12L,
    dimnames = list(ids, paste0("b", seq_len(3L)))
  )
  y <- setNames(rnorm(12L), ids)
  x_valid <- list(
    a = x_a[seq_len(4L), , drop = FALSE],
    b = x_b[seq_len(4L), , drop = FALSE]
  )

  fit <- suppressWarnings(stabl_multiomic_train_validate(
    x_train_list = list(a = x_a, b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = 1),
    x_valid_list = x_valid,
    y_valid = NULL,
    artificial_type = NULL,
    hard_threshold = 1,
    n_bootstraps = 2L,
    sample_fraction = 1,
    late_fusion = TRUE,
    n_iter_lf = 5L,
    random_state = 1L
  ))

  expect_type(fit$late_fusion$valid_predictions, "double")
  expect_length(fit$late_fusion$valid_predictions, 4L)
})

test_that("AUDIT INT-005: stacked_multi_omic rejects recycled short y", {
  predictions <- matrix(
    c(0.1, 0.8, 0.2, 0.9, 0.2, 0.7, 0.3, 0.6),
    nrow = 4L,
    dimnames = list(paste0("s", seq_len(4L)), c("a", "b"))
  )

  expect_error(
    stacked_multi_omic(
      predictions,
      y = c(0, 1),
      task_type = "binary",
      n_iter = 5L,
      random_state = 1L
    ),
    "one value per prediction row"
  )
})
