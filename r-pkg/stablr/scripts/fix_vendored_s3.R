#!/usr/bin/env Rscript
# Fix S3 method names broken by port_multiview.R

vendored <- file.path(
  Sys.getenv("STABLR_ROOT", "/exports/para-lipg-hpc/mdmanurung/stablr"),
  "r-pkg", "stablr", "R", "cooperative", "vendored"
)

fixes <- c(
  ".mv_cv_.mv_multiview" = ".mv_cv_multiview",
  "coef..mv_cv_.mv_multiview" = "coef.cv.multiview",
  "coef_ordered..mv_cv_.mv_multiview" = "coef_ordered.cv.multiview",
  "family..mv_cv_.mv_multiview" = "family.cv.multiview",
  "plot..mv_multiview" = "plot.multiview",
  "coef..mv_multiview" = "coef.multiview",
  "coef_ordered..mv_multiview" = "coef_ordered.multiview",
  "predict..mv_multiview" = "predict.multiview",
  "family..mv_multiview" = "family.multiview",
  "jerr..mv_multiview" = "jerr.multiview"
)

files <- list.files(vendored, pattern = "\\.R$", full.names = TRUE)
for (f in files) {
  txt <- paste(readLines(f, warn = FALSE), collapse = "\n")
  for (pat in names(fixes)) {
    txt <- gsub(pat, fixes[[pat]], txt, fixed = TRUE)
  }
  writeLines(strsplit(txt, "\n")[[1]], f)
}
message("Fixed S3 names in ", length(files), " files")
