#' Build a glmnet Learner Adapter
#'
#' Returns a closure that fits a `glmnet` model on a single bootstrap
#' subsample and returns a logical selection mask over the features.  The
#' closure mirrors the role of `fit_bootstrapped_sample()` in the Python STABL
#' library.
#'
#' Learner adapters decouple the modelling back-end from the STABL bootstrap
#' loop, making it easy to substitute different penalised-regression solvers
#' without changing the stability-accumulation logic.  This factory produces
#' the standard lasso / elastic-net adapter that is the default back-end for
#' [stabl_fit()].
#'
#' The returned function accepts a pre-expanded lambda-grid row (a 1-row
#' `data.frame`) and applies `glmnet` at that exact penalty value.  The
#' `alpha` elastic-net mixing parameter is resolved in priority order:
#' `alpha_fixed` argument > `alpha` column in `lambda_val` > default of 1
#' (pure lasso).
#'
#' @details
#' This adapter factory is primarily an internal backend used by [stabl_fit()].
#' Most users should configure `base_learner`, `family`, and `lambda_grid`
#' directly in [stabl_fit()] rather than calling this factory manually.
#'
#' @param family Character; the `glmnet` response family, for example
#'   `"gaussian"`, `"binomial"`, `"multinomial"`, or `"cox"`.
#' @param alpha_fixed Numeric scalar or `NULL`.  When not `NULL`, this value
#'   overrides any `alpha` column in `lambda_val`.
#' @param bootstrap_threshold Numeric scalar, character string, or `NULL`;
#'   per-bootstrap feature-selection cutoff applied to absolute coefficients.
#'   Numeric thresholds keep features with `|coef| >= bootstrap_threshold`.
#'   Strings may be `"mean"`, `"median"`, or scaled forms such as
#'   `"1.25*mean"`, matching sklearn `SelectFromModel` threshold syntax.
#'   `NULL` resolves to the upstream STABL l1 default of `1e-5`.
#'
#' @return A function with signature
#'   `function(x, y, lambda_val) -> logical vector of length ncol(x)`
#'   for use inside [stabl_fit()].
#'
#' @seealso [make_adaptive_lasso_adapter()], [make_sgl_adapter()],
#'   [stabl_fit()]
#' @export
make_glmnet_adapter <- function(
    family              = "gaussian",
    alpha_fixed         = NULL,
    bootstrap_threshold = 1e-5
) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop(
      "Package 'glmnet' is required. ",
      "Install it with: install.packages(\"glmnet\")",
      call. = FALSE
    )
  }
  .validate_bootstrap_threshold(bootstrap_threshold)

  function(x, y, lambda_val) {
    alpha_use <- if (!is.null(alpha_fixed)) {
      alpha_fixed
    } else if ("alpha" %in% names(lambda_val)) {
      lambda_val[["alpha"]]
    } else {
      1.0
    }

    lambda_use <- lambda_val[["lambda"]]

    fit <- glmnet::glmnet(
      x = x,
      y = y,
      family = family,
      alpha = alpha_use,
      lambda = lambda_use
    )
    .selected_by_bootstrap_threshold(
      .feature_abs_coefs(fit = fit, s = lambda_use, family = family),
      bootstrap_threshold
    )
  }
}

