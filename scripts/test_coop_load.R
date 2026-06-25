pkg <- Sys.getenv("STABLR_PKG", unset = "/exports/para-lipg-hpc/mdmanurung/stablr")
d <- read.dcf(file.path(pkg, "DESCRIPTION"))
files <- gsub("'", "", trimws(unlist(strsplit(as.character(d[1, "Collate"]), "\n"))))
for (f in files) {
  path <- file.path(pkg, "R", f)
  message("sourcing ", f)
  tryCatch(
    source(path, local = FALSE),
    error = function(e) message("ERROR in ", f, ": ", conditionMessage(e))
  )
}
message(".mv_multiview exists: ", exists(".mv_multiview"))
message(".cooperative_backend_cv exists: ", exists(".cooperative_backend_cv"))
