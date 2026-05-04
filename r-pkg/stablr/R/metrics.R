# metrics.R — Selection-stability similarity measures
# R port of stabl/metrics.py
#
# These functions compare lists of selected features across repeat runs of
# STABL (or any other feature-selection method) to assess reproducibility.

# ── Jaccard ──────────────────────────────────────────────────────────────────

#' Jaccard Similarity Between Two Feature Sets
#'
#' Computes the Jaccard index between two character (or integer) vectors treated
#' as sets.  When both sets are empty the function returns 0 (convention
#' matching the Python implementation).
#'
#' @param list1 Character or integer vector of selected feature identifiers.
#' @param list2 Character or integer vector of selected feature identifiers.
#'
#' @return Numeric scalar in \eqn{[0, 1]}.
#' @export
jaccard_similarity <- function(list1, list2) {
  s1 <- unique(list1)
  s2 <- unique(list2)
  inter <- length(intersect(s1, s2))
  union_size <- length(s1) + length(s2) - inter
  if (inter == 0L && union_size == 0L) return(0)
  inter / union_size
}

#' Pairwise Jaccard Matrix from a List of Feature Sets
#'
#' Computes all pairwise Jaccard similarities among the elements of
#' `list_of_lists`.  By default the (self-similarity) diagonal is removed,
#' returning an N x (N-1) matrix.
#'
#' @param list_of_lists A list of character/integer vectors, one per STABL run.
#' @param remove_diag Logical; if `TRUE` (default) the diagonal column is
#'   removed from the result.
#'
#' @return Numeric matrix of dimension N x N (or N x (N-1) when
#'   `remove_diag = TRUE`).
#' @export
jaccard_matrix <- function(list_of_lists, remove_diag = TRUE) {
  n <- length(list_of_lists)
  mat <- matrix(0, nrow = n, ncol = n)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      mat[i, j] <- jaccard_similarity(list_of_lists[[i]], list_of_lists[[j]])
    }
  }
  if (remove_diag) {
    mat <- mat[, -seq(1, n * n, by = n + 1L), drop = FALSE]
    # Equivalent to np array[~eye] reshape; remove diagonal column-wise.
    # Re-implement: drop col j == row i (diagonal positions) per column index.
    mat <- do.call(
      cbind,
      lapply(seq_len(n), function(i) {
        col_data <- numeric(n - 1L)
        idx <- setdiff(seq_len(n), i)
        for (k in seq_along(idx)) col_data[k] <- jaccard_similarity(
          list_of_lists[[i]], list_of_lists[[idx[k]]]
        )
        col_data
      })
    )
  }
  mat
}

# ── Adjusted similarity ───────────────────────────────────────────────────────

#' Adjusted Similarity Between Two Feature Sets
#'
#' Computes the chance-adjusted similarity between two feature sets.  The
#' adjustment accounts for set size relative to the total feature universe so
#' that random overlap is penalised.
#'
#' Returns 0 when either set is empty or equals the full universe (edge cases
#' where the correction is undefined in a meaningful way).
#'
#' @param list1 Character or integer vector.
#' @param list2 Character or integer vector.
#' @param nb_total_elements Integer; total number of candidate features.
#'
#' @return Numeric scalar in \eqn{(-1, 1]}.
#' @export
adjusted_similarity <- function(list1, list2, nb_total_elements) {
  s1 <- unique(list1)
  s2 <- unique(list2)
  r  <- length(intersect(s1, s2))
  k1 <- length(s1)
  k2 <- length(s2)
  u  <- k1 + k2 - r

  d <- as.integer(nb_total_elements)
  if (u > d) {
    stop(
      "Union cardinal (", u, ") exceeds nb_total_elements (", d, ").",
      call. = FALSE
    )
  }
  if (k1 == d || k2 == d || k1 == 0L || k2 == 0L) return(0)

  num   <- r - (k1 * k2) / d
  denom <- min(k1, k2) - max(0L, k1 + k2 - d)
  num / denom
}

#' Upper-Triangle Adjusted Similarity Values
#'
#' Computes the full adjusted-similarity matrix and returns only the upper
#' triangle (excluding the diagonal), matching the Python convention.
#'
#' @param list_of_lists A list of character/integer vectors.
#' @param nb_total_elements Integer; total number of candidate features.
#'
#' @return Numeric vector of length N*(N-1)/2.
#' @export
adjusted_similarity_values <- function(list_of_lists, nb_total_elements) {
  n <- length(list_of_lists)
  mat <- matrix(0, nrow = n, ncol = n)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      mat[i, j] <- adjusted_similarity(
        list_of_lists[[i]], list_of_lists[[j]], nb_total_elements
      )
    }
  }
  mat[upper.tri(mat)]
}

