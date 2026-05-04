#' Minimal Multi-Omic STABL Train/Validation Workflow
#'
#' Fits [stabl_fit()] independently on each omic block from a named list,
#' then returns per-omic fitted objects and selected-feature matrices for
#' downstream composition.
#'
#' This function intentionally keeps scope narrow for the first Phase 5
#' workflow slice: it orchestrates strict alignment checks and leakage-safe
#' grouped fitting, but does not perform downstream predictive refitting.
#'
#' @param x_train_list Named list of training omic tables (`data.frame` or
#'   numeric matrix), each with row names as sample IDs.
#' @param y_train Named outcome vector for training samples.
#' @param lambda_grid Either a shared lambda grid (`data.frame` or `"auto"`)
#'   used for all omics, or a named list mapping each omic name to its own
#'   lambda grid.
#' @param x_valid_list Optional named list of validation omic tables. When
#'   supplied, names must match `x_train_list` names.
#' @param y_valid Optional named outcome vector for validation samples. When
#'   supplied together with `x_valid_list`, sample alignment is validated.
#' @param groups_train Optional named grouping vector for training samples.
#'   When supplied, grouped bootstrap sampling is used in each per-omic fit.
#' @param base_learner Passed to [stabl_fit()].
#' @param family Passed to [stabl_fit()].
#' @param n_bootstraps Passed to [stabl_fit()].
#' @param artificial_type Passed to [stabl_fit()].
#' @param hard_threshold Passed to [stabl_fit()].
#' @param random_state Passed to [stabl_fit()].
#' @param ... Additional arguments forwarded to [stabl_fit()].
#'
#' @param early_fusion Logical.  When `TRUE`, a single [stabl_fit()] is run on
#'   the column-bound concatenation of all omic matrices in addition to the
#'   per-omic fits.  Results are returned in the `early_fusion` field.
#' @param late_fusion Logical.  When `TRUE`, a downstream predictor is fitted
#'   per omic on its selected features, and [stacked_multi_omic()] combines the
#'   per-omic predictions.  Requires at least one feature to be selected across
#'   the omics.  The `task_type` (binary vs. regression) is inferred from
#'   `family`.  Results are returned in the `late_fusion` field.
#' @param n_iter_lf Number of random weight draws passed to
#'   [stacked_multi_omic()] during late fusion.  Ignored when
#'   `late_fusion = FALSE`.
#'
#' @return A named list with class `"stabl_multiomic_fit"` containing:
#'   \describe{
#'     \item{`fits`}{Named list of per-omic `stabl_fit` objects.}
#'     \item{`selected_features`}{Named list of selected feature names.}
#'     \item{`selected_train`}{Named list of training matrices restricted to
#'       selected features (possibly 0-column).}
#'     \item{`selected_valid`}{Named list of validation matrices restricted to
#'       selected features, or `NULL` when no validation input is provided.}
#'     \item{`early_fusion`}{`NULL` when `early_fusion = FALSE`.  Otherwise a
#'       list with `fit`, `selected_features`, `selected_train`, and
#'       `selected_valid` for the concatenated single-STABL run.}
#'     \item{`late_fusion`}{`NULL` when `late_fusion = FALSE`.  Otherwise a
#'       list with `weights` (data.frame), `train_predictions` (data.frame),
#'       `valid_predictions` (numeric vector or `NULL`), and `score`.}
#'   }
#' @export
stabl_multiomic_train_validate <- function(
    x_train_list,
    y_train,
    lambda_grid,
    x_valid_list    = NULL,
    y_valid         = NULL,
    groups_train    = NULL,
    base_learner    = "lasso",
    family          = "gaussian",
    n_bootstraps    = 100L,
    artificial_type = "random_permutation",
    hard_threshold  = NULL,
    random_state    = NULL,
    early_fusion    = FALSE,
    late_fusion     = FALSE,
    n_iter_lf       = 10000L,
    ...
) {
  validate_multiomic_inputs(x_list = x_train_list, y = y_train,
                            groups = groups_train)

  omic_names <- names(x_train_list)
  lambda_by_omic <- .resolve_multiomic_lambda_grid(lambda_grid, omic_names)

  if (!is.null(x_valid_list)) {
    .validate_multiomic_validation_inputs(
      x_valid_list = x_valid_list,
      y_valid = y_valid,
      train_omic_names = omic_names
    )
  }

  fits <- vector("list", length(omic_names))
  names(fits) <- omic_names

  selected_features <- vector("list", length(omic_names))
  names(selected_features) <- omic_names

  selected_train <- vector("list", length(omic_names))
  names(selected_train) <- omic_names

  selected_valid <- if (!is.null(x_valid_list)) {
    out <- vector("list", length(omic_names))
    names(out) <- omic_names
    out
  } else {
    NULL
  }

  for (omic in omic_names) {
    x_train <- x_train_list[[omic]]
    if (is.data.frame(x_train)) x_train <- as.matrix(x_train)

    fit <- stabl_fit(
      x = x_train,
      y = y_train,
      lambda_grid = lambda_by_omic[[omic]],
      base_learner = base_learner,
      family = family,
      n_bootstraps = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold = hard_threshold,
      groups = groups_train,
      random_state = random_state,
      ...
    )

    sel <- get_feature_names_out(fit)

    fits[[omic]] <- fit
    selected_features[[omic]] <- sel
    selected_train[[omic]] <- .subset_selected_matrix(x_train_list[[omic]], sel)

    if (!is.null(x_valid_list)) {
      selected_valid[[omic]] <- .subset_selected_matrix(x_valid_list[[omic]], sel)
    }
  }

  # ---- Early fusion --------------------------------------------------------
  ef_result <- NULL
  if (isTRUE(early_fusion)) {
    x_all_train <- do.call(cbind, lapply(omic_names, function(omic) {
      x <- x_train_list[[omic]]
      if (is.data.frame(x)) as.matrix(x) else x
    }))

    # Use the shared/first lambda grid for the concatenated model.
    ef_lambda <- lambda_by_omic[[omic_names[1L]]]

    ef_fit <- stabl_fit(
      x            = x_all_train,
      y            = y_train,
      lambda_grid  = ef_lambda,
      base_learner = base_learner,
      family       = family,
      n_bootstraps = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold  = hard_threshold,
      groups       = groups_train,
      random_state = random_state,
      ...
    )

    ef_sel        <- get_feature_names_out(ef_fit)
    ef_train_mat  <- .subset_selected_matrix(as.data.frame(x_all_train), ef_sel)

    ef_valid_mat <- if (!is.null(x_valid_list)) {
      x_all_valid <- do.call(cbind, lapply(omic_names, function(omic) {
        x <- x_valid_list[[omic]]
        if (is.data.frame(x)) as.matrix(x) else x
      }))
      .subset_selected_matrix(as.data.frame(x_all_valid), ef_sel)
    } else {
      NULL
    }

    ef_result <- list(
      fit               = ef_fit,
      selected_features = ef_sel,
      selected_train    = ef_train_mat,
      selected_valid    = ef_valid_mat
    )
  }

  # ---- Late fusion ---------------------------------------------------------
  lf_result <- NULL
  if (isTRUE(late_fusion)) {
    task_type    <- .family_to_task_type(family)
    y_train_mean <- mean(unname(y_train))

    train_preds_mat <- matrix(
      NA_real_,
      nrow = length(y_train),
      ncol = length(omic_names),
      dimnames = list(names(y_train), omic_names)
    )
    valid_preds_mat <- if (!is.null(x_valid_list)) {
      matrix(
        NA_real_,
        nrow = length(y_valid),
        ncol = length(omic_names),
        dimnames = list(names(y_valid), omic_names)
      )
    } else {
      NULL
    }

    for (omic in omic_names) {
      omic_result <- .late_fusion_fit_omic(
        x_train_sel  = selected_train[[omic]],
        y_train      = y_train,
        x_valid_sel  = if (!is.null(x_valid_list)) selected_valid[[omic]] else NULL,
        y_train_mean = y_train_mean,
        task_type    = task_type
      )
      train_preds_mat[, omic] <- omic_result$train_preds
      if (!is.null(valid_preds_mat)) {
        valid_preds_mat[, omic] <- omic_result$valid_preds
      }
    }

    stacked <- stacked_multi_omic(
      predictions  = train_preds_mat,
      y            = unname(y_train),
      task_type    = task_type,
      n_iter       = n_iter_lf,
      random_state = random_state
    )

    # Apply best weights to validation predictions.
    lf_valid_preds <- if (!is.null(valid_preds_mat)) {
      w      <- stacked$weights$Associated_weight
      w_mat  <- matrix(w, nrow = nrow(valid_preds_mat),
                       ncol = length(w), byrow = TRUE)
      is_obs <- !is.na(valid_preds_mat)
      denom  <- rowSums(is_obs * w_mat)
      num    <- rowSums(ifelse(is_obs, valid_preds_mat * w_mat, 0))
      ifelse(denom > 0, num / denom, NA_real_)
    } else {
      NULL
    }

    lf_result <- list(
      weights           = stacked$weights,
      train_predictions = stacked$predictions,
      valid_predictions = lf_valid_preds,
      score             = stacked$score
    )
  }

  structure(
    list(
      fits              = fits,
      selected_features = selected_features,
      selected_train    = selected_train,
      selected_valid    = selected_valid,
      early_fusion      = ef_result,
      late_fusion       = lf_result
    ),
    class = "stabl_multiomic_fit"
  )
}

