test_that("validate_sample_alignment accepts aligned inputs", {
  x <- data.frame(a = c(1, 2), b = c(3, 4), row.names = c("s1", "s2"))
  y <- c(s1 = 0, s2 = 1)
  g <- c(s1 = "p1", s2 = "p2")

  expect_invisible(validate_sample_alignment(x, y, g))
})

test_that("validate_sample_alignment fails on id mismatch", {
  x <- data.frame(a = c(1, 2), row.names = c("s1", "s2"))
  y <- c(s1 = 0, s3 = 1)

  expect_error(validate_sample_alignment(x, y), "Sample mismatch")
})

test_that("validate_multiomic_inputs enforces named list and sample order", {
  x1 <- data.frame(a = c(1, 2), row.names = c("s1", "s2"))
  x2 <- data.frame(a = c(2, 3), row.names = c("s2", "s1"))
  y <- c(s1 = 0, s2 = 1)

  expect_error(
    validate_multiomic_inputs(list(omic1 = x1, omic2 = x2), y),
    "identical sample order"
  )
})
