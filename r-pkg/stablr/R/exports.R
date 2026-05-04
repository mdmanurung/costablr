# exports.R — CSV/disk export helpers for fitted STABL objects
# R port of export_stabl_to_csv() and save_stabl_results() from stabl/stabl.py

#' Export STABL Stability Scores to CSV
#'
#' Writes the full stability-score matrix, the per-feature maximum stability
#' scores, and (when artificial features were used) the corresponding
#' artificial-feature scores to CSV files in the directory specified by
#' `path`.
#'
#' Files written:
#' - `STABL scores.csv` — full p x L stability score matrix.
#' - `Max STABL scores.csv` — per-feature maximum stability score, sorted
#'   descending.
#' - `STABL artificial scores.csv` — artificial feature scores (only when
#'   `object$artificial_type` is not `NULL`).
#' - `Max STABL artificial scores.csv` — artificial max scores, sorted
#'   descending (only when artificial features were used).
#'
#' @param object A fitted `"stabl_fit"` object from [stabl_fit()].
#' @param path Character string; path to an existing (or to-be-created)
#'   directory.
#'
#' @return Invisibly returns `path` (as a normalized string).
#' @export
export_stabl_to_csv <- function(object, path) {
  .check_fitted_stabl(object)
  if (!is.character(path) || length(path) != 1L) {
    stop("`path` must be a single character string.", call. = FALSE)
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  feat_names <- object$feature_names

  # Build column labels from the lambda grid rows
  col_labels <- .lambda_grid_row_labels(object$fitted_lambda_grid)

  # Full stability score matrix
  scores_df <- as.data.frame(object$stabl_scores_)
  rownames(scores_df) <- feat_names
  colnames(scores_df) <- col_labels
  utils::write.csv(scores_df, file = file.path(path, "STABL scores.csv"))

  # Max stability scores per feature (sorted descending)
  max_scores <- rowMaxs(object$stabl_scores_)
  max_df <- data.frame(
    "Max Proba" = max_scores,
    row.names   = feat_names,
    check.names = FALSE
  )
  max_df <- max_df[order(max_df[["Max Proba"]], decreasing = TRUE), , drop = FALSE]
  utils::write.csv(max_df, file = file.path(path, "Max STABL scores.csv"))

  # Artificial feature scores (only when present)
  if (!is.null(object$stabl_scores_artificial_)) {
    art_scores <- object$stabl_scores_artificial_
    n_art      <- nrow(art_scores)
    art_names  <- paste0("artificial.", seq_len(n_art))

    art_df <- as.data.frame(art_scores)
    rownames(art_df) <- art_names
    colnames(art_df) <- col_labels
    utils::write.csv(art_df,
                     file = file.path(path, "STABL artificial scores.csv"))

    max_art <- rowMaxs(art_scores)
    max_art_df <- data.frame(
      "Max Proba" = max_art,
      row.names   = art_names,
      check.names = FALSE
    )
    max_art_df <- max_art_df[
      order(max_art_df[["Max Proba"]], decreasing = TRUE), , drop = FALSE
    ]
    utils::write.csv(max_art_df,
                     file = file.path(path, "Max STABL artificial scores.csv"))
  }

  invisible(normalizePath(path))
}

#' Save All STABL Results to Disk
#'
#' Bundles all standard STABL diagnostics — stability scores, selected feature
#' list, FDR/stability-path plots, and per-feature distribution plots — into a
#' single output directory.
#'
#' @param object A fitted `"stabl_fit"` object.
#' @param path Character string; output directory to create.  Raises an error
#'   if the directory already exists and `override = FALSE`.
#' @param x Numeric matrix of predictors used to fit `object` (used for
#'   per-feature distribution plots).
#' @param y Outcome vector/factor/`Surv` object used to fit `object`.
#' @param figure_fmt Character; graphics device extension, e.g. `"pdf"`,
#'   `"png"`, `"svg"` (default `"pdf"`).
#' @param new_hard_threshold Numeric in `(0, 1]` or `NULL`.  When supplied,
#'   overrides the stored threshold for support extraction and path plotting.
#' @param task_type Character; one of `"binary"`, `"regression"`, or
#'   `"multiclass"`.  Determines which per-feature plot is generated.
#' @param override Logical; if `TRUE`, existing directory contents are
#'   overwritten.  Default `FALSE`.
#'
#' @return Invisibly returns `path`.
#' @export
save_stabl_results <- function(
    object,
    path,
    x,
    y,
    figure_fmt          = "pdf",
    new_hard_threshold  = NULL,
    task_type           = "binary",
    override            = FALSE
) {
  .check_fitted_stabl(object)
  if (!is.character(path) || length(path) != 1L) {
    stop("`path` must be a single character string.", call. = FALSE)
  }
  task_type <- match.arg(task_type, c("binary", "multiclass", "regression"))

  # Create output directory (fail if exists and override = FALSE)
  if (dir.exists(path) && !override) {
    stop(
      "Directory already exists: ", path,
      ". Set `override = TRUE` to overwrite.",
      call. = FALSE
    )
  }
  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  # 1. CSV exports
  export_stabl_to_csv(object, path)

  # 2. FDR graph (only when artificial features were used)
  if (!is.null(object$artificial_type) && !is.null(object$FDRs_)) {
    p_fdr <- plot_fdr_graph(object)
    ggplot2::ggsave(
      filename = file.path(path, paste0("FDR Graph.", figure_fmt)),
      plot     = p_fdr,
      width    = 8, height = 4
    )
  }

  # 3. Stability path
  p_path <- plot_stabl_path(object, new_hard_threshold = new_hard_threshold)
  ggplot2::ggsave(
    filename = file.path(path, paste0("Stability Path.", figure_fmt)),
    plot     = p_path,
    width    = 6, height = 8
  )

  # 4. Selected features list → CSV
  sel_features <- get_feature_names_out(object,
                                        new_hard_threshold = new_hard_threshold)
  sel_dir <- file.path(path, "Selected Features")
  dir.create(sel_dir, recursive = TRUE, showWarnings = FALSE)

  sel_df <- data.frame(
    "Feature Name" = sel_features,
    row.names      = paste0("Feature n\u00b0", seq_along(sel_features)),
    check.names    = FALSE
  )
  utils::write.csv(sel_df, file = file.path(sel_dir, "Selected features.csv"))

  # 5. Per-feature distribution plots
  if (length(sel_features) > 0L) {
    if (task_type %in% c("binary", "multiclass")) {
      p_feats <- boxplot_features(
        features = sel_features,
        x        = x,
        y        = y
      )
      ggplot2::ggsave(
        filename = file.path(sel_dir,
                             paste0("Feature distributions.", figure_fmt)),
        plot   = p_feats,
        width  = max(4, 3 * min(length(sel_features), 4)),
        height = ceiling(length(sel_features) / 4) * 3
      )
    } else if (task_type == "regression") {
      p_feats <- scatterplot_features(
        features = sel_features,
        x        = x,
        y        = y
      )
      ggplot2::ggsave(
        filename = file.path(sel_dir,
                             paste0("Feature distributions.", figure_fmt)),
        plot   = p_feats,
        width  = max(4, 3 * min(length(sel_features), 4)),
        height = ceiling(length(sel_features) / 4) * 3
      )
    }
  }

  invisible(normalizePath(path))
}

# ── Internal helpers ──────────────────────────────────────────────────────────

# Row-wise max without external dependencies
rowMaxs <- function(m) apply(m, 1L, max)

# Build readable column labels from the lambda grid (one label per row)
.lambda_grid_row_labels <- function(lambda_grid) {
  if (nrow(lambda_grid) == 0L) return(character(0L))
  apply(lambda_grid, 1L, function(row) {
    pairs <- paste0(names(row), "=", signif(as.numeric(row), 4L))
    paste(pairs, collapse = ", ")
  })
}
