#' Multi-Omic STABL Train/Validation Workflow
#'
#' Fits [stabl_fit()] independently on each omic block from a named list,
#' then returns per-omic fitted objects and selected-feature matrices for
#' downstream composition. Optional early-fusion, late-fusion, and
#' cooperative-fusion branches are additive to the per-omic STABL results.
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
#' @param stratify_bootstrap Passed to [stabl_fit()]. When `TRUE`, per-omic
#'   and early-fusion STABL fits draw class-stratified bootstrap subsamples.
#' @param bootstrap_strata_train Optional categorical bootstrap stratification
#'   design for training samples, forwarded to [stabl_fit()].
#' @param l1_ratio Passed to [stabl_fit()] when `lambda_grid = "auto"`.
#'   Use this with `base_learner = "elastic_net"` to generate alpha-aware auto
#'   grids.
#' @param random_state Passed to [stabl_fit()].
#' @param ... Additional arguments forwarded to [stabl_fit()].
#'
#' @param early_fusion Logical.  When `TRUE`, a single [stabl_fit()] is run on
#'   the column-bound concatenation of all omic matrices in addition to the
#'   per-omic fits.  Results are returned in the `early_fusion` field.
#' @param late_fusion Logical.  When `TRUE`, a downstream predictor is fitted
#'   per omic on its selected features, and [stacked_multi_omic()] combines the
#'   per-omic predictions.  If no features are selected for an omic, late
#'   fusion falls back to class priors for multinomial tasks or the train-set
#'   mean for other tasks. The `task_type` (binary, regression, or multiclass)
#'   is inferred from `family`.  Results are returned in the `late_fusion`
#'   field.
#' @param n_iter_lf Number of random weight draws passed to
#'   [stacked_multi_omic()] during late fusion.  Ignored when
#'   `late_fusion = FALSE`.
#' @param cooperative_fusion Logical. When `TRUE`, fit a multiview-based
#'   cooperative learning branch in addition to the existing per-omic STABL
#'   fits. For `family = "multinomial"`, this runs an automatic one-vs-rest
#'   wrapper with one binomial cooperative model per class. Requires the
#'   optional `multiview` package.
#' @param rho Numeric scalar or vector of non-negative cooperation strengths.
#'   When `NULL`, defaults to `0` following [multiview::multiview()].
#' @param cooperation_selection Character scalar. Either `"cv"` or
#'   `"validation"`. `"cv"` tunes over `rho` with shared inner fold
#'   assignments. `"validation"` tunes over `rho` and `lambda` on the
#'   supplied validation set.
#' @param cooperation_selector Character scalar. Selection rule for the
#'   cooperative `lambda`. `"lambda.1se"` is only available when
#'   `cooperation_selection = "cv"`.
#' @param cooperation_type_measure Character scalar controlling the cooperative
#'   tuning metric. Supported values follow the active `family` and the
#'   multiview CV API; multinomial cooperative fusion uses binomial
#'   one-vs-rest tuning metrics.
#' @param cooperation_nfolds Number of inner folds used when
#'   `cooperation_selection = "cv"`.
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
#'       `valid_predictions`, and `score`; multinomial tasks also include
#'       `levels`, `log_loss`, and classification metrics.}
#'     \item{`cooperative_fusion`}{Present only when
#'       `cooperative_fusion = TRUE`. For scalar families, a list containing
#'       the selected multiview fit, chosen `rho` and `lambda`, selected
#'       features per view, train/validation predictions, and tuning
#'       diagnostics. For `family = "multinomial"`, a one-vs-rest result with
#'       class-specific cooperative fits, row-normalized class probabilities,
#'       class-specific selected features, and per-view union selections.}
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
    stratify_bootstrap = FALSE,
    bootstrap_strata_train = NULL,
    l1_ratio        = NULL,
    random_state    = NULL,
    early_fusion    = FALSE,
    late_fusion     = FALSE,
    n_iter_lf       = 10000L,
    cooperative_fusion = FALSE,
    rho             = NULL,
    cooperation_selection = c("cv", "validation"),
    cooperation_selector = c("lambda.min", "lambda.1se"),
    cooperation_type_measure = "default",
    cooperation_nfolds = 5L,
    ...
) {
  validate_multiomic_inputs(x_list = x_train_list, y = y_train,
                            groups = groups_train)

  omic_names <- names(x_train_list)
  train_ids <- rownames(x_train_list[[omic_names[1L]]])
  y_train <- .subset_outcome_by_ids(y_train, train_ids)
  if (!is.null(groups_train)) {
    groups_train <- groups_train[train_ids]
  }
  if (!is.null(bootstrap_strata_train)) {
    bootstrap_strata_train <- .subset_bootstrap_strata_by_ids(
      bootstrap_strata_train,
      sample_ids = train_ids,
      arg = "bootstrap_strata_train"
    )
  }
  lambda_by_omic <- .resolve_multiomic_lambda_grid(lambda_grid, omic_names)

  if (!is.null(x_valid_list)) {
    .validate_multiomic_validation_inputs(
      x_valid_list = x_valid_list,
      y_valid = y_valid,
      train_omic_names = omic_names
    )
    valid_ids <- rownames(x_valid_list[[omic_names[1L]]])
    if (!is.null(y_valid)) {
      y_valid <- .subset_outcome_by_ids(y_valid, valid_ids)
    }
  } else {
    valid_ids <- NULL
  }

  cooperative_args <- NULL
  if (isTRUE(cooperative_fusion)) {
    cooperative_args <- .normalize_cooperative_multiomic_args(
      x_list = x_train_list,
      family = family,
      rho = rho,
      cooperative_selection = cooperation_selection,
      cooperation_selector = cooperation_selector,
      cooperation_type_measure = cooperation_type_measure,
      cooperation_nfolds = cooperation_nfolds,
      x_valid_list = x_valid_list,
      y_valid = y_valid
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
    if (is.null(colnames(x_train))) {
      colnames(x_train) <- paste0("x.", seq_len(ncol(x_train)))
    }
    x_train_list[[omic]] <- x_train
    if (!is.null(x_valid_list)) {
      x_valid <- x_valid_list[[omic]]
      if (is.data.frame(x_valid)) x_valid <- as.matrix(x_valid)
      if (is.null(colnames(x_valid))) {
        if (ncol(x_valid) != ncol(x_train)) {
          stop(
            sprintf(
              "Validation omic '%s' has unnamed columns and a different column count from training.",
              omic
            ),
            call. = FALSE
          )
        }
        colnames(x_valid) <- colnames(x_train)
      }
      x_valid_list[[omic]] <- x_valid
    }

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
      stratify_bootstrap = stratify_bootstrap,
      bootstrap_strata = bootstrap_strata_train,
      l1_ratio = l1_ratio,
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
      stratify_bootstrap = stratify_bootstrap,
      bootstrap_strata = bootstrap_strata_train,
      l1_ratio     = l1_ratio,
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
    y_train_mean <- if (identical(task_type, "regression")) {
      mean(unname(y_train))
    } else {
      NA_real_
    }

    if (identical(task_type, "multiclass")) {
      train_preds <- vector("list", length(omic_names))
      names(train_preds) <- omic_names
      valid_preds <- if (!is.null(x_valid_list)) {
        out <- vector("list", length(omic_names))
        names(out) <- omic_names
        out
      } else {
        NULL
      }
    } else {
      train_preds <- matrix(
        NA_real_,
        nrow = length(y_train),
        ncol = length(omic_names),
        dimnames = list(names(y_train), omic_names)
      )
      valid_preds <- if (!is.null(x_valid_list)) {
        matrix(
          NA_real_,
          nrow = length(valid_ids),
          ncol = length(omic_names),
          dimnames = list(valid_ids, omic_names)
        )
      } else {
        NULL
      }
    }

    y_levels <- if (identical(task_type, "multiclass")) {
      levels(factor(y_train))
    } else {
      NULL
    }

    for (omic in omic_names) {
      omic_result <- .late_fusion_fit_omic(
        x_train_sel  = selected_train[[omic]],
        y_train      = y_train,
        x_valid_sel  = if (!is.null(x_valid_list)) selected_valid[[omic]] else NULL,
        y_train_mean = y_train_mean,
        task_type    = task_type,
        levels       = y_levels
      )
      if (identical(task_type, "multiclass")) {
        train_preds[[omic]] <- omic_result$train_preds
        if (!is.null(valid_preds)) {
          valid_preds[[omic]] <- omic_result$valid_preds
        }
      } else {
        train_preds[, omic] <- omic_result$train_preds
        if (!is.null(valid_preds)) {
          valid_preds[, omic] <- omic_result$valid_preds
        }
      }
    }

    stacked <- stacked_multi_omic(
      predictions  = train_preds,
      y            = unname(y_train),
      task_type    = task_type,
      n_iter       = n_iter_lf,
      random_state = random_state
    )

    lf_valid_preds <- if (is.null(valid_preds)) {
      NULL
    } else if (identical(task_type, "multiclass")) {
      .apply_multiclass_stack_weights(valid_preds, stacked$weights$Associated_weight)
    } else {
      w      <- stacked$weights$Associated_weight
      w_mat  <- matrix(w, nrow = nrow(valid_preds),
                       ncol = length(w), byrow = TRUE)
      is_obs <- !is.na(valid_preds)
      denom  <- rowSums(is_obs * w_mat)
      num    <- rowSums(ifelse(is_obs, valid_preds * w_mat, 0))
      ifelse(denom > 0, num / denom, NA_real_)
    }

    lf_result <- list(
      weights           = stacked$weights,
      train_predictions = stacked$predictions,
      valid_predictions = lf_valid_preds,
      score             = stacked$score
    )
    if (identical(task_type, "multiclass")) {
      lf_result$task_type <- task_type
      lf_result$levels <- stacked$levels
      lf_result$log_loss <- stacked$log_loss
      lf_result$train_metrics <- .classification_metrics(
        truth = factor(y_train, levels = stacked$levels),
        predicted = factor(stacked$predictions$predicted_class,
                           levels = stacked$levels)
      )
      if (!is.null(y_valid) && !is.null(lf_valid_preds)) {
        lf_result$valid_metrics <- .classification_metrics(
          truth = factor(y_valid, levels = stacked$levels),
          predicted = factor(lf_valid_preds$predicted_class,
                             levels = stacked$levels)
        )
      }
    }
  }

  # ---- Cooperative fusion --------------------------------------------------
  cf_result <- NULL
  if (isTRUE(cooperative_fusion)) {
    cf_result <- .cooperative_multiomic_fit(
      x_train_list = x_train_list,
      y_train = y_train,
      x_valid_list = x_valid_list,
      y_valid = y_valid,
      groups_train = groups_train,
      family = family,
      random_state = random_state,
      cooperative_args = cooperative_args
    )
  }

  out <- list(
    fits              = fits,
    selected_features = selected_features,
    selected_train    = selected_train,
    selected_valid    = selected_valid,
    early_fusion      = ef_result,
    late_fusion       = lf_result
  )

  if (!is.null(cf_result)) {
    out$cooperative_fusion <- cf_result
  }

  structure(
    out,
    class = "stabl_multiomic_fit"
  )
}

#' Multi-Omic STABL Cross-Validation Workflow
#'
#' Builds deterministic fold splits over a named multi-omic input, fits
#' [stabl_multiomic_train_validate()] on each training fold, and returns
#' fold-wise selection diagnostics together with selected train/validation
#' matrices for downstream inspection.
#'
#' Optional early-fusion, late-fusion, and cooperative-fusion branches are
#' forwarded to each fold-specific [stabl_multiomic_train_validate()] call.
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
#' @param stratify_bootstrap Passed to [stabl_fit()].
#' @param bootstrap_strata Optional categorical bootstrap stratification design
#'   forwarded to [stabl_fit()] for each training fold.
#' @param l1_ratio Passed to [stabl_fit()] when `lambda_grid = "auto"`.
#' @param random_state Optional integer seed used for deterministic fold
#'   assignment and forwarded to each per-fold [stabl_fit()] call.
#' @param early_fusion Logical.  Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call.
#' @param late_fusion Logical.  Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call.
#' @param n_iter_lf Forwarded to [stabl_multiomic_train_validate()].
#' @param cooperative_fusion Forwarded to
#'   [stabl_multiomic_train_validate()].
#' @param rho Forwarded to [stabl_multiomic_train_validate()].
#' @param cooperation_selection Forwarded to
#'   [stabl_multiomic_train_validate()].
#' @param cooperation_selector Forwarded to
#'   [stabl_multiomic_train_validate()].
#' @param cooperation_type_measure Forwarded to
#'   [stabl_multiomic_train_validate()].
#' @param cooperation_nfolds Forwarded to
#'   [stabl_multiomic_train_validate()].
#' @param ... Additional arguments forwarded to [stabl_fit()].
#'
#' @return A list with class `"stabl_multiomic_cv"` containing:
#'   \describe{
#'     \item{`folds`}{List of fold descriptors with `fold`, `train_ids`, and
#'       `valid_ids`.}
#'     \item{`fold_results`}{Named list of per-fold
#'       `stabl_multiomic_fit` results.}
#'     \item{`diagnostics`}{Data frame with one row per fold/omic and columns
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
  stratify_bootstrap = FALSE,
  bootstrap_strata = NULL,
  l1_ratio        = NULL,
  random_state    = NULL,
  early_fusion    = FALSE,
  late_fusion     = FALSE,
  n_iter_lf       = 10000L,
  cooperative_fusion = FALSE,
  rho               = NULL,
  cooperation_selection = c("cv", "validation"),
  cooperation_selector = c("lambda.min", "lambda.1se"),
  cooperation_type_measure = "default",
  cooperation_nfolds = 5L,
  ...
) {
  validate_multiomic_inputs(x_list = x_list, y = y, groups = groups)

  sample_ids <- rownames(x_list[[1L]])
  bootstrap_strata <- .subset_bootstrap_strata_by_ids(
    bootstrap_strata,
    sample_ids = sample_ids,
    arg = "bootstrap_strata"
  )
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
      y_train         = .subset_outcome_by_ids(y, train_ids),
      lambda_grid     = lambda_grid,
      x_valid_list    = .subset_multiomic_rows(x_list, valid_ids),
      y_valid         = .subset_outcome_by_ids(y, valid_ids),
      groups_train    = if (is.null(groups)) NULL else groups[train_ids],
      base_learner    = base_learner,
      family          = family,
      n_bootstraps    = n_bootstraps,
      artificial_type = artificial_type,
      hard_threshold  = hard_threshold,
      stratify_bootstrap = stratify_bootstrap,
      bootstrap_strata_train = .subset_bootstrap_strata_by_ids(
        bootstrap_strata,
        sample_ids = train_ids,
        arg = "bootstrap_strata"
      ),
      l1_ratio        = l1_ratio,
      random_state    = random_state,
      early_fusion    = early_fusion,
      late_fusion     = late_fusion,
      n_iter_lf       = n_iter_lf,
      cooperative_fusion = cooperative_fusion,
      rho             = rho,
      cooperation_selection = cooperation_selection,
      cooperation_selector = cooperation_selector,
      cooperation_type_measure = cooperation_type_measure,
      cooperation_nfolds = cooperation_nfolds,
      ...
    )

    fold_results[[fold_index]] <- fold_fit
    diagnostics[[fold_index]] <- .augment_multiomic_fold_diagnostics(
      .summarize_multiomic_fold(fold_fit, fold$fold),
      fold_fit = fold_fit
    )
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

  base_ids <- NULL
  for (omic in train_omic_names) {
    x_valid <- x_valid_list[[omic]]
    if (!(is.data.frame(x_valid) || is.matrix(x_valid))) {
      stop(sprintf("Validation omic '%s' must be a data.frame or matrix.", omic),
           call. = FALSE)
    }
    sample_ids <- rownames(x_valid)
    if (is.null(sample_ids) || anyNA(sample_ids) || any(sample_ids == "")) {
      stop(
        sprintf("Validation omic '%s' must have non-empty row names used as sample ids.", omic),
        call. = FALSE
      )
    }
    if (anyDuplicated(sample_ids)) {
      stop(
        sprintf("Validation omic '%s' row names must be unique sample ids.", omic),
        call. = FALSE
      )
    }
    if (is.null(base_ids)) {
      base_ids <- sample_ids
    } else if (!identical(base_ids, sample_ids)) {
      stop(
        sprintf("All validation omic tables must have identical sample order; mismatch at omic '%s'.", omic),
        call. = FALSE
      )
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

.coerce_multiomic_matrix_list <- function(x_list) {
  out <- lapply(x_list, function(x) {
    if (is.data.frame(x)) as.matrix(x) else x
  })
  names(out) <- names(x_list)
  out
}

.cooperative_family_to_multiview <- function(family) {
  switch(
    family,
    gaussian = stats::gaussian(),
    binomial = stats::binomial(),
    poisson = stats::poisson(),
    cox = "cox",
    stop(
      "`cooperative_fusion = TRUE` only supports family = 'gaussian', 'binomial', 'poisson', or 'cox'.",
      call. = FALSE
    )
  )
}

.cooperative_prediction_type <- function(family, type_measure) {
  if (identical(type_measure, "class")) {
    return("class")
  }

  if (identical(family, "binomial") && identical(type_measure, "deviance")) {
    return("response")
  }

  "link"
}

.cooperative_metric_direction <- function(type_measure) {
  if (type_measure %in% c("auc", "C")) "max" else "min"
}

.select_cooperative_metric_index <- function(metric_values, direction) {
  if (all(is.na(metric_values))) {
    stop("Cooperative tuning failed: all candidate metric values were NA.",
         call. = FALSE)
  }

  if (identical(direction, "max")) {
    which.max(replace(metric_values, is.na(metric_values), -Inf))
  } else {
    which.min(replace(metric_values, is.na(metric_values), Inf))
  }
}

.make_multiomic_foldid <- function(sample_ids,
                                   groups,
                                   v,
                                   random_state = NULL) {
  folds <- .make_multiomic_cv_folds(
    sample_ids = sample_ids,
    groups = groups,
    v = v,
    random_state = random_state
  )

  foldid <- integer(length(sample_ids))
  names(foldid) <- sample_ids

  for (fold_index in seq_along(folds)) {
    foldid[folds[[fold_index]]$valid_ids] <- fold_index
  }

  unname(foldid[sample_ids])
}

.cooperative_coerce_binary_outcome <- function(y) {
  if (is.factor(y)) {
    return(as.integer(y) - 1L)
  }

  y_num <- as.numeric(y)
  if (all(sort(unique(y_num)) %in% c(0, 1))) {
    return(as.integer(y_num))
  }

  as.integer(as.factor(y)) - 1L
}

.cooperative_binomial_deviance <- function(pred, y) {
  prob_min <- 1e-05
  prob_max <- 1 - prob_min
  nc <- dim(y)

  if (is.null(nc)) {
    y <- as.factor(y)
    ntab <- table(y)
    nc <- as.integer(length(ntab))
    y <- diag(nc)[as.numeric(y), , drop = FALSE]
  }

  pred <- pmin(pmax(as.numeric(pred), prob_min), prob_max)
  lp <- y[, 1] * log(1 - pred) + y[, 2] * log(pred)
  ly <- log(y)
  ly[y == 0] <- 0
  ly <- drop((y * ly) %*% c(1, 1))
  mean(2 * (ly - lp))
}

.cooperative_poisson_deviance <- function(eta, y) {
  y <- as.numeric(y)
  deveta <- y * eta - exp(eta)
  devy <- y * log(y) - y
  devy[y == 0] <- 0
  mean(2 * (devy - deveta))
}

.cooperative_validation_metric <- function(true_y,
                                           pred_y,
                                           family,
                                           type_measure) {
  switch(
    type_measure,
    mse = mean((as.numeric(true_y) - as.numeric(pred_y))^2),
    class = mean(as.character(true_y) != as.character(pred_y)),
    auc = .r_auc(.cooperative_coerce_binary_outcome(true_y), as.numeric(pred_y)),
    mae = mean(abs(as.numeric(true_y) - as.numeric(pred_y))),
    deviance = switch(
      family,
      gaussian = mean((as.numeric(true_y) - as.numeric(pred_y))^2),
      binomial = .cooperative_binomial_deviance(pred_y, true_y),
      poisson = .cooperative_poisson_deviance(pred_y, true_y),
      stop(
        sprintf(
          "Validation-based cooperative tuning does not support family '%s'.",
          family
        ),
        call. = FALSE
      )
    ),
    stop(sprintf("Unsupported cooperative type measure '%s'.", type_measure),
         call. = FALSE)
  )
}

.cooperative_predict <- function(fit,
                                 newx,
                                 s,
                                 family,
                                 type_measure) {
  prediction_type <- .cooperative_prediction_type(
    family = family,
    type_measure = type_measure
  )

  if (identical(prediction_type, "link")) {
    stats::predict(fit, newx = newx, s = s)
  } else {
    stats::predict(fit, newx = newx, s = s, type = prediction_type)
  }
}

.cooperative_prediction_matrix <- function(pred, n_rows) {
  if (length(dim(pred)) > 2L) {
    pred <- pred[, 1L, , drop = TRUE]
  }

  out <- as.matrix(pred)
  if (nrow(out) != n_rows) {
    out <- matrix(out, nrow = n_rows)
  }
  out
}

.cooperative_prediction_vector <- function(pred, sample_ids) {
  out <- as.vector(pred)
  names(out) <- sample_ids
  out
}

.cooperative_coefficient_table <- function(fit, s) {
  fit_core <- if (inherits(fit, "cv.multiview")) fit$multiview.fit else fit
  coef_mat <- as.matrix(stats::coef(fit, s = s))
  coef_vec <- as.numeric(coef_mat)

  col_names <- unlist(fit_core$colnames_list)
  view <- rep(names(fit_core$p_x), unlist(fit_core$p_x))

  if (length(coef_vec) == length(col_names) + 1L) {
    coef_vec <- coef_vec[-1L]
  }

  if (length(coef_vec) != length(col_names)) {
    stop(
      "Cooperative coefficient extraction failed: coefficient length did not match the multiview feature layout.",
      call. = FALSE
    )
  }

  data.frame(
    view = view,
    view_col = col_names,
    coef = coef_vec,
    stringsAsFactors = FALSE
  )
}

.cooperative_selected_features <- function(coef_table, omic_names) {
  out <- setNames(vector("list", length(omic_names)), omic_names)

  for (omic in omic_names) {
    out[[omic]] <- character(0)
  }

  if (is.null(coef_table) || nrow(coef_table) == 0L) {
    return(out)
  }

  for (omic in omic_names) {
    keep <- coef_table$view == omic & coef_table$coef != 0
    out[[omic]] <- unique(as.character(coef_table$view_col[keep]))
  }

  out
}

.augment_multiomic_fold_diagnostics <- function(diagnostics, fold_fit) {
  cooperative <- fold_fit$cooperative_fusion
  if (is.null(cooperative)) {
    return(diagnostics)
  }

  diagnostics$cooperative_rho <- cooperative$rho
  diagnostics$cooperative_lambda <- cooperative$selected_lambda
  diagnostics$cooperative_selection <- cooperative$selection
  diagnostics$cooperative_selector <- cooperative$selector
  diagnostics$cooperative_type_measure <- cooperative$type_measure
  diagnostics$cooperative_score <- cooperative$score
  diagnostics$cooperative_prediction_type <- cooperative$prediction_type
  diagnostics$cooperative_n_selected <- vapply(
    diagnostics$omic,
    function(omic) length(cooperative$selected_features[[omic]]),
    integer(1L)
  )

  diagnostics
}

.cooperative_multiomic_fit <- function(x_train_list,
                                       y_train,
                                       x_valid_list = NULL,
                                       y_valid = NULL,
                                       groups_train = NULL,
                                       family = "gaussian",
                                       random_state = NULL,
                                       cooperative_args,
                                       foldid = NULL) {
  if (identical(family, "multinomial")) {
    return(.cooperative_multiomic_fit_ovr(
      x_train_list = x_train_list,
      y_train = y_train,
      x_valid_list = x_valid_list,
      y_valid = y_valid,
      groups_train = groups_train,
      random_state = random_state,
      cooperative_args = cooperative_args
    ))
  }

  omic_names <- names(x_train_list)
  x_train_mv <- .coerce_multiomic_matrix_list(x_train_list)
  x_valid_mv <- if (is.null(x_valid_list)) NULL else .coerce_multiomic_matrix_list(x_valid_list)
  mv_family <- .cooperative_family_to_multiview(family)
  direction <- .cooperative_metric_direction(cooperative_args$cooperation_type_measure)

  if (identical(cooperative_args$cooperative_selection, "cv")) {
    if (is.null(foldid)) {
      foldid <- .make_multiomic_foldid(
        sample_ids = rownames(x_train_mv[[1L]]),
        groups = groups_train,
        v = cooperative_args$cooperation_nfolds,
        random_state = random_state
      )
    } else if (length(foldid) != nrow(x_train_mv[[1L]])) {
      stop("Shared cooperative `foldid` must have one value per training sample.",
           call. = FALSE)
    }

    cv_fits <- lapply(cooperative_args$rho, function(rho_value) {
      multiview::cv.multiview(
        x_list = x_train_mv,
        y = y_train,
        family = mv_family,
        rho = rho_value,
        type.measure = cooperative_args$cooperation_type_measure,
        foldid = foldid
      )
    })

    diagnostics <- do.call(rbind, lapply(seq_along(cv_fits), function(i) {
      fit <- cv_fits[[i]]
      selector <- cooperative_args$cooperation_selector
      lambda_value <- unname(fit[[selector]])
      lambda_index <- match(lambda_value, fit$lambda)
      data.frame(
        rho = cooperative_args$rho[[i]],
        lambda = lambda_value,
        metric_value = fit$cvm[[lambda_index]],
        selected = FALSE,
        stringsAsFactors = FALSE
      )
    }))

    best_index <- .select_cooperative_metric_index(diagnostics$metric_value,
                                                   direction)
    diagnostics$selected[[best_index]] <- TRUE

    best_fit <- cv_fits[[best_index]]
    best_rho <- diagnostics$rho[[best_index]]
    best_lambda <- diagnostics$lambda[[best_index]]
    best_score <- diagnostics$metric_value[[best_index]]
    selector <- cooperative_args$cooperation_selector

    train_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_train_mv,
      s = selector,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    valid_pred <- if (is.null(x_valid_mv)) {
      NULL
    } else {
      .cooperative_predict(
        fit = best_fit,
        newx = x_valid_mv,
        s = selector,
        family = family,
        type_measure = cooperative_args$cooperation_type_measure
      )
    }
    coef_table <- .cooperative_coefficient_table(best_fit, s = selector)
  } else {
    foldid <- NULL
    mv_fits <- lapply(cooperative_args$rho, function(rho_value) {
      multiview::multiview(
        x_list = x_train_mv,
        y = y_train,
        family = mv_family,
        rho = rho_value
      )
    })

    diagnostics_list <- vector("list", length(mv_fits))
    candidate_metric <- numeric(length(mv_fits))
    candidate_lambda <- numeric(length(mv_fits))

    for (i in seq_along(mv_fits)) {
      fit <- mv_fits[[i]]
      pred_path <- .cooperative_predict(
        fit = fit,
        newx = x_valid_mv,
        s = fit$lambda,
        family = family,
        type_measure = cooperative_args$cooperation_type_measure
      )
      pred_path <- .cooperative_prediction_matrix(pred_path, length(y_valid))

      metric_path <- vapply(seq_along(fit$lambda), function(lambda_index) {
        .cooperative_validation_metric(
          true_y = y_valid,
          pred_y = pred_path[, lambda_index],
          family = family,
          type_measure = cooperative_args$cooperation_type_measure
        )
      }, numeric(1L))

      selected_index <- .select_cooperative_metric_index(metric_path, direction)
      candidate_metric[[i]] <- metric_path[[selected_index]]
      candidate_lambda[[i]] <- fit$lambda[[selected_index]]
      diagnostics_list[[i]] <- data.frame(
        rho = cooperative_args$rho[[i]],
        lambda = fit$lambda,
        metric_value = metric_path,
        selected = FALSE,
        stringsAsFactors = FALSE
      )
    }

    best_index <- .select_cooperative_metric_index(candidate_metric, direction)
    best_fit <- mv_fits[[best_index]]
    best_rho <- cooperative_args$rho[[best_index]]
    best_lambda <- candidate_lambda[[best_index]]
    best_score <- candidate_metric[[best_index]]
    selector <- "lambda.min"

    diagnostics <- do.call(rbind, diagnostics_list)
    selected_row <- which(diagnostics$rho == best_rho & diagnostics$lambda == best_lambda)[1L]
    diagnostics$selected[[selected_row]] <- TRUE

    train_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_train_mv,
      s = best_lambda,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    valid_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_valid_mv,
      s = best_lambda,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    coef_table <- .cooperative_coefficient_table(best_fit, s = best_lambda)
  }

  selected_features <- .cooperative_selected_features(coef_table, omic_names)
  selected_train <- setNames(vector("list", length(omic_names)), omic_names)
  selected_valid <- if (is.null(x_valid_list)) NULL else setNames(vector("list", length(omic_names)), omic_names)

  for (omic in omic_names) {
    selected_train[[omic]] <- .subset_selected_matrix(x_train_list[[omic]], selected_features[[omic]])
    if (!is.null(selected_valid)) {
      selected_valid[[omic]] <- .subset_selected_matrix(x_valid_list[[omic]], selected_features[[omic]])
    }
  }

  list(
    fit = best_fit,
    rho = best_rho,
    rho_grid = cooperative_args$rho,
    selection = cooperative_args$cooperative_selection,
    selector = selector,
    type_measure = cooperative_args$cooperation_type_measure,
    prediction_type = .cooperative_prediction_type(
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    ),
    score = best_score,
    selected_lambda = best_lambda,
    selected_features = selected_features,
    selected_train = selected_train,
    selected_valid = selected_valid,
    train_predictions = .cooperative_prediction_vector(
      train_pred,
      rownames(x_train_mv[[1L]])
    ),
    valid_predictions = if (is.null(valid_pred)) NULL else {
      .cooperative_prediction_vector(valid_pred, rownames(x_valid_mv[[1L]]))
    },
    diagnostics = diagnostics,
    foldid = foldid
  )
}

.cooperative_multiomic_fit_ovr <- function(x_train_list,
                                           y_train,
                                           x_valid_list = NULL,
                                           y_valid = NULL,
                                           groups_train = NULL,
                                           random_state = NULL,
                                           cooperative_args) {
  omic_names <- names(x_train_list)
  x_train_mv <- .coerce_multiomic_matrix_list(x_train_list)
  x_valid_mv <- if (is.null(x_valid_list)) NULL else .coerce_multiomic_matrix_list(x_valid_list)

  y_train_factor <- droplevels(factor(y_train))
  names(y_train_factor) <- names(y_train)
  class_levels <- levels(y_train_factor)
  if (length(class_levels) < 3L) {
    stop(
      "One-vs-rest cooperative fusion for `family = 'multinomial'` requires at least three training classes.",
      call. = FALSE
    )
  }

  y_valid_factor <- NULL
  if (!is.null(y_valid)) {
    y_valid_factor <- factor(y_valid, levels = class_levels)
    names(y_valid_factor) <- names(y_valid)
    if (anyNA(y_valid_factor)) {
      stop(
        "Validation labels for one-vs-rest cooperative fusion must all be present in the training classes.",
        call. = FALSE
      )
    }
  }

  shared_foldid <- NULL
  if (identical(cooperative_args$cooperative_selection, "cv")) {
    shared_foldid <- .make_multiomic_foldid(
      sample_ids = rownames(x_train_mv[[1L]]),
      groups = groups_train,
      v = cooperative_args$cooperation_nfolds,
      random_state = random_state
    )
  }

  class_args <- cooperative_args
  class_args$task_type <- "binomial"

  class_results <- setNames(vector("list", length(class_levels)), class_levels)
  for (class_level in class_levels) {
    y_binary <- setNames(
      as.integer(y_train_factor == class_level),
      names(y_train_factor)
    )
    y_valid_binary <- if (is.null(y_valid_factor)) {
      NULL
    } else {
      setNames(as.integer(y_valid_factor == class_level), names(y_valid_factor))
    }

    class_results[[class_level]] <- .cooperative_multiomic_fit(
      x_train_list = x_train_list,
      y_train = y_binary,
      x_valid_list = x_valid_list,
      y_valid = y_valid_binary,
      groups_train = groups_train,
      family = "binomial",
      random_state = random_state,
      cooperative_args = class_args,
      foldid = shared_foldid
    )
  }

  selected_features_by_class <- lapply(class_results, function(result) {
    result$selected_features
  })
  selected_features <- .cooperative_union_selected_features(
    selected_features_by_class = selected_features_by_class,
    omic_names = omic_names
  )

  selected_train <- setNames(vector("list", length(omic_names)), omic_names)
  selected_valid <- if (is.null(x_valid_list)) NULL else setNames(vector("list", length(omic_names)), omic_names)
  for (omic in omic_names) {
    selected_train[[omic]] <- .subset_selected_matrix(x_train_list[[omic]], selected_features[[omic]])
    if (!is.null(selected_valid)) {
      selected_valid[[omic]] <- .subset_selected_matrix(x_valid_list[[omic]], selected_features[[omic]])
    }
  }

  train_prob <- .cooperative_ovr_probability_matrix(
    class_results = class_results,
    newx = x_train_mv,
    sample_ids = rownames(x_train_mv[[1L]]),
    class_levels = class_levels
  )
  train_predictions <- .cooperative_ovr_prediction_frame(train_prob)
  log_loss <- .multiclass_log_loss(y_train_factor, train_prob)

  valid_prob <- NULL
  valid_predictions <- NULL
  valid_log_loss <- NULL
  valid_metrics <- NULL
  if (!is.null(x_valid_mv)) {
    valid_prob <- .cooperative_ovr_probability_matrix(
      class_results = class_results,
      newx = x_valid_mv,
      sample_ids = rownames(x_valid_mv[[1L]]),
      class_levels = class_levels
    )
    valid_predictions <- .cooperative_ovr_prediction_frame(valid_prob)
    if (!is.null(y_valid_factor)) {
      valid_log_loss <- .multiclass_log_loss(y_valid_factor, valid_prob)
      valid_metrics <- .classification_metrics(
        truth = factor(y_valid_factor, levels = class_levels),
        predicted = factor(valid_predictions$predicted_class,
                           levels = class_levels)
      )
    }
  }

  diagnostics <- do.call(rbind, lapply(class_levels, function(class_level) {
    data.frame(
      class = class_level,
      class_results[[class_level]]$diagnostics,
      stringsAsFactors = FALSE
    )
  }))
  rownames(diagnostics) <- NULL

  class_summary <- do.call(rbind, lapply(class_levels, function(class_level) {
    result <- class_results[[class_level]]
    data.frame(
      class = class_level,
      rho = result$rho,
      selected_lambda = result$selected_lambda,
      score = result$score,
      n_selected = sum(vapply(result$selected_features, length, integer(1L))),
      stringsAsFactors = FALSE
    )
  }))
  rownames(class_summary) <- NULL

  fitted_models <- lapply(class_results, function(result) result$fit)

  out <- list(
    fit = fitted_models,
    task_type = "multiclass_ovr",
    levels = class_levels,
    class_results = class_results,
    class_summary = class_summary,
    selected_features_by_class = selected_features_by_class,
    rho = NA_real_,
    rho_grid = cooperative_args$rho,
    selection = cooperative_args$cooperative_selection,
    selector = cooperative_args$cooperation_selector,
    type_measure = cooperative_args$cooperation_type_measure,
    prediction_type = "response",
    score = -log_loss,
    log_loss = log_loss,
    selected_lambda = NA_real_,
    selected_features = selected_features,
    selected_train = selected_train,
    selected_valid = selected_valid,
    train_predictions = train_predictions,
    valid_predictions = valid_predictions,
    train_metrics = .classification_metrics(
      truth = factor(y_train_factor, levels = class_levels),
      predicted = factor(train_predictions$predicted_class,
                         levels = class_levels)
    ),
    diagnostics = diagnostics,
    foldid = shared_foldid
  )

  if (!is.null(valid_log_loss)) {
    out$valid_log_loss <- valid_log_loss
  }
  if (!is.null(valid_metrics)) {
    out$valid_metrics <- valid_metrics
  }

  out
}

.cooperative_union_selected_features <- function(selected_features_by_class,
                                                 omic_names) {
  out <- setNames(vector("list", length(omic_names)), omic_names)
  for (omic in omic_names) {
    out[[omic]] <- unique(unlist(
      lapply(selected_features_by_class, function(class_features) {
        class_features[[omic]]
      }),
      use.names = FALSE
    ))
    if (is.null(out[[omic]])) {
      out[[omic]] <- character(0)
    }
  }
  out
}

.cooperative_binomial_response_predict <- function(fit,
                                                   newx,
                                                   s,
                                                   sample_ids) {
  pred <- stats::predict(fit, newx = newx, s = s, type = "response")
  pred_mat <- .cooperative_prediction_matrix(pred, length(sample_ids))
  out <- as.numeric(pred_mat[, 1L])
  names(out) <- sample_ids
  out
}

.cooperative_ovr_probability_matrix <- function(class_results,
                                                newx,
                                                sample_ids,
                                                class_levels,
                                                eps = 1e-15) {
  prob <- matrix(
    NA_real_,
    nrow = length(sample_ids),
    ncol = length(class_levels),
    dimnames = list(sample_ids, class_levels)
  )

  for (class_level in class_levels) {
    result <- class_results[[class_level]]
    s <- if (identical(result$selection, "cv")) {
      result$selector
    } else {
      result$selected_lambda
    }
    prob[, class_level] <- .cooperative_binomial_response_predict(
      fit = result$fit,
      newx = newx,
      s = s,
      sample_ids = sample_ids
    )
  }

  prob[!is.finite(prob)] <- eps
  prob <- pmin(pmax(prob, eps), 1 - eps)

  row_totals <- rowSums(prob)
  bad_rows <- !is.finite(row_totals) | row_totals <= 0
  if (any(bad_rows)) {
    prob[bad_rows, ] <- 1 / ncol(prob)
    row_totals <- rowSums(prob)
  }

  prob / row_totals
}

.cooperative_ovr_prediction_frame <- function(prob) {
  out <- as.data.frame(prob, check.names = FALSE)
  names(out) <- paste0("prob_", names(out))
  class_levels <- colnames(prob)
  out$predicted_class <- class_levels[max.col(prob, ties.method = "first")]
  out
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
#' @param predictions For `task_type = "binary"` or `"regression"`, a
#'   `data.frame` or numeric matrix with one column per omic and one row per
#'   sample. For `task_type = "multiclass"`, a named list of class-probability
#'   matrices/data frames, one per omic, with samples in rows and classes in
#'   columns.
#' @param y Named numeric outcome vector aligned with rows of `predictions`.
#'   For `task_type = "binary"` values must be `0`/`1`; for
#'   `task_type = "multiclass"`, values are coerced to a factor with levels
#'   matching the probability columns, and every label must be present in those
#'   columns.
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

# ---------------------------------------------------------------------------
# Late-fusion helpers
# ---------------------------------------------------------------------------

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

# Fit a downstream predictor on selected features for one omic.
# Returns a list(train_preds, valid_preds, model) where valid_preds may be NULL.
.late_fusion_fit_omic <- function(x_train_sel, y_train,
                                  x_valid_sel = NULL, y_train_mean,
                                  task_type,
                                  levels = NULL) {
  n_sel <- ncol(x_train_sel)

  if (identical(task_type, "multiclass")) {
    levels <- levels %||% levels(factor(y_train))
    y_train <- factor(y_train, levels = levels)
    priors <- as.numeric(table(y_train) / length(y_train))
    names(priors) <- levels
    fallback_matrix <- function(n, row_names) {
      out <- matrix(
        rep(priors, each = n),
        nrow = n,
        ncol = length(priors),
        dimnames = list(row_names, names(priors))
      )
      out
    }
    if (n_sel == 0L) {
      train_preds <- fallback_matrix(nrow(x_train_sel), rownames(x_train_sel))
      valid_preds <- if (!is.null(x_valid_sel)) {
        fallback_matrix(nrow(x_valid_sel), rownames(x_valid_sel))
      } else {
        NULL
      }
      return(list(train_preds = train_preds, valid_preds = valid_preds, model = NULL))
    }

    model_fit <- tryCatch({
      glmnet::cv.glmnet(
        x = as.matrix(x_train_sel),
        y = y_train,
        family = "multinomial",
        type.measure = "class",
        nfolds = min(5L, min(table(y_train)))
      )
    }, error = function(e) NULL)

    if (is.null(model_fit)) {
      train_preds <- fallback_matrix(nrow(x_train_sel), rownames(x_train_sel))
      valid_preds <- if (!is.null(x_valid_sel)) {
        fallback_matrix(nrow(x_valid_sel), rownames(x_valid_sel))
      } else {
        NULL
      }
      return(list(train_preds = train_preds, valid_preds = valid_preds, model = NULL))
    }

    coerce_prob <- function(pred, row_names) {
      pred <- as.matrix(pred[, , 1L])
      pred <- pred[, levels, drop = FALSE]
      rownames(pred) <- row_names
      pred
    }

    train_preds <- coerce_prob(
      stats::predict(model_fit, newx = as.matrix(x_train_sel),
                     s = "lambda.min", type = "response"),
      rownames(x_train_sel)
    )
    valid_preds <- if (!is.null(x_valid_sel)) {
      coerce_prob(
        stats::predict(model_fit, newx = as.matrix(x_valid_sel),
                       s = "lambda.min", type = "response"),
        rownames(x_valid_sel)
      )
    } else {
      NULL
    }
    return(list(train_preds = train_preds, valid_preds = valid_preds, model = model_fit))
  }

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
