#' Multi-Omic STABL Train/Validation Workflow
#'
#' Fits [stabl_fit()] independently on each omic block from a named list,
#' then returns per-omic fitted objects and selected-feature matrices for
#' downstream composition. Optional Early Fusion, canonical Late Fusion,
#' STABL-Selected Late Fusion, Multi-Omic STABL, and Cooperative Fusion
#' branches are additive to the per-omic STABL results. Their outputs remain
#' separated in `early_fusion`, `late_fusion`,
#' `stabl_selected_late_fusion`, `multiomic_stabl`, and
#' `cooperative_fusion`.
#'
#' @param x_train_list Named list of training omic tables (`data.frame` or
#'   numeric matrix), each with row names as sample IDs.
#' @param y_train Named outcome vector for training samples.
#' @param lambda_grid Either a shared lambda grid (`data.frame` or `"auto"`)
#'   used for all omics, or a named list mapping each omic name to its own
#'   lambda grid. When `early_fusion = TRUE`, this must be a shared grid
#'   (`data.frame` or `"auto"`); per-omic lambda lists are rejected because
#'   Early Fusion has one concatenated input space.
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
#'   per-omic fits. Combined Early Fusion feature names are prefixed as
#'   `<Omic View>__<original feature>` to preserve provenance. Results are
#'   returned in the `early_fusion` field.
#' @param late_fusion Logical. When `TRUE`, fit an independent penalized
#'   glmnet predictor on each full omic matrix, collect the per-omic
#'   predictions, and combine those predictions with [stacked_multi_omic()].
#'   This is canonical prediction-level Late Fusion: it does not use STABL
#'   feature selection and it does not concatenate selected biomarkers.
#'   Results are returned in the `late_fusion` field.
#' @param stabl_selected_late_fusion Logical.  When `TRUE`, a downstream
#'   unpenalized predictor is fitted per omic on its selected features, and
#'   [stacked_multi_omic()] combines the per-omic predictions.  If no features
#'   are selected for an omic, the downstream predictor is fitted as an
#'   intercept-only model. The `task_type` (binary, regression, or multiclass)
#'   is inferred from `family`. Results are returned in the
#'   `stabl_selected_late_fusion` field. This is a STABL-selected hybrid
#'   comparator, not canonical Late Fusion as defined in the paper taxonomy.
#' @param n_iter_stacking Number of random weight draws passed to
#'   [stacked_multi_omic()] during canonical Late Fusion and STABL-Selected
#'   Late Fusion. Ignored when both `late_fusion = FALSE` and
#'   `stabl_selected_late_fusion = FALSE`.
#' @param multiomic_stabl Logical. When `TRUE`, concatenate the per-omic
#'   STABL-selected biomarkers into one final-layer matrix and fit a single
#'   downstream unpenalized final refit on that combined selected set. This is
#'   distinct from canonical Late Fusion and STABL-Selected Late Fusion, which
#'   combine prediction outputs.
#' @param cooperative_fusion Logical. When `TRUE`, fit a multiview-based
#'   cooperative comparator branch in addition to the existing per-omic STABL
#'   fits. This branch is outside the formal Early Fusion, Late Fusion, and
#'   Multi-Omic STABL taxonomy. For `family = "multinomial"`, this runs an
#'   automatic one-vs-rest wrapper with one binomial cooperative model per
#'   class. Requires the optional `multiview` package.
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
#'       list with `fit`, `refit`, Omic View-prefixed `selected_features`,
#'       `selected_train`, and `selected_valid` for the concatenated
#'       single-STABL run.}
#'     \item{`late_fusion`}{`NULL` when `late_fusion = FALSE`. Otherwise a list
#'       with per-view penalized `models`, stacking `weights`,
#'       `train_predictions`, `valid_predictions`, and `score`; multinomial
#'       tasks also include `levels`, `log_loss`, and classification metrics.}
#'     \item{`stabl_selected_late_fusion`}{`NULL` when
#'       `stabl_selected_late_fusion = FALSE`. Otherwise a list with
#'       `weights` (data.frame), `train_predictions` (data.frame),
#'       `valid_predictions`, and `score`; multinomial tasks also include
#'       `levels`, `log_loss`, and classification metrics.}
#'     \item{`multiomic_stabl`}{Present only when `multiomic_stabl = TRUE`.
#'       A list containing per-view selected features, a provenance map,
#'       prefixed combined selected train/validation matrices, one final
#'       refit, train/validation predictions, and metrics where defined.}
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
    stabl_selected_late_fusion = FALSE,
    n_iter_stacking = 10000L,
    multiomic_stabl = FALSE,
    cooperative_fusion = FALSE,
    rho             = NULL,
    cooperation_selection = c("cv", "validation"),
    cooperation_selector = c("lambda.min", "lambda.1se"),
    cooperation_type_measure = "default",
    cooperation_nfolds = 5L,
    ...
) {
  extra_args <- list(...)
  .reject_retired_stacking_args(extra_args)
  validate_multiomic_inputs(x_list = x_train_list, y = y_train,
                            groups = groups_train)

  omic_names <- names(x_train_list)
  if (isTRUE(early_fusion) || isTRUE(multiomic_stabl)) {
    .validate_prefixed_omic_names(omic_names)
  }
  early_fusion_lambda <- NULL
  if (isTRUE(early_fusion)) {
    early_fusion_lambda <- .resolve_early_fusion_lambda_grid(lambda_grid)
  }
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
  if (identical(family, "cox") && isTRUE(late_fusion)) {
    stop("`late_fusion = TRUE` does not support `family = 'cox'`.",
         call. = FALSE)
  }
  if (identical(family, "cox") && isTRUE(stabl_selected_late_fusion)) {
    stop("`stabl_selected_late_fusion = TRUE` does not support `family = 'cox'`.",
         call. = FALSE)
  }

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
      if (is.data.frame(x)) x <- as.matrix(x)
      .prefix_omic_matrix(x, omic)
    }))

    ef_fit <- stabl_fit(
      x            = x_all_train,
      y            = y_train,
      lambda_grid  = early_fusion_lambda,
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
        if (is.data.frame(x)) x <- as.matrix(x)
        .prefix_omic_matrix(x, omic)
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

  # ---- Canonical late fusion ----------------------------------------------
  late_fusion_result <- NULL
  if (isTRUE(late_fusion)) {
    task_type <- .family_to_task_type(family)
    late_fusion_models <- vector("list", length(omic_names))
    names(late_fusion_models) <- omic_names

    for (omic in omic_names) {
      late_fusion_models[[omic]] <- .fit_late_fusion_glmnet_model(
        x_train = x_train_list[[omic]],
        y_train = y_train,
        x_valid = if (is.null(x_valid_list)) NULL else x_valid_list[[omic]],
        family = family,
        base_learner = base_learner,
        lambda_grid = lambda_by_omic[[omic]],
        l1_ratio = l1_ratio,
        n_lambda = extra_args[["n_lambda"]] %||% 30L,
        adaptive_gamma = extra_args[["adaptive_gamma"]] %||% 1.0,
        adaptive_epsilon = extra_args[["adaptive_epsilon"]] %||% 1e-6
      )
    }

    late_fusion_result <- c(
      list(models = late_fusion_models),
      .stack_per_view_predictions(
        per_view_models = late_fusion_models,
        omic_names = omic_names,
        y_train = y_train,
        y_valid = y_valid,
        valid_ids = valid_ids,
        task_type = task_type,
        n_iter_stacking = n_iter_stacking,
        random_state = random_state
      )
    )
  }

  # ---- STABL-selected late fusion -----------------------------------------
  lf_result <- NULL
  if (isTRUE(stabl_selected_late_fusion)) {
    task_type    <- .family_to_task_type(family)
    lf_result <- .stack_per_view_predictions(
      per_view_models = refits,
      omic_names = omic_names,
      y_train = y_train,
      y_valid = y_valid,
      valid_ids = valid_ids,
      task_type = task_type,
      n_iter_stacking = n_iter_stacking,
      random_state = random_state
    )
  }

  # ---- Multi-Omic STABL final layer ---------------------------------------
  mos_result <- NULL
  if (isTRUE(multiomic_stabl)) {
    mos_result <- .fit_multiomic_stabl_final_layer(
      selected_train = selected_train,
      selected_valid = selected_valid,
      selected_features = selected_features,
      y_train = y_train,
      y_valid = y_valid,
      task_type = refit_task_type,
      levels = refit_levels
    )
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
    late_fusion       = late_fusion_result,
    stabl_selected_late_fusion = lf_result
  )

  if (!is.null(mos_result)) {
    out$multiomic_stabl <- mos_result
  }

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
#' Optional Early Fusion, canonical Late Fusion, STABL-Selected Late Fusion,
#' Multi-Omic STABL, and Cooperative Fusion branches are forwarded to each
#' fold-specific
#' [stabl_multiomic_train_validate()] call.
#'
#' @param x_list Named list of omic tables (`data.frame` or numeric matrix),
#'   each with row names as sample IDs.
#' @param y Named outcome vector.
#' @param lambda_grid Either a shared lambda grid (`data.frame` or `"auto"`)
#'   used for all omics, or a named list mapping each omic name to its own
#'   lambda grid. When `early_fusion = TRUE`, this must be a shared grid
#'   (`data.frame` or `"auto"`); per-omic lambda lists are rejected because
#'   Early Fusion has one concatenated input space.
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
#' @param late_fusion Logical. Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call. This enables canonical
#'   prediction-level Late Fusion.
#' @param stabl_selected_late_fusion Logical. Forwarded to each per-fold
#'   [stabl_multiomic_train_validate()] call. This enables the
#'   STABL-selected late-fusion comparator.
#' @param n_iter_stacking Forwarded to [stabl_multiomic_train_validate()].
#' @param multiomic_stabl Forwarded to [stabl_multiomic_train_validate()].
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
#'       `fold`, `omic`, `n_selected`, `threshold`, and `max_score`. This
#'       table summarizes the per-omic STABL selector. When
#'       `multiomic_stabl = TRUE`, combined final-layer details remain inside
#'       `fold_results[[fold]]$multiomic_stabl` rather than being promoted to
#'       top-level diagnostic rows.}
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
  stabl_selected_late_fusion = FALSE,
  n_iter_stacking = 10000L,
  multiomic_stabl = FALSE,
  cooperative_fusion = FALSE,
  rho               = NULL,
  cooperation_selection = c("cv", "validation"),
  cooperation_selector = c("lambda.min", "lambda.1se"),
  cooperation_type_measure = "default",
  cooperation_nfolds = 5L,
  ...
) {
  .reject_retired_stacking_args(list(...))
  validate_multiomic_inputs(x_list = x_list, y = y, groups = groups)
  if (isTRUE(early_fusion)) {
    .resolve_early_fusion_lambda_grid(lambda_grid)
  }

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
      stabl_selected_late_fusion = stabl_selected_late_fusion,
      n_iter_stacking = n_iter_stacking,
      multiomic_stabl = multiomic_stabl,
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

.reject_retired_stacking_args <- function(args) {
  retired <- intersect(names(args), "n_iter_lf")
  if (length(retired) == 0L) {
    return(invisible(NULL))
  }

  replacements <- c(
    n_iter_lf = "n_iter_stacking"
  )
  details <- paste0(
    "`", retired, "` was renamed to `", replacements[retired], "`",
    collapse = "; "
  )
  stop(
    paste0(
      details,
      ". `late_fusion` now names canonical prediction-level fusion; use ",
      "`stabl_selected_late_fusion` for the STABL-selected hybrid."
    ),
    call. = FALSE
  )
}

.fit_late_fusion_glmnet_model <- function(x_train,
                                          y_train,
                                          x_valid,
                                          family,
                                          base_learner,
                                          lambda_grid,
                                          l1_ratio,
                                          n_lambda,
                                          adaptive_gamma,
                                          adaptive_epsilon) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop(
      "Package 'glmnet' is required for `late_fusion = TRUE`. ",
      "Install it with: install.packages(\"glmnet\")",
      call. = FALSE
    )
  }
  if (identical(base_learner, "sparse_group_lasso")) {
    stop(
      "`late_fusion = TRUE` currently supports `base_learner = \"lasso\"`, ",
      "`\"elastic_net\"`, or `\"adaptive_lasso\"`; sparse-group late fusion ",
      "is not implemented.",
      call. = FALSE
    )
  }
  if (!base_learner %in% c("lasso", "elastic_net", "adaptive_lasso")) {
    stop(
      "`base_learner` must be one of: \"lasso\", \"elastic_net\", ",
      "\"adaptive_lasso\", \"sparse_group_lasso\".",
      call. = FALSE
    )
  }

  if (is.data.frame(x_train)) x_train <- as.matrix(x_train)
  if (!is.null(x_valid) && is.data.frame(x_valid)) x_valid <- as.matrix(x_valid)
  if (!is.matrix(x_train) || !is.numeric(x_train)) {
    stop("`x_train` must be a numeric matrix or data.frame.", call. = FALSE)
  }
  if (!is.null(x_valid) && (!is.matrix(x_valid) || !is.numeric(x_valid))) {
    stop("`x_valid` must be a numeric matrix or data.frame.", call. = FALSE)
  }

  lambda_grid <- .late_fusion_lambda_grid(
    lambda_grid = lambda_grid,
    x_train = x_train,
    y_train = y_train,
    family = family,
    base_learner = base_learner,
    l1_ratio = l1_ratio,
    n_lambda = n_lambda
  )
  task_type <- .family_to_task_type(family)
  y_model <- .late_fusion_model_outcome(y_train, family)
  penalty_factor <- .late_fusion_penalty_factor(
    x_train = x_train,
    y_model = y_model,
    family = family,
    base_learner = base_learner,
    adaptive_gamma = adaptive_gamma,
    adaptive_epsilon = adaptive_epsilon
  )

  best <- NULL
  best_score <- -Inf
  for (i in seq_len(nrow(lambda_grid))) {
    lambda_i <- lambda_grid[["lambda"]][[i]]
    alpha_i <- .late_fusion_alpha(base_learner, lambda_grid[i, , drop = FALSE])
    fit_args <- list(
      x = x_train,
      y = y_model,
      family = family,
      alpha = alpha_i,
      lambda = lambda_i
    )
    if (!is.null(penalty_factor)) {
      fit_args$penalty.factor <- penalty_factor
    }
    model <- do.call(glmnet::glmnet, fit_args)
    train_pred <- .late_fusion_predict_glmnet(
      model = model,
      newx = x_train,
      family = family,
      lambda = lambda_i,
      levels = if (identical(task_type, "multiclass")) levels(y_model) else NULL
    )
    score <- .late_fusion_candidate_score(
      y = y_train,
      predictions = train_pred,
      task_type = task_type
    )
    if (is.finite(score) && score > best_score) {
      best_score <- score
      best <- list(
        model = model,
        lambda = lambda_i,
        alpha = alpha_i,
        lambda_index = i,
        training_predictions = train_pred
      )
    }
  }

  if (is.null(best)) {
    stop("No finite late-fusion glmnet candidate score was obtained.",
         call. = FALSE)
  }

  best$valid_predictions <- if (is.null(x_valid)) {
    NULL
  } else {
    .late_fusion_predict_glmnet(
      model = best$model,
      newx = x_valid,
      family = family,
      lambda = best$lambda,
      levels = if (identical(task_type, "multiclass")) levels(y_model) else NULL
    )
  }
  best$model_type <- paste0("glmnet_", base_learner)
  best$family <- family
  best$task_type <- task_type
  best$score <- best_score
  best$lambda_grid <- lambda_grid
  best
}