#' Minimal Multi-Omic STABL Cross-Validation Workflow
#'
#' Builds deterministic fold splits over a named multi-omic input, fits
#' [stabl_multiomic_train_validate()] on each training fold, and returns
#' fold-wise selection diagnostics together with selected train/validation
#' matrices for downstream inspection.
#'
#' This function keeps the first CV slice narrow: it performs per-omic STABL
#' feature selection only and does not add downstream predictive refits,
#' early fusion, or late fusion.
#'
#' @param x_list Named list of omic tables (`data.frame` or numeric matrix),
#'   each with row names as sample IDs.
#' @param y Named outcome vector.
#' @param lambda_grid Either a shared lambda grid (`data.frame` or `"auto"`)
#'   used for all omics, or a named list mapping each omic name to its own
#'   lambda grid.
#' @param v Number of folds. Must be at least 2.
#' @param groups Optional named grouping vector. When supplied, all samples in
#'   the same group are assigned to the same assessment fold.
#' @param base_learner Passed to [stabl_fit()].
#' @param family Passed to [stabl_fit()].
#' @param n_bootstraps Passed to [stabl_fit()].
#' @param artificial_type Passed to [stabl_fit()].
#' @param hard_threshold Passed to [stabl_fit()].
#' @param random_state Optional integer seed used for deterministic fold
#'   assignment and forwarded to each per-fold [stabl_fit()] call.
#' @param early_fusion Logical.  Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call.
#' @param late_fusion Logical.  Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call.
#' @param n_iter_lf Forwarded to [stabl_multiomic_train_validate()].
#' @param ... Additional arguments forwarded to [stabl_fit()].
#'
#' @return A list with class `"stabl_multiomic_cv"` containing:
#'   \\describe{
#'     \\item{`folds`}{List of fold descriptors with `fold`, `train_ids`, and
#'       `valid_ids`.}
#'     \\item{`fold_results`}{Named list of per-fold
#'       `stabl_multiomic_fit` results.}
#'     \\item{`diagnostics`}{Data frame with one row per fold/omic and columns
#'       `fold`, `omic`, `n_selected`, `threshold`, and `max_score`.}
#'   }
#' @export
stabl_multiomic_cv <- function(
  x_list,
  y,
  lambda_grid,
  v               = 5L,
  groups          = NULL,
  base_learner    = "lasso",
  family          = "gaussian",
  n_bootstraps    = 100L,
  artificial_type = "random_permutation",
  hard_threshold  = NULL,
  random_state    = NULL,
  early_fusion    = FALSE,
  late_fusion     = FALSE,
  n_iter_lf       = 10000L,
  ...
) {
  validate_multiomic_inputs(x_list = x_list, y = y, groups = groups)

  sample_ids <- rownames(x_list[[1L]])
  folds <- .make_multiomic_cv_folds(
    sample_ids = sample_ids,
    groups = groups,
    v = v,
    random_state = random_state
  )

  fold_results <- vector("list", length(folds))
  names(fold_results) <- vapply(folds, function(fold) fold$fold, character(1L))

  diagnostics <- vector("list", length(folds))
  names(diagnostics) <- names(fold_results)

  for (fold_index in seq_along(folds)) {
    fold <- folds[[fold_index]]
    train_ids <- fold$train_ids
    valid_ids <- fold$valid_ids

    fold_fit <- stabl_multiomic_train_validate(
      x_train_list    = .subset_multiomic_rows(x_list, train_ids),
      y_train         = y[train_ids],
      lambda_grid     = lambda_grid,
      x_valid_list    = .subset_multiomic_rows(x_list, valid_ids),
      y_valid         = y[valid_ids],
      groups_train    = if (is.null(groups)) NULL else groups[train_ids],
      base_learner    = base_learner,
      family          = family,
      n_bootstraps    = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold  = hard_threshold,
      random_state    = random_state,
      early_fusion    = early_fusion,
      late_fusion     = late_fusion,
      n_iter_lf       = n_iter_lf,
      ...
    )

    fold_results[[fold_index]] <- fold_fit
    diagnostics[[fold_index]] <- .summarize_multiomic_fold(fold_fit, fold$fold)
  }

  structure(
    list(
      folds = folds,
      fold_results = fold_results,
      diagnostics = do.call(rbind, diagnostics)
    ),
    class = "stabl_multiomic_cv"
  )
}

