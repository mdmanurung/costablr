test_that("stabl_multiomic_train_validate fits each omic and returns selected matrices", {
  set.seed(101)
  n <- 36L

  x_a <- matrix(rnorm(n * 8L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(8L))))
  x_b <- matrix(rnorm(n * 6L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(6L))))

  y <- setNames(0.7 * x_a[, 1L] - 0.5 * x_b[, 2L] + rnorm(n, sd = 0.8), rownames(x_a))
  groups <- setNames(rep(paste0("id", seq_len(n / 3L)), each = 3L), rownames(x_a))

  x_train_list <- list(omic_a = x_a, omic_b = x_b)
  lambda_grid <- data.frame(lambda = c(0.2, 0.1, 0.05))

  fit <- stabl_multiomic_train_validate(
    x_train_list = x_train_list,
    y_train = y,
    lambda_grid = lambda_grid,
    groups_train = groups,
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 6L,
    family = "gaussian",
    random_state = 11L
  )

  expect_s3_class(fit, "stabl_multiomic_fit")
  expect_named(fit$fits, c("omic_a", "omic_b"))
  expect_true(all(vapply(fit$fits, inherits, logical(1L), what = "stabl_fit")))

  expect_named(fit$selected_train, c("omic_a", "omic_b"))
  expect_equal(nrow(fit$selected_train$omic_a), n)
  expect_equal(nrow(fit$selected_train$omic_b), n)

  expect_named(fit$selected_features, c("omic_a", "omic_b"))
  expect_true(all(vapply(fit$selected_features, is.character, logical(1L))))
})

test_that("stabl_multiomic_train_validate errors on misaligned train samples", {
  x_a <- matrix(rnorm(20), nrow = 10,
                dimnames = list(paste0("s", 1:10), paste0("a", 1:2)))
  x_b <- matrix(rnorm(20), nrow = 10,
                dimnames = list(paste0("t", 1:10), paste0("b", 1:2)))
  y <- setNames(rnorm(10), paste0("s", 1:10))

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x_a, omic_b = x_b),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L
    ),
    "Sample mismatch"
  )
})

test_that("stabl_multiomic_train_validate errors on validation omic name mismatch", {
  x <- matrix(rnorm(20), nrow = 10,
              dimnames = list(paste0("s", 1:10), paste0("f", 1:2)))
  y <- setNames(rnorm(10), rownames(x))

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      x_valid_list = list(other_omic = x),
      y_valid = y,
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L
    ),
    "names must match"
  )
})

test_that("stabl_multiomic_train_validate errors on misaligned validation samples", {
  x <- matrix(rnorm(20), nrow = 10,
              dimnames = list(paste0("s", 1:10), paste0("f", 1:2)))
  y <- setNames(rnorm(10), rownames(x))
  y_bad <- setNames(rnorm(10), paste0("v", 1:10))

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      x_valid_list = list(omic_a = x),
      y_valid = y_bad,
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L
    ),
    "Sample mismatch"
  )
})

test_that("stabl_multiomic_train_validate forwards l1_ratio to auto lambda grids", {
  set.seed(131)
  n <- 24L
  ids <- paste0("s", seq_len(n))
  x <- matrix(rnorm(n * 5L), nrow = n,
              dimnames = list(ids, paste0("f", seq_len(5L))))
  y <- setNames(rnorm(n), ids)

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x),
    y_train = y,
    lambda_grid = "auto",
    base_learner = "elastic_net",
    l1_ratio = 0.4,
    n_lambda = 2L,
    artificial_type = NULL,
    hard_threshold = 1,
    n_bootstraps = 2L,
    sample_fraction = 1,
    random_state = 131L
  )

  grid <- fit$fits$omic_a$fitted_lambda_grid
  expect_true("alpha" %in% names(grid))
  expect_equal(unique(grid$alpha), 0.4)
})

test_that("stabl_multiomic_cv returns deterministic fold diagnostics and selected matrices", {
  set.seed(202)
  n <- 18L

  x_a <- matrix(rnorm(n * 6L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(6L))))
  x_b <- matrix(rnorm(n * 5L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(5L))))
  y <- setNames(0.8 * x_a[, 1L] - 0.6 * x_b[, 2L] + rnorm(n, sd = 0.6), rownames(x_a))

  fit <- stabl_multiomic_cv(
    x_list = list(omic_a = x_a, omic_b = x_b),
    y = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1, 0.05)),
    v = 3L,
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 5L,
    random_state = 19L,
    family = "gaussian"
  )

  expect_s3_class(fit, "stabl_multiomic_cv")
  expect_length(fit$folds, 3L)
  expect_named(fit$fold_results, c("Fold1", "Fold2", "Fold3"))
  expect_true(all(vapply(fit$fold_results, inherits, logical(1L), what = "stabl_multiomic_fit")))

  expect_equal(sort(unlist(lapply(fit$folds, `[[`, "valid_ids"))),
               sort(rownames(x_a)))
  expect_equal(nrow(fit$diagnostics), 6L)
  expect_named(fit$diagnostics,
               c("fold", "omic", "n_selected", "threshold", "max_score"))

  fold1 <- fit$fold_results[["Fold1"]]
  expect_named(fold1$selected_valid, c("omic_a", "omic_b"))
  expect_equal(nrow(fold1$selected_valid$omic_a), length(fit$folds[[1L]]$valid_ids))
  expect_equal(nrow(fold1$selected_train$omic_b), length(fit$folds[[1L]]$train_ids))
})

