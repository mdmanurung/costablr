## generate_ool_extdata.R
## Run once from the repo root to produce inst/extdata/ subset files.
## Usage:
##   conda run -n R4_51 Rscript r-pkg/stablr/scripts/generate_ool_extdata.R

resolve_pkg_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  script_file <- grep("^--file=", args, value = TRUE)
  if (length(script_file) > 0L) {
    script_path <- normalizePath(sub("^--file=", "", script_file[[1L]]),
                                 winslash = "/", mustWork = TRUE)
    candidate <- dirname(dirname(script_path))
    if (dir.exists(file.path(candidate, "R"))) return(candidate)
  }
  candidates <- c(
    file.path(getwd(), "r-pkg", "stablr"),
    "r-pkg/stablr"
  )
  hit <- candidates[vapply(candidates, function(p) dir.exists(file.path(p, "R")), logical(1L))]
  if (length(hit) == 0L) {
    stop("Could not locate stablr package root.", call. = FALSE)
  }
  normalizePath(hit[[1L]], winslash = "/", mustWork = TRUE)
}

pkg_root <- resolve_pkg_root()

out_dir <- file.path(pkg_root, "inst", "extdata")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

data_root <- file.path(dirname(dirname(pkg_root)), "Sample Data", "Onset of Labor")
train_dir <- file.path(data_root, "Training")
valid_dir <- file.path(data_root, "Validation")

MAX_FEAT_COLS <- 100L  # keep first 100 feature columns (after row-ID col)

.subset_and_write_gz <- function(src, dst, max_feat_cols = MAX_FEAT_COLS) {
  df <- read.csv(src, check.names = FALSE)
  # First column is always the sample ID (named "ID")
  id_col  <- df[, 1, drop = FALSE]
  feat_df <- df[, seq(2, min(ncol(df), 1L + max_feat_cols)), drop = FALSE]
  out     <- cbind(id_col, feat_df)
  con     <- gzfile(dst, "wt")
  write.csv(out, con, row.names = FALSE)
  close(con)
  message(sprintf("Written %d rows x %d cols -> %s",
                  nrow(out), ncol(out), basename(dst)))
}

.subset_and_write <- function(src, dst) {
  df <- read.csv(src, check.names = FALSE)
  write.csv(df, dst, row.names = FALSE)
  message(sprintf("Written %d rows x %d cols -> %s",
                  nrow(df), ncol(df), basename(dst)))
}

# Training omics (100 feature cols each)
.subset_and_write_gz(
  file.path(train_dir, "CyTOF.csv"),
  file.path(out_dir,   "ool_cytof_train.csv.gz")
)
.subset_and_write_gz(
  file.path(train_dir, "Proteomics.csv"),
  file.path(out_dir,   "ool_proteomics_train.csv.gz")
)

# Validation omics (100 feature cols each)
.subset_and_write_gz(
  file.path(valid_dir, "CyTOF_validation.csv"),
  file.path(out_dir,   "ool_cytof_valid.csv.gz")
)
.subset_and_write_gz(
  file.path(valid_dir, "Proteomics_validation.csv"),
  file.path(out_dir,   "ool_proteomics_valid.csv.gz")
)

# Outcomes (small, keep as plain CSV)
.subset_and_write(
  file.path(train_dir, "DOS.csv"),
  file.path(out_dir,   "ool_dos_train.csv")
)
.subset_and_write(
  file.path(valid_dir, "DOS_validation.csv"),
  file.path(out_dir,   "ool_dos_valid.csv")
)

message("Done. Files written to: ", out_dir)