#' Build an Adaptive Lasso Learner Adapter
#'
#' Returns a closure that computes feature-specific penalty weights from a
#' ridge initialisation on each bootstrap subsample, then fits a lasso model
#' with those `penalty.factor` values to obtain the selected-feature mask.
#'
#' Adaptive lasso improves on standard lasso by assigning stronger penalties
#' to features with small initial coefficients (likely noise) and weaker
#' penalties to features with large initial coefficients (likely signal).
#' This asymmetric penalisation achieves the oracle property under regularity
#' conditions, selecting the true support more reliably than plain lasso when
#' signal features have moderate to large effect sizes.
#'
#' Weights are defined as:
#' \deqn{w_j = 1 / (|\hat\beta_j^{\mathrm{init}}| + \epsilon)^\gamma}
#' where \eqn{\hat\beta_j^{\mathrm{init}}} comes from a ridge regression on
#' the same bootstrap subsample.  The `epsilon` floor avoids division by zero
#' for features with near-zero ridge coefficients.
#'
#' @details
#' This adapter factory is primarily an internal backend used by [stabl_fit()].
#' For end-to-end feature selection workflows, prefer
#' `base_learner = "adaptive_lasso"` in [stabl_fit()].
#'
#' @param family Character; the `glmnet` response family, for example
#'   `"gaussian"`, `"binomial"`, `"multinomial"`, or `"cox"`.
#' @param gamma Positive numeric scalar; controls how sharply the weights
#'   down-penalise features with large ridge coefficients.  Larger values
#'   make the penalty more selective.  Default `1.0` matches the Python
#'   reference implementation.
#' @param epsilon Positive numeric scalar; added to the denominator of the
#'   weight to avoid division by zero.  Default `1e-6`.
#' @param bootstrap_threshold Numeric scalar, character string, or `NULL`;
#'   per-bootstrap feature-selection cutoff applied to absolute coefficients.
#'   Numeric thresholds keep features with `|coef| >= bootstrap_threshold`.
#'   Strings may be `"mean"`, `"median"`, or scaled forms such as
#'   `"1.25*mean"`, matching sklearn `SelectFromModel` threshold syntax.
#'   `NULL` resolves to the upstream STABL l1 default of `1e-5`.
#'
#' @return A function with signature
#'   `function(x, y, lambda_val) -> logical vector of length ncol(x)`.
#'
#' @seealso [make_glmnet_adapter()], [make_sgl_adapter()], [stabl_fit()]
#' @export
make_adaptive_lasso_adapter <- function(
    family              = "gaussian",
    gamma               = 1.0,
    epsilon             = 1e-6,
    bootstrap_threshold = 1e-5
) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop(
      "Package 'glmnet' is required. ",
      "Install it with: install.packages(\"glmnet\")",
      call. = FALSE
    )
  }
  if (!is.numeric(gamma) || length(gamma) != 1L || gamma <= 0) {
    stop("`gamma` must be a positive numeric scalar.", call. = FALSE)
  }
  if (!is.numeric(epsilon) || length(epsilon) != 1L || epsilon <= 0) {
    stop("`epsilon` must be a positive numeric scalar.", call. = FALSE)
  }
  .validate_bootstrap_threshold(bootstrap_threshold)

  function(x, y, lambda_val) {
    lambda_use <- lambda_val[["lambda"]]

    # Ridge initialization for adaptive weights.
    init_fit <- glmnet::glmnet(
      x = x,
      y = y,
      family = family,
      alpha = 0,
      nlambda = 30L
    )
    init_lambda <- tail(init_fit$lambda, n = 1L)
    init_scores <- .feature_abs_coefs(fit = init_fit, s = init_lambda,
                      family = family)
    penalty_factor <- 1 / ((init_scores + epsilon) ^ gamma)

    fit <- glmnet::glmnet(
      x = x,
      y = y,
      family = family,
      alpha = 1,
      lambda = lambda_use,
      penalty.factor = penalty_factor
    )
    .selected_by_bootstrap_threshold(
      .feature_abs_coefs(fit = fit, s = lambda_use, family = family),
      bootstrap_threshold
    )
  }
}

