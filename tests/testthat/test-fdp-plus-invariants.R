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

.slow_compute_fdp_plus_reference <- function(real, artificial, proportion,
                                             thresholds) {
  inv_prop <- 1 / proportion
  max_real <- apply(real, 1L, max)
  max_art <- apply(artificial, 1L, max)
  n_real <- colSums(outer(max_real, thresholds, ">"))
  n_art <- colSums(outer(max_art, thresholds, ">"))
  fdr <- (inv_prop * n_art + 1) / pmax(1, n_real)
  nr_table <- vapply(thresholds, function(t) colSums(real > t), numeric(ncol(real)))
  na_table <- vapply(thresholds, function(t) colSums(artificial > t), numeric(ncol(real)))
  table <- (inv_prop * na_table + 1) / pmax(1, nr_table)
  list(FDRs = fdr, fdrs_table = table)
}

test_that("compute_fdp_plus matches strict-comparison reference on ties and unordered thresholds", {
  set.seed(12L)
  real <- matrix(sample(seq(0, 1, by = 0.1), 101L * 7L, replace = TRUE), 101L, 7L)
  artificial <- matrix(sample(seq(0, 1, by = 0.1), 53L * 7L, replace = TRUE), 53L, 7L)
  thresholds <- c(0.5, 0.2, 0.5, 1, 0, 0.9)

  observed <- compute_fdp_plus(real, artificial, 0.5, thresholds)
  reference <- .slow_compute_fdp_plus_reference(real, artificial, 0.5, thresholds)

  expect_equal(observed$FDRs, reference$FDRs, tolerance = 0)
  expect_equal(observed$fdrs_table, reference$fdrs_table, tolerance = 0)
})

test_that("compute_fdp_plus preserves lambda-by-threshold shape for one threshold", {
  real <- matrix(c(0.1, 0.8, 0.4, 0.9, 0.2, 0.6), nrow = 2L)
  artificial <- matrix(c(0.2, 0.7, 0.5), nrow = 1L)
  observed <- compute_fdp_plus(real, artificial, 0.5, 0.5)
  reference <- .slow_compute_fdp_plus_reference(real, artificial, 0.5, 0.5)

  expect_equal(dim(observed$fdrs_table), c(ncol(real), 1L))
  expect_equal(observed$fdrs_table, reference$fdrs_table, tolerance = 0)
})

test_that("compute_fdp_plus preserves names on threshold-level FDP output", {
  real <- matrix(c(0.1, 0.8, 0.4, 0.9), nrow = 2L)
  artificial <- matrix(c(0.2, 0.7), nrow = 1L)
  thresholds <- c(low = 0.2, high = 0.5)

  observed <- compute_fdp_plus(real, artificial, 0.5, thresholds)
  expect_named(observed$FDRs, names(thresholds))
})

test_that("compute_fdp_plus rejects malformed public inputs", {
  valid <- matrix(c(0.1, 0.7, 0.2, 0.8), nrow = 2L)
  expect_error(compute_fdp_plus(as.data.frame(valid), valid, 1), "numeric matrix")
  expect_error(compute_fdp_plus(valid, valid[, 1L, drop = FALSE], 1), "same number of columns")
  bad <- valid
  bad[[1L]] <- NA_real_
  expect_error(compute_fdp_plus(bad, valid, 1), "finite")
  expect_error(compute_fdp_plus(valid, valid, 0), "artificial_proportion")
  expect_error(compute_fdp_plus(valid, valid, 1, numeric()), "fdr_threshold_range")
  expect_error(compute_fdp_plus(valid, valid, 1, c(0.2, Inf)), "fdr_threshold_range")
  expect_error(compute_fdp_plus(valid, valid, 1, matrix(0.2)), "fdr_threshold_range")
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

test_that("stabl_fit injects at least one artificial feature for tiny positive proportions", {
  set.seed(2L)
  x <- matrix(rnorm(12), nrow = 12L,
              dimnames = list(paste0("s", 1:12), "only_feature"))
  y <- setNames(rnorm(12L), rownames(x))

  fit <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.1)),
    n_bootstraps = 2L,
    artificial_type = "random_permutation",
    artificial_proportion = 0.001,
    hard_threshold = NULL,
    random_state = 1L
  )

  expect_equal(nrow(fit$stabl_scores_artificial_), 1L)
  expect_equal(fit$effective_artificial_proportion, 1)
  expect_equal(fit$artificial_proportion, 0.001)
})

test_that("stabl_fit caps artificial feature injection at ncol(x)", {
  set.seed(3L)
  x <- matrix(rnorm(30), nrow = 10L,
              dimnames = list(paste0("s", 1:10), paste0("f", 1:3)))
  y <- setNames(rnorm(10L), rownames(x))

  fit <- stabl_fit(
    x = x,
    y = y,
    lambda_grid = data.frame(lambda = c(0.1)),
    n_bootstraps = 2L,
    artificial_type = "random_permutation",
    artificial_proportion = 1,
    random_state = 1L
  )

  expect_equal(nrow(fit$stabl_scores_artificial_), ncol(x))
  expect_equal(fit$effective_artificial_proportion, 1)
})

test_that("stabl_fit supports all documented artificial feature strategies", {
  x <- matrix(rnorm(60), nrow = 20L,
              dimnames = list(paste0("s", 1:20), paste0("f", 1:3)))
  y <- setNames(rnorm(20L), rownames(x))
  strategies <- c("random_permutation", "knockoff", "knockoff_equi", "knockoff_mvr")

  for (strategy in strategies) {
    if (startsWith(strategy, "knockoff")) {
      skip_if_not_installed("knockoff")
    }
    fit <- stabl_fit(
      x = x,
      y = y,
      lambda_grid = data.frame(lambda = c(0.1)),
      n_bootstraps = 2L,
      artificial_type = strategy,
      artificial_proportion = 0.2,
      random_state = 1L
    )
    expect_equal(nrow(fit$stabl_scores_artificial_), 1L)
    expect_equal(fit$effective_artificial_proportion, 1 / ncol(x))
  }
})
