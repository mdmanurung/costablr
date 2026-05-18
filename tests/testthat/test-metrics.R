# tests for metrics.R — selection-stability similarity measures
# Note: .r_auc() and .r_squared() are internal helpers originally defined in
# multiomic_workflows.R; they live here to keep metric logic in one place.

# ── jaccard_similarity ────────────────────────────────────────────────────────

test_that("jaccard_similarity: identical sets return 1", {
  expect_equal(jaccard_similarity(c("A", "B", "C"), c("A", "B", "C")), 1)
})

test_that("jaccard_similarity: disjoint sets return 0", {
  expect_equal(jaccard_similarity(c("A", "B"), c("C", "D")), 0)
})

test_that("jaccard_similarity: both empty sets return 0", {
  expect_equal(jaccard_similarity(character(0), character(0)), 0)
})

test_that("jaccard_similarity: one empty set returns 0", {
  expect_equal(jaccard_similarity(character(0), c("A", "B")), 0)
  expect_equal(jaccard_similarity(c("A", "B"), character(0)), 0)
})

test_that("jaccard_similarity: partial overlap is correct", {
  # intersection = {B}, union = {A, B, C} => 1/3
  expect_equal(jaccard_similarity(c("A", "B"), c("B", "C")), 1 / 3)
})

test_that("jaccard_similarity: duplicates in input are deduplicated", {
  expect_equal(
    jaccard_similarity(c("A", "A", "B"), c("B", "B", "C")),
    jaccard_similarity(c("A", "B"), c("B", "C"))
  )
})

test_that("jaccard_similarity: integer indices work", {
  expect_equal(jaccard_similarity(1:3, 2:4), 2 / 4)
})

# ── jaccard_matrix ────────────────────────────────────────────────────────────

test_that("jaccard_matrix with remove_diag=FALSE is symmetric with 1s on diagonal", {
  sets <- list(c("A", "B"), c("B", "C"), c("C", "D"))
  mat <- jaccard_matrix(sets, remove_diag = FALSE)
  expect_equal(nrow(mat), 3L)
  expect_equal(ncol(mat), 3L)
  expect_equal(diag(mat), c(1, 1, 1))
  expect_equal(mat[1, 2], mat[2, 1])
  expect_equal(mat[1, 3], mat[3, 1])
})

test_that("jaccard_matrix with remove_diag=TRUE drops diagonal column", {
  sets <- list(c("A", "B"), c("B", "C"), c("A", "C"))
  mat <- jaccard_matrix(sets, remove_diag = TRUE)
  expect_equal(nrow(mat), 3L)
  expect_equal(ncol(mat), 2L)
})

test_that("jaccard_matrix: single-pair case", {
  mat_full <- jaccard_matrix(list(c("A"), c("A", "B")), remove_diag = FALSE)
  expect_equal(mat_full[1, 2], 1 / 2)
  expect_equal(mat_full[2, 1], 1 / 2)
})

# ── adjusted_similarity ───────────────────────────────────────────────────────

test_that("adjusted_similarity: identical non-trivial sets return value in (0, 1)", {
  # The chance-corrected formula does not reach 1 for non-trivial identical sets.
  # k1=k2=2, d=10 => num = 2 - 4/10 = 1.6, denom = 2 => result = 0.8
  val <- adjusted_similarity(c("A", "B"), c("A", "B"), nb_total_elements = 10)
  expect_equal(val, 0.8)
  expect_gt(val, 0)
})

test_that("adjusted_similarity: empty set returns 0", {
  expect_equal(adjusted_similarity(character(0), c("A", "B"), nb_total_elements = 10), 0)
  expect_equal(adjusted_similarity(c("A", "B"), character(0), nb_total_elements = 10), 0)
})

test_that("adjusted_similarity: full-universe set returns 0", {
  all_feats <- letters[1:5]
  expect_equal(adjusted_similarity(all_feats, c("a", "b"), nb_total_elements = 5), 0)
})