#' Build a Sparse Group Lasso Learner Adapter
#'
#' Returns a closure that fits `sparsegl::sparsegl()` on a single bootstrap
#' subsample and returns a logical selection mask over the features.
#'
#' Sparse-group lasso is useful when features have a known (or inferred) block
#' structure, for example gene pathways, omic layers, or correlated feature
#' clusters.  It imposes simultaneous sparsity within and between groups: the
#' group-level penalty encourages whole groups to be zeroed out, while the
#' within-group lasso penalty allows groups to have only a sparse subset of
#' active features.  This can substantially improve stability in structured
#' high-dimensional settings.
#'
#' The `alpha` value (`asparse` in `sparsegl`) controls the balance between
#' the within-group lasso penalty and the group-level penalty: 0 = pure group
#' lasso; 1 = pure lasso (no group penalty).  The default of `0.05` used when
#' no `alpha` column is present matches the Python STABL reference.
#'
#' @details
#' This adapter factory is primarily an internal backend used by [stabl_fit()].
#' For end-to-end feature selection workflows, prefer
#' `base_learner = "sparse_group_lasso"` in [stabl_fit()] and provide
#' `feature_groups` (or `corr_group_threshold`) there.
#'
#' @param family Character; response family (`"gaussian"`, `"binomial"`, or
#'   `"multinomial"`).  Cox regression is not supported by `sparsegl`.
#' @param feature_groups Integer or factor vector of length `p` (number of
#'   features) assigning each feature to a group.  Values are coerced via
#'   `as.integer(as.factor(...))`, so any type that has a natural ordering is
#'   accepted.
#' @param alpha_fixed Numeric scalar in `[0, 1]` or `NULL`.  When not `NULL`,
#'   overrides any `alpha` column in `lambda_val`.  Controls the lasso /
#'   group-lasso mixing weight (`asparse` in `sparsegl`).
#' @param bootstrap_threshold Numeric scalar, character string, or `NULL`;
#'   per-bootstrap feature-selection cutoff applied to absolute coefficients.
#'   Numeric thresholds keep features with `|coef| >= bootstrap_threshold`.
#'   Strings may be `"mean"`, `"median"`, or scaled forms such as
#'   `"1.25*mean"`, matching sklearn `SelectFromModel` threshold syntax.
#'   `NULL` resolves to the upstream STABL l1 default of `1e-5`.
#'
#' @return A function with signature
#'   `function(x, y, lambda_val) -> logical vector of length ncol(x)`.
#'
#' @seealso [make_glmnet_adapter()], [make_adaptive_lasso_adapter()],
#'   [stabl_fit()]
#' @export
make_sgl_adapter <- function(
    family              = "gaussian",
    feature_groups,
    alpha_fixed         = NULL,
    bootstrap_threshold = 1e-5
) {
  if (!requireNamespace("sparsegl", quietly = TRUE)) {
    stop(
      "Package 'sparsegl' is required for base_learner = \"sparse_group_lasso\". ",
      "Install it with: install.packages(\"sparsegl\")",
      call. = FALSE
    )
  }
  if (identical(family, "cox")) {
    stop(
      "Cox family is not supported by sparse_group_lasso. ",
      "Use base_learner = \"lasso\" or \"adaptive_lasso\" with family = \"cox\".",
      call. = FALSE
    )
  }
  if (missing(feature_groups) || is.null(feature_groups)) {
    stop("`feature_groups` must be provided for sparse group lasso.", call. = FALSE)
  }

  groups <- as.integer(as.factor(feature_groups))
  if (length(groups) == 0L) {
    stop("`feature_groups` cannot be empty.", call. = FALSE)
  }
  if (anyNA(groups)) {
    stop("`feature_groups` cannot contain NA values.", call. = FALSE)
  }
  if (!is.null(alpha_fixed) &&
      (!is.numeric(alpha_fixed) || length(alpha_fixed) != 1L ||
       alpha_fixed < 0 || alpha_fixed > 1)) {
    stop("`alpha_fixed` must be NULL or a numeric scalar in [0, 1].", call. = FALSE)
  }
  .validate_bootstrap_threshold(bootstrap_threshold)

  .resolve_asparse <- function(lambda_val) {
    if (!is.null(alpha_fixed)) {
      return(as.numeric(alpha_fixed))
    }
    if ("alpha" %in% names(lambda_val)) {
      alpha_val <- as.numeric(lambda_val[["alpha"]])
      if (length(alpha_val) != 1L || is.na(alpha_val) ||
          alpha_val < 0 || alpha_val > 1) {
        stop("`alpha` in `lambda_val` must be in [0, 1] for sparse_group_lasso.", call. = FALSE)
      }
      return(alpha_val)
    }
    0.05
  }

  function(x, y, lambda_val) {
    if (length(groups) != ncol(x)) {
      stop("`feature_groups` length must match ncol(x) for sparse_group_lasso.", call. = FALSE)
    }

    lambda_use  <- as.numeric(lambda_val[["lambda"]])
    asparse_use <- .resolve_asparse(lambda_val)

    # sparsegl requires features sorted by group (non-decreasing group index).
    sort_ord <- order(groups)
    inv_ord  <- order(sort_ord)
    x_s      <- x[, sort_ord, drop = FALSE]
    grp_s    <- groups[sort_ord]

    if (family == "multinomial") {
      if (!is.factor(y)) {
        y <- factor(y)
      }
      levs <- levels(y)
      if (length(levs) < 2L) {
        stop("Multinomial sparse-group fitting requires at least 2 classes.", call. = FALSE)
      }

      coef_mat <- matrix(0, nrow = ncol(x), ncol = length(levs))
      for (k in seq_along(levs)) {
        yk <- as.integer(y == levs[[k]])
        fit_k <- sparsegl::sparsegl(
          x = x_s,
          y = yk,
          group = grp_s,
          family = "binomial",
          lambda = lambda_use,
          asparse = asparse_use
        )
        coef_mat[, k] <- .feature_abs_coefs_sparsegl(fit_k, s = lambda_use)[inv_ord]
      }
      return(.selected_by_bootstrap_threshold(
        apply(coef_mat, 1L, max),
        bootstrap_threshold
      ))
    }

    fit <- sparsegl::sparsegl(
      x = x_s,
      y = y,
      group = grp_s,
      family = family,
      lambda = lambda_use,
      asparse = asparse_use
    )
    .selected_by_bootstrap_threshold(
      .feature_abs_coefs_sparsegl(fit, s = lambda_use)[inv_ord],
      bootstrap_threshold
    )
  }
}

