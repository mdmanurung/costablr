#!/usr/bin/env Rscript

command_args <- commandArgs(trailingOnly = FALSE)
script_file <- grep("^--file=", command_args, value = TRUE)
script_dir <- if (length(script_file) > 0L) {
  dirname(normalizePath(sub("^--file=", "", script_file[[1L]]), winslash = "/", mustWork = FALSE))
} else {
  file.path(getwd(), "scratch", "scripts")
}

source(file.path(script_dir, "stablr_baseline_comparisons_helpers.R"))

usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript scratch/scripts/run_stablr_baseline_comparisons_branch.R <contrast> <branch>",
      "  Rscript scratch/scripts/run_stablr_baseline_comparisons_branch.R --contrast <contrast> --branch <branch>",
      "",
      "Contrasts:",
      paste0("  ", paste(baseline_comparison_names(), collapse = "\n  ")),
      "",
      "Branches:",
      "  preprocess",
      "  cytof",
      "  single_view:<view>",
      "  early_fusion",
      "  late_fusion",
      "  cooperative",
      "  nested_cv",
      "  visualize",
      "",
      "Environment overrides:",
      "  STABLR_CACHE_DIR, STABLR_EXPORT_DIR, STABLR_BASELINE_PREPROCESS_RDS,",
      "  STABLR_N_BOOTSTRAPS, STABLR_N_LAMBDA, STABLR_N_ITER_LF,",
      "  STABLR_SAMPLE_FRACTION, STABLR_ARTIFICIAL_TYPE",
      sep = "\n"
    ),
    "\n"
  )
}

arg_value <- function(args, flag) {
  idx <- match(flag, args)
  if (is.na(idx)) return(NULL)
  if (idx == length(args)) stop("Missing value after ", flag, ".", call. = FALSE)
  args[[idx + 1L]]
}

parse_args <- function(args) {
  if (length(args) == 0L || any(args %in% c("--help", "-h"))) {
    usage()
    quit(status = 0L)
  }
  contrast <- arg_value(args, "--contrast")
  branch <- arg_value(args, "--branch")
  skip <- logical(length(args))
  for (flag in c("--contrast", "--branch")) {
    idx <- match(flag, args)
    if (!is.na(idx)) {
      skip[idx] <- TRUE
      if (idx < length(args)) skip[idx + 1L] <- TRUE
    }
  }
  positional <- args[!skip]
  if (is.null(contrast) && length(positional) >= 1L) contrast <- positional[[1L]]
  if (is.null(branch) && length(positional) >= 2L) branch <- positional[[2L]]
  if (is.null(contrast)) contrast <- Sys.getenv("STABLR_CONTRAST", "")
  if (is.null(branch)) branch <- Sys.getenv("STABLR_BRANCH", "")
  if (!nzchar(contrast) || !nzchar(branch)) {
    usage()
    stop("Both contrast and branch are required.", call. = FALSE)
  }
  list(contrast = contrast, branch = branch)
}

parsed <- parse_args(commandArgs(trailingOnly = TRUE))

setup_stablr_for_baseline()
config <- baseline_comparisons_config(parsed$contrast)
dir.create(config$cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$export_dir, recursive = TRUE, showWarnings = FALSE)

message("Running STABL baseline comparison branch: ", parsed$contrast, " / ", parsed$branch)

if (identical(parsed$branch, "preprocess")) {
  data <- preprocess_comparison(
    config,
    force = isTRUE(as.logical(Sys.getenv("STABLR_FORCE_RECOMPUTE", "FALSE")))
  )
  merge_artifact_manifests(config)
  message("Contrast counts: ", paste(names(table(data$y)), as.integer(table(data$y)), sep = "=", collapse = ", "))
  quit(status = 0L)
}

data <- preprocess_comparison(config, force = FALSE)

if (identical(parsed$branch, "cytof")) {
  fit_single_view_branch_comparison(data, config, "cytof_celltype", branch = "cytof")
} else if (startsWith(parsed$branch, "single_view:")) {
  view <- sub("^single_view:", "", parsed$branch)
  fit_single_view_branch_comparison(data, config, view)
} else if (identical(parsed$branch, "early_fusion")) {
  fit_early_fusion_branch_comparison(data, config)
} else if (identical(parsed$branch, "late_fusion")) {
  run_late_fusion_branch_comparison(data, config)
} else if (identical(parsed$branch, "cooperative")) {
  run_cooperative_branch_comparison(data, config)
} else if (identical(parsed$branch, "nested_cv")) {
  run_nested_cv_branch_comparison(data, config)
} else if (identical(parsed$branch, "visualize")) {
  run_visualize_branch_comparison(data, config)
} else {
  usage()
  stop("Unknown branch: ", parsed$branch, call. = FALSE)
}

merge_artifact_manifests(config)
message("Finished STABL baseline comparison branch: ", parsed$contrast, " / ", parsed$branch)
