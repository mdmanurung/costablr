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

  stabl_ref <- utils::read.csv(
    file.path(fixture_dir, "stabl_fit_reference.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  stack_ref <- utils::read.csv(
    file.path(fixture_dir, "stacked_multi_omic_reference.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  expect_named(stabl_ref, c("feature", "max_stability_score"))
  expect_named(stack_ref, c("omic", "weight"))
  expect_true(all(is.finite(stabl_ref$max_stability_score)))
  expect_true(all(is.finite(stack_ref$weight)))
})

test_that("bundled Python parity fixtures keep the frozen reference values", {
  fixture_dir <- test_path("fixtures", "python_parity")

  stabl_ref <- utils::read.csv(
    file.path(fixture_dir, "stabl_fit_reference.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  stack_ref <- utils::read.csv(
    file.path(fixture_dir, "stacked_multi_omic_reference.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  expect_equal(stabl_ref$feature, c("gene_a", "gene_b", "gene_c"))
  expect_equal(stabl_ref$max_stability_score, c(1, 0.5, 0), tolerance = 1e-12)
  expect_true(all(stabl_ref$max_stability_score >= 0 & stabl_ref$max_stability_score <= 1))

  expect_equal(stack_ref$omic, c("rna", "protein"))
  expect_equal(stack_ref$weight, c(0.7, 0.3), tolerance = 1e-12)
  expect_true(all(stack_ref$weight >= 0))
  expect_equal(sum(stack_ref$weight), 1, tolerance = 1e-12)
})
