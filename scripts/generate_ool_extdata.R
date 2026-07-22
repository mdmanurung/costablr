#!/usr/bin/env Rscript

# Convenience wrapper around the canonical data-raw preparation script.
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1L]]), mustWork = TRUE)
pkg_root <- dirname(dirname(script_path))
source(file.path(pkg_root, "data-raw", "prepare_ool_data.R"))

experiments_root <- Sys.getenv(
  "STABLR_EXPERIMENTS_ROOT", file.path(dirname(pkg_root), "stablr-experiments")
)
root <- file.path(experiments_root, "sample-data", "Onset of Labor")
inputs <- c(
  cytof_train = file.path(root, "Training", "CyTOF.csv"),
  proteomics_train = file.path(root, "Training", "Proteomics.csv"),
  dos_train = file.path(root, "Training", "DOS.csv"),
  cytof_valid = file.path(root, "Validation", "CyTOF_validation.csv"),
  proteomics_valid = file.path(root, "Validation", "Proteomics_validation.csv"),
  dos_valid = file.path(root, "Validation", "DOS_validation.csv")
)
prepare_ool_data(inputs, file.path(pkg_root, "inst", "extdata"))
