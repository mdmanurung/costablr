#!/usr/bin/env Rscript
# run_novel_coop.R — B5b: Cooperative-fusion rho sweep benchmark.
#
# Compares cooperative fusion (rho ∈ {0, 0.25, 0.5, 1, 2, 4}) vs early_fusion
# and late_fusion baselines on genuine multi-omic datasets (SSI, OOL-CyPr,
# OOL-CyPrMe). Uses the Python outer CV folds (from folds.csv) for identical
# splits across conditions. Reports:
#   - held-out AUC (binary) or R² (regression) per fold
#   - cross-fold selected-set stability (mean pairwise Jaccard)
#
# This benchmarks something Python STABL cannot do (cooperative fusion is an
# R-exclusive feature of stablr).
#
# Output:
#   papers/application-note/artifacts/coop_rho_sweep.csv
#     (dataset, condition, rho, fold_id, metric, n_selected, stability, runtime_sec)
#   papers/application-note/artifacts/coop_rho_sweep_summary.csv
#     (dataset, condition, rho, metric_mean, metric_ci_lo, metric_ci_hi,
#      stability_mean, n_folds)
#
# Usage (from repo root):
#   Rscript r-pkg/stablr/inst/benchmark/R/run_novel_coop.R \
#     [--data-dir   scratch/benchmark/data] \
#     [--ref-dir    scratch/benchmark/reference] \
#     [--out-dir    papers/application-note/artifacts] \
#     [--datasets   SSI,OOL-CyPr,OOL-CyPrMe] \
#     [--n-folds    20]   # how many outer folds to run (default: all)

suppressPackageStartupMessages({
  has_jsonlit <- requireNamespace("jsonlite", quietly = TRUE)
  has_yaml    <- requireNamespace("yaml",     quietly = TRUE)
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
  raw      <- commandArgs(trailingOnly = TRUE)
  data_dir <- "scratch/benchmark/data"
  ref_dir  <- "scratch/benchmark/reference"
  out_dir  <- "papers/application-note/artifacts"
  datasets <- c("SSI", "OOL-CyPr", "OOL-CyPrMe")
  n_folds  <- NULL   # NULL = all folds
  i <- 1L
  while (i <= length(raw)) {
    switch(raw[[i]],
      "--data-dir"  = { data_dir <- raw[[i + 1L]]; i <- i + 2L },
      "--ref-dir"   = { ref_dir  <- raw[[i + 1L]]; i <- i + 2L },
      "--out-dir"   = { out_dir  <- raw[[i + 1L]]; i <- i + 2L },
      "--datasets"  = { datasets <- strsplit(raw[[i + 1L]], ",")[[1L]]; i <- i + 2L },
      "--n-folds"   = { n_folds  <- as.integer(raw[[i + 1L]]); i <- i + 2L },
      { i <- i + 1L }
    )
  }
  list(data_dir = data_dir, ref_dir = ref_dir, out_dir = out_dir,
       datasets = datasets, n_folds = n_folds)
}

# ── Data loaders (same as run_stablr_pipeline.R) ──────────────────────────────
.read_csv_data <- function(path, row_col = 1L) {
  df <- utils::read.csv(path, row.names = row_col, check.names = FALSE)
  as.matrix(df)
}

.load_ssi <- function(data_dir) {
  base <- file.path(data_dir, "Biobank SSI")
  list(
    x_list = list(
      CyTOF      = .read_csv_data(file.path(base, "Training", "CyTOF.csv")),
      Proteomics = .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
    ),
    y = {
      y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
      setNames(as.integer(y_df[[1L]]), rownames(y_df))
    },
    family = "binomial", task_type = "binary", groups = NULL
  )
}

.load_ool_cypr <- function(data_dir) {
  base <- file.path(data_dir, "Onset of Labor")
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  list(
    x_list = list(
      CyTOF      = .read_csv_data(file.path(base, "Training", "CyTOF.csv")),
      Proteomics = .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
    ),
    y = {
      y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
      setNames(as.numeric(y_df[[1L]]), rownames(y_df))
    },
    family = "gaussian", task_type = "regression",
    groups = if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  )
}

.load_ool_cyprme <- function(data_dir) {
  base <- file.path(data_dir, "Onset of Labor")
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  list(
    x_list = list(
      CyTOF        = .read_csv_data(file.path(base, "Training", "CyTOF.csv")),
      Proteomics   = .read_csv_data(file.path(base, "Training", "Proteomics.csv")),
      Metabolomics = .read_csv_data(file.path(base, "Training", "Metabolomics.csv"))
    ),
    y = {
      y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
      setNames(as.numeric(y_df[[1L]]), rownames(y_df))
    },
    family = "gaussian", task_type = "regression",
    groups = if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  )
}

LOADERS <- list(
  "SSI"         = .load_ssi,
  "OOL-CyPr"   = .load_ool_cypr,
  "OOL-CyPrMe" = .load_ool_cyprme
)

# ── Fold reader (reuse from parity runner) ────────────────────────────────────
.load_python_folds <- function(ref_dir, ds_id) {
  path <- file.path(ref_dir, ds_id, "folds.csv")
  if (!file.exists(path)) return(NULL)
  df <- utils::read.csv(path, stringsAsFactors = FALSE)
  lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, ]
    parse_json_ids <- function(s) {
      if (has_jsonlit) jsonlite::fromJSON(s)
      else strsplit(gsub('\\[|\\]|"', "", s), ",\\s*")[[1L]]
    }
    list(
      fold_id       = row$fold_id,
      train_samples = as.character(parse_json_ids(row$train_samples)),
      test_samples  = as.character(parse_json_ids(row$test_samples))
    )
  })
}