test_that("stabl_multiomic_cv accepts unnamed full-length bootstrap strata", {
  set.seed(232)
  n <- 18L
  ids <- paste0("s", seq_len(n))
  x <- matrix(rnorm(n * 4L), nrow = n,
              dimnames = list(ids, paste0("f", seq_len(4L))))
  y <- setNames(factor(rep(c("A", "B"), each = n / 2L)), ids)
  strata <- rep(c("site1", "site2", "site3"), length.out = n)

  fit_vec <- suppressWarnings(stabl_multiomic_cv(
    x_list = list(omic_a = x),
    y = y,
    lambda_grid = data.frame(lambda = 0.2),
    v = 3L,
    family = "binomial",
    artificial_type = NULL,
    hard_threshold = 1,
    n_bootstraps = 2L,
    sample_fraction = 1,
    bootstrap_strata = strata,
    random_state = 232L
  ))

  fit_df <- suppressWarnings(stabl_multiomic_cv(
    x_list = list(omic_a = x),
    y = y,
    lambda_grid = data.frame(lambda = 0.2),
    v = 3L,
    family = "binomial",
    artificial_type = NULL,
    hard_threshold = 1,
    n_bootstraps = 2L,
    sample_fraction = 1,
    bootstrap_strata = data.frame(site = strata),
    random_state = 233L
  ))

  expect_s3_class(fit_vec, "stabl_multiomic_cv")
  expect_s3_class(fit_df, "stabl_multiomic_cv")
})

test_that("stabl_multiomic_cv rejects wrong-length unnamed bootstrap strata", {
  set.seed(234)
  n <- 18L
  ids <- paste0("s", seq_len(n))
  x <- matrix(rnorm(n * 4L), nrow = n,
              dimnames = list(ids, paste0("f", seq_len(4L))))
  y <- setNames(factor(rep(c("A", "B"), each = n / 2L)), ids)

  expect_error(
    stabl_multiomic_cv(
      x_list = list(omic_a = x),
      y = y,
      lambda_grid = data.frame(lambda = 0.2),
      v = 3L,
      family = "binomial",
      artificial_type = NULL,
      hard_threshold = 1,
      n_bootstraps = 2L,
      sample_fraction = 1,
      bootstrap_strata = c("site1", "site2"),
      random_state = 234L
    ),
    "one value per sample"
  )
})

test_that("stabl_multiomic_cv keeps grouped samples in the same assessment fold", {
  set.seed(303)
  n_groups <- 6L
  reps <- 3L
  n <- n_groups * reps

  x <- matrix(rnorm(n * 4L), nrow = n,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(4L))))
  y <- setNames(rnorm(n), rownames(x))
  groups <- setNames(rep(paste0("id", seq_len(n_groups)), each = reps), rownames(x))

  fit <- stabl_multiomic_cv(
    x_list = list(omic_a = x),
    y = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    v = 3L,
    groups = groups,
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    random_state = 7L,
    family = "gaussian"
  )

  for (fold in fit$folds) {
    valid_groups <- unique(groups[fold$valid_ids])
    group_counts <- table(groups[names(groups) %in% fold$valid_ids])
    expect_true(all(group_counts == reps))
    expect_false(any(groups[fold$train_ids] %in% valid_groups))
  }
})

test_that("stabl_multiomic_cv errors when folds exceed grouped units", {
  x <- matrix(rnorm(24), nrow = 12,
              dimnames = list(paste0("s", 1:12), paste0("f", 1:2)))
  y <- setNames(rnorm(12), rownames(x))
  groups <- setNames(rep(c("g1", "g2", "g3"), each = 4L), rownames(x))

  expect_error(
    stabl_multiomic_cv(
      x_list = list(omic_a = x),
      y = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      v = 4L,
      groups = groups,
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L
    ),
    "number of folds"
  )
})

# ---------------------------------------------------------------------------
# stacked_multi_omic tests
# ---------------------------------------------------------------------------

