# metrics.R — Selection-stability similarity measures
# R port of stabl/metrics.py
#
# These functions compare lists of selected features across repeat runs of
# STABL (or any other feature-selection method) to assess reproducibility.
# Three families of similarity are provided:
#   - Jaccard: set-overlap fraction, no correction for chance.
#   - Adjusted: chance-corrected overlap (analogous to Cohen's kappa for sets).
#   - Pearson: correlation-inspired chance correction, normalized by set size.
# For simulation benchmarks where a ground-truth feature set is known, the
# file also provides FDR, TPR, and F-score functions.

# ── Jaccard ──────────────────────────────────────────────────────────────────

#' Jaccard Similarity Between Two Feature Sets
#'
#' Measures the overlap between two sets of selected features as a simple
#' fraction of shared features out of all features that appeared in either
#' set.  This is the most interpretable pairwise similarity when no prior
#' expectation of set sizes exists.
#'
#' Use Jaccard when you want a quick, easy-to-explain measure.  Prefer
#' [adjusted_similarity()] or [pearson_similarity()] when comparing across
#' runs that select very different numbers of features, because Jaccard does
#' not correct for the chance overlap expected between small or large sets.
#'
#' When both sets are empty the function returns 0 (convention matching the
#' Python implementation).
#'
#' @param list1 Character or integer vector of selected feature identifiers.
#' @param list2 Character or integer vector of selected feature identifiers.
#'
#' @return Numeric scalar in \eqn{[0, 1]}.  A value of 1 means the two sets
#'   are identical; 0 means they share no features.
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
#' Computes all N\eqn{\times}N pairwise Jaccard similarities in one call.
#' Useful for visualising the reproducibility of STABL across multiple
#' cross-validation folds or repeated runs: a boxplot of the off-diagonal
#' values summarises how consistently the same features are selected.
#'
#' By default the self-similarity diagonal (always 1) is removed, so the
#' returned matrix has \eqn{N \times (N - 1)} columns and each row contains
#' the \eqn{N - 1} similarities of run \eqn{i} with every other run.
#'
#' @param list_of_lists A list of character/integer vectors, one per STABL run
#'   (e.g. one per cross-validation fold).
#' @param remove_diag Logical; if `TRUE` (default) the diagonal column
#'   (self-similarity = 1) is removed from the output.
#'
#' @return Numeric matrix of dimension N\eqn{\times}N (or N\eqn{\times}(N-1)
#'   when `remove_diag = TRUE`).  Row/column order matches `list_of_lists`.
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
    out <- matrix(0, nrow = n, ncol = n - 1L)
    for (i in seq_len(n)) {
      out[i, ] <- mat[i, setdiff(seq_len(n), i)]
    }
    mat <- out
  }
  mat
}

# ── Adjusted similarity ───────────────────────────────────────────────────────

#' Adjusted Similarity Between Two Feature Sets
#'
#' Computes a chance-corrected similarity between two feature sets.  Unlike
#' [jaccard_similarity()], the adjusted measure accounts for the expected
#' random overlap given the sizes of both sets and the total feature universe,
#' so it does not systematically penalise methods that select many features.
#'
#' The formula is analogous to Cohen's kappa for sets:
#' \deqn{S_{\text{adj}}(A, B) =
#'   \frac{r - \mathbb{E}[r]}{\min(k_1, k_2) - \max(0, k_1 + k_2 - d)}}
#' where \eqn{r = |A \cap B|}, \eqn{k_i = |A_i|}, \eqn{d =} `nb_total_elements`,
#' and \eqn{\mathbb{E}[r] = k_1 k_2 / d}.
#'
#' Returns 0 when either set is empty or equals the full universe (edge cases
#' where the correction denominator is zero).
#'
#' @param list1 Character or integer vector of selected feature identifiers.
#' @param list2 Character or integer vector of selected feature identifiers.
#' @param nb_total_elements Integer; total number of candidate features in the
#'   universe (i.e. the number of columns in the original predictor matrix).
#'
#' @return Numeric scalar in \eqn{(-1, 1]}.  Values above 0 indicate more
#'   overlap than expected by chance; 1 means perfect agreement; negative
#'   values indicate less overlap than chance.
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
#' Computes the full pairwise adjusted-similarity matrix for N feature sets and
#' returns only the N\eqn{\times}(N-1)/2 off-diagonal upper-triangle values as
#' a flat vector.  This format is convenient for computing summary statistics
#' (see [adjusted_similarity_measure()]) or for Wilcoxon/permutation tests
#' comparing reproducibility across methods.
#'
#' @param list_of_lists A list of character/integer vectors, one per STABL run.
#' @param nb_total_elements Integer; total number of candidate features.
#'
#' @return Numeric vector of length N*(N-1)/2 containing the pairwise
#'   adjusted-similarity values for all unique pairs (row-major upper-triangle
#'   order, matching the Python convention).
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
  vals <- numeric(n * (n - 1L) / 2L)
  k <- 1L
  if (n >= 2L) {
    for (i in seq_len(n - 1L)) {
      for (j in seq.int(i + 1L, n)) {
        vals[k] <- mat[i, j]
        k <- k + 1L
      }
    }
  }
  vals
}

