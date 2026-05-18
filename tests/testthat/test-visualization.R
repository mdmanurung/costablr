# tests for visualization.R
# These tests check that plot functions (a) don't error on valid inputs and
# (b) return ggplot objects.  No pixel-level rendering is validated; the goal
# is a fast smoke-test safety net for refactoring.

skip_if_not_installed("ggplot2")

# ── Shared fixture ────────────────────────────────────────────────────────────

.make_vis_fit <- function(seed = 42L, n = 30L, p = 10L, family = "binomial") {
  withr::local_seed(seed)
  x <- matrix(
    rnorm(n * p), n, p,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  if (family == "gaussian") {
    y <- setNames(rnorm(n), rownames(x))
  } else {
    y <- setNames(sample(0:1, n, replace = TRUE), rownames(x))
  }
  lam <- data.frame(lambda = seq(0.05, 0.5, length.out = 5L))
  suppressWarnings(stabl_fit(
    x               = x,
    y               = y,
    lambda_grid     = lam,
    family          = family,
    n_bootstraps    = 20L,
    artificial_type = "random_permutation"
  ))
}

# ── plot_stabl_path ───────────────────────────────────────────────────────────

test_that("plot_stabl_path returns a ggplot for binomial fit", {
  fit <- .make_vis_fit(family = "binomial")
  p <- plot_stabl_path(fit)
  expect_s3_class(p, "ggplot")
})

test_that("plot_stabl_path returns a ggplot for gaussian fit", {
  fit <- .make_vis_fit(family = "gaussian")
  p <- plot_stabl_path(fit)
  expect_s3_class(p, "ggplot")
})

test_that("plot_stabl_path accepts new_hard_threshold override", {
  fit <- .make_vis_fit()
  p <- plot_stabl_path(fit, new_hard_threshold = 0.6)
  expect_s3_class(p, "ggplot")
})

test_that("plot_stabl_path rejects non-stabl_fit input", {
  expect_error(plot_stabl_path(list()), "stabl_fit")
})

# ── plot_fdr_graph ────────────────────────────────────────────────────────────

test_that("plot_fdr_graph returns a ggplot when FDRs_ is present", {
  fit <- .make_vis_fit()
  if (!is.null(fit$FDRs_)) {
    p <- plot_fdr_graph(fit)
    expect_s3_class(p, "ggplot")
  } else {
    skip("fit$FDRs_ not present (no artificial features); skipping FDR graph test")
  }
})

# ── plot_roc ──────────────────────────────────────────────────────────────────

test_that("plot_roc returns a ggplot with valid binary inputs", {
  set.seed(1)
  y_true  <- sample(0:1, 40L, replace = TRUE)
  y_preds <- runif(40L)
  p <- plot_roc(y_true, y_preds)
  expect_s3_class(p, "ggplot")
})

# ── plot_prc ──────────────────────────────────────────────────────────────────

test_that("plot_prc returns a ggplot with valid binary inputs", {
  set.seed(2)
  y_true  <- sample(0:1, 40L, replace = TRUE)
  y_preds <- runif(40L)
  p <- plot_prc(y_true, y_preds)
  expect_s3_class(p, "ggplot")
})

# ── boxplot_features ─────────────────────────────────────────────────────────

test_that("boxplot_features returns a ggplot when features are selected", {
  withr::local_seed(99L)
  n <- 40L; p <- 8L
  x <- matrix(
    rnorm(n * p), n, p,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(sample(c("A", "B"), n, replace = TRUE), rownames(x))
  # Use features directly by name (bypass stabl_fit for speed)
  p_box <- boxplot_features(features = c("f1", "f2"), x = x, y = y)
  expect_s3_class(p_box, "ggplot")
})

# ── scatterplot_features ──────────────────────────────────────────────────────

test_that("scatterplot_features returns a ggplot for continuous y", {
  withr::local_seed(77L)
  n <- 40L; p <- 6L
  x <- matrix(
    rnorm(n * p), n, p,
    dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
  )
  y <- setNames(rnorm(n), rownames(x))
  p_scat <- scatterplot_features(features = c("f1", "f2"), x = x, y = y)
  expect_s3_class(p_scat, "ggplot")
})