.late_fusion_lambda_grid <- function(lambda_grid,
                                     x_train,
                                     y_train,
                                     family,
                                     base_learner,
                                     l1_ratio,
                                     n_lambda) {
  if (identical(lambda_grid, "auto")) {
    auto_l1_ratio <- l1_ratio
    if (is.null(auto_l1_ratio)) {
      auto_l1_ratio <- if (identical(base_learner, "elastic_net")) {
        c(0.5, 0.7, 0.9)
      } else {
        1.0
      }
    }
    lambda_grid <- auto_lambda_grid(
      x = x_train,
      y = y_train,
      family = family,
      n_lambda = as.integer(n_lambda),
      l1_ratio = auto_l1_ratio
    )
  }
  if (!is.data.frame(lambda_grid) || !"lambda" %in% names(lambda_grid)) {
    stop("Late Fusion requires `lambda_grid` to be a data.frame with a `lambda` column or \"auto\".",
         call. = FALSE)
  }
  lambda_grid
}

.late_fusion_model_outcome <- function(y_train, family) {
  if (identical(family, "gaussian") || identical(family, "poisson")) {
    return(unname(as.numeric(y_train)))
  }
  if (identical(family, "binomial")) {
    y_factor <- droplevels(factor(y_train))
    if (length(levels(y_factor)) != 2L) {
      stop("Binomial Late Fusion requires exactly two outcome classes.",
           call. = FALSE)
    }
    return(y_factor)
  }
  if (identical(family, "multinomial")) {
    y_factor <- droplevels(factor(y_train))
    if (length(levels(y_factor)) < 2L) {
      stop("Multinomial Late Fusion requires at least two outcome classes.",
           call. = FALSE)
    }
    return(y_factor)
  }
  stop(
    "`late_fusion = TRUE` supports family = 'gaussian', 'binomial', ",
    "'multinomial', or 'poisson'.",
    call. = FALSE
  )
}

