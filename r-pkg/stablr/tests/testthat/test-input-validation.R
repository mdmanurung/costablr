test_that("validate_sample_alignment accepts aligned inputs", {
  x <- data.frame(a = c(1, 2), b = c(3, 4), row.names = c("s1", "s2"))
  y <- c(s1 = 0, s2 = 1)
  g <- c(s1 = "p1", s2 = "p2")

  expect_invisible(validate_sample_alignment(x, y, g))
})

test_that("validate_sample_alignment fails on id mismatch", {
  x <- data.frame(a = c(1, 2), row.names = c("s1", "s2"))
  y <- c(s1 = 0, s3 = 1)

  expect_error(validate_sample_alignment(x, y), "Sample mismatch")
})

test_that("validate_multiomic_inputs enforces named list and sample order", {
  x1 <- data.frame(a = c(1, 2), row.names = c("s1", "s2"))
  x2 <- data.frame(a = c(2, 3), row.names = c("s2", "s1"))
  y <- c(s1 = 0, s2 = 1)

  expect_error(
    validate_multiomic_inputs(list(omic1 = x1, omic2 = x2), y),
    "identical sample order"
  )
})

test_that("stabl_fit errors early when sample_fraction > 1 and replace = FALSE", {
  # Fix 7: validator must fire before the bootstrap loop to give a clear message.
  set.seed(1L)
  n <- 20L; p <- 5L
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))
  lam_grid <- data.frame(lambda = c(0.1, 0.2))

  expect_error(
    stabl_fit(
      x               = x,
      y               = y,
      lambda_grid     = lam_grid,
      family          = "gaussian",
      n_bootstraps    = 5L,
      artificial_type = NULL,
      hard_threshold  = 0.3,
      sample_fraction = 1.5,   # > 1 with replace = FALSE -> n_subsamples > n_samples
      replace         = FALSE
    ),
    "cannot exceed 1.*replace = FALSE|reduce.*sample_fraction|replace = TRUE",
    ignore.case = TRUE
  )
})
