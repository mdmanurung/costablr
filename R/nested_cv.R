# Nested cross-validation helpers for multi-omic STABL workflows.

#' Multi-Omic STABL Nested Cross-Validation
#'
#' Runs a repeated outer cross-validation loop for generalisation assessment.
#' Within each outer training split, candidate STABL workflows are compared
#' using an inner cross-validation loop. The selected candidate is then refit
#' on the full outer-training split and evaluated once on the held-out outer
#' fold.
#'
#' @param x_list Named list of omic matrices or data frames with identical
#'   sample row names.
#' @param y Named factor or character vector aligned to `x_list` rows.
#' @param candidates Optional list of candidate definitions. Each candidate is
#'   a list with `name` and `blocks`; `blocks` names one or more omics from
#'   `x_list`. When `NULL`, one candidate is created for each omic plus one
#'   early-fusion candidate using all omics.
#' @param lambda_grid Either `"auto"`, a single lambda-grid data frame, or a
#'   named list of lambda grids. Named entries can match omic names or candidate
#'   names.
#' @param outer_v Number of outer folds per repeat.
#' @param outer_repeats Number of repeated outer CV rounds.
#' @param inner_v Number of inner folds used for candidate selection.
#' @param stratified Logical. When `TRUE` (default), outer and inner folds
#'   preserve class proportions as closely as possible.
#' @param strata Optional named vector used to stratify folds instead of `y`.
#'   Categorical values are used directly. Numeric values are binned into
#'   quantile groups before fold assignment.
#' @param strata_bins Number of quantile bins for numeric `strata`.
#' @param metric Candidate-selection metric, `"ber"` or `"accuracy"`.
#' @param family Passed to [stabl_fit()]. Defaults to `"multinomial"`.
#' @param n_bootstraps Passed to [stabl_fit()].
#' @param artificial_type Passed to [stabl_fit()].
#' @param hard_threshold Passed to [stabl_fit()].
#' @param random_state Optional integer seed.
#' @param n_lambda Passed to [stabl_fit()] when `lambda_grid = "auto"`.
#' @param l1_ratio Passed to [stabl_fit()] when `lambda_grid = "auto"`.
#'   Use this with `base_learner = "elastic_net"` to generate alpha-aware
#'   train-fold grids.
#' @param workers Passed to [stabl_fit()] for bootstrap-level parallelism.
#' @param cv_workers Number of outer folds to evaluate in parallel. Uses
#'   `parallel::mclapply()` on Unix-like systems and falls back to sequential
#'   execution on Windows.
#' @param ... Additional arguments passed to [stabl_fit()].
#'
#' @note Parallelism has two levels: `cv_workers` parallelizes outer folds in
#'   this nested-CV wrapper, while `workers` is forwarded to [stabl_fit()] for
#'   bootstrap-level parallelism. Avoid setting both above 1 in the same run.
#'   When using `cv_workers > 1`, keep any active `future` plan sequential
#'   because nested CV uses `parallel::mclapply()` rather than `future`.
#'
#' @return An object of class `"stabl_multiomic_nested_cv"` containing fold
#'   definitions, inner candidate diagnostics, outer held-out predictions,
#'   selected features, and aggregate performance.
#' @export
stabl_multiomic_nested_cv <- function(
    x_list,
    y,
    candidates      = NULL,
    lambda_grid     = "auto",
    outer_v         = 5L,
    outer_repeats   = 1L,
    inner_v         = 5L,
    stratified      = TRUE,
    strata          = NULL,
    strata_bins     = 5L,
    metric          = c("ber", "accuracy"),
    family          = "multinomial",
    n_bootstraps    = 100L,
    artificial_type = "random_permutation",
    hard_threshold  = NULL,
    random_state    = NULL,
    n_lambda        = 30L,
    l1_ratio        = NULL,
    workers         = 1L,
    cv_workers      = 1L,
    ...
) {
  metric <- match.arg(metric)
  validate_multiomic_inputs(x_list = x_list, y = y)

  y <- .subset_outcome_by_ids(y, rownames(x_list[[1L]]))
  y <- factor(y)
  sample_ids <- names(y)
  if (nlevels(y) < 2L) {
    stop("`y` must contain at least two outcome classes.", call. = FALSE)
  }
  strata_labels <- .make_nested_strata(
    strata = strata,
    y = y,
    sample_ids = sample_ids,
    bins = strata_bins
  )

  outer_v <- as.integer(outer_v)
  outer_repeats <- as.integer(outer_repeats)
  inner_v <- as.integer(inner_v)
  cv_workers <- as.integer(cv_workers)
  if (outer_v < 2L || outer_repeats < 1L || inner_v < 2L) {
    stop("`outer_v`, `outer_repeats`, and `inner_v` must define valid CV folds.", call. = FALSE)
  }
  if (cv_workers < 1L) {
    stop("`cv_workers` must be a positive integer.", call. = FALSE)
  }
  .warn_nested_cv_parallelism(cv_workers = cv_workers, workers = workers)
  if (isTRUE(stratified) && min(table(strata_labels)) < max(outer_v, inner_v)) {
    stop("Each stratum must have at least `max(outer_v, inner_v)` samples.", call. = FALSE)
  }

  candidates <- .normalize_stabl_nested_candidates(candidates, names(x_list))
  outer_folds <- .make_repeated_cv_folds(
    y = strata_labels,
    v = outer_v,
    repeats = outer_repeats,
    stratified = stratified,
    random_state = random_state
  )

  process_outer_fold <- function(outer_i) {
    outer <- outer_folds[[outer_i]]
    train_ids <- outer$train_ids
    valid_ids <- outer$valid_ids

    inner_seed <- .derive_nested_seed(random_state, outer_i, 1000L)
    inner_folds <- .make_cv_folds(
      y = strata_labels[train_ids],
      v = inner_v,
      stratified = stratified,
      random_state = inner_seed
    )

    inner_eval <- .evaluate_stabl_candidates_inner(
      x_list = x_list,
      y = y,
      train_ids = train_ids,
      candidates = candidates,
      inner_folds = inner_folds,
      lambda_grid = lambda_grid,
      metric = metric,
      family = family,
      n_bootstraps = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold = hard_threshold,
      random_state = .derive_nested_seed(random_state, outer_i, 2000L),
      n_lambda = n_lambda,
      l1_ratio = l1_ratio,
      workers = workers,
      ...
    )

    selected_name <- .select_nested_candidate(inner_eval$summary, metric)
    selected_candidate <- candidates[[selected_name]]

    outer_fit <- .fit_stabl_nested_candidate(
      x_list = x_list,
      y = y,
      train_ids = train_ids,
      valid_ids = valid_ids,
      candidate = selected_candidate,
      lambda_grid = lambda_grid,
      family = family,
      n_bootstraps = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold = hard_threshold,
      random_state = .derive_nested_seed(random_state, outer_i, 3000L),
      n_lambda = n_lambda,
      l1_ratio = l1_ratio,
      workers = workers,
      ...
    )

    pred_df <- data.frame(
      repeat_id = outer[["repeat"]],
      fold = outer$fold,
      fold_id = outer$fold_id,
      sample_id = valid_ids,
      truth = as.character(y[valid_ids]),
      predicted = outer_fit$predicted,
      selected_candidate = selected_name,
      stringsAsFactors = FALSE
    )
    feature_df <- .stabl_nested_feature_table(
      selected_features = outer_fit$selected_features,
      importances = outer_fit$importances,
      repeat_id = outer[["repeat"]],
      fold = outer$fold,
      fold_id = outer$fold_id,
      method = "costablr",
      candidate = selected_name
    )

    inner_diag <- inner_eval$summary
    inner_diag$repeat_id <- outer[["repeat"]]
    inner_diag$fold <- outer$fold
    inner_diag$fold_id <- outer$fold_id

    list(
      fold_result = list(
        outer_fold = outer,
        inner_folds = inner_folds,
        inner_results = inner_eval,
        selected_candidate = selected_name,
        fit = outer_fit
      ),
      diagnostics = inner_diag,
      predictions = pred_df,
      selected_features = feature_df
    )
  }

  if (cv_workers > 1L && .Platform$OS.type != "windows") {
    outer_results <- parallel::mclapply(
      seq_along(outer_folds),
      process_outer_fold,
      mc.cores = min(cv_workers, length(outer_folds))
    )
  } else {
    outer_results <- lapply(seq_along(outer_folds), process_outer_fold)
  }

  fold_results <- lapply(outer_results, `[[`, "fold_result")
  names(fold_results) <- vapply(outer_folds, `[[`, character(1L), "fold_id")
  inner_rows <- lapply(outer_results, `[[`, "diagnostics")
  prediction_rows <- lapply(outer_results, `[[`, "predictions")
  feature_rows <- lapply(outer_results, `[[`, "selected_features")

  predictions <- do.call(rbind, prediction_rows)
  diagnostics <- do.call(rbind, inner_rows)
  selected_features <- do.call(rbind, feature_rows)
  performance <- .classification_metrics(
    truth = factor(predictions$truth, levels = levels(y)),
    predicted = factor(predictions$predicted, levels = levels(y))
  )

  structure(
    list(
      outer_folds = outer_folds,
      fold_results = fold_results,
      diagnostics = diagnostics,
      outer_predictions = predictions,
      selected_features = selected_features,
      performance = performance,
      levels = levels(y),
      metric = metric,
      candidates = candidates,
      strata = strata_labels,
      stratified = isTRUE(stratified),
      cv_workers = cv_workers,
      stabl_workers = workers
    ),
    class = "stabl_multiomic_nested_cv"
  )
}

