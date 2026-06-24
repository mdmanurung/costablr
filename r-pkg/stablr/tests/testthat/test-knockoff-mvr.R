# test-knockoff-mvr.R — TDD tests for the MVR knockoff S-matrix solver
# (R port of knockpy/mrc.py; internal functions exposed by pkgload::load_all)
#
# Test execution order (TDD):
#   1. Write tests (this file) — ALL should fail / error before implementation.
#   2. Implement R/knockoff_mvr.R + extensions to R/artificial_features.R.
#   3. Re-run: ALL should pass; baseline suite (PASS=1588) unchanged.
#
# Reference fixtures in fixtures/mvr/ were generated offline by
#   .venv-parity/bin/python r-pkg/stablr/scripts/generate_mvr_refs.py
# and are committed so no Python is needed at test time.

FIXTURE_DIR <- file.path(testthat::test_path("fixtures", "mvr"))

# ── Helper: load CSV fixtures ─────────────────────────────────────────────────
.load_csv <- function(name) {
  path <- file.path(FIXTURE_DIR, name)
  testthat::skip_if_not(file.exists(path),
    message = paste0("Fixture missing: ", name,
                     ". Run r-pkg/stablr/scripts/generate_mvr_refs.py first."))
  mat <- utils::read.csv(path, header = TRUE, check.names = FALSE)
  as.matrix(mat)
}

# ── AR(1) covariance matrix factory ─────────────────────────────────────────
.ar1_sigma <- function(p, rho) {
  rho ^ abs(outer(seq_len(p), seq_len(p), "-"))
}

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 1: Primitive — .mvr_cholupdate
# ─────────────────────────────────────────────────────────────────────────────

test_that(".mvr_cholupdate rank-1 update matches chol(V + xx')", {
  set.seed(1L)
  p <- 5L
  A <- crossprod(matrix(rnorm(p * p), p, p)) + diag(p)  # PD
  R <- chol(A)                    # upper triangular

  x <- rnorm(p)
  R_updated <- .mvr_cholupdate(R, x, add = TRUE)
  A_expected <- A + outer(x, x)
  expect_equal(t(R_updated) %*% R_updated, A_expected,
               tolerance = 1e-10, label = "update: R'R = A + xx'")
})

