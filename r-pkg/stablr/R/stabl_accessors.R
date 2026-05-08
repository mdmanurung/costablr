#' Get the Feature Selection Mask from a Fitted STABL Object
#'
#' Returns a named logical vector that is `TRUE` for every feature whose
#' maximum stability score exceeds the effective threshold.  This is the
#' primary accessor for downstream use of a fitted STABL model: index your
#' data matrix with the returned mask, or pass the object to
#' [get_feature_names_out()] to obtain the names directly.
#'
#' @details
#' **Threshold resolution order:**
#' 1. `new_hard_threshold` (if supplied to this call).
#' 2. `object$hard_threshold` (if a hard threshold was given to [stabl_fit()]).
#' 3. `object$fdr_min_threshold_` (the FDP+-optimal threshold computed from
#'    artificial features during fitting).
#'
#' An error is raised when none of these is available — which can only happen
#' if `stabl_fit()` was called with both `artificial_type = NULL` and no
#' `hard_threshold`.
#'
#' **Explore fallback:** When `explore = TRUE` was set during fitting and no
#' feature's score exceeds the threshold, the function returns the top
#' `n_explore` features instead of an all-`FALSE` vector.  This is useful in
#' exploratory analyses where you want at least some candidates even when the
#' signal is weak.
#'
#' @param object A fitted `"stabl_fit"` object returned by [stabl_fit()].
#' @param new_hard_threshold Numeric in `(0, 1]` or `NULL`.  When supplied,
#'   overrides the threshold stored in `object` for this call only.
#'
#' @return Named logical vector of length `object$n_features_in_`.  Names are
#'   the original feature names from the training matrix.
#'
#' @seealso [get_feature_names_out()] to get names directly,
#'   [get_importances()] to inspect raw stability scores.
#' @export
get_support <- function(object, new_hard_threshold = NULL) {
  UseMethod("get_support")
}

#' @export
get_support.stabl_fit <- function(object, new_hard_threshold = NULL) {
  .check_fitted_stabl(object)

  threshold <- if (!is.null(new_hard_threshold)) {
    new_hard_threshold
  } else if (!is.null(object$hard_threshold)) {
    object$hard_threshold
  } else {
    object$fdr_min_threshold_
  }

  if (is.null(threshold)) {
    stop(
      "No threshold available: fit with `artificial_type` or supply ",
      "`hard_threshold`.",
      call. = FALSE
    )
  }

  max_scores <- get_importances(object)
  mask       <- max_scores > threshold

  # explore fallback: top n_explore features if nothing passes threshold
  if (!any(mask) && isTRUE(object$explore)) {
    n_exp  <- min(object$n_explore, length(max_scores))
    cutoff <- sort(max_scores, decreasing = TRUE)[n_exp] - 0.01
    mask   <- max_scores > cutoff
  }

  mask
}

#' Get the Full Stability Score Matrix from a Fitted STABL Object
#'
#' Returns the raw stability-score matrix accumulated over all bootstrap
#' iterations.  Inspecting this matrix is useful for diagnostics: you can
#' check how stable features are across the regularisation path, identify
#' features that are consistently selected at many lambda values (robustness),
#' and spot features that peak only at one extreme of the path (fragility).
#'
#' The stability score for feature \eqn{j} at regularisation strength
#' \eqn{\lambda_k} is defined as the fraction of bootstrap subsamples in
#' which feature \eqn{j} received a non-zero coefficient when the model was
#' fitted at \eqn{\lambda_k}.  Values lie in \eqn{[0, 1]}.
#'
#' @param object A fitted `"stabl_fit"` object returned by [stabl_fit()].
#'
#' @return Numeric matrix with one row per original feature and one column per
#'   lambda in the fitted grid.  Row names are the feature names from the
#'   training matrix; column names are not set (use
#'   `object$fitted_lambda_grid` to map column indices to lambda values).
#'
#' @seealso [get_importances()] for the per-feature maximum score (scalar
#'   summary), [get_support()] for the binary selection mask.
#' @export
get_stabl_scores <- function(object) {
  UseMethod("get_stabl_scores")
}

#' @export
get_stabl_scores.stabl_fit <- function(object) {
  .check_fitted_stabl(object)
  object$stabl_scores_
}

#' Get the Names of Selected Features from a Fitted STABL Object
#'
#' Convenience wrapper around [get_support()] that returns only the names of
#' the features that pass the stability threshold, ready for use as column
#' selectors in downstream modelling (e.g.
#' `x[, get_feature_names_out(fit)]`).
#'
#' @param object A fitted `"stabl_fit"` object returned by [stabl_fit()].
#' @param new_hard_threshold Numeric in `(0, 1]` or `NULL`.  Forwarded to
#'   [get_support()]; see that function for the full threshold resolution
#'   order.
#'
#' @return Character vector of selected feature names.  An empty character
#'   vector is returned when no feature passes the threshold (and
#'   `explore = FALSE` was used during fitting).
#'
#' @seealso [get_support()] for the binary mask, [get_importances()] for
#'   ranked scores.
#' @export
get_feature_names_out <- function(object, new_hard_threshold = NULL) {
  UseMethod("get_feature_names_out")
}

#' @export
get_feature_names_out.stabl_fit <- function(object, new_hard_threshold = NULL) {
  mask <- get_support(object, new_hard_threshold = new_hard_threshold)
  object$feature_names[mask]
}

