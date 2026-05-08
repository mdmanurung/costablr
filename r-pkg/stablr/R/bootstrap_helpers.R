#' Classic Bootstrap Sampler Indices
#'
#' Draws a random set of row indices from a training set for a single STABL
#' bootstrap iteration.  This is the standard (non-grouped) sampler used when
#' all samples are independent.
#'
#' STABL accumulates how often each feature is selected across many bootstrap
#' subsamples; these subsamples must be drawn consistently to avoid bias.
#' This function centralises that sampling so that class-imbalance handling
#' and the "degenerate bootstrap" guard (see below) are applied uniformly.
#'
#' @details
#' **Class weighting:** When `class_weights` is supplied each sample's
#' inclusion probability is proportional to the weight of its class.  This is
#' useful for imbalanced binary or multi-class outcomes where unweighted
#' subsampling would frequently produce single-class bootstraps.
#'
#' **Degenerate bootstrap guard:** When the drawn subsample contains only one
#' unique class but the full outcome contains at least two, the function
#' retries (without a seed) until a class-diverse subsample is found.  This
#' prevents downstream model failures in classifiers that require at least two
#' classes.
#'
#' @param y Outcome vector whose length equals the number of training samples.
#'   Values are only examined to check class diversity and to apply
#'   `class_weights`; the type is arbitrary (numeric, factor, character).
#' @param n_subsamples Positive integer; number of row indices to draw.  Must
#'   not exceed `length(y)` when `replace = FALSE`.
#' @param replace Logical; sample with replacement?  Default `TRUE`.
#' @param class_weights Optional named numeric vector keyed by class labels
#'   (as produced by `as.character(y)`).  When `NULL` all samples are equally
#'   likely.
#' @param seed Optional integer; passed to [set.seed()] before sampling for
#'   reproducibility.  `NULL` leaves the RNG state unchanged.
#'
#' @return Integer vector of length `n_subsamples` containing 1-based row
#'   indices into the training set.
#'
#' @seealso [group_bootstrap_indices()] for repeated-measures/grouped data,
#'   [stabl_fit()] which calls this sampler automatically.
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
#' Draws row indices for a single STABL bootstrap iteration by sampling
#' **groups** rather than individual samples.  Use this instead of
#' [classic_bootstrap_indices()] whenever the training data contains repeated
#' measurements or known clusters (e.g. multiple time-points per subject,
#' technical replicates, or family members).
#'
#' @details
#' **Why group-level sampling prevents leakage:** If individual rows from the
#' same subject appear in both the bootstrap subsample and its complement, the
#' stability score becomes inflated because the learner can partially memorise
#' subject-level patterns.  By sampling complete groups, the subsample and its
#' "holdout" are subject-disjoint, preserving the independence assumption
#' underlying STABL's FDP+ guarantee.
#'
#' **How groups are sampled:** Groups are drawn one at a time (without
#' replacement by default) until the running tally of included rows reaches
#' `n_subsamples`.  If the last added group causes the count to exceed
#' `n_subsamples`, the excess rows are trimmed.  When `replace = TRUE` the
#' same group may be drawn multiple times (useful when there are very few
#' groups).
#'
#' **Degenerate bootstrap guard:** As with [classic_bootstrap_indices()], if
#' the final subsample contains only one unique class the function retries
#' until a class-diverse sample is obtained.
#'
#' @param y Outcome vector with the same length as `groups`.
#' @param groups Vector of group identifiers (same length as `y`).  Values may
#'   be any type that supports `unique()` and equality comparison.
#' @param n_subsamples Positive integer; target number of rows in the
#'   subsample.  The actual count may differ slightly due to whole-group
#'   granularity.
#' @param replace Logical; may the same group be sampled more than once?
#'   Default `FALSE`.
#' @param seed Optional integer; passed to [set.seed()] before sampling.
#'   `NULL` leaves the RNG state unchanged.
#'
#' @return Integer vector of 1-based row indices into the training set.
#'
#' @seealso [classic_bootstrap_indices()] for independent-sample data,
#'   [stabl_fit()] which calls this sampler automatically when `groups` is
#'   supplied.
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
  # When replace = FALSE, each group may only be drawn once.
  # Track the remaining available pool so we stop re-drawing exhausted groups.
  remaining   <- group_levels
  sampled_idx <- integer(0)

  while (length(sampled_idx) < n_subsamples && length(remaining) > 0L) {
    g         <- sample(remaining, size = 1L)
    remaining <- if (replace) remaining else remaining[remaining != g]
    sampled_idx <- unique(c(sampled_idx, which(groups == g)))
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
