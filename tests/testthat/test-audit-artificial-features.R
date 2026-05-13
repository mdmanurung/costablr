test_that("AUDIT IMPL-004: direct model-X random_state argument is reproducible", {
  skip_if_not_installed("knockoff")

  withr::local_seed(301)
  x <- matrix(rnorm(60L), nrow = 20L)

  set.seed(1L)
  first <- make_modelx_knockoff_features(x, n_injected = 3L, random_state = 123L)
  set.seed(2L)
  second <- make_modelx_knockoff_features(x, n_injected = 3L, random_state = 123L)

  expect_equal(
    isTRUE(all.equal(
      first$x_augmented,
      second$x_augmented,
      check.attributes = FALSE
    )),
    TRUE
  )
  expect_equal(identical(first$noise_col_indices, second$noise_col_indices), TRUE)
})
