# TPR Between Two Feature Sets

Computes the True Positive Rate (sensitivity / recall) when `list1` is
the predicted selection and `list2` is the known ground-truth. Use
together with
[`fdr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fdr_similarity.md)
and
[`fscore_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fscore_similarity.md)
to characterise the precision-recall trade-off in simulation benchmarks.

## Usage

``` r
tpr_similarity(list1, list2)
```

## Arguments

- list1:

  Predicted feature set (character or integer vector).

- list2:

  True feature set (ground truth).

## Value

Numeric scalar in \\\[0, 1\]\\. Returns 0 when the true set is empty.
