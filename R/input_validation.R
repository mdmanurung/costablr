#' costablr: Sparse and Reliable Biomarker Discovery in R
#'
#' `costablr` is an R implementation of STABL for sparse, stable biomarker
#' selection in high-dimensional clinical and omic datasets.  The package
#' provides a core bootstrap stability-selection engine, FDP+ threshold
#' calibration with artificial features, glmnet-family learner adapters, and
#' multi-omic workflows for per-omic, early-fusion, late-fusion, and
#' cooperative-fusion analyses.
#'
#' @section Main workflows:
#' \itemize{
#'   \item [stabl_fit()] fits the core single-matrix STABL selector.
#'   \item [stabl_multiomic_train_validate()] runs train/validation multi-omic
#'     workflows with optional early, late, and cooperative fusion.
#'   \item [stabl_multiomic_cv()] runs outer cross-validation for named
#'     multi-omic inputs, preserving optional group structure.
#' }
#'
#' @section Learners and outcomes:
#' The core selector supports lasso, elastic net, adaptive lasso, and optional
#' sparse group lasso backends.  Supported `glmnet` families include Gaussian,
#' binomial, multinomial, and Cox where the selected backend supports them.
#'
#' @section Outputs:
#' Fitted objects expose stable S3 accessors for support masks, selected feature
#' names, stability scores, importances, cooperative-fusion features, and
#' cooperative diagnostics.  Plotting and export helpers provide stability
#' paths, FDP+ curves, ROC/PRC plots, selected-feature visualizations, and CSV
#' output.
#'
#' @seealso [stabl_fit()], [stabl_multiomic_train_validate()],
#'   [get_support()], [get_importances()], [plot_stabl_path()]
#'
#' @useDynLib costablr, .registration = TRUE
#' @importFrom Rcpp evalCpp
#' @keywords internal
"_PACKAGE"

utils::globalVariables(c(
  "FDR", "feature", "fpr", "lambda_idx", "outcome", "precision",
  "recall", "score", "threshold", "tpr", "value"
))

#' Validate Sample Alignment Across Inputs
#'
#' Checks that the predictor matrix, outcome vector, and optional group vector
#' all refer to exactly the same set of samples (by name), and that they can
#' be safely aligned before modelling.
#'
#' STABL enforces strict name-based alignment (rather than positional
#' alignment) to mirror the pandas index-alignment semantics of the Python
#' reference implementation and to prevent silent sample-order bugs that could
#' corrupt stability scores or introduce outcome leakage.
#'
#' This function is called automatically by [stabl_fit()] and
#' [stabl_multiomic_train_validate()]; you only need to call it directly when
#' building a custom pre-processing step that receives `x` and `y` separately.
#'
#' @param x A `data.frame` or numeric matrix with non-empty, non-`NA` row
#'   names used as sample IDs.
#' @param y A named vector (or matrix-like object such as `survival::Surv`
#'   with row names) whose names identify the samples.  The set of names in
#'   `y` must be identical to the set of row names in `x`; order does not
#'   need to match.
#' @param groups Optional named vector where names are sample IDs and values
#'   are group memberships.  When supplied, its name set must also match
#'   `rownames(x)`.  Pass `NULL` to skip group validation.
#'
#' @return Invisibly returns `TRUE` when all checks pass.  Raises an
#'   informative error as soon as the first violation is found.
#'
#' @seealso [validate_multiomic_inputs()] for multi-omic list inputs.
#' @export
validate_sample_alignment <- function(x, y, groups = NULL) {
  if (!(is.data.frame(x) || is.matrix(x))) {
    stop("`x` must be a data.frame or matrix.", call. = FALSE)
  }

  sample_ids <- rownames(x)
  if (is.null(sample_ids) || anyNA(sample_ids) || any(sample_ids == "")) {
    stop("`x` must have non-empty row names used as sample ids.", call. = FALSE)
  }
  if (anyDuplicated(sample_ids)) {
    stop("`x` row names must be unique sample ids.", call. = FALSE)
  }

  y_ids <- .outcome_sample_ids(y)
  if (is.null(y_ids)) {
    stop(
      "`y` must be a named vector or matrix-like outcome with row names as sample ids.",
      call. = FALSE
    )
  }
  if (anyDuplicated(y_ids)) {
    stop("`y` sample ids must be unique.", call. = FALSE)
  }

  if (!setequal(sample_ids, y_ids)) {
    stop("Sample mismatch between `x` row names and `y` names.", call. = FALSE)
  }

  y_ordered <- .subset_outcome_by_ids(y, sample_ids)
  if (anyNA(y_ordered)) {
    stop("`y` cannot contain missing sample mappings after alignment.", call. = FALSE)
  }

  if (!is.null(groups)) {
    if (is.null(names(groups))) {
      stop("`groups` must be a named vector where names are sample ids.", call. = FALSE)
    }
    if (anyDuplicated(names(groups))) {
      stop("`groups` sample ids must be unique.", call. = FALSE)
    }
    if (!setequal(sample_ids, names(groups))) {
      stop("Sample mismatch between `x` row names and `groups` names.", call. = FALSE)
    }
    groups_ordered <- groups[sample_ids]
    if (anyNA(groups_ordered)) {
      stop("`groups` cannot contain missing sample mappings after alignment.", call. = FALSE)
    }
  }

  invisible(TRUE)
}

