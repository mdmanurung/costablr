# Transform New Data to the Selected STABL Feature Set

Subsets a matrix or data frame to the features selected by a fitted
`stabl_fit()` object. Columns are returned in fitted feature order, rows
are preserved, and the output remains two-dimensional even when no
features are selected.

## Usage

``` r
transform_stabl(object, x, new_hard_threshold = NULL)
```

## Arguments

  - object:
    
    A fitted `"stabl_fit"` object returned by `stabl_fit()`.

  - x:
    
    A matrix or `data.frame` with feature names in columns.

  - new\_hard\_threshold:
    
    Numeric in `(0, 1]` or `NULL`. When supplied, overrides the fitted
    threshold for this transformation only.

## Value

A matrix when `x` is a matrix, or a `data.frame` when `x` is a
`data.frame`, containing selected columns in fitted feature order.

## See also

`get_feature_names_out()`, `get_support()`
