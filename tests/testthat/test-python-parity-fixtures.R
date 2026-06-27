test_that("bundled Python parity fixtures are present and loadable", {
  fixture_dir <- test_path("fixtures", "python_parity")
  required <- file.path(
    fixture_dir,
    c(
      "README.md",
      "stabl_fit_reference.csv",
      "stacked_multi_omic_reference.csv",
      "metrics_scalars.csv",
      "metrics_vectors.csv"
    )
  )

  missing <- required[!file.exists(required)]
  expect_equal(missing, character(0L), info = paste("Missing fixtures:", paste(missing, collapse = ", ")))

  stabl_ref <- utils::read.csv(file.path(fixture_dir, "stabl_fit_reference.csv"))
  stack_ref <- utils::read.csv(file.path(fixture_dir, "stacked_multi_omic_reference.csv"))

  expect_named(stabl_ref, c("feature", "max_stability_score"))
  expect_named(stack_ref, c("omic", "weight"))
  expect_true(all(is.finite(stabl_ref$max_stability_score)))
  expect_true(all(is.finite(stack_ref$weight)))
})
