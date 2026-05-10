# FDR Between Two Feature Sets

Computes the False Discovery Rate when `list1` is treated as the
predicted selection and `list2` as the known ground-truth. This metric
is only meaningful in simulation benchmarks where the true signal
features are known in advance.

## Usage

``` r
fdr_similarity(list1, list2)
```

## Arguments

- list1:

  Predicted feature set (character or integer vector).

- list2:

  True feature set (ground truth).

## Value

Numeric scalar in \\\[0, 1\]\\. Returns 0 when the predicted set is
empty (no false discoveries possible).
