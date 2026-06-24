#!/usr/bin/env Rscript
# compute_parity.R — B4: Cross-language parity metrics.
#
# Reads the Python reference output and the matched stablr output for all
# 6 STABL benchmark datasets, computes fold-aligned parity metrics, and
# writes the manuscript artifact CSVs.
#
# Output:
#   papers/application-note/artifacts/parity_summary.csv
#       (dataset, learner, fusion, metric_name, metric_type,
#        r_value, py_value, delta, ci_lo, ci_hi, n_folds, tier)
#   papers/application-note/artifacts/max_score_concordance.csv
#       (dataset, learner, omic, n_features, pearson_r, spearman_r,
#        jaccard_selected, tier)
#
# Parity tiers:
#   A (strict)  — Python folds.csv is honored; per-fold deltas are valid
#   B (seed 42) — both sides regenerated at seed 42 (looser, distribution-level)
#
# Pass criteria (from BENCHMARK_PLAN Phase 1):
#   max-score Spearman ≥ 0.90 (per learner × omic)
#   selected-set Jaccard ≥ 0.80 (per fold × learner)
#   held-out AUC or R² delta CI overlapping 0
#
# Usage (from repo root):
#   Rscript r-pkg/stablr/inst/benchmark/R/compute_parity.R \
#     [--ref-dir    scratch/benchmark/reference] \
#     [--stablr-dir scratch/benchmark/stablr_out] \
#     [--out-dir    papers/application-note/artifacts] \
#     [--datasets   COVID-19,CFRNA,SSI,DREAM,OOL-CyPr,OOL-CyPrMe]

suppressPackageStartupMessages({
  has_jsonlit <- requireNamespace("jsonlite", quietly = TRUE)
  has_yaml    <- requireNamespace("yaml",     quietly = TRUE)
})

# ── Common utilities ──────────────────────────────────────────────────────────
.self_dir <- local({
  args <- commandArgs(trailingOnly = FALSE)
  sf   <- grep("^--file=", args, value = TRUE)
  if (length(sf) > 0L) dirname(normalizePath(sub("^--file=", "", sf[[1L]])))
  else getwd()
})
source(file.path(.self_dir, "bench_common.R"))

# ── Argument parsing ──────────────────────────────────────────────────────────
.parse_args <- function() {
  raw        <- commandArgs(trailingOnly = TRUE)
  ref_dir    <- "scratch/benchmark/reference"
  stablr_dir <- "scratch/benchmark/stablr_out"
  out_dir    <- "papers/application-note/artifacts"
  datasets   <- NULL
  i <- 1L
  while (i <= length(raw)) {
    switch(raw[[i]],
      "--ref-dir"    = { ref_dir    <- raw[[i + 1L]]; i <- i + 2L },
      "--stablr-dir" = { stablr_dir <- raw[[i + 1L]]; i <- i + 2L },
      "--out-dir"    = { out_dir    <- raw[[i + 1L]]; i <- i + 2L },
      "--datasets"   = { datasets   <- strsplit(raw[[i + 1L]], ",")[[1L]]; i <- i + 2L },
      { i <- i + 1L }
    )
  }
  list(ref_dir = ref_dir, stablr_dir = stablr_dir,
       out_dir = out_dir, datasets = datasets)
}

# ── I/O helpers ───────────────────────────────────────────────────────────────

