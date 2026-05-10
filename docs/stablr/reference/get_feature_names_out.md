# Get the Names of Selected Features from a Fitted STABL Object

Convenience wrapper around
[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
that returns only the names of the features that pass the stability
threshold, ready for use as column selectors in downstream modelling
(e.g. `x[, get_feature_names_out(fit)]`).

## Usage

``` r
get_feature_names_out(object, new_hard_threshold = NULL)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- new_hard_threshold:

  Numeric in `(0, 1]` or `NULL`. Forwarded to
  [`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md);
  see that function for the full threshold resolution order.

## Value

Character vector of selected feature names. An empty character vector is
returned when no feature passes the threshold (and `explore = FALSE` was
used during fitting).

## See also

[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
for the binary mask,
[`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md)
for ranked scores.
