#!/usr/bin/env Rscript
# run_novel_mvr.R — B5a: Decoy FDR/power benchmark for MVR vs equi vs RP knockoffs.
#
# Semi-synthetic spike-in experiment: y = X[,S] %*% beta + noise, where S is a
# known support (k=15 features), on real correlated donor matrices (OOL Proteomics,
# SSI CyTOF). Runs STABL with each of four artificial_type values:
#   "random_permutation", "knockoff" (fixed-X), "knockoff_equi", "knockoff_mvr"
# and records empirical FDR and power across n_reps replicates.
#
# Hypothesis: MVR ≥ equi ≥ RP ≥ fixed-X on power at matched FDR under high
# correlation (the regime MVR targets).
#
# Output:
#   papers/application-note/artifacts/mvr_fdr_power.csv
#     (dataset, omic, artificial_type, rep, n_true, n_selected,
#      true_positives, false_positives, power, fdr, threshold, runtime_sec)
#
# Usage (from repo root):
#   Rscript r-pkg/stablr/inst/benchmark/R/run_novel_mvr.R \
#     [--data-dir scratch/benchmark/data] \
#     [--out-dir  papers/application-note/artifacts] \
#     [--n-reps   50] \
#     [--n-true   15] \
#     [--seed     42]

suppressPackageStartupMessages({
  has_yaml <- requireNamespace("yaml", quietly = TRUE)
})

.self_dir <- local({
  args <- commandArgs(trailingOnly = FALSE)
  sf   <- grep("^--file=", args, value = TRUE)
  if (length(sf) > 0L) dirname(normalizePath(sub("^--file=", "", sf[[1L]])))
  else getwd()
})
source(file.path(.self_dir, "bench_common.R"))

# ── Argument parsing ──────────────────────────────────────────────────────────
.parse_args <- function() {
  raw     <- commandArgs(trailingOnly = TRUE)
  data_dir <- "scratch/benchmark/data"
  out_dir  <- "papers/application-note/artifacts"
  n_reps   <- 50L
  n_true   <- 15L
  seed     <- 42L
  i <- 1L
  while (i <= length(raw)) {
    switch(raw[[i]],
      "--data-dir" = { data_dir <- raw[[i + 1L]]; i <- i + 2L },
      "--out-dir"  = { out_dir  <- raw[[i + 1L]]; i <- i + 2L },
      "--n-reps"   = { n_reps   <- as.integer(raw[[i + 1L]]); i <- i + 2L },
      "--n-true"   = { n_true   <- as.integer(raw[[i + 1L]]); i <- i + 2L },
      "--seed"     = { seed     <- as.integer(raw[[i + 1L]]); i <- i + 2L },
      { i <- i + 1L }
    )
  }
  list(data_dir = data_dir, out_dir = out_dir,
       n_reps = n_reps, n_true = n_true, seed = seed)
}

# ── Donor matrices ────────────────────────────────────────────────────────────
.load_donor_matrices <- function(data_dir) {
  donors <- list()

  # OOL Proteomics
  ool_prot <- tryCatch(
    as.matrix(utils::read.csv(
      file.path(data_dir, "Onset of Labor", "Training", "Proteomics.csv"),
      row.names = 1L, check.names = FALSE)),
    error = function(e) NULL
  )
  if (!is.null(ool_prot)) donors[["OOL_Proteomics"]] <- ool_prot

  # SSI CyTOF
  ssi_cytof <- tryCatch(
    as.matrix(utils::read.csv(
      file.path(data_dir, "Biobank SSI", "Training", "CyTOF.csv"),
      row.names = 1L, check.names = FALSE)),
    error = function(e) NULL
  )
  if (!is.null(ssi_cytof)) donors[["SSI_CyTOF"]] <- ssi_cytof

  if (length(donors) == 0L) stop("No donor matrices found. Run stage_datasets.R first.", call. = FALSE)
  donors
}

# ── Semi-synthetic spike-in ───────────────────────────────────────────────────
#' Generate semi-synthetic response from real X.
#' Selects n_true features uniformly at random, then y = X[,S] %*% beta + noise.
.spike_in <- function(X, n_true, snr = 1.0, rng_state) {
  set.seed(rng_state)
  p       <- ncol(X)
  n       <- nrow(X)
  S       <- sort(sample(p, n_true))
  beta    <- rnorm(n_true)
  signal  <- X[, S, drop = FALSE] %*% beta
  noise   <- rnorm(n, sd = sqrt(sum(signal^2) / (n * snr)))
  y       <- setNames(as.numeric(signal + noise), rownames(X))
  list(y = y, true_support = colnames(X)[S])
}