.normalize_stabl_nested_candidates <- function(candidates, omic_names) {
  if (is.null(candidates)) {
    out <- lapply(omic_names, function(block) list(name = block, blocks = block))
    names(out) <- omic_names
    if (length(omic_names) > 1L) {
      out$early_fusion <- list(name = "early_fusion", blocks = omic_names)
    }
    return(out)
  }

  if (!is.list(candidates) || length(candidates) == 0L) {
    stop("`candidates` must be a non-empty list.", call. = FALSE)
  }

  out <- vector("list", length(candidates))
  for (i in seq_along(candidates)) {
    cand <- candidates[[i]]
    if (is.character(cand)) cand <- list(name = cand[[1L]], blocks = cand)
    if (is.null(cand$name) || is.null(cand$blocks)) {
      stop("Each candidate must define `name` and `blocks`.", call. = FALSE)
    }
    cand$name <- as.character(cand$name[[1L]])
    cand$blocks <- as.character(cand$blocks)
    if (!all(cand$blocks %in% omic_names)) {
      stop("Candidate `blocks` must name omics in `x_list`.", call. = FALSE)
    }
    out[[i]] <- cand
  }
  names(out) <- vapply(out, `[[`, character(1L), "name")
  if (anyDuplicated(names(out))) {
    stop("Candidate names must be unique.", call. = FALSE)
  }
  out
}

