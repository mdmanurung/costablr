# Shared helpers for AURORA baseline binary study-group comparisons.

.comparison_helper_file <- tryCatch(
  normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = TRUE),
  error = function(e) NA_character_
)
.comparison_helper_dir <- if (!is.na(.comparison_helper_file)) {
  dirname(.comparison_helper_file)
} else {
  .repo_root <- Sys.getenv("STABLR_REPO_ROOT", "")
  if (nzchar(.repo_root)) {
    file.path(.repo_root, "scratch", "scripts")
  } else {
    file.path(getwd(), "scratch", "scripts")
  }
}
source(file.path(.comparison_helper_dir, "stablr_baseline_groups_helpers.R"))

comparison_repo_root <- function(start = getwd()) {
  override <- Sys.getenv("STABLR_REPO_ROOT", "")
  if (nzchar(override)) {
    return(normalizePath(override, winslash = "/", mustWork = FALSE))
  }
  path <- normalizePath(start, winslash = "/", mustWork = TRUE)
  repeat {
    if (file.exists(file.path(path, "AGENTS.md")) && dir.exists(file.path(path, "scratch"))) {
      return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) break
    path <- parent
  }
  normalizePath(start, winslash = "/", mustWork = TRUE)
}

baseline_comparison_definitions <- function() {
  list(
    EG_vs_GA_TU = list(
      name = "EG_vs_GA_TU",
      title = "EG vs combined GA and TU",
      include_groups = c("EG", "GA", "TU"),
      reference_groups = c("GA", "TU"),
      reference_class = "GA_TU",
      positive_group = "EG",
      positive_class = "EG",
      levels = c("GA_TU", "EG"),
      seed_offset = 11000L
    ),
    GA_vs_EG = list(
      name = "GA_vs_EG",
      title = "GA vs EG",
      include_groups = c("EG", "GA"),
      reference_groups = "EG",
      reference_class = "EG",
      positive_group = "GA",
      positive_class = "GA",
      levels = c("EG", "GA"),
      seed_offset = 12000L
    ),
    TU_vs_EG = list(
      name = "TU_vs_EG",
      title = "TU vs EG",
      include_groups = c("EG", "TU"),
      reference_groups = "EG",
      reference_class = "EG",
      positive_group = "TU",
      positive_class = "TU",
      levels = c("EG", "TU"),
      seed_offset = 13000L
    )
  )
}

baseline_comparison_names <- function() {
  names(baseline_comparison_definitions())
}

baseline_comparisons_config <- function(contrast = Sys.getenv("STABLR_CONTRAST", "EG_vs_GA_TU")) {
  defs <- baseline_comparison_definitions()
  if (!contrast %in% names(defs)) {
    stop(
      "Unknown contrast '", contrast, "'. Available contrasts: ",
      paste(names(defs), collapse = ", "),
      call. = FALSE
    )
  }
  repo_root <- comparison_repo_root()
  root_cache <- Sys.getenv(
    "STABLR_CACHE_DIR",
    file.path(repo_root, "scratch", "cache", "stablr_baseline_binary_comparisons")
  )
  root_export <- Sys.getenv(
    "STABLR_EXPORT_DIR",
    file.path(repo_root, "scratch", "outputs", "stablr_baseline_binary_comparisons")
  )
  config <- baseline_config()
  config$family <- "binomial"
  config$cache_dir <- file.path(root_cache, contrast)
  config$export_dir <- file.path(root_export, contrast)
  config$comparison_cache_root <- root_cache
  config$comparison_export_root <- root_export
  config$repo_root <- repo_root
  config$contrast <- defs[[contrast]]
  config$contrast_name <- contrast
  config$contrast_title <- defs[[contrast]]$title
  config$contrast_levels <- defs[[contrast]]$levels
  config$reference_class <- defs[[contrast]]$reference_class
  config$positive_class <- defs[[contrast]]$positive_class
  config$outcome_colors <- c(
    GA_TU = "#7F7F7F",
    EG = "#4C78A8",
    GA = "#F58518",
    TU = "#54A24B"
  )[config$contrast_levels]
  config
}

