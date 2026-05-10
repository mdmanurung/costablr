# Get the Full Stability Score Matrix from a Fitted STABL Object

Returns the raw stability-score matrix accumulated over all bootstrap
iterations. Inspecting this matrix is useful for diagnostics: you can
check how stable features are across the regularisation path, identify
features that are consistently selected at many lambda values
(robustness), and spot features that peak only at one extreme of the
path (fragility).

## Usage

``` r
get_stabl_scores(object)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

## Value

Numeric matrix with one row per original feature and one column per
lambda in the fitted grid. Row names are the feature names from the
training matrix; column names are not set (use
`object$fitted_lambda_grid` to map column indices to lambda values).

## Details

The stability score for feature \\j\\ at regularisation strength
\\\lambda_k\\ is defined as the fraction of bootstrap subsamples in
which feature \\j\\ received a non-zero coefficient when the model was
fitted at \\\lambda_k\\. Values lie in \\\[0, 1\]\\.

## See also

[`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md)
for the per-feature maximum score (scalar summary),
[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
for the binary selection mask.