.make_nested_strata <- function(strata, y, sample_ids, bins = 5L) {
  if (is.null(strata)) {
    out <- factor(y)
    names(out) <- sample_ids
    return(out)
  }

  if (is.null(names(strata))) {
    if (length(strata) != length(sample_ids)) {
      stop("Unnamed `strata` must have the same length as `y`.", call. = FALSE)
    }
    names(strata) <- sample_ids
  }
  if (!all(sample_ids %in% names(strata))) {
    stop("`strata` must contain names for every sample in `y`.", call. = FALSE)
  }
  strata <- strata[sample_ids]

  if (anyNA(strata)) {
    stop("`strata` cannot contain missing values.", call. = FALSE)
  }

  if (is.numeric(strata) || is.integer(strata)) {
    bins <- as.integer(bins)
    if (bins < 2L) {
      stop("`strata_bins` must be at least 2 for numeric strata.", call. = FALSE)
    }
    probs <- seq(0, 1, length.out = bins + 1L)
    breaks <- unique(stats::quantile(as.numeric(strata), probs = probs,
                                     na.rm = TRUE, names = FALSE,
                                     type = 7))
    if (length(breaks) < 3L) {
      out <- factor(rep("all", length(strata)))
    } else {
      out <- cut(as.numeric(strata), breaks = breaks, include.lowest = TRUE,
                 ordered_result = TRUE)
    }
  } else {
    out <- factor(strata)
  }

  names(out) <- sample_ids
  out
}

