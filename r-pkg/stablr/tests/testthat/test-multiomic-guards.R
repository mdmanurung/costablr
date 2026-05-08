# Audit V-9: hard guards on multi-omic input contracts.
# (Existing test-input-validation.R covers happy-path basics; this file
# pins the failure paths the audit flagged as untested.)

test_that("validate_multiomic_inputs rejects mismatched sample order across omics", {
  s_ids <- paste0("s", 1:6)
  x1 <- matrix(rnorm(6 * 3), nrow = 6, dimnames = list(s_ids, paste0("a", 1:3)))
  x2 <- matrix(rnorm(6 * 3), nrow = 6, dimnames = list(rev(s_ids), paste0("b", 1:3)))
  y  <- setNames(rnorm(6), s_ids)

  expect_error(
    validate_multiomic_inputs(list(omicA = x1, omicB = x2), y = y),
    "identical sample order"
  )
})

test_that("cooperative_fusion + family = 'cox' + selection = 'validation' is rejected", {
  skip_if_not_installed("multiview")
  skip_if_not_installed("survival")

  s_ids <- paste0("s", 1:30)
  x1 <- matrix(rnorm(30 * 4), nrow = 30, dimnames = list(s_ids, paste0("a", 1:4)))
  x2 <- matrix(rnorm(30 * 4), nrow = 30, dimnames = list(s_ids, paste0("b", 1:4)))
  y  <- survival::Surv(time = abs(rnorm(30)) + 0.1,
                        event = sample(0:1, 30, replace = TRUE))
  rownames(y) <- s_ids
  x_valid <- list(omicA = x1, omicB = x2)
  y_valid <- y

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list           = list(omicA = x1, omicB = x2),
      y_train                = y,
      x_valid_list           = x_valid,
      y_valid                = y_valid,
      lambda_grid            = data.frame(lambda = c(0.2, 0.1)),
      family                 = "cox",
      cooperative_fusion     = TRUE,
      cooperative_selection  = "validation",
      n_bootstraps           = 5L,
      artificial_type        = "random_permutation",
      random_state           = 1L
    ),
    "validation.*not supported.*cox|cox.*validation"
  )
})

test_that("cooperative_fusion errors when 'multiview' is not available", {
  s_ids <- paste0("s", 1:30)
  x1 <- matrix(rnorm(30 * 4), nrow = 30, dimnames = list(s_ids, paste0("a", 1:4)))
  x2 <- matrix(rnorm(30 * 4), nrow = 30, dimnames = list(s_ids, paste0("b", 1:4)))
  y  <- setNames(rnorm(30), s_ids)

  testthat::local_mocked_bindings(.has_multiview = function() FALSE)

  expect_error(
    stabl_multiomic_train_validate(
      x_train_list      = list(omicA = x1, omicB = x2),
      y_train           = y,
      lambda_grid       = data.frame(lambda = c(0.2, 0.1)),
      family            = "gaussian",
      cooperative_fusion = TRUE,
      n_bootstraps      = 5L,
      artificial_type   = "random_permutation",
      random_state      = 1L
    ),
    "multiview"
  )
})
