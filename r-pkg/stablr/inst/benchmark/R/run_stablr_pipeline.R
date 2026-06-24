#!/usr/bin/env Rscript
# run_stablr_pipeline.R — B3: Matched stablr run for the cross-language parity benchmark.
#
# Replays the exact outer CV folds written by run_reference.py (folds.csv in the
# Python reference output tree) and calls stabl_multiomic_train_validate once per
# fold × base_learner, using knockoff_equi (model-X equicorrelated) to match the
# Python STABL artificial type.
#
# Output (per dataset, under scratch/benchmark/stablr_out/<dataset_id>/):
#   <fold_id>_<learner>.rds  — list(fold_id, learner, train_ids, test_ids,
#                                    selected, max_scores, predictions, y_test,
#                                    family, runtime_sec)
#   predictions.csv          — sample × learner: held-out predicted scores (aggregated)
#   selected.csv             — feature × learner: fraction of folds each feature selected
#   max_scores.csv           — feature × learner: mean max-score across folds
#   summary.csv              — learner × metric: AUC or R² per fold (long format)
#
# Usage (from repo root):
#   Rscript r-pkg/stablr/inst/benchmark/R/run_stablr_pipeline.R \
#     [--data-dir   scratch/benchmark/data] \
#     [--ref-dir    scratch/benchmark/reference] \
#     [--out-dir    scratch/benchmark/stablr_out] \
#     [--datasets   COVID-19,CFRNA,SSI,DREAM,OOL-CyPr,OOL-CyPrMe] \
#     [--learners   lasso,alasso,en] \
#     [--n-workers  1] \
#     [--dry-run]

suppressPackageStartupMessages({
  has_yaml    <- requireNamespace("yaml",    quietly = TRUE)
  has_jsonlit <- requireNamespace("jsonlite", quietly = TRUE)
})

# ── Locate common utilities ───────────────────────────────────────────────────
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
  out_dir  <- "scratch/benchmark/stablr_out"
  datasets <- NULL
  learners <- c("lasso", "alasso", "en")
  n_workers <- 1L
  dry_run   <- FALSE
  i <- 1L
  while (i <= length(raw)) {
    switch(raw[[i]],
      "--data-dir"  = { data_dir  <- raw[[i + 1L]]; i <- i + 2L },
      "--ref-dir"   = { ref_dir   <- raw[[i + 1L]]; i <- i + 2L },
      "--out-dir"   = { out_dir   <- raw[[i + 1L]]; i <- i + 2L },
      "--datasets"  = { datasets  <- strsplit(raw[[i + 1L]], ",")[[1L]]; i <- i + 2L },
      "--learners"  = { learners  <- strsplit(raw[[i + 1L]], ",")[[1L]]; i <- i + 2L },
      "--n-workers" = { n_workers <- as.integer(raw[[i + 1L]]); i <- i + 2L },
      "--dry-run"   = { dry_run   <- TRUE; i <- i + 1L },
      { i <- i + 1L }
    )
  }
  list(data_dir = data_dir, ref_dir = ref_dir, out_dir = out_dir,
       datasets = datasets, learners = learners,
       n_workers = n_workers, dry_run = dry_run)
}

# ── Dataset loaders ───────────────────────────────────────────────────────────
# Each returns list(x_list, y, groups, family, task_type, x_valid_list, y_valid)
# matching the structure Python's load_* functions return.

.read_csv_data <- function(path, row_col = 1L) {
  df <- utils::read.csv(path, row.names = row_col, check.names = FALSE)
  as.matrix(df)
}

load_covid_r <- function(data_dir) {
  base <- file.path(data_dir, "COVID-19")
  x    <- .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
  y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y    <- setNames(as.integer(y_df[[1L]]), rownames(y_df))
  # Validation set
  xv   <- .read_csv_data(file.path(base, "Validation", "Proteomics.csv"))
  yv_df <- utils::read.csv(file.path(base, "Validation", "Outcome.csv"), row.names = 1L)
  yv   <- setNames(as.integer(yv_df[[1L]]), rownames(yv_df))
  list(x_list = list(Proteomics = x), y = y, groups = NULL,
       family = "binomial", task_type = "binary",
       x_valid_list = list(Proteomics = xv), y_valid = yv)
}

