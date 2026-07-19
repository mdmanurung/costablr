test_that("methodology validation runner writes bounded artifact schema", {
  skip_on_cran()

  env <- new.env(parent = globalenv())
  sys.source(
    file.path("..", "..", "inst", "analysis", "run_methodology_validation.R"),
    envir = env
  )

  out <- tempfile("stablr-methodology-validation-")
  dir.create(out)

  artifacts <- env$run_methodology_validation(
    out = out,
    replicates = 1L,
    n_bootstraps = 2L,
    n_lambda = 2L,
    artificial_types = "random_permutation",
    scenario_ids = "null_independent",
    seed = 270627L
  )

  expect_true(file.exists(artifacts$replicates))
  expect_true(file.exists(artifacts$summary))
  expect_true(file.exists(artifacts$warnings))
  expect_true(file.exists(artifacts$parity))
  expect_true(file.exists(artifacts$manifest))

  replicate_rows <- utils::read.csv(artifacts$replicates, stringsAsFactors = FALSE)
  expect_named(
    replicate_rows,
    c(
      "scenario", "regime", "correlation", "profile", "replicate",
      "artificial_type", "status", "n", "p", "n_signal",
      "n_bootstraps", "n_lambda", "fallback_random_permutation_warnings",
      "fallback_equi_warnings", "warning_count", "elapsed_sec",
      "n_selected", "true_positives", "false_positives", "empirical_fdp",
      "tpr", "min_fdp_plus", "fdp_threshold", "mean_max_real_score",
      "mean_max_artificial_score", "max_artificial_score",
      "selected_features", "error"
    )
  )
  expect_equal(nrow(replicate_rows), 1L)
  expect_equal(replicate_rows$status, "ok")

  parity_rows <- utils::read.csv(artifacts$parity, stringsAsFactors = FALSE)
  expect_true(all(c("metric", "reference", "observed", "abs_error", "status") %in% names(parity_rows)))
})
