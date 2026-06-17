# Shared helpers for the focused AURORA baseline study-group plus P/NP analysis.

`%||%` <- function(x, y) if (is.null(x)) y else x

gp_find_repo_root <- function(start = getwd()) {
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "AGENTS.md")) &&
        file.exists(file.path(path, "r-pkg", "stablr", "DESCRIPTION"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  stop("Could not locate repository root from: ", start, call. = FALSE)
}

gp_repo_path <- function(...) {
  file.path(gp_find_repo_root(), ...)
}

source(gp_repo_path("scratch", "scripts", "stablr_baseline_groups_helpers.R"))

reset_artifact_manifest <- function() {
  .artifact_env$manifest <- .artifact_env$manifest[0L, , drop = FALSE]
  invisible(NULL)
}

group_protection_config <- function() {
  cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "8"))
  if (is.na(cpus) || cpus < 1L) cpus <- 8L

  joint_levels <- c("EG_P", "EG_NP", "TU_P", "TU_NP", "GA_P", "GA_NP")
  study_levels <- c("EG", "TU", "GA")
  list(
    seed = as.integer(Sys.getenv("STABLR_SEED", "20260512")),
    family = "multinomial",
    within_family = "binomial",
    base_learner = "elastic_net",
    l1_ratio = as.numeric(Sys.getenv("STABLR_L1_RATIO", "0.5")),
    n_bootstraps = as.integer(Sys.getenv("STABLR_N_BOOTSTRAPS", "500")),
    n_lambda = as.integer(Sys.getenv("STABLR_N_LAMBDA", "20")),
    sample_fraction = as.numeric(Sys.getenv("STABLR_SAMPLE_FRACTION", "0.8")),
    artificial_type = Sys.getenv("STABLR_ARTIFICIAL_TYPE", "random_permutation"),
    artificial_proportion = as.numeric(Sys.getenv("STABLR_ARTIFICIAL_PROPORTION", "1")),
    fdr_threshold_range = seq(0, 0.99, by = 0.01),
    workers = cpus,
    cache_dir = normalizePath(
      Sys.getenv(
        "STABLR_CACHE_DIR",
        gp_repo_path("scratch", "cache", "stablr_baseline_group_protection_test")
      ),
      winslash = "/",
      mustWork = FALSE
    ),
    export_dir = normalizePath(
      Sys.getenv(
        "STABLR_EXPORT_DIR",
        gp_repo_path("scratch", "outputs", "stablr_baseline_group_protection_test")
      ),
      winslash = "/",
      mustWork = FALSE
    ),
    source_cache_dir = normalizePath(
      Sys.getenv(
        "STABLR_BASELINE_GROUPS_CACHE_DIR",
        gp_repo_path("scratch", "cache", "stablr_baseline_groups_test")
      ),
      winslash = "/",
      mustWork = FALSE
    ),
    source_export_dir = normalizePath(
      Sys.getenv(
        "STABLR_BASELINE_GROUPS_EXPORT_DIR",
        gp_repo_path("scratch", "outputs", "stablr_baseline_groups_test")
      ),
      winslash = "/",
      mustWork = FALSE
    ),
    joint_levels = joint_levels,
    study_levels = study_levels,
    protection_levels = c("P", "NP"),
    expected_joint_counts = c(EG_P = 6L, EG_NP = 4L, TU_P = 9L, TU_NP = 3L, GA_P = 8L, GA_NP = 8L),
    group_protection_colors = c(
      EG_P = "#4C78A8", EG_NP = "#9EC5E6",
      TU_P = "#54A24B", TU_NP = "#A1D99B",
      GA_P = "#F58518", GA_NP = "#FFBF79"
    )
  )
}

load_or_build_baseline_group_cache <- function(config, force = FALSE) {
  candidates <- c(
    file.path(config$source_cache_dir, "preprocess", "baseline_preprocessed.rds"),
    file.path(config$source_cache_dir, "preprocess", "baseline_complete_case_views.rds")
  )
  cache_path <- candidates[file.exists(candidates)][1L]
  if (!is.na(cache_path) && !isTRUE(force)) {
    message("Loaded source baseline study-group preprocessing cache: ", cache_path)
    return(readRDS(cache_path))
  }

  old_config <- baseline_config()
  old_config$cache_dir <- config$source_cache_dir
  old_config$export_dir <- config$source_export_dir
  message("Source baseline study-group cache missing or forced; rebuilding via existing baseline helper.")
  out <- preprocess_all_views(old_config, force = force)
  reset_artifact_manifest()
  out
}