#' Get Per-Feature Importance Scores (Maximum Stability Score)
#'
#' Returns a scalar summary of how stably each feature is selected across the
#' entire regularisation path.  The importance of feature \eqn{j} is defined
#' as \eqn{\max_{k} q_{jk}}, i.e. the highest selection frequency it achieved
#' at any lambda.  This is the score compared against the stability threshold
#' in [get_support()].
#'
#' Because the maximum is taken across lambdas, the importance measure is
#' lenient: a feature qualifies even if it is stable only at one particular
#' penalty strength.  For a more conservative view, use [get_stabl_scores()]
#' and inspect the full path.
#'
#' @param object A fitted `"stabl_fit"` object returned by [stabl_fit()].
#'
#' @return Named numeric vector of length `object$n_features_in_`, with
#'   values in \eqn{[0, 1]}.  Higher values indicate more stable features.
#'   Names are the original feature names from the training matrix.
#'
#' @seealso [get_support()] to convert importances to a binary selection mask,
#'   [get_stabl_scores()] for the full path matrix.
#' @export
get_importances <- function(object) {
  UseMethod("get_importances")
}

#' @export
get_importances.stabl_fit <- function(object) {
  .check_fitted_stabl(object)
  scores        <- apply(object$stabl_scores_, 1L, max)
  names(scores) <- object$feature_names
  scores
}

#' @export
print.stabl_fit <- function(x, ...) {
  cat("<stabl_fit>\n")
  cat("  Features in:     ", x$n_features_in_, "\n")
  tryCatch(
    {
      mask <- get_support(x)
      cat("  Features selected:", sum(mask), "\n")
    },
    error = function(e) {
      cat("  Features selected: [threshold not yet resolved]\n")
    }
  )
  if (!is.null(x$min_fdr_)) {
    cat("  Min FDP+:        ", round(x$min_fdr_, 4L), "\n")
    cat("  FDP+ threshold:  ", round(x$fdr_min_threshold_, 4L), "\n")
  }
  if (!is.null(x$hard_threshold)) {
    cat("  Hard threshold:  ", x$hard_threshold, "\n")
  }
  cat("  Artificial:      ", if (is.null(x$artificial_type)) "none"
                             else x$artificial_type, "\n")
  invisible(x)
}

#' @export
print.stabl_multiomic_fit <- function(x, ...) {
  omic_names <- names(x$fits)
  cat("<stabl_multiomic_fit>\n")
  cat("  Omics:           ", length(omic_names), " (", paste(omic_names, collapse = ", "), ")\n", sep = "")
  cat("  Per-omic selected features:\n")
  for (omic in omic_names) {
    n_sel <- length(x$selected_features[[omic]])
    cat("    ", omic, ": ", n_sel, "\n", sep = "")
  }
  has_valid <- !is.null(x$selected_valid)
  cat("  Validation data: ", if (has_valid) "yes" else "no", "\n")
  cat("  Early fusion:    ", if (!is.null(x$early_fusion)) {
    paste0("yes (", length(x$early_fusion$selected_features), " features selected)")
  } else "no", "\n")
  cat("  Late fusion:     ", if (!is.null(x$late_fusion)) {
    paste0("yes (score = ", round(x$late_fusion$score, 4L), ")")
  } else "no", "\n")
  if (!is.null(x$cooperative_fusion)) {
    cf <- x$cooperative_fusion
    n_cf_sel <- sum(vapply(cf$selected_features, length, integer(1L)))
    cat("  Cooperative fusion:\n")
    cat("    selection:     ", cf$selection, "\n", sep = "")
    cat("    rho (chosen):  ", cf$rho, "\n", sep = "")
    cat("    selector:      ", cf$selector, "\n", sep = "")
    cat("    type.measure:  ", cf$type_measure, "\n", sep = "")
    cat("    score:         ", round(cf$score, 4L), "\n", sep = "")
    cat("    selected feats: ", n_cf_sel, " (across views)\n", sep = "")
  }
  invisible(x)
}

#' @export
print.stabl_multiomic_cv <- function(x, ...) {
  cat("<stabl_multiomic_cv>\n")
  cat("  Folds:           ", length(x$folds), "\n")
  if (!is.null(x$diagnostics) && nrow(x$diagnostics) > 0L) {
    omic_names <- unique(x$diagnostics$omic)
    cat("  Omics:           ", length(omic_names), " (",
        paste(omic_names, collapse = ", "), ")\n", sep = "")
    cat("  Mean selected features per omic (across folds):\n")
    for (omic in omic_names) {
      sub <- x$diagnostics[x$diagnostics$omic == omic, , drop = FALSE]
      cat("    ", omic, ": ", round(mean(sub$n_selected), 1L), "\n", sep = "")
    }
  }
  invisible(x)
}

# ---- Internal helpers --------------------------------------------------------
.check_fitted_stabl <- function(object) {
  if (is.null(object$stabl_scores_)) {
    stop(
      "Object has no `stabl_scores_`: ensure `stabl_fit()` completed.",
      call. = FALSE
    )
  }
  invisible(NULL)
}

# Null-coalescing helper (package-internal)
`%||%` <- function(a, b) if (is.null(a)) b else a
