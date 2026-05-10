# Get Per-Feature Importance Scores (Maximum Stability Score)

Returns a scalar summary of how stably each feature is selected across
the entire regularisation path. The importance of feature \\j\\ is
defined as \\\max\_{k} q\_{jk}\\, i.e. the highest selection frequency
it achieved at any lambda. This is the score compared against the
stability threshold in
[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md).

## Usage

``` r
get_importances(object)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

## Value

Named numeric vector of length `object$n_features_in_`, with values in
\\\[0, 1\]\\. Higher values indicate more stable features. Names are the
original feature names from the training matrix.

## Details

Because the maximum is taken across lambdas, the importance measure is
lenient: a feature qualifies even if it is stable only at one particular
penalty strength. For a more conservative view, use
[`get_stabl_scores()`](https://gregbellan.github.io/Stabl/stablr/reference/get_stabl_scores.md)
and inspect the full path.

## See also

[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
to convert importances to a binary selection mask,
[`get_stabl_scores()`](https://gregbellan.github.io/Stabl/stablr/reference/get_stabl_scores.md)
for the full path matrix.
