# Stacked-generalization helpers for prediction-level fusion.

# ---------------------------------------------------------------------------
# stacked_multi_omic
# ---------------------------------------------------------------------------

#' Stacked Generalization Over Per-Omic Predictions
#'
#' Finds optimal omic weights by random search, matching the Python
#' `stacked_multi_omic` algorithm from `stabl/stacked_generalization.py`.
#' Missing values in `predictions` are handled per-row: rows with all-NA
#' predictions receive `NA` in the stacked output. For binary and regression
#' scoring, rows with missing outcomes are skipped when evaluating candidate
#' weights.
#'
#' @param predictions For `task_type = "binary"` or `"regression"`, a
#'   `data.frame` or numeric matrix with one column per omic and one row per
#'   sample. For `task_type = "multiclass"`, a named list of class-probability
#'   matrices/data frames, one per omic, with samples in rows and classes in
#'   columns.
#' @param y Outcome vector aligned with rows of `predictions`. For
#'   `task_type = "binary"`, values may be numeric/logical `0`/`1` or a
#'   two-level factor/character vector; the second level is treated as the
#'   positive class. For `task_type = "multiclass"`, values are coerced to a
#'   factor with levels matching the probability columns, and every label must
#'   be present in those columns.
#' @param task_type `"binary"` (maximise AUC), `"regression"` (maximise R²), or
#'   `"multiclass"` (minimise multiclass log loss).
#' @param n_iter Number of random weight draws to try.  Mirrors `n_iter` in
#'   the Python implementation (default `10000`).
#' @param random_state Optional integer seed for reproducibility.  Saves and
#'   restores the RNG state on exit so caller state is unaffected.
#'
#' @return A named list with three elements:
#'   \describe{
#'     \item{`predictions`}{`data.frame` with one column per omic plus a
#'       `"Stacked Gen. Predictions"` column of the best weighted average.}
#'     \item{`weights`}{`data.frame` with one row per omic and a column
#'       `Associated_weight` containing the optimal weight.}
#'     \item{`score`}{Best score achieved (AUC, R², or negative log loss).}
#'   }
#' @export
stacked_multi_omic <- function(
    predictions,
    y,
    task_type = c("binary", "regression", "multiclass"),
    n_iter    = 10000L,
    random_state = NULL
) {
  task_type <- match.arg(task_type)
  if (identical(task_type, "multiclass")) {
    return(.stacked_multi_omic_multiclass(
      predictions = predictions,
      y = y,
      n_iter = n_iter,
      random_state = random_state
    ))
  }

  predictions <- as.matrix(predictions)
  n_omics   <- ncol(predictions)
  n_samples <- nrow(predictions)

  if (n_omics == 0L) {
    stop("`predictions` must have at least one column.", call. = FALSE)
  }
  if (length(y) != n_samples) {
    stop("`y` must have one value per prediction row.", call. = FALSE)
  }
  if (identical(task_type, "binary")) {
    y <- .coerce_binary_stack_outcome(y)
  }

  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  best_score   <- -Inf
  best_weights <- rep(1 / n_omics, n_omics)
  best_probs   <- rep(NA_real_, n_samples)

  is_obs <- !is.na(predictions)
  obs_mat <- is_obs
  storage.mode(obs_mat) <- "double"
  pred_zero <- predictions
  pred_zero[!is_obs] <- 0

  n_iter <- as.integer(n_iter)
  chunk_size <- min(n_iter, 256L)
  iter_start <- 1L
  while (iter_start <= n_iter) {
    block_size <- min(chunk_size, n_iter - iter_start + 1L)
    weight_block <- matrix(
      stats::runif(n_omics * block_size, 0, 10),
      nrow = n_omics,
      ncol = block_size
    )
    num_block <- pred_zero %*% weight_block
    denom_block <- obs_mat %*% weight_block

    for (k in seq_len(block_size)) {
      weighted_probs <- rep(NA_real_, n_samples)
      has_denom <- denom_block[, k] > 0
      weighted_probs[has_denom] <- num_block[has_denom, k] / denom_block[has_denom, k]

      complete_idx <- !is.na(weighted_probs) & !is.na(y)
      if (sum(complete_idx) < 2L) next

      score <- tryCatch(
        if (task_type == "binary") {
          .r_auc(y[complete_idx], weighted_probs[complete_idx])
        } else {
          .r_squared(y[complete_idx], weighted_probs[complete_idx])
        },
        error = function(e) NA_real_
      )

      if (!is.na(score) && score > best_score) {
        best_score   <- score
        best_weights <- weight_block[, k]
        best_probs   <- weighted_probs
      }
    }
    iter_start <- iter_start + block_size
  }

  weights_df        <- data.frame(Associated_weight = best_weights,
                                  row.names = colnames(predictions))
  preds_df          <- as.data.frame(predictions)
  preds_df[["Stacked Gen. Predictions"]] <- best_probs

  list(predictions = preds_df, weights = weights_df, score = best_score)
}

