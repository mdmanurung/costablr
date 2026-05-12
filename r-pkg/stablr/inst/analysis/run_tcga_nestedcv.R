#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  if (file.exists("r-pkg/stablr/DESCRIPTION") &&
      requireNamespace("pkgload", quietly = TRUE)) {
    pkgload::load_all("r-pkg/stablr", quiet = TRUE)
  } else {
    library(stablr)
  }
})

tcga_cache_complete <- function(path) {
  if (!file.exists(path)) return(FALSE)
  obj <- tryCatch(readRDS(path), error = function(e) NULL)
  is.list(obj) &&
    all(c("stablr", "diablo", "performance", "feature_comparison") %in% names(obj)) &&
    nrow(obj$performance) > 0L
}

tcga_load_two_block <- function() {
  if (!requireNamespace("mixOmics", quietly = TRUE)) {
    stop("mixOmics is required for the TCGA nested-CV analysis.", call. = FALSE)
  }
  data("breast.TCGA", package = "mixOmics", envir = environment())

  x_mrna <- rbind(
    breast.TCGA$data.train$mrna,
    breast.TCGA$data.test$mrna
  )
  x_mirna <- rbind(
    breast.TCGA$data.train$mirna,
    breast.TCGA$data.test$mirna
  )
  y <- factor(c(
    as.character(breast.TCGA$data.train$subtype),
    as.character(breast.TCGA$data.test$subtype)
  ), levels = c("Basal", "Her2", "LumA"))

  ids <- make.unique(c(
    rownames(breast.TCGA$data.train$mrna),
    rownames(breast.TCGA$data.test$mrna)
  ))
  rownames(x_mrna) <- ids
  rownames(x_mirna) <- ids
  names(y) <- ids

  split_label <- c(
    rep("mixOmics_train", nrow(breast.TCGA$data.train$mrna)),
    rep("mixOmics_test", nrow(breast.TCGA$data.test$mrna))
  )
  names(split_label) <- ids

  list(
    x_list = list(mRNA = as.matrix(x_mrna), miRNA = as.matrix(x_mirna)),
    y = y,
    original_split = split_label
  )
}

tcga_metrics <- function(truth, predicted) {
  truth <- factor(truth)
  predicted <- factor(predicted, levels = levels(truth))
  tab <- table(truth = truth, predicted = predicted)
  recall <- diag(tab) / pmax(rowSums(tab), 1L)
  precision <- diag(tab) / pmax(colSums(tab), 1L)
  f1 <- ifelse(precision + recall > 0, 2 * precision * recall / (precision + recall), 0)
  data.frame(
    accuracy = sum(diag(tab)) / sum(tab),
    balanced_error_rate = 1 - mean(recall),
    macro_f1 = mean(f1),
    stringsAsFactors = FALSE
  )
}

tcga_diablo_design <- function(block_names, weight = 0.1) {
  design <- matrix(weight, nrow = length(block_names), ncol = length(block_names),
                   dimnames = list(block_names, block_names))
  diag(design) <- 0
  design
}