test_that("adjusted_similarity: union exceeding d raises error", {
  expect_error(
    adjusted_similarity(c("A", "B", "C"), c("D", "E", "F"), nb_total_elements = 5),
    "Union cardinal"
  )
})

test_that("adjusted_similarity: known value is correct", {
  # s1={A,B}, s2={B,C}, d=10 => r=1, k1=k2=2, E[r]=4/10=0.4, denom=2-0=2
  # => (1 - 0.4) / 2 = 0.3
  expect_equal(
    adjusted_similarity(c("A", "B"), c("B", "C"), nb_total_elements = 10),
    0.3
  )
})

# ── adjusted_similarity_values ────────────────────────────────────────────────

test_that("adjusted_similarity_values: length is n*(n-1)/2", {
  sets <- list(c("A", "B"), c("B", "C"), c("C", "D"))
  vals <- adjusted_similarity_values(sets, nb_total_elements = 10)
  expect_length(vals, 3L)
})

test_that("adjusted_similarity_values: single pair returns length-1 vector", {
  vals <- adjusted_similarity_values(list(c("A"), c("B")), nb_total_elements = 5)
  expect_length(vals, 1L)
})

# ── adjusted_similarity_measure ───────────────────────────────────────────────

test_that("adjusted_similarity_measure: returns list with statistic and err", {
  sets <- list(c("A", "B"), c("B", "C"), c("A", "C"))
  res <- adjusted_similarity_measure(sets, nb_total_elements = 10)
  expect_named(res, c("statistic", "err"))
  expect_true(is.numeric(res$statistic))
  expect_true(is.numeric(res$err))
})

test_that("adjusted_similarity_measure: stat='mean' returns rmsd", {
  sets <- list(c("A", "B"), c("B", "C"), c("A", "C"))
  res <- adjusted_similarity_measure(sets, nb_total_elements = 10, stat = "mean")
  expect_length(res$err, 1L)
})

test_that("adjusted_similarity_measure: invalid stat raises error", {
  sets <- list(c("A"), c("B"))
  expect_error(
    adjusted_similarity_measure(sets, nb_total_elements = 5, stat = "max"),
    "must be"
  )
})

# ── pearson_similarity ────────────────────────────────────────────────────────

test_that("pearson_similarity: both empty returns 1", {
  expect_equal(pearson_similarity(character(0), character(0), d = 10), 1)
})

test_that("pearson_similarity: both full-universe returns 1", {
  all_feats <- letters[1:4]
  expect_equal(pearson_similarity(all_feats, all_feats, d = 4), 1)
})

test_that("pearson_similarity: one empty returns 0", {
  expect_equal(pearson_similarity(character(0), c("A", "B"), d = 10), 0)
})

test_that("pearson_similarity: one full-universe returns 0", {
  expect_equal(pearson_similarity(letters[1:5], c("a", "b"), d = 5), 0)
})

test_that("pearson_similarity: identical non-trivial sets are positive", {
  val <- pearson_similarity(c("A", "B"), c("A", "B"), d = 10)
  expect_gt(val, 0)
})

test_that("pearson_similarity: disjoint sets are non-positive", {
  val <- pearson_similarity(c("A", "B"), c("C", "D"), d = 10)
  expect_lte(val, 0)
})

# ── pearson_similarity_values ─────────────────────────────────────────────────

test_that("pearson_similarity_values: length is n*(n-1)/2", {
  sets <- list(c("A", "B"), c("B", "C"), c("C", "D"))
  vals <- pearson_similarity_values(sets, d = 10)
  expect_length(vals, 3L)
})

# ── pearson_similarity_measure ────────────────────────────────────────────────

test_that("pearson_similarity_measure: returns named list", {
  sets <- list(c("A", "B"), c("B", "C"), c("A", "C"))
  res <- pearson_similarity_measure(sets, d = 10)
  expect_named(res, c("statistic", "err"))
})

# ── fdr_similarity ────────────────────────────────────────────────────────────

test_that("fdr_similarity: perfect prediction returns 0", {
  expect_equal(fdr_similarity(c("A", "B"), c("A", "B")), 0)
})

