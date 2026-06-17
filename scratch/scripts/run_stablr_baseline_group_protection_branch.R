#!/usr/bin/env Rscript

command_args <- commandArgs(trailingOnly = FALSE)
script_file <- grep("^--file=", command_args, value = TRUE)
script_dir <- if (length(script_file) > 0L) {
  dirname(normalizePath(sub("^--file=", "", script_file[[1L]]), winslash = "/", mustWork = FALSE))
} else {
  file.path(getwd(), "scratch", "scripts")
}

source(file.path(script_dir, "stablr_baseline_group_protection_helpers.R"))

usage <- function() {
  config <- group_protection_config()
  cat(
    paste(
      c(
        "Usage:",
        "  Rscript scratch/scripts/run_stablr_baseline_group_protection_branch.R <branch>",
        "  Rscript scratch/scripts/run_stablr_baseline_group_protection_branch.R --branch <branch>",
        "",
        "Branches:",
        paste0("  ", available_group_protection_branches(config)),
        "",
        "Environment overrides:",
        "  STABLR_CACHE_DIR, STABLR_EXPORT_DIR, STABLR_BASELINE_GROUPS_CACHE_DIR,",
        "  STABLR_BASELINE_GROUPS_EXPORT_DIR, STABLR_N_BOOTSTRAPS, STABLR_N_LAMBDA,",
        "  STABLR_N_ITER_LF, STABLR_SAMPLE_FRACTION, STABLR_ARTIFICIAL_TYPE"
      ),
      collapse = "\n"
    ),
    "\n"
  )
}

parse_branch <- function(args) {
  if (length(args) == 0L || any(args %in% c("--help", "-h"))) {
    usage()
    quit(status = 0L)
  }
  branch_idx <- match("--branch", args)
  if (!is.na(branch_idx)) {
    if (branch_idx == length(args)) stop("Missing value after --branch.", call. = FALSE)
    return(args[[branch_idx + 1L]])
  }
  args[[1L]]
}

args <- commandArgs(trailingOnly = TRUE)
branch <- parse_branch(args)

setup_stablr_for_baseline()
config <- group_protection_config()
dir.create(config$cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$export_dir, recursive = TRUE, showWarnings = FALSE)

message("Running STABL baseline group-protection branch: ", branch)

if (identical(branch, "preprocess")) {
  data <- preprocess_group_protection_views(
    config,
    force = isTRUE(as.logical(Sys.getenv("STABLR_FORCE_RECOMPUTE", "FALSE")))
  )
  merge_artifact_manifests(config)
  message("Preprocessed views: ", paste(names(data$joint$x_list), collapse = ", "))
  counts <- table(data$joint$y)
  message("Joint class counts: ", paste(names(counts), as.integer(counts), sep = "=", collapse = ", "))
  quit(status = 0L)
}

data <- preprocess_group_protection_views(config, force = FALSE)
run_group_protection_branch(branch, data, config)
merge_artifact_manifests(config)
message("Finished STABL baseline group-protection branch: ", branch)