# Resolve sample identifiers from supported outcome types.
.outcome_sample_ids <- function(y) {
  if (!is.null(names(y))) {
    return(names(y))
  }

  if (is.matrix(y) || is.data.frame(y) || inherits(y, "Surv")) {
    return(rownames(y))
  }

  NULL
}

# Subset supported outcome types by sample id while preserving their shape.
.subset_outcome_by_ids <- function(y, sample_ids) {
  y_ids <- .outcome_sample_ids(y)
  if (anyDuplicated(sample_ids)) {
    stop("`sample_ids` must be unique.", call. = FALSE)
  }
  if (anyDuplicated(y_ids)) {
    stop("`y` sample ids must be unique.", call. = FALSE)
  }
  idx <- match(sample_ids, y_ids)

  if (anyNA(idx)) {
    stop("`y` cannot contain missing sample mappings after alignment.", call. = FALSE)
  }

  if (!is.null(names(y))) {
    return(y[sample_ids])
  }

  if (is.matrix(y) || is.data.frame(y) || inherits(y, "Surv")) {
    return(y[idx, , drop = FALSE])
  }

  y[idx]
}

#' Validate Multi-Omic Input Contract
#'
#' Enforces the canonical `costablr` input contract for multi-omic analyses: a
#' named list of omic tables with identical sample IDs and row order across
#' all views, plus strict alignment with the outcome and optional group
#' vectors.
#'
#' Multi-omic analyses require that all omic matrices have exactly the same
#' rows in exactly the same order so that row-wise operations (bootstrap
#' sampling, cooperative learning) are coherent.  This function catches
#' mismatches early and provides informative error messages naming the
#' offending omic layer, which is much easier to diagnose than silent
#' misalignment detected later in the modelling pipeline.
#'
#' @param x_list Named list of `data.frame` or numeric matrix omic tables.
#'   Each table must have non-empty row names identifying samples.  All tables
#'   must have the same set of row names **in the same order**.
#' @param y Named outcome vector aligned to the samples in `x_list`.  The
#'   name set must match the row names of every omic table.
#' @param groups Optional named group vector.  When supplied its names must
#'   match the sample IDs in `x_list`.  Pass `NULL` to skip group validation.
#'
#' @return Invisibly returns `TRUE` when all checks pass.  Raises an
#'   informative error as soon as the first violation is found.
#'
#' @seealso [validate_sample_alignment()] for single-omic inputs,
#'   [stabl_multiomic_train_validate()] which calls this automatically.
#' @export
validate_multiomic_inputs <- function(x_list, y, groups = NULL) {
  if (!is.list(x_list) || length(x_list) == 0L) {
    stop("`x_list` must be a non-empty named list.", call. = FALSE)
  }

  if (is.null(names(x_list)) || anyNA(names(x_list)) || any(names(x_list) == "")) {
    stop("`x_list` must have non-empty names for each omic table.", call. = FALSE)
  }

  for (name in names(x_list)) {
    x <- x_list[[name]]
    if (!(is.data.frame(x) || is.matrix(x))) {
      stop(sprintf("Omic '%s' must be a data.frame or matrix.", name), call. = FALSE)
    }
    validate_sample_alignment(x = x, y = y, groups = groups)
  }

  base_ids <- rownames(x_list[[1]])
  for (name in names(x_list)[-1]) {
    if (!identical(base_ids, rownames(x_list[[name]]))) {
      stop(
        sprintf("All omic tables must have identical sample order; mismatch at omic '%s'.", name),
        call. = FALSE
      )
    }
  }

  invisible(TRUE)
}

