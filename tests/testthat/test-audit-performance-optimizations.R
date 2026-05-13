test_that("PERF-001 stacking refactor preserves binary and regression outputs", {
  set.seed(101)
  n <- 80L
  predictions <- matrix(rnorm(n * 5L), nrow = n)
  predictions[sample(length(predictions), 35L)] <- NA_real_
  dimnames(predictions) <- list(paste0("s", seq_len(n)), paste0("omic", seq_len(5L)))

  y_binary <- as.integer(rnorm(n) + predictions[, 1L] > 0)
  y_regression <- 0.4 * predictions[, 2L] - 0.2 * predictions[, 3L] + rnorm(n)
  y_regression[is.na(y_regression)] <- rnorm(sum(is.na(y_regression)))

  old_seed <- .Random.seed
  old_bin <- .old_stacked_multi_omic(predictions, y_binary, "binary",
                                     n_iter = 175L, random_state = 7L)
  expect_identical(.Random.seed, old_seed)
  new_bin <- stacked_multi_omic(predictions, y_binary, "binary",
                                n_iter = 175L, random_state = 7L)
  expect_identical(.Random.seed, old_seed)

  expect_equal(new_bin$weights, old_bin$weights, tolerance = 1e-12)
  expect_equal(new_bin$score, old_bin$score, tolerance = 1e-12)
  expect_equal(new_bin$predictions, old_bin$predictions, tolerance = 1e-12)

  old_reg <- .old_stacked_multi_omic(predictions, y_regression, "regression",
                                     n_iter = 175L, random_state = 8L)
  new_reg <- stacked_multi_omic(predictions, y_regression, "regression",
                                n_iter = 175L, random_state = 8L)

  expect_equal(new_reg$weights, old_reg$weights, tolerance = 1e-12)
  expect_equal(new_reg$score, old_reg$score, tolerance = 1e-12)
  expect_equal(new_reg$predictions, old_reg$predictions, tolerance = 1e-12)
})

test_that("PERF-002 multiclass stacking refactor preserves probabilities and labels", {
  set.seed(202)
  n <- 64L
  classes <- c("A", "B", "C", "D")
  make_probs <- function() {
    raw <- matrix(stats::runif(n * length(classes)), nrow = n)
    raw <- raw / rowSums(raw)
    dimnames(raw) <- list(paste0("s", seq_len(n)), classes)
    raw
  }
  predictions <- list(omic_a = make_probs(), omic_b = make_probs(),
                      omic_c = make_probs(), omic_d = make_probs())
  predictions$omic_b[c(2L, 17L), ] <- NA_real_
  predictions$omic_d[33L, 3L] <- NA_real_
  y <- sample(classes, n, replace = TRUE)

  old <- .old_stacked_multi_omic(predictions, y, "multiclass",
                                 n_iter = 150L, random_state = 19L)
  new <- stacked_multi_omic(predictions, y, "multiclass",
                            n_iter = 150L, random_state = 19L)

  expect_equal(new$weights, old$weights, tolerance = 1e-12)
  expect_equal(new$score, old$score, tolerance = 1e-12)
  expect_equal(new$log_loss, old$log_loss, tolerance = 1e-12)
  expect_equal(new$levels, old$levels)
  expect_equal(names(new$predictions), names(old$predictions))
  expect_equal(new$predictions, old$predictions, tolerance = 1e-12)
})

test_that("PERF-003 glmnet batch coefficient extraction matches per-lambda reference", {
  set.seed(303)
  n <- 45L
  p <- 12L
  x <- matrix(rnorm(n * p), nrow = n)
  y_gaussian <- rnorm(n)
  y_binomial <- factor(sample(c(0L, 1L), n, replace = TRUE))
  y_multinomial <- factor(sample(c("A", "B", "C"), n, replace = TRUE))
  pick_lambda <- function(lambda, n_pick = 4L) {
    lambda[unique(round(seq(1L, length(lambda), length.out = min(n_pick, length(lambda)))))]
  }

  fit_g <- glmnet::glmnet(x, y_gaussian, family = "gaussian", nlambda = 8L)
  lambda_g <- pick_lambda(fit_g$lambda, 4L)
  expect_equal(
    costablr:::.feature_abs_coefs_batch(fit_g, lambda_g, family = "gaussian"),
    .old_feature_abs_coefs_batch(fit_g, lambda_g, family = "gaussian"),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )

  fit_b <- suppressWarnings(glmnet::glmnet(x, y_binomial, family = "binomial", nlambda = 8L))
  lambda_b <- pick_lambda(fit_b$lambda, 3L)
  expect_equal(
    costablr:::.feature_abs_coefs_batch(fit_b, lambda_b, family = "binomial"),
    .old_feature_abs_coefs_batch(fit_b, lambda_b, family = "binomial"),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )

  fit_m <- suppressWarnings(glmnet::glmnet(x, y_multinomial, family = "multinomial", nlambda = 8L))
  lambda_m <- pick_lambda(fit_m$lambda, 3L)
  expect_equal(
    costablr:::.feature_abs_coefs_batch(fit_m, lambda_m, family = "multinomial"),
    .old_feature_abs_coefs_batch(fit_m, lambda_m, family = "multinomial"),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )
})

