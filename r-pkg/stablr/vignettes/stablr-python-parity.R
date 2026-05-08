## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse  = TRUE,
  comment   = "#>",
  fig.width  = 7,
  fig.height = 5,
  cache      = TRUE,
  cache.path = "stablr-python-parity-cache/"
)

## ----libraries----------------------------------------------------------------
library(stablr)

## ----preprocess-helpers-------------------------------------------------------
preprocess_fit <- function(x, min_var = 1e-6) {
  col_vars  <- apply(x, 2, var, na.rm = TRUE)
  keep_cols <- col_vars > min_var
  x <- x[, keep_cols, drop = FALSE]
  col_medians <- apply(x, 2, median, na.rm = TRUE)
  for (j in seq_along(col_medians)) {
    na_idx <- is.na(x[, j])
    if (any(na_idx)) x[na_idx, j] <- col_medians[j]
  }
  col_means <- colMeans(x)
  col_sds   <- apply(x, 2, sd)
  col_sds[col_sds < 1e-10] <- 1
  x <- sweep(sweep(x, 2, col_means), 2, col_sds, "/")
  list(x = x, keep_cols = keep_cols, col_medians = col_medians,
       col_means = col_means, col_sds = col_sds)
}

preprocess_apply <- function(x, pipe) {
  x <- x[, pipe$keep_cols, drop = FALSE]
  for (j in seq_len(ncol(x))) {
    na_idx <- is.na(x[, j])
    if (any(na_idx)) x[na_idx, j] <- pipe$col_medians[j]
  }
  sweep(sweep(x, 2, pipe$col_means), 2, pipe$col_sds, "/")
}

## ----ool-load-----------------------------------------------------------------
ool_train <- load_ool_data(split = "train")
ool_valid <- load_ool_data(split = "valid")

pipe_prot    <- preprocess_fit(ool_train$x_list$proteomics)
x_prot       <- pipe_prot$x
y_prot       <- ool_train$y
x_prot_valid <- preprocess_apply(ool_valid$x_list$proteomics, pipe_prot)
y_prot_valid <- ool_valid$y

cat("Training set:   ", nrow(x_prot), "samples x", ncol(x_prot), "features\n")
cat("Validation set: ", nrow(x_prot_valid), "samples x", ncol(x_prot_valid), "features\n")

## ----ool-lambda---------------------------------------------------------------
lambda_prot <- auto_lambda_grid(
  x_prot, y_prot,
  family   = "gaussian",
  n_lambda = 10
)

## ----ool-fit, cache = TRUE----------------------------------------------------
set.seed(42)
fit_prot <- stabl_fit(
  x                   = x_prot,
  y                   = y_prot,
  lambda_grid         = lambda_prot,
  base_learner        = "lasso",
  family              = "gaussian",
  n_bootstraps        = 500L,
  artificial_type     = "knockoff",
  fdr_threshold_range = seq(0, 1, by = 0.01),
  random_state        = 42L
)
fit_prot