load_cfrna_r <- function(data_dir) {
  base <- file.path(data_dir, "CFRNA")
  x    <- .read_csv_data(file.path(base, "Training", "CFRNA.csv"))
  # log2(x+1) transform (mirrors Python load_cfrna)
  x    <- log2(x + 1)
  y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y    <- setNames(as.integer(y_df[[1L]]), rownames(y_df))
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  groups <- if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  list(x_list = list(CFRNA = x), y = y, groups = groups,
       family = "binomial", task_type = "binary",
       x_valid_list = NULL, y_valid = NULL)
}

load_ssi_r <- function(data_dir) {
  base <- file.path(data_dir, "Biobank SSI")
  xc   <- .read_csv_data(file.path(base, "Training", "CyTOF.csv"))
  xp   <- .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
  y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y    <- setNames(as.integer(y_df[[1L]]), rownames(y_df))
  list(x_list = list(CyTOF = xc, Proteomics = xp), y = y, groups = NULL,
       family = "binomial", task_type = "binary",
       x_valid_list = NULL, y_valid = NULL)
}

load_dream_r <- function(data_dir) {
  base <- file.path(data_dir, "Dream")
  # Phylotype + Taxonomy (column "/" → "_")
  read_and_fix <- function(f) {
    m <- .read_csv_data(file.path(base, "Training", f))
    colnames(m) <- gsub("/", "_", colnames(m), fixed = TRUE)
    m
  }
  xph <- read_and_fix("Phylotype.csv")
  xtx <- read_and_fix("Taxonomy.csv")
  y_df  <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y     <- setNames(as.integer(y_df[[1L]]), rownames(y_df))
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  groups <- if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  list(x_list = list(Phylotype = xph, Taxonomy = xtx), y = y, groups = groups,
       family = "binomial", task_type = "binary",
       x_valid_list = NULL, y_valid = NULL)
}

load_ool_cypr_r <- function(data_dir) {
  base <- file.path(data_dir, "Onset of Labor")
  xc   <- .read_csv_data(file.path(base, "Training", "CyTOF.csv"))
  xp   <- .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
  y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y    <- setNames(as.numeric(y_df[[1L]]), rownames(y_df))
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  groups <- if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  # Validation set (CyTOF + Proteomics only)
  xvc <- tryCatch(.read_csv_data(file.path(base, "Validation", "CyTOF.csv")),      error = function(e) NULL)
  xvp <- tryCatch(.read_csv_data(file.path(base, "Validation", "Proteomics.csv")), error = function(e) NULL)
  yv_df <- tryCatch(utils::read.csv(file.path(base, "Validation", "Outcome.csv"), row.names = 1L), error = function(e) NULL)
  xvl <- if (!is.null(xvc) && !is.null(xvp)) list(CyTOF = xvc, Proteomics = xvp) else NULL
  yv  <- if (!is.null(yv_df)) setNames(as.numeric(yv_df[[1L]]), rownames(yv_df)) else NULL
  list(x_list = list(CyTOF = xc, Proteomics = xp), y = y, groups = groups,
       family = "gaussian", task_type = "regression",
       x_valid_list = xvl, y_valid = yv)
}

load_ool_cyprme_r <- function(data_dir) {
  base <- file.path(data_dir, "Onset of Labor")
  xc   <- .read_csv_data(file.path(base, "Training", "CyTOF.csv"))
  xp   <- .read_csv_data(file.path(base, "Training", "Proteomics.csv"))
  xm   <- .read_csv_data(file.path(base, "Training", "Metabolomics.csv"))
  y_df <- utils::read.csv(file.path(base, "Training", "Outcome.csv"), row.names = 1L)
  y    <- setNames(as.numeric(y_df[[1L]]), rownames(y_df))
  id_df <- tryCatch(
    utils::read.csv(file.path(base, "Training", "ID.csv"), row.names = 1L),
    error = function(e) NULL
  )
  groups <- if (!is.null(id_df)) setNames(id_df[[1L]], rownames(id_df)) else NULL
  list(x_list = list(CyTOF = xc, Proteomics = xp, Metabolomics = xm),
       y = y, groups = groups,
       family = "gaussian", task_type = "regression",
       x_valid_list = NULL, y_valid = NULL)
}

DATASET_LOADERS <- list(
  "COVID-19"    = load_covid_r,
  "CFRNA"       = load_cfrna_r,
  "SSI"         = load_ssi_r,
  "DREAM"       = load_dream_r,
  "OOL-CyPr"   = load_ool_cypr_r,
  "OOL-CyPrMe" = load_ool_cyprme_r
)