test_that("fdr_similarity: empty prediction returns 0", {
  expect_equal(fdr_similarity(character(0), c("A", "B")), 0)
})

test_that("fdr_similarity: all false discoveries returns 1", {
  expect_equal(fdr_similarity(c("C", "D"), c("A", "B")), 1)
})

test_that("fdr_similarity: partial FDR is correct", {
  # predicted={A,B,C}, truth={A,B} => tp=2, fp=1 => FDR=1/3
  expect_equal(fdr_similarity(c("A", "B", "C"), c("A", "B")), 1 / 3)
})

# ── tpr_similarity ────────────────────────────────────────────────────────────

test_that("tpr_similarity: perfect recall returns 1", {
  expect_equal(tpr_similarity(c("A", "B", "C"), c("A", "B")), 1)
})

test_that("tpr_similarity: empty truth returns 0", {
  expect_equal(tpr_similarity(c("A", "B"), character(0)), 0)
})

test_that("tpr_similarity: empty prediction returns 0", {
  expect_equal(tpr_similarity(character(0), c("A", "B")), 0)
})

test_that("tpr_similarity: partial TPR is correct", {
  # predicted={A}, truth={A,B} => tp=1, fn=1 => TPR=0.5
  expect_equal(tpr_similarity(c("A"), c("A", "B")), 0.5)
})

# ── fscore_similarity ─────────────────────────────────────────────────────────

test_that("fscore_similarity: perfect match returns 1", {
  expect_equal(fscore_similarity(c("A", "B"), c("A", "B")), 1)
})

test_that("fscore_similarity: both empty returns 0", {
  expect_equal(fscore_similarity(character(0), character(0)), 0)
})

test_that("fscore_similarity: no overlap returns 0", {
  expect_equal(fscore_similarity(c("A"), c("B")), 0)
})

test_that("fscore_similarity: known F1 value is correct", {
  # predicted={A,B,C}, truth={A,B} => tp=2, fp=1, fn=0
  # F1 = 2*2 / (2*2 + 0 + 1) = 4/5
  expect_equal(fscore_similarity(c("A", "B", "C"), c("A", "B")), 4 / 5)
})

test_that("fscore_similarity: beta=2 weights recall more heavily", {
  # tp=1, fp=1, fn=1 => F2 = (1+4)*1 / ((1+4)*1 + 4*1 + 1) = 5/10 = 0.5
  expect_equal(fscore_similarity(c("A", "B"), c("A", "C"), beta = 2), 5 / 10)
})

# ── .r_auc (internal, moved from multiomic_workflows.R) ──────────────────────

test_that(".r_auc: perfect separation returns 1", {
  y      <- c(0L, 0L, 0L, 1L, 1L, 1L)
  scores <- c(0.1, 0.2, 0.3, 0.7, 0.8, 0.9)
  expect_equal(costablr:::.r_auc(y, scores), 1)
})

test_that(".r_auc: reversed separation returns 0", {
  y      <- c(0L, 0L, 0L, 1L, 1L, 1L)
  scores <- c(0.7, 0.8, 0.9, 0.1, 0.2, 0.3)
  expect_equal(costablr:::.r_auc(y, scores), 0)
})

test_that(".r_auc: all-same class returns 0.5", {
  expect_equal(costablr:::.r_auc(c(0L, 0L, 0L), c(0.1, 0.2, 0.3)), 0.5)
})

# ── .r_squared (internal, moved from multiomic_workflows.R) ──────────────────

test_that(".r_squared: perfect fit returns 1", {
  y <- c(1, 2, 3, 4)
  expect_equal(costablr:::.r_squared(y, y), 1)
})

test_that(".r_squared: constant y returns 0 (no variance to explain)", {
  expect_equal(costablr:::.r_squared(c(3, 3, 3), c(1, 2, 3)), 0)
})

test_that(".r_squared: intercept-only prediction is negative or zero for non-mean fit", {
  y     <- c(1, 2, 3, 4)
  y_hat <- rep(0, 4)
  expect_lte(costablr:::.r_squared(y, y_hat), 0)
})
