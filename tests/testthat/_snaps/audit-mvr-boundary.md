# AUDIT INT-007: direct Rcpp MVR boundary accepts non-permutation order

    Code
      costablr:::.solve_mvr(sigma, num_iter = 1L, update_order = bad_order)
    Condition
      Error:
      ! Each `update_order` row must be a permutation of 1:p.

