# Get Cooperative-Fusion Tuning Diagnostics

Returns the cooperative-fusion tuning diagnostics from a fitted
multi-omic workflow. For train/validation fits this is the per-candidate
tuning table; for outer cross-validation fits this is the fold
diagnostics table restricted to cooperative diagnostic columns.

## Usage

``` r
get_cooperative_diagnostics(object)
```

## Arguments

- object:

  A `"stabl_multiomic_fit"` or `"stabl_multiomic_cv"` object with
  cooperative fusion enabled.

## Value

A `data.frame` of cooperative tuning diagnostics.

## See also

[`get_cooperative_features()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_features.md),
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md),
[`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