# ── Lambda grid helpers ───────────────────────────────────────────────────────
# Match the Python protocol from datasets.yaml / run_cv_*.py.
# Python STABL uses linspace for lasso/alasso C, logspace for CV estimators.
# R stabl_fit lambda_grid is a data.frame (one row per lambda).

.make_lambda_grid <- function(param_name, values) {
  stats::setNames(data.frame(values), param_name)
}

.dataset_lambda_grids <- function(ds_cfg, learner) {
  # ds_cfg: one list element from datasets.yaml
  # Returns lambda_grid data.frame for the STABL run (not CV tuning grid).
  # "auto" is safe but this gives exact Python parity on the lambda sequence.
  task <- ds_cfg$task_type   # "binary" or "regression"

  if (task == "binary") {
    # Python: stabl_lasso uses linspace(0.01, 1, 10) for C
    lo <- ds_cfg$stabl_lasso_lambda_grid_logspace[[1L]]
    hi <- ds_cfg$stabl_lasso_lambda_grid_logspace[[2L]]
    n  <- ds_cfg$stabl_lasso_lambda_grid_logspace[[3L]]
    lasso_vals <- 10^seq(lo, hi, length.out = n)

    lo2 <- ds_cfg$stabl_alasso_lambda_grid_logspace[[1L]]
    hi2 <- ds_cfg$stabl_alasso_lambda_grid_logspace[[2L]]
    n2  <- ds_cfg$stabl_alasso_lambda_grid_logspace[[3L]]
    alasso_vals <- 10^seq(lo2, hi2, length.out = n2)

    param <- "C"
  } else {
    lo <- ds_cfg$stabl_lasso_lambda_grid_logspace[[1L]]
    hi <- ds_cfg$stabl_lasso_lambda_grid_logspace[[2L]]
    n  <- ds_cfg$stabl_lasso_lambda_grid_logspace[[3L]]
    lasso_vals <- 10^seq(lo, hi, length.out = n)

    lo2 <- ds_cfg$stabl_alasso_lambda_grid_logspace[[1L]]
    hi2 <- ds_cfg$stabl_alasso_lambda_grid_logspace[[2L]]
    n2  <- ds_cfg$stabl_alasso_lambda_grid_logspace[[3L]]
    alasso_vals <- 10^seq(lo2, hi2, length.out = n2)

    param <- "alpha"
  }

  switch(learner,
    lasso  = .make_lambda_grid(param, lasso_vals),
    alasso = .make_lambda_grid(param, alasso_vals),
    en     = "auto",    # ElasticNet: let stablr auto-select
    stop("Unknown learner: ", learner, call. = FALSE)
  )
}

# ── Fold replay ───────────────────────────────────────────────────────────────
.load_python_folds <- function(ref_dir, ds_id) {
  folds_path <- file.path(ref_dir, ds_id, "folds.csv")
  if (!file.exists(folds_path)) return(NULL)
  df <- utils::read.csv(folds_path, stringsAsFactors = FALSE)
  lapply(seq_len(nrow(df)), function(i) {
    row <- df[i, ]
    list(
      fold_id      = row$fold_id,
      train_samples = if (has_jsonlit) jsonlite::fromJSON(row$train_samples)
                      else strsplit(gsub('\\[|\\]|"', "", row$train_samples), ",\\s*")[[1L]],
      test_samples  = if (has_jsonlit) jsonlite::fromJSON(row$test_samples)
                      else strsplit(gsub('\\[|\\]|"', "", row$test_samples), ",\\s*")[[1L]]
    )
  })
}

