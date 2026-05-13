# Minimum variance-based reconstructability (MVR) Gaussian knockoffs.
# The coordinate update formulas follow knockpy's ungrouped MVR S-matrix
# solver, but this first R implementation recomputes Cholesky factors and is
# therefore intentionally limited to small covariance blocks.

.calc_mineig <- function(M) {
  M <- (M + t(M)) / 2
  min(eigen(M, symmetric = TRUE, only.values = TRUE)$values)
}

.shift_until_psd <- function(M, tol = 1e-5) {
  M <- (M + t(M)) / 2
  min_eig <- .calc_mineig(M)
  if (min_eig < tol) {
    M <- M + (tol - min_eig) * diag(nrow(M))
  }
  M
}

.scale_until_psd <- function(Sigma, S, tol = 1e-5, num_iter = 10L) {
  S <- .shift_until_psd(S, tol = tol)
  lower <- 0
  upper <- 1

  for (i in seq_len(num_iter)) {
    gamma <- (lower + upper) / 2
    V <- 2 * Sigma - gamma * S
    ok <- isTRUE(tryCatch({
      chol(V - tol * diag(nrow(V)))
      TRUE
    }, error = function(e) FALSE))
    if (ok) lower <- gamma else upper <- gamma
  }

  lower * S
}

mvr_loss <- function(Sigma, S, smoothing = 0) {
  eigs_S <- diag(S)
  eigs_diff <- eigen(2 * Sigma - S, symmetric = TRUE,
                     only.values = TRUE)$values
  if (min(eigs_S) < 0 || min(eigs_diff) < 0) return(Inf)
  sum(1 / (eigs_diff + smoothing)) + sum(1 / (eigs_S + smoothing))
}

.solve_mvr_quadratic <- function(cn, cd, sj, smoothing = 0) {
  coef2 <- -cn - cd^2
  coef1 <- 2 * (-cn * (sj + smoothing) + cd)
  coef0 <- -cn * (sj + smoothing)^2 - 1
  roots <- polyroot(c(coef0, coef1, coef2))
  real_roots <- Re(roots[abs(Im(roots)) < 1e-8])

  upper <- 1 / cd
  lower <- -sj
  feasible <- real_roots[real_roots > lower & real_roots < upper]
  if (length(feasible) == 0L) return(0)
  if (length(feasible) == 1L) return(feasible)

  losses <- 1 / (sj + feasible) - (feasible * cn) / (1 - feasible * cd)
  feasible[which.min(losses)]
}

.solve_mvr_ungrouped_r <- function(Sigma, num_iter = 50L, smoothing = 0,
                                   converge_tol = 1e-3,
                                   verbose = FALSE) {
  p <- nrow(Sigma)
  S <- .calc_mineig(Sigma) * diag(p)
  loss <- Inf
  decayed_improvement <- 10
  I <- diag(p)

  for (iter in seq_len(num_iter)) {
    for (j in sample.int(p)) {
      L <- chol(2 * Sigma - S + smoothing * I)
      ej <- numeric(p)
      ej[j] <- 1

      vd <- forwardsolve(t(L), ej)
      cd <- sum(vd^2)
      vn <- backsolve(L, vd)
      cn <- -sum(vn^2)

      delta <- .solve_mvr_quadratic(cn = cn, cd = cd, sj = S[j, j],
                                    smoothing = smoothing)
      S[j, j] <- S[j, j] + delta
    }

    prev_loss <- loss
    loss <- mvr_loss(Sigma, S, smoothing = smoothing)
    if (iter > 1L) {
      decayed_improvement <- decayed_improvement / 10 +
        9 * (prev_loss - loss) / 10
    }
    if (verbose) {
      message(sprintf("MVR iteration %d loss=%.6g", iter, loss))
    }
    if (iter > 1L && decayed_improvement >= 0 &&
        decayed_improvement < converge_tol) {
      break
    }
  }

  S
}

.solve_mvr <- function(Sigma, tol = 1e-5, num_iter = 50L, smoothing = 0,
                       converge_tol = 1e-3, verbose = FALSE,
                       max_p_r = 300L) {
  if (!is.matrix(Sigma) || nrow(Sigma) != ncol(Sigma)) {
    stop("`Sigma` must be a square matrix.", call. = FALSE)
  }
  if (nrow(Sigma) > max_p_r) {
    stop(
      "R MVR solver is limited to p <= ", max_p_r,
      "; use chunking or the future Rcpp solver.",
      call. = FALSE
    )
  }

  Sigma <- (Sigma + t(Sigma)) / 2
  S <- .solve_mvr_ungrouped_r(
    Sigma = Sigma,
    num_iter = num_iter,
    smoothing = smoothing,
    converge_tol = converge_tol,
    verbose = verbose
  )
  S <- .shift_until_psd(S, tol = tol)
  .scale_until_psd(Sigma, S, tol = tol, num_iter = 10L)
}

.produce_mx_gaussian_knockoffs <- function(X, mu, invSigma, S, tol = 1e-5) {
  invSigma_S <- invSigma %*% S
  centered <- sweep(X, 2, mu, "-")
  mu_k <- X - centered %*% invSigma_S
  Vk <- 2 * S - S %*% invSigma_S
  Vk <- (Vk + t(Vk)) / 2

  U <- tryCatch(
    chol(Vk),
    error = function(e) chol(.shift_until_psd(Vk, tol = tol))
  )
  Z <- matrix(stats::rnorm(nrow(X) * ncol(X)), nrow(X), ncol(X))
  out <- mu_k + Z %*% U
  dimnames(out) <- dimnames(X)
  out
}

make_mvr_knockoff_features <- function(x, n_injected, random_state = NULL,
                                       chunk_size = 300L, ...) {
  if (!is.null(random_state)) set.seed(random_state)
  n_features <- ncol(x)

  .make_mvr_chunk <- function(x_chunk) {
    tryCatch(
      {
        moments <- .estimate_gaussian_moments(x_chunk, compute_inverse = TRUE)
        S <- .solve_mvr(moments$Sigma, ...)
        .produce_mx_gaussian_knockoffs(
          X = x_chunk,
          mu = moments$mu,
          invSigma = moments$invSigma,
          S = S
        )
      },
      error = function(e) {
        warning(
          "MVR knockoff generation failed; falling back to random ",
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
    warning(
      "MVR knockoff chunking ignores cross-chunk covariance; generated ",
      "knockoffs are an approximation for this feature count.",
      call. = FALSE
    )
    chunk_ids <- ceiling(seq_len(n_features) / chunk_size)
    chunks <- split(seq_len(n_features), chunk_ids)
    x_art_full <- do.call(cbind, lapply(chunks, function(idx) {
      .make_mvr_chunk(x[, idx, drop = FALSE])
    }))
    orig_map <- seq_len(n_features)
  } else {
    x_art_full <- .make_mvr_chunk(x)
    orig_map <- seq_len(n_features)
  }

  sel_idx <- sample.int(n = ncol(x_art_full), size = n_injected,
                        replace = FALSE)
  list(
    x_augmented = cbind(x, x_art_full[, sel_idx, drop = FALSE]),
    noise_col_indices = orig_map[sel_idx]
  )
}
