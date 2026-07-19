release_source_root <- function() {
  candidates <- unique(c(
    normalizePath(testthat::test_path("..", ".."), mustWork = FALSE),
    normalizePath(getwd(), mustWork = FALSE),
    normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
  ))

  for (candidate in candidates) {
    if (file.exists(file.path(candidate, "DESCRIPTION")) &&
        dir.exists(file.path(candidate, "R"))) {
      return(candidate)
    }
  }

  testthat::skip("package source root is not available")
}

release_source_lines <- function(path) {
  file <- file.path(release_source_root(), path)
  if (!file.exists(file)) {
    testthat::skip(sprintf("source file '%s' is not available", path))
  }
  readLines(file, warn = FALSE)
}

test_that(".Rbuildignore explicitly excludes local release-check byproducts", {
  lines <- release_source_lines(".Rbuildignore")

  expect_true(any(grepl("Rcheck", lines, fixed = TRUE)))
  expect_true(any(grepl("tar[.]gz", lines, fixed = TRUE)) ||
              any(grepl("tar[.]xz", lines, fixed = TRUE)))
  expect_true(any(grepl("src/.*[.](o|so|dll)$", lines, fixed = TRUE)))
  expect_true(any(grepl("test-release-hygiene[.]R", lines, fixed = TRUE)))
  expect_true(any(grepl("test-vignette-readiness[.]R", lines, fixed = TRUE)))
})

test_that("cran-comments describe the strict current release check", {
  text <- paste(release_source_lines("cran-comments.md"), collapse = "\n")

  expect_match(text, "R CMD check --as-cran", fixed = TRUE)
  expect_match(text, "0 errors | 0 warnings | 1 note", fixed = TRUE)
  expect_match(text, "New submission", fixed = TRUE)
  expect_false(grepl("0 errors \\| 0 warnings \\| 0 notes", text))
  expect_false(grepl("--no-manual --ignore-vignettes --no-build-vignettes", text))
})

test_that("cran-comments CRAN-skip notes match source skip_on_cran guards", {
  root <- release_source_root()
  test_files <- list.files(
    file.path(root, "tests", "testthat"),
    pattern = "\\.R$",
    full.names = TRUE
  )
  has_skip <- vapply(
    test_files,
    function(file) any(grepl("skip_on_cran\\(", readLines(file, warn = FALSE))),
    logical(1)
  )
  skip_files <- basename(test_files[has_skip])
  text <- paste(release_source_lines("cran-comments.md"), collapse = "\n")

  expect_match(text, sprintf("Tests skipped on CRAN \\(%d\\)", length(skip_files)))
  for (file in skip_files) {
    expect_match(text, file, fixed = TRUE)
  }
})

test_that("release notes do not retain stale no-vignette check metadata", {
  news <- paste(release_source_lines("NEWS.md"), collapse = "\n")

  expect_false(grepl("no-vignette", news, ignore.case = TRUE))
  expect_false(grepl("no-manual/no-vignette", news, ignore.case = TRUE))
  expect_false(grepl("PASS 1611", news, fixed = TRUE))
})

test_that("vendored cooperative S3 note matches the hand-maintained namespace", {
  cran <- paste(release_source_lines("cran-comments.md"), collapse = "\n")
  namespace <- paste(release_source_lines("NAMESPACE"), collapse = "\n")

  expect_match(namespace, "S3method(plot,multiview)", fixed = TRUE)
  expect_match(cran, "plot.multiview", fixed = TRUE)
  expect_false(grepl("Package-level startup messages", cran, fixed = TRUE))
  expect_false(grepl("coef_ordered.multiview", cran, fixed = TRUE))
})