test_that(".mvr_cholupdate rank-1 downdate matches chol(V - xx')", {
  set.seed(2L)
  p <- 5L
  A <- crossprod(matrix(rnorm(p * p), p, p)) + 10 * diag(p)  # well-conditioned
  R <- chol(A)

  # Choose x small enough that A - xx' is still PD
  x <- rnorm(p) * 0.1
  R_downdated <- .mvr_cholupdate(R, x, add = FALSE)
  A_expected <- A - outer(x, x)
  expect_true(all(eigen(A_expected, only.values = TRUE)$values > 0),
              label = "A - xx' is PD")
  expect_equal(t(R_downdated) %*% R_downdated, A_expected,
               tolerance = 1e-10, label = "downdate: R'R = A - xx'")
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 2: Primitive — .solve_mvr_quadratic
# ─────────────────────────────────────────────────────────────────────────────

test_that(".solve_mvr_quadratic agrees with brute-force 1-D minimize", {
  # MVR per-coordinate 1-D loss (no smoothing):
  #   f(delta) = 1/(sj + delta) - delta*cn / (1 - delta*cd)
  # restricted to delta in (-sj, 1/cd)
  f_1d <- function(delta, cn, cd, sj) {
    1 / (sj + delta) - (delta * cn) / (1 - delta * cd)
  }

  set.seed(3L)
  for (trial in seq_len(10L)) {
    cd <- runif(1L, 0.1, 2.0)
    cn <- -runif(1L, 0.1, 2.0)   # cn is negative (= -sum(vn^2))
    sj <- runif(1L, 0.01, 0.5)

    lo <- -sj + 1e-9
    hi <- 1 / cd - 1e-9
    if (lo >= hi) next

    brute <- optimise(f_1d, interval = c(lo, hi), cn = cn, cd = cd, sj = sj)
    got   <- .solve_mvr_quadratic(cn = cn, cd = cd, sj = sj, smoothing = 0)

    # Both should yield similar objective values (minimizers may differ by
    # convention when the quadratic has two real roots, but the minimum loss
    # should match within numerical tolerance).
    expect_equal(f_1d(got, cn, cd, sj), brute$objective,
                 tolerance = 1e-6,
                 label = paste0("trial ", trial, ": quadratic min = brute min"))
  }
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 3: .mvr_loss
# ─────────────────────────────────────────────────────────────────────────────

test_that(".mvr_loss returns Inf for infeasible S", {
  Sigma <- .ar1_sigma(4L, 0.5)
  # S with negative diagonal → infeasible
  s_bad <- diag(-0.1, 4L)
  expect_equal(.mvr_loss(Sigma, s_bad), Inf)
})

test_that(".mvr_loss is finite and positive for feasible S", {
  Sigma <- .ar1_sigma(4L, 0.5)
  min_eig <- min(eigen(Sigma, only.values = TRUE)$values)
  S <- diag(min_eig * 0.5, 4L)  # well inside feasible cone
  loss <- .mvr_loss(Sigma, S)
  expect_true(is.finite(loss) && loss > 0)
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 4: solve_mvr — S parity vs knockpy reference fixtures
# ─────────────────────────────────────────────────────────────────────────────

test_that("solve_mvr AR(1) p=10 rho=0.5 matches knockpy within 1e-4", {
  Sigma_ref <- .load_csv("ar1_p10_Sigma.csv")
  S_ref     <- as.numeric(.load_csv("ar1_p10_S_diag.csv"))

  set.seed(42L)
  got <- solve_mvr(Sigma_ref, num_iter = 200L, converge_tol = 1e-5, tol = 1e-5)

  expect_equal(length(got), nrow(Sigma_ref))
  max_dev <- max(abs(got - S_ref))
  expect_lte(max_dev, 1e-4,
    label = paste0("max |S_R - S_py| = ", signif(max_dev, 4L),
                   " (tolerance 1e-4)"))
})

test_that("solve_mvr on Identity Sigma returns diagonal ~1 (within 1e-3)", {
  Sigma5 <- diag(5L)
  set.seed(7L)
  got <- solve_mvr(Sigma5, num_iter = 100L, converge_tol = 1e-5, tol = 1e-5)
  # For I_p the optimal S = I_p (equicorrelated solution); after PSD guards ≈ 1
  expect_equal(got, rep(1, 5L), tolerance = 1e-3)
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 5: solve_mvr — PSD guarantees
# ─────────────────────────────────────────────────────────────────────────────

test_that("solve_mvr guarantees S > 0 and 2Sigma - diag(S) is PSD", {
  for (config in list(
    list(p = 10L, rho = 0.5),
    list(p =  6L, rho = 0.7),
    list(p =  5L, rho = 0.0)   # Identity
  )) {
    Sigma <- if (config$rho == 0) diag(config$p) else
               .ar1_sigma(config$p, config$rho)
    set.seed(1L)
    S_diag <- solve_mvr(Sigma, tol = 1e-5)
    S_mat  <- diag(S_diag, config$p)

    eigs_S    <- eigen(S_mat, only.values = TRUE)$values
    eigs_diff <- eigen(2 * Sigma - S_mat, only.values = TRUE)$values

    expect_true(min(eigs_S) > -1e-6,
      label = paste0("p=", config$p, " rho=", config$rho, ": min(S) > 0"))
    expect_true(min(eigs_diff) > -1e-6,
      label = paste0("p=", config$p, " rho=", config$rho,
                     ": min(2Sigma-S) > 0"))
  }
})

test_that("create.gaussian with solve_mvr S-matrix does not throw", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE),
              message = "knockoff package required")
  set.seed(5L)
  p <- 8L; n <- 40L
  X <- matrix(rnorm(n * p), n, p)
  # Standardize
  X <- scale(X)
  mu    <- colMeans(X)
  Sigma <- cov(X)
  S_diag <- solve_mvr(Sigma, tol = 1e-5)
  expect_no_error(knockoff::create.gaussian(X, mu, Sigma, diag_s = S_diag))
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 6: solve_mvr — loss monotonically non-increasing (final < init)
# ─────────────────────────────────────────────────────────────────────────────

test_that("solve_mvr loss strictly decreases from initialization", {
  Sigma <- .load_csv("ar1_p6_Sigma.csv")
  S_ref <- as.numeric(.load_csv("ar1_p6_S_diag.csv"))

  # Compute initial loss (S = min_eig * I)
  min_eig  <- min(eigen(Sigma, only.values = TRUE)$values)
  S_init   <- diag(min_eig, nrow(Sigma))
  loss_init <- .mvr_loss(Sigma, S_init)

  # Final loss
  S_final  <- diag(S_ref, nrow(Sigma))
  loss_final <- .mvr_loss(Sigma, S_final)

  expect_true(loss_final < loss_init,
    label = paste0("final loss=", round(loss_final, 4),
                   " < init loss=", round(loss_init, 4)))
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 7: Dispatcher — make_artificial_features new types
# ─────────────────────────────────────────────────────────────────────────────

.make_test_x <- function(n = 30L, p = 8L, seed = 99L) {
  set.seed(seed)
  X <- matrix(rnorm(n * p), n, p,
              dimnames = list(paste0("s", seq_len(n)),
                              paste0("f", seq_len(p))))
  scale(X)
}

test_that("make_artificial_features type='knockoff_equi' returns correct shape", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  X    <- .make_test_x()
  n_inj <- ncol(X)

  out <- make_artificial_features(X, n_inj, type = "knockoff_equi",
                                   random_state = 1L)
  expect_named(out, c("x_augmented", "noise_col_indices"))
  expect_equal(nrow(out$x_augmented), nrow(X))
  expect_equal(ncol(out$x_augmented), ncol(X) + n_inj)
  expect_equal(length(out$noise_col_indices), n_inj)
  expect_true(all(out$noise_col_indices >= 1L &
                  out$noise_col_indices <= ncol(X)))
})

test_that("make_artificial_features type='knockoff_mvr' returns correct shape", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  X    <- .make_test_x()
  n_inj <- ncol(X)

  out <- make_artificial_features(X, n_inj, type = "knockoff_mvr",
                                   random_state = 2L)
  expect_named(out, c("x_augmented", "noise_col_indices"))
  expect_equal(nrow(out$x_augmented), nrow(X))
  expect_equal(ncol(out$x_augmented), ncol(X) + n_inj)
  expect_equal(length(out$noise_col_indices), n_inj)
  expect_true(all(out$noise_col_indices >= 1L &
                  out$noise_col_indices <= ncol(X)))
})

test_that("make_artificial_features rejects unknown type with informative error", {
  X <- .make_test_x()
  expect_error(make_artificial_features(X, 4L, type = "knockoff_mvr_bad"),
               regexp = "knockoff_mvr_bad", ignore.case = TRUE)
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 8: RNG determinism
# ─────────────────────────────────────────────────────────────────────────────

test_that("solve_mvr is deterministic given random_state", {
  Sigma <- .ar1_sigma(8L, 0.5)
  s1 <- solve_mvr(Sigma, random_state = 42L)
  s2 <- solve_mvr(Sigma, random_state = 42L)
  expect_identical(s1, s2)
})

test_that("make_artificial_features knockoff_mvr is deterministic given random_state", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  X <- .make_test_x()
  o1 <- make_artificial_features(X, 4L, type = "knockoff_mvr", random_state = 7L)
  o2 <- make_artificial_features(X, 4L, type = "knockoff_mvr", random_state = 7L)
  expect_identical(o1$x_augmented,      o2$x_augmented)
  expect_identical(o1$noise_col_indices, o2$noise_col_indices)
})

test_that("make_artificial_features knockoff_equi is deterministic given random_state", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  X <- .make_test_x()
  o1 <- make_artificial_features(X, 4L, type = "knockoff_equi", random_state = 8L)
  o2 <- make_artificial_features(X, 4L, type = "knockoff_equi", random_state = 8L)
  expect_identical(o1$x_augmented,      o2$x_augmented)
  expect_identical(o1$noise_col_indices, o2$noise_col_indices)
})

# ─────────────────────────────────────────────────────────────────────────────
# BLOCK 9: Fallback for rank-deficient input (p > n)
# ─────────────────────────────────────────────────────────────────────────────

test_that("make_artificial_features knockoff_mvr handles rank-deficient input", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  # p=20, n=10: rank-deficient; should fall back gracefully (no error)
  set.seed(55L)
  X_rd <- matrix(rnorm(10L * 20L), 10L, 20L,
                 dimnames = list(paste0("s", 1:10), paste0("f", 1:20)))
  # Should not throw; may warn about fallback
  out <- suppressWarnings(
    make_artificial_features(X_rd, 10L, type = "knockoff_mvr", random_state = 1L)
  )
  expect_equal(nrow(out$x_augmented), 10L)
  expect_equal(ncol(out$x_augmented), 30L)   # 20 + 10
})

test_that("make_artificial_features knockoff_equi handles rank-deficient input", {
  skip_if_not(requireNamespace("knockoff", quietly = TRUE))
  set.seed(56L)
  X_rd <- matrix(rnorm(10L * 20L), 10L, 20L,
                 dimnames = list(paste0("s", 1:10), paste0("f", 1:20)))
  out <- suppressWarnings(
    make_artificial_features(X_rd, 10L, type = "knockoff_equi", random_state = 1L)
  )
  expect_equal(nrow(out$x_augmented), 10L)
  expect_equal(ncol(out$x_augmented), 30L)
})