first_existing_comparison_path <- function(paths) {
  existing <- paths[file.exists(paths)]
  if (length(existing) == 0L) NA_character_ else existing[[1L]]
}

load_baseline_source_data <- function(config, force = FALSE) {
  candidates <- c(
    Sys.getenv("STABLR_BASELINE_PREPROCESS_RDS", ""),
    file.path(config$repo_root, "scratch", "cache", "stablr_baseline_groups_test", "preprocess", "baseline_preprocessed.rds"),
    file.path(config$repo_root, "scratch", "cache", "stablr_baseline_groups_test", "baseline_preprocessed.rds")
  )
  candidates <- candidates[nzchar(candidates)]
  source_path <- first_existing_comparison_path(candidates)
  if (!isTRUE(force) && !is.na(source_path)) {
    message("Loaded source baseline preprocessing cache: ", source_path)
    return(readRDS(source_path))
  }

  message("Source baseline preprocessing cache not found; running baseline preprocessing once.")
  source_config <- baseline_config()
  source_config$cache_dir <- file.path(config$repo_root, "scratch", "cache", "stablr_baseline_groups_test")
  source_config$export_dir <- file.path(config$repo_root, "scratch", "outputs", "stablr_baseline_groups_test")
  preprocess_all_views(source_config, force = force)
}

make_contrast_data <- function(base_data, config) {
  spec <- config$contrast
  metadata <- as.data.frame(base_data$metadata, check.names = FALSE)
  study_group <- as.character(metadata$study_group)
  keep <- !is.na(study_group) & study_group %in% spec$include_groups
  sample_ids <- rownames(metadata)[keep]
  outcome <- ifelse(study_group[keep] == spec$positive_group, spec$positive_class, spec$reference_class)
  outcome <- factor(outcome, levels = spec$levels)
  names(outcome) <- sample_ids

  x_list <- lapply(base_data$x_list, function(x) {
    x[sample_ids, , drop = FALSE]
  })
  metadata <- droplevels(metadata[sample_ids, , drop = FALSE])
  metadata$contrast_name <- spec$name
  metadata$contrast_outcome <- outcome[rownames(metadata)]
  metadata$contrast_reference <- spec$reference_class
  metadata$contrast_positive <- spec$positive_class

  list(
    x_list = x_list,
    y = outcome,
    metadata = metadata,
    source_y = stats::setNames(metadata$study_group, rownames(metadata)),
    contrast = spec
  )
}

preprocess_comparison <- function(config, force = FALSE) {
  cache_path <- file.path(branch_cache_dir(config, "preprocess"), "baseline_preprocessed.rds")
  if (file.exists(cache_path) && !isTRUE(force)) {
    return(readRDS(cache_path))
  }

  base_data <- load_baseline_source_data(config, force = FALSE)
  data <- make_contrast_data(base_data, config)

  outcome_qc <- tibble::tibble(
    contrast = config$contrast_name,
    outcome = data$y
  ) |>
    dplyr::count(.data$contrast, .data$outcome, name = "n")

  study_group_qc <- data$metadata |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::count(.data$contrast_outcome, .data$study_group, .data$protection, name = "n")

  view_qc <- purrr::imap_dfr(data$x_list, function(x, view) {
    tibble::tibble(
      contrast = config$contrast_name,
      view = view,
      n_samples = nrow(x),
      n_features = ncol(x),
      n_missing = sum(is.na(x)),
      frobenius_norm = norm(x, type = "F")
    )
  })

  data$outcome_qc <- outcome_qc
  data$study_group_qc <- study_group_qc
  data$view_qc <- view_qc

  cache_object(data, "baseline_preprocessed", "preprocess", config)
  export_table(outcome_qc, "contrast_outcome_qc", "preprocess", config)
  export_table(study_group_qc, "contrast_study_group_qc", "preprocess", config)
  export_table(view_qc, "contrast_view_qc", "preprocess", config)
  write_branch_manifest("preprocess", config)
  data
}