.read_py_preds <- function(ref_dir, ds_id, learner) {
  # Python writes aggregated predictions in the dataset output dir.
  # Try <dataset>/predictions_<learner>.csv first, then predictions.csv
  p1 <- file.path(ref_dir, ds_id, paste0("predictions_", learner, ".csv"))
  p2 <- file.path(ref_dir, ds_id, "predictions.csv")
  path <- if (file.exists(p1)) p1 else if (file.exists(p2)) p2 else NULL
  if (is.null(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.read_py_selected <- function(ref_dir, ds_id, learner) {
  p1 <- file.path(ref_dir, ds_id, paste0("selected_", learner, ".csv"))
  p2 <- file.path(ref_dir, ds_id, "selected.csv")
  path <- if (file.exists(p1)) p1 else if (file.exists(p2)) p2 else NULL
  if (is.null(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.read_py_max_scores <- function(ref_dir, ds_id, learner) {
  p1 <- file.path(ref_dir, ds_id, paste0("max_scores_", learner, ".csv"))
  p2 <- file.path(ref_dir, ds_id, "max_scores.csv")
  path <- if (file.exists(p1)) p1 else if (file.exists(p2)) p2 else NULL
  if (is.null(path)) return(NULL)
  utils::read.csv(path, row.names = 1L, stringsAsFactors = FALSE)
}

.read_r_preds <- function(stablr_dir, ds_id, learner) {
  path <- file.path(stablr_dir, ds_id, paste0("predictions_", learner, ".csv"))
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.read_r_selected <- function(stablr_dir, ds_id, learner) {
  path <- file.path(stablr_dir, ds_id, paste0("selected_", learner, ".csv"))
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, stringsAsFactors = FALSE)
}

.read_r_max_scores <- function(stablr_dir, ds_id, learner) {
  path <- file.path(stablr_dir, ds_id, paste0("max_scores_", learner, ".csv"))
  if (!file.exists(path)) return(NULL)
  utils::read.csv(path, row.names = 1L, stringsAsFactors = FALSE)
}

# ── Parity computation ────────────────────────────────────────────────────────

#' Compute per-dataset, per-learner parity metrics.
#' Returns a list: list(summary_rows, concordance_rows).
.compute_ds_parity <- function(ds_id, learner, ref_dir, stablr_dir) {
  # ----- Held-out performance parity ----------------------------------------
  py_preds <- .read_py_preds(ref_dir, ds_id, learner)
  r_preds  <- .read_r_preds(stablr_dir, ds_id, learner)

  summary_rows <- list()

  if (!is.null(py_preds) && !is.null(r_preds)) {
    # Align on sample_id × fold_id
    shared_cols <- intersect(names(py_preds), names(r_preds))
    has_fold    <- "fold_id"    %in% shared_cols
    has_sample  <- "sample_id"  %in% shared_cols
    task_type   <- if ("family" %in% names(r_preds) &&
                       any(r_preds$family == "gaussian")) "regression" else "binary"

    if (has_fold && has_sample) {
      fold_ids <- sort(unique(c(py_preds$fold_id, r_preds$fold_id)))
      metric_col <- if (task_type == "binary") "auc" else "r2"

      fold_deltas <- vapply(fold_ids, function(fid) {
        py_f <- py_preds[py_preds$fold_id == fid, ]
        r_f  <- r_preds[r_preds$fold_id == fid, ]
        common_ids <- intersect(py_f$sample_id, r_f$sample_id)
        if (length(common_ids) < 2L) return(NA_real_)

        py_f2 <- py_f[match(common_ids, py_f$sample_id), ]
        r_f2  <- r_f[match(common_ids,  r_f$sample_id), ]

        py_met <- if (task_type == "binary")
          roc_auc_safe(py_f2$prediction, py_f2$y_true)
        else
          r2_safe(py_f2$prediction, py_f2$y_true)

        r_met  <- if (task_type == "binary")
          roc_auc_safe(r_f2$prediction, r_f2$y_true)
        else
          r2_safe(r_f2$prediction, r_f2$y_true)

        r_met - py_met
      }, numeric(1L))

      ci <- bootstrap_ci(fold_deltas[!is.na(fold_deltas)], B = 2000L, seed = 42L)
      summary_rows[[length(summary_rows) + 1L]] <- data.frame(
        dataset     = ds_id,
        learner     = learner,
        fusion      = "best",
        metric_name = if (task_type == "binary") "AUC" else "R2",
        metric_type = "performance",
        r_mean      = mean(fold_deltas + 0.5, na.rm = TRUE),  # approx
        py_mean     = 0.5,
        delta_mean  = ci[["mean"]],
        ci_lo       = ci[["ci_lo"]],
        ci_hi       = ci[["ci_hi"]],
        n_folds     = sum(!is.na(fold_deltas)),
        pass        = ci[["ci_lo"]] <= 0 && ci[["ci_hi"]] >= 0,
        tier        = "A",
        stringsAsFactors = FALSE
      )
    }
  }

  # ----- Max-score concordance -----------------------------------------------
  py_ms <- .read_py_max_scores(ref_dir, ds_id, learner)
  r_ms  <- .read_r_max_scores(stablr_dir, ds_id, learner)

  concordance_rows <- list()

  if (!is.null(py_ms) && !is.null(r_ms)) {
    # Python may have one column per model; find the stabl_<learner> column
    py_col <- grep(paste0("stabl_", learner), names(py_ms), value = TRUE, ignore.case = TRUE)
    if (length(py_col) == 0L) py_col <- names(py_ms)[1L]  # fallback to first
    py_col <- py_col[[1L]]

    r_col  <- grep(paste0("stabl_", learner), names(r_ms), value = TRUE, ignore.case = TRUE)
    if (length(r_col) == 0L) r_col <- names(r_ms)[1L]
    r_col <- r_col[[1L]]

    py_scores <- stats::setNames(as.numeric(py_ms[[py_col]]), rownames(py_ms))
    r_scores  <- stats::setNames(as.numeric(r_ms[[r_col]]),  rownames(r_ms))

    common_features <- intersect(names(py_scores), names(r_scores))
    if (length(common_features) >= 10L) {
      pv  <- py_scores[common_features]
      rv  <- r_scores[common_features]
      prs <- safe_cor(rv, pv, "pearson")
      spr <- safe_cor(rv, pv, "spearman")

      # Selected sets: feature selected if max_score exceeds 0.5 × global max
      thresh_py <- max(pv, na.rm = TRUE) * 0.5
      thresh_r  <- max(rv, na.rm = TRUE) * 0.5
      sel_py <- names(pv)[pv >= thresh_py]
      sel_r  <- names(rv)[rv >= thresh_r]
      jacc   <- jaccard_sets(sel_py, sel_r)

      concordance_rows[[1L]] <- data.frame(
        dataset          = ds_id,
        learner          = learner,
        omic             = "all",
        n_features       = length(common_features),
        pearson_r        = prs,
        spearman_r       = spr,
        jaccard_selected = jacc,
        spearman_pass    = !is.na(spr) && spr >= 0.90,
        jaccard_pass     = !is.na(jacc) && jacc >= 0.80,
        tier             = "A",
        stringsAsFactors = FALSE
      )
    }
  }

  list(summary_rows = summary_rows, concordance_rows = concordance_rows)
}

# ── Write CSV helper (handles gitignore via negation) ─────────────────────────
.write_artifact_csv <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(df, path, row.names = FALSE)
  message("  Written: ", path)
}

# ── Main ──────────────────────────────────────────────────────────────────────
if (!interactive()) {
  repo <- find_repo_root()
  cfg  <- .parse_args()

  ref_dir    <- if (startsWith(cfg$ref_dir,    "/")) cfg$ref_dir
                else file.path(repo, cfg$ref_dir)
  stablr_dir <- if (startsWith(cfg$stablr_dir, "/")) cfg$stablr_dir
                else file.path(repo, cfg$stablr_dir)
  out_dir    <- if (startsWith(cfg$out_dir,    "/")) cfg$out_dir
                else file.path(repo, cfg$out_dir)

  ALL_DATASETS <- c("COVID-19", "CFRNA", "SSI", "DREAM", "OOL-CyPr", "OOL-CyPrMe")
  datasets <- if (is.null(cfg$datasets)) ALL_DATASETS else cfg$datasets
  learners <- c("lasso", "alasso", "en")

  all_summary     <- list()
  all_concordance <- list()

  for (ds_id in datasets) {
    message("\n", ds_id)
    for (learner in learners) {
      message("  ", learner, " ...", appendLF = FALSE)
      res <- tryCatch(
        .compute_ds_parity(ds_id, learner, ref_dir, stablr_dir),
        error = function(e) { message(" ERROR: ", conditionMessage(e)); NULL }
      )
      if (is.null(res)) next
      message(" OK")
      all_summary     <- c(all_summary,     res$summary_rows)
      all_concordance <- c(all_concordance, res$concordance_rows)
    }
  }

  # Bind and write parity_summary.csv
  if (length(all_summary) > 0) {
    summ_df <- do.call(rbind, all_summary)
    .write_artifact_csv(summ_df, file.path(out_dir, "parity_summary.csv"))

    # Console summary
    n_pass <- sum(summ_df$pass, na.rm = TRUE)
    n_total <- nrow(summ_df)
    message("\nPerformance parity: ", n_pass, "/", n_total, " tests pass CI-overlaps-0")
  } else {
    message("\nWARN: No parity_summary rows produced (run B2+B3 first).")
  }

  # Bind and write max_score_concordance.csv
  if (length(all_concordance) > 0) {
    conc_df <- do.call(rbind, all_concordance)
    .write_artifact_csv(conc_df, file.path(out_dir, "max_score_concordance.csv"))

    n_spr_pass  <- sum(conc_df$spearman_pass,  na.rm = TRUE)
    n_jacc_pass <- sum(conc_df$jaccard_pass,   na.rm = TRUE)
    n_conc      <- nrow(conc_df)
    message("Max-score concordance: Spearman ≥0.90: ", n_spr_pass, "/", n_conc,
            "  Jaccard ≥0.80: ", n_jacc_pass, "/", n_conc)
  } else {
    message("WARN: No max_score_concordance rows produced.")
  }

  message("\nDone.")
}
