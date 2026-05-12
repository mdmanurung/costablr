library(stablr)

# ── Shared fixtures ───────────────────────────────────────────────────────────

.make_fit <- function(seed = 1L, n = 40L, p = 8L, family = "gaussian",
                      artificial_type = "random_permutation",
                      hard_threshold = NULL, n_bootstraps = 8L) {
  set.seed(seed)
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)),
                               paste0("f", seq_len(p))))
  if (family == "binomial") {
    y <- setNames(sample(0:1, n, replace = TRUE), rownames(x))
  } else if (family == "multinomial") {
    y <- setNames(factor(sample(c("A","B","C"), n, replace = TRUE)), rownames(x))
  } else {
    y <- setNames(rnorm(n), rownames(x))
  }
  lam_grid <- data.frame(lambda = seq(0.05, 0.4, length.out = 4L))
  suppressWarnings(stabl_fit(
    x               = x,
    y               = y,
    lambda_grid     = lam_grid,
    family          = family,
    n_bootstraps    = n_bootstraps,
    artificial_type = artificial_type,
    hard_threshold  = hard_threshold,
    random_state    = seed
  ))
}

.load_real_biobank_binary_fixture <- function(max_features = 48L) {
  anchored_zip <- testthat::test_path("..", "..", "..", "..", "Sample Data", "data.zip")
  zip_candidates <- c(
    anchored_zip,
    file.path("Sample Data", "data.zip"),
    file.path("..", "Sample Data", "data.zip"),
    file.path("..", "..", "Sample Data", "data.zip")
  )
  existing <- zip_candidates[file.exists(zip_candidates)]
  if (length(existing) == 0L) {
    skip("Sample Data/data.zip not available in workspace.")
  }
  zip_path <- existing[[1L]]

  prot <- utils::read.csv(
    unz(zip_path, "Biobank SSI/Proteomics.csv"),
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out <- utils::read.csv(
    unz(zip_path, "Biobank SSI/outcome.csv"),
    stringsAsFactors = FALSE
  )

  if (!all(c("sampleID", "model1b") %in% colnames(out))) {
    skip("Biobank SSI outcome schema does not match expected columns.")
  }
  if (!"sampleID" %in% colnames(prot)) {
    skip("Biobank SSI proteomics schema does not contain sampleID.")
  }

  ids <- intersect(prot$sampleID, out$sampleID)
  if (length(ids) < 20L) {
    skip("Not enough aligned samples in Biobank SSI fixture.")
  }

  prot <- prot[match(ids, prot$sampleID), , drop = FALSE]
  out <- out[match(ids, out$sampleID), , drop = FALSE]

  n_feat <- min(max_features, ncol(prot) - 1L)
  x <- as.matrix(prot[, seq.int(2L, n_feat + 1L), drop = FALSE])
  storage.mode(x) <- "double"
  rownames(x) <- prot$sampleID

  y <- as.numeric(out$model1b)
  names(y) <- out$sampleID

  keep <- !is.na(y)
  x <- x[keep, , drop = FALSE]
  y <- y[keep]

  if (length(unique(y)) < 2L) {
    skip("Biobank SSI fixture requires at least two classes for binomial fit.")
  }

  list(x = x, y = y)
}

.load_python_metrics_reference <- function() {
  base_dir <- testthat::test_path("fixtures", "python_parity")
  scalars <- utils::read.csv(
    file.path(base_dir, "metrics_scalars.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  vectors <- utils::read.csv(
    file.path(base_dir, "metrics_vectors.csv"),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )

  list(
    scalars = stats::setNames(scalars$value, scalars$metric),
    vectors = vectors
  )
}

.get_python_metric_vector <- function(reference, metric_name) {
  rows <- reference$vectors[reference$vectors$metric == metric_name, , drop = FALSE]
  rows <- rows[order(rows$index), , drop = FALSE]
  rows$value
}

.python_metric_inputs <- function() {
  list(
    pair_pred = c("f1", "f2", "f5"),
    pair_true = c("f2", "f3", "f6"),
    list_of_lists = list(
      c("f1", "f2", "f3"),
      c("f2", "f3", "f4"),
      c("f1", "f4"),
      character(0)
    ),
    nb_total = 8L,
    d = 8L
  )
}

# ── metrics.R ─────────────────────────────────────────────────────────────────

test_that("jaccard_similarity returns 0 for disjoint sets", {
  expect_equal(jaccard_similarity(c("a","b"), c("c","d")), 0)
})

test_that("jaccard_similarity returns 1 for identical sets", {
  expect_equal(jaccard_similarity(c("x","y","z"), c("x","y","z")), 1)
})

test_that("jaccard_similarity correct partial overlap", {
  # intersection={b}, union={a,b,c} -> 1/3
  expect_equal(jaccard_similarity(c("a","b"), c("b","c")), 1/3)
})

test_that("jaccard_similarity both empty returns 0", {
  expect_equal(jaccard_similarity(character(0), character(0)), 0)
})

test_that("jaccard_matrix returns correct dimensions with remove_diag", {
  lists <- list(c("a","b"), c("b","c"), c("a","c"))
  mat <- jaccard_matrix(lists, remove_diag = TRUE)
  # Python parity: N lists -> N rows and (N - 1) columns.
  expect_equal(nrow(mat), 3L)
  expect_equal(ncol(mat), 2L)
})

test_that("metrics functions match frozen Python reference values", {
  ref <- .load_python_metrics_reference()
  inp <- .python_metric_inputs()
  tol <- 1e-12

  expect_equal(
    jaccard_similarity(inp$pair_pred, inp$pair_true),
    unname(ref$scalars[["jaccard_similarity_pair"]]),
    tolerance = tol
  )
  expect_equal(
    adjusted_similarity(inp$pair_pred, inp$pair_true, inp$nb_total),
    unname(ref$scalars[["adjusted_similarity_pair"]]),
    tolerance = tol
  )
  expect_equal(
    pearson_similarity(inp$pair_pred, inp$pair_true, inp$d),
    unname(ref$scalars[["pearson_similarity_pair"]]),
    tolerance = tol
  )
  expect_equal(
    fdr_similarity(inp$pair_pred, inp$pair_true),
    unname(ref$scalars[["fdr_similarity_pair"]]),
    tolerance = tol
  )
  expect_equal(
    tpr_similarity(inp$pair_pred, inp$pair_true),
    unname(ref$scalars[["tpr_similarity_pair"]]),
    tolerance = tol
  )
  expect_equal(
    fscore_similarity(inp$pair_pred, inp$pair_true, beta = 1),
    unname(ref$scalars[["fscore_similarity_beta1_pair"]]),
    tolerance = tol
  )
  expect_equal(
    fscore_similarity(inp$pair_pred, inp$pair_true, beta = 2),
    unname(ref$scalars[["fscore_similarity_beta2_pair"]]),
    tolerance = tol
  )

  r_jaccard_rowmajor <- as.vector(t(jaccard_matrix(inp$list_of_lists, remove_diag = TRUE)))
  expect_equal(
    r_jaccard_rowmajor,
    .get_python_metric_vector(ref, "jaccard_matrix_remove_diag_rowmajor"),
    tolerance = tol
  )

  expect_equal(
    adjusted_similarity_values(inp$list_of_lists, inp$nb_total),
    .get_python_metric_vector(ref, "adjusted_similarity_values"),
    tolerance = tol
  )
  expect_equal(
    pearson_similarity_values(inp$list_of_lists, inp$d),
    .get_python_metric_vector(ref, "pearson_similarity_values"),
    tolerance = tol
  )

  adj_med <- adjusted_similarity_measure(inp$list_of_lists, inp$nb_total, stat = "median")
  expect_equal(
    adj_med$statistic,
    unname(ref$scalars[["adjusted_similarity_measure_median_stat"]]),
    tolerance = tol
  )
  expect_equal(
    adj_med$err,
    c(
      unname(ref$scalars[["adjusted_similarity_measure_median_err_q25"]]),
      unname(ref$scalars[["adjusted_similarity_measure_median_err_q75"]])
    ),
    tolerance = tol
  )

  adj_mean <- adjusted_similarity_measure(inp$list_of_lists, inp$nb_total, stat = "mean")
  expect_equal(
    adj_mean$statistic,
    unname(ref$scalars[["adjusted_similarity_measure_mean_stat"]]),
    tolerance = tol
  )
  expect_equal(
    adj_mean$err,
    unname(ref$scalars[["adjusted_similarity_measure_mean_err_sd"]]),
    tolerance = tol
  )

  pear_med <- pearson_similarity_measure(inp$list_of_lists, inp$d, stat = "median")
  expect_equal(
    pear_med$statistic,
    unname(ref$scalars[["pearson_similarity_measure_median_stat"]]),
    tolerance = tol
  )
  expect_equal(
    pear_med$err,
    c(
      unname(ref$scalars[["pearson_similarity_measure_median_err_q25"]]),
      unname(ref$scalars[["pearson_similarity_measure_median_err_q75"]])
    ),
    tolerance = tol
  )

  pear_mean <- pearson_similarity_measure(inp$list_of_lists, inp$d, stat = "mean")
  expect_equal(
    pear_mean$statistic,
    unname(ref$scalars[["pearson_similarity_measure_mean_stat"]]),
    tolerance = tol
  )
  expect_equal(
    pear_mean$err,
    unname(ref$scalars[["pearson_similarity_measure_mean_err_sd"]]),
    tolerance = tol
  )
})

test_that("adjusted_similarity zero for empty set", {
  expect_equal(adjusted_similarity(character(0), c("a","b"), 10L), 0)
})

test_that("adjusted_similarity zero when set equals universe", {
  all_feats <- letters[1:5]
  expect_equal(adjusted_similarity(all_feats, all_feats[1:3], 5L), 0)
})

test_that("adjusted_similarity errors when union > nb_total_elements", {
  expect_error(
    adjusted_similarity(letters[1:5], letters[6:10], 8L),
    "exceeds"
  )
})

test_that("adjusted_similarity_values returns upper-triangle vector", {
  lists <- list(c("a","b","c"), c("b","c","d"), c("a","c","d"), c("a","b","d"))
  vals  <- adjusted_similarity_values(lists, 6L)
  expect_length(vals, 4L * 3L / 2L)  # n*(n-1)/2 = 6
  expect_true(all(is.numeric(vals)))
})

test_that("adjusted_similarity_measure median returns list with statistic and err", {
  lists <- list(c("a","b"), c("b","c"), c("a","c"))
  res   <- adjusted_similarity_measure(lists, 5L, stat = "median")
  expect_named(res, c("statistic", "err"))
  expect_length(res$err, 2L)
})

test_that("adjusted_similarity_measure mean returns sd as err", {
  lists <- list(c("a","b"), c("b","c"), c("a","c"))
  res   <- adjusted_similarity_measure(lists, 5L, stat = "mean")
  expect_named(res, c("statistic", "err"))
  expect_length(res$err, 1L)
})

test_that("adjusted_similarity_measure errors on unknown stat", {
  lists <- list(c("a","b"), c("b","c"))
  expect_error(adjusted_similarity_measure(lists, 5L, stat = "mode"), "mean")
})

test_that("pearson_similarity returns 1 when both sets empty", {
  expect_equal(pearson_similarity(character(0), character(0), 10L), 1)
})

test_that("pearson_similarity returns 0 when one set empty", {
  expect_equal(pearson_similarity(character(0), c("a","b"), 10L), 0)
})

test_that("pearson_similarity_values upper-triangle length", {
  lists <- list(c("a","b"), c("b","c"), c("c","d"))
  vals  <- pearson_similarity_values(lists, 6L)
  expect_length(vals, 3L)  # 3*(3-1)/2 = 3
})

test_that("pearson_similarity_measure returns correct structure", {
  lists <- list(c("a","b"), c("b","c"), c("a","d"))
  res   <- pearson_similarity_measure(lists, 6L)
  expect_named(res, c("statistic", "err"))
})

test_that("fdr_similarity is 0 when predicted set is empty", {
  expect_equal(fdr_similarity(character(0), c("a","b")), 0)
})

test_that("fdr_similarity is 0 when predicted = true", {
  expect_equal(fdr_similarity(c("a","b"), c("a","b")), 0)
})

test_that("fdr_similarity correct partial FDR", {
  # predicted {a,b,c}, true {a,b} -> FP=1, TP=2 -> FDR=1/3
  expect_equal(fdr_similarity(c("a","b","c"), c("a","b")), 1/3)
})

test_that("tpr_similarity is 0 when true set is empty", {
  expect_equal(tpr_similarity(c("a"), character(0)), 0)
})

test_that("tpr_similarity is 1 when all true features recovered", {
  expect_equal(tpr_similarity(c("a","b","c"), c("a","b")), 1)
})

test_that("fscore_similarity returns 1 for perfect match", {
  expect_equal(fscore_similarity(c("a","b"), c("a","b")), 1)
})

test_that("fscore_similarity returns 0 for empty predicted with non-empty true", {
  expect_equal(fscore_similarity(character(0), c("a","b")), 0)
})

# ── exports.R ─────────────────────────────────────────────────────────────────

test_that("export_stabl_to_csv writes expected files", {
  fit  <- .make_fit()
  path <- tempfile("stablr_test_export")
  on.exit(unlink(path, recursive = TRUE))

  export_stabl_to_csv(fit, path)

  expect_true(file.exists(file.path(path, "STABL scores.csv")))
  expect_true(file.exists(file.path(path, "Max STABL scores.csv")))
  expect_true(file.exists(file.path(path, "STABL artificial scores.csv")))
  expect_true(file.exists(file.path(path, "Max STABL artificial scores.csv")))
})

test_that("export_stabl_to_csv skips artificial files when no artificial_type", {
  fit  <- .make_fit(artificial_type = NULL, hard_threshold = 0.3)
  path <- tempfile("stablr_test_export_noart")
  on.exit(unlink(path, recursive = TRUE))

  export_stabl_to_csv(fit, path)

  expect_true(file.exists(file.path(path, "STABL scores.csv")))
  expect_false(file.exists(file.path(path, "STABL artificial scores.csv")))
})

test_that("export_stabl_to_csv STABL scores.csv has correct dimensions", {
  n <- 30L; p <- 6L; n_lambda <- 4L
  set.seed(10)
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))
  lam <- data.frame(lambda = seq(0.05, 0.4, length.out = n_lambda))
  fit <- stabl_fit(x = x, y = y, lambda_grid = lam, n_bootstraps = 5L,
                   artificial_type = "random_permutation", random_state = 10L)

  path <- tempfile("stablr_csv_dim")
  on.exit(unlink(path, recursive = TRUE))
  export_stabl_to_csv(fit, path)

  df <- utils::read.csv(file.path(path, "STABL scores.csv"), row.names = 1L)
  expect_equal(nrow(df), p)
  expect_equal(ncol(df), n_lambda)
})

