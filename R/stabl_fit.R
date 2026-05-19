#' Fit STABL (Stability-Penalized Feature Selection)
#'
#' Performs the STABL bootstrap stability-selection procedure over a grid of
#' regularisation parameters, optionally injecting artificial features for
#' automatic FDP+ threshold control.  This is the R counterpart of
#' `Stabl.fit()` in the Python STABL library.
#'
#' @param x A numeric matrix or `data.frame` (samples \eqn{\times} features)
#'   with row names used as sample IDs.
#' @param y A named numeric/factor vector whose names are sample IDs, or a
#'   matrix-like outcome (for example `survival::Surv`) with row names as
#'   sample IDs.
#' @param lambda_grid A pre-expanded `data.frame` (each row = one parameter
#'   combination) with at least a `lambda` column.  Pass `"auto"` to derive a
#'   data-driven grid via [auto_lambda_grid()] (uses `family` and `n_lambda`).
#' @param base_learner Character; `"lasso"` (alpha = 1), `"elastic_net"`
#'   (reads `alpha` from the `lambda_grid` `alpha` column), or
#'   `"adaptive_lasso"`, or `"sparse_group_lasso"`. Default: `"lasso"`.
#' @param family Character; `glmnet` response family (`"gaussian"`,
#'   `"binomial"`, `"multinomial"`, `"poisson"`, or `"cox"`). Default:
#'   `"gaussian"`.
#' @param n_bootstraps Positive integer; bootstrap iterations per lambda.
#'   Default: `1000L`.
#' @param artificial_type Character or `NULL`; `"random_permutation"`,
#'   `"modelx_knockoff"`, `"mvr_knockoff"`, or `NULL` (no artificial features — requires
#'   `hard_threshold`).  Default: `"random_permutation"`.
#' @param artificial_proportion Numeric in `(0, 1]`; fraction of original
#'   features to inject as artificial noise.  The realised count is
#'   `floor(ncol(x) * artificial_proportion)`, matching Python STABL. Default:
#'   `1.0`.
#' @param sample_fraction Positive numeric; fraction of samples drawn per
#'   bootstrap.  Default: `0.5`.
#' @param replace Logical; sample with replacement?  Default: `FALSE`.
#' @param hard_threshold Numeric in `(0, 1]` or `NULL`.  When supplied, FDP+
#'   control is bypassed and this value is the stability-score cut-off.
#'   Default: `NULL`.
#' @param fdr_threshold_range Numeric vector swept when computing FDP+.
#'   Default: `seq(0, 0.99, by = 0.01)`, matching Python STABL's
#'   `np.arange(0., 1., .01)`.
#' @param explore Logical; if `TRUE` and no features pass the threshold,
#'   lower the cutoff to the `n_explore`-th largest score minus `0.01`.
#'   Default: `FALSE`.
#' @param n_explore Positive integer; fallback rank used when `explore = TRUE`.
#'   Tied scores can select more than this count. Default: `5L`.
#' @param bootstrap_threshold Numeric scalar, character string, or `NULL`;
#'   per-bootstrap feature-selection cutoff applied to absolute coefficients.
#'   Numeric thresholds keep features with `|coef| >= bootstrap_threshold`.
#'   Strings may be `"mean"`, `"median"`, or scaled forms such as
#'   `"1.25*mean"`, matching sklearn `SelectFromModel` threshold syntax.
#'   `NULL` resolves to the upstream STABL l1 default of `1e-5`. Default:
#'   `1e-5`.
#' @param groups Named vector of group IDs (same names as `rownames(x)`) or
#'   `NULL`.  When supplied, [group_bootstrap_indices()] is used instead of
#'   [classic_bootstrap_indices()].  Default: `NULL`.
#' @param stratify_bootstrap Logical; if `TRUE`, bootstrap subsamples are
#'   stratified by the outcome class.  This is intended for classification
#'   tasks with small or imbalanced classes.  Default `FALSE` preserves the
#'   original STABL sampling behavior.
#' @param bootstrap_strata Optional categorical stratification design for
#'   bootstrap sampling.  Provide a named vector, matrix, `data.frame`, or
#'   list with one row/value per sample.  Multiple columns are combined as a
#'   joint interaction stratum, for example outcome class by study group.  When
#'   supplied, this overrides `stratify_bootstrap`.
#' @param n_lambda Integer; number of lambda values when `lambda_grid = "auto"`.
#'   Ignored otherwise.  Default: `30L`.
#' @param l1_ratio Numeric scalar, numeric vector, or `NULL`. Passed to
#'   [auto_lambda_grid()] when `lambda_grid = "auto"`. Use this for
#'   `base_learner = "elastic_net"` so the generated grid contains the
#'   elastic-net `alpha` column. For `base_learner = "elastic_net"` and
#'   `lambda_grid = "auto"`, default `NULL` expands to Python STABL's
#'   `c(0.5, 0.7, 0.9)` auto-mode grid.
#' @param verbose Logical; emit progress messages.  Default: `FALSE`.
#' @param workers Positive integer; parallel workers for the bootstrap loop.
#'   Values above `1` use a scoped `future`/`furrr` multisession plan when
#'   those optional packages are installed, and otherwise fall back to
#'   sequential execution with a warning.  Default: `1L`.
#' @param random_state Integer or `NULL`; top-level seed.  Default: `NULL`.
#' @param adaptive_gamma Positive numeric scalar. Used only when
#'   `base_learner = "adaptive_lasso"`.
#' @param adaptive_epsilon Positive numeric scalar. Used only when
#'   `base_learner = "adaptive_lasso"`.
#' @param feature_groups Optional feature-group definition for
#'   `base_learner = "sparse_group_lasso"`. Provide a vector/factor of length
#'   `ncol(x)` assigning each original feature to a group.
#' @param corr_group_threshold Optional numeric percentile in `(0, 100]` used
#'   to derive sparse-group feature groups from pairwise correlations of
#'   original features. Used only when
#'   `base_learner = "sparse_group_lasso"`.
#'
#' @return An S3 object of class `"stabl_fit"` containing:
#'   \describe{
#'     \item{`stabl_scores_`}{Numeric matrix (features \eqn{\times} lambdas)
#'       of per-bootstrap selection frequencies (stability scores).}
#'     \item{`stabl_scores_artificial_`}{Analogous matrix for artificial
#'       features, or `NULL` when `artificial_type = NULL`.}
#'     \item{`fitted_lambda_grid`}{The `data.frame` of lambda combinations
#'       actually used.}
#'     \item{`family`}{Model family used by the selector and downstream final
#'       refits.}
#'     \item{`fdr_min_threshold_`}{FDP+-optimal stability threshold, or `NULL`.}
#'     \item{`FDRs_`}{Numeric vector of FDP+ estimates per threshold, or `NULL`.}
#'     \item{`min_fdr_`}{Minimum FDP+ achieved, or `NULL`.}
#'     \item{`fdrs_table_`}{Per-lambda FDP+ matrix, or `NULL`.}
#'     \item{`hard_threshold`}{As supplied.}
#'     \item{`artificial_type`}{As supplied.}
#'     \item{`artificial_type_used_`}{Artificial-feature strategy actually
#'       used after any constructor fallback, or `NULL` when
#'       `artificial_type = NULL`.}
#'     \item{`artificial_proportion`}{As supplied.}
#'     \item{`bootstrap_threshold`}{As supplied.}
#'     \item{`explore`}{As supplied.}
#'     \item{`n_explore`}{As supplied.}
#'     \item{`feature_names`}{Character vector of original feature names.}
#'     \item{`n_features_in_`}{Integer number of original features.}
#'   }
#'
#' @examples
#' set.seed(42)
#' n <- 50L
#' p <- 10L
#' x <- matrix(
#'   rnorm(n * p),
#'   nrow = n,
#'   dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
#' )
#' y <- setNames(0.8 * x[, 1] - 0.5 * x[, 2] + rnorm(n, sd = 0.3), rownames(x))
#' lambda_grid <- data.frame(lambda = seq(0.02, 0.30, length.out = 4L))
#'
#' # Default lasso path
#' fit_lasso <- stabl_fit(
#'   x = x,
#'   y = y,
#'   lambda_grid = lambda_grid,
#'   n_bootstraps = 6L,
#'   artificial_type = "random_permutation",
#'   random_state = 1L
#' )
#' get_feature_names_out(fit_lasso)
#'
#' # Adaptive lasso path
#' fit_adaptive <- stabl_fit(
#'   x = x,
#'   y = y,
#'   lambda_grid = lambda_grid,
#'   base_learner = "adaptive_lasso",
#'   adaptive_gamma = 1.0,
#'   adaptive_epsilon = 1e-6,
#'   n_bootstraps = 6L,
#'   artificial_type = "random_permutation",
#'   random_state = 2L
#' )
#' get_importances(fit_adaptive)
#'
#' # Sparse-group lasso path (optional dependency)
#' if (requireNamespace("sparsegl", quietly = TRUE)) {
#'   feature_groups <- rep(seq_len(5L), each = 2L)
#'   fit_sgl <- stabl_fit(
#'     x = x,
#'     y = y,
#'     lambda_grid = lambda_grid,
#'     base_learner = "sparse_group_lasso",
#'     feature_groups = feature_groups,
#'     n_bootstraps = 5L,
#'     artificial_type = "random_permutation",
#'     random_state = 3L
#'   )
#'   get_support(fit_sgl)
#' }
#'
#' # Multinomial path with three classes
#' y_multi <- setNames(
#'   factor(sample(c("A", "B", "C"), n, replace = TRUE)),
#'   rownames(x)
#' )
#' fit_multi <- suppressWarnings(stabl_fit(
#'   x = x,
#'   y = y_multi,
#'   lambda_grid = lambda_grid,
#'   family = "multinomial",
#'   n_bootstraps = 5L,
#'   artificial_type = "random_permutation",
#'   random_state = 4L
#' ))
#' get_feature_names_out(fit_multi)
#' @export
stabl_fit <- function(
    x,
    y,
    lambda_grid,
    base_learner          = "lasso",
    family                = "gaussian",
    n_bootstraps          = 1000L,
    artificial_type       = "random_permutation",
    artificial_proportion = 1.0,
    sample_fraction       = 0.5,
    replace               = FALSE,
    hard_threshold        = NULL,
    fdr_threshold_range   = seq(0, 0.99, by = 0.01),
    explore               = FALSE,
    n_explore             = 5L,
    bootstrap_threshold   = 1e-5,
    groups                = NULL,
    stratify_bootstrap    = FALSE,
    bootstrap_strata      = NULL,
    n_lambda              = 30L,
    l1_ratio              = NULL,
    verbose               = FALSE,
    workers               = 1L,
    random_state          = NULL,
    adaptive_gamma        = 1.0,
    adaptive_epsilon      = 1e-6,
    feature_groups        = NULL,
    corr_group_threshold  = NULL
) {
  workers <- .normalize_worker_count(workers)
  family <- .validate_stabl_family(family)

  # ---- Input coercion -------------------------------------------------------
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix or data.frame.", call. = FALSE)
  }

  validate_sample_alignment(x, y, groups)

  # Align y (and groups) to row order of x
  y <- .subset_outcome_by_ids(y, rownames(x))
  if (!is.null(groups)) groups <- groups[rownames(x)]
  if (!is.null(bootstrap_strata)) {
    bootstrap_strata <- .subset_bootstrap_strata_by_ids(
      bootstrap_strata,
      sample_ids = rownames(x)
    )
  } else if (isTRUE(stratify_bootstrap)) {
    bootstrap_strata <- y
  }
  bootstrap_strata_ids <- .bootstrap_strata_ids(
    strata = bootstrap_strata,
    n = nrow(x),
    arg = "bootstrap_strata"
  )

  # ---- Validate scalar params -----------------------------------------------
  .validate_stabl_params(n_bootstraps, sample_fraction, replace,
                         hard_threshold, artificial_type,
                         artificial_proportion, stratify_bootstrap,
                         bootstrap_threshold)

  n_samples   <- nrow(x)
  n_features  <- ncol(x)
  feat_names  <- colnames(x)
  if (is.null(feat_names)) {
    feat_names <- paste0("x.", seq_len(n_features))
    colnames(x) <- feat_names
  }

  # ---- Lambda grid ----------------------------------------------------------
  if (identical(lambda_grid, "auto")) {
    if (verbose) message("Computing auto lambda grid...")
    auto_l1_ratio <- l1_ratio
    if (identical(base_learner, "elastic_net") && is.null(auto_l1_ratio)) {
      auto_l1_ratio <- c(0.5, 0.7, 0.9)
    }
    lambda_grid <- auto_lambda_grid(
      x,
      y,
      family = family,
      n_lambda = n_lambda,
      l1_ratio = auto_l1_ratio
    )
  }
  if (!is.data.frame(lambda_grid)) {
    stop("`lambda_grid` must be a data.frame or \"auto\".", call. = FALSE)
  }
  if (!"lambda" %in% names(lambda_grid)) {
    stop("`lambda_grid` must contain a `lambda` column.", call. = FALSE)
  }
  n_lambdas <- nrow(lambda_grid)

  # ---- Derived RNG streams (audit M-5, V-7) ---------------------------------
  # When `random_state` is set we draw three independent integer seeds from a
  # single seeded RNG: one for artificial-feature generation, one for the
  # bootstrap-index draws, and one used as the base of per-iteration seeds
  # passed into the bootstrap loop.  This keeps the three RNG streams
  # independent (artificial features cannot consume RNG that boot indices
  # need) and makes the parallel and sequential loops bit-identical because
  # each iteration seeds its own RNG before calling the learner adapter.
  art_seed  <- NULL
  boot_seed <- NULL
  iter_seed_base <- NULL
  if (!is.null(random_state)) {
    set.seed(random_state)
    rng_seeds      <- sample.int(.Machine$integer.max, size = 3L)
    art_seed       <- rng_seeds[[1L]]
    boot_seed      <- rng_seeds[[2L]]
    iter_seed_base <- rng_seeds[[3L]]
  }

  # ---- Artificial features --------------------------------------------------
  n_injected        <- as.integer(floor(n_features * artificial_proportion))
  x_fit             <- x
  noise_col_indices <- NULL
  artificial_type_used <- NULL

  if (!is.null(artificial_type)) {
    if (n_injected < 1L) {
      stop(
        "`artificial_proportion` (= ", artificial_proportion,
        ") with n_features = ", n_features,
        " produces n_injected = ", n_injected,
        "; artificial features require at least one injected column.",
        call. = FALSE
      )
    }
    if (verbose) message("Generating artificial features (type=",
                         artificial_type, ")...")
    art_result        <- make_artificial_features(x, n_injected,
                                                  artificial_type, art_seed)
    x_fit             <- art_result$x_augmented
    noise_col_indices <- art_result$noise_col_indices
    artificial_type_used <- if (!is.null(art_result$type_used)) {
      art_result$type_used
    } else {
      artificial_type
    }
  }

  # ---- Sparse-group feature groups -----------------------------------------
  sgl_feature_groups <- .resolve_sgl_feature_groups(
    base_learner         = base_learner,
    x_original           = x,
    x_augmented          = x_fit,
    feature_groups       = feature_groups,
    corr_group_threshold = corr_group_threshold,
    noise_col_indices    = noise_col_indices
  )

  # ---- Learner adapter (batch: one model path call per bootstrap) -----------
  # Each batch adapter accepts the full lambda_grid and returns a logical
  # matrix (n_total_features × n_lambdas), reducing n_bootstraps × n_lambdas
  # glmnet calls to just n_bootstraps calls.
  batch_adapter <- switch(
    base_learner,
    lasso = .make_glmnet_batch_adapter(
      family              = family,
      alpha_fixed         = 1.0,
      bootstrap_threshold = bootstrap_threshold
    ),
    elastic_net = .make_glmnet_batch_adapter(
      family              = family,
      alpha_fixed         = NULL,
      bootstrap_threshold = bootstrap_threshold
    ),
    adaptive_lasso = .make_adaptive_lasso_batch_adapter(
      family              = family,
      gamma               = adaptive_gamma,
      epsilon             = adaptive_epsilon,
      bootstrap_threshold = bootstrap_threshold
    ),
    sparse_group_lasso = .make_sgl_batch_adapter(
      family              = family,
      feature_groups      = sgl_feature_groups,
      alpha_fixed         = NULL,
      bootstrap_threshold = bootstrap_threshold
    ),
    stop(
      "`base_learner` must be one of: \"lasso\", \"elastic_net\", \"adaptive_lasso\", \"sparse_group_lasso\".",
      call. = FALSE
    )
  )

  n_total_features <- ncol(x_fit)
  n_subsamples     <- as.integer(floor(sample_fraction * n_samples))

  if (n_subsamples < 1L) {
    stop(
      "`sample_fraction` (= ", sample_fraction, ") with n_samples = ",
      n_samples, " produces n_subsamples = ", n_subsamples,
      "; at least one row must be sampled.",
      call. = FALSE
    )
  }

  # Fix 7: reject impossible configuration before entering bootstrap
  if (!replace && n_subsamples > n_samples) {
    stop(
      "`sample_fraction` (= ", sample_fraction, ") implies n_subsamples = ",
      n_subsamples, " > n_samples = ", n_samples,
      " but `replace = FALSE`. Reduce `sample_fraction` or set `replace = TRUE`.",
      call. = FALSE
    )
  }

  # ---- Bootstrap index lists ------------------------------------------------
  if (!is.null(boot_seed)) set.seed(boot_seed)

  boot_sampler <- if (is.null(groups)) {
    function(.) classic_bootstrap_indices(y = y, n_subsamples = n_subsamples,
                                          replace = replace,
                                          strata = bootstrap_strata)
  } else {
    group_sampler <- .make_group_bootstrap_sampler(
      y = y,
      groups = groups,
      n_subsamples = n_subsamples,
      replace = replace,
      strata = bootstrap_strata
    )
    function(.) group_sampler()
  }
  boot_indices <- lapply(seq_len(n_bootstraps), boot_sampler)

  # ---- Per-iteration seeds for adapter calls (audit V-7) -------------------
  # Pre-generate one integer seed per bootstrap iteration so that the learner
  # adapter is reproducible and bit-identical across sequential and parallel
  # execution paths.
  iter_seeds <- if (!is.null(iter_seed_base)) {
    set.seed(iter_seed_base)
    sample.int(.Machine$integer.max, size = n_bootstraps)
  } else NULL

  # ---- Stability accumulation -----------------------------------------------
  stabl_scores_    <- matrix(0.0, nrow = n_features, ncol = n_lambdas,
                              dimnames = list(feat_names, NULL))
  stabl_scores_art <- if (!is.null(artificial_type)) {
    matrix(0.0, nrow = n_injected, ncol = n_lambdas)
  } else NULL

  art_rows <- if (!is.null(artificial_type)) {
    seq(n_features + 1L, n_features + n_injected)
  } else NULL

  if (verbose) message("Running STABL bootstrap loop (",
                       n_bootstraps, " bootstraps, ",
                       n_lambdas, " lambdas, 1 path call per bootstrap)...")

  # Bootstrap-outer loop: each iteration fits the full lambda path once.
  # With n_bootstraps iterations and n_lambdas lambdas, this replaces the
  # previous n_bootstraps × n_lambdas individual model calls.
  process_one_bootstrap <- function(i) {
    idx <- boot_indices[[i]]
    if (!is.null(iter_seeds)) {
      .with_local_seed(iter_seeds[[i]],
                       batch_adapter(x_fit[idx, , drop = FALSE], y[idx], lambda_grid))
    } else {
      batch_adapter(x_fit[idx, , drop = FALSE], y[idx], lambda_grid)
    }
  }

  if (workers > 1L && .future_backend_available()) {
    # Parallel path: must collect all results before accumulating.
    # `seed = TRUE` is preserved as a furrr safety guard for any RNG that
    # leaks outside our explicit `.with_local_seed`; the explicit per-iter
    # seed inside `process_one_bootstrap` is what actually pins the result.
    result_list <- .future_map_or_lapply(
      seq_along(boot_indices),
      process_one_bootstrap,
      workers = workers,
      seed = TRUE
    )
    for (r in result_list) {
      stabl_scores_ <- stabl_scores_ + r[seq_len(n_features), , drop = FALSE]
      if (!is.null(artificial_type)) {
        stabl_scores_art <- stabl_scores_art + r[art_rows, , drop = FALSE]
      }
    }
  } else {
    if (workers > 1L) {
      .warn_future_backend_unavailable()
    }
    # Sequential path: stream-accumulate one bootstrap at a time so we never
    # hold more than a single result matrix in memory (Fix 5).
    for (i in seq_along(boot_indices)) {
      r <- process_one_bootstrap(i)
      stabl_scores_ <- stabl_scores_ + r[seq_len(n_features), , drop = FALSE]
      if (!is.null(artificial_type)) {
        stabl_scores_art <- stabl_scores_art + r[art_rows, , drop = FALSE]
      }
    }
  }
  stabl_scores_ <- stabl_scores_ / n_bootstraps
  if (!is.null(artificial_type)) {
    stabl_scores_art <- stabl_scores_art / n_bootstraps
  }

  # ---- FDP+ control ---------------------------------------------------------
  fdp <- NULL
  if (!is.null(artificial_type)) {
    fdp <- compute_fdp_plus(
      stabl_scores            = stabl_scores_,
      stabl_scores_artificial = stabl_scores_art,
      artificial_proportion   = artificial_proportion,
      fdr_threshold_range     = fdr_threshold_range
    )
  }

  # ---- Assemble S3 result ---------------------------------------------------
  structure(
    list(
      stabl_scores_         = stabl_scores_,
      stabl_scores_artificial_ = stabl_scores_art,
      fitted_lambda_grid    = lambda_grid,
      family                = family,
      fdr_min_threshold_    = if (!is.null(fdp)) fdp$fdr_min_threshold else NULL,
      FDRs_                 = if (!is.null(fdp)) fdp$FDRs              else NULL,
      min_fdr_              = if (!is.null(fdp)) fdp$min_fdr            else NULL,
      fdrs_table_           = if (!is.null(fdp)) fdp$fdrs_table         else NULL,
      fdr_threshold_range   = fdr_threshold_range,
      hard_threshold        = hard_threshold,
      artificial_type       = artificial_type,
      artificial_type_used_ = artificial_type_used,
      artificial_proportion = artificial_proportion,
      bootstrap_threshold   = bootstrap_threshold,
      stratify_bootstrap    = !is.null(bootstrap_strata_ids),
      bootstrap_strata_levels = if (!is.null(bootstrap_strata_ids)) {
        sort(unique(as.character(bootstrap_strata_ids)))
      } else NULL,
      explore               = explore,
      n_explore             = as.integer(n_explore),
      feature_names         = feat_names,
      n_features_in_        = n_features
    ),
    class = "stabl_fit"
  )
}