#' Build a Data-Driven Lambda Grid
#'
#' Returns a Python STABL-compatible penalty sequence as a pre-expanded
#' `data.frame` suitable for use as the `lambda_grid` argument of
#' [stabl_fit()].  Gaussian, binomial, and multinomial families use the
#' upstream Python auto-mode formulas translated to glmnet's `lambda` scale.
#' Cox remains on glmnet's native path because upstream Python STABL has no Cox
#' backend.
#'
#' For Gaussian outcomes, the path follows Python's
#' `||X'Y||_inf / (n * l1_ratio)` scale and returns
#' `geomspace(lambda_max / 30, lambda_max + 5, n_lambda)`.  For classification,
#' R approximates Python's `sklearn.svm.l1_min_c()` grid, converts the resulting
#' `C` path to glmnet-style `lambda = 1 / C`, and returns that decreasing
#' penalty sequence.
#'
#' For elastic-net models, supplying a vector of `l1_ratio` values causes the
#' function to fit a separate path per alpha, row-bind the resulting grids,
#' and add an `alpha` column so that [make_glmnet_adapter()] can dispatch
#' correctly.  This mirrors `auto_mode_lambda_grid()` in the Python reference
#' implementation.
#'
#' @param x Numeric matrix of predictors (samples by features).
#' @param y Outcome vector.  For `"gaussian"` provide a numeric vector; for
#'   `"binomial"`/`"multinomial"` provide a factor or 0/1 integer vector;
#'   for `"cox"` provide a `survival::Surv` object.
#' @param family Character; `glmnet` response family (`"gaussian"`,
#'   `"binomial"`, `"multinomial"`, or `"cox"`).  Default `"gaussian"`.
#' @param n_lambda Positive integer; desired number of lambda values per alpha
#'   level.  Actual length may be slightly shorter if `glmnet` detects
#'   saturation early.  Default `30L`.
#' @param l1_ratio Numeric scalar, numeric vector, or `NULL`.  When `NULL`
#'   (default), a pure lasso path (alpha = 1) is used.  When a vector is
#'   supplied (e.g. `c(0.5, 0.75, 1.0)`), one path is fitted per value and
#'   the results are combined; an `alpha` column is added to the output.
#'
#' @return A `data.frame` with at least a `lambda` column.  An `alpha` column
#'   is included whenever `l1_ratio` is not `NULL`.
#'
#' @seealso [stabl_fit()] which calls this automatically when
#'   `lambda_grid = "auto"`.
#' @export
auto_lambda_grid <- function(
    x,
    y,
    family   = "gaussian",
    n_lambda = 30L,
    l1_ratio = NULL
) {
  if (!is.numeric(n_lambda) || length(n_lambda) != 1L ||
      is.na(n_lambda) || n_lambda < 1L) {
    stop("`n_lambda` must be a positive integer.", call. = FALSE)
  }
  n_lambda <- as.integer(n_lambda)

  alphas <- if (is.null(l1_ratio)) 1.0 else as.numeric(l1_ratio)
  add_alpha <- !is.null(l1_ratio)
  if (anyNA(alphas) || any(!is.finite(alphas)) || any(alphas <= 0)) {
    stop("`l1_ratio` must contain positive finite values.", call. = FALSE)
  }

  grids <- vector("list", length(alphas))
  for (i in seq_along(alphas)) {
    lam_seq <- switch(
      family,
      gaussian = .python_regression_lambda_grid(
        x = x,
        y = y,
        l1_ratio = alphas[[i]],
        n_lambda = n_lambda
      ),
      binomial = .python_classification_lambda_grid(
        x = x,
        y = y,
        l1_ratio = alphas[[i]],
        n_lambda = n_lambda
      ),
      multinomial = .python_classification_lambda_grid(
        x = x,
        y = y,
        l1_ratio = alphas[[i]],
        n_lambda = n_lambda
      ),
      .glmnet_auto_lambda_sequence(
        x = x,
        y = y,
        family = family,
        alpha = alphas[[i]],
        n_lambda = n_lambda
      )
    )
    grids[[i]] <- if (add_alpha) {
      data.frame(alpha = alphas[[i]], lambda = lam_seq)
    } else {
      data.frame(lambda = lam_seq)
    }
  }

  do.call(rbind, grids)
}

.python_regression_lambda_grid <- function(x, y, l1_ratio, n_lambda) {
  x <- as.matrix(x)
  y <- as.numeric(y)
  lambda_max <- max(abs(as.numeric(crossprod(x, y)))) / (nrow(x) * l1_ratio)
  lambda_max <- .positive_lambda_scale(lambda_max)
  .geomspace(lambda_max / 30, lambda_max + 5, n_lambda)
}