# ── Stability (mean pairwise Jaccard) ─────────────────────────────────────────
.mean_pairwise_jaccard <- function(selected_list) {
  n <- length(selected_list)
  if (n < 2L) return(NA_real_)
  vals <- numeric(n * (n - 1L) / 2L)
  k <- 0L
  for (i in seq_len(n - 1L)) {
    for (j in seq(i + 1L, n)) {
      k <- k + 1L
      vals[[k]] <- jaccard_sets(selected_list[[i]], selected_list[[j]])
    }
  }
  mean(vals, na.rm = TRUE)
}

# ── One condition × fold run ───────────────────────────────────────────────────
.run_fold_condition <- function(fold, ds, condition, rho, family) {
  all_ids   <- rownames(ds$x_list[[1L]])
  train_ids <- intersect(as.character(fold$train_samples), all_ids)
  test_ids  <- intersect(as.character(fold$test_samples),  all_ids)
  if (length(train_ids) < 10L || length(test_ids) < 2L) return(NULL)

  x_train <- lapply(ds$x_list, function(m) m[train_ids, , drop = FALSE])
  x_test  <- lapply(ds$x_list, function(m) m[test_ids,  , drop = FALSE])
  y_train <- ds$y[train_ids]
  y_test  <- ds$y[test_ids]

  early_fusion <- condition == "early_fusion"
  late_fusion  <- condition == "late_fusion"
  coop_fusion  <- condition == "cooperative"

  t0 <- proc.time()[["elapsed"]]
  fit <- tryCatch(
    stabl_multiomic_train_validate(
      x_train_list    = x_train,
      y_train         = y_train,
      lambda_grid     = "auto",
      x_valid_list    = x_test,
      y_valid         = y_test,
      groups_train    = NULL,
      base_learner    = "lasso",
      family          = family,
      n_bootstraps    = 300L,
      artificial_type = "knockoff_equi",
      fdr_threshold_range = seq(0.1, 0.99, by = 0.01),
      sample_fraction = 0.5,
      replace         = FALSE,
      early_fusion    = early_fusion,
      late_fusion     = late_fusion,
      n_iter_lf       = 500L,
      cooperative_fusion = coop_fusion,
      rho             = if (coop_fusion) rho else NULL,
      random_state    = 42L,
      verbose         = FALSE
    ),
    error = function(e) { message("    FAILED: ", conditionMessage(e)); NULL }
  )
  runtime <- proc.time()[["elapsed"]] - t0
  if (is.null(fit)) return(NULL)

  # Extract prediction and selected features from the best available fusion
  if (coop_fusion) {
    pred_obj <- fit$cooperative_fusion
  } else if (late_fusion && !is.null(fit$late_fusion)) {
    pred_obj <- fit$late_fusion
  } else {
    pred_obj <- fit$early_fusion
  }

  predictions <- tryCatch(pred_obj$validation_predictions, error = function(e) NULL)
  # Selected features from STABL components
  all_selected <- unique(unlist(lapply(
    c(fit$per_omic, list(fit$early_fusion, fit$cooperative_fusion)),
    function(r) if (!is.null(r)) r$selected_features else NULL
  )))

  metric_val <- if (!is.null(predictions) && length(y_test) > 0) {
    if (family == "binomial")
      roc_auc_safe(as.numeric(predictions), as.integer(y_test))
    else
      r2_safe(as.numeric(predictions), as.numeric(y_test))
  } else NA_real_

  list(
    metric      = metric_val,
    selected    = all_selected,
    n_selected  = length(all_selected),
    runtime_sec = runtime
  )
}

# ── Define conditions ─────────────────────────────────────────────────────────
RHO_VALUES <- c(0, 0.25, 0.5, 1, 2, 4)

.build_conditions <- function() {
  conds <- list(
    list(condition = "early_fusion", rho = NA_real_),
    list(condition = "late_fusion",  rho = NA_real_)
  )
  for (rho in RHO_VALUES) {
    conds[[length(conds) + 1L]] <- list(condition = "cooperative", rho = rho)
  }
  conds
}

