test_that("AUDIT INT-001: duplicate sample ids are rejected", {
  x <- matrix(
    seq_len(6L),
    nrow = 3L,
    dimnames = list(c("s1", "s1", "s2"), c("f1", "f2"))
  )
  y <- c(s1 = 1, s2 = 2)

  expect_error(
    validate_sample_alignment(x, y),
    "unique sample ids"
  )
  expect_error(
    costablr:::.subset_outcome_by_ids(y, rownames(x)),
    "sample_ids.*unique"
  )

  x_unique <- matrix(
    seq_len(4L),
    nrow = 2L,
    dimnames = list(c("s1", "s2"), c("f1", "f2"))
  )
  expect_error(
    validate_sample_alignment(x_unique, c(s1 = 1, s1 = 2)),
    "`y` sample ids must be unique"
  )
  expect_error(
    validate_sample_alignment(
      x_unique,
      c(s1 = 1, s2 = 2),
      groups = c(s1 = "g1", s1 = "g2")
    ),
    "`groups` sample ids must be unique"
  )
})