.resolve_multiomic_lambda_grid <- function(lambda_grid, omic_names) {
  if (is.data.frame(lambda_grid) || identical(lambda_grid, "auto")) {
    out <- replicate(length(omic_names), lambda_grid, simplify = FALSE)
    names(out) <- omic_names
    return(out)
  }

  if (!is.list(lambda_grid) || is.null(names(lambda_grid))) {
    stop(
      "`lambda_grid` must be a data.frame, \"auto\", or a named list keyed by omic names.",
      call. = FALSE
    )
  }

  if (!setequal(names(lambda_grid), omic_names)) {
    stop(
      "When `lambda_grid` is a list, its names must match `x_train_list` names.",
      call. = FALSE
    )
  }

  lambda_grid[omic_names]
}

.validate_multiomic_validation_inputs <- function(x_valid_list,
                                                  y_valid,
                                                  train_omic_names) {
  if (!is.list(x_valid_list) || is.null(names(x_valid_list))) {
    stop("`x_valid_list` must be a named list when supplied.", call. = FALSE)
  }

  if (!setequal(names(x_valid_list), train_omic_names)) {
    stop(
      "`x_valid_list` names must match `x_train_list` names.",
      call. = FALSE
    )
  }

  for (omic in train_omic_names) {
    x_valid <- x_valid_list[[omic]]
    if (!(is.data.frame(x_valid) || is.matrix(x_valid))) {
      stop(sprintf("Validation omic '%s' must be a data.frame or matrix.", omic),
           call. = FALSE)
    }
    if (!is.null(y_valid)) {
      validate_sample_alignment(x = x_valid, y = y_valid, groups = NULL)
    }
  }

  invisible(NULL)
}

