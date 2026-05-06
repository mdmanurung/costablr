#' stablr Package
#'
#' Initial package scaffolding for the R port of STABL.
#'
#' @keywords internal
"_PACKAGE"

#' Validate Sample Alignment Across Inputs
#'
#' Enforces strict sample alignment between predictor table, outcome vector,
#' and optional group vector.
#'
#' @param x A `data.frame` or matrix with row names representing sample ids.
#' @param y A named vector with sample ids as names.
#' @param groups Optional named vector of group ids aligned on sample ids.
#'
#' @return Invisibly returns `TRUE` when validation succeeds.
#' @export
validate_sample_alignment <- function(x, y, groups = NULL) {
  if (!(is.data.frame(x) || is.matrix(x))) {
    stop("`x` must be a data.frame or matrix.", call. = FALSE)
  }

  sample_ids <- rownames(x)
  if (is.null(sample_ids) || anyNA(sample_ids) || any(sample_ids == "")) {
    stop("`x` must have non-empty row names used as sample ids.", call. = FALSE)
  }

  y_ids <- .outcome_sample_ids(y)
  if (is.null(y_ids)) {
    stop(
      "`y` must be a named vector or matrix-like outcome with row names as sample ids.",
      call. = FALSE
    )
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
#' Enforces the canonical `stablr` input contract: a named list of omic tables
#' with identical sample ids and strict alignment with outcome and optional
#' groups vectors.
#'
#' @param x_list Named list of `data.frame`/matrix omic tables.
#' @param y Named outcome vector.
#' @param groups Optional named group vector.
#'
#' @return Invisibly returns `TRUE` when validation succeeds.
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

  if (!requireNamespace("multiview", quietly = TRUE)) {
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
