# Shared helper for Python parity fixtures.
#
# Returns a richer parity payload than the legacy loader: in addition to
# `python_mean_score` (kept for backward compatibility), it parses
# `python_max_score` (the spec-defined importance per STABL.md §Step 3)
# and the FDP+-thresholded selected feature set.

load_python_parity_fixture <- function(case_name) {
  case_dir <- testthat::test_path("fixtures", "python_parity", case_name)

  x <- as.matrix(read.csv(file.path(case_dir, "x.csv"),
                          row.names = 1L, check.names = FALSE))
  y_tbl <- read.csv(file.path(case_dir, "y.csv"),
                    row.names = 1L, check.names = FALSE)

  score_tbl    <- read.csv(file.path(case_dir, "python_feature_scores.csv"),
                           check.names = FALSE)
  ranked_tbl   <- read.csv(file.path(case_dir, "python_ranked_features.csv"),
                           check.names = FALSE)
  selected_tbl <- read.csv(file.path(case_dir, "python_selected_features.csv"),
                           check.names = FALSE)

  py_max <- if ("python_max_score" %in% names(score_tbl)) {
    stats::setNames(score_tbl$python_max_score, score_tbl$feature)
  } else NULL

  list(
    x                    = x,
    y                    = y_tbl$y,
    py_mean_scores       = stats::setNames(score_tbl$python_mean_score, score_tbl$feature),
    py_max_scores        = py_max,
    py_ranked_features   = ranked_tbl$feature,
    py_selected_features = selected_tbl$feature
  )
}