.subset_selected_matrix <- function(x, selected_features) {
  x_df <- if (is.matrix(x)) as.data.frame(x) else x
  as.matrix(x_df[, selected_features, drop = FALSE])
}

.subset_multiomic_rows <- function(x_list, sample_ids) {
  out <- lapply(x_list, function(x) {
    x_df <- if (is.matrix(x)) as.data.frame(x) else x
    x_df[sample_ids, , drop = FALSE]
  })
  names(out) <- names(x_list)
  out
}

.make_multiomic_cv_folds <- function(sample_ids,
                                     groups,
                                     v,
                                     random_state = NULL) {
  if (length(v) != 1L || is.na(v) || v < 2L) {
    stop("`v` must be a single integer greater than or equal to 2.", call. = FALSE)
  }

  v <- as.integer(v)

  units <- if (is.null(groups)) {
    sample_ids
  } else {
    as.character(unique(unname(groups[sample_ids])))
  }

  if (length(units) < v) {
    stop("The number of folds cannot exceed the number of samples/groups.",
         call. = FALSE)
  }

  ordered_units <- .permute_for_cv(units, random_state)
  unit_to_fold <- rep(seq_len(v), length.out = length(ordered_units))
  names(unit_to_fold) <- ordered_units

  assessment_fold <- if (is.null(groups)) {
    unit_to_fold[sample_ids]
  } else {
    unit_to_fold[as.character(groups[sample_ids])]
  }

  lapply(seq_len(v), function(fold_index) {
    valid_ids <- sample_ids[assessment_fold == fold_index]
    train_ids <- sample_ids[assessment_fold != fold_index]
    list(
      fold = paste0("Fold", fold_index),
      train_ids = train_ids,
      valid_ids = valid_ids
    )
  })
}