test_that("save_stabl_results creates directory structure", {
  skip_if_not_installed("ggplot2")
  fit  <- .make_fit()
  n <- 40L; p <- 8L
  set.seed(1L)
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))

  path <- tempfile("stablr_test_save")
  on.exit(unlink(path, recursive = TRUE))

  save_stabl_results(
    object    = fit,
    path      = path,
    x         = x,
    y         = y,
    task_type = "regression",
    figure_fmt = "png"
  )

  expect_true(dir.exists(path))
  expect_true(file.exists(file.path(path, "STABL scores.csv")))
  expect_true(file.exists(file.path(path, "Stability Path.png")))
  expect_true(dir.exists(file.path(path, "Selected Features")))
})

test_that("save_stabl_results errors when directory exists and override = FALSE", {
  skip_if_not_installed("ggplot2")
  fit  <- .make_fit()
  path <- tempfile("stablr_test_override")
  dir.create(path)
  on.exit(unlink(path, recursive = TRUE))

  set.seed(1L); n <- 40L; p <- 8L
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))

  expect_error(
    save_stabl_results(fit, path, x = x, y = y),
    "already exists"
  )
})

test_that("real-data Biobank SSI export helpers write stable artifact schema", {
  skip_if_not_installed("ggplot2")

  fixture <- .load_real_biobank_binary_fixture(max_features = 48L)
  lambda_grid <- data.frame(lambda = c(0.02, 0.05, 0.10))

  fit <- suppressWarnings(stabl_fit(
    x               = fixture$x,
    y               = fixture$y,
    family          = "binomial",
    lambda_grid     = lambda_grid,
    n_bootstraps    = 4L,
    artificial_type = "random_permutation",
    random_state    = 2026L
  ))

  csv_path <- tempfile("stablr_real_data_csv")
  save_path <- tempfile("stablr real data save")
  on.exit(unlink(c(csv_path, save_path), recursive = TRUE), add = TRUE)

  export_stabl_to_csv(fit, csv_path)

  scores_csv <- utils::read.csv(
    file.path(csv_path, "STABL scores.csv"),
    row.names = 1L,
    check.names = FALSE
  )
  max_csv <- utils::read.csv(
    file.path(csv_path, "Max STABL scores.csv"),
    row.names = 1L,
    check.names = FALSE
  )

  expect_equal(nrow(scores_csv), ncol(fixture$x))
  expect_equal(ncol(scores_csv), nrow(fit$fitted_lambda_grid))
  expect_equal(colnames(scores_csv), stablr:::.lambda_grid_row_labels(fit$fitted_lambda_grid))
  expect_true(all(diff(max_csv[["Max Proba"]]) <= 0))

  save_stabl_results(
    object     = fit,
    path       = save_path,
    x          = fixture$x,
    y          = fixture$y,
    task_type  = "binary",
    figure_fmt = "png",
    override   = TRUE
  )

  expect_true(file.exists(file.path(save_path, "STABL scores.csv")))
  expect_true(file.exists(file.path(save_path, "Stability Path.png")))
  expect_true(file.exists(file.path(save_path, "FDR Graph.png")))
  expect_true(file.exists(file.path(save_path, "Selected Features", "Selected features.csv")))

  selected_df <- utils::read.csv(
    file.path(save_path, "Selected Features", "Selected features.csv"),
    check.names = FALSE
  )
  expect_true("Feature Name" %in% colnames(selected_df))
})

