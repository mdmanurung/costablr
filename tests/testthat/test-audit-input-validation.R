test_that("AUDIT INT-002: duplicate sample ids currently pass alignment", {
  x <- matrix(
    seq_len(6L),
    nrow = 3L,
    dimnames = list(c("s1", "s1", "s2"), c("f1", "f2"))
  )
  y <- c(s1 = 1, s2 = 2)

  expect_invisible(validate_sample_alignment(x, y))
  expect_equal(
    costablr:::.subset_outcome_by_ids(y, rownames(x)),
    c(s1 = 1, s1 = 1, s2 = 2)
  )
})
