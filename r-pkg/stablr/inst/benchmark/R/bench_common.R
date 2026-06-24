# bench_common.R — Shared utilities for the STABL cross-language parity benchmark.
#
# Source this file (or let stage/run scripts source it) to get the helpers
# below.  All functions are prefixed with `.bench_` or are re-exported helpers
# from generate_publication_parity_table.R (duplicated here so the benchmark
# harness has no dependency on the analysis/ sub-tree).
#
# Functions:
#   find_repo_root()          — walk up from script/wd to repo root
#   load_stablr_pkg()         — load stablr from source or installed
#   pkg_version()             — stablr package version string
#   preprocess_fit()          — variance filter → missingness filter → impute → z-score
#   jaccard_sets()            — Jaccard index of two character vectors
#   spearman_on_common()      — Spearman of named vectors on common names
#   bootstrap_ci()            — percentile CI by resampling a numeric vector
#   read_named_vec()          — read 1-col CSV as named numeric vector
#   read_stablr_output()      — read per-dataset stablr output RDS or CSV files
#   read_python_output()      — read Python reference CSVs from reference/<dataset>/
#   safe_cor()                — cor() returning NA on zero-variance inputs (no warning)
#   roc_auc_safe()            — AUC from predicted scores + binary labels (no package dep)
#   r2_safe()                 — R² from predicted + observed values

# ── Repository root ───────────────────────────────────────────────────────────
find_repo_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  sf   <- grep("^--file=", args, value = TRUE)
  start <- if (length(sf) > 0L)
    dirname(normalizePath(sub("^--file=", "", sf[[1L]]), winslash = "/", mustWork = TRUE))
  else getwd()
  path <- start
  repeat {
    if (file.exists(file.path(path, "r-pkg", "stablr", "DESCRIPTION"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("Cannot locate repository root.", call. = FALSE)
    path <- parent
  }
}

# ── Package loading ───────────────────────────────────────────────────────────
load_stablr_pkg <- function(pkg_root = NULL, quiet = TRUE) {
  if (is.null(pkg_root)) {
    repo     <- find_repo_root()
    pkg_root <- file.path(repo, "r-pkg", "stablr")
  }
  if (dir.exists(file.path(pkg_root, "R"))) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      suppressPackageStartupMessages(pkgload::load_all(pkg_root, quiet = quiet))
      return(invisible(getNamespace("stablr")))
    }
    if (requireNamespace("devtools", quietly = TRUE)) {
      suppressPackageStartupMessages(devtools::load_all(pkg_root, quiet = quiet))
      return(invisible(getNamespace("stablr")))
    }
  }
  if (requireNamespace("stablr", quietly = TRUE)) {
    suppressPackageStartupMessages(library(stablr, quietly = quiet))
    return(invisible(getNamespace("stablr")))
  }
  stop("Cannot load stablr. Install pkgload/devtools or the package itself.", call. = FALSE)
}

pkg_version <- function(pkg_root = NULL, pkg = "stablr") {
  ver <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NULL)
  if (!is.null(ver)) return(ver)
  if (is.null(pkg_root)) pkg_root <- file.path(find_repo_root(), "r-pkg", "stablr")
  desc <- file.path(pkg_root, "DESCRIPTION")
  if (!file.exists(desc)) return("unknown")
  unname(read.dcf(desc)[1L, "Version"])
}

# ── Data preprocessing (mirrors Python STABL's preprocess_data) ──────────────