tcga_choose_diablo_ncomp <- function(x_train, y_train, design, ncomp_grid,
                                     inner_v, inner_repeats, seed) {
  max_ncomp <- max(ncomp_grid)
  fit <- mixOmics::block.plsda(x_train, y_train, ncomp = max_ncomp, design = design)
  perf <- tryCatch(
    mixOmics::perf(
      fit,
      validation = "Mfold",
      folds = inner_v,
      nrepeat = inner_repeats,
      dist = "centroids.dist",
      progressBar = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(perf) || is.null(perf$choice.ncomp$WeightedVote)) {
    return(min(2L, max_ncomp))
  }
  choice <- perf$choice.ncomp$WeightedVote
  chosen <- suppressWarnings(as.integer(choice["Overall.BER", "centroids.dist"]))
  if (is.na(chosen)) min(2L, max_ncomp) else max(1L, min(chosen, max_ncomp))
}

tcga_extract_diablo_features <- function(fit, blocks, ncomp, repeat_id, fold_id) {
  rows <- list()
  k <- 1L
  for (block in blocks) {
    for (comp in seq_len(ncomp)) {
      sv <- mixOmics::selectVar(fit, block = block, comp = comp)
      obj <- sv[[block]]
      if (is.null(obj)) next

      if (is.list(obj) && !is.data.frame(obj) && !is.null(obj$name)) {
        feature <- as.character(obj$name)
        if (is.data.frame(obj$value) && ncol(obj$value) > 0L) {
          score <- abs(as.numeric(obj$value[[1L]]))
        } else {
          score <- rep(NA_real_, length(feature))
        }
      } else if (is.data.frame(obj)) {
        feature <- if ("name" %in% names(obj)) as.character(obj$name) else rownames(obj)
        score_col <- intersect(c("value", "loading", "loadings", "importance"), names(obj))
        score <- if (length(score_col)) abs(as.numeric(obj[[score_col[[1L]]]])) else NA_real_
      } else if (is.matrix(obj)) {
        feature <- rownames(obj)
        score <- if (ncol(obj) > 0L) abs(as.numeric(obj[, 1L])) else NA_real_
      } else {
        feature <- names(obj)
        if (is.null(feature)) feature <- as.character(obj)
        score <- suppressWarnings(abs(as.numeric(obj)))
        if (length(score) != length(feature)) score <- rep(NA_real_, length(feature))
      }

      keep <- !is.na(feature) & nzchar(feature)
      if (!any(keep)) next
      rows[[k]] <- data.frame(
        method = "DIABLO",
        candidate = "DIABLO",
        repeat_id = repeat_id,
        fold = sub("^.*_", "", fold_id),
        fold_id = fold_id,
        block = block,
        feature = feature[keep],
        component = comp,
        score = score[keep],
        stringsAsFactors = FALSE
      )
      k <- k + 1L
    }
  }
  if (length(rows) == 0L) {
    return(data.frame(
      method = character(), candidate = character(), repeat_id = integer(),
      fold = character(), fold_id = character(), block = character(),
      feature = character(), component = integer(), score = numeric(),
      stringsAsFactors = FALSE
    ))
  }
  unique(do.call(rbind, rows))
}

tcga_run_diablo_nested <- function(x_list, y, outer_folds, inner_v = 5L,
                                   inner_repeats = 10L, ncomp_grid = 1:5,
                                   keepx_grid = NULL, workers = 6L,
                                   random_state = 42L) {
  if (!requireNamespace("mixOmics", quietly = TRUE)) {
    stop("mixOmics is required for DIABLO.", call. = FALSE)
  }
  if (!requireNamespace("BiocParallel", quietly = TRUE)) {
    stop("BiocParallel is required for robust DIABLO tuning.", call. = FALSE)
  }
  if (is.null(keepx_grid)) {
    keepx_grid <- list(
      mRNA = c(5:10, seq(15, 50, 5)),
      miRNA = c(5:10, seq(12, 40, 4))
    )
  }

  design <- tcga_diablo_design(names(x_list), weight = 0.1)
  predictions <- list()
  diagnostics <- list()
  features <- list()

  for (i in seq_along(outer_folds)) {
    fold <- outer_folds[[i]]
    train_ids <- fold$train_ids
    valid_ids <- fold$valid_ids
    x_train <- lapply(x_list, function(x) x[train_ids, , drop = FALSE])
    x_valid <- lapply(x_list, function(x) x[valid_ids, , drop = FALSE])
    y_train <- droplevels(y[train_ids])

    set.seed(random_state + i * 1009L)
    ncomp <- tcga_choose_diablo_ncomp(
      x_train = x_train,
      y_train = y_train,
      design = design,
      ncomp_grid = ncomp_grid,
      inner_v = inner_v,
      inner_repeats = inner_repeats,
      seed = random_state + i
    )

    bp <- BiocParallel::SnowParam(workers = workers, type = "SOCK")
    tune <- mixOmics::tune.block.splsda(
      X = x_train,
      Y = y_train,
      ncomp = ncomp,
      test.keepX = keepx_grid,
      design = design,
      validation = "Mfold",
      folds = inner_v,
      nrepeat = inner_repeats,
      dist = "centroids.dist",
      measure = "BER",
      weighted = TRUE,
      progressBar = FALSE,
      BPPARAM = bp,
      seed = random_state + i * 2003L
    )
    keepx <- tune$choice.keepX

    fit <- mixOmics::block.splsda(
      X = x_train,
      Y = y_train,
      ncomp = ncomp,
      keepX = keepx,
      design = design
    )
    pred <- predict(fit, newdata = x_valid)
    pred_class <- as.character(pred$WeightedVote$centroids.dist[, ncomp])

    predictions[[i]] <- data.frame(
      repeat_id = fold[["repeat"]],
      fold = fold$fold,
      fold_id = fold$fold_id,
      sample_id = valid_ids,
      truth = as.character(y[valid_ids]),
      predicted = pred_class,
      selected_candidate = "DIABLO",
      stringsAsFactors = FALSE
    )
    diagnostics[[i]] <- data.frame(
      repeat_id = fold[["repeat"]],
      fold = fold$fold,
      fold_id = fold$fold_id,
      ncomp = ncomp,
      keepX = paste(names(keepx), vapply(keepx, paste, character(1L), collapse = "/"),
                    sep = "=", collapse = ";"),
      stringsAsFactors = FALSE
    )
    features[[i]] <- tcga_extract_diablo_features(
      fit = fit,
      blocks = names(x_list),
      ncomp = ncomp,
      repeat_id = fold[["repeat"]],
      fold_id = fold$fold_id
    )
  }

  pred_df <- do.call(rbind, predictions)
  list(
    outer_predictions = pred_df,
    diagnostics = do.call(rbind, diagnostics),
    selected_features = do.call(rbind, features),
    performance = tcga_metrics(pred_df$truth, pred_df$predicted)
  )
}

tcga_feature_recurrence <- function(features, n_folds) {
  if (nrow(features) == 0L) {
    return(data.frame(
      method = character(), block = character(), feature = character(),
      n_folds = integer(), recurrence = numeric(), mean_score = numeric()
    ))
  }
  agg <- aggregate(
    list(n_folds = features$fold_id, mean_score = features$score),
    by = list(method = features$method, block = features$block, feature = features$feature),
    FUN = function(x) length(unique(x))
  )
  score <- aggregate(
    list(mean_score = features$score),
    by = list(method = features$method, block = features$block, feature = features$feature),
    FUN = function(x) mean(as.numeric(x), na.rm = TRUE)
  )
  agg$mean_score <- NULL
  out <- merge(agg, score, by = c("method", "block", "feature"), all.x = TRUE)
  out$recurrence <- out$n_folds / n_folds
  out[order(out$block, -out$recurrence, out$method, out$feature), ]
}

tcga_compare_feature_sets <- function(stabl_features, diablo_features, n_folds) {
  all_cols <- union(names(stabl_features), names(diablo_features))
  for (nm in setdiff(all_cols, names(stabl_features))) stabl_features[[nm]] <- NA
  for (nm in setdiff(all_cols, names(diablo_features))) diablo_features[[nm]] <- NA
  stabl_features <- stabl_features[, all_cols, drop = FALSE]
  diablo_features <- diablo_features[, all_cols, drop = FALSE]
  all_features <- rbind(stabl_features, diablo_features)
  recurrence <- tcga_feature_recurrence(all_features, n_folds = n_folds)
  blocks <- sort(unique(recurrence$block))
  overlap <- lapply(blocks, function(block) {
    s <- unique(recurrence$feature[recurrence$method == "stablr" & recurrence$block == block])
    d <- unique(recurrence$feature[recurrence$method == "DIABLO" & recurrence$block == block])
    inter <- intersect(s, d)
    union_set <- union(s, d)
    data.frame(
      block = block,
      stablr_n = length(s),
      diablo_n = length(d),
      shared_n = length(inter),
      jaccard = if (length(union_set) == 0L) NA_real_ else length(inter) / length(union_set),
      stringsAsFactors = FALSE
    )
  })
  list(
    recurrence = recurrence,
    overlap = do.call(rbind, overlap)
  )
}

run_tcga_head_to_head <- function(cache_path,
                                  force = FALSE,
                                  smoke = FALSE,
                                  cv_workers = 1L,
                                  stabl_workers = 6L,
                                  diablo_workers = 6L) {
  if (!force && tcga_cache_complete(cache_path)) {
    message("Cache is complete: ", cache_path)
    return(readRDS(cache_path))
  }
  if (!requireNamespace("knockoff", quietly = TRUE)) {
    stop("The TCGA stablr arm uses artificial_type = 'knockoff'; install knockoff first.",
         call. = FALSE)
  }

  dat <- tcga_load_two_block()
  outer_v <- if (smoke) 2L else 5L
  outer_repeats <- if (smoke) 1L else 20L
  inner_v <- if (smoke) 2L else 5L
  n_bootstraps <- if (smoke) 4L else 500L
  n_lambda <- if (smoke) 4L else 50L
  inner_repeats_diablo <- if (smoke) 1L else 10L
  ncomp_grid <- if (smoke) 1:2 else 1:5
  keepx_grid <- if (smoke) {
    list(mRNA = c(5, 8), miRNA = c(5, 8))
  } else {
    list(mRNA = c(5:10, seq(15, 50, 5)), miRNA = c(5:10, seq(12, 40, 4)))
  }

  stabl <- stablr::stabl_multiomic_nested_cv(
    x_list = dat$x_list,
    y = dat$y,
    lambda_grid = "auto",
    outer_v = outer_v,
    outer_repeats = outer_repeats,
    inner_v = inner_v,
    stratified = TRUE,
    metric = "ber",
    family = "multinomial",
    n_bootstraps = n_bootstraps,
    artificial_type = "knockoff",
    n_lambda = n_lambda,
    random_state = 42L,
    workers = stabl_workers,
    cv_workers = cv_workers
  )

  diablo <- tcga_run_diablo_nested(
    x_list = dat$x_list,
    y = dat$y,
    outer_folds = stabl$outer_folds,
    inner_v = inner_v,
    inner_repeats = inner_repeats_diablo,
    ncomp_grid = ncomp_grid,
    keepx_grid = keepx_grid,
    workers = diablo_workers,
    random_state = 42L
  )

  perf <- rbind(
    data.frame(
      method = "stablr",
      accuracy = stabl$performance$accuracy,
      balanced_error_rate = stabl$performance$balanced_error_rate,
      macro_f1 = stabl$performance$macro_f1,
      stringsAsFactors = FALSE
    ),
    data.frame(
      method = "DIABLO",
      accuracy = diablo$performance$accuracy,
      balanced_error_rate = diablo$performance$balanced_error_rate,
      macro_f1 = diablo$performance$macro_f1,
      stringsAsFactors = FALSE
    )
  )

  comparison <- tcga_compare_feature_sets(
    stabl_features = stabl$selected_features,
    diablo_features = diablo$selected_features,
    n_folds = length(stabl$outer_folds)
  )

  out <- list(
    stablr = stabl,
    diablo = diablo,
    performance = perf,
    feature_comparison = comparison,
    original_split = dat$original_split,
    settings = list(
      outer_v = outer_v,
      outer_repeats = outer_repeats,
      inner_v = inner_v,
      stabl_artificial_type = "knockoff",
      stabl_n_bootstraps = n_bootstraps,
      stabl_n_lambda = n_lambda,
      diablo_inner_repeats = inner_repeats_diablo,
      smoke = smoke
    ),
    session_info = utils::sessionInfo()
  )

  dir.create(dirname(cache_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, cache_path)
  utils::write.csv(perf, file.path(dirname(cache_path), "tcga_nestedcv_performance.csv"), row.names = FALSE)
  utils::write.csv(comparison$recurrence, file.path(dirname(cache_path), "tcga_nestedcv_feature_recurrence.csv"), row.names = FALSE)
  utils::write.csv(comparison$overlap, file.path(dirname(cache_path), "tcga_nestedcv_feature_overlap.csv"), row.names = FALSE)
  out
}

args <- commandArgs(trailingOnly = TRUE)
get_arg <- function(flag, default = NULL) {
  hit <- which(args == flag)
  if (!length(hit) || hit == length(args)) return(default)
  args[[hit + 1L]]
}
has_flag <- function(flag) flag %in% args

if (sys.nframe() == 0L) {
  cache_path <- get_arg("--cache", "r-pkg/stablr/inst/analysis/cache/tcga_nestedcv_results.rds")
  force <- has_flag("--force")
  smoke <- has_flag("--smoke")
  cv_workers <- as.integer(get_arg("--cv-workers", "1"))
  stabl_workers <- as.integer(get_arg("--stabl-workers", Sys.getenv("SLURM_CPUS_PER_TASK", "6")))
  diablo_workers <- as.integer(get_arg("--diablo-workers", Sys.getenv("SLURM_CPUS_PER_TASK", "6")))
  res <- run_tcga_head_to_head(
    cache_path = cache_path,
    force = force,
    smoke = smoke,
    cv_workers = cv_workers,
    stabl_workers = stabl_workers,
    diablo_workers = diablo_workers
  )
  print(res$performance)
}
