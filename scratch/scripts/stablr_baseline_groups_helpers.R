# Shared helpers for the AURORA baseline study-group STABL analysis.

`%||%` <- function(x, y) if (is.null(x)) y else x

baseline_default_paths <- function() {
  c(
    cytof_celltype = "/exports/para-lipg-hpc/Xuran/data/cytof/analysis/clus_freq_clr_combat.csv",
    exvivo_celltype = "/exports/para-lipg-hpc/Xuran/data/aurora_exvivo/analysis/clus_freq_combat.csv",
    exvivo_enzyme = "/exports/para-lipg-hpc/Xuran/data/aurora_exvivo/analysis/enzyme_celltype_combat.csv",
    `6h_cyto_LPS` = "/exports/para-lipg-hpc/Xuran/data/aurora_6H/analysis/cytokine_pos_6hLPS_combat.csv",
    `6h_cyto_ssRNA40` = "/exports/para-lipg-hpc/Xuran/data/aurora_6H/analysis/cytokine_pos_6hssRNA40_combat.csv",
    `24h_cyto_iRBC` = "/exports/para-lipg-hpc/Xuran/data/aurora_24H/analysis/cytokine_pos_24hiRBC_combat.csv",
    `24h_cyto_SEB` = "/exports/para-lipg-hpc/Xuran/data/aurora_24H/analysis/cytokine_pos_24hSEB_combat.csv",
    `24h_enzyme_iRBC` = "/exports/para-lipg-hpc/Xuran/data/aurora_24H/analysis/enzyme_celltype_24hiRBC_combat.csv",
    `24h_enzyme_SEB` = "/exports/para-lipg-hpc/Xuran/data/aurora_24H/analysis/enzyme_celltype_24hSEB_combat.csv",
    `3d_cyto` = "/exports/para-lipg-hpc/Xuran/data/aurora_3D/analysis/cytokine_pos_combat.csv",
    `3d_enzyme` = "/exports/para-lipg-hpc/Xuran/data/aurora_3D/analysis/enzyme_celltype_combat.csv"
  )
}

baseline_config <- function() {
  cpus <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", "8"))
  if (is.na(cpus) || cpus < 1L) cpus <- 8L
  list(
    all_view_paths = baseline_default_paths(),
    metadata_path = Sys.getenv(
      "STABLR_BASELINE_METADATA",
      "/exports/para-lipg-hpc/Xuran/data/metadata.csv"
    ),
    seed = as.integer(Sys.getenv("STABLR_SEED", "20260512")),
    imputation_seed = as.integer(Sys.getenv("STABLR_IMPUTATION_SEED", "101")),
    family = "multinomial",
    base_learner = "elastic_net",
    l1_ratio = as.numeric(Sys.getenv("STABLR_L1_RATIO", "0.5")),
    n_bootstraps = as.integer(Sys.getenv("STABLR_N_BOOTSTRAPS", "500")),
    n_lambda = as.integer(Sys.getenv("STABLR_N_LAMBDA", "20")),
    sample_fraction = as.numeric(Sys.getenv("STABLR_SAMPLE_FRACTION", "0.8")),
    artificial_type = Sys.getenv("STABLR_ARTIFICIAL_TYPE", "random_permutation"),
    artificial_proportion = as.numeric(Sys.getenv("STABLR_ARTIFICIAL_PROPORTION", "1")),
    fdr_threshold_range = seq(0, 0.99, by = 0.01),
    workers = cpus,
    cache_dir = Sys.getenv(
      "STABLR_CACHE_DIR",
      file.path("scratch", "cache", "stablr_baseline_groups_test")
    ),
    export_dir = Sys.getenv(
      "STABLR_EXPORT_DIR",
      file.path("scratch", "outputs", "stablr_baseline_groups_test")
    ),
    study_group_map = c(CVTU3 = "TU", EGSV2 = "EG", PfGA2 = "GA"),
    study_group_levels = c("EG", "GA", "TU"),
    study_group_colors = c(EG = "#4C78A8", GA = "#F58518", TU = "#54A24B")
  )
}