.validate_stabl_family <- function(family) {
  supported <- c("gaussian", "binomial", "multinomial", "poisson", "cox")
  if (!is.character(family) || length(family) != 1L ||
      is.na(family) || !(family %in% supported)) {
    stop(
      "`family` must be one of: \"gaussian\", \"binomial\", ",
      "\"multinomial\", \"poisson\", or \"cox\".",
      call. = FALSE
    )
  }
  family
}

# ---- Internal param validator ------------------------------------------------
.validate_stabl_params <- function(n_bootstraps, sample_fraction, replace,
                                   hard_threshold, artificial_type,
                                   artificial_proportion,
                                   stratify_bootstrap,
                                   bootstrap_threshold) {
  if (!is.numeric(n_bootstraps) || length(n_bootstraps) != 1L ||
      n_bootstraps < 1L) {
    stop("`n_bootstraps` must be a positive integer.", call. = FALSE)
  }
  if (!is.numeric(sample_fraction) || length(sample_fraction) != 1L ||
      sample_fraction <= 0) {
    stop("`sample_fraction` must be a positive numeric.", call. = FALSE)
  }
  if (!is.logical(replace) || length(replace) != 1L || is.na(replace)) {
    stop("`replace` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!is.logical(stratify_bootstrap) || length(stratify_bootstrap) != 1L ||
      is.na(stratify_bootstrap)) {
    stop("`stratify_bootstrap` must be TRUE or FALSE.", call. = FALSE)
  }
  if (!replace && sample_fraction > 1) {
    stop(
      "`sample_fraction` cannot exceed 1 when `replace = FALSE`.",
      call. = FALSE
    )
  }
  if (!is.null(hard_threshold)) {
    if (!is.numeric(hard_threshold) || hard_threshold <= 0 ||
        hard_threshold > 1) {
      stop("`hard_threshold` must be a numeric in (0, 1].", call. = FALSE)
    }
  }
  if (is.null(hard_threshold) && is.null(artificial_type)) {
    stop(
      "Either `hard_threshold` or `artificial_type` must be specified.",
      call. = FALSE
    )
  }
  if (!is.null(artificial_type) &&
      (artificial_proportion <= 0 || artificial_proportion > 1)) {
    stop("`artificial_proportion` must be in (0, 1].", call. = FALSE)
  }
  .validate_bootstrap_threshold(bootstrap_threshold)
  invisible(NULL)
}

.resolve_sgl_feature_groups <- function(base_learner,
                                        x_original,
                                        x_augmented,
                                        feature_groups,
                                        corr_group_threshold,
                                        noise_col_indices) {
  if (base_learner != "sparse_group_lasso") {
    return(NULL)
  }

  has_explicit <- !is.null(feature_groups)
  has_corr <- !is.null(corr_group_threshold)

  if (has_explicit && has_corr) {
    stop(
      "For `base_learner = \"sparse_group_lasso\"`, provide either `feature_groups` or `corr_group_threshold`, not both.",
      call. = FALSE
    )
  }
  if (!has_explicit && !has_corr) {
    stop(
      "For `base_learner = \"sparse_group_lasso\"`, provide `feature_groups` or `corr_group_threshold`.",
      call. = FALSE
    )
  }

  if (has_explicit) {
    grp <- as.integer(as.factor(feature_groups))
    if (length(grp) != ncol(x_original)) {
      stop("`feature_groups` must have length ncol(x).", call. = FALSE)
    }
    if (anyNA(grp)) {
      stop("`feature_groups` cannot contain NA values.", call. = FALSE)
    }
  } else {
    grp <- .build_corr_groups(x_original, corr_group_threshold)
  }

  .append_noise_groups(grp, noise_col_indices, ncol(x_augmented))
}

.build_corr_groups <- function(x, percentile) {
  if (!is.numeric(percentile) || length(percentile) != 1L ||
      percentile <= 0 || percentile > 100) {
    stop("`corr_group_threshold` must be a numeric scalar in (0, 100].", call. = FALSE)
  }

  p <- ncol(x)
  if (p <= 1L) {
    return(rep.int(1L, p))
  }

  corr <- suppressWarnings(stats::cor(x, use = "pairwise.complete.obs"))
  corr[is.na(corr)] <- 0
  corr_vals <- corr[upper.tri(corr, diag = FALSE)]
  # Subtract 0.1 to match Python reference: threshold = np.percentile(corr_val, perc) - 0.1
  # (stabl/stabl.py line 1142).  Without the offset the R port uses a stricter
  # threshold than Python, producing fewer correlation groups than expected.
  cutoff <- as.numeric(stats::quantile(corr_vals, probs = percentile / 100,
                                       names = FALSE, na.rm = TRUE)) - 0.1

  .corr_groups_from_corr(corr, cutoff)
}

.corr_groups_from_corr <- function(corr, cutoff) {
  if (exists("corr_groups_from_corr_cpp", mode = "function")) {
    return(corr_groups_from_corr_cpp(corr, cutoff))
  }
  .corr_groups_from_corr_r(corr, cutoff)
}

.corr_groups_from_corr_r <- function(corr, cutoff) {
  p <- ncol(corr)
  parent <- seq_len(p)
  find_root <- function(i) {
    while (parent[[i]] != i) {
      parent[[i]] <<- parent[[parent[[i]]]]
      i <- parent[[i]]
    }
    i
  }
  union_nodes <- function(i, j) {
    ri <- find_root(i)
    rj <- find_root(j)
    if (ri != rj) parent[[rj]] <<- ri
  }

  if (p > 1L) {
    for (j in seq.int(2L, p)) {
      hits <- which(corr[seq_len(j - 1L), j] > cutoff)
      if (length(hits) > 0L) {
        for (i in hits) {
          union_nodes(i, j)
        }
      }
    }
  }

  roots <- vapply(seq_len(p), find_root, integer(1L))
  as.integer(as.factor(roots))
}

.append_noise_groups <- function(groups, noise_col_indices, total_p) {
  if (is.null(noise_col_indices)) {
    return(groups)
  }

  n_groups <- length(groups)
  out <- integer(n_groups + length(noise_col_indices))
  out[seq_len(n_groups)] <- as.integer(groups)
  next_gid <- max(out[seq_len(n_groups)])
  for (i in seq_along(noise_col_indices)) {
    src <- noise_col_indices[[i]]
    src <- as.integer(src)
    out_pos <- n_groups + i
    if (!is.na(src) && src >= 1L && src <= length(groups)) {
      out[[out_pos]] <- groups[[src]]
    } else {
      next_gid <- next_gid + 1L
      out[[out_pos]] <- next_gid
    }
  }

  if (length(out) != total_p) {
    stop("Sparse-group feature-group construction failed due to length mismatch.", call. = FALSE)
  }

  out
}

# Internal: scoped seed helper.  Saves & restores `.Random.seed` so that the
# wrapped expression has its own deterministic RNG state without polluting the
# caller's RNG.  Used by `stabl_fit()` to make per-bootstrap learner calls
# reproducible regardless of sequential vs parallel execution (audit V-7).
.with_local_seed <- function(seed, expr) {
  has_old <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (has_old) {
    old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", old, envir = globalenv()), add = TRUE)
  } else {
    on.exit(
      if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
        rm(".Random.seed", envir = globalenv())
      },
      add = TRUE
    )
  }
  set.seed(seed)
  expr
}