#' Variance filter, missingness filter, median imputation, z-score standardise.
#'
#' @param x         Numeric matrix or data frame (samples × features).
#' @param min_var   Remove columns with variance ≤ this (default 0).
#' @param max_nan_fraction  Remove columns with fraction of NAs above this (default 0.2).
#' @return Standardised numeric matrix (same rows, filtered columns).
preprocess_fit <- function(x, min_var = 0, max_nan_fraction = 0.2) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  col_vars <- apply(x, 2L, stats::var, na.rm = TRUE)
  na_frac  <- colSums(is.na(x)) / nrow(x)
  keep     <- col_vars > min_var & na_frac <= max_nan_fraction
  x        <- x[, keep, drop = FALSE]
  col_med  <- apply(x, 2L, stats::median, na.rm = TRUE)
  col_med[is.na(col_med)] <- 0
  for (j in seq_along(col_med)) {
    idx <- is.na(x[, j])
    if (any(idx)) x[idx, j] <- col_med[[j]]
  }
  col_mn  <- colMeans(x)
  col_sd  <- sqrt(colMeans(sweep(x, 2L, col_mn)^2))
  col_sd[col_sd < 1e-10] <- 1
  sweep(sweep(x, 2L, col_mn), 2L, col_sd, "/")
}

# ── Set similarity ────────────────────────────────────────────────────────────

#' Jaccard index of two character vectors.
jaccard_sets <- function(a, b) {
  a <- unique(a[!is.na(a)])
  b <- unique(b[!is.na(b)])
  if (length(a) == 0L && length(b) == 0L) return(1)
  length(intersect(a, b)) / length(union(a, b))
}

#' Spearman correlation of named numeric vectors on their common names.
spearman_on_common <- function(r_scores, py_scores) {
  common <- intersect(names(r_scores), names(py_scores))
  if (length(common) < 2L) return(NA_real_)
  stats::cor(r_scores[common], py_scores[common], method = "spearman")
}

# ── Safe statistics ───────────────────────────────────────────────────────────

#' Pearson or Spearman correlation that returns NA (no warning) when either
#' input has zero variance.
safe_cor <- function(x, y, method = "pearson") {
  if (stats::sd(x, na.rm = TRUE) == 0 || stats::sd(y, na.rm = TRUE) == 0) {
    return(NA_real_)
  }
  stats::cor(x, y, method = method, use = "complete.obs")
}

#' Area under the ROC curve (trapezoidal rule; no package dependency).
#' Returns NA if fewer than 2 levels in labels.
roc_auc_safe <- function(scores, labels) {
  labels <- as.integer(as.factor(labels)) - 1L
  if (length(unique(labels)) < 2L) return(NA_real_)
  ord <- order(scores, decreasing = TRUE)
  labels_ord <- labels[ord]
  n_pos <- sum(labels)
  n_neg <- length(labels) - n_pos
  if (n_pos == 0L || n_neg == 0L) return(NA_real_)
  # Wilcoxon-Mann-Whitney statistic
  ranks <- rank(scores)
  auc   <- (sum(ranks[labels == 1L]) - n_pos * (n_pos + 1L) / 2) / (n_pos * n_neg)
  auc
}

#' R² from predicted and observed vectors.
r2_safe <- function(predicted, observed) {
  if (length(predicted) != length(observed)) return(NA_real_)
  ss_res <- sum((observed - predicted)^2, na.rm = TRUE)
  ss_tot <- sum((observed - mean(observed, na.rm = TRUE))^2, na.rm = TRUE)
  if (ss_tot == 0) return(NA_real_)
  1 - ss_res / ss_tot
}

# ── Bootstrap CI ─────────────────────────────────────────────────────────────

#' Percentile bootstrap confidence interval for the mean of a numeric vector.
#'
#' @param x  Numeric vector of per-fold metric deltas.
#' @param B  Number of bootstrap replicates (default 2000).
#' @param alpha Confidence level complement (default 0.05 → 95% CI).
#' @param seed Optional RNG seed for reproducibility.
#' @return Named numeric vector: c(mean=, ci_lo=, ci_hi=).
bootstrap_ci <- function(x, B = 2000L, alpha = 0.05, seed = NULL) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(c(mean = NA_real_, ci_lo = NA_real_, ci_hi = NA_real_))
  if (!is.null(seed)) set.seed(seed)
  boot_means <- replicate(B, mean(sample(x, replace = TRUE)))
  c(
    mean  = mean(x),
    ci_lo = unname(stats::quantile(boot_means, alpha / 2)),
    ci_hi = unname(stats::quantile(boot_means, 1 - alpha / 2))
  )
}