setup_stablr_for_baseline <- function() {
  find_root <- function(start = getwd()) {
    path <- normalizePath(start, winslash = "/", mustWork = TRUE)
    repeat {
      candidates <- c(file.path(path, "r-pkg", "stablr"), path)
      for (candidate in candidates) {
        desc <- file.path(candidate, "DESCRIPTION")
        if (file.exists(desc)) {
          fields <- tryCatch(read.dcf(desc), error = function(e) NULL)
          if (!is.null(fields) && "Package" %in% colnames(fields) &&
              identical(unname(fields[1, "Package"]), "stablr")) {
            return(candidate)
          }
        }
      }
      parent <- dirname(path)
      if (identical(parent, path)) break
      path <- parent
    }
    NA_character_
  }
  pkg_root <- find_root()
  if (!is.na(pkg_root) && requireNamespace("devtools", quietly = TRUE)) {
    suppressPackageStartupMessages(devtools::load_all(pkg_root, quiet = TRUE))
  } else {
    suppressPackageStartupMessages(library(stablr))
  }
  required <- c("dplyr", "tidyr", "ggplot2", "tibble", "purrr", "readr", "forcats")
  missing <- required[!vapply(required, requireNamespace, logical(1L), quietly = TRUE)]
  if (length(missing) > 0L) {
    stop("Install required packages: ", paste(missing, collapse = ", "), call. = FALSE)
  }
  suppressPackageStartupMessages(invisible(lapply(required, library, character.only = TRUE)))
}

.artifact_env <- new.env(parent = emptyenv())
.artifact_env$manifest <- data.frame(
  branch = character(),
  object_type = character(),
  name = character(),
  path = character(),
  timestamp = character(),
  stringsAsFactors = FALSE
)