# ── Main ──────────────────────────────────────────────────────────────────────
if (!interactive()) {
  repo <- find_repo_root()
  cfg  <- .parse_args()

  data_dir <- if (startsWith(cfg$data_dir, "/")) cfg$data_dir
              else file.path(repo, cfg$data_dir)
  ref_dir  <- if (startsWith(cfg$ref_dir,  "/")) cfg$ref_dir
              else file.path(repo, cfg$ref_dir)
  out_dir  <- if (startsWith(cfg$out_dir,  "/")) cfg$out_dir
              else file.path(repo, cfg$out_dir)

  load_stablr_pkg(quiet = TRUE)

  conditions <- .build_conditions()
  all_rows <- list()

  for (ds_id in cfg$datasets) {
    message("\n", strrep("=", 60))
    message("Dataset: ", ds_id)

    ds <- tryCatch(LOADERS[[ds_id]](data_dir),
                   error = function(e) { message("ERROR: ", conditionMessage(e)); NULL })
    if (is.null(ds)) next

    folds <- .load_python_folds(ref_dir, ds_id)
    if (is.null(folds)) {
      message("WARN: No folds.csv — run Python reference first. Skipping.")
      next
    }
    if (!is.null(cfg$n_folds)) folds <- folds[seq_len(min(cfg$n_folds, length(folds)))]
    message("  n_folds=", length(folds), "  family=", ds$family)

    # Accumulate selected features per (condition, rho) across folds for stability
    sel_by_cond <- list()

    for (cond in conditions) {
      cond_key <- if (cond$condition == "cooperative")
        sprintf("coop_rho%.2f", cond$rho)
      else cond$condition

      message("  Condition: ", cond_key)
      sel_by_cond[[cond_key]] <- list()

      for (fi in seq_along(folds)) {
        cat(sprintf("\r    fold %d/%d", fi, length(folds)))
        res <- .run_fold_condition(
          folds[[fi]], ds, cond$condition, cond$rho, ds$family
        )
        if (!is.null(res)) {
          sel_by_cond[[cond_key]][[fi]] <- res$selected
          all_rows[[length(all_rows) + 1L]] <- data.frame(
            dataset    = ds_id,
            condition  = cond$condition,
            rho        = cond$rho,
            fold_id    = folds[[fi]]$fold_id,
            metric     = res$metric,
            n_selected = res$n_selected,
            stability  = NA_real_,  # filled after all folds
            runtime_sec = res$runtime_sec,
            stringsAsFactors = FALSE
          )
        }
      }
      cat("\n")

      # Fill in stability for this condition
      stab <- .mean_pairwise_jaccard(
        Filter(Negate(is.null), sel_by_cond[[cond_key]])
      )
      cond_rows_idx <- which(
        vapply(all_rows, function(r) {
          r$dataset == ds_id &&
          r$condition == cond$condition &&
          isTRUE(all.equal(r$rho, cond$rho))
        }, logical(1L))
      )
      for (idx in cond_rows_idx) {
        all_rows[[idx]]$stability <- stab
      }
      message(sprintf("    stability=%.3f  median_metric=%.3f",
                      stab,
                      median(vapply(all_rows[cond_rows_idx],
                                    function(r) r$metric, numeric(1L)), na.rm = TRUE)))
    }
  }

  if (length(all_rows) == 0L) {
    message("No results produced.")
    quit(status = 1L)
  }

  result_df <- do.call(rbind, all_rows)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  # Per-fold output
  fold_path <- file.path(out_dir, "coop_rho_sweep.csv")
  utils::write.csv(result_df, fold_path, row.names = FALSE)
  message("Written: ", fold_path)

  # Summary with bootstrap CIs per (dataset, condition, rho)
  keys <- unique(result_df[, c("dataset", "condition", "rho")])
  summ_rows <- lapply(seq_len(nrow(keys)), function(i) {
    sub <- result_df[
      result_df$dataset    == keys$dataset[[i]] &
      result_df$condition  == keys$condition[[i]] &
      isTRUE(all.equal(result_df$rho, keys$rho[[i]])),
    ]
    ci <- bootstrap_ci(sub$metric, B = 1000L, seed = 42L)
    data.frame(
      dataset       = keys$dataset[[i]],
      condition     = keys$condition[[i]],
      rho           = keys$rho[[i]],
      metric_mean   = ci[["mean"]],
      metric_ci_lo  = ci[["ci_lo"]],
      metric_ci_hi  = ci[["ci_hi"]],
      stability_mean = mean(sub$stability, na.rm = TRUE),
      n_folds       = nrow(sub),
      stringsAsFactors = FALSE
    )
  })
  summ_df <- do.call(rbind, summ_rows)

  summ_path <- file.path(out_dir, "coop_rho_sweep_summary.csv")
  utils::write.csv(summ_df, summ_path, row.names = FALSE)
  message("Written: ", summ_path)

  message("\nDone.")
}