comparison_bootstrap_strata <- function(data) {
  data.frame(
    outcome = data$y,
    study_group = data$metadata[names(data$y), "study_group"],
    row.names = names(data$y)
  )
}

comparison_numeric_outcome <- function(y, config) {
  out <- as.integer(as.character(y) == config$positive_class)
  names(out) <- names(y)
  out
}

binomial_beta_table <- function(x, y, lambda_grid, alpha = NULL) {
  if (!requireNamespace("glmnet", quietly = TRUE)) {
    stop("Package 'glmnet' is required for coefficient extraction.", call. = FALSE)
  }
  lambdas <- sort(unique(lambda_grid$lambda), decreasing = TRUE)
  alpha <- alpha %||% 1
  beta_fit <- glmnet::glmnet(
    x = x,
    y = y,
    family = "binomial",
    alpha = alpha,
    lambda = lambdas
  )

  purrr::map_dfr(lambdas, function(lambda_value) {
    coef_mat <- as.matrix(glmnet::coef.glmnet(beta_fit, s = lambda_value))
    beta_values <- as.numeric(coef_mat[-1L, 1L])
    tibble::tibble(
      feature = rownames(coef_mat)[-1L],
      beta = beta_values,
      abs_beta = abs(beta_values),
      lambda_at_max_abs_beta = lambda_value
    )
  }) |>
    dplyr::group_by(.data$feature) |>
    dplyr::slice_max(order_by = .data$abs_beta, n = 1L, with_ties = FALSE) |>
    dplyr::ungroup()
}

comparison_signature_table <- function(fit, x, y, lambda_grid, view, config) {
  scores <- get_importances(fit)
  selected <- get_feature_names_out(fit)
  importance <- tibble::tibble(
    feature = names(scores),
    stability_score = as.numeric(scores),
    selected = names(scores) %in% selected
  )
  beta <- binomial_beta_table(
    x = x,
    y = y,
    lambda_grid = lambda_grid,
    alpha = config$l1_ratio
  )
  values <- as.data.frame(x, check.names = FALSE) |>
    tibble::rownames_to_column("sample_id") |>
    tidyr::pivot_longer(cols = -dplyr::all_of("sample_id"),
                        names_to = "feature", values_to = "value") |>
    dplyr::mutate(outcome = as.character(y[.data$sample_id]))
  means <- values |>
    dplyr::group_by(.data$feature, .data$outcome) |>
    dplyr::summarise(mean_value = mean(.data$value, na.rm = TRUE), .groups = "drop") |>
    tidyr::pivot_wider(names_from = "outcome", values_from = "mean_value")

  positive_mean <- means[[config$positive_class]]
  reference_mean <- means[[config$reference_class]]
  positive_mean <- positive_mean %||% rep(NA_real_, nrow(means))
  reference_mean <- reference_mean %||% rep(NA_real_, nrow(means))

  tibble::tibble(
    feature = means$feature,
    positive_mean = positive_mean,
    reference_mean = reference_mean,
    positive_vs_reference_mean_diff = positive_mean - reference_mean
  ) |>
    dplyr::right_join(importance, by = "feature") |>
    dplyr::left_join(beta, by = "feature") |>
    dplyr::mutate(
      contrast = config$contrast_name,
      contrast_title = config$contrast_title,
      reference_class = config$reference_class,
      positive_class = config$positive_class,
      view = view,
      rank_score = .data$stability_score * .data$abs_beta,
      direction = dplyr::case_when(
        .data$beta > 0 ~ paste0("toward_", config$positive_class),
        .data$beta < 0 ~ paste0("toward_", config$reference_class),
        TRUE ~ "near_zero_beta"
      ),
      interpretation = dplyr::case_when(
        .data$beta > 0 & .data$positive_vs_reference_mean_diff > 0 ~
          paste0("higher in ", config$positive_class, " with positive log-odds beta"),
        .data$beta > 0 ~
          paste0("positive log-odds beta but mean is not higher in ", config$positive_class),
        .data$beta < 0 & .data$positive_vs_reference_mean_diff < 0 ~
          paste0("higher in ", config$reference_class, " with negative log-odds beta"),
        .data$beta < 0 ~
          paste0("negative log-odds beta but mean is not higher in ", config$reference_class),
        TRUE ~ "near-zero beta"
      )
    ) |>
    dplyr::arrange(dplyr::desc(.data$rank_score), dplyr::desc(.data$stability_score), .data$feature)
}