derive_group_protection_data <- function(source_data, config) {
  required <- c("x_list", "metadata")
  if (!all(required %in% names(source_data))) {
    stop("Source preprocessing cache must contain x_list and metadata.", call. = FALSE)
  }

  metadata <- as.data.frame(source_data$metadata, check.names = FALSE)
  if (!all(c("study_group", "protection") %in% names(metadata))) {
    stop("Source metadata must contain study_group and protection columns.", call. = FALSE)
  }

  metadata$study_group <- factor(as.character(metadata$study_group), levels = config$study_levels)
  metadata$protection <- factor(as.character(metadata$protection), levels = config$protection_levels)
  metadata$group_protection <- factor(
    paste(as.character(metadata$study_group), as.character(metadata$protection), sep = "_"),
    levels = config$joint_levels
  )

  keep <- !is.na(metadata$study_group) & !is.na(metadata$protection) & !is.na(metadata$group_protection)
  metadata <- droplevels(metadata[keep, , drop = FALSE])
  sample_ids <- rownames(metadata)

  x_list <- lapply(source_data$x_list, function(x) {
    x <- as.matrix(x)
    x[sample_ids, , drop = FALSE]
  })
  y_joint <- stats::setNames(factor(metadata$group_protection, levels = config$joint_levels), sample_ids)

  joint <- list(
    x_list = x_list,
    y = y_joint,
    metadata = metadata,
    comparison = "joint_group_protection",
    levels = config$joint_levels,
    family = config$family
  )

  within <- purrr::set_names(vector("list", length(config$study_levels)), config$study_levels)
  for (study in config$study_levels) {
    ids <- rownames(metadata)[as.character(metadata$study_group) == study]
    y <- stats::setNames(
      factor(as.character(metadata[ids, "protection"]), levels = config$protection_levels),
      ids
    )
    within[[study]] <- list(
      x_list = lapply(x_list, function(x) x[ids, , drop = FALSE]),
      y = y,
      metadata = droplevels(metadata[ids, , drop = FALSE]),
      comparison = paste0(study, "_P_vs_", study, "_NP"),
      levels = config$protection_levels,
      family = config$within_family,
      study_group = study
    )
  }

  baseline_class_qc <- tibble::tibble(group_protection = y_joint) |>
    dplyr::count(.data$group_protection, name = "n") |>
    tidyr::complete(
      group_protection = factor(config$joint_levels, levels = config$joint_levels),
      fill = list(n = 0L)
    ) |>
    dplyr::mutate(expected_n = unname(config$expected_joint_counts[as.character(.data$group_protection)]))

  baseline_study_protection_qc <- metadata |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::count(.data$study_group, .data$protection, .data$group_protection, name = "n")

  baseline_view_qc <- purrr::imap_dfr(x_list, function(x, view) {
    tibble::tibble(
      view = view,
      n_samples = nrow(x),
      n_features = ncol(x),
      n_missing = sum(is.na(x)),
      frobenius_norm = norm(x, type = "F")
    )
  })

  list(
    joint = joint,
    within = within,
    baseline_class_qc = baseline_class_qc,
    baseline_study_protection_qc = baseline_study_protection_qc,
    baseline_view_qc = baseline_view_qc,
    source_cache = source_data
  )
}

preprocess_group_protection_views <- function(config, force = FALSE) {
  cache_path <- file.path(branch_cache_dir(config, "preprocess"), "baseline_preprocessed.rds")
  if (file.exists(cache_path) && !isTRUE(force)) {
    return(readRDS(cache_path))
  }

  reset_artifact_manifest()
  source_data <- load_or_build_baseline_group_cache(config, force = FALSE)
  out <- derive_group_protection_data(source_data, config)

  cache_object(out, "baseline_preprocessed", "preprocess", config)
  export_table(out$baseline_class_qc, "baseline_class_qc", "preprocess", config)
  export_table(out$baseline_study_protection_qc, "baseline_study_protection_qc", "preprocess", config)
  export_table(out$baseline_view_qc, "baseline_view_qc", "preprocess", config)
  write_branch_manifest("preprocess", config)
  out
}

comparison_dataset <- function(data, scope, study = NULL) {
  if (identical(scope, "joint")) {
    return(data$joint)
  }
  if (!identical(scope, "within") || is.null(study) || !study %in% names(data$within)) {
    stop("Unknown comparison scope/study.", call. = FALSE)
  }
  data$within[[study]]
}

