.parity_fixture_dir <- function() {
  testthat::test_path("fixtures", "python_parity")
}

.parity_read <- function(name) {
  utils::read.csv(
    file.path(.parity_fixture_dir(), name),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

.parity_sha256 <- function(path) {
  sha256sum <- Sys.which("sha256sum")
  if (nzchar(sha256sum)) {
    output <- system2(sha256sum, path, stdout = TRUE, stderr = TRUE)
    return(tolower(strsplit(output[[1L]], "[[:space:]]+")[[1L]][[1L]]))
  }
  shasum <- Sys.which("shasum")
  if (nzchar(shasum)) {
    output <- system2(shasum, c("-a", "256", path), stdout = TRUE, stderr = TRUE)
    return(tolower(strsplit(output[[1L]], "[[:space:]]+")[[1L]][[1L]]))
  }
  NA_character_
}

.parity_score_matrix <- function(scores, feature_type) {
  part <- scores[scores$feature_type == feature_type, , drop = FALSE]
  features <- unique(part$feature)
  lambdas <- unique(part$lambda_id)
  output <- matrix(
    NA_real_,
    nrow = length(features),
    ncol = length(lambdas),
    dimnames = list(features, lambdas)
  )
  for (i in seq_len(nrow(part))) {
    output[part$feature[[i]], part$lambda_id[[i]]] <- part$stability_score[[i]]
  }
  output
}

.parity_weighted_candidates <- function(predictions, outcomes, candidates) {
  prediction_matrix <- as.matrix(predictions[, setdiff(names(predictions), "sample_id"), drop = FALSE])
  y <- outcomes$outcome[match(predictions$sample_id, outcomes$sample_id)]
  omics <- colnames(prediction_matrix)
  scores <- rep(NA_real_, nrow(candidates))
  stacked <- vector("list", nrow(candidates))
  best_score <- -Inf
  best_index <- NA_integer_

  for (i in seq_len(nrow(candidates))) {
    weights <- as.numeric(candidates[i, omics, drop = TRUE])
    stacked[[i]] <- stablr:::.weighted_masked_mean(prediction_matrix, weights)
    if (anyNA(stacked[[i]])) next
    scores[[i]] <- stablr:::.r_auc(y, stacked[[i]])
    if (is.finite(scores[[i]]) && scores[[i]] > best_score) {
      best_score <- scores[[i]]
      best_index <- i
    }
  }

  list(
    scores = scores,
    best_index = best_index,
    best_id = candidates$candidate_id[[best_index]],
    weights = as.numeric(candidates[best_index, omics, drop = TRUE]),
    predictions = stacked[[best_index]],
    score = best_score,
    omics = omics
  )
}

.parity_solver_fit <- function(x, y, schedule, lambda_grid, family, alpha) {
  bootstrap_ids <- unique(schedule$bootstrap_id)
  lambda_values <- lambda_grid$r_lambda
  selected <- array(
    FALSE,
    dim = c(ncol(x), length(lambda_values), length(bootstrap_ids)),
    dimnames = list(colnames(x), lambda_grid$lambda_id, as.character(bootstrap_ids))
  )

  for (bootstrap_index in seq_along(bootstrap_ids)) {
    rows <- schedule$sample_id[schedule$bootstrap_id == bootstrap_ids[[bootstrap_index]]]
    indices <- match(rows, rownames(x))
    fit <- suppressWarnings(glmnet::glmnet(
      x = x[indices, , drop = FALSE],
      y = y[indices],
      family = family,
      alpha = alpha,
      lambda = sort(lambda_values, decreasing = TRUE),
      standardize = FALSE,
      thresh = 1e-12,
      maxit = 100000L
    ))
    coefficients <- stablr:::.feature_abs_coefs_batch(
      fit,
      lambda_seq = lambda_values,
      family = family
    )
    selected[, , bootstrap_index] <- coefficients > 1e-5
  }
  apply(selected, c(1L, 2L), mean)
}

test_that("Python parity fixture inventory and SHA-256 manifest are complete", {
  fixture_dir <- .parity_fixture_dir()
  required <- c(
    "README.md", "environment.yml", "generate.py", "provenance.json",
    "manifest.sha256", "input_matrix.csv", "outcomes.csv",
    "bootstrap_schedule.csv", "artificial_matrix.csv",
    "artificial_provenance.csv", "lambda_grid.csv", "selection_masks.csv",
    "stability_scores.csv", "fdp_plus_curve.csv", "fdp_plus_by_lambda.csv",
    "stabl_fit_reference.csv", "stacking_predictions.csv",
    "stacking_outcomes.csv", "stacking_candidate_weights.csv",
    "stacking_candidate_scores.csv", "stacked_multi_omic_reference.csv",
    "stacking_predictions_reference.csv", "metrics_scalars.csv",
    "metrics_vectors.csv", "solver_input_matrix.csv", "solver_outcomes.csv",
    "solver_bootstrap_schedule.csv", "solver_cases.csv",
    "solver_lambda_grid.csv", "solver_reference.csv"
  )
  expect_equal(required[!file.exists(file.path(fixture_dir, required))], character())

  manifest <- readLines(file.path(fixture_dir, "manifest.sha256"), warn = FALSE)
  expect_true(length(manifest) > 20L)
  expect_true(all(grepl("^[0-9a-f]{64}  [A-Za-z0-9_.-]+$", manifest)))
  expected_hash <- substr(manifest, 1L, 64L)
  filenames <- substring(manifest, 67L)
  expect_equal(anyDuplicated(filenames), 0L)
  expect_true(all(file.exists(file.path(fixture_dir, filenames))))

  actual_hash <- vapply(file.path(fixture_dir, filenames), .parity_sha256, character(1L))
  if (all(is.na(actual_hash))) {
    testthat::succeed("No platform SHA-256 utility is available; manifest structure was checked.")
  } else {
    expect_equal(unname(actual_hash), expected_hash)
  }
})

test_that("parity provenance pins Python 3.11 and the immutable Stabl commit", {
  provenance <- paste(readLines(file.path(.parity_fixture_dir(), "provenance.json")), collapse = "\n")
  environment <- paste(readLines(file.path(.parity_fixture_dir(), "environment.yml")), collapse = "\n")
  commit <- "1d07f85a13cfbecb4f08ce21075bf4fbb8e34678"

  expect_match(provenance, commit, fixed = TRUE)
  expect_match(provenance, '"python": "3.11.9"', fixed = TRUE)
  expect_match(environment, "python=3.11.9", fixed = TRUE)
  expect_match(environment, paste0("STABL_REFERENCE_COMMIT: ", commit), fixed = TRUE)
  expect_match(provenance, "not outputs of glmnet or scikit-learn fits", fixed = TRUE)
})

test_that("frozen selection masks accumulate to the Python stability scores exactly", {
  masks <- .parity_read("selection_masks.csv")
  scores <- .parity_read("stability_scores.csv")
  expect_setequal(unique(masks$selected), c(0L, 1L))
  expect_equal(length(unique(masks$bootstrap_id)), 8L)

  accumulated <- stats::aggregate(
    selected ~ feature_type + feature + lambda_id,
    data = masks,
    FUN = mean
  )
  names(accumulated)[names(accumulated) == "selected"] <- "actual"
  compared <- merge(scores, accumulated, by = c("feature_type", "feature", "lambda_id"))
  expect_equal(nrow(compared), nrow(scores))
  expect_equal(compared$actual, compared$stability_score, tolerance = 1e-12)

  reference <- .parity_read("stabl_fit_reference.csv")
  real_scores <- .parity_score_matrix(scores, "real")
  observed_max <- apply(real_scores, 1L, max)
  expect_equal(unname(observed_max[reference$feature]), reference$max_stability_score, tolerance = 1e-12)
  expect_equal(
    as.integer(rank(-reference$max_stability_score, ties.method = "min")),
    reference$rank
  )
  expect_true(all(c("signal_a", "signal_b") %in% reference$feature[reference$rank <= 2L]))
  expect_gt(length(unique(reference$max_stability_score)), 1L)
})

test_that("FDP+, first-minimum threshold, and support match pinned Python methods", {
  scores <- .parity_read("stability_scores.csv")
  curve <- .parity_read("fdp_plus_curve.csv")
  by_lambda <- .parity_read("fdp_plus_by_lambda.csv")
  reference <- .parity_read("stabl_fit_reference.csv")
  real_scores <- .parity_score_matrix(scores, "real")
  artificial_scores <- .parity_score_matrix(scores, "artificial")

  observed <- compute_fdp_plus(
    real_scores,
    artificial_scores,
    artificial_proportion = 0.5,
    fdr_threshold_range = curve$threshold
  )
  expect_equal(observed$FDRs, curve$fdp_plus, tolerance = 1e-12)
  expect_equal(observed$min_fdr, min(curve$fdp_plus), tolerance = 1e-12)
  expected_threshold <- curve$threshold[curve$is_first_minimum == 1L]
  expect_length(expected_threshold, 1L)
  expect_equal(observed$fdr_min_threshold, expected_threshold, tolerance = 1e-12)

  for (lambda_index in seq_along(colnames(real_scores))) {
    lambda_id <- colnames(real_scores)[[lambda_index]]
    expected <- by_lambda$fdp_plus[by_lambda$lambda_id == lambda_id]
    expect_equal(
      unname(observed$fdrs_table[lambda_index, ]),
      expected,
      tolerance = 1e-12
    )
  }
  expect_equal(
    as.integer(reference$max_stability_score > observed$fdr_min_threshold),
    reference$selected
  )
  expect_true(all(
    reference$selected[reference$max_stability_score == observed$fdr_min_threshold] == 0L
  ))
})

test_that("committed stacking candidates match Python choice, predictions, and tie semantics", {
  predictions <- .parity_read("stacking_predictions.csv")
  outcomes <- .parity_read("stacking_outcomes.csv")
  candidates <- .parity_read("stacking_candidate_weights.csv")
  candidate_reference <- .parity_read("stacking_candidate_scores.csv")
  weight_reference <- .parity_read("stacked_multi_omic_reference.csv")
  prediction_reference <- .parity_read("stacking_predictions_reference.csv")
  observed <- .parity_weighted_candidates(predictions, outcomes, candidates)

  expect_equal(observed$scores, candidate_reference$score, tolerance = 1e-12)
  expect_equal(observed$best_id, unique(weight_reference$candidate_id))
  expect_equal(observed$score, unique(weight_reference$score), tolerance = 1e-12)
  expect_equal(observed$weights, weight_reference$raw_weight, tolerance = 1e-12)
  expect_equal(observed$weights / sum(observed$weights), weight_reference$weight, tolerance = 1e-12)
  expect_equal(observed$predictions, prediction_reference$stacked_prediction, tolerance = 1e-12)
  expect_equal(predictions$sample_id, prediction_reference$sample_id)

  tied <- candidate_reference$candidate_id[candidate_reference$ties_chosen_score == 1L]
  expect_gt(length(tied), 1L)
  expect_equal(observed$best_id, min(tied))
  expect_true(anyNA(candidate_reference$score))
  expect_true(anyNA(predictions) && !anyNA(observed$predictions))
})

test_that("end-to-end solver parity meets family-specific ranking and support contracts", {
  x_frame <- .parity_read("solver_input_matrix.csv")
  outcomes <- .parity_read("solver_outcomes.csv")
  schedule <- .parity_read("solver_bootstrap_schedule.csv")
  cases <- .parity_read("solver_cases.csv")
  lambda_grid <- .parity_read("solver_lambda_grid.csv")
  reference <- .parity_read("solver_reference.csv")
  x <- as.matrix(x_frame[, setdiff(names(x_frame), "sample_id"), drop = FALSE])
  rownames(x) <- x_frame$sample_id

  for (case_index in seq_len(nrow(cases))) {
    case <- cases[case_index, , drop = FALSE]
    case_name <- case$case[[1L]]
    family <- case$family[[1L]]
    case_lambdas <- lambda_grid[lambda_grid$case == case_name, , drop = FALSE]
    y <- outcomes[[family]]
    names(y) <- outcomes$sample_id
    if (family == "multinomial") y <- factor(y, levels = c("A", "B", "C"))
    score_matrix <- .parity_solver_fit(
      x,
      y,
      schedule,
      case_lambdas,
      family,
      alpha = case$l1_ratio[[1L]]
    )
    r_scores <- apply(score_matrix, 1L, max)
    python <- reference[reference$case == case_name, , drop = FALSE]
    python <- python[match(names(r_scores), python$feature), , drop = FALSE]
    expect_false(anyNA(python$feature), info = case_name)

    spearman <- suppressWarnings(stats::cor(r_scores, python$max_stability_score, method = "spearman"))
    r_top5 <- names(sort(r_scores, decreasing = TRUE))[seq_len(5L)]
    python_top5 <- python$feature[order(python$rank, match(python$feature, colnames(x)))][seq_len(5L)]
    top5_overlap <- length(intersect(r_top5, python_top5))
    r_support <- names(r_scores)[r_scores > case$hard_threshold[[1L]]]
    python_support <- python$feature[python$selected == 1L]
    support_union <- union(r_support, python_support)
    jaccard <- if (length(support_union)) {
      length(intersect(r_support, python_support)) / length(support_union)
    } else {
      0
    }

    expect_true(length(unique(r_scores)) > 1L,
                info = paste(case_name, "R scores must not be constant"))
    expect_true(length(unique(python$max_stability_score)) > 1L,
                info = paste(case_name, "Python scores must not be constant"))
    expect_true(spearman >= case$spearman_min[[1L]],
                info = paste(case_name, "Spearman", spearman))
    expect_true(top5_overlap >= case$top5_overlap_min[[1L]],
                info = paste(case_name, "top-five overlap", top5_overlap))
    expect_true(jaccard >= case$jaccard_min[[1L]],
                info = paste(case_name, "support Jaccard", jaccard))
    expect_true(all(paste0("signal_", 1:3) %in% r_top5), info = case_name)
    expect_true(all(paste0("signal_", 1:3) %in% python_top5), info = case_name)
  }
})