test_that("stacked_multi_omic returns correct structure for binary task", {
  set.seed(7)
  y <- rep(c(0L, 1L), 10)
  preds <- data.frame(
    omic_a = y + rnorm(20, sd = 0.4),
    omic_b = y + rnorm(20, sd = 1.0)
  )
  res <- stacked_multi_omic(preds, y, task_type = "binary",
                             n_iter = 500L, random_state = 42L)

  expect_named(res, c("predictions", "weights", "score"))
  expect_s3_class(res$predictions, "data.frame")
  expect_true("Stacked Gen. Predictions" %in% names(res$predictions))
  expect_equal(nrow(res$predictions), 20L)
  expect_s3_class(res$weights, "data.frame")
  expect_equal(nrow(res$weights), 2L)
  expect_true(res$score > 0.5)            # should be better than chance
})

test_that("stacked_multi_omic returns correct structure for regression task", {
  set.seed(8)
  n <- 30L
  y <- rnorm(n)
  preds <- data.frame(
    omic_a = y + rnorm(n, sd = 0.3),
    omic_b = y + rnorm(n, sd = 1.2)
  )
  res <- stacked_multi_omic(preds, y, task_type = "regression",
                             n_iter = 500L, random_state = 99L)

  expect_true(res$score > 0)              # positive R² expected
  expect_equal(length(res$weights$Associated_weight), 2L)
})

test_that("stacked_multi_omic is reproducible with random_state", {
  set.seed(1)
  y <- rep(c(0L, 1L), 8)
  preds <- data.frame(a = y + rnorm(16), b = y + rnorm(16))

  r1 <- stacked_multi_omic(preds, y, task_type = "binary",
                            n_iter = 200L, random_state = 77L)
  r2 <- stacked_multi_omic(preds, y, task_type = "binary",
                            n_iter = 200L, random_state = 77L)

  expect_equal(r1$score, r2$score)
  expect_equal(r1$weights, r2$weights)
})

test_that("stacked_multi_omic handles NA predictions per-row", {
  y <- c(0L, 1L, 0L, 1L)
  preds <- data.frame(
    omic_a = c(0.1, 0.9, 0.2, 0.8),
    omic_b = c(NA,  0.8, NA, 0.7)
  )
  res <- stacked_multi_omic(preds, y, task_type = "binary",
                             n_iter = 200L, random_state = 5L)
  # Rows 1 and 3 have NA in omic_b — stacked prediction should still be non-NA
  expect_false(any(is.na(res$predictions[["Stacked Gen. Predictions"]])))
})

test_that("stacked_multi_omic supports multiclass probability stacking", {
  set.seed(9)
  y <- factor(rep(c("A", "B", "C"), each = 5L))
  ids <- paste0("s", seq_along(y))
  make_probs <- function(noise) {
    p <- matrix(0.1, nrow = length(y), ncol = 3L,
                dimnames = list(ids, levels(y)))
    p[cbind(seq_along(y), as.integer(y))] <- 0.8
    p <- p + matrix(stats::runif(length(p), 0, noise), nrow = nrow(p))
    p / rowSums(p)
  }
  preds <- list(omic_a = make_probs(0.05), omic_b = make_probs(0.25))

  res <- stacked_multi_omic(preds, y, task_type = "multiclass",
                            n_iter = 200L, random_state = 9L)

  expect_named(res, c("predictions", "weights", "score", "log_loss", "levels"))
  expect_equal(res$levels, levels(y))
  expect_equal(nrow(res$weights), 2L)
  expect_true(all(paste0("prob_", levels(y)) %in% names(res$predictions)))
  expect_true("predicted_class" %in% names(res$predictions))
  expect_true(is.finite(res$log_loss))
  expect_true(res$log_loss < 1)
})

test_that("stacked_multi_omic errors when multiclass labels are absent from probability columns", {
  y <- factor(c("A", "B", "C"))
  ids <- paste0("s", seq_along(y))
  preds <- list(
    omic_a = matrix(
      c(0.9, 0.1,
        0.2, 0.8,
        0.4, 0.6),
      nrow = length(y),
      byrow = TRUE,
      dimnames = list(ids, c("A", "B"))
    )
  )

  expect_error(
    stacked_multi_omic(preds, y, task_type = "multiclass",
                       n_iter = 5L, random_state = 99L),
    "All multiclass `y` labels must be present"
  )
})

# ---------------------------------------------------------------------------
# Early fusion tests
# ---------------------------------------------------------------------------

test_that("early_fusion = TRUE adds early_fusion field with correct structure", {
  set.seed(21)
  n <- 30L
  x_a <- matrix(rnorm(n * 5L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(5L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))
  y <- setNames(x_a[, 1L] - x_b[, 2L] + rnorm(n), rownames(x_a))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x_a, omic_b = x_b),
    y_train         = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1, 0.05)),
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    family          = "gaussian",
    random_state    = 3L,
    early_fusion    = TRUE
  )

  expect_false(is.null(fit$early_fusion))
  ef <- fit$early_fusion
  expect_named(ef, c("fit", "selected_features", "selected_train", "selected_valid"))
  expect_s3_class(ef$fit, "stabl_fit")
  expect_true(is.character(ef$selected_features))
  # Number of columns in selected_train should equal length of selected_features
  expect_equal(ncol(ef$selected_train), length(ef$selected_features))
  # No validation supplied => selected_valid is NULL
  expect_null(ef$selected_valid)
})

