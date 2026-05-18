# Shared future/furrr backend helpers.

.normalize_worker_count <- function(workers, arg = "workers") {
  if (!is.numeric(workers) || length(workers) != 1L || is.na(workers)) {
    stop("`", arg, "` must be a positive integer.", call. = FALSE)
  }
  workers <- as.integer(workers)
  if (workers < 1L) {
    stop("`", arg, "` must be a positive integer.", call. = FALSE)
  }
  workers
}

.future_backend_available <- function() {
  requireNamespace("future", quietly = TRUE) &&
    requireNamespace("furrr", quietly = TRUE)
}

.warn_future_backend_unavailable <- function(arg = "workers") {
  warning(
    "`", arg, " > 1` requires optional packages `future` and `furrr`; ",
    "falling back to sequential execution.",
    call. = FALSE
  )
}

.with_scoped_future_plan <- function(workers, expr) {
  workers <- .normalize_worker_count(workers)
  if (workers <= 1L) {
    return(force(expr))
  }

  old_plan <- future::plan()
  on.exit(suppressWarnings(future::plan(old_plan)), add = TRUE)
  suppressWarnings(future::plan(future::multisession, workers = workers))
  force(expr)
}

.future_map_or_lapply <- function(x, fn, workers, seed = TRUE,
                                  arg = "workers") {
  workers <- .normalize_worker_count(workers, arg = arg)
  if (workers <= 1L) {
    return(lapply(x, fn))
  }

  if (!.future_backend_available()) {
    .warn_future_backend_unavailable(arg = arg)
    return(lapply(x, fn))
  }

  .with_scoped_future_plan(
    workers,
    furrr::future_map(
      x,
      fn,
      .options = furrr::furrr_options(seed = seed)
    )
  )
}
