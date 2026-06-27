.can_open_test_server_socket <- function() {
  socket <- tryCatch(
    serverSocket(port = 0L),
    error = function(e) NULL
  )
  if (is.null(socket)) {
    return(FALSE)
  }
  close(socket)

  if (!requireNamespace("future", quietly = TRUE)) {
    return(TRUE)
  }

  old_plan <- future::plan()
  on.exit(future::plan(old_plan), add = TRUE)
  tryCatch({
    future::plan(future::multisession, workers = 2L)
    suppressWarnings(future::value(future::future(TRUE)))
    TRUE
  }, error = function(e) FALSE)
}
