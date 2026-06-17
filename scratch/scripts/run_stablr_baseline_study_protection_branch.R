#!/usr/bin/env Rscript

command_args <- commandArgs(trailingOnly = FALSE)
script_file <- grep("^--file=", command_args, value = TRUE)
script_dir <- if (length(script_file) > 0L) {
  dirname(normalizePath(sub("^--file=", "", script_file[[1L]]), winslash = "/", mustWork = FALSE))
} else {
  file.path(getwd(), "scratch", "scripts")
}

source(file.path(script_dir, "stablr_baseline_study_protection_helpers.R"))

study_protection_groups <- c("EG_P", "EG_NP", "TU_P", "TU_NP", "GA_P", "GA_NP")

usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript scratch/scripts/run_stablr_baseline_study_protection_branch.R <branch>",
      "  Rscript scratch/scripts/run_stablr_baseline_study_protection_branch.R --branch <branch>",
      "",
      "Branches:",
      "  preprocess",
      "  cytof",
      "  single_view:<view>",
      "  early_fusion",
      "  late_fusion",
      "  ovr_stabl:<EG_P|EG_NP|TU_P|TU_NP|GA_P|GA_NP>",
      "  cooperative_ovr:<EG_P|EG_NP|TU_P|TU_NP|GA_P|GA_NP>",
      "  nested_cv",
      "  visualize",
      "",
      "Environment overrides:",
      "  STABLR_CACHE_DIR, STABLR_EXPORT_DIR, STABLR_N_BOOTSTRAPS, STABLR_N_LAMBDA,",
      "  STABLR_N_ITER_LF, STABLR_SAMPLE_FRACTION, STABLR_ARTIFICIAL_TYPE,",
      "  STABLR_NESTED_OUTER_V, STABLR_NESTED_INNER_V, STABLR_COOPERATIVE_NFOLDS",
      sep = "\n"
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

fit_early_fusion_branch <- function(data, config) {
  x_early <- do.call(cbind, purrr::imap(data$x_list, prefix_feature_names))
  bootstrap_strata <- data.frame(study_protection_group = data$y, row.names = names(data$y))
  fit_stabl_branch(
    x = x_early,
    y = data$y,
    config = config,
    branch = "early_fusion",
    bootstrap_strata = bootstrap_strata,
    seed_offset = 5000L
  )
}

fit_single_view_branch <- function(data, config, view, branch = file.path("single_view", view)) {
  if (!view %in% names(data$x_list)) {
    stop("Unknown view '", view, "'. Available views: ",
         paste(names(data$x_list), collapse = ", "), call. = FALSE)
  }
  bootstrap_strata <- data.frame(study_protection_group = data$y, row.names = names(data$y))
  seed_offset <- match(view, names(data$x_list)) * 100L
  fit_stabl_branch(
    x = data$x_list[[view]],
    y = data$y,
    config = config,
    branch = branch,
    bootstrap_strata = bootstrap_strata,
    seed_offset = seed_offset
  )
}

run_nested_cv_branch <- function(data, config) {
  result <- stabl_multiomic_nested_cv(
    x_list = data$x_list,
    y = data$y,
    candidates = NULL,
    lambda_grid = "auto",
    outer_v = config$nested_outer_v,
    outer_repeats = as.integer(Sys.getenv("STABLR_NESTED_OUTER_REPEATS", "1")),
    inner_v = config$nested_inner_v,
    stratified = TRUE,
    strata = data$y,
    metric = "ber",
    family = config$family,
    base_learner = config$base_learner,
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    stratify_bootstrap = TRUE,
    bootstrap_strata = data.frame(study_protection_group = data$y, row.names = names(data$y)),
    random_state = config$seed + 9000L,
    n_lambda = config$n_lambda,
    l1_ratio = config$l1_ratio,
    workers = config$workers,
    cv_workers = 1L
  )
  branch <- "nested_cv"
  cache_object(result, "nested_cv_result", branch, config)
  if (!is.null(result$outer_predictions)) {
    export_table(as.data.frame(result$outer_predictions), "nested_cv_outer_predictions", branch, config)
  }
  if (!is.null(result$performance)) {
    export_table(as.data.frame(result$performance), "nested_cv_performance", branch, config)
  }
  if (!is.null(result$selected_features)) {
    export_table(as.data.frame(result$selected_features), "nested_cv_selected_features", branch, config)
  }
  write_branch_manifest(branch, config)
  result
}

args <- commandArgs(trailingOnly = TRUE)
branch <- parse_branch(args)

setup_stablr_for_baseline()
config <- baseline_config()
dir.create(config$cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(config$export_dir, recursive = TRUE, showWarnings = FALSE)

message("Running STABL baseline study-protection branch: ", branch)

if (identical(branch, "preprocess")) {
  data <- preprocess_all_views(config, force = isTRUE(as.logical(Sys.getenv("STABLR_FORCE_RECOMPUTE", "FALSE"))))
  merge_artifact_manifests(config)
  message("Preprocessed views: ", paste(names(data$x_list), collapse = ", "))
  message("Class counts: ", paste(names(table(data$y)), as.integer(table(data$y)), sep = "=", collapse = ", "))
  quit(status = 0L)
}

data <- preprocess_all_views(config, force = FALSE)

if (identical(branch, "cytof")) {
  fit_single_view_branch(data, config, "cytof_celltype", branch = "cytof")
} else if (startsWith(branch, "single_view:")) {
  view <- sub("^single_view:", "", branch)
  fit_single_view_branch(data, config, view)
} else if (identical(branch, "early_fusion")) {
  fit_early_fusion_branch(data, config)
} else if (identical(branch, "late_fusion")) {
  run_late_fusion_branch(data, config)
} else if (startsWith(branch, "ovr_stabl:")) {
  group <- sub("^ovr_stabl:", "", branch)
  if (!group %in% config$study_group_levels) {
    stop("Unknown one-vs-rest group '", group, "'. Valid groups: ",
         paste(config$study_group_levels, collapse = ", "), call. = FALSE)
  }
  run_ovr_stabl_branch(data, config, group)
} else if (startsWith(branch, "cooperative_ovr:")) {
  group <- sub("^cooperative_ovr:", "", branch)
  if (!group %in% config$study_group_levels) {
    stop("Unknown cooperative one-vs-rest group '", group, "'. Valid groups: ",
         paste(config$study_group_levels, collapse = ", "), call. = FALSE)
  }
  run_cooperative_ovr_branch(data, config, group)
} else if (identical(branch, "nested_cv")) {
  run_nested_cv_branch(data, config)
} else if (identical(branch, "visualize")) {
  run_visualize_branch(data, config)
} else {
  usage()
  stop("Unknown branch: ", branch, call. = FALSE)
}

merge_artifact_manifests(config)
message("Finished STABL baseline study-protection branch: ", branch)
