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
  stop("Usage: stacked_multi_omic_benchmark.R --out /tmp/output-dir", call. = FALSE)
}
dir.create(out, recursive = TRUE, showWarnings = FALSE)

set.seed(270627L)
n <- 200L
y <- rbinom(n, 1L, 0.5)
predictions <- data.frame(
  rna = y + rnorm(n, sd = 0.4),
  protein = y + rnorm(n, sd = 0.7),
  methylation = y + rnorm(n, sd = 1.0)
)

elapsed <- system.time({
  result <- stablr::stacked_multi_omic(
    predictions = predictions,
    y = y,
    task_type = "binary",
    n_iter = 1000L,
    random_state = 270627L
  )
})

summary <- data.frame(
  n_samples = n,
  n_omics = ncol(predictions),
  n_iter = 1000L,
  score = result$score,
  elapsed_sec = unname(elapsed[["elapsed"]])
)
utils::write.csv(summary, file.path(out, "stacked_multi_omic_benchmark.csv"), row.names = FALSE)
