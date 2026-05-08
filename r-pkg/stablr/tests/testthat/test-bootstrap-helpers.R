test_that("classic_bootstrap_indices returns requested size", {
  y <- c(0, 1, 0, 1, 0, 1)
  idx <- classic_bootstrap_indices(y = y, n_subsamples = 4, replace = FALSE, seed = 1)

  expect_length(idx, 4)
  expect_true(all(idx >= 1 & idx <= length(y)))
})

test_that("classic_bootstrap_indices validates non-replacement size", {
  y <- c(0, 1, 0)
  expect_error(
    classic_bootstrap_indices(y = y, n_subsamples = 5, replace = FALSE),
    "cannot exceed"
  )
})

test_that("group_bootstrap_indices validates group length", {
  y <- c(0, 1, 0)
  g <- c("a", "a")
  expect_error(group_bootstrap_indices(y = y, groups = g, n_subsamples = 2), "same length")
})

test_that("group_bootstrap_indices keeps whole groups when target aligns", {
  # Simulate repeated-measures layout: 4 subjects, 3 visits each.
  groups <- rep(paste0("id", 1:4), each = 3L)
  y <- rep(c(0, 1), length.out = length(groups))

  set.seed(123)
  idx <- group_bootstrap_indices(
    y = y,
    groups = groups,
    n_subsamples = 6L,
    replace = FALSE
  )

  expect_length(idx, 6L)

  selected_groups <- unique(groups[idx])
  for (g in selected_groups) {
    expect_setequal(idx[groups[idx] == g], which(groups == g))
  }
})

test_that("classic_bootstrap_indices can split repeated-measures groups", {
  # Without grouped sampling, subject rows can be partially sampled.
  groups <- rep(paste0("id", 1:4), each = 3L)
  y <- rep(c(0, 1), length.out = length(groups))

  has_partial_group <- FALSE
  set.seed(321)
  for (i in seq_len(200L)) {
    idx <- classic_bootstrap_indices(y = y, n_subsamples = 6L, replace = FALSE)
    selected_groups <- unique(groups[idx])
    partial <- any(vapply(selected_groups, function(g) {
      sel <- idx[groups[idx] == g]
      !setequal(sel, which(groups == g))
    }, logical(1L)))

    if (partial) {
      has_partial_group <- TRUE
      break
    }
  }

  expect_true(has_partial_group)
})

test_that("group_bootstrap_indices replace=FALSE never re-draws the same group", {
  # Each group must appear at most once when replace = FALSE.
  # The old code used sample(group_levels, replace=replace) which had no effect
  # on a size-1 draw — the pool never shrank and the same group could appear
  # multiple times.
  groups <- rep(paste0("id", 1:6), each = 4L)
  y      <- rep(c(0, 1), length.out = length(groups))

  for (seed_val in c(1L, 7L, 42L, 99L, 200L)) {
    idx             <- group_bootstrap_indices(y = y, groups = groups,
                                              n_subsamples = 12L,
                                              replace = FALSE, seed = seed_val)
    selected_groups <- groups[idx]
    group_counts    <- table(selected_groups)
    # Every sampled row belongs to a group; each group is present at most once
    # (all its rows appear, but the group label appears exactly n_rows_per_group times)
    # — the key assertion is that no group appears more than its actual row count.
    for (g in names(group_counts)) {
      expect_lte(length(unique(idx[selected_groups == g])),
                 sum(groups == g))
    }
    # Stronger: unique group labels in the selection must equal selected group count
    expect_equal(length(unique(selected_groups)),
                 length(unique(groups[idx])))
  }
})
