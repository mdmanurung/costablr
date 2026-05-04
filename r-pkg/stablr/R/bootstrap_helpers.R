#' Classic Bootstrap Sampler Indices
#'
#' Draws sample indices for STABL bootstrap resampling with optional class
#' weighting behavior.
#'
#' @param y Outcome vector.
#' @param n_subsamples Number of sampled indices to draw.
#' @param replace Whether sampling is done with replacement.
#' @param class_weights Optional named numeric vector keyed by class labels.
#' @param seed Optional integer seed.
#'
#' @return Integer vector of sampled indices.
#' @export
classic_bootstrap_indices <- function(
  y,
  n_subsamples,
  replace = TRUE,
  class_weights = NULL,
  seed = NULL
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  n <- length(y)
  if (!replace && n_subsamples > n) {
    stop("`n_subsamples` cannot exceed sample size when replace = FALSE.", call. = FALSE)
  }

  probs <- NULL
  if (!is.null(class_weights)) {
    class_ids <- as.character(y)
    if (is.null(names(class_weights))) {
      stop("`class_weights` must be a named numeric vector.", call. = FALSE)
    }
    if (!all(unique(class_ids) %in% names(class_weights))) {
      stop("All observed classes must have an entry in `class_weights`.", call. = FALSE)
    }
    probs <- unname(class_weights[class_ids])
    probs <- probs / sum(probs)
  }

  idx <- sample.int(n = n, size = n_subsamples, replace = replace, prob = probs)

  # Avoid degenerate binary resamples with a single class.
  if (length(unique(y[idx])) < 2L && length(unique(y)) >= 2L) {
    return(classic_bootstrap_indices(
      y = y,
      n_subsamples = n_subsamples,
      replace = replace,
      class_weights = class_weights,
      seed = NULL
    ))
  }

  idx
}

#' Group-Aware Bootstrap Sampler Indices
#'
#' Draws sample indices by first sampling groups and then collecting their
#' member rows to prevent leakage in repeated-measures settings.
#'
#' @param y Outcome vector.
#' @param groups Vector of group identifiers with same length as `y`.
#' @param n_subsamples Target number of rows to include.
#' @param replace Whether groups can be resampled.
#' @param seed Optional integer seed.
#'
#' @return Integer vector of sampled indices.
#' @export
group_bootstrap_indices <- function(y, groups, n_subsamples, replace = FALSE, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  if (length(groups) != length(y)) {
    stop("`groups` must be the same length as `y`.", call. = FALSE)
  }

  n <- length(y)
  if (!replace && n_subsamples > n) {
    stop("`n_subsamples` cannot exceed sample size when replace = FALSE.", call. = FALSE)
  }

  group_levels <- unique(groups)
  sampled_idx <- integer(0)

  while (length(sampled_idx) < n_subsamples) {
    g <- sample(group_levels, size = 1L, replace = replace)
    sampled_idx <- unique(c(sampled_idx, which(groups == g)))
    if (!replace && length(sampled_idx) == n) {
      break
    }
  }

  sampled_idx <- sampled_idx[seq_len(min(length(sampled_idx), n_subsamples))]

  if (length(unique(y[sampled_idx])) < 2L && length(unique(y)) >= 2L) {
    return(group_bootstrap_indices(
      y = y,
      groups = groups,
      n_subsamples = n_subsamples,
      replace = replace,
      seed = NULL
    ))
  }

  sampled_idx
}