export_comparison_fit_summaries <- function(bundle, x, y, branch, view, config, top_n = 25L) {
  signature <- comparison_signature_table(
    fit = bundle$fit,
    x = x,
    y = y,
    lambda_grid = bundle$lambda_grid,
    view = view,
    config = config
  )
  top <- signature |>
    dplyr::slice_max(order_by = .data$rank_score, n = top_n, with_ties = FALSE)
  export_table(signature, "signature_table", branch, config)
  export_table(top, "top_predictors", branch, config)
  invisible(list(signature = signature, top = top))
}

plot_comparison_top_predictors <- function(top_tbl, config, title = NULL) {
  direction_values <- c(
    unname(config$outcome_colors[config$positive_class]),
    unname(config$outcome_colors[config$reference_class]),
    "#A6A6A6"
  )
  names(direction_values) <- c(
    paste0("toward_", config$positive_class),
    paste0("toward_", config$reference_class),
    "near_zero_beta"
  )

  top_tbl <- top_tbl |>
    dplyr::mutate(
      feature_label = paste(.data$view, .data$feature, sep = "__"),
      signed_rank = ifelse(.data$beta >= 0, .data$rank_score, -.data$rank_score)
    ) |>
    dplyr::slice_max(order_by = abs(.data$signed_rank), n = 20L, with_ties = FALSE)

  ggplot2::ggplot(
    top_tbl,
    ggplot2::aes(x = stats::reorder(.data$feature_label, .data$signed_rank),
                 y = .data$signed_rank,
                 fill = .data$direction)
  ) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(
      values = direction_values,
      drop = FALSE
    ) +
    ggplot2::labs(
      title = title %||% paste0("Top predictors: ", config$contrast_title),
      x = NULL,
      y = "Signed stability x |beta|",
      fill = "Direction"
    ) +
    ggplot2::theme_bw(base_size = 10)
}

fit_single_view_branch_comparison <- function(data, config, view, branch = file.path("single_view", view)) {
  if (!view %in% names(data$x_list)) {
    stop("Unknown view '", view, "'. Available views: ",
         paste(names(data$x_list), collapse = ", "), call. = FALSE)
  }
  seed_offset <- config$contrast$seed_offset + match(view, names(data$x_list)) * 100L
  bundle <- fit_stabl_branch(
    x = data$x_list[[view]],
    y = data$y,
    config = config,
    branch = branch,
    family = "binomial",
    bootstrap_strata = comparison_bootstrap_strata(data),
    seed_offset = seed_offset
  )
  export_comparison_fit_summaries(bundle, data$x_list[[view]], data$y, branch, view, config)
  top_tbl <- readr::read_csv(
    file.path(branch_export_dir(config, branch, "tables"), "top_predictors.csv"),
    show_col_types = FALSE
  )
  export_plot(
    plot_comparison_top_predictors(top_tbl, config),
    "top_predictors",
    branch,
    config,
    width = 10,
    height = 7
  )
  write_branch_manifest(branch, config)
  bundle
}

