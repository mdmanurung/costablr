# Native cooperative-learning parity against frozen reference fixtures.

.cf_parity_data <- function(n = 40L, seed = 42L) {
  set.seed(seed)
  ids <- paste0("s", seq_len(n))
  x_a <- matrix(
    rnorm(n * 5L), nrow = n,
    dimnames = list(ids, paste0("a", seq_len(5L)))
  )
  x_b <- matrix(
    rnorm(n * 5L), nrow = n,
    dimnames = list(ids, paste0("b", seq_len(5L)))
  )
  y <- setNames(0.8 * x_a[, 1L] - 0.6 * x_b[, 2L] + rnorm(n, sd = 0.2), ids)
  list(x_list = list(omic_a = x_a, omic_b = x_b), y = y)
}

test_that("native cooperative gaussian CV matches frozen parity fixtures", {
  d <- .cf_parity_data()
  foldid <- rep(1:3, length.out = nrow(d$x_list[[1L]]))

  for (rho in c(0, 0.3, 0.5)) {
    ref_path <- testthat::test_path(
      "fixtures", "cooperative_parity",
      sprintf("gaussian_rho_%s.rds", gsub("\\.", "_", as.character(rho)))
    )
    ref <- readRDS(ref_path)

    fit <- stablr:::.cooperative_backend_cv(
      d$x_list,
      d$y,
      family = "gaussian",
      rho = rho,
      foldid = foldid,
      nfolds = 3L,
      type.measure = "mse"
    )

    expect_equal(fit$lambda.min, ref$lambda.min, tolerance = 1e-5)
    expect_equal(fit$lambda.1se, ref$lambda.1se, tolerance = 1e-5)
    expect_equal(fit$cvm, ref$cvm, tolerance = 1e-5)

    coef_table <- stablr:::.cooperative_coefficient_table(fit, s = "lambda.min")
    selected <- stablr:::.cooperative_selected_features(coef_table, names(d$x_list))
    expect_equal(selected, ref$selected_features)
  }
})

test_that("native cooperative binomial CV matches frozen parity fixture", {
  d <- .cf_parity_data()
  foldid <- rep(1:3, length.out = nrow(d$x_list[[1L]]))
  y_bin <- as.integer(d$y > median(d$y))
  names(y_bin) <- names(d$y)

  ref <- readRDS(testthat::test_path(
    "fixtures", "cooperative_parity", "binomial_rho_0_4.rds"
  ))

  fit <- stablr:::.cooperative_backend_cv(
    d$x_list,
    y_bin,
    family = "binomial",
    rho = 0.4,
    foldid = foldid,
    nfolds = 3L,
    type.measure = "deviance"
  )

  expect_equal(fit$lambda.min, ref$lambda.min, tolerance = 1e-5)
  expect_equal(fit$lambda.1se, ref$lambda.1se, tolerance = 1e-5)
  expect_equal(fit$cvm, ref$cvm, tolerance = 1e-5)
})

test_that(".mv_multiview rejects non-scalar rho", {
  d <- .cf_parity_data(n = 20L)
  expect_error(
    stablr:::.mv_multiview(d$x_list, d$y, rho = c(0.3, 0.5)),
    "rho must be a scalar"
  )
})

test_that("plot.multiview runs on a native cooperative fit", {
  d <- .cf_parity_data(n = 30L)
  fit <- stablr:::.cooperative_backend_fit(
    d$x_list,
    d$y,
    family = "gaussian",
    rho = 0.3
  )
  expect_s3_class(fit, "multiview")
  # Redirect base-graphics output to a temp file so no Rplots.pdf is created.
  withr::local_pdf(tempfile(fileext = ".pdf"))
  expect_no_error(suppressMessages(plot(fit)))
})

test_that("native cooperative backend is always available", {
  expect_true(stablr:::.has_cooperative_backend())
})

test_that("optional CRAN multiview parity when installed", {
  skip_if_not_installed("multiview")

  d <- .cf_parity_data()
  foldid <- rep(1:3, length.out = nrow(d$x_list[[1L]]))

  native <- stablr:::.cooperative_backend_cv(
    d$x_list, d$y, family = "gaussian", rho = 0.3,
    foldid = foldid, nfolds = 3L, type.measure = "mse"
  )
  external <- multiview::cv.multiview(
    d$x_list, d$y, family = gaussian(), rho = 0.3,
    foldid = foldid, nfolds = 3L, type.measure = "mse"
  )

  expect_equal(native$lambda.min, external$lambda.min, tolerance = 1e-5)
  expect_equal(native$cvm, external$cvm, tolerance = 1e-5)
})
