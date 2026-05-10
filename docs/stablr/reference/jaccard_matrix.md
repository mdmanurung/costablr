# Pairwise Jaccard Matrix from a List of Feature Sets

Computes all N\\\times\\N pairwise Jaccard similarities in one call.
Useful for visualising the reproducibility of STABL across multiple
cross-validation folds or repeated runs: a boxplot of the off-diagonal
values summarises how consistently the same features are selected.

## Usage

``` r
jaccard_matrix(list_of_lists, remove_diag = TRUE)
```

## Arguments

- list_of_lists:

  A list of character/integer vectors, one per STABL run (e.g. one per
  cross-validation fold).

- remove_diag:

  Logical; if `TRUE` (default) the diagonal column (self-similarity = 1)
  is removed from the output.

## Value

Numeric matrix of dimension N\\\times\\N (or N\\\times\\(N-1) when
`remove_diag = TRUE`). Row/column order matches `list_of_lists`.

## Details

By default the self-similarity diagonal (always 1) is removed, so the
returned matrix has \\N \times (N - 1)\\ columns and each row contains
the \\N - 1\\ similarities of run \\i\\ with every other run.
