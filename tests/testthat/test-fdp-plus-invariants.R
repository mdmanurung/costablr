# Audit V-6: pin the FDP+ algorithmic invariants symbolically (STABL.md §Step 4).
#
#   FDP+(t) = ((1/pi) * |{j: q_j^art >= t}| + 1) / max(1, |{j: q_j >= t}|)
#
# Paper-method `>=`, additive 1 in numerator, max(1, .) denominator guard, and
# (1/pi) artificial scaling are all baked in here on hand-computed cases so
# future refactors cannot silently drift on any of them.

test_that("compute_fdp_plus uses paper-method `>=` (ties at threshold count)", {
  art  <- matrix(0.5, nrow = 10L, ncol = 5L)
  real <- matrix(0.5, nrow = 10L, ncol = 5L)

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          fdr_threshold_range     = c(0.5))

  # All features equal 0.5: numerator = 1 + (1/1)*10 = 11; denom = 10.
  expect_equal(unname(res$FDRs), 1.1)
  expect_equal(res$min_fdr, 1.1)
})

test_that("compute_fdp_plus applies the (1/pi) artificial-feature scaling", {
  # All 10 artificial features exceed 0.5; same for real.
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
  art  <- matrix(0.9, nrow = 4L, ncol = 3L)  # 4 art features exceed 0.5
  real <- matrix(0.1, nrow = 4L, ncol = 3L)  # 0 real features exceed 0.5

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          fdr_threshold_range     = c(0.5))

  # num = (1/1)*4 + 1 = 5; denom = max(1, 0) = 1 → 5
  expect_equal(unname(res$FDRs), 5)
})

test_that("compute_fdp_plus caps fdr_min_threshold at 1 when min FDP+ > 1", {
  # Construct a case where min FDP+ exceeds 1 → final cutoff must be 1.
  art  <- matrix(0.99, nrow = 20L, ncol = 2L)
  real <- matrix(0.05, nrow = 5L,  ncol = 2L)

  res <- compute_fdp_plus(stabl_scores            = real,
                          stabl_scores_artificial = art,
                          artificial_proportion   = 1.0,
                          # Exclude 1.0 so the high-artificial-feature case
                          # remains above 1 across the swept grid.
                          fdr_threshold_range     = seq(0, 0.9, by = 0.1))

  expect_gt(res$min_fdr, 1)
  expect_equal(res$fdr_min_threshold, 1)
})
