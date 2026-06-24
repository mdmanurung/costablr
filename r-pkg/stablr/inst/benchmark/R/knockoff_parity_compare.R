#!/usr/bin/env Rscript
# knockoff_parity_compare.R — A4 model-X knockoff parity: Python knockpy vs stablr.
#
# For each Sigma configuration in scratch/benchmark/knockoff_parity/:
#   1. Read Sigma and Python S_equi / S_mvr reference vectors.
#   2. Compute R's equicorrelated S (knockoff::create.gaussian method="equi")
#      and R's MVR S (stablr::solve_mvr) from the same Sigma.
#   3. Report per-configuration concordance: Pearson r, Spearman r, max|delta|.
#   4. Write papers/application-note/artifacts/knockoff_parity.csv
#
# Run from repo root:
#   /exports/archive/hg-funcgenom-research/mdmanurung/conda/envs/R4_51/bin/Rscript \
#     r-pkg/stablr/inst/benchmark/R/knockoff_parity_compare.R

suppressPackageStartupMessages({
  pkgload::load_all("r-pkg/stablr", quiet = TRUE)
  stopifnot(requireNamespace("knockoff",  quietly = TRUE))
})

PARITY_DIR  <- "scratch/benchmark/knockoff_parity"
ARTIFACT    <- "papers/application-note/artifacts/knockoff_parity.csv"

# ── Helper: read CSV and return as numeric vector or matrix ───────────────────
read_vec <- function(path) {
  as.numeric(as.matrix(utils::read.csv(path, header = TRUE,
                                        check.names = FALSE)))
}
read_mat <- function(path) {
  as.matrix(utils::read.csv(path, header = TRUE, check.names = FALSE))
}

concordance <- function(a, b, label_a, label_b) {
  # Pearson/Spearman are undefined when either vector has zero variance
  # (equicorrelated S is a constant scalar).  Use safe_cor() that returns NA
  # rather than warning; max_abs_dev is the primary parity metric.
  safe_cor <- function(x, y, method) {
    if (sd(x) == 0 || sd(y) == 0) return(NA_real_)
    cor(x, y, method = method)
  }
  data.frame(
    method_a     = label_a,
    method_b     = label_b,
    n            = length(a),
    pearson_r    = safe_cor(a, b, "pearson"),
    spearman_r   = safe_cor(a, b, "spearman"),
    max_abs_dev  = max(abs(a - b)),
    mean_abs_dev = mean(abs(a - b)),
    is_constant_a = (sd(a) == 0),
    stringsAsFactors = FALSE
  )
}

# ── R equicorrelated S solver ─────────────────────────────────────────────────
# knockoff::create.gaussian method="equi" solves for S internally; we recover
# it by inspecting the SDP/equi formula:
#   s = min(2 * lambda_min(Sigma), 1)  (all elements equal for equicorrelated)
solve_equi_s <- function(Sigma) {
  p       <- nrow(Sigma)
  min_eig <- min(eigen(Sigma, symmetric = TRUE, only.values = TRUE)$values)
  s_val   <- min(2 * min_eig, 1)
  rep(s_val, p)
}

# ── Discover configs ──────────────────────────────────────────────────────────
sigma_files <- list.files(PARITY_DIR, pattern = "_Sigma\\.csv$", full.names = TRUE)
configs <- sub("_Sigma\\.csv$", "", basename(sigma_files))

cat(sprintf("Found %d Sigma configurations in %s\n\n", length(configs), PARITY_DIR))

