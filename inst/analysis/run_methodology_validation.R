#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
out <- NULL
if (length(args) >= 2L) {
  hit <- which(args == "--out")
  if (length(hit) == 1L && hit < length(args)) {
    out <- args[[hit + 1L]]
  }
}
if (is.null(out) || !nzchar(out)) {
  stop("Usage: run_methodology_validation.R --out /tmp/output-dir", call. = FALSE)
}
dir.create(out, recursive = TRUE, showWarnings = FALSE)

set.seed(270627L)
n <- 40L
p <- 6L
x <- matrix(
  rnorm(n * p),
  nrow = n,
  dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
)
y <- setNames(0.8 * x[, 1L] - 0.3 * x[, 2L] + rnorm(n, sd = 0.2), rownames(x))

fit <- stablr::stabl_fit(
  x = x,
  y = y,
  lambda_grid = data.frame(lambda = c(0.2, 0.1, 0.05)),
  n_bootstraps = 8L,
  artificial_type = "random_permutation",
  random_state = 270627L
)

summary <- data.frame(
  n_features = fit$n_features_in_,
  n_selected = length(stablr::get_feature_names_out(fit)),
  min_fdp = fit$min_fdr_,
  fdp_threshold = fit$fdr_min_threshold_
)
utils::write.csv(summary, file.path(out, "methodology_validation_summary.csv"), row.names = FALSE)