.supported_cooperation_type_measures <- function(family) {
  switch(
    family,
    gaussian = c("default", "mse", "deviance", "mae"),
    binomial = c("default", "mse", "deviance", "class", "auc", "mae"),
    poisson = c("default", "mse", "deviance", "mae"),
    cox = c("default", "deviance", "C"),
    character(0)
  )
}

# Internal indirection so tests can mock the optional-dep check via
# `testthat::local_mocked_bindings(.has_multiview = function() FALSE)`.
.has_multiview <- function() {
  requireNamespace("multiview", quietly = TRUE)
}

.resolve_cooperation_type_measure <- function(family, type_measure) {
  allowed <- .supported_cooperation_type_measures(family)

  if (!(type_measure %in% allowed)) {
    stop(
      sprintf(
        "`cooperation_type_measure` must be one of %s for family '%s'.",
        paste(sprintf("'%s'", allowed), collapse = ", "),
        family
      ),
      call. = FALSE
    )
  }

  if (!identical(type_measure, "default")) {
    return(type_measure)
  }

  switch(
    family,
    gaussian = "mse",
    binomial = "deviance",
    poisson = "deviance",
    cox = "deviance"
  )
}

.normalize_cooperative_multiomic_args <- function(x_list,
                                                  family,
                                                  rho = NULL,
                                                  cooperative_selection = c("cv", "validation"),
                                                  cooperation_selector = c("lambda.min", "lambda.1se"),
                                                  cooperation_type_measure = "default",
                                                  cooperation_nfolds = 5L,
                                                  x_valid_list = NULL,
                                                  y_valid = NULL) {
  cooperative_selection <- match.arg(cooperative_selection)
  cooperation_selector <- match.arg(cooperation_selector)

  if (!.has_multiview()) {
    stop(
      "`cooperative_fusion = TRUE` requires the optional 'multiview' package to be installed.",
      call. = FALSE
    )
  }

  if (length(x_list) < 2L) {
    stop(
      "`cooperative_fusion = TRUE` requires at least two omic views.",
      call. = FALSE
    )
  }

  if (!(family %in% c("gaussian", "binomial", "poisson", "cox"))) {
    stop(
      "`cooperative_fusion = TRUE` currently supports family = 'gaussian', 'binomial', 'poisson', or 'cox'.",
      call. = FALSE
    )
  }

  if (is.null(rho)) {
    rho <- 0
  }

  if (!is.numeric(rho) || length(rho) == 0L || anyNA(rho) || any(!is.finite(rho))) {
    stop("`rho` must be a non-empty numeric scalar or vector.", call. = FALSE)
  }

  if (any(rho < 0)) {
    stop("`rho` must contain only non-negative values.", call. = FALSE)
  }

  if (length(cooperation_nfolds) != 1L || is.na(cooperation_nfolds)) {
    stop("`cooperation_nfolds` must be a single non-missing integer.", call. = FALSE)
  }

  cooperation_nfolds <- as.integer(cooperation_nfolds)
  if (cooperation_nfolds < 3L) {
    stop("`cooperation_nfolds` must be greater than or equal to 3.", call. = FALSE)
  }

  if (identical(cooperative_selection, "validation")) {
    if (identical(family, "cox")) {
      stop(
        "`cooperation_selection = 'validation'` is not supported for family = 'cox'; use `cooperation_selection = 'cv'`.",
        call. = FALSE
      )
    }

    if (is.null(x_valid_list) || is.null(y_valid)) {
      stop(
        "`cooperation_selection = 'validation'` requires both `x_valid_list` and `y_valid`.",
        call. = FALSE
      )
    }

    if (identical(cooperation_selector, "lambda.1se")) {
      stop(
        "`cooperation_selector = 'lambda.1se'` is only available when `cooperation_selection = 'cv'`.",
        call. = FALSE
      )
    }
  }

  type_measure <- .resolve_cooperation_type_measure(
    family = family,
    type_measure = cooperation_type_measure
  )

  list(
    rho = unique(as.numeric(rho)),
    cooperative_selection = cooperative_selection,
    cooperation_selector = cooperation_selector,
    cooperation_type_measure = type_measure,
    cooperation_nfolds = cooperation_nfolds
  )
}