test_that("early_fusion = TRUE with validation populates selected_valid", {
  set.seed(22)
  n_tr <- 24L; n_va <- 12L
  x_a_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("a", seq_len(4L))))
  x_b_tr <- matrix(rnorm(n_tr * 3L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("b", seq_len(3L))))
  x_a_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("a", seq_len(4L))))
  x_b_va <- matrix(rnorm(n_va * 3L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("b", seq_len(3L))))
  y_tr <- setNames(rnorm(n_tr), rownames(x_a_tr))
  y_va <- setNames(rnorm(n_va), rownames(x_a_va))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x_a_tr, omic_b = x_b_tr),
    y_train         = y_tr,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    x_valid_list    = list(omic_a = x_a_va, omic_b = x_b_va),
    y_valid         = y_va,
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    early_fusion    = TRUE,
    random_state    = 4L
  )

  ef <- fit$early_fusion
  expect_false(is.null(ef$selected_valid))
  expect_equal(nrow(ef$selected_valid), n_va)
  expect_equal(ncol(ef$selected_valid), ncol(ef$selected_train))
})

test_that("early_fusion = FALSE leaves early_fusion field NULL", {
  set.seed(23)
  n <- 20L
  x <- matrix(rnorm(n * 4L), nrow = n,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(4L))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x),
    y_train         = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    early_fusion    = FALSE,
    random_state    = 5L
  )

  expect_null(fit$early_fusion)
})

# ---------------------------------------------------------------------------
# Late fusion tests
# ---------------------------------------------------------------------------

test_that("late_fusion = TRUE adds late_fusion field with weights and predictions", {
  set.seed(31)
  n <- 30L
  x_a <- matrix(rnorm(n * 5L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(5L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))
  y_raw <- x_a[, 1L] - x_b[, 2L] + rnorm(n)
  y <- setNames(y_raw, rownames(x_a))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x_a, omic_b = x_b),
    y_train         = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1, 0.05)),
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    family          = "gaussian",
    random_state    = 10L,
    late_fusion     = TRUE,
    n_iter_lf       = 200L
  )

  expect_false(is.null(fit$late_fusion))
  lf <- fit$late_fusion
  expect_named(lf, c("weights", "train_predictions", "valid_predictions", "score"))
  expect_s3_class(lf$weights, "data.frame")
  expect_equal(nrow(lf$weights), 2L)             # one row per omic
  expect_s3_class(lf$train_predictions, "data.frame")
  expect_true("Stacked Gen. Predictions" %in% names(lf$train_predictions))
  expect_null(lf$valid_predictions)              # no validation supplied
})

test_that("late_fusion = TRUE with validation returns valid_predictions vector", {
  set.seed(32)
  n_tr <- 24L; n_va <- 12L
  x_a_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("a", seq_len(4L))))
  x_b_tr <- matrix(rnorm(n_tr * 3L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("b", seq_len(3L))))
  x_a_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("a", seq_len(4L))))
  x_b_va <- matrix(rnorm(n_va * 3L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("b", seq_len(3L))))
  y_tr <- setNames(rnorm(n_tr), rownames(x_a_tr))
  y_va <- setNames(rnorm(n_va), rownames(x_a_va))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x_a_tr, omic_b = x_b_tr),
    y_train         = y_tr,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    x_valid_list    = list(omic_a = x_a_va, omic_b = x_b_va),
    y_valid         = y_va,
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    family          = "gaussian",
    random_state    = 11L,
    late_fusion     = TRUE,
    n_iter_lf       = 200L
  )

  lf <- fit$late_fusion
  expect_false(is.null(lf$valid_predictions))
  expect_equal(length(lf$valid_predictions), n_va)
})

test_that("late_fusion = TRUE supports multinomial probability stacking", {
  set.seed(321)
  n <- 24L
  ids <- paste0("s", seq_len(n))
  y <- setNames(factor(rep(c("A", "B", "C"), each = 8L)), ids)
  signal <- model.matrix(~ y - 1)
  x_a <- matrix(rnorm(n * 6L, sd = 0.2), nrow = n,
                dimnames = list(ids, paste0("a", seq_len(6L))))
  x_b <- matrix(rnorm(n * 5L, sd = 0.2), nrow = n,
                dimnames = list(ids, paste0("b", seq_len(5L))))
  x_a[, 1:3] <- x_a[, 1:3] + signal
  x_b[, 1:3] <- x_b[, 1:3] + signal

  fit <- suppressWarnings(stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = c(0.05, 0.01)),
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 2L,
    sample_fraction = 1,
    family = "multinomial",
    random_state = 321L,
    late_fusion = TRUE,
    n_iter_lf = 100L
  ))

  lf <- fit$late_fusion
  expect_equal(lf$task_type, "multiclass")
  expect_equal(lf$levels, levels(y))
  expect_equal(nrow(lf$weights), 2L)
  expect_true(all(paste0("prob_", levels(y)) %in% names(lf$train_predictions)))
  expect_true("predicted_class" %in% names(lf$train_predictions))
  expect_named(lf$train_metrics,
               c("accuracy", "balanced_error_rate", "per_class_recall",
                 "macro_f1", "confusion"))
  expect_true(is.finite(lf$log_loss))
})