#' Summary Statistic of Adjusted Similarity Values
#'
#' @param list_of_lists A list of character/integer vectors.
#' @param nb_total_elements Integer; total number of candidate features.
#' @param stat Character; `"median"` (default) or `"mean"`.
#'
#' @return A named list with two elements:
#'   - `statistic`: the median (or mean) of adjusted-similarity values,
#'   - `err`: for `"median"` the 25th and 75th percentiles; for `"mean"` the
#'     standard deviation.
#' @export
adjusted_similarity_measure <- function(list_of_lists, nb_total_elements,
                                        stat = "median") {
  vals <- adjusted_similarity_values(list_of_lists, nb_total_elements)
  .similarity_summary(vals, stat)
}

# ── Pearson similarity ────────────────────────────────────────────────────────

#' Pearson-Corrected Similarity Between Two Feature Sets
#'
#' Computes a Pearson-correlation-inspired similarity that corrects for
#' expected random intersection.  Convention: returns 1 when both sets are
#' either empty or equal the full universe.
#'
#' @param list_i Character or integer vector.
#' @param list_j Character or integer vector.
#' @param d Integer; total number of candidate features.
#'
#' @return Numeric scalar.
#' @export
pearson_similarity <- function(list_i, list_j, d) {
  si <- unique(list_i)
  sj <- unique(list_j)
  r  <- length(intersect(si, sj))
  ki <- length(si)
  kj <- length(sj)
  d  <- as.integer(d)

  if ((ki == d && kj == d) || (ki == 0L && kj == 0L)) {
    return(1)
  }
  if (ki == 0L || kj == 0L || ki == d || kj == d) {
    return(0)
  }

  exp_r      <- (ki * kj) / d
  pi_i       <- ki / d
  pi_j       <- kj / d
  upsilon_i  <- sqrt(pi_i * (1 - pi_i))
  upsilon_j  <- sqrt(pi_j * (1 - pi_j))
  (r - exp_r) / (d * upsilon_i * upsilon_j)
}

#' Upper-Triangle Pearson Similarity Values
#'
#' @param list_of_lists A list of character/integer vectors.
#' @param d Integer; total number of candidate features.
#'
#' @return Numeric vector of length N*(N-1)/2.
#' @export
pearson_similarity_values <- function(list_of_lists, d) {
  n <- length(list_of_lists)
  mat <- matrix(0, nrow = n, ncol = n)
  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      mat[i, j] <- pearson_similarity(list_of_lists[[i]], list_of_lists[[j]], d)
    }
  }
  mat[upper.tri(mat)]
}

#' Summary Statistic of Pearson Similarity Values
#'
#' @param list_of_lists A list of character/integer vectors.
#' @param d Integer; total number of candidate features.
#' @param stat Character; `"median"` (default) or `"mean"`.
#'
#' @return A named list with `statistic` and `err` (see
#'   [adjusted_similarity_measure()]).
#' @export
pearson_similarity_measure <- function(list_of_lists, d, stat = "median") {
  vals <- pearson_similarity_values(list_of_lists, d)
  .similarity_summary(vals, stat)
}

# ── Classification metrics ────────────────────────────────────────────────────

#' FDR Between Two Feature Sets
#'
#' Treats `list2` as the ground-truth set.  Returns 0 when the predicted
#' set is empty.
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set.
#'
#' @return Numeric scalar in \eqn{[0, 1]}.
#' @export
fdr_similarity <- function(list1, list2) {
  tp <- length(intersect(list1, list2))
  fp <- length(setdiff(list1,  list2))
  if (fp + tp == 0L) return(0)
  fp / (tp + fp)
}

#' TPR Between Two Feature Sets
#'
#' Treats `list2` as the ground-truth set.  Returns 0 when the true set is
#' empty.
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set.
#'
#' @return Numeric scalar in \eqn{[0, 1]}.
#' @export
tpr_similarity <- function(list1, list2) {
  tp <- length(intersect(list1, list2))
  fn <- length(setdiff(list2,  list1))
  if (fn + tp == 0L) return(0)
  tp / (tp + fn)
}

#' F-Score Between Two Feature Sets
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set.
#' @param beta Numeric; controls trade-off between precision and recall
#'   (default 1 gives the F1 score).
#'
#' @return Numeric scalar in \eqn{[0, 1]}.
#' @export
fscore_similarity <- function(list1, list2, beta = 1) {
  tp <- length(intersect(list1, list2))
  fp <- length(setdiff(list1,  list2))
  fn <- length(setdiff(list2,  list1))
  num <- (1 + beta^2) * tp
  den <- (1 + beta^2) * tp + beta^2 * fn + fp
  if (den == 0L) return(0)
  num / den
}

# ── Internal helpers ──────────────────────────────────────────────────────────

.similarity_summary <- function(vals, stat) {
  if (stat == "median") {
    list(
      statistic = stats::median(vals),
      err       = as.numeric(stats::quantile(vals, probs = c(0.25, 0.75)))
    )
  } else if (stat == "mean") {
    list(
      statistic = mean(vals),
      err       = stats::sd(vals)
    )
  } else {
    stop(
      "`stat` must be \"median\" or \"mean\", got \"", stat, "\".",
      call. = FALSE
    )
  }
}