#' Summary Statistic of Adjusted Similarity Values
#'
#' Convenience wrapper that computes all pairwise adjusted similarities
#' (via [adjusted_similarity_values()]) and reduces them to a single
#' location statistic with an associated spread measure.  Useful for
#' reporting a single reproducibility number per STABL configuration in
#' benchmarking tables.
#'
#' @param list_of_lists A list of character/integer vectors, one per run.
#' @param nb_total_elements Integer; total number of candidate features.
#' @param stat Character; `"median"` (default, robust to outliers) or
#'   `"mean"`.
#'
#' @return A named list with two elements:
#'   \describe{
#'     \item{`statistic`}{The median (or mean) of adjusted-similarity values.}
#'     \item{`err`}{For `"median"`: the 25th and 75th percentile vector
#'       (IQR bounds).  For `"mean"`: the root-mean-squared deviation
#'       (RMSD / population SD).}
#'   }
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
#' expected random intersection.  This is a second chance-correction approach
#' (alongside [adjusted_similarity()]) that normalises by the geometric mean
#' of the within-set variances under independent Bernoulli sampling.
#'
#' The formula is:
#' \deqn{S_{\text{Pearson}}(A, B) =
#'   \frac{r - k_i k_j / d}{d \cdot \upsilon_i \upsilon_j}}
#' where \eqn{r = |A \cap B|}, \eqn{k_i = |A_i|}, \eqn{d} is the universe
#' size, and \eqn{\upsilon_i = \sqrt{\pi_i (1 - \pi_i)}} with
#' \eqn{\pi_i = k_i / d}.
#'
#' Edge cases: returns 1 when both sets are empty or both equal the universe;
#' returns 0 when one set is empty or equals the universe.
#'
#' @param list_i Character or integer vector of selected feature identifiers.
#' @param list_j Character or integer vector of selected feature identifiers.
#' @param d Integer; total number of candidate features in the universe.
#'
#' @return Numeric scalar.  Positive values indicate more overlap than chance;
#'   the maximum is typically close to 1 for perfectly matching sets.
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
#' Computes all pairwise Pearson-corrected similarities and returns the
#' N\eqn{\times}(N-1)/2 upper-triangle values as a flat vector (same layout
#' as [adjusted_similarity_values()], enabling direct comparison between the
#' two metrics on the same data).
#'
#' @param list_of_lists A list of character/integer vectors, one per run.
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
  vals <- numeric(n * (n - 1L) / 2L)
  k <- 1L
  if (n >= 2L) {
    for (i in seq_len(n - 1L)) {
      for (j in seq.int(i + 1L, n)) {
        vals[k] <- mat[i, j]
        k <- k + 1L
      }
    }
  }
  vals
}

