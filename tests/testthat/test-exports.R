# tests for exports.R — CSV and disk export helpers

skip_if_not_installed("ggplot2")

# ── Shared fixture ────────────────────────────────────────────────────────────

.make_export_fit <- function(seed = 42L) {
  withr::local_seed(seed)
  n <- 30L; p <- 8L
  x <- matrix(
    rnorm(n * p), n, p,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(sample(0:1, n, replace = TRUE), rownames(x))
  lam <- data.frame(lambda = seq(0.05, 0.5, length.out = 5L))
  list(
    fit = suppressWarnings(stabl_fit(
      x               = x,
      y               = y,
      lambda_grid     = lam,
      family          = "binomial",
      n_bootstraps    = 20L,
      artificial_type = "random_permutation"
    )),
    x = x,
    y = y
  )
}

# ── export_stabl_to_csv ───────────────────────────────────────────────────────

test_that("export_stabl_to_csv creates expected CSV files", {
  d <- .make_export_fit()
  tmp <- withr::local_tempdir()
  export_stabl_to_csv(d$fit, tmp)

  expect_true(file.exists(file.path(tmp, "STABL scores.csv")))
  expect_true(file.exists(file.path(tmp, "Max STABL scores.csv")))
  # Artificial features were used, so artificial score files should exist
  expect_true(file.exists(file.path(tmp, "STABL artificial scores.csv")))
  expect_true(file.exists(file.path(tmp, "Max STABL artificial scores.csv")))
})

test_that("export_stabl_to_csv CSV has correct row count", {
  d <- .make_export_fit()
  tmp <- withr::local_tempdir()
  export_stabl_to_csv(d$fit, tmp)

  scores_csv <- utils::read.csv(file.path(tmp, "STABL scores.csv"),
                                 row.names = 1L)
  # Rows = number of features; cols = number of lambda values
  expect_equal(nrow(scores_csv), d$fit$n_features_in_)
  expect_equal(ncol(scores_csv), ncol(d$fit$stabl_scores_))
})

test_that("export_stabl_to_csv creates directory if it does not exist", {
  d <- .make_export_fit()
  tmp <- withr::local_tempdir()
  new_dir <- file.path(tmp, "new_subdir")
  expect_false(dir.exists(new_dir))
  export_stabl_to_csv(d$fit, new_dir)
  expect_true(dir.exists(new_dir))
})

test_that("export_stabl_to_csv rejects non-character path", {
  d <- .make_export_fit()
  expect_error(export_stabl_to_csv(d$fit, 123L), "`path`")
})

# ── save_stabl_results ────────────────────────────────────────────────────────

test_that("save_stabl_results creates output directory with expected files", {
  d <- .make_export_fit()
  tmp  <- withr::local_tempdir()
  dest <- file.path(tmp, "results")

  suppressWarnings(
    save_stabl_results(
      object    = d$fit,
      path      = dest,
      x         = d$x,
      y         = d$y,
      figure_fmt = "png",
      task_type  = "binary"
    )
  )

  expect_true(dir.exists(dest))
  expect_true(file.exists(file.path(dest, "STABL scores.csv")))
  expect_true(file.exists(file.path(dest, "Stability Path.png")))
  expect_true(dir.exists(file.path(dest, "Selected Features")))
  expect_true(file.exists(
    file.path(dest, "Selected Features", "Selected features.csv")
  ))
})

test_that("save_stabl_results errors if directory exists and override = FALSE", {
  d <- .make_export_fit()
  tmp  <- withr::local_tempdir()
  dest <- file.path(tmp, "already_there")
  dir.create(dest)

  expect_error(
    save_stabl_results(d$fit, dest, d$x, d$y),
    "already exists"
  )
})

test_that("save_stabl_results succeeds if directory exists and override = TRUE", {
  d <- .make_export_fit()
  tmp  <- withr::local_tempdir()
  dest <- file.path(tmp, "will_override")
  dir.create(dest)

  expect_no_error(suppressWarnings(
    save_stabl_results(
      object    = d$fit,
      path      = dest,
      x         = d$x,
      y         = d$y,
      figure_fmt = "png",
      override   = TRUE
    )
  ))
})

test_that("save_stabl_results returns path invisibly", {
  d <- .make_export_fit()
  tmp  <- withr::local_tempdir()
  dest <- file.path(tmp, "ret_check")
  ret <- suppressWarnings(
    save_stabl_results(d$fit, dest, d$x, d$y, figure_fmt = "png")
  )
  expect_equal(ret, normalizePath(dest))
})
