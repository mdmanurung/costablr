#' Make Random-Permutation Artificial Features
#'
#' Randomly selects `n_injected` columns from `x`, copies them, and shuffles
#' each copy independently.  Mirrors the `"random_permutation"` branch of
#' `Stabl._make_artificial_features()` in the Python STABL library.
#'
#' @param x Numeric matrix of predictors (samples \eqn{\times} features).
#' @param n_injected Integer; number of artificial columns to generate.
#'
#' @return Named list:
#'   \describe{
#'     \item{x_augmented}{Original matrix with artificial columns appended.}
#'     \item{noise_col_indices}{Integer vector (1-based) of original column
#'       indices selected as sources for the artificial block.}
#'   }
#' @keywords internal
make_rp_features <- function(x, n_injected) {
  n_features <- ncol(x)
  indices    <- sample.int(n = n_features, size = n_injected, replace = FALSE)
  x_art      <- x[, indices, drop = FALSE]
  for (i in seq_len(ncol(x_art))) {
    x_art[, i] <- sample(x_art[, i])
  }
  list(
    x_augmented      = cbind(x, x_art),
    noise_col_indices = indices
  )
}

#' Make Knockoff Artificial Features
#'
#' Generates model-X knockoff features via `knockoff::create.fixed()`, with
#' column-chunking for datasets that exceed 3 000 features (mirroring the
#' Python STABL implementation that chunks calls to `GaussianSampler`).
#' Falls back to random-permutation features when the knockoff constructor
#' fails (e.g., rank-deficient input).
#'
#' @param x Numeric matrix of predictors (samples \eqn{\times} features).
#' @param n_injected Integer; number of knockoff columns to select.
#' @param random_state Optional integer seed.
#'
#' @return Named list with elements `x_augmented` and `noise_col_indices`;
#'   see [make_rp_features()] for details.
#' @keywords internal
make_knockoff_features <- function(x, n_injected, random_state = NULL) {
  if (!requireNamespace("knockoff", quietly = TRUE)) {
    stop(
      "Package 'knockoff' is required for artificial_type = \"knockoff\". ",
      "Install it with: install.packages(\"knockoff\")",
      call. = FALSE
    )
  }

  if (!is.null(random_state)) set.seed(random_state)

  n_features <- ncol(x)
  chunk_size <- 3000L

  .make_ko_chunk <- function(x_chunk) {
    tryCatch(
      knockoff::create.fixed(x_chunk)$Xk,
      error = function(e) {
        warning(
          "knockoff::create.fixed failed; falling back to random ",
          "permutation for this chunk. Reason: ", conditionMessage(e),
          call. = FALSE
        )
        make_rp_features(x_chunk, ncol(x_chunk))$x_augmented[
          , seq(ncol(x_chunk) + 1L, 2L * ncol(x_chunk)), drop = FALSE
        ]
      }
    )
  }

  if (n_features > chunk_size) {
    n_chunks   <- ceiling(n_features / chunk_size)
    ko_blocks  <- vector("list", n_chunks)
    for (i in seq_len(n_chunks)) {
      col_idx      <- sample.int(n_features, size = min(chunk_size, n_features),
                                 replace = FALSE)
      ko_blocks[[i]] <- .make_ko_chunk(x[, col_idx, drop = FALSE])
    }
    x_art_full <- do.call(cbind, ko_blocks)  # n_samples × (n_chunks * chunk_size)
    keep_idx   <- sample.int(ncol(x_art_full), size = n_features, replace = FALSE)
    x_art_full <- x_art_full[, keep_idx, drop = FALSE]
  } else {
    x_art_full <- .make_ko_chunk(x)  # n_samples × n_features
  }

  sel_idx <- sample.int(n = ncol(x_art_full), size = n_injected, replace = FALSE)
  x_art   <- x_art_full[, sel_idx, drop = FALSE]

  list(
    x_augmented      = cbind(x, x_art),
    noise_col_indices = sel_idx
  )
}

#' Dispatcher for Artificial Feature Generation
#'
#' Selects and calls the appropriate artificial-feature generator based on
#' `type`, returning the augmented predictor matrix together with the column
#' indices of the injected noise block.
#'
#' Injecting artificial features is central to STABL's automatic FDP+ control:
#' by mixing known-noise columns into the predictor matrix alongside real
#' features, STABL can empirically estimate how often a variable of pure noise
#' is selected at a given stability threshold.  This observed noise-selection
#' rate drives the FDP+ bound computed in [compute_fdp_plus()], eliminating
#' the need to choose a stability threshold by hand.
#'
#' Two noise strategies are supported:
#' \describe{
#'   \item{`"random_permutation"`}{Copies `n_injected` randomly chosen real
#'     columns and shuffles each copy independently, breaking all signal while
#'     preserving marginal distributions.  Fast and broadly applicable.}
#'   \item{`"knockoff"`}{Generates model-X knockoffs via
#'     [knockoff::create.fixed()], which preserve the covariance structure of
#'     the original features.  More powerful when features are correlated, at
#'     the cost of requiring the optional `knockoff` package and higher
#'     compute.}
#' }
#'
#' @param x Numeric matrix of predictors (samples \eqn{\times} features).
#'   Must have more columns than `n_injected` for random permutation; for
#'   knockoffs, must not be rank-deficient (a fallback to random permutation
#'   is attempted otherwise).
#' @param n_injected Positive integer; number of artificial columns to append.
#'   Typically `round(ncol(x) * artificial_proportion)` as computed in
#'   [stabl_fit()].
#' @param type Character string; `"random_permutation"` or `"knockoff"`.
#' @param random_state Optional integer; passed to [set.seed()] before any
#'   random operations for reproducibility.  `NULL` leaves the RNG unchanged.
#'
#' @return Named list with two elements:
#'   \describe{
#'     \item{`x_augmented`}{Numeric matrix of size
#'       (nrow(x)) \eqn{\times} (ncol(x) + n_injected) with the artificial
#'       columns appended after the original features.}
#'     \item{`noise_col_indices`}{Integer vector of length `n_injected`
#'       containing the 1-based indices (into the artificial block itself)
#'       that identify which artificial features were injected.  Used by
#'       [stabl_fit()] to extract the artificial-feature stability scores.}
#'   }
#'
#' @seealso [compute_fdp_plus()] which consumes the artificial-feature scores,
#'   [stabl_fit()] which calls this function automatically.
#' @export
make_artificial_features <- function(x, n_injected, type, random_state = NULL) {
  if (!is.null(random_state)) set.seed(random_state)
  switch(
    type,
    random_permutation = make_rp_features(x, n_injected),
    knockoff           = make_knockoff_features(x, n_injected,
                                                random_state = random_state),
    stop(
      "`type` must be \"random_permutation\" or \"knockoff\", got: ", type,
      call. = FALSE
    )
  )
}
