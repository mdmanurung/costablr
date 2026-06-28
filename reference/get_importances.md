# Get Per-Feature Importance Scores (Maximum Stability Score)

Returns a scalar summary of how stably each feature is selected across
the entire regularisation path. The importance of feature \\(j\\) is
defined as \\(\\max\_{k} q\_{jk}\\), i.e. the highest selection
frequency it achieved at any lambda. This is the score compared against
the stability threshold in `get_support()`.

## Usage

``` r
get_importances(object)
```

## Arguments

  - object:
    
    A fitted `"stabl_fit"` object returned by `stabl_fit()`.

## Value

Named numeric vector of length `object$n_features_in_`, with values in
\\(\[0, 1\]\\). Higher values indicate more stable features. Names are
the original feature names from the training matrix.

## Details

Because the maximum is taken across lambdas, the importance measure is
lenient: a feature qualifies even if it is stable only at one particular
penalty strength. For a more conservative view, use `get_stabl_scores()`
and inspect the full path.

## See also

`get_support()` to convert importances to a binary selection mask,
`get_stabl_scores()` for the full path matrix.

## Examples

``` r
set.seed(1L)
x <- matrix(rnorm(30 * 5), 30, 5,
            dimnames = list(paste0("s", 1:30), paste0("f", 1:5)))
y <- setNames(rnorm(30), rownames(x))
fit <- stabl_fit(x, y,
                 lambda_grid    = data.frame(lambda = c(0.2, 0.1, 0.05)),
                 n_bootstraps   = 4L,
                 hard_threshold = 0.3,
                 random_state   = 1L)
imp <- get_importances(fit)  # named numeric, max stability per feature
sort(imp, decreasing = TRUE)
```
