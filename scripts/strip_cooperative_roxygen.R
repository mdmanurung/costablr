# Strip roxygen from vendored cooperative R sources (internal only).
# Keeps a minimal @exportS3Method block for plot.multiview.

root <- Sys.getenv("STABLR_PKG", unset = ".")
r_dir <- file.path(root, "R")
files <- list.files(r_dir, pattern = "^cooperative-.*\\.R$", full.names = TRUE)

strip_block <- function(lines, start_idx) {
  end_idx <- start_idx
  while (end_idx <= length(lines) && grepl("^#'", lines[[end_idx]])) {
    end_idx <- end_idx + 1L
  }
  block <- lines[start_idx:(end_idx - 1L)]
  list(end = end_idx - 1L, block = block)
}

for (path in files) {
  lines <- readLines(path, warn = FALSE)
  out <- character()
  i <- 1L
  while (i <= length(lines)) {
    if (!grepl("^#'", lines[[i]])) {
      out <- c(out, lines[[i]])
      i <- i + 1L
      next
    }
    sb <- strip_block(lines, i)
    block <- sb$block
    i <- sb$end + 1L

    is_plot <- any(grepl('Plot coefficients from a "multiview" object', block, fixed = TRUE))
    if (is_plot && basename(path) == "cooperative-multiview.R") {
      out <- c(out, "#' @exportS3Method plot multiview", "#' @noRd")
      next
    }

    out <- c(out, sub("^#'", "#", block))
  }
  writeLines(out, path)
}

message("Stripped roxygen from ", length(files), " cooperative files.")