.coerce_binary_stack_outcome <- function(y) {
  missing <- is.na(y)

  if (is.factor(y) || is.character(y)) {
    y_factor <- droplevels(factor(y[!missing]))
    if (length(levels(y_factor)) != 2L) {
      stop(
        "Binary stacking `y` must contain exactly two observed classes.",
        call. = FALSE
      )
    }
    out <- rep(NA_integer_, length(y))
    out[!missing] <- as.integer(y_factor == levels(y_factor)[[2L]])
    return(out)
  }

  y_num <- if (is.logical(y)) {
    as.numeric(y)
  } else {
    suppressWarnings(as.numeric(y))
  }
  if (any(!missing & (is.na(y_num) | !is.finite(y_num)))) {
    stop(
      "Binary stacking `y` must be numeric/logical 0/1 values or a two-level factor/character vector.",
      call. = FALSE
    )
  }

  observed <- sort(unique(y_num[!missing]))
  if (!all(observed %in% c(0, 1))) {
    stop("Binary stacking `y` must contain only 0/1 values.", call. = FALSE)
  }
  if (!identical(observed, c(0, 1))) {
    stop(
      "Binary stacking `y` must contain exactly two observed classes.",
      call. = FALSE
    )
  }

  as.integer(y_num)
}

.stacked_multi_omic_multiclass <- function(predictions,
                                           y,
                                           n_iter = 10000L,
                                           random_state = NULL) {
  arr <- .as_multiclass_prediction_array(predictions)
  n_samples <- dim(arr)[[1L]]
  n_classes <- dim(arr)[[2L]]
  n_omics <- dim(arr)[[3L]]
  classes <- dimnames(arr)[[2L]]
  omic_names <- dimnames(arr)[[3L]]

  if (length(y) != n_samples) {
    stop("`y` must have one value per prediction row.", call. = FALSE)
  }
  y <- factor(y, levels = classes)
  if (anyNA(y)) {
    stop(
      "All multiclass `y` labels must be present in prediction probability columns.",
      call. = FALSE
    )
  }

  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  best_score <- -Inf
  best_loss <- Inf
  best_weights <- rep(1 / n_omics, n_omics)
  best_probs <- matrix(NA_real_, nrow = n_samples, ncol = n_classes,
                       dimnames = list(dimnames(arr)[[1L]], classes))
  observed <- .multiclass_observed_omics(arr)

  for (i in seq_len(as.integer(n_iter))) {
    weights <- stats::runif(n_omics, 0, 10)
    probs <- .weighted_multiclass_probabilities(arr, weights, observed = observed)
    loss <- .multiclass_log_loss(y, probs)
    score <- -loss
    if (is.finite(score) && score > best_score) {
      best_score <- score
      best_loss <- loss
      best_weights <- weights
      best_probs <- probs
    }
  }

  weights_df <- data.frame(Associated_weight = best_weights,
                           row.names = omic_names)
  preds_df <- as.data.frame(best_probs, check.names = FALSE)
  names(preds_df) <- paste0("prob_", names(preds_df))
  preds_df$predicted_class <- classes[max.col(best_probs, ties.method = "first")]

  list(
    predictions = preds_df,
    weights = weights_df,
    score = best_score,
    log_loss = best_loss,
    levels = classes
  )
}

