#' Get the Feature Selection Mask from a Fitted STABL Object
#'
#' Returns a logical vector indicating which features are selected by STABL.
#' Selection is determined by the FDP+-optimal threshold (when artificial
#' features were used during fitting) or by `hard_threshold`, in that priority
#' order.  When `explore = TRUE` was set during fitting and no feature passes
#' the threshold, the top `n_explore` features are returned as a fallback.
#'
#' @param object A fitted `"stabl_fit"` object from [stabl_fit()].
#' @param new_hard_threshold Numeric in `(0, 1]` or `NULL`.  When supplied,
#'   overrides the threshold stored in `object`.
#'
#' @return Named logical vector of length `object$n_features_in_`.
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

#' Get Stability Scores from a Fitted STABL Object
#'
#' @param object A fitted `"stabl_fit"` object.
#'
#' @return Numeric matrix (features \eqn{\times} lambdas) of stability scores,
#'   with feature names as row names.
#' @export
get_stabl_scores <- function(object) {
  UseMethod("get_stabl_scores")
}

#' @export
get_stabl_scores.stabl_fit <- function(object) {
  .check_fitted_stabl(object)
  object$stabl_scores_
}

#' Get Names of Selected Features
#'
#' @param object A fitted `"stabl_fit"` object.
#' @param new_hard_threshold Numeric or `NULL`; see [get_support()].
#'
#' @return Character vector of selected feature names.
#' @export
get_feature_names_out <- function(object, new_hard_threshold = NULL) {
  UseMethod("get_feature_names_out")
}

#' @export
get_feature_names_out.stabl_fit <- function(object, new_hard_threshold = NULL) {
  mask <- get_support(object, new_hard_threshold = new_hard_threshold)
  object$feature_names[mask]
}

#' Get Feature Importances (Max Stability Scores)
#'
#' Returns the per-feature importance score, defined as the maximum stability
#' score across all lambda values.  Mirrors `Stabl.get_importances()`.
#'
#' @param object A fitted `"stabl_fit"` object.
#'
#' @return Named numeric vector of length `object$n_features_in_`.
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