# ── I/O helpers ──────────────────────────────────────────────────────────────

#' Read a 1-column (optionally row-named) CSV as a named numeric vector.
read_named_vec <- function(path, col = 1L) {
  df <- utils::read.csv(path, row.names = 1L, check.names = FALSE)
  stats::setNames(as.numeric(df[[col]]), rownames(df))
}

#' Read the Python reference output for a single dataset.
#'
#' Expects files produced by inst/benchmark/py/run_reference.py:
#'   reference/<dataset_id>/predictions.csv  (sample × model predicted scores)
#'   reference/<dataset_id>/selected.csv     (feature × model 0/1 selection)
#'   reference/<dataset_id>/max_scores.csv   (feature × model max score)
#'   reference/<dataset_id>/folds.csv        (fold × sample: train/test membership)
#'
#' @param ref_dir Root of the reference/ output tree.
#' @param dataset_id Short dataset ID matching the directory name.
#' @return Named list with elements: predictions, selected, max_scores, folds.
read_python_output <- function(ref_dir, dataset_id) {
  base <- file.path(ref_dir, dataset_id)
  read_csv_safe <- function(f) {
    p <- file.path(base, f)
    if (!file.exists(p)) return(NULL)
    df <- utils::read.csv(p, row.names = 1L, check.names = FALSE)
    df
  }
  list(
    predictions = read_csv_safe("predictions.csv"),
    selected    = read_csv_safe("selected.csv"),
    max_scores  = read_csv_safe("max_scores.csv"),
    folds       = read_csv_safe("folds.csv")
  )
}

#' Read the stablr benchmark output for a single dataset.
#'
#' Expects RDS files written by run_stablr_pipeline.R under
#'   stablr_out/<dataset_id>/<model_name>.rds
#' (a list with $fit, $predictions, $folds, $selected, $max_scores).
#'
#' @param stablr_dir Root of the stablr_out/ output tree.
#' @param dataset_id Dataset short ID.
#' @return Named list (model → list(fit, predictions, folds, selected, max_scores)).
read_stablr_output <- function(stablr_dir, dataset_id) {
  base  <- file.path(stablr_dir, dataset_id)
  rds   <- list.files(base, pattern = "\\.rds$", full.names = TRUE)
  if (length(rds) == 0L) return(NULL)
  out   <- lapply(rds, readRDS)
  names(out) <- sub("\\.rds$", "", basename(rds))
  out
}

# ── YAML config reader ────────────────────────────────────────────────────────

#' Read inst/benchmark/config/datasets.yaml.
#'
#' Returns a list, one element per dataset.
#' Falls back to a minimal hard-coded list if yaml is not installed (for
#' environments where yaml is unavailable).
read_dataset_config <- function(config_path = NULL) {
  if (is.null(config_path)) {
    # Find relative to this script's location
    args <- commandArgs(trailingOnly = FALSE)
    sf   <- grep("^--file=", args, value = TRUE)
    if (length(sf) > 0L) {
      script_dir <- dirname(normalizePath(sub("^--file=", "", sf[[1L]])))
      config_path <- file.path(script_dir, "..", "config", "datasets.yaml")
    } else {
      config_path <- file.path(find_repo_root(),
                               "r-pkg", "stablr", "inst", "benchmark",
                               "config", "datasets.yaml")
    }
  }
  if (!file.exists(config_path)) {
    stop("datasets.yaml not found: ", config_path, call. = FALSE)
  }
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop("Package 'yaml' required for read_dataset_config().", call. = FALSE)
  }
  yaml::read_yaml(config_path)[["datasets"]]
}
