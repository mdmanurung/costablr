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