.permute_for_cv <- function(x, random_state = NULL) {
  if (is.null(random_state)) {
    return(sample(x, length(x), replace = FALSE))
  }

  if (length(random_state) != 1L || is.na(random_state)) {
    stop("`random_state` must be a single non-missing integer when supplied.",
         call. = FALSE)
  }

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
  sample(x, length(x), replace = FALSE)
}

.summarize_multiomic_fold <- function(fold_fit, fold_name) {
  omic_names <- names(fold_fit$fits)

  out <- data.frame(
    fold = rep(fold_name, length(omic_names)),
    omic = omic_names,
    n_selected = vapply(fold_fit$selected_features, length, integer(1L)),
    threshold = vapply(
      fold_fit$fits,
      .effective_multiomic_threshold,
      numeric(1L)
    ),
    max_score = vapply(
      fold_fit$fits,
      function(fit) {
        scores <- get_stabl_scores(fit)
        if (length(scores) == 0L) 0 else max(scores)
      },
      numeric(1L)
    ),
    stringsAsFactors = FALSE
  )

  rownames(out) <- NULL
  out
}

.effective_multiomic_threshold <- function(fit) {
  if (!is.null(fit$hard_threshold)) {
    return(fit$hard_threshold)
  }

  if (!is.null(fit$fdr_min_threshold_)) {
    return(fit$fdr_min_threshold_)
  }

  NA_real_
}

# ---------------------------------------------------------------------------
# AUC and R-squared helpers (no external dependencies)
# ---------------------------------------------------------------------------

# Wilcoxon rank-sum based AUC.  y must be 0/1.
.r_auc <- function(y, scores) {
  pos <- which(y == 1L)
  n1 <- length(pos)
  n0 <- length(y) - n1
  if (n1 == 0L || n0 == 0L) return(0.5)
  r <- rank(scores, ties.method = "average")
  (sum(r[pos]) - n1 * (n1 + 1L) / 2L) / (n1 * n0)
}

.r_squared <- function(y, y_hat) {
  ss_tot <- sum((y - mean(y))^2)
  if (ss_tot == 0) return(0)
  1 - sum((y - y_hat)^2) / ss_tot
}

# ---------------------------------------------------------------------------
# stacked_multi_omic
# ---------------------------------------------------------------------------