test_that("late_fusion = FALSE leaves late_fusion field NULL", {
  set.seed(33)
  n <- 20L
  x <- matrix(rnorm(n * 4L), nrow = n,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(4L))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x),
    y_train         = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 4L,
    late_fusion     = FALSE,
    random_state    = 6L
  )

  expect_null(fit$late_fusion)
})

test_that("print.stabl_multiomic_fit runs and reports class header", {
  set.seed(34)
  n <- 18L
  x_a <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(4L))))
  x_b <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(3L))))
  y <- setNames(rnorm(n), rownames(x_a))

  fit <- stabl_multiomic_train_validate(
    x_train_list    = list(omic_a = x_a, omic_b = x_b),
    y_train         = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 3L,
    random_state    = 12L
  )

  expect_output(print(fit), "stabl_multiomic_fit")
})

test_that("print.stabl_multiomic_cv runs and reports class header", {
  set.seed(35)
  n <- 18L
  x <- matrix(rnorm(n * 5L), nrow = n,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(5L))))
  y <- setNames(rnorm(n), rownames(x))

  fit <- stabl_multiomic_cv(
    x_list          = list(omic_a = x),
    y               = y,
    lambda_grid     = data.frame(lambda = c(0.2, 0.1)),
    v               = 3L,
    artificial_type = NULL,
    hard_threshold  = 0.3,
    n_bootstraps    = 3L,
    random_state    = 13L
  )

  expect_output(print(fit), "stabl_multiomic_cv")
})

test_that("default multi-omic return structure is unchanged when cooperative_fusion is FALSE", {
  set.seed(36)
  n <- 18L

  x_a <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(4L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))
  y <- setNames(rnorm(n), rownames(x_a))

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    random_state = 14L
  )

  expect_named(
    fit,
    c("fits", "selected_features", "selected_train", "selected_valid",
      "early_fusion", "late_fusion")
  )
  expect_false("cooperative_fusion" %in% names(fit))
})

test_that("cooperative_fusion with cv selection returns a multiview-backed branch", {
  skip_if_not_installed("multiview")

  set.seed(37)
  n <- 18L

  x_a <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(4L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))
  y <- setNames(0.9 * x_a[, 1L] - 0.7 * x_b[, 2L] + rnorm(n, sd = 0.3),
                rownames(x_a))

  fit_1 <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 15L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.3),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  fit_2 <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 15L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.3),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  cf <- fit_1$cooperative_fusion
  expect_s3_class(cf$fit, "cv.multiview")
  expect_equal(cf$selection, "cv")
  expect_equal(cf$selector, "lambda.min")
  expect_equal(length(cf$foldid), n)
  expect_equal(cf$rho, fit_2$cooperative_fusion$rho)
  expect_equal(cf$foldid, fit_2$cooperative_fusion$foldid)
  expect_equal(names(cf$selected_features), c("omic_a", "omic_b"))
  expect_equal(length(cf$train_predictions), n)
})

test_that("cooperative_fusion supports validation-based gaussian tuning", {
  skip_if_not_installed("multiview")

  set.seed(38)
  n_tr <- 18L
  n_va <- 10L

  x_a_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("a", seq_len(4L))))
  x_b_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                   dimnames = list(paste0("tr", seq_len(n_tr)), paste0("b", seq_len(4L))))
  x_a_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("a", seq_len(4L))))
  x_b_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                   dimnames = list(paste0("va", seq_len(n_va)), paste0("b", seq_len(4L))))

  y_tr <- setNames(0.7 * x_a_tr[, 1L] - 0.5 * x_b_tr[, 2L] + rnorm(n_tr, sd = 0.4),
                   rownames(x_a_tr))
  y_va <- setNames(0.7 * x_a_va[, 1L] - 0.5 * x_b_va[, 2L] + rnorm(n_va, sd = 0.4),
                   rownames(x_a_va))

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a_tr, omic_b = x_b_tr),
    y_train = y_tr,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    x_valid_list = list(omic_a = x_a_va, omic_b = x_b_va),
    y_valid = y_va,
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 16L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.2),
    cooperation_selection = "validation",
    cooperation_selector = "lambda.min"
  )

  cf <- fit$cooperative_fusion
  expect_s3_class(cf$fit, "multiview")
  expect_equal(cf$selection, "validation")
  expect_equal(cf$selector, "lambda.min")
  expect_equal(length(cf$valid_predictions), n_va)
  expect_equal(sum(cf$diagnostics$selected), 1L)
  expect_true(nrow(cf$diagnostics) >= length(cf$rho_grid))
})

