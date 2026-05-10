# Get Cooperative-Fusion Selected Features

Returns the feature names selected by the cooperative-fusion branch of a
fitted multi-omic workflow. This accessor gives downstream code a stable
public surface instead of reaching into `$cooperative_fusion` directly.

## Usage

``` r
get_cooperative_features(object, view = NULL)
```

## Arguments

- object:

  A fitted `"stabl_multiomic_fit"` object returned by
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
  with `cooperative_fusion = TRUE`, or a `"stabl_multiomic_cv"` object
  returned by
  [`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
  with `cooperative_fusion = TRUE`.

- view:

  Optional character scalar naming one omic view. When supplied for a
  `"stabl_multiomic_fit"`, only that view's cooperative feature names
  are returned.

## Value

For `"stabl_multiomic_fit"`, a named list of character vectors, or a
character vector when `view` is supplied. For `"stabl_multiomic_cv"`, a
named list keyed by fold, where each element has the same structure as
the `"stabl_multiomic_fit"` method.

## See also

[`get_cooperative_diagnostics()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_diagnostics.md),
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md),
[`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