# ── Per-fold runner ───────────────────────────────────────────────────────────
.run_one_fold <- function(fold, learner, ds, ds_cfg,
                          n_workers, artificial_type) {
  family    <- ds$family
  n_boot    <- ds_cfg$stabl_n_bootstraps[[learner]] %||% 1000L
  lgrid     <- .dataset_lambda_grids(ds_cfg, learner)

  train_ids <- as.character(fold$train_samples)
  test_ids  <- as.character(fold$test_samples)

  # Subset — keep only IDs present in the actual data
  all_ids   <- rownames(ds$x_list[[1L]])
  train_ids <- intersect(train_ids, all_ids)
  test_ids  <- intersect(test_ids, all_ids)

  x_train <- lapply(ds$x_list, function(m) m[train_ids, , drop = FALSE])
  x_test  <- lapply(ds$x_list, function(m) m[test_ids,  , drop = FALSE])
  y_train <- ds$y[train_ids]
  y_test  <- ds$y[test_ids]
  groups_train <- if (!is.null(ds$groups)) ds$groups[train_ids] else NULL

  base_learner <- switch(learner,
    lasso  = "lasso",
    alasso = "alasso",
    en     = "elastic_net",
    stop("Unknown learner: ", learner, call. = FALSE)
  )
  l1_ratio <- if (learner == "en") 0.5 else NULL

  t0 <- proc.time()[["elapsed"]]
  fit <- stabl_multiomic_train_validate(
    x_train_list    = x_train,
    y_train         = y_train,
    lambda_grid     = lgrid,
    x_valid_list    = x_test,
    y_valid         = y_test,
    groups_train    = groups_train,
    base_learner    = base_learner,
    family          = family,
    n_bootstraps    = n_boot,
    artificial_type = artificial_type,
    sample_fraction = 0.5,
    replace         = FALSE,
    fdr_threshold_range = seq(0.1, 0.99, by = 0.01),
    early_fusion    = TRUE,
    late_fusion     = TRUE,
    n_iter_lf       = 1000L,
    l1_ratio        = l1_ratio,
    random_state    = 42L,
    workers         = n_workers,
    verbose         = FALSE
  )
  runtime <- proc.time()[["elapsed"]] - t0

  # Extract normalised outputs from the fit object
  # fit$per_omic is a list (omic → stabl_fit result); fit$early_fusion, fit$late_fusion
  stabl_results <- c(fit$per_omic, fit["early_fusion"], fit["late_fusion"])
  stabl_results <- Filter(Negate(is.null), stabl_results)

  selected_list  <- lapply(stabl_results, function(r) r$selected_features)
  max_score_list <- lapply(stabl_results, function(r) {
    sc <- r$stability_scores
    if (is.null(sc)) return(NULL)
    apply(sc, 1L, max, na.rm = TRUE)
  })

  # Predictions: use validation predictions from late_fusion if available; fall back to EF
  predictions <- tryCatch({
    pf <- fit$late_fusion$validation_predictions
    if (is.null(pf)) fit$early_fusion$validation_predictions else pf
  }, error = function(e) NULL)

  list(
    fold_id      = fold$fold_id,
    learner      = learner,
    train_ids    = train_ids,
    test_ids     = test_ids,
    selected     = selected_list,
    max_scores   = max_score_list,
    predictions  = predictions,
    y_test       = y_test,
    family       = family,
    runtime_sec  = runtime,
    fit          = fit   # full fit for later inspection
  )
}

# NULL-coalescing
`%||%` <- function(a, b) if (!is.null(a)) a else b

