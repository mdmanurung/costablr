test_that("stabl_fit sequential and furrr paths remain identical", {
  skip_if_not_installed("furrr")
  skip_if_not_installed("future")

  withr::local_seed(501)
  n <- 40L
  p <- 6L
  x <- matrix(
    rnorm(n * p),
    nrow = n,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))
  lambda_grid <- data.frame(lambda = c(0.25, 0.1))

  fit_seq <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = lambda_grid,
    family = "gaussian",
    n_bootstraps = 8L,
    artificial_type = "random_permutation",
    random_state = 19L,
    workers = 1L
  )

  fit_par <- suppressWarnings(stabl_fit(
    x = x,
    y = y,
    lambda_grid = lambda_grid,
    family = "gaussian",
    n_bootstraps = 8L,
    artificial_type = "random_permutation",
    random_state = 19L,
    workers = 2L
  ))

  expect_equal(fit_seq$stabl_scores_, fit_par$stabl_scores_, tolerance = 0)
  expect_equal(
    fit_seq$stabl_scores_artificial_,
    fit_par$stabl_scores_artificial_,
    tolerance = 0
  )
})

test_that("nested CV sequential and cv_workers paths remain identical", {
  withr::local_seed(502)
  n <- 16L
  ids <- paste0("s", seq_len(n))
  y <- setNames(factor(rep(c("A", "B"), each = n / 2L)), ids)
  signal <- ifelse(y == "B", 1, -1)
  x_a <- matrix(
    rnorm(n * 4L, sd = 0.2),
    nrow = n,
    dimnames = list(ids, paste0("a", seq_len(4L)))
  )
  x_b <- matrix(
    rnorm(n * 3L, sd = 0.2),
    nrow = n,
    dimnames = list(ids, paste0("b", seq_len(3L)))
  )
  x_a[, 1L] <- x_a[, 1L] + signal
  x_b[, 1L] <- x_b[, 1L] + signal

  common_args <- list(
    x_list = list(mrna = x_a, mirna = x_b),
    y = y,
    candidates = list(list(name = "mrna", blocks = "mrna")),
    lambda_grid = data.frame(lambda = c(0.2, 0.1)),
    outer_v = 2L,
    outer_repeats = 1L,
    inner_v = 2L,
    metric = "ber",
    family = "binomial",
    artificial_type = NULL,
    hard_threshold = 1e-9,
    n_bootstraps = 2L,
    sample_fraction = 1.0,
    random_state = 23L,
    workers = 1L
  )

  fit_seq <- suppressWarnings(do.call(
    stabl_multiomic_nested_cv,
    c(common_args, list(cv_workers = 1L))
  ))
  fit_par <- suppressWarnings(do.call(
    stabl_multiomic_nested_cv,
    c(common_args, list(cv_workers = 2L))
  ))

  expect_equal(fit_seq$outer_predictions, fit_par$outer_predictions)
  expect_equal(fit_seq$diagnostics, fit_par$diagnostics)
  expect_equal(fit_seq$performance$accuracy, fit_par$performance$accuracy)
  expect_equal(
    fit_seq$performance$balanced_error_rate,
    fit_par$performance$balanced_error_rate
  )
})