branch_cache_dir <- function(config, branch) {
  path <- file.path(config$cache_dir, branch)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

branch_export_dir <- function(config, branch, type = NULL) {
  path <- if (is.null(type)) config$export_dir else file.path(config$export_dir, branch, type)
  if (is.null(type)) path <- file.path(config$export_dir, branch)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

record_artifact <- function(branch, object_type, name, path) {
  .artifact_env$manifest <- rbind(
    .artifact_env$manifest,
    data.frame(
      branch = branch,
      object_type = object_type,
      name = name,
      path = normalizePath(path, winslash = "/", mustWork = FALSE),
      timestamp = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
      stringsAsFactors = FALSE
    )
  )
  invisible(path)
}

cache_object <- function(object, name, branch, config) {
  path <- file.path(branch_cache_dir(config, branch), paste0(name, ".rds"))
  saveRDS(object, path)
  record_artifact(branch, "rds", name, path)
  invisible(path)
}

export_table <- function(x, name, branch, config) {
  path <- file.path(branch_export_dir(config, branch, "tables"), paste0(name, ".csv"))
  readr::write_csv(x, path)
  record_artifact(branch, "csv", name, path)
  invisible(path)
}

export_plot <- function(p, name, branch, config, width = 10, height = 7) {
  fig_dir <- branch_export_dir(config, branch, "figures")
  png_path <- file.path(fig_dir, paste0(name, ".png"))
  pdf_path <- file.path(fig_dir, paste0(name, ".pdf"))
  ggplot2::ggsave(png_path, p, width = width, height = height, dpi = 300)
  ggplot2::ggsave(pdf_path, p, width = width, height = height)
  record_artifact(branch, "png", name, png_path)
  record_artifact(branch, "pdf", name, pdf_path)
  invisible(c(png = png_path, pdf = pdf_path))
}

write_branch_manifest <- function(branch, config) {
  manifest <- .artifact_env$manifest
  cache_object(manifest, "artifact_manifest", branch, config)
  export_table(manifest, "artifact_manifest", branch, config)
  invisible(manifest)
}

merge_artifact_manifests <- function(config) {
  cache_manifests <- list.files(
    config$cache_dir,
    pattern = "^artifact_manifest[.]rds$",
    recursive = TRUE,
    full.names = TRUE
  )
  manifests <- lapply(cache_manifests, function(path) {
    out <- tryCatch(readRDS(path), error = function(e) NULL)
    if (is.null(out)) return(NULL)
    out$manifest_source <- normalizePath(path, winslash = "/", mustWork = FALSE)
    out
  })
  manifest <- dplyr::bind_rows(manifests)
  if (nrow(manifest) > 0L) {
    manifest <- dplyr::distinct(manifest)
  }
  dir.create(config$cache_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(config$export_dir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(manifest, file.path(config$cache_dir, "artifact_manifest.rds"))
  readr::write_csv(manifest, file.path(config$export_dir, "artifact_manifest.csv"))
  invisible(manifest)
}

read_feature_matrix <- function(path) {
  x <- read.csv(path, row.names = 1, check.names = FALSE)
  x <- as.matrix(x)
  storage.mode(x) <- "double"
  x
}

read_metadata <- function(path) {
  meta <- read.csv(path, row.names = 1, check.names = FALSE)
  if ("sample_id" %in% names(meta) && identical(rownames(meta), as.character(seq_len(nrow(meta))))) {
    rownames(meta) <- as.character(meta$sample_id)
  }
  if ("sample_id" %in% names(meta)) meta$sample_id <- NULL
  meta
}

add_analysis_labels <- function(meta, config) {
  meta <- as.data.frame(meta, check.names = FALSE)
  meta$protection <- dplyr::case_when(
    as.character(meta$chmi_qPCR) == "No" ~ "P",
    as.character(meta$chmi_qPCR) == "Yes" ~ "NP",
    TRUE ~ NA_character_
  )
  meta$protection <- factor(meta$protection, levels = c("P", "NP"))
  meta$study_id <- factor(meta$study_id, levels = names(config$study_group_map))
  meta$study_group <- unname(config$study_group_map[as.character(meta$study_id)])
  meta$study_group <- factor(meta$study_group, levels = config$study_group_levels)
  meta$timepoint <- factor(meta$timepoint, levels = c("t1", "t2", "t3"))
  meta
}

safe_natural_sort <- function(x) {
  if (requireNamespace("naturalsort", quietly = TRUE)) naturalsort::naturalsort(x) else sort(x)
}

preprocess_all_views <- function(config, force = FALSE) {
  cache_path <- file.path(branch_cache_dir(config, "preprocess"), "baseline_preprocessed.rds")
  if (file.exists(cache_path) && !isTRUE(force)) return(readRDS(cache_path))

  metadata_raw <- read_metadata(config$metadata_path)
  raw_blocks <- lapply(config$all_view_paths, read_feature_matrix)
  names(raw_blocks) <- names(config$all_view_paths)
  analysis_samples <- safe_natural_sort(Reduce(union, lapply(raw_blocks, rownames)))
  pfga1 <- rownames(metadata_raw)[!is.na(metadata_raw$study_id) & metadata_raw$study_id == "PfGA1"]
  analysis_samples <- setdiff(analysis_samples, pfga1)

  if (!requireNamespace("missForest", quietly = TRUE)) {
    stop("Package 'missForest' is required for preprocessing.", call. = FALSE)
  }
  if (!requireNamespace("mixOmics", quietly = TRUE)) {
    stop("Package 'mixOmics' is required for preprocessing.", call. = FALSE)
  }

  set.seed(config$imputation_seed)
  aligned <- purrr::imap(raw_blocks, function(x, view) {
    x <- as.data.frame(x, check.names = FALSE)
    missing_samples <- setdiff(analysis_samples, rownames(x))
    if (length(missing_samples) > 0L) {
      add <- as.data.frame(matrix(NA_real_, nrow = length(missing_samples), ncol = ncol(x),
                                  dimnames = list(missing_samples, colnames(x))))
      x <- rbind(x, add)
    }
    x <- x[analysis_samples, , drop = FALSE]
    colnames(x) <- make.unique(colnames(x), sep = "__dup")
    if (anyNA(x)) x <- missForest::missForest(x, verbose = TRUE)$ximp
    out <- as.matrix(x)
    storage.mode(out) <- "double"
    rownames(out) <- analysis_samples
    out
  })

  nzv_summary <- list()
  filtered <- purrr::imap(aligned, function(x, view) {
    nzv <- mixOmics::nearZeroVar(x, freqCut = 95 / 5, uniqueCut = 10)
    remove_idx <- if (is.null(nzv$Position)) integer(0) else as.integer(nzv$Position)
    keep_idx <- setdiff(seq_len(ncol(x)), remove_idx)
    nzv_summary[[view]] <<- tibble::tibble(
      view = view,
      n_features_before_nzv = ncol(x),
      n_near_zero_variance_features = length(remove_idx),
      n_features_after_nzv = length(keep_idx)
    )
    x[, keep_idx, drop = FALSE]
  })

  scale_summary <- list()
  scaled <- purrr::imap(filtered, function(x, view) {
    med <- apply(x, 2L, stats::median, na.rm = TRUE)
    madv <- apply(x, 2L, stats::mad, na.rm = TRUE)
    zero_mad <- !is.finite(madv) | madv <= .Machine$double.eps
    z <- sweep(x, 2L, med, "-")
    mode <- if (identical(view, "cytof_celltype")) "center_only" else "median_mad"
    if (!identical(mode, "center_only")) {
      if (any(!zero_mad)) z[, !zero_mad] <- sweep(z[, !zero_mad, drop = FALSE], 2L, madv[!zero_mad], "/")
      if (any(zero_mad)) z[, zero_mad] <- 0
    }
    frob <- norm(z, type = "F")
    z <- z / frob
    scale_summary[[view]] <<- tibble::tibble(
      view = view,
      scaling_mode = mode,
      n_samples = nrow(z),
      n_features = ncol(z),
      zero_mad_features = sum(zero_mad),
      frob_before = frob,
      frob_after = norm(z, type = "F")
    )
    z
  })

  metadata <- add_analysis_labels(metadata_raw, config)
  eligible <- rownames(metadata)[metadata$timepoint == "t1" & !is.na(metadata$study_group)]
  common_ids <- Reduce(intersect, c(list(eligible), lapply(scaled, rownames)))
  common_ids <- eligible[eligible %in% common_ids]
  x_list <- lapply(scaled, function(x) x[common_ids, , drop = FALSE])
  metadata_baseline <- droplevels(metadata[common_ids, , drop = FALSE])
  y <- stats::setNames(metadata_baseline$study_group, common_ids)

  out <- list(
    x_list = x_list,
    y = y,
    metadata = metadata_baseline,
    analysis_samples = analysis_samples,
    nzv_summary = dplyr::bind_rows(nzv_summary),
    scaling_qc = dplyr::bind_rows(scale_summary)
  )
  cache_object(out, "baseline_preprocessed", "preprocess", config)
  export_table(out$nzv_summary, "near_zero_variance_qc", "preprocess", config)
  export_table(out$scaling_qc, "scaling_qc", "preprocess", config)
  write_branch_manifest("preprocess", config)
  out
}

make_lambda_grid <- function(x, y, config, family = config$family) {
  auto_lambda_grid(
    x,
    y,
    family = family,
    n_lambda = config$n_lambda,
    l1_ratio = config$l1_ratio
  )
}

fit_stabl_branch <- function(x, y, config, branch, family = config$family,
                             bootstrap_strata = NULL, seed_offset = 0L) {
  lambda_grid <- make_lambda_grid(x, y, config, family = family)
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
  out <- list(fit = fit, lambda_grid = lambda_grid)
  cache_object(out, "stabl_fit_bundle", branch, config)
  imp <- tibble::tibble(
    feature = names(get_importances(fit)),
    stability_score = as.numeric(get_importances(fit)),
    selected = names(get_importances(fit)) %in% get_feature_names_out(fit)
  )
  export_table(imp, "feature_importance", branch, config)
  write_branch_manifest(branch, config)
  out
}

prefix_feature_names <- function(x, view) {
  x <- as.matrix(x)
  colnames(x) <- paste(view, colnames(x), sep = "__")
  x
}

split_prefixed_features <- function(features) {
  parts <- strsplit(features, "__", fixed = TRUE)
  tibble::tibble(
    feature = features,
    view = vapply(parts, function(x) x[[1L]], character(1L)),
    feature_name = vapply(parts, function(x) paste(x[-1L], collapse = "__"), character(1L))
  )
}

classification_metric_table <- function(truth, predicted, levels = NULL) {
  levels <- levels %||% levels(factor(truth))
  truth <- factor(truth, levels = levels)
  predicted <- factor(predicted, levels = levels)
  confusion <- table(truth = truth, predicted = predicted)
  recall <- diag(confusion) / pmax(rowSums(confusion), 1L)
  precision <- diag(confusion) / pmax(colSums(confusion), 1L)
  f1 <- ifelse(precision + recall > 0, 2 * precision * recall / (precision + recall), 0)
  tibble::tibble(
    metric = c("accuracy", "balanced_error_rate", "macro_f1"),
    value = c(
      mean(truth == predicted, na.rm = TRUE),
      mean(1 - recall, na.rm = TRUE),
      mean(f1)
    )
  )
}

confusion_table <- function(truth, predicted, levels = NULL) {
  levels <- levels %||% levels(factor(truth))
  as.data.frame(table(
    truth = factor(truth, levels = levels),
    predicted = factor(predicted, levels = levels)
  ))
}

choose_heatmap_features <- function(fit, top_n = 50L) {
  scores <- sort(get_importances(fit), decreasing = TRUE)
  selected <- get_feature_names_out(fit)
  if (length(selected) > 0L) {
    features <- selected
    fallback <- FALSE
  } else {
    features <- names(scores)[seq_len(min(top_n, length(scores)))]
    fallback <- TRUE
  }
  tibble::tibble(
    feature = features,
    stability_score = as.numeric(scores[features]),
    selected = features %in% selected,
    exploratory_fallback = fallback
  )
}

make_selected_feature_matrix <- function(x, feature_tbl) {
  features <- intersect(feature_tbl$feature, colnames(x))
  mat <- t(x[, features, drop = FALSE])
  mat <- t(scale(t(mat)))
  mat[!is.finite(mat)] <- 0
  mat
}

export_heatmap <- function(mat, sample_metadata, feature_metadata, name, branch, config,
                           cluster_rows = TRUE, cluster_columns = TRUE,
                           row_split = NULL, width = 12, height = 9) {
  sample_metadata <- as.data.frame(sample_metadata, check.names = FALSE)
  sample_metadata <- sample_metadata[colnames(mat), , drop = FALSE]
  feature_metadata <- as.data.frame(feature_metadata, check.names = FALSE)
  feature_metadata <- feature_metadata[match(rownames(mat), feature_metadata$feature), , drop = FALSE]

  fig_dir <- branch_export_dir(config, branch, "figures")
  png_path <- file.path(fig_dir, paste0(name, ".png"))
  pdf_path <- file.path(fig_dir, paste0(name, ".pdf"))

  if (requireNamespace("ComplexHeatmap", quietly = TRUE) &&
      requireNamespace("circlize", quietly = TRUE)) {
    sex_annotation <- if ("sex" %in% names(sample_metadata)) {
      sample_metadata$sex
    } else {
      rep(NA_character_, nrow(sample_metadata))
    }
    top_ha <- ComplexHeatmap::HeatmapAnnotation(
      study_group = sample_metadata$study_group,
      study_id = sample_metadata$study_id,
      protection = sample_metadata$protection,
      sex = sex_annotation,
      col = list(study_group = config$study_group_colors)
    )
    left_ha <- ComplexHeatmap::rowAnnotation(
      view = feature_metadata$view,
      selected = feature_metadata$selected
    )
    ht <- ComplexHeatmap::Heatmap(
      mat,
      name = "z",
      top_annotation = top_ha,
      left_annotation = left_ha,
      cluster_rows = cluster_rows,
      cluster_columns = cluster_columns,
      row_split = row_split,
      show_column_names = FALSE,
      column_title = "Baseline samples",
      row_title = "Selected or fallback features"
    )
    grDevices::png(png_path, width = width * 200, height = height * 200, res = 200)
    ComplexHeatmap::draw(ht)
    grDevices::dev.off()
    grDevices::pdf(pdf_path, width = width, height = height)
    ComplexHeatmap::draw(ht)
    grDevices::dev.off()
    record_artifact(branch, "png", name, png_path)
    record_artifact(branch, "pdf", name, pdf_path)
  } else if (requireNamespace("pheatmap", quietly = TRUE)) {
    annotation_col <- sample_metadata[, intersect(c("study_group", "study_id", "protection", "sex"), names(sample_metadata)), drop = FALSE]
    annotation_row <- feature_metadata[, intersect(c("view", "selected"), names(feature_metadata)), drop = FALSE]
    rownames(annotation_col) <- colnames(mat)
    rownames(annotation_row) <- rownames(mat)
    pheatmap::pheatmap(
      mat,
      annotation_col = annotation_col,
      annotation_row = annotation_row,
      cluster_rows = cluster_rows,
      cluster_cols = cluster_columns,
      show_colnames = FALSE,
      filename = png_path,
      width = width,
      height = height
    )
    pheatmap::pheatmap(
      mat,
      annotation_col = annotation_col,
      annotation_row = annotation_row,
      cluster_rows = cluster_rows,
      cluster_cols = cluster_columns,
      show_colnames = FALSE,
      filename = pdf_path,
      width = width,
      height = height
    )
    record_artifact(branch, "png", name, png_path)
    record_artifact(branch, "pdf", name, pdf_path)
  } else {
    plot_df <- as.data.frame(mat, check.names = FALSE) |>
      tibble::rownames_to_column("feature") |>
      tidyr::pivot_longer(cols = -dplyr::all_of("feature"),
                          names_to = "sample_id", values_to = "z")
    p <- ggplot2::ggplot(plot_df, ggplot2::aes(.data$sample_id, .data$feature, fill = .data$z)) +
      ggplot2::geom_tile() +
      ggplot2::scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B") +
      ggplot2::labs(x = "Sample", y = NULL, fill = "z") +
      ggplot2::theme_bw(base_size = 9) +
      ggplot2::theme(axis.text.x = ggplot2::element_blank(), axis.ticks.x = ggplot2::element_blank())
    export_plot(p, name, branch, config, width = width, height = height)
  }
  invisible(c(png = png_path, pdf = pdf_path))
}

sample_cluster_purity <- function(mat, metadata, k = 3L) {
  if (ncol(mat) < k) return(tibble::tibble())
  hc <- stats::hclust(stats::dist(t(mat)))
  clusters <- stats::cutree(hc, k = k)
  tab <- as.data.frame(table(
    cluster = clusters,
    study_group = metadata[names(clusters), "study_group"]
  ))
  tab |>
    dplyr::group_by(.data$cluster) |>
    dplyr::mutate(
      cluster_total = sum(.data$Freq),
      cluster_purity = max(.data$Freq) / .data$cluster_total
    ) |>
    dplyr::ungroup()
}

export_embedding_plots <- function(mat, metadata, branch, config) {
  sample_mat <- t(mat)
  pca <- stats::prcomp(sample_mat, center = FALSE, scale. = FALSE)
  pca_df <- as.data.frame(pca$x[, 1:2, drop = FALSE]) |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::left_join(metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
  p_pca <- ggplot2::ggplot(
    pca_df,
    ggplot2::aes(.data$PC1, .data$PC2, color = .data$study_group, shape = .data$protection)
  ) +
    ggplot2::geom_point(size = 3, alpha = 0.9) +
    ggplot2::scale_color_manual(values = config$study_group_colors, drop = FALSE) +
    ggplot2::labs(title = "PCA on selected or fallback immune-signature features") +
    ggplot2::theme_bw(base_size = 10)
  export_plot(p_pca, "selected_feature_pca", branch, config, width = 7, height = 6)

  if (requireNamespace("uwot", quietly = TRUE) && nrow(sample_mat) >= 10L) {
    set.seed(config$seed)
    umap <- uwot::umap(sample_mat, n_neighbors = min(10L, nrow(sample_mat) - 1L), metric = "euclidean")
    umap_df <- tibble::tibble(
      sample_id = rownames(sample_mat),
      UMAP1 = umap[, 1L],
      UMAP2 = umap[, 2L]
    ) |>
      dplyr::left_join(metadata |> tibble::rownames_to_column("sample_id"), by = "sample_id")
    p_umap <- ggplot2::ggplot(
      umap_df,
      ggplot2::aes(.data$UMAP1, .data$UMAP2, color = .data$study_group, shape = .data$protection)
    ) +
      ggplot2::geom_point(size = 3, alpha = 0.9) +
      ggplot2::scale_color_manual(values = config$study_group_colors, drop = FALSE) +
      ggplot2::labs(title = "UMAP on selected or fallback immune-signature features") +
      ggplot2::theme_bw(base_size = 10)
    export_plot(p_umap, "selected_feature_umap", branch, config, width = 7, height = 6)
  }
  invisible(pca_df)
}

run_late_fusion_branch <- function(data, config) {
  bootstrap_strata <- data.frame(study_group = data$y, row.names = names(data$y))
  fit <- stabl_multiomic_train_validate(
    x_train_list = data$x_list,
    y_train = data$y,
    lambda_grid = "auto",
    base_learner = config$base_learner,
    family = config$family,
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    stratify_bootstrap = TRUE,
    bootstrap_strata_train = bootstrap_strata,
    l1_ratio = config$l1_ratio,
    n_lambda = config$n_lambda,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    random_state = config$seed + 7000L,
    late_fusion = TRUE,
    n_iter_lf = as.integer(Sys.getenv("STABLR_N_ITER_LF", "5000"))
  )
  cache_object(fit, "late_fusion_result", "late_fusion", config)
  export_table(fit$late_fusion$weights |> tibble::rownames_to_column("view"),
               "late_fusion_weights", "late_fusion", config)
  pred_tbl <- fit$late_fusion$train_predictions |>
    tibble::rownames_to_column("sample_id") |>
    dplyr::mutate(truth = as.character(data$y[.data$sample_id]), .after = "sample_id")
  export_table(pred_tbl, "late_fusion_train_predictions", "late_fusion", config)
  export_table(
    confusion_table(pred_tbl$truth, pred_tbl$predicted_class, levels = config$study_group_levels),
    "late_fusion_confusion_matrix",
    "late_fusion",
    config
  )
  metrics <- classification_metric_table(
    pred_tbl$truth,
    pred_tbl$predicted_class,
    levels = config$study_group_levels
  ) |>
    dplyr::bind_rows(tibble::tibble(metric = "log_loss", value = fit$late_fusion$log_loss))
  export_table(metrics, "late_fusion_metrics", "late_fusion", config)
  plot_prediction_heatmap(pred_tbl, data$metadata, config, "late_fusion")
  write_branch_manifest("late_fusion", config)
  fit
}

run_cooperative_ovr_branch <- function(data, config, group) {
  y_bin <- factor(ifelse(as.character(data$y) == group, group, "rest"),
                  levels = c("rest", group))
  names(y_bin) <- names(data$y)
  bootstrap_strata <- data.frame(
    outcome = y_bin,
    study_group = data$y,
    row.names = names(data$y)
  )
  fit <- stabl_multiomic_train_validate(
    x_train_list = data$x_list,
    y_train = y_bin,
    lambda_grid = "auto",
    base_learner = config$base_learner,
    family = "binomial",
    n_bootstraps = config$n_bootstraps,
    artificial_type = config$artificial_type,
    stratify_bootstrap = TRUE,
    bootstrap_strata_train = bootstrap_strata,
    l1_ratio = config$l1_ratio,
    n_lambda = config$n_lambda,
    sample_fraction = config$sample_fraction,
    replace = FALSE,
    random_state = config$seed + match(group, config$study_group_levels) * 1000L,
    cooperative_fusion = TRUE,
    rho = c(0, 0.1, 0.25, 0.5, 1),
    cooperation_selection = "cv",
    cooperation_selector = "lambda.1se",
    cooperation_type_measure = "deviance",
    cooperation_nfolds = 5L
  )
  branch <- paste0("cooperative_ovr/", group)
  cache_object(fit, "cooperative_fit", branch, config)
  export_table(get_cooperative_diagnostics(fit),
               "cooperative_diagnostics", branch, config)
  features <- get_cooperative_features(fit)
  feature_tbl <- purrr::imap_dfr(features, function(x, view) {
    tibble::tibble(view = view, feature = x)
  })
  export_table(feature_tbl, "cooperative_features", branch, config)
  write_branch_manifest(branch, config)
  fit
}

  plot_prediction_heatmap <- function(predictions, metadata, config, branch) {
  prob_cols <- grep("^prob_", names(predictions), value = TRUE)
  if (length(prob_cols) == 0L) return(invisible(NULL))
  mat <- as.matrix(predictions[, prob_cols, drop = FALSE])
  rownames(mat) <- predictions$sample_id %||% rownames(predictions)
  mat <- t(mat)
  if (requireNamespace("ComplexHeatmap", quietly = TRUE) &&
      requireNamespace("circlize", quietly = TRUE)) {
    ha <- ComplexHeatmap::HeatmapAnnotation(
      study_group = metadata[colnames(mat), "study_group"],
      protection = metadata[colnames(mat), "protection"],
      col = list(study_group = config$study_group_colors)
    )
    ht <- ComplexHeatmap::Heatmap(
      mat,
      name = "probability",
      top_annotation = ha,
      cluster_rows = FALSE,
      cluster_columns = TRUE
    )
    fig_dir <- branch_export_dir(config, branch, "figures")
    png_path <- file.path(fig_dir, "prediction_probability_heatmap.png")
    pdf_path <- file.path(fig_dir, "prediction_probability_heatmap.pdf")
    grDevices::png(png_path, width = 2200, height = 1200, res = 200)
    ComplexHeatmap::draw(ht)
    grDevices::dev.off()
    grDevices::pdf(pdf_path, width = 11, height = 6)
    ComplexHeatmap::draw(ht)
    grDevices::dev.off()
    record_artifact(branch, "png", "prediction_probability_heatmap", png_path)
    record_artifact(branch, "pdf", "prediction_probability_heatmap", pdf_path)
  } else {
    plot_df <- as.data.frame(mat, check.names = FALSE) |>
      tibble::rownames_to_column("class") |>
      tidyr::pivot_longer(cols = -dplyr::all_of("class"),
                          names_to = "sample_id", values_to = "probability") |>
      dplyr::left_join(
        metadata |> tibble::rownames_to_column("sample_id"),
        by = "sample_id"
      )
    p <- ggplot2::ggplot(
      plot_df,
      ggplot2::aes(.data$sample_id, .data$class, fill = .data$probability)
    ) +
      ggplot2::geom_tile(color = "white", linewidth = 0.15) +
      ggplot2::facet_grid(. ~ study_group, scales = "free_x", space = "free_x") +
      ggplot2::scale_fill_gradient(low = "white", high = "#2166AC", limits = c(0, 1)) +
      ggplot2::labs(
        title = "Late-fusion class probabilities",
        x = "Sample",
        y = NULL,
        fill = "Probability"
      ) +
      ggplot2::theme_bw(base_size = 9) +
      ggplot2::theme(
        axis.text.x = ggplot2::element_blank(),
        axis.ticks.x = ggplot2::element_blank()
      )
    export_plot(p, "prediction_probability_heatmap", branch, config, width = 10, height = 4)
  }
}

run_visualize_branch <- function(data, config) {
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
    dplyr::arrange(dplyr::desc(.data$selected),
                   dplyr::desc(.data$stability_score),
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

  weighted_tbl <- feature_tbl |>
    dplyr::mutate(weighted_rank = .data$stability_score) |>
    dplyr::arrange(dplyr::desc(.data$weighted_rank))
  weighted_mat <- mat[weighted_tbl$feature, , drop = FALSE]
  export_heatmap(
    mat = weighted_mat,
    sample_metadata = data$metadata,
    feature_metadata = weighted_tbl,
    name = "stability_weighted_selected_feature_heatmap",
    branch = branch,
    config = config,
    row_split = weighted_tbl$view,
    width = 13,
    height = 10
  )

  purity <- sample_cluster_purity(mat, data$metadata, k = length(config$study_group_levels))
  export_table(purity, "selected_feature_sample_cluster_purity", branch, config)
  pca_df <- export_embedding_plots(mat, data$metadata, branch, config)
  export_table(pca_df, "selected_feature_pca_scores", branch, config)

  late_pred_path <- file.path(
    branch_export_dir(config, "late_fusion", "tables"),
    "late_fusion_train_predictions.csv"
  )
  if (file.exists(late_pred_path)) {
    pred_tbl <- readr::read_csv(late_pred_path, show_col_types = FALSE)
    plot_prediction_heatmap(pred_tbl, data$metadata, config, "late_fusion")
  }

  write_branch_manifest(branch, config)
  merge_artifact_manifests(config)
  invisible(list(features = feature_tbl, purity = purity))
}
