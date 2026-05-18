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
  expect_equal(
    get_support(object, new_hard_threshold = 0.4),
    c(a = TRUE, b = TRUE)
  )

  object$fdr_min_threshold_ <- 0
  expect_equal(
    get_support(object),
    c(a = TRUE, b = TRUE)
  )
})

test_that("get_support uses paper-method threshold ties", {
  object <- structure(
    list(
      stabl_scores_ = matrix(
        c(0, 0.4, 0.8, 0, 0.4, 0.8),
        nrow = 3L,
        dimnames = list(c("zero", "tie", "high"), NULL)
      ),
      hard_threshold = NULL,
      fdr_min_threshold_ = 0.4,
      explore = FALSE,
      n_explore = 1L,
      feature_names = c("zero", "tie", "high"),
      n_features_in_ = 3L
    ),
    class = "stabl_fit"
  )

  expect_equal(
    get_support(object),
    c(zero = FALSE, tie = TRUE, high = TRUE)
  )

  object$fdr_min_threshold_ <- 0
  expect_equal(
    get_support(object),
    c(zero = TRUE, tie = TRUE, high = TRUE)
  )
})

test_that("threshold resolution order is shared by accessors and plots", {
  object <- structure(
    list(
      stabl_scores_ = matrix(
        c(0.2, 0.8, 0.4, 0.6),
        nrow = 2L,
        dimnames = list(c("a", "b"), NULL)
      ),
      hard_threshold = 0.6,
      fdr_min_threshold_ = 0.4,
      explore = FALSE,
      n_explore = 1L,
      feature_names = c("a", "b"),
      n_features_in_ = 2L
    ),
    class = "stabl_fit"
  )

  override <- costablr:::.resolve_threshold(object, new_hard_threshold = 0.7)
  expect_identical(override$source, "new_hard_threshold")
  expect_equal(override$value, 0.7)

  hard <- costablr:::.resolve_threshold(object)
  expect_identical(hard$source, "hard_threshold")
  expect_equal(hard$value, 0.6)

  object$hard_threshold <- NULL
  fdp <- costablr:::.resolve_threshold(object)
  expect_identical(fdp$source, "fdr_min_threshold_")
  expect_equal(fdp$value, 0.4)

  object$fdr_min_threshold_ <- 0
  expect_equal(costablr:::.resolve_threshold(object)$value, 0)
})