fit_early_fusion_branch_comparison <- function(data, config) {
  x_early <- do.call(cbind, purrr::imap(data$x_list, prefix_feature_names))
  bundle <- fit_stabl_branch(
    x = x_early,
    y = data$y,
    config = config,
    branch = "early_fusion",
    family = "binomial",
    bootstrap_strata = comparison_bootstrap_strata(data),
    seed_offset = config$contrast$seed_offset + 5000L
  )
  summaries <- export_comparison_fit_summaries(
    bundle,
    x_early,
    data$y,
    branch = "early_fusion",
    view = "all_view_early_fusion",
    config = config,
    top_n = 50L
  )
  export_plot(
    plot_comparison_top_predictors(summaries$top, config),
    "all_view_top_predictors",
    "early_fusion",
    config,
    width = 10,
    height = 7
  )
  write_branch_manifest("early_fusion", config)
  bundle
}

plot_binary_prediction_heatmap <- function(pred_tbl, metadata, config, branch) {
  if (!"positive_probability" %in% names(pred_tbl)) return(invisible(NULL))
  metadata <- as.data.frame(metadata, check.names = FALSE)
  plot_df <- pred_tbl |>
    dplyr::left_join(metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
  p <- ggplot2::ggplot(
    plot_df,
    ggplot2::aes(x = .data$sample_id, y = config$positive_class, fill = .data$positive_probability)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.15) +
    ggplot2::facet_grid(. ~ contrast_outcome, scales = "free_x", space = "free_x") +
    ggplot2::scale_fill_gradient(low = "white", high = unname(config$outcome_colors[config$positive_class]),
                                 limits = c(0, 1)) +
    ggplot2::labs(
      title = paste0("Late-fusion probability for ", config$positive_class),
      x = "Sample",
      y = NULL,
      fill = "Probability"
    ) +
    ggplot2::theme_bw(base_size = 9) +
    ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                   axis.ticks.x = ggplot2::element_blank())
  export_plot(p, "prediction_probability_heatmap", branch, config, width = 10, height = 3.5)
}

run_late_fusion_branch_comparison <- function(data, config) {
  y_model <- comparison_numeric_outcome(data$y, config)
  fit <- stabl_multiomic_train_validate(
    x_train_list = data$x_list,
    y_train = y_model,
    lambda_grid = "auto",
    base_learner = config$base_learner,
    family = "binomial",
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    stratify_bootstrap = TRUE,
    bootstrap_strata_train = comparison_bootstrap_strata(data),
    l1_ratio = config$l1_ratio,
    n_lambda = config$n_lambda,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    random_state = config$seed + config$contrast$seed_offset + 7000L,
    late_fusion = TRUE,
    n_iter_lf = as.integer(Sys.getenv("STABLR_N_ITER_LF", "5000"))
  )
  cache_object(fit, "late_fusion_result", "late_fusion", config)
  export_table(fit$late_fusion$weights |> tibble::rownames_to_column("view"),
               "late_fusion_weights", "late_fusion", config)

  pred_tbl <- fit$late_fusion$train_predictions |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::mutate(
      truth = as.character(data$y[.data$sample_id]),
      positive_probability = .data[["Stacked Gen. Predictions"]],
      predicted_class = ifelse(
        .data$positive_probability >= 0.5,
        config$positive_class,
        config$reference_class
      ),
      predicted_class = factor(.data$predicted_class, levels = config$contrast_levels),
      .after = "sample_id"
    )
  export_table(pred_tbl, "late_fusion_train_predictions", "late_fusion", config)
  export_table(
    confusion_table(pred_tbl$truth, pred_tbl$predicted_class, levels = config$contrast_levels),
    "late_fusion_confusion_matrix",
    "late_fusion",
    config
  )
  metrics <- classification_metric_table(
    pred_tbl$truth,
    pred_tbl$predicted_class,
    levels = config$contrast_levels
  ) |>
    dplyr::bind_rows(tibble::tibble(metric = "stacking_auc", value = fit$late_fusion$score))
  export_table(metrics, "late_fusion_metrics", "late_fusion", config)
  plot_binary_prediction_heatmap(pred_tbl, data$metadata, config, "late_fusion")
  write_branch_manifest("late_fusion", config)
  fit
}

