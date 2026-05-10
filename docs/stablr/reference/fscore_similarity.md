# F-Score Between Two Feature Sets

Computes the F\\\_\beta\\ score between a predicted and a ground-truth
feature set. The default `beta = 1` gives the standard F1 score
(harmonic mean of precision and recall). Larger `beta` values weight
recall more heavily; smaller values emphasise precision.

## Usage

``` r
fscore_similarity(list1, list2, beta = 1)
```

## Arguments

- list1:

  Predicted feature set (character or integer vector).

- list2:

  True feature set (ground truth).

- beta:

  Positive numeric; controls trade-off between precision and recall.
  Default 1 gives the F1 score.

## Value

Numeric scalar in \\\[0, 1\]\\. Returns 0 when both the predicted and
true sets are empty.

## Details

Use
[`fdr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fdr_similarity.md)
and
[`tpr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/tpr_similarity.md)
when you want to report precision and recall separately; use
`fscore_similarity()` when you need a single number that balances both.