#' Stacked Generalization Over Per-Omic Predictions
#'
#' Finds optimal omic weights by random search, matching the Python
#' `stacked_multi_omic` algorithm from `stabl/stacked_generalization.py`.
#' Missing values in `predictions` are handled per-row: rows with all-NA
#' predictions receive `NA` in the stacked output.
#'
#' @param predictions A `data.frame` or numeric matrix with one column per
#'   omic and one row per sample.  Missing values (`NA`) are supported and
#'   treated as absent omics for those samples.
#' @param y Named numeric outcome vector aligned with rows of `predictions`.
#'   For `task_type = "binary"` values must be `0`/`1`.
#' @param task_type Either `"binary"` (maximise AUC) or `"regression"`
#'   (maximise R²).
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
#'     \item{`score`}{Best score achieved (AUC or R²).}
#'   }
#' @export
stacked_multi_omic <- function(
    predictions,
    y,
    task_type = c("binary", "regression"),
    n_iter    = 10000L,
    random_state = NULL
) {
  task_type <- match.arg(task_type)
  predictions <- as.matrix(predictions)
  n_omics   <- ncol(predictions)
  n_samples <- nrow(predictions)

  if (n_omics == 0L) {
    stop("`predictions` must have at least one column.", call. = FALSE)
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

  for (i in seq_len(as.integer(n_iter))) {
    weights <- stats::runif(n_omics, 0, 10)
    w_mat   <- matrix(weights, nrow = n_samples, ncol = n_omics, byrow = TRUE)
    is_obs  <- !is.na(predictions)
    denom   <- rowSums(is_obs * w_mat)
    num     <- rowSums(ifelse(is_obs, predictions * w_mat, 0))
    weighted_probs <- ifelse(denom > 0, num / denom, NA_real_)

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
      best_weights <- weights
      best_probs   <- weighted_probs
    }
  }

  weights_df        <- data.frame(Associated_weight = best_weights,
                                  row.names = colnames(predictions))
  preds_df          <- as.data.frame(predictions)
  preds_df[["Stacked Gen. Predictions"]] <- best_probs

  list(predictions = preds_df, weights = weights_df, score = best_score)
}

# ---------------------------------------------------------------------------
# Late-fusion helpers
# ---------------------------------------------------------------------------

# Infer task_type from glm family string.
.family_to_task_type <- function(family) {
  if (identical(family, "binomial")) "binary" else "regression"
}

# Fit a downstream predictor on selected features for one omic.
# Returns a list(train_preds, valid_preds, model) where valid_preds may be NULL.
.late_fusion_fit_omic <- function(x_train_sel, y_train,
                                  x_valid_sel = NULL, y_train_mean,
                                  task_type) {
  n_sel <- ncol(x_train_sel)

  if (n_sel == 0L) {
    fallback <- if (task_type == "binary") 0.5 else y_train_mean
    train_preds <- rep(fallback, nrow(x_train_sel))
    valid_preds <- if (!is.null(x_valid_sel)) rep(fallback, nrow(x_valid_sel)) else NULL
    return(list(train_preds = train_preds, valid_preds = valid_preds, model = NULL))
  }

  train_df      <- as.data.frame(x_train_sel)
  train_df$.y   <- unname(y_train)

  if (task_type == "binary") {
    m           <- stats::glm(.y ~ ., data = train_df,
                              family = stats::binomial(link = "logit"))
    train_preds <- unname(stats::predict(m, newdata = train_df, type = "response"))
    valid_preds <- if (!is.null(x_valid_sel)) {
      unname(stats::predict(m, newdata = as.data.frame(x_valid_sel),
                            type = "response"))
    } else NULL
  } else {
    m           <- stats::lm(.y ~ ., data = train_df)
    train_preds <- unname(stats::predict(m, newdata = train_df))
    valid_preds <- if (!is.null(x_valid_sel)) {
      unname(stats::predict(m, newdata = as.data.frame(x_valid_sel)))
    } else NULL
  }

  list(train_preds = train_preds, valid_preds = valid_preds, model = m)
}