# ── visualization.R ──────────────────────────────────────────────────────────

test_that("plot_stabl_path returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  fit <- .make_fit()
  p   <- plot_stabl_path(fit)
  expect_s3_class(p, "ggplot")
})

test_that("plot_stabl_path works with hard_threshold fit", {
  skip_if_not_installed("ggplot2")
  fit <- .make_fit(artificial_type = NULL, hard_threshold = 0.3)
  p   <- plot_stabl_path(fit)
  expect_s3_class(p, "ggplot")
})

test_that("plot_stabl_path works with mixed-alpha grid", {
  skip_if_not_installed("ggplot2")
  set.seed(99)
  n <- 50L; p <- 8L
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- setNames(rnorm(n), rownames(x))
  lam_grid <- auto_lambda_grid(x, y, family = "gaussian",
                                n_lambda = 4L, l1_ratio = c(0.4, 0.8))
  fit <- stabl_fit(x = x, y = y, lambda_grid = lam_grid,
                   base_learner = "elastic_net",
                   n_bootstraps = 6L, artificial_type = "random_permutation",
                   random_state = 99L)
  p <- plot_stabl_path(fit)
  expect_s3_class(p, "ggplot")
})

test_that("plot_fdr_graph returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  fit <- .make_fit()
  p   <- plot_fdr_graph(fit)
  expect_s3_class(p, "ggplot")

  built <- ggplot2::ggplot_build(p)
  hline <- built$data[[length(built$data)]]
  expect_equal(unique(hline$yintercept), 0.05)
})

