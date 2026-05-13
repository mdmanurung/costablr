# AUDIT IMPL-002: zero artificial count errors during accumulation

    Code
      stabl_fit(x = x, y = y, lambda_grid = data.frame(lambda = 0.1), n_bootstraps = 2L,
      artificial_type = "random_permutation", artificial_proportion = 0.1,
      sample_fraction = 1, random_state = 1L)
    Condition
      Error in `r[art_rows, , drop = FALSE]`:
      ! subscript out of bounds

# AUDIT IMPL-003: zero subsample count fails after bootstrap retries

    Code
      stabl_fit(x = x, y = y, lambda_grid = data.frame(lambda = 0.1), family = "binomial",
      n_bootstraps = 2L, artificial_type = NULL, hard_threshold = 0.5,
      sample_fraction = 0.01, random_state = 1L)
    Condition
      Error:
      ! classic_bootstrap_indices: could not draw a class-diverse subsample after 1000 attempts. Check class balance or increase `sample_fraction`.

