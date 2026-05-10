# Get the Feature Selection Mask from a Fitted STABL Object

Returns a named logical vector that is `TRUE` for every feature whose
maximum stability score exceeds the effective threshold. This is the
primary accessor for downstream use of a fitted STABL model: index your
data matrix with the returned mask, or pass the object to
[`get_feature_names_out()`](https://gregbellan.github.io/Stabl/stablr/reference/get_feature_names_out.md)
to obtain the names directly.

## Usage

``` r
get_support(object, new_hard_threshold = NULL)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- new_hard_threshold:

  Numeric in `(0, 1]` or `NULL`. When supplied, overrides the threshold
  stored in `object` for this call only.

## Value

Named logical vector of length `object$n_features_in_`. Names are the
original feature names from the training matrix.

## Details

**Threshold resolution order:**

1.  `new_hard_threshold` (if supplied to this call).

2.  `object$hard_threshold` (if a hard threshold was given to
    [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)).

3.  `object$fdr_min_threshold_` (the FDP+-optimal threshold computed
    from artificial features during fitting).

An error is raised when none of these is available — which can only
happen if
[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
was called with both `artificial_type = NULL` and no `hard_threshold`.

**Explore fallback:** When `explore = TRUE` was set during fitting and
no feature's score exceeds the threshold, the function returns the top
`n_explore` features instead of an all-`FALSE` vector. This is useful in
exploratory analyses where you want at least some candidates even when
the signal is weak.

## See also

[`get_feature_names_out()`](https://gregbellan.github.io/Stabl/stablr/reference/get_feature_names_out.md)
to get names directly,
[`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md)
to inspect raw stability scores.