.derive_nested_seed <- function(random_state, index, offset) {
  if (is.null(random_state)) return(NULL)
  as.integer((as.integer(random_state) + as.integer(offset) + as.integer(index) * 7919L) %% .Machine$integer.max)
}

.evaluate_stabl_candidates_inner <- function(x_list, y, train_ids, candidates,
                                             inner_folds, lambda_grid, metric,
                                             family, n_bootstraps,
                                             artificial_type, hard_threshold,
                                             random_state, n_lambda, l1_ratio,
                                             workers, ...) {
  candidate_rows <- list()
  k <- 1L

  for (cand_name in names(candidates)) {
    candidate <- candidates[[cand_name]]
    pred_rows <- list()

    for (fold_i in seq_along(inner_folds)) {
      fold <- inner_folds[[fold_i]]
      inner_train <- fold$train_ids
      inner_valid <- fold$valid_ids
      fit <- .fit_stabl_nested_candidate(
        x_list = x_list,
        y = y,
        train_ids = inner_train,
        valid_ids = inner_valid,
        candidate = candidate,
        lambda_grid = lambda_grid,
        family = family,
        n_bootstraps = n_bootstraps,
        artificial_type = artificial_type,
        hard_threshold = hard_threshold,
        random_state = .derive_nested_seed(random_state, fold_i, k * 100L),
        n_lambda = n_lambda,
        l1_ratio = l1_ratio,
        workers = workers,
        ...
      )
      pred_rows[[fold_i]] <- data.frame(
        truth = as.character(y[inner_valid]),
        predicted = fit$predicted,
        stringsAsFactors = FALSE
      )
    }

    preds <- do.call(rbind, pred_rows)
    metrics <- .classification_metrics(
      truth = factor(preds$truth, levels = levels(y)),
      predicted = factor(preds$predicted, levels = levels(y))
    )
    candidate_rows[[cand_name]] <- data.frame(
      candidate = cand_name,
      accuracy = metrics$accuracy,
      balanced_error_rate = metrics$balanced_error_rate,
      macro_f1 = metrics$macro_f1,
      n_inner_predictions = nrow(preds),
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }

  list(summary = do.call(rbind, candidate_rows))
}

.select_nested_candidate <- function(summary, metric) {
  if (metric == "accuracy") {
    return(summary$candidate[which.max(summary$accuracy)])
  }
  summary$candidate[which.min(summary$balanced_error_rate)]
}

.fit_stabl_nested_candidate <- function(x_list, y, train_ids, valid_ids,
                                        candidate, lambda_grid, family,
                                        n_bootstraps, artificial_type,
                                        hard_threshold, random_state,
                                        n_lambda, l1_ratio, workers, ...) {
  x_train <- .candidate_matrix(x_list, candidate, train_ids)
  x_valid <- .candidate_matrix(x_list, candidate, valid_ids)
  y_train <- y[train_ids]

  fit <- stabl_fit(
    x = x_train,
    y = y_train,
    lambda_grid = .resolve_nested_lambda_grid(
      lambda_grid,
      candidate,
      x_train,
      y_train,
      family,
      n_lambda,
      l1_ratio
    ),
    family = family,
    n_bootstraps = n_bootstraps,
    artificial_type = artificial_type,
    hard_threshold = hard_threshold,
    random_state = random_state,
    n_lambda = n_lambda,
    l1_ratio = l1_ratio,
    workers = workers,
    ...
  )

  support <- get_support(fit)
  selected <- names(support)[support]
  importances <- get_importances(fit)
  refit_prediction <- .predict_stabl_nested_final_classes(
    x_train_sel = x_train[, selected, drop = FALSE],
    y_train = y_train,
    x_valid_sel = x_valid[, selected, drop = FALSE],
    family = family,
    levels = levels(y)
  )

  list(
    stabl_fit = fit,
    final_refit = refit_prediction$final_refit,
    selected_features = .split_prefixed_features(selected),
    importances = importances,
    predicted = refit_prediction$predicted,
    candidate = candidate$name
  )
}

.candidate_matrix <- function(x_list, candidate, ids) {
  mats <- lapply(candidate$blocks, function(block) {
    x <- as.matrix(x_list[[block]][ids, , drop = FALSE])
    colnames(x) <- paste(block, colnames(x), sep = "::")
    x
  })
  out <- do.call(cbind, mats)
  rownames(out) <- ids
  out
}

.resolve_nested_lambda_grid <- function(lambda_grid, candidate, x_train, y_train,
                                        family, n_lambda, l1_ratio = NULL) {
  if (identical(lambda_grid, "auto")) {
    return("auto")
  }
  if (is.data.frame(lambda_grid)) {
    return(lambda_grid)
  }
  if (is.list(lambda_grid)) {
    if (!is.null(lambda_grid[[candidate$name]])) {
      return(lambda_grid[[candidate$name]])
    }
    if (length(candidate$blocks) == 1L && !is.null(lambda_grid[[candidate$blocks[[1L]]]])) {
      return(lambda_grid[[candidate$blocks[[1L]]]])
    }
  }
  auto_lambda_grid(
    x_train,
    y_train,
    family = family,
    n_lambda = n_lambda,
    l1_ratio = l1_ratio
  )
}

.predict_stabl_nested_final_classes <- function(x_train_sel, y_train, x_valid_sel,
                                                family, levels) {
  task_type <- .stabl_refit_task_type(family)
  tryCatch({
    final_refit <- .fit_stabl_final_model(
      x_train_sel = x_train_sel,
      y_train = y_train,
      task_type = task_type,
      levels = levels
    )
    list(
      final_refit = final_refit,
      predicted = as.character(.predict_stabl_final_model(
        final_refit,
        x_valid_sel,
        type = "class"
      ))
    )
  }, error = function(e) {
    .stabl_nested_majority_prediction(
      y_train = y_train,
      x_valid_sel = x_valid_sel,
      task_type = task_type,
      levels = levels,
      error = e
    )
  })
}

.stabl_nested_majority_prediction <- function(y_train, x_valid_sel, task_type,
                                              levels, error = NULL) {
  level_set <- levels
  if (is.null(level_set)) {
    level_set <- base::levels(factor(y_train))
  }
  observed <- as.character(y_train[!is.na(y_train)])
  if (length(level_set) == 0L) {
    level_set <- sort(unique(observed))
  }
  if (length(level_set) == 0L) {
    stop("Cannot derive a majority-class fallback without observed labels.",
         call. = FALSE)
  }

  counts <- table(factor(observed, levels = level_set))
  majority <- names(counts)[[which.max(counts)]]
  list(
    final_refit = list(
      model = NULL,
      model_type = "majority_class",
      task_type = task_type,
      levels = level_set,
      majority_class = majority,
      fallback_reason = if (is.null(error)) NULL else conditionMessage(error)
    ),
    predicted = rep(majority, nrow(x_valid_sel))
  )
}

.split_prefixed_features <- function(features) {
  out <- list()
  if (length(features) == 0L) return(out)
  parts <- strsplit(features, "::", fixed = TRUE)
  blocks <- vapply(parts, `[`, character(1L), 1L)
  names_only <- vapply(parts, function(x) paste(x[-1L], collapse = "::"), character(1L))
  split(names_only, blocks)
}

.stabl_nested_feature_table <- function(selected_features, importances, repeat_id,
                                        fold, fold_id, method, candidate) {
  rows <- list()
  k <- 1L
  for (block in names(selected_features)) {
    feats <- selected_features[[block]]
    prefixed <- paste(block, feats, sep = "::")
    rows[[k]] <- data.frame(
      method = method,
      candidate = candidate,
      repeat_id = repeat_id,
      fold = fold,
      fold_id = fold_id,
      block = block,
      feature = feats,
      score = unname(importances[prefixed]),
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }
  if (length(rows) == 0L) {
    return(data.frame(
      method = character(), candidate = character(), repeat_id = integer(),
      fold = character(), fold_id = character(), block = character(),
      feature = character(), score = numeric(), stringsAsFactors = FALSE
    ))
  }
  do.call(rbind, rows)
}

.classification_metrics <- function(truth, predicted) {
  truth <- factor(truth)
  predicted <- factor(predicted, levels = levels(truth))
  tab <- table(truth = truth, predicted = predicted)
  recalls <- diag(tab) / pmax(rowSums(tab), 1L)
  precisions <- diag(tab) / pmax(colSums(tab), 1L)
  f1 <- ifelse(precisions + recalls > 0, 2 * precisions * recalls / (precisions + recalls), 0)
  accuracy <- sum(diag(tab)) / sum(tab)
  list(
    accuracy = unname(accuracy),
    balanced_error_rate = unname(1 - mean(recalls)),
    per_class_recall = recalls,
    macro_f1 = unname(mean(f1)),
    confusion = tab
  )
}

#' @export
print.stabl_multiomic_nested_cv <- function(x, ...) {
  cat("<stabl_multiomic_nested_cv>\n")
  cat("  outer folds: ", length(x$outer_folds), "\n", sep = "")
  cat("  candidates:  ", paste(names(x$candidates), collapse = ", "), "\n", sep = "")
  cat("  metric:      ", x$metric, "\n", sep = "")
  cat("  accuracy:    ", sprintf("%.3f", x$performance$accuracy), "\n", sep = "")
  cat("  BER:         ", sprintf("%.3f", x$performance$balanced_error_rate), "\n", sep = "")
  invisible(x)
}

.warn_nested_cv_parallelism <- function(cv_workers, workers) {
  if (is.na(cv_workers) || cv_workers <= 1L) {
    return(invisible(NULL))
  }

  workers_int <- suppressWarnings(as.integer(workers))
  if (length(workers_int) == 1L && is.finite(workers_int) && workers_int > 1L) {
    warning(
      "Avoid setting both `cv_workers` and `workers` above 1 in ",
      "`stabl_multiomic_nested_cv()`: `cv_workers` parallelizes outer folds, ",
      "while `workers` parallelizes STABL bootstraps inside each fold.",
      call. = FALSE
    )
  }

  if (requireNamespace("future", quietly = TRUE) &&
      !isTRUE(.future_plan_is_sequential())) {
    warning(
      "`cv_workers > 1` uses `parallel::mclapply()` for outer folds. ",
      "Call `future::plan(sequential)` before nested CV to avoid mixing ",
      "parallel backends.",
      call. = FALSE
    )
  }

  invisible(NULL)
}

.future_plan_is_sequential <- function() {
  plan <- tryCatch(future::plan(), error = function(e) NULL)
  inherits(plan, "sequential")
}