.python_classification_lambda_grid <- function(x, y, l1_ratio, n_lambda) {
  x <- as.matrix(x)
  y_factor <- factor(y)
  if (nlevels(y_factor) < 2L) {
    stop("Classification auto lambda grid requires at least two outcome classes.",
         call. = FALSE)
  }

  indicator <- stats::model.matrix(~ y_factor - 1)
  residual <- sweep(indicator, 2L, colMeans(indicator), "-")
  lambda_max <- max(abs(as.matrix(crossprod(x, residual)))) /
    (nrow(x) * l1_ratio)
  lambda_max <- .positive_lambda_scale(lambda_max)

  # Python uses an increasing C grid from C_min to 100 * C_min.  glmnet consumes
  # lambda, the inverse regularization scale, so return the decreasing 1 / C path.
  c_min <- 1.0 / lambda_max
  c_grid <- seq(c_min, c_min * 100, length.out = n_lambda)
  1.0 / c_grid
}

.glmnet_auto_lambda_sequence <- function(x, y, family, alpha, n_lambda) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop(
      "Package 'glmnet' is required. ",
      "Install it with: install.packages(\"glmnet\")",
      call. = FALSE
    )
  }
  fit_tmp <- glmnet::glmnet(
    x = x,
    y = y,
    family = family,
    alpha = alpha,
    nlambda = n_lambda
  )
  fit_tmp$lambda
}

.positive_lambda_scale <- function(x) {
  if (!is.finite(x) || x <= 0) {
    return(.Machine$double.eps)
  }
  x
}

.geomspace <- function(from, to, length.out) {
  exp(seq(log(from), log(to), length.out = length.out))
}

.feature_abs_coefs <- function(fit, s, family = "gaussian") {
  coef_obj <- glmnet::coef.glmnet(fit, s = s)
  row_sel <- if (family == "cox") TRUE else -1L

  if (inherits(coef_obj, "dgCMatrix")) {
    return(abs(as.numeric(coef_obj[row_sel, 1L])))
  }
  if (is.matrix(coef_obj)) {
    return(abs(as.numeric(coef_obj[row_sel, 1L])))
  }
  if (is.list(coef_obj)) {
    mats <- lapply(coef_obj, function(m) as.numeric(m[row_sel, 1L]))
    coef_mat <- do.call(cbind, mats)
    return(apply(abs(coef_mat), 1L, max))
  }

  stop("Unsupported coefficient structure returned by glmnet.", call. = FALSE)
}

.feature_abs_coefs_sparsegl <- function(fit, s) {
  coef_obj <- stats::coef(fit, s = s)

  if (inherits(coef_obj, "dgCMatrix")) {
    return(abs(as.numeric(coef_obj[-1L, 1L])))
  }
  if (is.matrix(coef_obj)) {
    return(abs(as.numeric(coef_obj[-1L, 1L])))
  }

  stop("Unsupported coefficient structure returned by sparsegl.", call. = FALSE)
}

.validate_bootstrap_threshold <- function(bootstrap_threshold) {
  if (is.null(bootstrap_threshold)) {
    return(invisible(NULL))
  }

  if (is.numeric(bootstrap_threshold) &&
      length(bootstrap_threshold) == 1L &&
      !is.na(bootstrap_threshold) &&
      is.finite(bootstrap_threshold) &&
      bootstrap_threshold >= 0) {
    return(invisible(NULL))
  }

  if (is.character(bootstrap_threshold) &&
      length(bootstrap_threshold) == 1L &&
      !is.na(bootstrap_threshold) &&
      !is.null(.parse_bootstrap_threshold(bootstrap_threshold))) {
    return(invisible(NULL))
  }

  stop(
    "`bootstrap_threshold` must be NULL, a non-negative numeric scalar, ",
    "or a string of the form \"mean\", \"median\", \"1.25*mean\", ",
    "or \"1.25*median\".",
    call. = FALSE
  )
}

.parse_bootstrap_threshold <- function(bootstrap_threshold) {
  threshold <- gsub("\\s+", "", bootstrap_threshold)
  if (threshold %in% c("mean", "median")) {
    return(list(scale = 1.0, stat = threshold))
  }

  pieces <- strsplit(threshold, "\\*")[[1L]]
  if (length(pieces) != 2L || !(pieces[[2L]] %in% c("mean", "median"))) {
    return(NULL)
  }

  scale <- suppressWarnings(as.numeric(pieces[[1L]]))
  if (is.na(scale) || !is.finite(scale) || scale < 0) {
    return(NULL)
  }

  list(scale = scale, stat = pieces[[2L]])
}