.late_fusion_penalty_factor <- function(x_train,
                                        y_model,
                                        family,
                                        base_learner,
                                        adaptive_gamma,
                                        adaptive_epsilon) {
  if (!identical(base_learner, "adaptive_lasso")) {
    return(NULL)
  }
  init_fit <- glmnet::glmnet(
    x = x_train,
    y = y_model,
    family = family,
    alpha = 0,
    nlambda = 30L
  )
  init_lambda <- utils::tail(init_fit$lambda, n = 1L)
  init_scores <- .feature_abs_coefs(
    fit = init_fit,
    s = init_lambda,
    family = family
  )
  1.0 / ((init_scores + adaptive_epsilon) ^ adaptive_gamma)
}

.late_fusion_alpha <- function(base_learner, lambda_row) {
  if (!identical(base_learner, "elastic_net")) {
    return(1.0)
  }
  if ("alpha" %in% names(lambda_row)) {
    return(lambda_row[["alpha"]][[1L]])
  }
  1.0
}

.late_fusion_predict_glmnet <- function(model,
                                        newx,
                                        family,
                                        lambda,
                                        levels = NULL) {
  pred <- stats::predict(
    model,
    newx = newx,
    s = lambda,
    type = if (identical(family, "multinomial")) "response" else "response"
  )
  if (!identical(family, "multinomial")) {
    return(unname(as.numeric(pred)))
  }

  if (length(dim(pred)) == 3L) {
    mat <- pred[, , 1L, drop = FALSE]
    dim(mat) <- dim(mat)[1:2]
    dimnames(mat) <- list(rownames(newx), dimnames(pred)[[2L]])
  } else {
    mat <- as.matrix(pred)
    rownames(mat) <- rownames(newx)
  }
  if (!is.null(levels)) {
    mat <- mat[, levels, drop = FALSE]
  }
  mat
}

