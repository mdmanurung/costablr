#!/usr/bin/env Rscript
# Port multiview v1.0 R sources into stablr cooperative vendored module.
# Run from repo root: Rscript scripts/port_multiview.R

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[1]) else "."
repo_root <- Sys.getenv(
  "STABLR_ROOT",
  unset = normalizePath(file.path(dirname(script_path), ".."))
)
experiments_root <- Sys.getenv(
  "STABLR_EXPERIMENTS_ROOT",
  unset = file.path(dirname(repo_root), "stablr-experiments")
)
src_pkg <- file.path(experiments_root, "third_party", "multiview", "R")
dest <- file.path(repo_root, "R", "cooperative", "vendored")

header <- "# Vendored from CRAN multiview v1.0 (GPL-2). See inst/COPYING.cooperative.\n\n"

r_files <- c(
  "utils.R",
  "get_start.R",
  "multiview.control.R",
  "multiview.R",
  "multiview.path.R",
  "mvglmnet.fit.R",
  "predict.multiview.R",
  "predict.cv.multiview.R",
  "cv.multiview.R",
  "family.multiview.R",
  "build_predmat.R",
  "cv.lognet.R",
  "cv.glmnetfit.R",
  "cv.elnet.R",
  "cvtype.R",
  "cvstats.R",
  "cvcompute.R",
  "getOptcv.R",
  "auc.R",
  "auc.mat.R",
  "RcppExports.R"
)

rename_fun <- function(txt) {
  txt <- gsub("multiview\\.control", ".mv_multiview.control", txt, fixed = FALSE)
  txt <- gsub("cv\\.multiview\\s*<-\\s*function", ".mv_cv_multiview <- function", txt)
  txt <- gsub("multiview\\s*<-\\s*function", ".mv_multiview <- function", txt)
  txt <- gsub("\\bcv\\.multiview\\(", ".mv_cv_multiview(", txt)
  txt <- gsub("(?<!\\.)\\bmultiview\\(", ".mv_multiview(", txt, perl = TRUE)
  txt <- gsub("as\\.name\\(\"multiview\"\\)", "as.name(\".mv_multiview\")", txt, fixed = TRUE)
  txt <- gsub("`_multiview_", "`_stablr_", txt, fixed = TRUE)
  txt
}

dir.create(dest, recursive = TRUE, showWarnings = FALSE)

for (f in r_files) {
  in_path <- file.path(src_pkg, f)
  out_path <- file.path(dest, f)
  if (!file.exists(in_path)) {
    stop("Missing source file: ", in_path)
  }
  txt <- readLines(in_path, warn = FALSE)
  txt <- gsub("^#' @export.*$", "", txt)
  txt <- gsub("^#' @method.*$", "", txt)
  txt <- gsub("^#' @importFrom.*$", "", txt)
  txt <- gsub("^#' @inheritParams.*$", "", txt)
  txt <- gsub("^#' @examples.*$", "", txt)
  txt <- paste(txt, collapse = "\n")
  txt <- rename_fun(txt)
  writeLines(c(strsplit(header, "\n")[[1]], strsplit(txt, "\n")[[1]]), out_path)
}

message("Ported ", length(r_files), " R files to ", dest)
