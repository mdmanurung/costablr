# TPR Between Two Feature Sets

Computes the True Positive Rate (sensitivity / recall) when `list1` is
the predicted selection and `list2` is the known ground-truth. Use
together with `fdr_similarity()` and `fscore_similarity()` to
characterise the precision-recall trade-off in simulation benchmarks.

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

Numeric scalar in \\(\[0, 1\]\\). Returns 0 when the true set is empty.

## See also

`fdr_similarity()`, `fscore_similarity()`

## Examples

``` r
true_signal <- c("f1", "f2", "f3")
predicted   <- c("f1", "f2", "f4")  # misses f3
tpr_similarity(predicted, true_signal)       # 2/3
tpr_similarity(character(0), true_signal)    # 0
tpr_similarity(c("f1","f2","f3"), true_signal)  # 1
```
