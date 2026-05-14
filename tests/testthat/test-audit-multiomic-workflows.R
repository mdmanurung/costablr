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

test_that("AUDIT INT-003: shuffled y is aligned before gaussian cooperative fusion", {
  skip_if_not_installed("multiview")
  withr::local_seed(700)
  ids <- paste0("s", seq_len(18L))
  x_a <- matrix(
    rnorm(18L * 4L),
    nrow = 18L,
    dimnames = list(ids, paste0("a", seq_len(4L)))
  )
  x_b <- matrix(
    rnorm(18L * 4L),
    nrow = 18L,
    dimnames = list(ids, paste0("b", seq_len(4L)))
  )
  y <- setNames(1.3 * x_a[, 1L] - 0.8 * x_b[, 2L] + rnorm(18L, sd = 0.1), ids)
  y_shuffled <- y[sample(seq_along(y))]

  args <- list(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    lambda_grid = data.frame(lambda = 0.05),
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 1L,
    sample_fraction = 1,
    family = "gaussian",
    random_state = 700L,
    cooperative_fusion = TRUE,
    rho = 0,
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )
  fit_ordered <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = y))
  ))
  fit_shuffled <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = y_shuffled))
  ))

  expect_equal(
    fit_ordered$cooperative_fusion$selected_features,
    fit_shuffled$cooperative_fusion$selected_features
  )
  expect_equal(
    fit_ordered$cooperative_fusion$train_predictions,
    fit_shuffled$cooperative_fusion$train_predictions,
    tolerance = 1e-8,
    ignore_attr = TRUE
  )
})

.audit_make_three_class_omics <- function(n_per_class = 5L, seed = 701L) {
  set.seed(seed)
  n <- 3L * n_per_class
  ids <- paste0("s", seq_len(n))
  y <- setNames(factor(rep(c("A", "B", "C"), each = n_per_class)), ids)
  signal <- model.matrix(~ y - 1)
  x_a <- matrix(
    rnorm(n * 4L, sd = 0.25),
    nrow = n,
    dimnames = list(ids, paste0("a", seq_len(4L)))
  )
  x_b <- matrix(
    rnorm(n * 4L, sd = 0.25),
    nrow = n,
    dimnames = list(ids, paste0("b", seq_len(4L)))
  )
  x_a[, 1:3] <- x_a[, 1:3] + 1.2 * signal
  x_b[, 1:3] <- x_b[, 1:3] + signal
  list(x_a = x_a, x_b = x_b, y = y)
}

test_that("AUDIT INT-003: shuffled y is aligned before multinomial cooperative fusion", {
  skip_if_not_installed("multiview")
  withr::local_seed(701)
  d <- .audit_make_three_class_omics(n_per_class = 5L, seed = 701L)
  y_shuffled <- d$y[sample(seq_along(d$y))]

  args <- list(
    x_train_list = list(omic_a = d$x_a, omic_b = d$x_b),
    lambda_grid = data.frame(lambda = 0.05),
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 1L,
    sample_fraction = 1,
    family = "multinomial",
    random_state = 701L,
    cooperative_fusion = TRUE,
    rho = 0,
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )
  fit_ordered <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = d$y))
  ))
  fit_shuffled <- suppressWarnings(do.call(
    stabl_multiomic_train_validate,
    c(args, list(y_train = y_shuffled))
  ))

  expect_equal(
    fit_ordered$cooperative_fusion$selected_features,
    fit_shuffled$cooperative_fusion$selected_features
  )
  expect_equal(
    fit_ordered$cooperative_fusion$class_summary,
    fit_shuffled$cooperative_fusion$class_summary,
    ignore_attr = TRUE
  )
  expect_equal(
    fit_ordered$cooperative_fusion$train_predictions,
    fit_shuffled$cooperative_fusion$train_predictions,
    tolerance = 1e-8,
    ignore_attr = TRUE
  )
})

test_that("AUDIT INT-CAND-C: two-class multinomial cooperative error points to binomial", {
  ids <- paste0("s", seq_len(6L))
  x <- matrix(
    rnorm(6L * 3L),
    nrow = 6L,
    dimnames = list(ids, paste0("f", seq_len(3L)))
  )
  y <- setNames(factor(rep(c("A", "B"), each = 3L)), ids)

  expect_error(
    .cooperative_multiomic_fit_ovr(
      x_train_list = list(view = x),
      y_train = y,
      cooperative_args = list()
    ),
    "family = 'binomial'"
  )
})

test_that("AUDIT CRIT-001: binary stacking treats factor outcomes like 0/1 labels", {
  predictions <- matrix(
    c(
      0.10, 0.80, 0.20, 0.90,
      0.20, 0.70, 0.30, 0.80
    ),
    nrow = 4L,
    dimnames = list(paste0("s", seq_len(4L)), c("omic_a", "omic_b"))
  )
  y_numeric <- c(0, 1, 0, 1)
  y_factor <- factor(c("no", "yes", "no", "yes"), levels = c("no", "yes"))

  fit_numeric <- stacked_multi_omic(
    predictions = predictions,
    y = y_numeric,
    task_type = "binary",
    n_iter = 20L,
    random_state = 17L
  )
  fit_factor <- stacked_multi_omic(
    predictions = predictions,
    y = y_factor,
    task_type = "binary",
    n_iter = 20L,
    random_state = 17L
  )

  expect_equal(fit_factor$score, fit_numeric$score, tolerance = 1e-12)
  expect_equal(fit_factor$score, 1)
  expect_equal(fit_factor$weights, fit_numeric$weights)
  expect_equal(fit_factor$predictions, fit_numeric$predictions)
})

test_that("AUDIT CRIT-001: binary stacking rejects malformed outcome labels", {
  predictions <- matrix(
    c(0.1, 0.8, 0.2, 0.9),
    ncol = 1L,
    dimnames = list(paste0("s", seq_len(4L)), "omic")
  )

  expect_error(
    stacked_multi_omic(predictions, factor(rep("yes", 4L)), task_type = "binary"),
    "exactly two"
  )
  expect_error(
    stacked_multi_omic(predictions, c(0, 2, 0, 1), task_type = "binary"),
    "0/1"
  )
})

test_that("AUDIT CRIT-001: binary stacking skips missing outcomes after validation", {
  predictions <- matrix(
    c(0.1, 0.8, 0.2, 0.9),
    ncol = 1L,
    dimnames = list(paste0("s", seq_len(4L)), "omic")
  )

  fit <- stacked_multi_omic(
    predictions,
    c(0, 1, NA, 1),
    task_type = "binary",
    n_iter = 10L,
    random_state = 19L
  )

  expect_true(is.finite(fit$score))
})