test_that("PERF-003 Cox and sparsegl coefficient fallbacks preserve shape and values", {
  skip_if_not_installed("survival")

  set.seed(304)
  n <- 50L
  p <- 10L
  x <- matrix(rnorm(n * p), nrow = n)
  y_cox <- survival::Surv(rexp(n, rate = 0.1), sample(0:1, n, replace = TRUE))
  pick_lambda <- function(lambda, n_pick = 3L) {
    lambda[unique(round(seq(1L, length(lambda), length.out = min(n_pick, length(lambda)))))]
  }

  fit_c <- glmnet::glmnet(x, y_cox, family = "cox", nlambda = 7L)
  lambda_c <- pick_lambda(fit_c$lambda, 3L)
  expect_equal(
    costablr:::.feature_abs_coefs_batch(fit_c, lambda_c, family = "cox"),
    .old_feature_abs_coefs_batch(fit_c, lambda_c, family = "cox"),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )

  skip_if_not_installed("sparsegl")
  groups <- rep(seq_len(5L), each = 2L)
  fit_s <- sparsegl::sparsegl(x = x, y = rnorm(n), group = groups,
                              family = "gaussian", nlambda = 7L)
  lambda_s <- pick_lambda(fit_s$lambda, 3L)
  expect_equal(
    costablr:::.feature_abs_coefs_sparsegl_batch(fit_s, lambda_s),
    .old_feature_abs_coefs_sparsegl_batch(fit_s, lambda_s),
    tolerance = 1e-12,
    ignore_attr = TRUE
  )
})

test_that("PERF-005 grouped bootstrap refactor preserves sampled indices exactly", {
  groups <- rep(paste0("id", seq_len(12L)), times = rep(c(2L, 3L, 4L), 4L))
  y <- rep(c("A", "B"), length.out = length(groups))

  for (seed in c(1L, 7L, 19L, 101L)) {
    expect_identical(
      group_bootstrap_indices(y, groups, n_subsamples = 18L,
                              replace = FALSE, seed = seed),
      .old_group_bootstrap_indices(y, groups, n_subsamples = 18L,
                                   replace = FALSE, seed = seed)
    )
    expect_identical(
      group_bootstrap_indices(y, groups, n_subsamples = 25L,
                              replace = TRUE, seed = seed),
      .old_group_bootstrap_indices(y, groups, n_subsamples = 25L,
                                   replace = TRUE, seed = seed)
    )
  }

  strata <- rep(c("S1", "S2"), each = length(groups) / 2L)
  groups_strat <- rep(paste0("g", seq_len(length(groups) / 2L)), each = 2L)
  y_strat <- strata
  for (seed in c(3L, 9L, 27L)) {
    expect_identical(
      group_bootstrap_indices(y_strat, groups_strat, n_subsamples = 18L,
                              replace = FALSE, strata = strata, seed = seed),
      .old_group_bootstrap_indices(y_strat, groups_strat, n_subsamples = 18L,
                                   replace = FALSE, strata = strata, seed = seed)
    )
  }
})

test_that("PERF-005 prepared grouped sampler matches old repeated draws", {
  groups <- rep(paste0("id", seq_len(30L)), each = 3L)
  y <- rep(c("case", "control"), length.out = length(groups))
  old_draws <- vector("list", 20L)
  new_draws <- vector("list", 20L)

  set.seed(505)
  for (i in seq_along(old_draws)) {
    old_draws[[i]] <- .old_group_bootstrap_indices(
      y, groups, n_subsamples = 45L, replace = FALSE
    )
  }

  set.seed(505)
  sampler <- costablr:::.make_group_bootstrap_sampler(
    y = y,
    groups = groups,
    n_subsamples = 45L,
    replace = FALSE
  )
  for (i in seq_along(new_draws)) {
    new_draws[[i]] <- sampler()
  }

  expect_identical(new_draws, old_draws)
})

test_that("PERF-006 correlation grouping and noise append preserve partitions", {
  set.seed(606)
  n <- 70L
  block <- matrix(rnorm(n * 4L), nrow = n)
  x <- cbind(
    block,
    block[, 1L:2L, drop = FALSE] + matrix(rnorm(n * 2L, sd = 0.01), nrow = n),
    matrix(rnorm(n * 5L), nrow = n)
  )
  x[1:5, 3L] <- NA_real_
  x[, 11L] <- 1

  for (threshold in c(50, 90, 100)) {
    old_groups <- .old_build_corr_groups(x, threshold)
    new_groups <- costablr:::.build_corr_groups(x, threshold)
    expect_true(all(.same_partition(old_groups, new_groups)))
  }

  groups <- c(1L, 1L, 2L, 3L)
  noise <- c(2L, 99L, NA_integer_, 3L)
  expect_identical(
    costablr:::.append_noise_groups(groups, noise, total_p = 8L),
    .old_append_noise_groups(groups, noise, total_p = 8L)
  )
})