test_that("plot_fdr_graph errors when no FDRs_ present", {
  skip_if_not_installed("ggplot2")
  fit <- .make_fit(artificial_type = NULL, hard_threshold = 0.3)
  expect_error(plot_fdr_graph(fit), "artificial_type")
})

test_that("plot_fdr_graph validates fdr_target", {
  skip_if_not_installed("ggplot2")
  fit <- .make_fit()
  expect_error(plot_fdr_graph(fit, fdr_target = -0.1), "fdr_target")
  expect_s3_class(plot_fdr_graph(fit, fdr_target = NULL), "ggplot")
})

test_that("plot_roc returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  set.seed(1L)
  y_true  <- rbinom(80, 1, 0.4)
  y_preds <- plogis(2 * y_true + rnorm(80))
  p       <- plot_roc(y_true, y_preds)
  expect_s3_class(p, "ggplot")
})

test_that("plot_roc errors on mismatched lengths", {
  skip_if_not_installed("ggplot2")
  expect_error(plot_roc(c(0,1,0), c(0.2, 0.8)), "same length")
})

test_that("plot_prc returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  set.seed(2L)
  y_true  <- rbinom(80, 1, 0.3)
  y_preds <- plogis(2 * y_true + rnorm(80))
  p       <- plot_prc(y_true, y_preds)
  expect_s3_class(p, "ggplot")
})

