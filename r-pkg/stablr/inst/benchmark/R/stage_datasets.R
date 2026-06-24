#!/usr/bin/env Rscript
# stage_datasets.R — B1: Idempotent dataset staging from data.zip.
#
# Usage (from repository root):
#   Rscript r-pkg/stablr/inst/benchmark/R/stage_datasets.R \
#     [--zip "Sample Data/data.zip"] [--dest scratch/benchmark/data] [--force]
#
# Behaviour:
#   1. Extracts every non-.DS_Store file from <zip> into <dest>, preserving the
#      zip's directory structure (which already matches stabl/data.py expectations).
#   2. Writes <dest>/MANIFEST.json: per-file SHA-256 and zip mtime, for later
#      reproducibility checks.
#   3. On subsequent calls with the same zip (same mtime), the manifest is compared
#      and extraction is skipped unless --force is passed or the manifest differs.
#
# Notes on OOL Training:
#   The on-disk "Sample Data/Onset of Labor/" directory is missing
#   Training/Metabolomics.csv and Training/ID.csv.  This script always extracts
#   from the zip, so staging is the canonical source regardless.
#
# Dependencies: digest (for sha256).  Soft dependency — falls back to mtime-only
#   MANIFEST if digest is not available.

suppressPackageStartupMessages({
  has_digest <- requireNamespace("digest", quietly = TRUE)
  has_yaml   <- requireNamespace("yaml",   quietly = TRUE)
})

# ── Argument parsing ──────────────────────────────────────────────────────────
parse_args_stage <- function() {
  raw <- commandArgs(trailingOnly = TRUE)
  zip   <- "Sample Data/data.zip"
  dest  <- "scratch/benchmark/data"
  force <- FALSE
  i <- 1L
  while (i <= length(raw)) {
    if (raw[[i]] == "--zip"   && i < length(raw)) { zip   <- raw[[i + 1L]]; i <- i + 2L }
    else if (raw[[i]] == "--dest"  && i < length(raw)) { dest  <- raw[[i + 1L]]; i <- i + 2L }
    else if (raw[[i]] == "--force")                    { force <- TRUE;           i <- i + 1L }
    else i <- i + 1L
  }
  list(zip = zip, dest = dest, force = force)
}

# ── Repo root ─────────────────────────────────────────────────────────────────
find_repo_root_stage <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  sf   <- grep("^--file=", args, value = TRUE)
  start <- if (length(sf) > 0L) dirname(normalizePath(sub("^--file=", "", sf[[1L]])))
            else getwd()
  path <- start
  repeat {
    if (file.exists(file.path(path, "r-pkg", "stablr", "DESCRIPTION"))) return(path)
    parent <- dirname(path)
    if (identical(parent, path)) stop("Cannot locate repository root.", call. = FALSE)
    path <- parent
  }
}

# ── SHA-256 helper ────────────────────────────────────────────────────────────
file_sha256 <- function(path) {
  if (has_digest) digest::digest(path, algo = "sha256", file = TRUE)
  else            as.character(file.info(path)$mtime)
}

# ── MANIFEST helpers ──────────────────────────────────────────────────────────
build_manifest <- function(dest, zip_path) {
  files <- list.files(dest, recursive = TRUE, full.names = TRUE)
  files <- sort(files[!grepl("MANIFEST\\.json$", files)])
  hashes <- vapply(files, file_sha256, character(1L))
  list(
    zip         = zip_path,
    zip_mtime   = as.character(file.info(zip_path)$mtime),
    n_files     = length(files),
    digest_algo = if (has_digest) "sha256" else "mtime",
    files       = setNames(as.list(hashes), sub(paste0("^", dest, "/"), "", files))
  )
}

write_manifest <- function(dest, zip_path) {
  m <- build_manifest(dest, zip_path)
  json_path <- file.path(dest, "MANIFEST.json")
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::write_json(m, json_path, pretty = TRUE, auto_unbox = TRUE)
  } else {
    # Minimal hand-rolled JSON writer (no jsonlite dependency at runtime)
    lines <- c(
      "{",
      sprintf('  "zip": "%s",',        m$zip),
      sprintf('  "zip_mtime": "%s",',  m$zip_mtime),
      sprintf('  "n_files": %d,',      m$n_files),
      sprintf('  "digest_algo": "%s",', m$digest_algo),
      '  "files": {',
      paste0(
        sprintf('    "%s": "%s"', names(m$files), unlist(m$files)),
        c(rep(",", length(m$files) - 1L), "")
      ),
      "  }",
      "}"
    )
    writeLines(lines, json_path)
  }
  invisible(json_path)
}

