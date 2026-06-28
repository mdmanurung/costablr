# F-Score Between Two Feature Sets

Computes the F\\(\_\\beta\\) score between a predicted and a
ground-truth feature set. The default `beta = 1` gives the standard F1
score (harmonic mean of precision and recall). Larger `beta` values
weight recall more heavily; smaller values emphasise precision.

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

Numeric scalar in \\(\[0, 1\]\\). Returns 0 when both the predicted and
true sets are empty.

## Details

Use `fdr_similarity()` and `tpr_similarity()` when you want to report
precision and recall separately; use `fscore_similarity()` when you need
a single number that balances both.

## See also

`fdr_similarity()`, `tpr_similarity()`

## Examples

``` r
true_signal <- c("f1", "f2", "f3")
predicted   <- c("f1", "f2", "f4")  # 2 TP, 1 FP, 1 FN
fscore_similarity(predicted, true_signal)           # F1
fscore_similarity(predicted, true_signal, beta = 2) # recall-weighted
fscore_similarity(character(0), character(0))       # 0
```
