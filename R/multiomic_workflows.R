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
#' @param late_fusion Logical.  When `TRUE`, a downstream unpenalized
#'   predictor is fitted per omic on its selected features, and
#'   [stacked_multi_omic()] combines the per-omic predictions.  If no features
#'   are selected for an omic, the downstream predictor is fitted as an
#'   intercept-only model. The `task_type` (binary, regression, or multiclass)
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
#'     \item{`refits`}{Named list of per-omic unpenalized final-refit
#'       objects fitted on each omic's STABL-selected features.}
#'     \item{`selected_features`}{Named list of selected feature names.}
#'     \item{`selected_train`}{Named list of training matrices restricted to
#'       selected features (possibly 0-column).}
#'     \item{`selected_valid`}{Named list of validation matrices restricted to
#'       selected features, or `NULL` when no validation input is provided.}
#'     \item{`early_fusion`}{`NULL` when `early_fusion = FALSE`.  Otherwise a
#'       list with `fit`, `refit`, `selected_features`, `selected_train`, and
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

  refit_task_type <- .stabl_refit_task_type(family)
  refit_levels <- if (identical(refit_task_type, "multiclass")) {
    levels(factor(y_train))
  } else {
    NULL
  }
  refits <- vector("list", length(omic_names))
  names(refits) <- omic_names

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

    refits[[omic]] <- .fit_stabl_final_model(
      x_train_sel = selected_train[[omic]],
      y_train = y_train,
      task_type = refit_task_type,
      levels = refit_levels
    )
    refits[[omic]]$valid_predictions <- if (!is.null(x_valid_list)) {
      .predict_stabl_final_model(
        refits[[omic]],
        selected_valid[[omic]],
        type = "response"
      )
    } else {
      NULL
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
    ef_train_mat  <- .stabl_subset_selected_matrix(x_all_train, ef_sel)

    ef_valid_mat <- if (!is.null(x_valid_list)) {
      x_all_valid <- do.call(cbind, lapply(omic_names, function(omic) {
        x <- x_valid_list[[omic]]
        if (is.data.frame(x)) as.matrix(x) else x
      }))
      .stabl_subset_selected_matrix(x_all_valid, ef_sel)
    } else {
      NULL
    }

    ef_refit <- .fit_stabl_final_model(
      x_train_sel = ef_train_mat,
      y_train = y_train,
      task_type = refit_task_type,
      levels = refit_levels
    )
    ef_refit$valid_predictions <- if (!is.null(ef_valid_mat)) {
      .predict_stabl_final_model(ef_refit, ef_valid_mat, type = "response")
    } else {
      NULL
    }

    ef_result <- list(
      fit               = ef_fit,
      refit             = ef_refit,
      selected_features = ef_sel,
      selected_train    = ef_train_mat,
      selected_valid    = ef_valid_mat
    )
  }

  # ---- Late fusion ---------------------------------------------------------
  lf_result <- NULL
  if (isTRUE(late_fusion)) {
    if (identical(family, "cox")) {
      stop("`late_fusion = TRUE` does not support `family = 'cox'`.",
           call. = FALSE)
    }
    task_type    <- .family_to_task_type(family)

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

    for (omic in omic_names) {
      omic_result <- refits[[omic]]
      if (identical(task_type, "multiclass")) {
        train_preds[[omic]] <- omic_result$training_predictions
        if (!is.null(valid_preds)) {
          valid_preds[[omic]] <- omic_result$valid_predictions
        }
      } else {
        train_preds[, omic] <- omic_result$training_predictions
        if (!is.null(valid_preds)) {
          valid_preds[, omic] <- omic_result$valid_predictions
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
    refits            = refits,
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