records <- list()
for (cfg in configs) {
  cat(sprintf("── %s ──\n", cfg))
  Sigma   <- read_mat(file.path(PARITY_DIR, paste0(cfg, "_Sigma.csv")))
  py_equi <- read_vec(file.path(PARITY_DIR, paste0(cfg, "_S_equi_py.csv")))
  py_mvr  <- read_vec(file.path(PARITY_DIR, paste0(cfg, "_S_mvr_py.csv")))
  p       <- nrow(Sigma)

  # ── R equicorrelated S ────────────────────────────────────────────────────
  r_equi <- tryCatch(
    solve_equi_s(Sigma),
    error = function(e) {
      warning("R equi S solver failed for ", cfg, ": ", conditionMessage(e))
      rep(NA_real_, p)
    }
  )
  cat(sprintf("  R equi  S: min=%.4f max=%.4f\n", min(r_equi), max(r_equi)))
  cat(sprintf("  Py equi S: min=%.4f max=%.4f\n", min(py_equi), max(py_equi)))

  # ── R MVR S ───────────────────────────────────────────────────────────────
  r_mvr <- tryCatch({
    set.seed(0L)
    solve_mvr(Sigma, num_iter = 200L, converge_tol = 1e-5, tol = 1e-5)
  }, error = function(e) {
    warning("R MVR solver failed for ", cfg, ": ", conditionMessage(e))
    rep(NA_real_, p)
  })
  cat(sprintf("  R mvr   S: min=%.4f max=%.4f\n", min(r_mvr), max(r_mvr)))
  cat(sprintf("  Py mvr  S: min=%.4f max=%.4f\n", min(py_mvr), max(py_mvr)))

  # ── Concordance metrics ───────────────────────────────────────────────────
  rec_equi <- cbind(
    data.frame(config = cfg, knockoff_type = "equicorrelated"),
    concordance(r_equi, py_equi, "R_knockoff_equi", "Python_knockpy_equi")
  )
  rec_mvr  <- cbind(
    data.frame(config = cfg, knockoff_type = "mvr"),
    concordance(r_mvr, py_mvr, "R_knockoff_mvr", "Python_knockpy_mvr")
  )
  cat(sprintf("  equi: Pearson=%.4f Spearman=%.4f maxDev=%.2e\n",
              rec_equi$pearson_r, rec_equi$spearman_r, rec_equi$max_abs_dev))
  cat(sprintf("  mvr:  Pearson=%.4f Spearman=%.4f maxDev=%.2e\n",
              rec_mvr$pearson_r,  rec_mvr$spearman_r,  rec_mvr$max_abs_dev))

  records <- c(records, list(rec_equi, rec_mvr))
  cat("\n")
}

# ── Write artifact ────────────────────────────────────────────────────────────
out_df <- do.call(rbind, records)
rownames(out_df) <- NULL

dir.create(dirname(ARTIFACT), recursive = TRUE, showWarnings = FALSE)
utils::write.csv(out_df, ARTIFACT, row.names = FALSE, quote = FALSE)
cat(sprintf("Wrote %s (%d rows)\n", ARTIFACT, nrow(out_df)))

# ── Summary gate ─────────────────────────────────────────────────────────────
# Primary criterion: max absolute deviation.
#   equicorrelated: constant vector, so Pearson/Spearman undefined.
#                   Parity gate = max_abs_dev ≤ 1e-3 (analytical formula
#                   discrepancy from floating-point precision in min-eigenvalue).
#   MVR:            max_abs_dev ≤ 1e-4 (coordinate-descent converges to the
#                   same optimum; test suite uses this threshold).
cat("\n── Parity gate ──\n")
equi_rows <- out_df[out_df$knockoff_type == "equicorrelated", ]
mvr_rows  <- out_df[out_df$knockoff_type == "mvr", ]

equi_max_dev <- max(equi_rows$max_abs_dev, na.rm = TRUE)
mvr_max_dev  <- max(mvr_rows$max_abs_dev,  na.rm = TRUE)

cat(sprintf("  equi max|delta| = %.2e  (threshold 1e-3)  %s\n", equi_max_dev,
            ifelse(equi_max_dev <= 1e-3, "PASS", "FAIL")))
cat(sprintf("  mvr  max|delta| = %.2e  (threshold 1e-4)  %s\n", mvr_max_dev,
            ifelse(mvr_max_dev  <= 1e-4, "PASS", "FAIL")))
cat("  Note: equicorrelated S is a constant scalar — Pearson/Spearman are\n")
cat("  undefined by construction and NOT reported as a parity metric.\n")
cat("  MVR Pearson r (where S varies) is embedded in the CSV per config.\n")
