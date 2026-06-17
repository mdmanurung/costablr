#!/usr/bin/env Rscript
# Generate publication-scale OOL proteomics parity metrics for the Application Note.
#
# Requires the full repository tutorial data at Sample Data/Onset of Labor unless
# --allow-bundled is passed (development only; not the manuscript reference).
#
# Usage (from repository root):
#   Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R
#   Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R --outdir papers/application-note/artifacts

`%||%` <- function(x, y) if (is.null(x)) y else x

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  outdir <- "papers/application-note/artifacts"
  allow_bundled <- FALSE
  if (length(args) > 0L) {
    i <- match("--outdir", args)
    if (!is.na(i) && i < length(args)) outdir <- args[[i + 1L]]
    allow_bundled <- "--allow-bundled" %in% args
  }
  list(outdir = outdir, allow_bundled = allow_bundled)
}

find_repo_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  script_file <- grep("^--file=", args, value = TRUE)
  start <- if (length(script_file) > 0L) {
    dirname(normalizePath(sub("^--file=", "", script_file[[1L]]), winslash = "/", mustWork = TRUE))
  } else {
    getwd()
  }
  path <- start
  repeat {
    if (file.exists(file.path(path, "r-pkg", "stablr", "DESCRIPTION"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  stop("Could not locate repository root.", call. = FALSE)
}

find_tutorial_dir <- function(repo) {
  candidates <- file.path(repo, "Sample Data", "Onset of Labor")
  if (dir.exists(candidates)) {
    return(normalizePath(candidates, winslash = "/", mustWork = TRUE))
  }
  NA_character_
}

read_named_vector <- function(path, column = 1L) {
  df <- read.csv(path, row.names = 1, check.names = FALSE)
  setNames(df[[column]], rownames(df))
}

preprocess_fit <- function(x, min_var = 0, max_nan_fraction = 0.2) {
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  col_vars <- apply(x, 2L, stats::var, na.rm = TRUE)
  keep_cols <- col_vars > min_var & colSums(is.na(x)) <= max_nan_fraction * nrow(x)
  x <- x[, keep_cols, drop = FALSE]
  col_medians <- apply(x, 2L, stats::median, na.rm = TRUE)
  col_medians[is.na(col_medians)] <- 0
  for (j in seq_along(col_medians)) {
    na_idx <- is.na(x[, j])
    if (any(na_idx)) x[na_idx, j] <- col_medians[[j]]
  }
  col_means <- colMeans(x)
  col_sds <- sqrt(colMeans(sweep(x, 2, col_means)^2))
  col_sds[col_sds < 1e-10] <- 1
  sweep(sweep(x, 2, col_means), 2, col_sds, "/")
}

jaccard_sets <- function(a, b) {
  a <- unique(a)
  b <- unique(b)
  if (length(a) == 0L && length(b) == 0L) return(1)
  length(intersect(a, b)) / length(union(a, b))
}

load_stablr <- function(pkg_root) {
  if (dir.exists(file.path(pkg_root, "R"))) {
    if (requireNamespace("pkgload", quietly = TRUE)) {
      suppressPackageStartupMessages(pkgload::load_all(pkg_root, quiet = TRUE))
      return(invisible(getNamespace("stablr")))
    }
    if (requireNamespace("devtools", quietly = TRUE)) {
      suppressPackageStartupMessages(devtools::load_all(pkg_root, quiet = TRUE))
      return(invisible(getNamespace("stablr")))
    }
  }
  if (requireNamespace("stablr", quietly = TRUE)) {
    suppressPackageStartupMessages(library(stablr))
    return(invisible(getNamespace("stablr")))
  }
  stop(
    "Load stablr before running this script: install the package or add ",
    "pkgload/devtools to run from source.",
    call. = FALSE
  )
}

package_version_string <- function(pkg_root, pkg = "stablr") {
  ver <- tryCatch(
    as.character(utils::packageVersion(pkg)),
    error = function(e) NULL
  )
  if (!is.null(ver)) return(ver)
  desc_path <- file.path(pkg_root, "DESCRIPTION")
  if (!file.exists(desc_path)) return("unknown")
  fields <- read.dcf(desc_path)
  unname(fields[1, "Version"])
}

load_python_reference <- function(pkg_root) {
  ref_path <- file.path(pkg_root, "inst", "analysis", "data",
                        "ool_python_tutorial_reference.csv")
  if (!file.exists(ref_path)) {
    stop("Missing reference file: ", ref_path, call. = FALSE)
  }
  ref <- read.csv(ref_path, stringsAsFactors = FALSE)
  list(
    features = ref$feature,
    scores_path = file.path(pkg_root, "inst", "analysis", "data",
                            "ool_python_tutorial_scores.csv")
  )
}

load_ool_proteomics <- function(repo, allow_bundled = FALSE) {
  ool_dir <- find_tutorial_dir(repo)
  if (!is.na(ool_dir)) {
    prot_train <- read.csv(
      file.path(ool_dir, "Training", "Proteomics.csv"),
      row.names = 1, check.names = FALSE
    )
    y_train <- read_named_vector(file.path(ool_dir, "Training", "DOS.csv"))
    common <- intersect(rownames(prot_train), names(y_train))
    return(list(
      x_raw = prot_train[common, , drop = FALSE],
      y = y_train[common],
      data_source = "repository_tutorial"
    ))
  }
  if (!isTRUE(allow_bundled)) {
    stop(
      "Publication parity requires Sample Data/Onset of Labor at the repository root. ",
      "The bundled extdata subset is not the manuscript reference dataset. ",
      "Pass --allow-bundled only for local smoke checks.",
      call. = FALSE
    )
  }
  ool_train <- load_ool_data("train")
  list(
    x_raw = ool_train$x_list$proteomics,
    y = ool_train$y,
    data_source = "bundled_extdata"
  )
}

spearman_on_common <- function(r_scores, py_scores) {
  common <- intersect(names(r_scores), names(py_scores))
  if (length(common) < 2L) return(NA_real_)
  stats::cor(r_scores[common], py_scores[common], method = "spearman")
}

main <- function() {
  cfg <- parse_args()
  repo <- find_repo_root()
  pkg_root <- file.path(repo, "r-pkg", "stablr")
  load_stablr(pkg_root)

  outdir <- file.path(repo, cfg$outdir)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

  py_ref <- load_python_reference(pkg_root)
  loaded <- load_ool_proteomics(repo, allow_bundled = cfg$allow_bundled)
  x_fit <- preprocess_fit(loaded$x_raw)
  y <- loaded$y[rownames(x_fit)]

  n_boot <- 500L
  n_lambda <- 10L
  seed <- 42L
  t0 <- proc.time()[["elapsed"]]

  lambda_grid <- auto_lambda_grid(
    x_fit, y, family = "gaussian", n_lambda = n_lambda
  )

  fit <- stabl_fit(
    x = x_fit,
    y = y,
    lambda_grid = lambda_grid,
    base_learner = "lasso",
    family = "gaussian",
    n_bootstraps = n_boot,
    artificial_type = "knockoff",
    fdr_threshold_range = seq(0, 1, by = 0.01),
    random_state = seed,
    workers = 1L
  )

  runtime_sec <- proc.time()[["elapsed"]] - t0
  selected <- get_feature_names_out(fit)
  importances <- get_importances(fit)
  py_features <- py_ref$features
  overlap <- intersect(selected, py_features)

  py_scores <- NULL
  if (file.exists(py_ref$scores_path)) {
    score_tbl <- read.csv(py_ref$scores_path, stringsAsFactors = FALSE)
    if (all(c("feature", "python_max_score") %in% names(score_tbl))) {
      py_scores <- stats::setNames(score_tbl$python_max_score, score_tbl$feature)
    }
  }

  metrics <- data.frame(
    dataset = "OOL_proteomics",
    data_source = loaded$data_source,
    n = nrow(x_fit),
    p = ncol(x_fit),
    family = "gaussian",
    base_learner = "lasso",
    artificial_type = "knockoff",
    n_bootstraps = n_boot,
    n_lambda = n_lambda,
    n_selected_r = length(selected),
    n_selected_python_reference = length(py_features),
    jaccard_r_vs_python_reference = jaccard_sets(selected, py_features),
    tutorial_recall = length(overlap),
    tutorial_total = length(py_features),
    spearman_max_importance = if (is.null(py_scores)) {
      NA_real_
    } else {
      spearman_on_common(importances, py_scores)
    },
    runtime_min = round(runtime_sec / 60, 2),
    glmnet_version = as.character(utils::packageVersion("glmnet")),
    stablr_version = package_version_string(pkg_root),
    stringsAsFactors = FALSE
  )

  selected_df <- data.frame(
    feature = selected,
    importance = importances[selected],
    in_python_tutorial_reference = selected %in% py_features,
    stringsAsFactors = FALSE
  )
  selected_df <- selected_df[order(-selected_df$importance), , drop = FALSE]

  overlap_df <- data.frame(
    feature = py_features,
    selected_by_stablr = py_features %in% selected,
    stringsAsFactors = FALSE
  )

  utils::write.csv(metrics, file.path(outdir, "ool_publication_parity_metrics.csv"), row.names = FALSE)
  utils::write.csv(selected_df, file.path(outdir, "ool_publication_selected_features.csv"), row.names = FALSE)
  utils::write.csv(overlap_df, file.path(outdir, "ool_publication_tutorial_overlap.csv"), row.names = FALSE)
  writeLines(capture.output(sessionInfo()), file.path(outdir, "ool_publication_sessionInfo.txt"))

  if (requireNamespace("ggplot2", quietly = TRUE)) {
    fdr_path <- file.path(outdir, "ool_publication_fdr_graph.pdf")
    grDevices::pdf(fdr_path, width = 7, height = 5)
    on.exit(grDevices::dev.off(), add = TRUE)
    print(plot_fdr_graph(fit, title = "OOL proteomics (publication-scale stablr)"))
  }

  message("Wrote publication parity artifacts to: ", outdir)
  print(metrics)
  message("Tutorial overlap: ", paste(overlap, collapse = ", "))
  if (is.na(metrics$spearman_max_importance)) {
    message(
      "Note: spearman_max_importance is NA. Add ",
      basename(py_ref$scores_path),
      " to record Python max-score concordance."
    )
  }
}

if (identical(environment(), globalenv()) &&
    !length(grep("^source\\(", sys.calls()))) {
  main()
}