.resolve_bootstrap_threshold <- function(importances, bootstrap_threshold) {
  if (is.null(bootstrap_threshold)) {
    return(1e-5)
  }
  if (is.numeric(bootstrap_threshold)) {
    return(as.numeric(bootstrap_threshold))
  }

  spec <- .parse_bootstrap_threshold(bootstrap_threshold)
  stat_fun <- switch(
    spec$stat,
    mean   = mean,
    median = stats::median
  )

  if (is.matrix(importances)) {
    return(spec$scale * as.numeric(apply(importances, 2L, stat_fun)))
  }
  spec$scale * as.numeric(stat_fun(importances))
}

.selected_by_bootstrap_threshold <- function(importances, bootstrap_threshold) {
  .validate_bootstrap_threshold(bootstrap_threshold)
  threshold <- .resolve_bootstrap_threshold(importances, bootstrap_threshold)

  if (is.matrix(importances) && length(threshold) > 1L) {
    threshold_mat <- matrix(
      rep(threshold, each = nrow(importances)),
      nrow = nrow(importances),
      ncol = ncol(importances)
    )
    return(importances >= threshold_mat)
  }

  importances >= threshold
}

# ---- Batch coefficient extraction helpers ------------------------------------
# These extract coefficients for ALL lambdas in one call, returning a
# (p × n_lambda) numeric matrix of absolute coefficient values.

.feature_abs_coefs_batch <- function(fit, lambda_seq, family = "gaussian") {
  coef_obj <- tryCatch(
    glmnet::coef.glmnet(fit, s = lambda_seq),
    error = function(e) NULL
  )
  out <- if (!is.null(coef_obj)) {
    tryCatch(
      .coerce_feature_abs_coefs_batch(coef_obj, family = family),
      error = function(e) NULL
    )
  } else {
    NULL
  }
  if (!is.null(out) && is.matrix(out) && ncol(out) == length(lambda_seq)) {
    return(out)
  }

  .feature_abs_coefs_batch_fallback(fit, lambda_seq, family = family)
}

.feature_abs_coefs_sparsegl_batch <- function(fit, lambda_seq) {
  coef_obj <- tryCatch(
    stats::coef(fit, s = lambda_seq),
    error = function(e) NULL
  )
  out <- if (!is.null(coef_obj)) {
    tryCatch(
      .coerce_sparsegl_abs_coefs_batch(coef_obj),
      error = function(e) NULL
    )
  } else {
    NULL
  }
  if (!is.null(out) && is.matrix(out) && ncol(out) == length(lambda_seq)) {
    return(out)
  }

  .feature_abs_coefs_sparsegl_batch_fallback(fit, lambda_seq)
}

.feature_abs_coefs_batch_fallback <- function(fit, lambda_seq, family = "gaussian") {
  col_list <- lapply(lambda_seq, function(s) {
    .feature_abs_coefs(fit = fit, s = s, family = family)
  })
  do.call(cbind, col_list)
}

.feature_abs_coefs_sparsegl_batch_fallback <- function(fit, lambda_seq) {
  col_list <- lapply(lambda_seq, function(s) {
    .feature_abs_coefs_sparsegl(fit = fit, s = s)
  })
  do.call(cbind, col_list)
}

.coerce_feature_abs_coefs_batch <- function(coef_obj, family = "gaussian") {
  row_sel <- if (family == "cox") TRUE else -1L

  if (inherits(coef_obj, "dgCMatrix") || is.matrix(coef_obj)) {
    return(abs(as.matrix(coef_obj[row_sel, , drop = FALSE])))
  }
  if (is.list(coef_obj)) {
    mats <- lapply(coef_obj, function(m) {
      abs(as.matrix(m[row_sel, , drop = FALSE]))
    })
    if (length(mats) == 0L) {
      stop("Empty coefficient list returned by glmnet.", call. = FALSE)
    }
    dims <- lapply(mats, dim)
    if (!all(vapply(dims[-1L], identical, logical(1L), dims[[1L]]))) {
      stop("Inconsistent coefficient shapes returned by glmnet.", call. = FALSE)
    }
    out <- mats[[1L]]
    if (length(mats) > 1L) {
      for (i in seq.int(2L, length(mats))) {
        out <- pmax(out, mats[[i]])
      }
    }
    return(out)
  }

  stop("Unsupported coefficient structure returned by glmnet.", call. = FALSE)
}

.coerce_sparsegl_abs_coefs_batch <- function(coef_obj) {
  if (inherits(coef_obj, "dgCMatrix") || is.matrix(coef_obj)) {
    return(abs(as.matrix(coef_obj[-1L, , drop = FALSE])))
  }

  stop("Unsupported coefficient structure returned by sparsegl.", call. = FALSE)
}

