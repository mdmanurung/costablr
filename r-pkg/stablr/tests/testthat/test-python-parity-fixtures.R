load_python_parity_case <- function(case_name) {
  case_dir <- testthat::test_path("fixtures", "python_parity", case_name)

  x <- as.matrix(read.csv(file.path(case_dir, "x.csv"), row.names = 1L, check.names = FALSE))
  y_tbl <- read.csv(file.path(case_dir, "y.csv"), row.names = 1L, check.names = FALSE)

  score_tbl <- read.csv(file.path(case_dir, "python_feature_scores.csv"), check.names = FALSE)
  ranked_tbl <- read.csv(file.path(case_dir, "python_ranked_features.csv"), check.names = FALSE)
  selected_tbl <- read.csv(file.path(case_dir, "python_selected_features.csv"), check.names = FALSE)

  list(
    x = x,
    y = y_tbl$y,
    py_mean_scores = stats::setNames(score_tbl$python_mean_score, score_tbl$feature),
    py_ranked_features = ranked_tbl$feature,
    py_selected_features = selected_tbl$feature
  )
}

expect_python_parity <- function(fit, py_mean_scores, py_ranked_features, py_selected_features) {
  r_mean_scores <- rowMeans(fit$stabl_scores_)
  r_mean_scores <- r_mean_scores[names(py_mean_scores)]

  expect_true(all(is.finite(r_mean_scores)))

  py_top2 <- py_ranked_features[1:2]
  r_top3 <- names(sort(r_mean_scores, decreasing = TRUE))[1:3]

  # Cross-language parity check: Python's strongest features should remain
  # strong in R even though underlying solvers and lambda conventions differ.
  expect_gte(length(intersect(py_top2, r_top3)), 1L)
  expect_gt(mean(r_mean_scores[py_top2]), stats::median(r_mean_scores))

  r_top5 <- names(sort(r_mean_scores, decreasing = TRUE))[1:5]
  expect_gte(length(intersect(py_selected_features, r_top5)), 1L)
}

test_that("frozen Python parity fixture agrees for gaussian lasso signal ranking", {
  fixture <- load_python_parity_case("gaussian")

  fit <- stabl_fit(
    x = fixture$x,
    y = stats::setNames(as.numeric(fixture$y), rownames(fixture$x)),
    lambda_grid = data.frame(lambda = exp(seq(log(0.30), log(0.01), length.out = 6L))),
    base_learner = "lasso",
    family = "gaussian",
    n_bootstraps = 60L,
    artificial_type = "random_permutation",
    random_state = 101L
  )

  expect_python_parity(
    fit = fit,
    py_mean_scores = fixture$py_mean_scores,
    py_ranked_features = fixture$py_ranked_features,
    py_selected_features = fixture$py_selected_features
  )
})

test_that("frozen Python parity fixture agrees for binomial lasso signal ranking", {
  fixture <- load_python_parity_case("binomial")

  fit <- suppressWarnings(stabl_fit(
    x = fixture$x,
    y = stats::setNames(as.integer(fixture$y), rownames(fixture$x)),
    lambda_grid = data.frame(lambda = exp(seq(log(0.40), log(0.02), length.out = 6L))),
    base_learner = "lasso",
    family = "binomial",
    n_bootstraps = 60L,
    artificial_type = "random_permutation",
    random_state = 102L
  ))

  expect_python_parity(
    fit = fit,
    py_mean_scores = fixture$py_mean_scores,
    py_ranked_features = fixture$py_ranked_features,
    py_selected_features = fixture$py_selected_features
  )
})

test_that("frozen Python parity fixture agrees for multinomial lasso signal ranking", {
  fixture <- load_python_parity_case("multinomial")

  fit <- suppressWarnings(stabl_fit(
    x = fixture$x,
    y = stats::setNames(factor(fixture$y), rownames(fixture$x)),
    lambda_grid = data.frame(lambda = exp(seq(log(0.35), log(0.02), length.out = 6L))),
    base_learner = "lasso",
    family = "multinomial",
    n_bootstraps = 50L,
    artificial_type = "random_permutation",
    random_state = 103L
  ))

  expect_python_parity(
    fit = fit,
    py_mean_scores = fixture$py_mean_scores,
    py_ranked_features = fixture$py_ranked_features,
    py_selected_features = fixture$py_selected_features
  )
})

test_that("frozen Python parity fixture agrees for gaussian elastic-net signal ranking", {
  fixture <- load_python_parity_case("gaussian_elastic_net")

  fit <- stabl_fit(
    x = fixture$x,
    y = stats::setNames(as.numeric(fixture$y), rownames(fixture$x)),
    lambda_grid = data.frame(
      alpha = rep(0.6, 6L),
      lambda = exp(seq(log(0.30), log(0.01), length.out = 6L))
    ),
    base_learner = "elastic_net",
    family = "gaussian",
    n_bootstraps = 60L,
    artificial_type = "random_permutation",
    random_state = 104L
  )

  expect_python_parity(
    fit = fit,
    py_mean_scores = fixture$py_mean_scores,
    py_ranked_features = fixture$py_ranked_features,
    py_selected_features = fixture$py_selected_features
  )
})

test_that("frozen Python parity fixture agrees for binomial elastic-net signal ranking", {
  fixture <- load_python_parity_case("binomial_elastic_net")

  fit <- suppressWarnings(stabl_fit(
    x = fixture$x,
    y = stats::setNames(as.integer(fixture$y), rownames(fixture$x)),
    lambda_grid = data.frame(
      alpha = rep(0.6, 6L),
      lambda = exp(seq(log(0.40), log(0.02), length.out = 6L))
    ),
    base_learner = "elastic_net",
    family = "binomial",
    n_bootstraps = 60L,
    artificial_type = "random_permutation",
    random_state = 105L
  ))

  expect_python_parity(
    fit = fit,
    py_mean_scores = fixture$py_mean_scores,
    py_ranked_features = fixture$py_ranked_features,
    py_selected_features = fixture$py_selected_features
  )
})
