test_that("AUDIT IMPL-002: zero artificial count errors during accumulation", {
  withr::local_seed(101)
  x <- matrix(
    rnorm(20),
    nrow = 10L,
    dimnames = list(paste0("s", seq_len(10L)), paste0("f", seq_len(2L)))
  )
  y <- setNames(rnorm(10L), rownames(x))

  expect_snapshot(error = TRUE, {
    stabl_fit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.1),
      n_bootstraps = 2L,
      artificial_type = "random_permutation",
      artificial_proportion = 0.1,
      sample_fraction = 1,
      random_state = 1L
    )
  })
})

test_that("AUDIT IMPL-003: zero subsample count fails after bootstrap retries", {
  withr::local_seed(102)
  x <- matrix(
    rnorm(20),
    nrow = 10L,
    dimnames = list(paste0("s", seq_len(10L)), paste0("f", seq_len(2L)))
  )
  y <- setNames(rep(c(0, 1), each = 5L), rownames(x))

  expect_snapshot(error = TRUE, {
    stabl_fit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = 0.1),
      family = "binomial",
      n_bootstraps = 2L,
      artificial_type = NULL,
      hard_threshold = 0.5,
      sample_fraction = 0.01,
      random_state = 1L
    )
  })
})