run_cooperative_branch_comparison <- function(data, config) {
  fit <- stabl_multiomic_train_validate(
    x_train_list = data$x_list,
    y_train = data$y,
    lambda_grid = "auto",
    base_learner = config$base_learner,
    family = "binomial",
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    stratify_bootstrap = TRUE,
    bootstrap_strata_train = comparison_bootstrap_strata(data),
    l1_ratio = config$l1_ratio,
    n_lambda = config$n_lambda,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    random_state = config$seed + config$contrast$seed_offset + 8000L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.1, 0.25, 0.5, 1),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.1se",
    cooperation_type_measure = "deviance",
    cooperation_nfolds = 5L
  )
  branch <- "cooperative"
  cache_object(fit, "cooperative_fit", branch, config)
  export_table(get_cooperative_diagnostics(fit), "cooperative_diagnostics", branch, config)
  features <- get_cooperative_features(fit)
  feature_tbl <- purrr::imap_dfr(features, function(x, view) {
    tibble::tibble(view = view, feature = x)
  })
  export_table(feature_tbl, "cooperative_features", branch, config)
  write_branch_manifest(branch, config)
  fit
}

run_nested_cv_branch_comparison <- function(data, config) {
  result <- stabl_multiomic_nested_cv(
    x_list = data$x_list,
    y = data$y,
    candidates = NULL,
    lambda_grid = "auto",
    outer_v = as.integer(Sys.getenv("STABLR_NESTED_OUTER_V", "5")),
    outer_repeats = as.integer(Sys.getenv("STABLR_NESTED_OUTER_REPEATS", "1")),
    inner_v = as.integer(Sys.getenv("STABLR_NESTED_INNER_V", "5")),
    stratified = TRUE,
    strata = data$y,
    metric = "ber",
    family = "binomial",
    base_learner = config$base_learner,
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    stratify_bootstrap = TRUE,
    bootstrap_strata = comparison_bootstrap_strata(data),
    random_state = config$seed + config$contrast$seed_offset + 9000L,
    n_lambda = config$n_lambda,
    l1_ratio = config$l1_ratio,
    workers = config$workers,
    cv_workers = 1L
  )
  branch <- "nested_cv"
  cache_object(result, "nested_cv_result", branch, config)
  if (!is.null(result$outer_results)) {
    export_table(as.data.frame(result$outer_results), "nested_cv_outer_results", branch, config)
  }
  write_branch_manifest(branch, config)
  result
}

comparison_sample_cluster_purity <- function(mat, metadata, k = 2L) {
  if (ncol(mat) < k) return(tibble::tibble())
  hc <- stats::hclust(stats::dist(t(mat)))
  clusters <- stats::cutree(hc, k = k)
  as.data.frame(table(
    cluster = clusters,
    contrast_outcome = metadata[names(clusters), "contrast_outcome"]
  )) |>
    dplyr::group_by(.data$cluster) |>
    dplyr::mutate(
      cluster_total = sum(.data$Freq),
      cluster_purity = max(.data$Freq) / .data$cluster_total
    ) |>
    dplyr::ungroup()
}

