test_that("AUDIT IMPL-001: get_support rejects invalid thresholds", {
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

  expect_error(
    get_support(object, new_hard_threshold = NA_real_),
    "single non-missing numeric value"
  )
  expect_error(
    get_support(object, new_hard_threshold = c(0.3, 0.7)),
    "single non-missing numeric value"
  )
  expect_error(
    get_support(object, new_hard_threshold = 0),
    "single non-missing numeric value"
  )
  expect_equal(
    get_support(object, new_hard_threshold = 0.5),
    c(a = FALSE, b = TRUE)
  )

  object$fdr_min_threshold_ <- 0
  expect_equal(
    get_support(object),
    c(a = TRUE, b = TRUE)
  )
})