# ── Aggregation helpers ───────────────────────────────────────────────────────
.aggregate_folds <- function(fold_results, learner, task_type, out_dir) {
  # predictions.csv: test-set predictions aggregated across folds
  pred_rows <- lapply(fold_results, function(fr) {
    preds <- fr$predictions
    if (is.null(preds)) return(NULL)
    df <- data.frame(
      sample_id  = fr$test_ids,
      fold_id    = fr$fold_id,
      prediction = as.numeric(preds),
      y_true     = as.numeric(fr$y_test)
    )
    df$learner <- learner
    df
  })
  pred_df <- do.call(rbind, Filter(Negate(is.null), pred_rows))
  if (!is.null(pred_df) && nrow(pred_df) > 0) {
    utils::write.csv(pred_df,
                     file.path(out_dir, paste0("predictions_", learner, ".csv")),
                     row.names = FALSE)
  }

  # selected: binary per feature (1 if selected in a majority of folds)
  sel_per_fold <- lapply(fold_results, function(fr) fr$selected)
  all_features <- unique(unlist(lapply(sel_per_fold, function(s) unlist(lapply(s, names)))))
  if (length(all_features) > 0) {
    sel_mat <- matrix(0, nrow = length(all_features),
                      ncol = length(sel_per_fold),
                      dimnames = list(all_features, NULL))
    for (fi in seq_along(sel_per_fold)) {
      sel_now <- unique(unlist(sel_per_fold[[fi]]))
      hit     <- intersect(sel_now, all_features)
      if (length(hit)) sel_mat[hit, fi] <- 1L
    }
    sel_mean <- rowMeans(sel_mat)
    sel_df   <- data.frame(feature = all_features,
                           selection_rate = sel_mean,
                           learner = learner)
    utils::write.csv(sel_df,
                     file.path(out_dir, paste0("selected_", learner, ".csv")),
                     row.names = FALSE)
  }

  # summary: per-fold metric
  metric_rows <- lapply(fold_results, function(fr) {
    if (is.null(fr$predictions) || length(fr$y_test) == 0) return(NULL)
    metric <- if (task_type == "binary")
      roc_auc_safe(as.numeric(fr$predictions), as.integer(fr$y_test))
    else
      r2_safe(as.numeric(fr$predictions), as.numeric(fr$y_test))
    data.frame(fold_id = fr$fold_id, learner = learner, metric = metric,
               runtime_sec = fr$runtime_sec)
  })
  metric_df <- do.call(rbind, Filter(Negate(is.null), metric_rows))
  if (!is.null(metric_df) && nrow(metric_df) > 0) {
    utils::write.csv(metric_df,
                     file.path(out_dir, paste0("summary_", learner, ".csv")),
                     row.names = FALSE)
  }

  invisible(NULL)
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

  all_datasets <- names(DATASET_LOADERS)
  datasets <- if (is.null(cfg$datasets)) all_datasets
              else cfg$datasets
  unknown <- setdiff(datasets, all_datasets)
  if (length(unknown)) stop("Unknown datasets: ", paste(unknown, collapse = ", "), call. = FALSE)

  load_stablr_pkg(quiet = TRUE)

  # Load datasets.yaml for per-dataset config (lambda grids, n_bootstraps)
  config_path <- file.path(repo, "r-pkg", "stablr", "inst", "benchmark",
                            "config", "datasets.yaml")
  ds_configs  <- stats::setNames(
    read_dataset_config(config_path),
    vapply(read_dataset_config(config_path), function(d) d$id, character(1L))
  )

  for (ds_id in datasets) {
    message("\n", strrep("=", 60))
    message("Dataset: ", ds_id, if (cfg$dry_run) "  [DRY RUN]" else "")
    message(strrep("=", 60))

    ds_out <- file.path(out_dir, ds_id)
    dir.create(ds_out, recursive = TRUE, showWarnings = FALSE)

    # Load R-side data
    message("  Loading data from: ", data_dir)
    ds <- tryCatch(
      DATASET_LOADERS[[ds_id]](data_dir),
      error = function(e) { message("  ERROR loading data: ", conditionMessage(e)); NULL }
    )
    if (is.null(ds)) next

    message("  Samples: ", nrow(ds$x_list[[1L]]),
            "   Omics: ", paste(names(ds$x_list), collapse = ", "))
    message("  Family: ", ds$family)

    # Load Python fold splits for Tier-A parity
    folds <- .load_python_folds(ref_dir, ds_id)
    if (is.null(folds)) {
      message("  WARN: No folds.csv found in ", file.path(ref_dir, ds_id),
              " — skipping (run Python reference first).")
      next
    }
    message("  Outer folds: ", length(folds))

    if (cfg$dry_run) {
      message("  [dry-run] Would run ", length(folds), " folds × ",
              length(cfg$learners), " learners")
      next
    }

    ds_cfg <- ds_configs[[ds_id]]
    artificial_type <- "knockoff_equi"    # model-X for Python parity

    for (learner in cfg$learners) {
      message("\n  Learner: ", learner)
      fold_results <- vector("list", length(folds))

      for (fi in seq_along(folds)) {
        fold <- folds[[fi]]
        message("    fold ", fold$fold_id + 1L, "/", length(folds), " ...",
                appendLF = FALSE)
        rds_path <- file.path(ds_out,
                              sprintf("fold%04d_%s.rds", fold$fold_id, learner))
        if (file.exists(rds_path)) {
          result <- readRDS(rds_path)
          message(" (cached)")
        } else {
          result <- tryCatch(
            .run_one_fold(fold, learner, ds, ds_cfg,
                          cfg$n_workers, artificial_type),
            error = function(e) {
              message(" FAILED: ", conditionMessage(e))
              NULL
            }
          )
          if (!is.null(result)) {
            saveRDS(result, rds_path)
            message(sprintf(" %.1fs", result$runtime_sec))
          }
        }
        fold_results[[fi]] <- result
      }

      # Aggregate across folds
      fold_results_ok <- Filter(Negate(is.null), fold_results)
      if (length(fold_results_ok) > 0) {
        .aggregate_folds(fold_results_ok, learner, ds$task_type, ds_out)
        message("  Aggregated ", length(fold_results_ok), " folds for ", learner)
      }
    }

    message("\n  Dataset ", ds_id, " complete → ", ds_out)
  }

  message("\nDone.")
}
