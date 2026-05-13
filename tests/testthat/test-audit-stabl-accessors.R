test_that("AUDIT INT-001: get_support currently accepts non-scalar thresholds", {
  object <- structure(
    list(
      stabl_scores_ = matrix(
        c(0.2, 0.8, 0.4, 0.6),
        nrow = 2L,
        dimnames = list(c("a", "b"), NULL)
      ),
      hard_threshold = NULL,
      fdr_min_threshold_ = 0.5,
      explore = FALSE,
      n_explore = 1L,
      feature_names = c("a", "b"),
      n_features_in_ = 2L
    ),
    class = "stabl_fit"
  )

  expect_equal(
    get_support(object, new_hard_threshold = NA_real_),
    c(a = NA, b = NA)
  )
  expect_equal(
    get_support(object, new_hard_threshold = c(0.3, 0.7)),
    c(a = TRUE, b = TRUE)
  )
})