model_response <- function(dataset) {
  if (!identical(dataset$family, "binomial")) {
    return(dataset$y)
  }
  positive <- levels(dataset$y)[[2L]]
  stats::setNames(as.integer(as.character(dataset$y) == positive), names(dataset$y))
}

branch_path_from_tokens <- function(tokens) {
  do.call(file.path, as.list(tokens))
}

annotate_result_table <- function(x, dataset, outcome_level = "global") {
  x <- as.data.frame(x, check.names = FALSE)
  if (nrow(x) == 0L) {
    x$comparison <- character()
    x$outcome_level <- character()
    return(x)
  }
  x |>
    dplyr::mutate(
      comparison = dataset$comparison,
      outcome_level = outcome_level,
      .before = 1L
    )
}

importance_table_for_fit <- function(fit) {
  scores <- get_importances(fit)
  selected <- get_feature_names_out(fit)
  tibble::tibble(
    feature = names(scores),
    stability_score = as.numeric(scores),
    selected = names(scores) %in% selected
  ) |>
    dplyr::arrange(dplyr::desc(.data$selected), dplyr::desc(.data$stability_score), .data$feature)
}

selected_top_feature_tables <- function(fit, top_n = 50L) {
  imp <- importance_table_for_fit(fit)
  list(
    importance = imp,
    selected = imp |> dplyr::filter(.data$selected),
    top = imp |> dplyr::slice_head(n = min(top_n, nrow(imp)))
  )
}

fit_group_protection_stabl_branch <- function(x, y, dataset, config, branch,
                                              family = dataset$family,
                                              bootstrap_strata = NULL,
                                              seed_offset = 0L) {
  reset_artifact_manifest()
  lambda_grid <- auto_lambda_grid(
    x,
    y,
    family = family,
    n_lambda = config$n_lambda,
    l1_ratio = config$l1_ratio
  )
  fit <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = lambda_grid,
    base_learner = config$base_learner,
    family = family,
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    artificial_proportion = config$artificial_proportion,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    bootstrap_strata = bootstrap_strata,
    random_state = config$seed + seed_offset,
    workers = config$workers,
    fdr_threshold_range = config$fdr_threshold_range
  )

  bundle <- list(
    fit = fit,
    lambda_grid = lambda_grid,
    comparison = dataset$comparison,
    outcome_levels = dataset$levels %||% levels(dataset$y),
    family = family
  )
  cache_object(bundle, "stabl_fit_bundle", branch, config)

  feature_tables <- selected_top_feature_tables(fit)
  export_table(annotate_result_table(feature_tables$importance, dataset), "feature_importance", branch, config)
  export_table(annotate_result_table(feature_tables$selected, dataset), "selected_features", branch, config)
  export_table(annotate_result_table(feature_tables$top, dataset), "top_features", branch, config)
  write_branch_manifest(branch, config)
  bundle
}

run_group_protection_single_view <- function(data, config, scope, view, study = NULL) {
  dataset <- comparison_dataset(data, scope, study)
  if (!view %in% names(dataset$x_list)) {
    stop("Unknown view '", view, "'. Available views: ",
         paste(names(dataset$x_list), collapse = ", "), call. = FALSE)
  }
  branch_tokens <- if (identical(scope, "joint")) {
    c("joint", "single_view", view)
  } else {
    c("within", study, "single_view", view)
  }
  bootstrap_strata <- data.frame(outcome = dataset$y, row.names = names(dataset$y))
  seed_offset <- 100L * match(view, names(dataset$x_list)) +
    if (identical(scope, "within")) 10000L + 1000L * match(study, config$study_levels) else 0L
  fit_group_protection_stabl_branch(
    x = dataset$x_list[[view]],
    y = model_response(dataset),
    dataset = dataset,
    config = config,
    branch = branch_path_from_tokens(branch_tokens),
    family = dataset$family,
    bootstrap_strata = bootstrap_strata,
    seed_offset = seed_offset
  )
}

run_group_protection_early_fusion <- function(data, config, scope, study = NULL) {
  dataset <- comparison_dataset(data, scope, study)
  x_early <- do.call(cbind, purrr::imap(dataset$x_list, prefix_feature_names))
  branch_tokens <- if (identical(scope, "joint")) c("joint", "early_fusion") else c("within", study, "early_fusion")
  bootstrap_strata <- data.frame(outcome = dataset$y, row.names = names(dataset$y))
  seed_offset <- if (identical(scope, "joint")) 5000L else 15000L + 1000L * match(study, config$study_levels)
  fit_group_protection_stabl_branch(
    x = x_early,
    y = model_response(dataset),
    dataset = dataset,
    config = config,
    branch = branch_path_from_tokens(branch_tokens),
    family = dataset$family,
    bootstrap_strata = bootstrap_strata,
    seed_offset = seed_offset
  )
}

