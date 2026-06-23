#' Compute FDP+ (False Discovery Proportion Upper Bound)
#'
#' Sweeps a grid of stability-score thresholds and computes the FDP+ estimate
#' at each one, then identifies the threshold that minimises it.  This is a
#' direct port of `Stabl._compute_FDPplus()` from the Python STABL library.
#'
#' The FDP+ at threshold \eqn{\tau} is estimated as:
#' \deqn{\widehat{\text{FDP}}(\tau) =
#'   \frac{(1/\pi) \cdot |\{j : \hat{q}_j^{\text{art}} > \tau\}| + 1}
#'        {\max(1,\, |\{j : \hat{q}_j > \tau\}|)}}
#' where \eqn{\pi} is `artificial_proportion`, \eqn{\hat{q}_j} are the
#' maximum-over-lambda stability scores for real feature \eqn{j}, and
#' \eqn{\hat{q}_j^{\text{art}}} are the scores for artificial feature \eqn{j}.
#'
#' @param stabl_scores Numeric matrix (features \eqn{\times} lambdas) of
#'   stability scores for the real features.
#' @param stabl_scores_artificial Numeric matrix (artificial features
#'   \eqn{\times} lambdas) of stability scores for the injected noise features.
#' @param artificial_proportion Positive numeric scalar; the fraction of
#'   artificial features relative to real features (used as \eqn{\pi}).
#' @param fdr_threshold_range Numeric vector of threshold values to sweep.
#'   Default: `seq(0, 0.99, by = 0.01)`, matching Python STABL's
#'   `np.arange(0., 1., .01)`.
#'
#' @return Named list:
#'   \describe{
#'     \item{FDRs}{Numeric vector of FDP+ estimates, one per threshold.}
#'     \item{min_fdr}{Minimum FDP+ achieved across the threshold range.}
#'     \item{fdr_min_threshold}{Threshold value achieving `min_fdr`, capped
#'       at 1.}
#'     \item{fdrs_table}{Numeric matrix (lambdas \eqn{\times} thresholds) of
#'       per-lambda FDP+ values.}
#'   }
#'
#' @examples
#' # Small synthetic stability-score matrices (3 real + 3 artificial features,
#' # 2 lambda values)
#' scores_real <- matrix(c(0.8, 0.6, 0.1, 0.9, 0.5, 0.05), nrow = 3)
#' scores_art  <- matrix(c(0.1, 0.2, 0.3, 0.15, 0.25, 0.1), nrow = 3)
#' result <- compute_fdp_plus(scores_real, scores_art,
#'                            artificial_proportion = 1.0)
#' result$min_fdr           # minimum FDP+ estimate
#' result$fdr_min_threshold # threshold that achieves it
#'
#' @seealso [stabl_fit()] which calls this internally when artificial features
#'   are used, [plot_fdr_graph()] to visualise the FDP+ curve.
#' @export
compute_fdp_plus <- function(
    stabl_scores,
    stabl_scores_artificial,
    artificial_proportion,
    fdr_threshold_range = seq(0, 0.99, by = 0.01)
) {
  inv_prop    <- 1.0 / artificial_proportion
  max_scores  <- apply(stabl_scores,            1L, max)
  max_art     <- apply(stabl_scores_artificial, 1L, max)
  n_thresh    <- length(fdr_threshold_range)

  # Vectorized FDP+ across all lambda (uses row-max scores).
  # outer() produces an (n_features × n_thresh) logical matrix; colSums gives
  # the count of features exceeding each threshold in one pass.
  n_real <- colSums(outer(max_scores, fdr_threshold_range, ">"))
  n_art  <- colSums(outer(max_art,    fdr_threshold_range, ">"))
  FDRs   <- (inv_prop * n_art + 1.0) / pmax(1.0, n_real)

  # Per-lambda FDP+ table: for each threshold sweep the full score matrix at
  # once (colSums on the n_features × n_lambdas comparison result), then
  # collect into an (n_lambdas × n_thresh) matrix in one pass.
  n_lambdas  <- ncol(stabl_scores)
  nr_table <- matrix(
    vapply(fdr_threshold_range,
           function(t) colSums(stabl_scores > t),
           numeric(n_lambdas)),
    nrow = n_lambdas, ncol = n_thresh
  )
  na_table <- matrix(
    vapply(fdr_threshold_range,
           function(t) colSums(stabl_scores_artificial > t),
           numeric(n_lambdas)),
    nrow = n_lambdas, ncol = n_thresh
  )
  fdrs_table <- (inv_prop * na_table + 1.0) / pmax(1.0, nr_table)

  min_fdr <- min(FDRs)
  fdr_min_threshold <- if (min_fdr > 1.0) {
    1.0
  } else {
    min(fdr_threshold_range[which.min(FDRs)], 1.0)  # ties: first-index wins (matches Python argmin)
  }

  list(
    FDRs              = FDRs,
    min_fdr           = min_fdr,
    fdr_min_threshold = fdr_min_threshold,
    fdrs_table        = fdrs_table
  )
}