test_that("plot_prc with show_iso = FALSE returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  set.seed(3L)
  y_true  <- rbinom(60, 1, 0.4)
  y_preds <- plogis(y_true + rnorm(60))
  p       <- plot_prc(y_true, y_preds, show_iso = FALSE)
  expect_s3_class(p, "ggplot")
})

test_that("boxplot_features returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  set.seed(4L)
  n <- 40L; p <- 6L
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- factor(sample(c("A","B"), n, replace = TRUE))
  p_plot <- boxplot_features(c("f1","f2","f3"), x, y)
  expect_s3_class(p_plot, "ggplot")
})

test_that("boxplot_features errors when no requested features are in x", {
  skip_if_not_installed("ggplot2")
  x <- matrix(rnorm(20), 10, 2,
               dimnames = list(NULL, c("a","b")))
  y <- factor(sample(c("X","Y"), 10, replace = TRUE))
  expect_error(boxplot_features(c("z","w"), x, y), "None of the requested")
})

test_that("scatterplot_features returns a ggplot object", {
  skip_if_not_installed("ggplot2")
  set.seed(5L)
  n <- 40L; p <- 5L
  x <- matrix(rnorm(n * p), n, p,
               dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p))))
  y <- rnorm(n)
  p_plot <- scatterplot_features(c("f1","f2"), x, y)
  expect_s3_class(p_plot, "ggplot")
})

test_that("scatterplot_features silently skips missing features", {
  skip_if_not_installed("ggplot2")
  set.seed(6L)
  n <- 30L
  x <- matrix(rnorm(n * 4), n, 4,
               dimnames = list(NULL, paste0("f", 1:4)))
  y <- rnorm(n)
  # "f99" is not in x; only f1 and f2 should be plotted
  p_plot <- scatterplot_features(c("f1","f2","f99"), x, y)
  expect_s3_class(p_plot, "ggplot")
})
