#!/usr/bin/env Rscript

# Minimal deterministic smoke benchmark for the R STABL implementation.
#
# Usage:
#   conda run -n R4_51 Rscript "r-pkg/stablr/scripts/run_smoke_stablr.R"

.find_repo_root <- function(start_dir) {
  probe <- normalizePath(start_dir, mustWork = TRUE)
  repeat {
    if (dir.exists(file.path(probe, "r-pkg", "stablr", "R"))) {
      return(probe)
    }
    parent <- dirname(probe)
    if (identical(parent, probe)) {
      return(NULL)
    }
    probe <- parent
  }
}

repo_root <- .find_repo_root(getwd())
if (is.null(repo_root)) {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  idx <- grep(paste0("^", file_arg), args)
  if (length(idx) > 0L) {
    script_path <- normalizePath(sub(file_arg, "", args[idx[1L]]), mustWork = FALSE)
    repo_root <- .find_repo_root(dirname(script_path))
  }
}
if (is.null(repo_root)) {
  stop("Could not resolve repository root containing r-pkg/stablr/R.", call. = FALSE)
}

r_dir <- file.path(repo_root, "r-pkg", "stablr", "R")
r_files <- list.files(r_dir, pattern = "\\.R$", full.names = TRUE)
for (path in r_files) {
  source(path, local = globalenv())
}

set.seed(20260503)
n <- 60L
p <- 20L
x <- matrix(rnorm(n * p), nrow = n, ncol = p)
rownames(x) <- paste0("s", seq_len(n))
colnames(x) <- paste0("f", seq_len(p))

y_signal <- 1.0 * x[, 1L] - 0.8 * x[, 2L] + 0.5 * x[, 3L]
y <- setNames(y_signal + rnorm(n, sd = 0.7), rownames(x))

lambda_grid <- data.frame(
  lambda = exp(seq(log(0.4), log(0.02), length.out = 6L))
)

fit <- stabl_fit(
  x = x,
  y = y,
  lambda_grid = lambda_grid,
  base_learner = "lasso",
  family = "gaussian",
  n_bootstraps = 20L,
  artificial_type = "random_permutation",
  artificial_proportion = 1.0,
  sample_fraction = 0.5,
  replace = FALSE,
  workers = 1L,
  random_state = 20260503
)

support <- get_support(fit)
importances <- get_importances(fit)
selected <- get_feature_names_out(fit)

stopifnot(inherits(fit, "stabl_fit"))
stopifnot(identical(dim(fit$stabl_scores_), c(p, nrow(lambda_grid))))
stopifnot(length(support) == p)
stopifnot(all(importances >= 0 & importances <= 1))
stopifnot(!is.null(fit$fdr_min_threshold_))
stopifnot(is.finite(fit$fdr_min_threshold_))

top_idx <- order(importances, decreasing = TRUE)[seq_len(min(5L, length(importances)))]
top_features <- names(importances)[top_idx]

cat("stablr smoke benchmark completed\n")
cat("n_samples:", n, "| n_features:", p, "| n_lambdas:", nrow(lambda_grid), "\n")
cat("fdr_min_threshold:", format(round(fit$fdr_min_threshold_, 4L), nsmall = 4L), "\n")
cat("selected_features:", length(selected), "\n")
cat("top_features:", paste(top_features, collapse = ", "), "\n")