# ── One replicate ─────────────────────────────────────────────────────────────
.one_rep <- function(X_raw, rep_id, n_true, art_type, n_boot) {
  X <- preprocess_fit(X_raw)
  if (ncol(X) < n_true + 5L) {
    message("    Skipping rep ", rep_id, ": too few features after preprocessing.")
    return(NULL)
  }
  spike  <- .spike_in(X, n_true = n_true, snr = 1.0, rng_state = rep_id * 1000L)
  y      <- spike$y
  S_true <- spike$true_support

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    stabl_fit(
      x               = X,
      y               = y,
      lambda_grid     = "auto",
      base_learner    = "lasso",
      family          = "gaussian",
      n_bootstraps    = n_boot,
      artificial_type = art_type,
      fdr_threshold_range = seq(0.05, 0.99, by = 0.01),
      sample_fraction = 0.5,
      replace         = FALSE,
      random_state    = rep_id,
      verbose         = FALSE
    ),
    error = function(e) { message("    STABL error: ", conditionMessage(e)); NULL }
  )
  runtime <- proc.time()[["elapsed"]] - t0

  if (is.null(fit)) return(NULL)

  selected <- fit$selected_features
  if (is.null(selected)) selected <- character(0L)
  thresh   <- fit$chosen_threshold

  tp <- length(intersect(selected, S_true))
  fp <- length(setdiff(selected, S_true))
  ns <- length(selected)
  list(
    rep          = rep_id,
    n_true       = n_true,
    n_selected   = ns,
    true_positives  = tp,
    false_positives = fp,
    power        = if (n_true > 0) tp / n_true else NA_real_,
    fdr          = if (ns > 0)    fp / ns     else 0,
    threshold    = thresh,
    runtime_sec  = runtime
  )
}

# ── Main ──────────────────────────────────────────────────────────────────────
ARTIFICIAL_TYPES <- c("random_permutation", "knockoff",
                      "knockoff_equi", "knockoff_mvr")
N_BOOT_PER_TYPE  <- c(
  random_permutation = 1000L,
  knockoff           = 1000L,
  knockoff_equi      = 1000L,
  knockoff_mvr       = 1000L
)

if (!interactive()) {
  repo <- find_repo_root()
  cfg  <- .parse_args()

  data_dir <- if (startsWith(cfg$data_dir, "/")) cfg$data_dir
              else file.path(repo, cfg$data_dir)
  out_dir  <- if (startsWith(cfg$out_dir, "/")) cfg$out_dir
              else file.path(repo, cfg$out_dir)

  load_stablr_pkg(quiet = TRUE)

  message("Loading donor matrices ...")
  donors <- .load_donor_matrices(data_dir)
  message("  Donors: ", paste(names(donors), collapse = ", "))

  all_rows <- list()

  for (donor_name in names(donors)) {
    X_raw <- donors[[donor_name]]
    # Sub-sample to ≤200 samples for speed (preserves correlation structure)
    if (nrow(X_raw) > 200L) {
      set.seed(cfg$seed)
      X_raw <- X_raw[sample(nrow(X_raw), 200L), , drop = FALSE]
    }
    message("\nDonor: ", donor_name, " (n=", nrow(X_raw), ", p=", ncol(X_raw), ")")
    parts  <- strsplit(donor_name, "_", fixed = TRUE)[[1L]]
    ds_nm  <- parts[[1L]]; omic_nm <- paste(parts[-1L], collapse = "_")

    for (art_type in ARTIFICIAL_TYPES) {
      n_boot <- N_BOOT_PER_TYPE[[art_type]]
      message("  artificial_type=", art_type, " (", cfg$n_reps, " reps) ...")

      for (rep_id in seq_len(cfg$n_reps)) {
        cat(sprintf("\r    rep %d/%d", rep_id, cfg$n_reps))
        res <- .one_rep(X_raw, rep_id, cfg$n_true, art_type, n_boot)
        if (!is.null(res)) {
          row <- as.data.frame(res, stringsAsFactors = FALSE)
          row$dataset      <- ds_nm
          row$omic         <- omic_nm
          row$artificial_type <- art_type
          all_rows[[length(all_rows) + 1L]] <- row
        }
      }
      cat("\n")
    }
  }

  if (length(all_rows) == 0L) {
    message("No results produced.")
    quit(status = 1L)
  }

  result_df <- do.call(rbind, all_rows)

  # Reorder columns
  col_order <- c("dataset", "omic", "artificial_type", "rep", "n_true",
                 "n_selected", "true_positives", "false_positives",
                 "power", "fdr", "threshold", "runtime_sec")
  result_df <- result_df[, intersect(col_order, names(result_df)), drop = FALSE]

  out_path <- file.path(out_dir, "mvr_fdr_power.csv")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(result_df, out_path, row.names = FALSE)
  message("Written: ", out_path)

  # Quick summary per artificial_type
  message("\nSummary (median across reps):")
  types <- unique(result_df$artificial_type)
  for (atype in types) {
    sub <- result_df[result_df$artificial_type == atype, ]
    message(sprintf("  %-22s  power=%.3f  fdr=%.3f  n_selected=%.1f",
                    atype,
                    median(sub$power,      na.rm = TRUE),
                    median(sub$fdr,        na.rm = TRUE),
                    median(sub$n_selected, na.rm = TRUE)))
  }

  message("\nDone.")
}
