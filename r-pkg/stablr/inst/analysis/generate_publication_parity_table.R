#!/usr/bin/env Rscript
# Generate publication-scale OOL proteomics parity metrics for the Application Note.
#
# Usage (from repository root):
#   Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R
#   Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R --outdir papers/application-note/artifacts

`%||%` <- function(x, y) if (is.null(x)) y else x

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  outdir <- "papers/application-note/artifacts"
  i <- match("--outdir", args)
  if (!is.na(i) && i < length(args)) outdir <- args[[i + 1L]]
  list(outdir = outdir)
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
  x <- sweep(sweep(x, 2, col_means), 2, col_sds, "/")
  list(x = x, keep_cols = keep_cols, col_medians = col_medians,
       col_means = col_means, col_sds = col_sds)
}

python_tutorial_features <- c(
  "Angiopoietin.2", "Siglec.6", "Activin.A", "IL.1.R4",
  "SLPI", "MMP.12", "PLXB2"
)

load_ool_proteomics <- function(repo) {
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
  ool_train <- load_ool_data("train")
  list(
    x_raw = ool_train$x_list$proteomics,
    y = ool_train$y,
    data_source = "bundled_extdata"
  )
}

main <- function() {
  cfg <- parse_args()
  repo <- find_repo_root()
  pkg_root <- file.path(repo, "r-pkg", "stablr")
  if (!requireNamespace("devtools", quietly = TRUE)) {
    stop("Install devtools to load stablr from source.", call. = FALSE)
  }
  suppressPackageStartupMessages(devtools::load_all(pkg_root, quiet = TRUE))

  outdir <- file.path(repo, cfg$outdir)
  dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

  loaded <- load_ool_proteomics(repo)
  pipe <- preprocess_fit(loaded$x_raw)
  x_fit <- pipe$x
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
  overlap <- intersect(selected, python_tutorial_features)

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
    n_selected = length(selected),
    tutorial_recall = length(overlap),
    tutorial_total = length(python_tutorial_features),
    jaccard_tutorial = if (length(union(selected, python_tutorial_features)) == 0L) {
      1
    } else {
      length(overlap) / length(union(selected, python_tutorial_features))
    },
    runtime_min = round(runtime_sec / 60, 2),
    glmnet_version = as.character(utils::packageVersion("glmnet")),
    stablr_version = as.character(utils::packageVersion("stablr")),
    stringsAsFactors = FALSE
  )

  selected_df <- data.frame(
    feature = selected,
    importance = importances[selected],
    in_python_tutorial_top = selected %in% python_tutorial_features,
    stringsAsFactors = FALSE
  )
  selected_df <- selected_df[order(-selected_df$importance), , drop = FALSE]

  overlap_df <- data.frame(
    feature = python_tutorial_features,
    selected_by_stablr = python_tutorial_features %in% selected,
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
}

if (identical(environment(), globalenv()) &&
    !length(grep("^source\\(", sys.calls()))) {
  main()
}
