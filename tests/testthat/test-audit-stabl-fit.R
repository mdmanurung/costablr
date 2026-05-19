test_that("AUDIT IMPL-002: zero artificial count is rejected early", {
  withr::local_seed(101)
  x <- matrix(
    rnorm(20),
    nrow = 10L,
    dimnames = list(paste0("s", seq_len(10L)), paste0("f", seq_len(2L)))
  )
  y <- setNames(rnorm(10L), rownames(x))

  expect_error(
    stabl_fit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.1),
      n_bootstraps = 2L,
      artificial_type = "random_permutation",
      artificial_proportion = 0.1,
      sample_fraction = 1,
      random_state = 1L
    ),
    "n_injected = 0"
  )
})

test_that("AUDIT IMPL-003: zero subsample count is rejected early", {
  withr::local_seed(102)
  x <- matrix(
    rnorm(20),
    nrow = 10L,
    dimnames = list(paste0("s", seq_len(10L)), paste0("f", seq_len(2L)))
  )
  y <- setNames(rep(c(0, 1), each = 5L), rownames(x))

  expect_error(
    stabl_fit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.1),
      family = "binomial",
      n_bootstraps = 2L,
      artificial_type = NULL,
      hard_threshold = 0.5,
      sample_fraction = 0.01,
      random_state = 1L
    ),
    "n_subsamples = 0"
  )
})

test_that("AUDIT stabl_refit: multinomial final refit predicts probabilities", {
  skip_if_not_installed("nnet")
  withr::local_seed(601)
  n_per_class <- 8L
  n <- 3L * n_per_class
  ids <- paste0("s", seq_len(n))
  y <- setNames(factor(rep(c("A", "B", "C"), each = n_per_class)), ids)
  signal <- model.matrix(~ y - 1)
  x <- matrix(
    rnorm(n * 5L, sd = 0.2),
    nrow = n,
    dimnames = list(ids, paste0("f", seq_len(5L)))
  )
  x[, 1:3] <- x[, 1:3] + signal

  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.05, 0.01)),
    family = "multinomial",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 601L
  )
  fit <- suppressWarnings(stabl_refit(selector, x = x, y = y))

  expect_equal(fit$final_model_type, "multinom")
  expect_equal(fit$outcome_levels, levels(y))

  prob <- predict(fit, x, type = "response")
  expect_true(is.matrix(prob))
  expect_equal(dim(prob), c(n, length(levels(y))))
  expect_equal(rownames(prob), ids)
  expect_equal(colnames(prob), levels(y))
  expect_true(all(abs(rowSums(prob) - 1) < 1e-8))

  cls <- predict(fit, x, type = "class")
  expect_true(all(as.character(cls) %in% levels(y)))
})

test_that("AUDIT stabl_refit: poisson final refit predicts counts", {
  withr::local_seed(602)
  n <- 28L
  ids <- paste0("s", seq_len(n))
  x <- matrix(
    rnorm(n * 5L),
    nrow = n,
    dimnames = list(ids, paste0("f", seq_len(5L)))
  )
  rate <- exp(0.6 + 0.4 * x[, 1L] - 0.2 * x[, 2L])
  y <- setNames(rpois(n, lambda = rate), ids)

  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.02, 0.01)),
    family = "poisson",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 602L
  )
  fit <- suppressWarnings(stabl_refit(selector, x = x, y = y))

  expect_equal(fit$final_model_type, "glm_poisson")
  expect_equal(selector$family, "poisson")
  pred <- predict(fit, x, type = "response")
  expect_type(pred, "double")
  expect_length(pred, n)
  expect_true(all(is.finite(pred)))
  expect_true(all(pred >= 0))
})

test_that("AUDIT stabl_refit: cox final refit predicts risk scores", {
  skip_if_not_installed("survival")
  withr::local_seed(603)
  n <- 32L
  ids <- paste0("s", seq_len(n))
  x <- matrix(
    rnorm(n * 5L),
    nrow = n,
    dimnames = list(ids, paste0("f", seq_len(5L)))
  )
  linpred <- 0.5 * x[, 1L] - 0.3 * x[, 2L]
  y <- survival::Surv(
    time = rexp(n, rate = exp(linpred) / 5) + 0.1,
    event = rbinom(n, size = 1L, prob = 0.75)
  )
  rownames(y) <- ids

  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.02, 0.01)),
    family = "cox",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 603L
  )
  fit <- suppressWarnings(stabl_refit(selector, x = x, y = y))

  expect_equal(fit$final_model_type, "coxph")
  pred <- predict(fit, x, type = "response")
  expect_type(pred, "double")
  expect_length(pred, n)
  expect_true(all(is.finite(pred)))
})

test_that("AUDIT stabl_refit: predict validates newdata schema and row ids", {
  withr::local_seed(604)
  n <- 24L
  ids <- paste0("s", seq_len(n))
  x <- matrix(
    rnorm(n * 5L),
    nrow = n,
    dimnames = list(ids, paste0("f", seq_len(5L)))
  )
  y <- setNames(1.2 * x[, 1L] - 0.7 * x[, 2L] + rnorm(n, sd = 0.1), ids)

  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.01, 0.005)),
    family = "gaussian",
    n_bootstraps = 2L,
    artificial_type = NULL,
    hard_threshold = 1e-9,
    sample_fraction = 1,
    random_state = 604L
  )
  fit <- stabl_refit(selector, x = x, y = y)
  expect_gt(length(fit$selected_features), 0L)

  unnamed <- x
  colnames(unnamed) <- NULL
  expect_error(
    predict(fit, unnamed),
    "column names"
  )

  missing_feature <- x[, setdiff(colnames(x), fit$selected_features[[1L]]),
                       drop = FALSE]
  expect_error(
    predict(fit, missing_feature),
    "missing selected feature columns"
  )

  duplicated_ids <- x
  rownames(duplicated_ids)[[2L]] <- rownames(duplicated_ids)[[1L]]
  expect_error(
    predict(fit, duplicated_ids),
    "unique sample ids"
  )

  no_ids <- x
  rownames(no_ids) <- NULL
  expect_error(
    predict(fit, no_ids),
    "non-empty row names"
  )
})

test_that("AUDIT stabl_refit: threshold override is rejected", {
  withr::local_seed(605)
  n <- 12L
  ids <- paste0("s", seq_len(n))
  x <- matrix(
    rnorm(n * 3L),
    nrow = n,
    dimnames = list(ids, paste0("f", seq_len(3L)))
  )
  y <- setNames(rnorm(n), ids)
  selector <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = 0.1),
    family = "gaussian",
    n_bootstraps = 1L,
    artificial_type = NULL,
    hard_threshold = 0.5,
    sample_fraction = 1,
    random_state = 605L
  )

  expect_error(
    stabl_refit(
      selector,
      x = x,
      y = y,
      new_hard_threshold = NA_real_
    ),
    "no longer accepts selector arguments"
  )
})

test_that("AUDIT stabl_refit: binomial refit reports class loss after alignment", {
  x_empty <- matrix(
    numeric(0L),
    nrow = 4L,
    ncol = 0L,
    dimnames = list(paste0("s", seq_len(4L)), character(0L))
  )
  y_one_class <- factor(rep("case", 4L), levels = c("case", "control"))

  expect_error(
    .fit_stabl_final_model(
      x_train_sel = x_empty,
      y_train = y_one_class,
      task_type = "binary"
    ),
    "one observed outcome class after alignment"
  )
})