test_that("cooperative_fusion supports binomial, poisson, and cox families", {
  skip_if_not_installed("multiview")
  skip_if_not_installed("survival")

  set.seed(39)
  n <- 20L
  x_a <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(4L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))

  y_bin <- setNames(rbinom(n, size = 1L, prob = plogis(0.9 * x_a[, 1L] - 0.8 * x_b[, 2L])),
                    rownames(x_a))
  fit_bin <- suppressWarnings(stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y_bin,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "binomial",
    random_state = 17L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.3),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.1se",
    cooperation_nfolds = 3L
  ))

  y_pois <- setNames(rpois(n, lambda = exp(0.2 + 0.4 * x_a[, 1L] - 0.2 * x_b[, 1L])),
                     rownames(x_a))
  fit_pois <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y_pois,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "poisson",
    random_state = 18L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.2),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  y_cox <- survival::Surv(
    time = rexp(n, rate = exp(0.3 + 0.2 * x_a[, 1L] - 0.2 * x_b[, 2L])),
    event = rbinom(n, size = 1L, prob = 0.7)
  )
  rownames(y_cox) <- rownames(x_a)
  fit_cox <- suppressWarnings(stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y_cox,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = "random_permutation",
    n_bootstraps = 3L,
    family = "cox",
    random_state = 19L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.2),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  ))

  expect_s3_class(fit_bin$cooperative_fusion$fit, "cv.multiview")
  expect_equal(fit_bin$cooperative_fusion$selector, "lambda.1se")
  expect_s3_class(fit_pois$cooperative_fusion$fit, "cv.multiview")
  expect_equal(length(fit_pois$cooperative_fusion$train_predictions), n)
  expect_s3_class(fit_cox$cooperative_fusion$fit, "cv.multiview")
  expect_equal(length(fit_cox$cooperative_fusion$train_predictions), n)
})

test_that("cooperative_fusion rejects unsupported selection combinations", {
  skip_if_not_installed("multiview")

  set.seed(40)
  n <- 12L
  x <- matrix(rnorm(n * 3L), nrow = n,
              dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(3L))))
  y <- setNames(rnorm(n), rownames(x))

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L,
      cooperative_fusion = TRUE,
      rho = c(0, 0.2)
    ),
    "at least two omic views"
  )

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x, omic_b = x),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      x_valid_list = list(omic_a = x, omic_b = x),
      y_valid = y,
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L,
      cooperative_fusion = TRUE,
      rho = c(0, 0.2),
      cooperation_selection = "validation",
      cooperation_selector = "lambda.1se"
    ),
    "lambda.1se"
  )
})

test_that("cooperative_fusion rejects multinomial family", {
  set.seed(401)
  n <- 18L
  ids <- paste0("s", seq_len(n))
  x_a <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("a", seq_len(3L))))
  x_b <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("b", seq_len(3L))))
  y <- setNames(factor(rep(c("A", "B", "C"), each = 6L)), ids)

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x_a, omic_b = x_b),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L,
      family = "multinomial",
      cooperative_fusion = TRUE,
      rho = c(0, 0.2)
    ),
    "supports family"
  )
})

test_that("stabl_multiomic_cv adds cooperative diagnostics when enabled", {
  skip_if_not_installed("multiview")

  set.seed(41)
  n <- 18L
  x_a <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("a", seq_len(4L))))
  x_b <- matrix(rnorm(n * 4L), nrow = n,
                dimnames = list(paste0("s", seq_len(n)), paste0("b", seq_len(4L))))
  y <- setNames(0.8 * x_a[, 1L] - 0.4 * x_b[, 2L] + rnorm(n, sd = 0.4),
                rownames(x_a))

  fit <- stabl_multiomic_cv(
    x_list = list(omic_a = x_a, omic_b = x_b),
    y = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    v = 3L,
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    random_state = 20L,
    family = "gaussian",
    cooperative_fusion = TRUE,
    rho = c(0, 0.2),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  expect_true(all(c(
    "cooperative_rho", "cooperative_lambda", "cooperative_selection",
    "cooperative_selector", "cooperative_type_measure",
    "cooperative_score", "cooperative_prediction_type",
    "cooperative_n_selected"
  ) %in% names(fit$diagnostics)))
  expect_equal(nrow(fit$diagnostics), 6L)
})

# ---------------------------------------------------------------------------
# Cooperative fusion: behavior-level hardening (MultiViewPlan CF-2)
# ---------------------------------------------------------------------------

