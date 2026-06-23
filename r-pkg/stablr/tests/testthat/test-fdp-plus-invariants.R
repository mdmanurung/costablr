# Audit V-6: pin the FDP+ algorithmic invariants symbolically (STABL.md §Step 4).
#
#   FDP+(t) = ((1/pi) * |{j: q_j^art > t}| + 1) / max(1, |{j: q_j > t}|)
#
# Strict `>` (not `>=`), additive 1 in numerator, max(1, .) denominator guard,
# and (1/pi) artificial scaling are all baked in here on hand-computed cases
# so future refactors cannot silently drift on any of them.

test_that("compute_fdp_plus uses strict `>` (ties at threshold do not count)", {
  art  <- matrix(0.5, nrow = 10L, ncol = 5L)
  real <- matrix(0.5, nrow = 10L, ncol = 5L)

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          fdr_threshold_range     = c(0.5))

  # Nothing exceeds 0.5 strictly: numerator = 1 + (1/1)*0 = 1; denom = max(1,0) = 1.
  expect_equal(unname(res$FDRs), 1)
  expect_equal(res$min_fdr, 1)
})

test_that("compute_fdp_plus applies the (1/pi) artificial-feature scaling", {
  # All 10 artificial features tied at 0.6 (>0.5 → counted); same for real.
  art  <- matrix(0.6, nrow = 10L, ncol = 5L)
  real <- matrix(0.6, nrow = 10L, ncol = 5L)

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 0.5,
                          fdr_threshold_range     = c(0.5))

  # (1/0.5)*10 + 1 = 21; denom = max(1, 10) = 10 → 2.1
  expect_equal(unname(res$FDRs), 2.1)
})

test_that("compute_fdp_plus denominator floor is 1 when no real features exceed t", {
  art  <- matrix(0.9, nrow = 4L, ncol = 3L)  # 4 art features >> 0.5
  real <- matrix(0.1, nrow = 4L, ncol = 3L)  # 0 real features > 0.5

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          fdr_threshold_range     = c(0.5))

  # num = (1/1)*4 + 1 = 5; denom = max(1, 0) = 1 → 5
  expect_equal(unname(res$FDRs), 5)
})

test_that("compute_fdp_plus fdrs_table is bit-identical after vectorization (characterization)", {
  # Pins the exact per-lambda FDP+ table for a known random input.
  # Captures current behaviour so any future refactor of the lambda loop must
  # produce the same floating-point values.
  set.seed(11L)
  p <- 4L; L <- 3L
  sc  <- matrix(runif(p * L), p, L)
  sca <- matrix(runif(p * L), p, L)
  thr <- seq(0.1, 0.9, length.out = 5L)

  res <- compute_fdp_plus(sc, sca, 0.5, thr)

  expected_table <- matrix(
    c(4.5, 9.0, 9.0, 7.0, 3.0,
      4.5, 7.0, 1.0, 1.0, 1.0,
      2.25, 3.5, 3.0, 1.0, 1.0),
    nrow = 3L, ncol = 5L, byrow = TRUE
  )
  expect_equal(res$fdrs_table, expected_table, tolerance = 0)
  expect_equal(res$FDRs, c(2.25, 2.25, 3.0, 3.5, 3.0), tolerance = 0)
  expect_equal(res$min_fdr, 2.25, tolerance = 0)
  expect_equal(res$fdr_min_threshold, 1.0, tolerance = 0)
})

test_that("compute_fdp_plus caps fdr_min_threshold at 1 when min FDP+ > 1", {
  # Construct a case where min FDP+ exceeds 1 → final cutoff must be 1.
  art  <- matrix(0.99, nrow = 20L, ncol = 2L)
  real <- matrix(0.05, nrow = 5L,  ncol = 2L)

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          # Exclude 1.0 so strict ">" cannot force a zero-count
                          # numerator/denominator corner where FDP+ becomes 1.
                          fdr_threshold_range     = seq(0, 0.9, by = 0.1))

  expect_gt(res$min_fdr, 1)
  expect_equal(res$fdr_min_threshold, 1)
})

# D1 characterization: rowMaxs / .row_maxs outputs on normal and degenerate
# inputs (pin at tolerance = 0 before refactoring to an improved helper).
test_that("rowMaxs returns correct row-wise maxima on normal inputs", {
  m <- matrix(c(1, 3, 2, 4, 0, 5), nrow = 3L, ncol = 2L)
  # Row maxima: max(1,4)=4, max(3,0)=3, max(2,5)=5
  expect_equal(stablr:::rowMaxs(m), c(4, 3, 5), tolerance = 0)
})

test_that("rowMaxs handles 0-row matrix gracefully", {
  m <- matrix(numeric(0), nrow = 0L, ncol = 3L)
  result <- stablr:::rowMaxs(m)
  expect_length(result, 0L)
  expect_true(is.numeric(result))
})

test_that("rowMaxs handles 1-column matrix (no silent apply dimension-drop)", {
  m <- matrix(c(7, 2, 9), nrow = 3L, ncol = 1L)
  # All three values are the row maxima; must return numeric vector, not NULL.
  expect_equal(stablr:::rowMaxs(m), c(7, 2, 9), tolerance = 0)
  expect_true(is.numeric(stablr:::rowMaxs(m)))
})