# ---- Internal batch adapters -------------------------------------------------
# Each factory returns a function with signature:
#   function(x, y, lambda_grid) -> logical matrix (n_features × n_lambdas)
#
# By fitting the full lambda path in one glmnet/sparsegl call per bootstrap
# (instead of one call per lambda), the bootstrap loop in stabl_fit() reduces
# from n_bootstraps × n_lambdas model fits to just n_bootstraps fits.

.make_glmnet_batch_adapter <- function(family, alpha_fixed, bootstrap_threshold) {
  .validate_bootstrap_threshold(bootstrap_threshold)
  feature_abs_coefs_batch <- .feature_abs_coefs_batch
  `.coerce_feature_abs_coefs_batch` <- .coerce_feature_abs_coefs_batch
  `.feature_abs_coefs_batch_fallback` <- .feature_abs_coefs_batch_fallback
  `.feature_abs_coefs` <- .feature_abs_coefs
  environment(feature_abs_coefs_batch) <- environment()
  selected_by_bootstrap_threshold <- .selected_by_bootstrap_threshold
  `.validate_bootstrap_threshold` <- .validate_bootstrap_threshold
  `.resolve_bootstrap_threshold` <- .resolve_bootstrap_threshold
  `.parse_bootstrap_threshold` <- .parse_bootstrap_threshold
  environment(selected_by_bootstrap_threshold) <- environment()

  function(x, y, lambda_grid) {
    n_lambdas  <- nrow(lambda_grid)
    n_features <- ncol(x)
    result     <- matrix(FALSE, nrow = n_features, ncol = n_lambdas)

    has_alpha_col <- "alpha" %in% names(lambda_grid)

    if (!is.null(alpha_fixed)) {
      # Lasso or fixed-alpha enet: single path call
      lambda_seq    <- lambda_grid[["lambda"]]
      fit           <- glmnet::glmnet(x, y, family = family, alpha = alpha_fixed,
                                      lambda = sort(lambda_seq, decreasing = TRUE))
      coef_mat      <- feature_abs_coefs_batch(fit, lambda_seq, family = family)
      result        <- selected_by_bootstrap_threshold(coef_mat, bootstrap_threshold)

    } else if (has_alpha_col) {
      # Elastic net with varying alpha: one path call per unique alpha
      unique_alphas <- unique(lambda_grid[["alpha"]])
      for (a in unique_alphas) {
        row_idx       <- which(lambda_grid[["alpha"]] == a)
        lambda_seq    <- lambda_grid[["lambda"]][row_idx]
        fit           <- glmnet::glmnet(x, y, family = family, alpha = a,
                                        lambda = sort(lambda_seq, decreasing = TRUE))
        coef_mat      <- feature_abs_coefs_batch(fit, lambda_seq, family = family)
        result[, row_idx] <- selected_by_bootstrap_threshold(coef_mat, bootstrap_threshold)
      }

    } else {
      # No alpha column: default to lasso (alpha = 1)
      lambda_seq    <- lambda_grid[["lambda"]]
      fit           <- glmnet::glmnet(x, y, family = family, alpha = 1.0,
                                      lambda = sort(lambda_seq, decreasing = TRUE))
      coef_mat      <- feature_abs_coefs_batch(fit, lambda_seq, family = family)
      result        <- selected_by_bootstrap_threshold(coef_mat, bootstrap_threshold)
    }

    result
  }
}

.make_adaptive_lasso_batch_adapter <- function(family, gamma, epsilon,
                                               bootstrap_threshold) {
  .validate_bootstrap_threshold(bootstrap_threshold)
  feature_abs_coefs <- .feature_abs_coefs
  environment(feature_abs_coefs) <- environment()
  feature_abs_coefs_batch <- .feature_abs_coefs_batch
  `.coerce_feature_abs_coefs_batch` <- .coerce_feature_abs_coefs_batch
  `.feature_abs_coefs_batch_fallback` <- .feature_abs_coefs_batch_fallback
  `.feature_abs_coefs` <- .feature_abs_coefs
  environment(feature_abs_coefs_batch) <- environment()
  selected_by_bootstrap_threshold <- .selected_by_bootstrap_threshold
  `.validate_bootstrap_threshold` <- .validate_bootstrap_threshold
  `.resolve_bootstrap_threshold` <- .resolve_bootstrap_threshold
  `.parse_bootstrap_threshold` <- .parse_bootstrap_threshold
  environment(selected_by_bootstrap_threshold) <- environment()

  function(x, y, lambda_grid) {
    lambda_seq <- lambda_grid[["lambda"]]

    # Ridge initialization to compute adaptive penalty weights
    init_fit       <- glmnet::glmnet(x, y, family = family, alpha = 0,
                                     nlambda = 30L)
    init_lambda    <- tail(init_fit$lambda, n = 1L)
    init_scores    <- feature_abs_coefs(fit = init_fit, s = init_lambda,
                                         family = family)
    penalty_factor <- 1.0 / ((init_scores + epsilon) ^ gamma)

    # Fit adaptive lasso across the full lambda path (one call)
    fit      <- glmnet::glmnet(x, y, family = family, alpha = 1,
                               lambda         = sort(lambda_seq, decreasing = TRUE),
                               penalty.factor = penalty_factor)
    coef_mat <- feature_abs_coefs_batch(fit, lambda_seq, family = family)
    selected_by_bootstrap_threshold(coef_mat, bootstrap_threshold)
  }
}