.cf_make_two_omic <- function(n, p_a = 4L, p_b = 4L, seed) {
  set.seed(seed)
  ids <- paste0("s", seq_len(n))
  x_a <- matrix(rnorm(n * p_a), nrow = n,
                dimnames = list(ids, paste0("a", seq_len(p_a))))
  x_b <- matrix(rnorm(n * p_b), nrow = n,
                dimnames = list(ids, paste0("b", seq_len(p_b))))
  y <- setNames(0.9 * x_a[, 1L] - 0.7 * x_b[, 2L] + rnorm(n, sd = 0.3), ids)
  list(x_a = x_a, x_b = x_b, y = y)
}

test_that("cooperative_fusion: rho > 0 alters selection vs rho = 0 (gaussian, cv)", {
  skip_if_not_installed("multiview")

  d <- .cf_make_two_omic(n = 30L, seed = 100L)

  call_with_rho <- function(rho_value) {
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = d$x_a, omic_b = d$x_b),
      y_train = d$y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 3L,
      family = "gaussian",
      random_state = 100L,
      cooperative_fusion = TRUE,
      rho = rho_value,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds = 3L
    )
  }

  fit_rho0 <- call_with_rho(0)
  fit_rho_pos <- call_with_rho(0.5)

  cf_zero <- fit_rho0$cooperative_fusion
  cf_pos <- fit_rho_pos$cooperative_fusion

  expect_equal(cf_zero$rho, 0)
  expect_equal(cf_pos$rho, 0.5)

  differs <-
    !identical(cf_zero$selected_features, cf_pos$selected_features) ||
    !isTRUE(all.equal(cf_zero$selected_lambda, cf_pos$selected_lambda)) ||
    !isTRUE(all.equal(unname(cf_zero$train_predictions),
                      unname(cf_pos$train_predictions)))
  expect_true(differs,
              info = "rho=0 and rho=0.5 should not yield identical cooperative output")
})

test_that("cooperative_fusion: cooperative selections differ from per-omic and early fusion", {
  skip_if_not_installed("multiview")

  d <- .cf_make_two_omic(n = 30L, seed = 101L)

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = d$x_a, omic_b = d$x_b),
    y_train = d$y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 101L,
    early_fusion = TRUE,
    cooperative_fusion = TRUE,
    rho = c(0, 0.4),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  cf <- fit$cooperative_fusion
  ef_features <- fit$early_fusion$selected_features
  per_omic_union <- unique(unlist(fit$selected_features, use.names = FALSE))
  cf_union <- unique(unlist(cf$selected_features, use.names = FALSE))

  expect_false(is.null(cf$fit))
  expect_false(is.null(fit$early_fusion$fit))
  # Cooperative selection should not be exactly identical to early fusion or
  # to the per-omic union; coupling changes the candidate set.
  expect_false(setequal(cf_union, ef_features) &&
               setequal(cf_union, per_omic_union),
               info = "cooperative, early, and per-omic should not all coincide")
})

test_that("cooperative_fusion rejects cox + validation selection", {
  skip_if_not_installed("multiview")
  skip_if_not_installed("survival")

  set.seed(114L)
  n <- 14L
  ids <- paste0("s", seq_len(n))
  x_a <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("a", seq_len(3L))))
  x_b <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("b", seq_len(3L))))
  y <- survival::Surv(time = rexp(n, rate = 1), event = rbinom(n, 1L, 0.7))
  rownames(y) <- ids

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = x_a, omic_b = x_b),
      y_train = y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      x_valid_list = list(omic_a = x_a, omic_b = x_b),
      y_valid = y,
      artificial_type = NULL,
      n_bootstraps = 2L,
      family = "cox",
      random_state = 114L,
      cooperative_fusion = TRUE,
      rho = c(0, 0.2),
      cooperation_selection = "validation",
      cooperation_selector = "lambda.min"
    ),
    regexp = "cox.*validation|validation.*cox",
    perl = TRUE
  )
})

test_that("cooperative_fusion fails cleanly when multiview is unavailable", {
  d <- .cf_make_two_omic(n = 12L, seed = 130L)

  testthat::local_mocked_bindings(
    .has_multiview = function() FALSE,
    .package = "stablr"
  )

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list = list(omic_a = d$x_a, omic_b = d$x_b),
      y_train = d$y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1)),
      artificial_type = NULL,
      hard_threshold = 0.3,
      n_bootstraps = 2L,
      family = "gaussian",
      cooperative_fusion = TRUE,
      rho = 0
    ),
    regexp = "multiview"
  )
})

# ---------------------------------------------------------------------------
# Cooperative fusion: print/summary ergonomics
# ---------------------------------------------------------------------------