.late_fusion_candidate_score <- function(y, predictions, task_type) {
  if (identical(task_type, "binary")) {
    return(.r_auc(.coerce_binary_stack_outcome(y), as.numeric(predictions)))
  }
  if (identical(task_type, "multiclass")) {
    return(-.multiclass_log_loss(y, predictions))
  }
  .r_squared(as.numeric(y), as.numeric(predictions))
}

.stack_per_view_predictions <- function(per_view_models,
                                        omic_names,
                                        y_train,
                                        y_valid,
                                        valid_ids,
                                        task_type,
                                        n_iter_stacking,
                                        random_state) {
  if (identical(task_type, "multiclass")) {
    train_preds <- vector("list", length(omic_names))
    names(train_preds) <- omic_names
    valid_preds <- if (is.null(valid_ids)) {
      NULL
    } else {
      out <- vector("list", length(omic_names))
      names(out) <- omic_names
      out
    }
  } else {
    train_preds <- matrix(
      NA_real_,
      nrow = length(y_train),
      ncol = length(omic_names),
      dimnames = list(names(y_train), omic_names)
    )
    valid_preds <- if (is.null(valid_ids)) {
      NULL
    } else {
      matrix(
        NA_real_,
        nrow = length(valid_ids),
        ncol = length(omic_names),
        dimnames = list(valid_ids, omic_names)
      )
    }
  }

  for (omic in omic_names) {
    omic_result <- per_view_models[[omic]]
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
    predictions = train_preds,
    y = unname(y_train),
    task_type = task_type,
    n_iter = n_iter_stacking,
    random_state = random_state
  )

  valid_predictions <- if (is.null(valid_preds)) {
    NULL
  } else if (identical(task_type, "multiclass")) {
    .apply_multiclass_stack_weights(valid_preds, stacked$weights$Associated_weight)
  } else {
    w <- stacked$weights$Associated_weight
    w_mat <- matrix(w, nrow = nrow(valid_preds), ncol = length(w), byrow = TRUE)
    is_obs <- !is.na(valid_preds)
    denom <- rowSums(is_obs * w_mat)
    num <- rowSums(ifelse(is_obs, valid_preds * w_mat, 0))
    ifelse(denom > 0, num / denom, NA_real_)
  }

  out <- list(
    weights = stacked$weights,
    train_predictions = stacked$predictions,
    valid_predictions = valid_predictions,
    score = stacked$score,
    task_type = task_type
  )
  if (identical(task_type, "multiclass")) {
    out$levels <- stacked$levels
    out$log_loss <- stacked$log_loss
    out$train_metrics <- .classification_metrics(
      truth = factor(y_train, levels = stacked$levels),
      predicted = factor(stacked$predictions$predicted_class,
                         levels = stacked$levels)
    )
    if (!is.null(y_valid) && !is.null(valid_predictions)) {
      out$valid_metrics <- .classification_metrics(
        truth = factor(y_valid, levels = stacked$levels),
        predicted = factor(valid_predictions$predicted_class,
                           levels = stacked$levels)
      )
    }
  }
  out
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

.resolve_early_fusion_lambda_grid <- function(lambda_grid) {
  if (is.data.frame(lambda_grid) || identical(lambda_grid, "auto")) {
    return(lambda_grid)
  }

  stop(
    "`early_fusion = TRUE` requires a shared `lambda_grid` (`data.frame` ",
    "or \"auto\"); named per-omic lambda lists are not supported for the ",
    "single concatenated Early Fusion input space.",
    call. = FALSE
  )
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

.validate_prefixed_omic_names <- function(omic_names) {
  bad <- omic_names[grepl("__", omic_names, fixed = TRUE)]
  if (length(bad) > 0L) {
    stop(
      "Omic View names must not contain `__` when prefixed multi-omic ",
      "feature names are required: ",
      paste(bad, collapse = ", "),
      call. = FALSE
    )
  }
  invisible(NULL)
}

.prefix_omic_matrix <- function(x, omic) {
  out <- if (is.data.frame(x)) as.matrix(x) else x
  colnames(out) <- .prefixed_omic_feature_names(omic, colnames(out))
  if (anyDuplicated(colnames(out))) {
    stop(
      "Prefixed multi-omic feature names must be unique within each Omic View.",
      call. = FALSE
    )
  }
  out
}

.fit_multiomic_stabl_final_layer <- function(selected_train,
                                             selected_valid,
                                             selected_features,
                                             y_train,
                                             y_valid,
                                             task_type,
                                             levels) {
  final_train <- .multiomic_stabl_bind_selected(selected_train)
  final_valid <- if (is.null(selected_valid)) {
    NULL
  } else {
    .multiomic_stabl_bind_selected(selected_valid)
  }
  feature_map <- .multiomic_stabl_feature_map(selected_features)

  final_refit <- .fit_stabl_final_model(
    x_train_sel = final_train,
    y_train = y_train,
    task_type = task_type,
    levels = levels
  )

  train_predictions <- .multiomic_stabl_predict(
    final_refit = final_refit,
    x_selected = final_train
  )
  valid_predictions <- if (is.null(final_valid)) {
    NULL
  } else {
    .multiomic_stabl_predict(
      final_refit = final_refit,
      x_selected = final_valid
    )
  }

  train_metrics <- .multiomic_stabl_metrics(
    y = y_train,
    predictions = train_predictions,
    final_refit = final_refit,
    x_selected = final_train
  )
  valid_metrics <- if (is.null(y_valid) || is.null(final_valid)) {
    NULL
  } else {
    .multiomic_stabl_metrics(
      y = y_valid,
      predictions = valid_predictions,
      final_refit = final_refit,
      x_selected = final_valid
    )
  }

  list(
    selected_features = selected_features,
    final_features = colnames(final_train),
    feature_map = feature_map,
    selected_train = final_train,
    selected_valid = final_valid,
    refit = final_refit,
    train_predictions = train_predictions,
    valid_predictions = valid_predictions,
    train_metrics = train_metrics,
    valid_metrics = valid_metrics
  )
}

.multiomic_stabl_bind_selected <- function(selected_list) {
  omic_names <- names(selected_list)
  n_rows <- if (length(selected_list) == 0L) {
    0L
  } else {
    nrow(selected_list[[1L]])
  }
  row_ids <- if (length(selected_list) == 0L) {
    NULL
  } else {
    rownames(selected_list[[1L]])
  }

  mats <- list()
  for (omic in omic_names) {
    mat <- selected_list[[omic]]
    if (ncol(mat) == 0L) next
    final_names <- .multiomic_stabl_feature_names(omic, colnames(mat))
    mat <- mat[, seq_len(ncol(mat)), drop = FALSE]
    colnames(mat) <- final_names
    mats[[omic]] <- mat
  }

  if (length(mats) == 0L) {
    return(matrix(
      numeric(0L),
      nrow = n_rows,
      ncol = 0L,
      dimnames = list(row_ids, character(0L))
    ))
  }

  out <- do.call(cbind, mats)
  if (anyDuplicated(colnames(out))) {
    stop(
      "Multi-Omic STABL final-layer feature names must be unique after ",
      "Omic View prefixing.",
      call. = FALSE
    )
  }
  rownames(out) <- row_ids
  out
}

.multiomic_stabl_feature_names <- function(omic, features) {
  .prefixed_omic_feature_names(omic, features)
}

.prefixed_omic_feature_names <- function(omic, features) {
  paste(omic, features, sep = "__")
}

.multiomic_stabl_feature_map <- function(selected_features) {
  rows <- lapply(names(selected_features), function(omic) {
    features <- selected_features[[omic]]
    if (length(features) == 0L) {
      return(NULL)
    }
    data.frame(
      final_feature = .multiomic_stabl_feature_names(omic, features),
      omic = omic,
      original_feature = features,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  if (length(rows) == 0L) {
    return(data.frame(
      final_feature = character(),
      omic = character(),
      original_feature = character(),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.multiomic_stabl_predict <- function(final_refit, x_selected) {
  task_type <- final_refit$task_type
  if (identical(task_type, "multiclass")) {
    probs <- .predict_stabl_final_model(
      final_refit,
      x_selected,
      type = "response"
    )
    return(.multiomic_stabl_prediction_frame(probs))
  }
  .predict_stabl_final_model(final_refit, x_selected, type = "response")
}

.multiomic_stabl_prediction_frame <- function(probabilities) {
  probs <- as.data.frame(probabilities, check.names = FALSE)
  names(probs) <- paste0("prob_", names(probs))
  classes <- sub("^prob_", "", names(probs))
  probs$predicted_class <- classes[max.col(as.matrix(probabilities),
                                           ties.method = "first")]
  probs
}

.multiomic_stabl_metrics <- function(y,
                                     predictions,
                                     final_refit,
                                     x_selected) {
  task_type <- final_refit$task_type

  if (identical(task_type, "regression")) {
    return(list(r_squared = .r_squared(as.numeric(y), as.numeric(predictions))))
  }

  if (identical(task_type, "binary")) {
    predicted_class <- .predict_stabl_final_model(
      final_refit,
      x_selected,
      type = "class"
    )
    metrics <- .classification_metrics(
      truth = factor(y, levels = final_refit$levels),
      predicted = factor(predicted_class, levels = final_refit$levels)
    )
    metrics$auc <- .r_auc(
      as.integer(factor(y, levels = final_refit$levels) == final_refit$levels[[2L]]),
      as.numeric(predictions)
    )
    return(metrics)
  }

  if (identical(task_type, "multiclass")) {
    prob_cols <- paste0("prob_", final_refit$levels)
    probs <- as.matrix(predictions[, prob_cols, drop = FALSE])
    colnames(probs) <- final_refit$levels
    metrics <- .classification_metrics(
      truth = factor(y, levels = final_refit$levels),
      predicted = factor(predictions$predicted_class, levels = final_refit$levels)
    )
    metrics$log_loss <- .multiclass_log_loss(
      factor(y, levels = final_refit$levels),
      probs
    )
    return(metrics)
  }

  if (identical(task_type, "poisson")) {
    return(list(
      mean_poisson_deviance = .multiomic_stabl_poisson_deviance(
        y = as.numeric(y),
        mu = as.numeric(predictions)
      )
    ))
  }

  NULL
}

.multiomic_stabl_poisson_deviance <- function(y, mu) {
  eps <- .Machine$double.eps
  mu <- pmax(as.numeric(mu), eps)
  y <- as.numeric(y)
  terms <- ifelse(y == 0, 0, y * log(pmax(y, eps) / mu))
  mean(2 * (terms - (y - mu)))
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