export_comparison_embedding_plots <- function(mat, metadata, branch, config) {
  sample_mat <- t(mat)
  pca <- stats::prcomp(sample_mat, center = FALSE, scale. = FALSE)
  pca_df <- as.data.frame(pca$x[, 1:2, drop = FALSE]) |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::left_join(metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
  p_pca <- ggplot2::ggplot(
    pca_df,
    ggplot2::aes(.data$PC1, .data$PC2, color = .data$contrast_outcome, shape = .data$protection)
  ) +
    ggplot2::geom_point(size = 3, alpha = 0.9) +
    ggplot2::scale_color_manual(values = config$outcome_colors, drop = FALSE) +
    ggplot2::labs(title = paste0("PCA on selected or fallback features: ", config$contrast_title)) +
    ggplot2::theme_bw(base_size = 10)
  export_plot(p_pca, "selected_feature_pca", branch, config, width = 7, height = 6)

  if (requireNamespace("uwot", quietly = TRUE) && nrow(sample_mat) >= 10L) {
    set.seed(config$seed + config$contrast$seed_offset)
    umap <- uwot::umap(sample_mat, n_neighbors = min(10L, nrow(sample_mat) - 1L), metric = "euclidean")
    umap_df <- tibble::tibble(
      sample_id = rownames(sample_mat),
      UMAP1 = umap[, 1L],
      UMAP2 = umap[, 2L]
    ) |>
      dplyr::left_join(metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
    p_umap <- ggplot2::ggplot(
      umap_df,
      ggplot2::aes(.data$UMAP1, .data$UMAP2, color = .data$contrast_outcome, shape = .data$protection)
    ) +
      ggplot2::geom_point(size = 3, alpha = 0.9) +
      ggplot2::scale_color_manual(values = config$outcome_colors, drop = FALSE) +
      ggplot2::labs(title = paste0("UMAP on selected or fallback features: ", config$contrast_title)) +
      ggplot2::theme_bw(base_size = 10)
    export_plot(p_umap, "selected_feature_umap", branch, config, width = 7, height = 6)
  }
  invisible(pca_df)
}

run_visualize_branch_comparison <- function(data, config) {
  branch <- "visualize"
  early_cache <- file.path(branch_cache_dir(config, "early_fusion"), "stabl_fit_bundle.rds")
  if (!file.exists(early_cache)) {
    stop("Missing early-fusion cache: ", early_cache,
         ". Run branch 'early_fusion' before 'visualize'.", call. = FALSE)
  }
  early_bundle <- readRDS(early_cache)
  x_all_early <- do.call(cbind, purrr::imap(data$x_list, prefix_feature_names))
  feature_tbl <- choose_heatmap_features(early_bundle$fit, top_n = 50L)
  feature_tbl <- feature_tbl |>
    dplyr::left_join(split_prefixed_features(feature_tbl$feature), by = "feature") |>
    dplyr::arrange(dplyr::desc(.data$selected), dplyr::desc(.data$stability_score),
                   .data$view, .data$feature_name)
  mat <- make_selected_feature_matrix(x_all_early, feature_tbl)
  feature_tbl <- feature_tbl[match(rownames(mat), feature_tbl$feature), , drop = FALSE]
  export_table(feature_tbl, "selected_heatmap_features", branch, config)
  cache_object(list(matrix = mat, feature_metadata = feature_tbl),
               "selected_feature_heatmap_matrix", branch, config)

  export_heatmap(
    mat = mat,
    sample_metadata = data$metadata,
    feature_metadata = feature_tbl,
    name = "all_view_selected_feature_heatmap",
    branch = branch,
    config = config,
    row_split = feature_tbl$view,
    width = 13,
    height = 10
  )

  purity <- comparison_sample_cluster_purity(mat, data$metadata, k = length(config$contrast_levels))
  export_table(purity, "selected_feature_sample_cluster_purity", branch, config)
  pca_df <- export_comparison_embedding_plots(mat, data$metadata, branch, config)
  export_table(pca_df, "selected_feature_pca_scores", branch, config)

  late_pred_path <- file.path(
    branch_export_dir(config, "late_fusion", "tables"),
    "late_fusion_train_predictions.csv"
  )
  if (file.exists(late_pred_path)) {
    pred_tbl <- readr::read_csv(late_pred_path, show_col_types = FALSE)
    plot_binary_prediction_heatmap(pred_tbl, data$metadata, config, "late_fusion")
  }

  write_branch_manifest(branch, config)
  merge_artifact_manifests(config)
  invisible(list(features = feature_tbl, purity = purity))
}