late_fusion_prediction_table <- function(fit, dataset) {
  pred <- fit$late_fusion$train_predictions |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::mutate(truth = as.character(dataset$y[.data$sample_id]), .after = "sample_id")

  if ("predicted_class" %in% names(pred)) {
    pred$predicted_class <- factor(pred$predicted_class, levels = levels(dataset$y))
    return(pred)
  }

  score_col <- "Stacked Gen. Predictions"
  if (!score_col %in% names(pred)) {
    pred$predicted_class <- NA_character_
    return(pred)
  }

  positive <- levels(dataset$y)[[2L]]
  negative <- levels(dataset$y)[[1L]]
  pred |>
    dplyr::mutate(
      positive_probability = .data[[score_col]],
      predicted_class = dplyr::case_when(
        is.na(.data$positive_probability) ~ NA_character_,
        .data$positive_probability >= 0.5 ~ positive,
        TRUE ~ negative
      ),
      predicted_class = factor(.data$predicted_class, levels = levels(dataset$y))
    )
}

per_outcome_metric_table <- function(truth, predicted, levels = NULL) {
  levels <- levels %||% levels(factor(truth))
  truth <- factor(truth, levels = levels)
  predicted <- factor(predicted, levels = levels)
  confusion <- table(truth = truth, predicted = predicted)
  recall <- diag(confusion) / pmax(rowSums(confusion), 1L)
  precision <- diag(confusion) / pmax(colSums(confusion), 1L)
  f1 <- ifelse(precision + recall > 0, 2 * precision * recall / (precision + recall), 0)
  tibble::tibble(
    outcome_level = levels,
    support = as.integer(rowSums(confusion)),
    predicted = as.integer(colSums(confusion)),
    recall = as.numeric(recall),
    precision = as.numeric(precision),
    f1 = as.numeric(f1)
  )
}

plot_group_protection_prediction_heatmap <- function(predictions, dataset, config, branch) {
  prob_cols <- grep("^prob_", names(predictions), value = TRUE)
  if (length(prob_cols) > 0L) {
    plot_df <- predictions |>
      dplyr::select(.data$sample_id, dplyr::all_of(prob_cols)) |>
      tidyr::pivot_longer(cols = dplyr::all_of(prob_cols), names_to = "outcome_level", values_to = "probability") |>
      dplyr::mutate(outcome_level = sub("^prob_", "", .data$outcome_level)) |>
      dplyr::left_join(dataset$metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
  } else if ("positive_probability" %in% names(predictions)) {
    plot_df <- predictions |>
      dplyr::transmute(
        sample_id = .data$sample_id,
        outcome_level = levels(dataset$y)[[2L]],
        probability = .data$positive_probability
      ) |>
      dplyr::left_join(dataset$metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
  } else {
    return(invisible(NULL))
  }

  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(.data$sample_id, .data$outcome_level, fill = .data$probability)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.15) +
    ggplot2::facet_grid(. ~ group_protection, scales = "free_x", space = "free_x") +
    ggplot2::scale_fill_gradient(low = "white", high = "#2166AC", limits = c(0, 1), na.value = "grey90") +
    ggplot2::labs(
      title = paste0(dataset$comparison, " late-fusion probabilities"),
      x = "Sample",
      y = NULL,
      fill = "Probability"
    ) +
    ggplot2::theme_bw(base_size = 9) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank()
    )
  export_plot(p, "late_fusion_prediction_heatmap", branch, config, width = 10, height = 4)
}