test_that("print.stabl_multiomic_fit reports cooperative fusion when present", {
  skip_if_not_installed("multiview")

  d <- .cf_make_two_omic(n = 18L, seed = 200L)

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = d$x_a, omic_b = d$x_b),
    y_train = d$y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 200L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.3),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.min",
    cooperation_nfolds = 3L
  )

  out <- capture.output(print(fit))
  expect_true(any(grepl("Cooperative fusion", out)),
              info = "print output should include 'Cooperative fusion' header")
  expect_true(any(grepl("rho", out, ignore.case = TRUE)),
              info = "print output should mention rho")
  expect_true(any(grepl("lambda.min|selector", out, ignore.case = TRUE)),
              info = "print output should mention selector")
})

test_that("print.stabl_multiomic_fit omits cooperative line when branch absent", {
  set.seed(201L)
  n <- 14L
  ids <- paste0("s", seq_len(n))
  x_a <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("a", seq_len(3L))))
  x_b <- matrix(rnorm(n * 3L), nrow = n,
                dimnames = list(ids, paste0("b", seq_len(3L))))
  y <- setNames(rnorm(n), ids)

  fit <- stabl_multiomic_train_validate(
    x_train_list = list(omic_a = x_a, omic_b = x_b),
    y_train = y,
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    artificial_type = NULL,
    hard_threshold = 0.3,
    n_bootstraps = 3L,
    family = "gaussian",
    random_state = 201L
  )

  out <- capture.output(print(fit))
  expect_false(any(grepl("Cooperative fusion", out)),
               info = "print should not mention cooperative fusion when branch is NULL")
})

test_that("cooperative accessors expose selected features and diagnostics", {
  diagnostics <- data.frame(
    rho = c(0, 0.3),
    lambda = c(0.12, 0.08),
    metric_value = c(0.4, 0.2),
    selected = c(FALSE, TRUE)
  )
  fit <- structure(
    list(
      fits = list(omic_a = NULL, omic_b = NULL),
      selected_features = list(omic_a = character(0), omic_b = character(0)),
      selected_train = list(omic_a = matrix(nrow = 0, ncol = 0),
                            omic_b = matrix(nrow = 0, ncol = 0)),
      selected_valid = NULL,
      early_fusion = NULL,
      late_fusion = NULL,
      cooperative_fusion = list(
        selected_features = list(omic_a = c("a1", "a3"), omic_b = "b2"),
        diagnostics = diagnostics
      )
    ),
    class = "stabl_multiomic_fit"
  )

  expect_equal(
    get_cooperative_features(fit),
    list(omic_a = c("a1", "a3"), omic_b = "b2")
  )
  expect_equal(get_cooperative_features(fit, view = "omic_b"), "b2")
  expect_equal(get_cooperative_diagnostics(fit), diagnostics)
  expect_error(get_cooperative_features(fit, view = "missing"), "view")
})

test_that("cooperative accessors fail clearly when branch is absent", {
  fit <- structure(
    list(
      fits = list(omic_a = NULL),
      selected_features = list(omic_a = character(0)),
      selected_train = list(omic_a = matrix(nrow = 0, ncol = 0)),
      selected_valid = NULL,
      early_fusion = NULL,
      late_fusion = NULL
    ),
    class = "stabl_multiomic_fit"
  )

  expect_error(get_cooperative_features(fit), "cooperative_fusion = TRUE")
  expect_error(get_cooperative_diagnostics(fit), "cooperative_fusion = TRUE")
})

test_that("cooperative accessors support multiomic cv objects", {
  fold_fit <- structure(
    list(
      fits = list(omic_a = NULL, omic_b = NULL),
      selected_features = list(omic_a = character(0), omic_b = character(0)),
      selected_train = list(omic_a = matrix(nrow = 0, ncol = 0),
                            omic_b = matrix(nrow = 0, ncol = 0)),
      selected_valid = NULL,
      early_fusion = NULL,
      late_fusion = NULL,
      cooperative_fusion = list(
        selected_features = list(omic_a = "a1", omic_b = character(0)),
        diagnostics = data.frame(rho = 0, lambda = 0.1, metric_value = 0.2,
                                 selected = TRUE)
      )
    ),
    class = "stabl_multiomic_fit"
  )
  cv <- structure(
    list(
      folds = list(list(fold = "Fold1")),
      fold_results = list(Fold1 = fold_fit),
      diagnostics = data.frame(
        fold = "Fold1",
        omic = c("omic_a", "omic_b"),
        n_selected = c(1L, 0L),
        threshold = c(0.3, 0.3),
        max_score = c(0.5, 0.1),
        cooperative_rho = c(0, 0),
        cooperative_lambda = c(0.1, 0.1),
        cooperative_score = c(0.2, 0.2)
      )
    ),
    class = "stabl_multiomic_cv"
  )

  expect_equal(get_cooperative_features(cv), list(Fold1 = list(
    omic_a = "a1",
    omic_b = character(0)
  )))
  expect_named(
    get_cooperative_diagnostics(cv),
    c("fold", "omic", "cooperative_rho", "cooperative_lambda",
      "cooperative_score")
  )
})