.as_multiclass_prediction_array <- function(predictions) {
  if (!is.list(predictions) || is.null(names(predictions)) || length(predictions) == 0L) {
    stop("Multiclass `predictions` must be a named non-empty list.", call. = FALSE)
  }
  mats <- lapply(predictions, function(x) {
    x <- as.matrix(x)
    storage.mode(x) <- "double"
    x
  })
  first_dim <- dim(mats[[1L]])
  first_rows <- rownames(mats[[1L]])
  first_cols <- colnames(mats[[1L]])
  if (is.null(first_cols)) {
    stop("Multiclass prediction matrices must have class column names.", call. = FALSE)
  }
  for (nm in names(mats)) {
    if (!identical(dim(mats[[nm]]), first_dim) ||
        !identical(rownames(mats[[nm]]), first_rows) ||
        !identical(colnames(mats[[nm]]), first_cols)) {
      stop("All multiclass prediction matrices must have identical rows and class columns.",
           call. = FALSE)
    }
  }
  arr <- array(
    NA_real_,
    dim = c(first_dim[[1L]], first_dim[[2L]], length(mats)),
    dimnames = list(first_rows, first_cols, names(mats))
  )
  for (i in seq_along(mats)) {
    arr[, , i] <- mats[[i]]
  }
  arr
}

.multiclass_observed_omics <- function(pred_array) {
  apply(is.finite(pred_array), c(1L, 3L), all)
}

.weighted_multiclass_probabilities <- function(pred_array, weights, observed = NULL) {
  n_samples <- dim(pred_array)[[1L]]
  n_classes <- dim(pred_array)[[2L]]
  n_omics <- dim(pred_array)[[3L]]
  out <- matrix(NA_real_, nrow = n_samples, ncol = n_classes,
                dimnames = dimnames(pred_array)[1:2])

  if (is.null(observed)) {
    observed <- .multiclass_observed_omics(pred_array)
  }

  denom <- as.numeric(observed %*% weights)
  has_denom <- denom > 0
  if (!any(has_denom)) {
    return(out)
  }

  weighted_sum <- matrix(0.0, nrow = n_samples, ncol = n_classes,
                         dimnames = dimnames(pred_array)[1:2])
  for (omic in seq_len(n_omics)) {
    rows <- observed[, omic]
    if (any(rows)) {
      omic_probs <- pred_array[rows, , omic, drop = FALSE]
      dim(omic_probs) <- c(sum(rows), n_classes)
      weighted_sum[rows, ] <- weighted_sum[rows, ] +
        omic_probs * weights[[omic]]
    }
  }

  out[has_denom, ] <- weighted_sum[has_denom, , drop = FALSE] / denom[has_denom]
  out[out < 0] <- 0
  row_totals <- rowSums(out[has_denom, , drop = FALSE])
  valid_rows <- has_denom
  valid_rows[has_denom] <- row_totals > 0 & is.finite(row_totals)
  if (any(valid_rows)) {
    out[valid_rows, ] <- out[valid_rows, , drop = FALSE] / rowSums(out[valid_rows, , drop = FALSE])
  }
  if (any(!valid_rows)) {
    out[!valid_rows, ] <- NA_real_
  }
  out
}

.multiclass_log_loss <- function(y, probs, eps = 1e-15) {
  y <- factor(y, levels = colnames(probs))
  idx <- !is.na(y) & rowSums(is.finite(probs)) == ncol(probs)
  if (sum(idx) == 0L) return(Inf)
  probs <- pmin(pmax(probs[idx, , drop = FALSE], eps), 1 - eps)
  probs <- probs / rowSums(probs)
  truth_idx <- cbind(seq_len(sum(idx)), as.integer(y[idx]))
  -mean(log(probs[truth_idx]))
}

.apply_multiclass_stack_weights <- function(predictions, weights) {
  arr <- .as_multiclass_prediction_array(predictions)
  probs <- .weighted_multiclass_probabilities(arr, weights)
  out <- as.data.frame(probs, check.names = FALSE)
  names(out) <- paste0("prob_", names(out))
  classes <- dimnames(arr)[[2L]]
  out$predicted_class <- classes[max.col(probs, ties.method = "first")]
  out
}

# Infer task_type from glm family string.
.family_to_task_type <- function(family) {
  if (identical(family, "binomial")) {
    "binary"
  } else if (identical(family, "multinomial")) {
    "multiclass"
  } else {
    "regression"
  }
}