.make_sgl_batch_adapter <- function(family, feature_groups, alpha_fixed,
                                    bootstrap_threshold) {
  .validate_bootstrap_threshold(bootstrap_threshold)

  if (identical(family, "cox")) {
    stop(
      "Cox family is not supported by sparse_group_lasso. ",
      "Use base_learner = \"lasso\" or \"adaptive_lasso\" with family = \"cox\".",
      call. = FALSE
    )
  }
  groups <- as.integer(as.factor(feature_groups))
  feature_abs_coefs_sparsegl_batch <- .feature_abs_coefs_sparsegl_batch
  `.coerce_sparsegl_abs_coefs_batch` <- .coerce_sparsegl_abs_coefs_batch
  `.feature_abs_coefs_sparsegl_batch_fallback` <- .feature_abs_coefs_sparsegl_batch_fallback
  `.feature_abs_coefs_sparsegl` <- .feature_abs_coefs_sparsegl
  environment(feature_abs_coefs_sparsegl_batch) <- environment()
  selected_by_bootstrap_threshold <- .selected_by_bootstrap_threshold
  `.validate_bootstrap_threshold` <- .validate_bootstrap_threshold
  `.resolve_bootstrap_threshold` <- .resolve_bootstrap_threshold
  `.parse_bootstrap_threshold` <- .parse_bootstrap_threshold
  environment(selected_by_bootstrap_threshold) <- environment()

  function(x, y, lambda_grid) {
    n_lambdas  <- nrow(lambda_grid)
    n_features <- ncol(x)
    result     <- matrix(FALSE, nrow = n_features, ncol = n_lambdas)

    has_alpha_col <- "alpha" %in% names(lambda_grid)

    # Build list of (alpha, row_idx) pairs for batching
    alpha_batches <- if (!is.null(alpha_fixed)) {
      list(list(alpha = as.numeric(alpha_fixed), row_idx = seq_len(n_lambdas)))
    } else if (has_alpha_col) {
      lapply(unique(lambda_grid[["alpha"]]), function(a) {
        list(alpha = a, row_idx = which(lambda_grid[["alpha"]] == a))
      })
    } else {
      list(list(alpha = 0.05, row_idx = seq_len(n_lambdas)))
    }

    for (ab in alpha_batches) {
      row_idx    <- ab$row_idx
      lambda_seq <- lambda_grid[["lambda"]][row_idx]
      asparse    <- ab$alpha

      # sparsegl requires features sorted by group (non-decreasing group index).
      sort_ord <- order(groups)
      inv_ord  <- order(sort_ord)
      x_s      <- x[, sort_ord, drop = FALSE]
      grp_s    <- groups[sort_ord]

      if (family == "multinomial") {
        if (!is.factor(y)) y <- factor(y)
        levs     <- levels(y)
        coef_acc <- matrix(0.0, nrow = n_features, ncol = length(row_idx))
        for (k in seq_along(levs)) {
          yk    <- as.integer(y == levs[[k]])
          fit_k <- sparsegl::sparsegl(x = x_s, y = yk, group = grp_s,
                                      family  = "binomial",
                                      lambda  = sort(lambda_seq, decreasing = TRUE),
                                      asparse = asparse)
          coef_k_sorted <- feature_abs_coefs_sparsegl_batch(fit_k, lambda_seq)
          coef_k        <- coef_k_sorted[inv_ord, , drop = FALSE]
          coef_acc      <- pmax(coef_acc, coef_k)
        }
        result[, row_idx] <- selected_by_bootstrap_threshold(coef_acc, bootstrap_threshold)
      } else {
        fit      <- sparsegl::sparsegl(x = x_s, y = y, group = grp_s,
                                       family  = family,
                                       lambda  = sort(lambda_seq, decreasing = TRUE),
                                       asparse = asparse)
        coef_mat          <- feature_abs_coefs_sparsegl_batch(fit, lambda_seq)
        result[, row_idx] <- selected_by_bootstrap_threshold(
          coef_mat[inv_ord, , drop = FALSE],
          bootstrap_threshold
        )
      }
    }

    result
  }
}