run_group_protection_late_fusion <- function(data, config, scope, study = NULL) {
  reset_artifact_manifest()
  dataset <- comparison_dataset(data, scope, study)
  branch_tokens <- if (identical(scope, "joint")) c("joint", "late_fusion") else c("within", study, "late_fusion")
  branch <- branch_path_from_tokens(branch_tokens)
  bootstrap_strata <- data.frame(outcome = dataset$y, row.names = names(dataset$y))
  seed_offset <- if (identical(scope, "joint")) 7000L else 17000L + 1000L * match(study, config$study_levels)

  fit <- stabl_multiomic_train_validate(
    x_train_list = dataset$x_list,
    y_train = model_response(dataset),
    lambda_grid = "auto",
    base_learner = config$base_learner,
    family = dataset$family,
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    artificial_proportion = config$artificial_proportion,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    stratify_bootstrap = TRUE,
    bootstrap_strata_train = bootstrap_strata,
    l1_ratio = config$l1_ratio,
    n_lambda = config$n_lambda,
    random_state = config$seed + seed_offset,
    workers = config$workers,
    fdr_threshold_range = config$fdr_threshold_range,
    late_fusion = TRUE,
    n_iter_lf = as.integer(Sys.getenv("STABLR_N_ITER_LF", "5000"))
  )

  cache_object(
    list(fit = fit, comparison = dataset$comparison, outcome_levels = levels(dataset$y), family = dataset$family),
    "late_fusion_result",
    branch,
    config
  )

  weights <- fit$late_fusion$weights |>
    tibble::rownames_to_column("view") |>
    dplyr::arrange(dplyr::desc(.data$Associated_weight))
  pred_tbl <- late_fusion_prediction_table(fit, dataset)
  confusion <- confusion_table(pred_tbl$truth, pred_tbl$predicted_class, levels = levels(dataset$y))
  metrics <- classification_metric_table(pred_tbl$truth, pred_tbl$predicted_class, levels = levels(dataset$y))
  if (!is.null(fit$late_fusion$log_loss)) {
    metrics <- metrics |> dplyr::bind_rows(tibble::tibble(metric = "log_loss", value = fit$late_fusion$log_loss))
  }
  if (!is.null(fit$late_fusion$score)) {
    metrics <- metrics |> dplyr::bind_rows(tibble::tibble(metric = "late_fusion_score", value = fit$late_fusion$score))
  }
  per_outcome <- per_outcome_metric_table(pred_tbl$truth, pred_tbl$predicted_class, levels = levels(dataset$y))

  export_table(annotate_result_table(weights, dataset), "late_fusion_weights", branch, config)
  export_table(annotate_result_table(pred_tbl, dataset, outcome_level = NA_character_), "late_fusion_train_predictions", branch, config)
  export_table(annotate_result_table(confusion, dataset, outcome_level = as.character(confusion$truth)), "late_fusion_confusion_matrix", branch, config)
  export_table(annotate_result_table(metrics, dataset), "late_fusion_metrics", branch, config)
  export_table(per_outcome |> dplyr::mutate(comparison = dataset$comparison, .before = 1L), "late_fusion_per_outcome_metrics", branch, config)
  plot_group_protection_prediction_heatmap(pred_tbl, dataset, config, branch)
  write_branch_manifest(branch, config)
  fit
}

available_group_protection_branches <- function(config = group_protection_config()) {
  views <- names(baseline_default_paths())
  c(
    "preprocess",
    paste0("joint:single_view:", views),
    "joint:early_fusion",
    "joint:late_fusion",
    unlist(lapply(config$study_levels, function(study) {
      c(
        paste0("within:", study, ":single_view:", views),
        paste0("within:", study, ":early_fusion"),
        paste0("within:", study, ":late_fusion")
      )
    }), use.names = FALSE)
  )
}

run_group_protection_branch <- function(branch, data, config) {
  tokens <- strsplit(branch, ":", fixed = TRUE)[[1L]]
  if (length(tokens) < 2L) {
    stop("Unknown branch: ", branch, call. = FALSE)
  }

  if (identical(tokens[[1L]], "joint")) {
    if (length(tokens) == 3L && identical(tokens[[2L]], "single_view")) {
      return(run_group_protection_single_view(data, config, "joint", tokens[[3L]]))
    }
    if (length(tokens) == 2L && identical(tokens[[2L]], "early_fusion")) {
      return(run_group_protection_early_fusion(data, config, "joint"))
    }
    if (length(tokens) == 2L && identical(tokens[[2L]], "late_fusion")) {
      return(run_group_protection_late_fusion(data, config, "joint"))
    }
  }

  if (identical(tokens[[1L]], "within") && length(tokens) >= 3L) {
    study <- tokens[[2L]]
    if (!study %in% config$study_levels) {
      stop("Unknown within-study group '", study, "'.", call. = FALSE)
    }
    if (length(tokens) == 4L && identical(tokens[[3L]], "single_view")) {
      return(run_group_protection_single_view(data, config, "within", tokens[[4L]], study = study))
    }
    if (length(tokens) == 3L && identical(tokens[[3L]], "early_fusion")) {
      return(run_group_protection_early_fusion(data, config, "within", study = study))
    }
    if (length(tokens) == 3L && identical(tokens[[3L]], "late_fusion")) {
      return(run_group_protection_late_fusion(data, config, "within", study = study))
    }
  }

  stop("Unknown branch: ", branch, call. = FALSE)
}