#' Summary Statistic of Pearson Similarity Values
#'
#' Convenience wrapper analogous to [adjusted_similarity_measure()] but
#' using the Pearson-corrected similarity.  See [pearson_similarity()] for a
#' description of the underlying metric and when to prefer it over the
#' adjusted similarity.
#'
#' @param list_of_lists A list of character/integer vectors, one per run.
#' @param d Integer; total number of candidate features.
#' @param stat Character; `"median"` (default) or `"mean"`.
#'
#' @return A named list with `statistic` and `err` (see
#'   [adjusted_similarity_measure()] for the exact definitions).
#' @export
pearson_similarity_measure <- function(list_of_lists, d, stat = "median") {
  vals <- pearson_similarity_values(list_of_lists, d)
  .similarity_summary(vals, stat)
}

# ── Classification metrics ────────────────────────────────────────────────────

#' FDR Between Two Feature Sets
#'
#' Computes the False Discovery Rate when `list1` is treated as the predicted
#' selection and `list2` as the known ground-truth.  This metric is only
#' meaningful in simulation benchmarks where the true signal features are
#' known in advance.
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set (ground truth).
#'
#' @return Numeric scalar in \eqn{[0, 1]}.  Returns 0 when the predicted set
#'   is empty (no false discoveries possible).
#' @export
fdr_similarity <- function(list1, list2) {
  tp <- length(intersect(list1, list2))
  fp <- length(setdiff(list1,  list2))
  if (fp + tp == 0L) return(0)
  fp / (tp + fp)
}

#' TPR Between Two Feature Sets
#'
#' Computes the True Positive Rate (sensitivity / recall) when `list1` is the
#' predicted selection and `list2` is the known ground-truth.  Use together
#' with [fdr_similarity()] and [fscore_similarity()] to characterise the
#' precision-recall trade-off in simulation benchmarks.
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set (ground truth).
#'
#' @return Numeric scalar in \eqn{[0, 1]}.  Returns 0 when the true set is
#'   empty.
#' @export
tpr_similarity <- function(list1, list2) {
  tp <- length(intersect(list1, list2))
  fn <- length(setdiff(list2,  list1))
  if (fn + tp == 0L) return(0)
  tp / (tp + fn)
}

#' F-Score Between Two Feature Sets
#'
#' Computes the F\eqn{_\beta} score between a predicted and a ground-truth
#' feature set.  The default `beta = 1` gives the standard F1 score (harmonic
#' mean of precision and recall).  Larger `beta` values weight recall more
#' heavily; smaller values emphasise precision.
#'
#' Use [fdr_similarity()] and [tpr_similarity()] when you want to report
#' precision and recall separately; use `fscore_similarity()` when you need
#' a single number that balances both.
#'
#' @param list1 Predicted feature set (character or integer vector).
#' @param list2 True feature set (ground truth).
#' @param beta Positive numeric; controls trade-off between precision and
#'   recall.  Default 1 gives the F1 score.
#'
#' @return Numeric scalar in \eqn{[0, 1]}.  Returns 0 when both the predicted
#'   and true sets are empty.
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

# ── Internal helpers used by multiomic_workflows.R ───────────────────────────

# Wilcoxon rank-sum based AUC.  y must be 0/1.
.r_auc <- function(y, scores) {
  pos <- which(y == 1L)
  n1 <- length(pos)
  n0 <- length(y) - n1
  if (n1 == 0L || n0 == 0L) return(0.5)
  r <- rank(scores, ties.method = "average")
  (sum(r[pos]) - n1 * (n1 + 1L) / 2L) / (n1 * n0)
}

.r_squared <- function(y, y_hat) {
  ss_tot <- sum((y - mean(y))^2)
  if (ss_tot == 0) return(0)
  1 - sum((y - y_hat)^2) / ss_tot
}

.similarity_summary <- function(vals, stat) {
  if (stat == "median") {
    list(
      statistic = stats::median(vals),
      err       = as.numeric(stats::quantile(vals, probs = c(0.25, 0.75)))
    )
  } else if (stat == "mean") {
    mu <- mean(vals)
    list(
      statistic = mu,
      err       = sqrt(mean((vals - mu)^2))
    )
  } else {
    stop(
      "`stat` must be \"median\" or \"mean\", got \"", stat, "\".",
      call. = FALSE
    )
  }
}