read_manifest <- function(dest) {
  json_path <- file.path(dest, "MANIFEST.json")
  if (!file.exists(json_path)) return(NULL)
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    jsonlite::read_json(json_path)
  } else {
    NULL  # can't compare without a JSON reader; force re-extract
  }
}

manifest_matches <- function(dest, zip_path) {
  m <- read_manifest(dest)
  if (is.null(m)) return(FALSE)
  # Quick check: zip mtime must match
  current_mtime <- as.character(file.info(zip_path)$mtime)
  identical(m[["zip_mtime"]], current_mtime)
}

# ── Main staging function ─────────────────────────────────────────────────────

#' Stage all six STABL benchmark datasets from data.zip
#'
#' Idempotent: checks the MANIFEST.json before extracting. The zip's directory
#' structure is preserved verbatim because it already matches the paths expected
#' by \code{stabl/data.py} (e.g. \code{"Onset of Labor/Training/Metabolomics.csv"}).
#'
#' @param zip  Path to \code{data.zip} (default: \code{"Sample Data/data.zip"}).
#' @param dest Destination directory (default: \code{"scratch/benchmark/data"}).
#' @param force If \code{TRUE}, re-extract even if the manifest matches.
#' @param verbose Logical; print progress messages.
#' @return Invisibly returns \code{dest} (the staged data root).
stage_all_datasets <- function(zip  = "Sample Data/data.zip",
                               dest = "scratch/benchmark/data",
                               force   = FALSE,
                               verbose = TRUE) {

  zip  <- normalizePath(zip,  winslash = "/", mustWork = TRUE)
  dest <- normalizePath(dest, winslash = "/", mustWork = FALSE)

  if (!file.exists(zip)) stop("data.zip not found: ", zip, call. = FALSE)

  # Idempotency check
  if (!force && dir.exists(dest) && manifest_matches(dest, zip)) {
    if (verbose) {
      n <- read_manifest(dest)[["n_files"]]
      message("Staging up-to-date (", n, " files). Pass force=TRUE to re-extract.")
    }
    return(invisible(dest))
  }

  if (verbose) message("Extracting ", basename(zip), " → ", dest, " ...")
  dir.create(dest, recursive = TRUE, showWarnings = FALSE)

  # List zip contents and filter
  zip_contents <- utils::unzip(zip, list = TRUE)
  to_extract <- zip_contents$Name[
    !grepl("\\.DS_Store$", zip_contents$Name, ignore.case = TRUE) &
    !grepl("/$", zip_contents$Name)   # skip directory entries
  ]

  if (length(to_extract) == 0L) stop("No extractable files found in zip.", call. = FALSE)
  if (verbose) message("  Extracting ", length(to_extract), " files ...")

  utils::unzip(zip,
               files    = to_extract,
               exdir    = dest,
               junkpaths = FALSE,
               overwrite = TRUE)

  # Write MANIFEST
  manifest_path <- write_manifest(dest, zip)
  algo_label <- if (has_digest) "sha256" else "mtime"
  if (verbose) message("  MANIFEST.json written (", algo_label, " hashes).")

  if (verbose) {
    message("Staging complete: ", dest)
    message("  Datasets available:")
    top_dirs <- list.dirs(dest, recursive = FALSE)
    for (d in sort(top_dirs)) message("    ", basename(d), "/")
  }

  invisible(dest)
}

# ── CLI entry point ───────────────────────────────────────────────────────────
if (!interactive()) {
  repo <- find_repo_root_stage()
  cfg  <- parse_args_stage()

  # Resolve paths relative to repo root if not absolute
  zip  <- if (startsWith(cfg$zip,  "/")) cfg$zip  else file.path(repo, cfg$zip)
  dest <- if (startsWith(cfg$dest, "/")) cfg$dest else file.path(repo, cfg$dest)

  stage_all_datasets(zip = zip, dest = dest, force = cfg$force, verbose = TRUE)
}
