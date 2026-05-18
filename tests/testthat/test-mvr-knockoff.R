test_that("solve_mvr S-matrix is PSD and feasible", {
  withr::local_seed(7)
  p <- 20L
  rho <- 0.7
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))

  S <- costablr:::.solve_mvr(Sigma, num_iter = 5L)

  expect_equal(dim(S), c(p, p))
  expect_equal(S[upper.tri(S)], rep(0, p * (p - 1L) / 2L))
  expect_true(costablr:::.calc_mineig(S) > -1e-6)
  expect_true(costablr:::.calc_mineig(2 * Sigma - S) > -1e-6)
})

test_that("Rcpp solve_mvr matches the pure-R reference for fixed updates", {
  p <- 8L
  rho <- 0.45
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))
  update_order <- rbind(
    c(1L, 3L, 5L, 7L, 2L, 4L, 6L, 8L),
    c(8L, 6L, 4L, 2L, 7L, 5L, 3L, 1L),
    c(2L, 1L, 4L, 3L, 6L, 5L, 8L, 7L)
  )

  S_cpp <- costablr:::.solve_mvr(
    Sigma,
    num_iter = nrow(update_order),
    converge_tol = -1e100,
    use_cpp = TRUE,
    update_order = update_order
  )
  S_r <- costablr:::.solve_mvr(
    Sigma,
    num_iter = nrow(update_order),
    converge_tol = -1e100,
    use_cpp = FALSE,
    update_order = update_order
  )

  expect_equal(S_cpp, S_r, tolerance = 1e-8, ignore_attr = TRUE)
})

test_that("Rcpp solve_mvr matches knockpy for fixed coordinate updates", {
  py <- Sys.which("python")
  skip_if(py == "", "Python is unavailable")
  probe <- suppressWarnings(system2(
    py,
    c("-c", shQuote("import knockpy")),
    stdout = TRUE,
    stderr = TRUE
  ))
  skip_if(
    !is.null(attr(probe, "status")) && attr(probe, "status") != 0,
    "Python knockpy is unavailable"
  )

  p <- 6L
  rho <- 0.35
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))
  update_order <- rbind(
    c(1L, 4L, 2L, 5L, 3L, 6L),
    c(6L, 3L, 5L, 2L, 4L, 1L),
    c(2L, 5L, 1L, 6L, 4L, 3L),
    c(3L, 1L, 6L, 4L, 2L, 5L)
  )

  sigma_file <- tempfile(fileext = ".csv")
  order_file <- tempfile(fileext = ".csv")
  out_file <- tempfile(fileext = ".csv")
  write.table(Sigma, sigma_file, sep = ",", row.names = FALSE,
              col.names = FALSE)
  write.table(update_order, order_file, sep = ",", row.names = FALSE,
              col.names = FALSE)

  python_code <- paste(
    "import sys, numpy as np",
    "from knockpy import mrc",
    "Sigma = np.loadtxt(sys.argv[1], delimiter=',')",
    "orders = np.loadtxt(sys.argv[2], delimiter=',', dtype=int)",
    "orders = np.atleast_2d(orders)",
    "state = {'i': 0}",
    "def fixed_shuffle(a):\n    a[:] = orders[state['i']] - 1\n    state['i'] += 1",
    "np.random.shuffle = fixed_shuffle",
    "S = mrc.solve_mvr(Sigma=Sigma, num_iter=orders.shape[0], smoothing=0, converge_tol=-1e100, choldate_warning=False)",
    "np.savetxt(sys.argv[3], S, delimiter=',', fmt='%.17g')",
    sep = "\n"
  )
  py_out <- suppressWarnings(system2(
    py,
    c("-c", shQuote(python_code), shQuote(sigma_file),
      shQuote(order_file), shQuote(out_file)),
    stdout = TRUE,
    stderr = TRUE
  ))
  expect_true(
    is.null(attr(py_out, "status")) || attr(py_out, "status") == 0,
    info = paste(py_out, collapse = "\n")
  )

  S_cpp <- costablr:::.solve_mvr(
    Sigma,
    num_iter = nrow(update_order),
    converge_tol = -1e100,
    use_cpp = TRUE,
    update_order = update_order
  )
  S_py <- as.matrix(utils::read.csv(out_file, header = FALSE))

  expect_equal(S_cpp, S_py, tolerance = 1e-7, ignore_attr = TRUE)
})

test_that("make_artificial_features supports mvr_knockoff", {
  withr::local_seed(42)
  n <- 60L
  p <- 24L
  rho <- 0.5
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))
  L <- chol(Sigma)
  x <- matrix(rnorm(n * p), nrow = n) %*% L
  dimnames(x) <- list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))

  out <- make_artificial_features(
    x,
    n_injected = 10L,
    type = "mvr_knockoff",
    random_state = 99L
  )

  expect_equal(dim(out$x_augmented), c(n, p + 10L))
  expect_length(out$noise_col_indices, 10L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= p))
  expect_false(isTRUE(all.equal(
    out$x_augmented[, seq.int(p + 1L, p + 10L), drop = FALSE],
    x[, out$noise_col_indices, drop = FALSE],
    check.attributes = FALSE
  )))
})

test_that("make_mvr_knockoff_features falls back with stable schema", {
  withr::local_seed(13)
  x <- matrix(rnorm(30 * 6), nrow = 30)

  expect_warning(
    out <- make_mvr_knockoff_features(
      x,
      n_injected = 3L,
      max_p_r = 1L
    ),
    "falling back to random permutation"
  )

  expect_equal(dim(out$x_augmented), c(30L, 9L))
  expect_length(out$noise_col_indices, 3L)
  expect_true(all(out$noise_col_indices >= 1L & out$noise_col_indices <= 6L))
  expect_identical(out$type_requested, "mvr_knockoff")
  expect_identical(out$type_used, "random_permutation")
  expect_true(out$fallback_used)
})
