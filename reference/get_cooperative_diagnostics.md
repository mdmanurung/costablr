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

`get_cooperative_features()`, `stabl_multiomic_train_validate()`,
`stabl_multiomic_cv()`

## Examples

``` r
# \donttest{
set.seed(1L)
n <- 40L
x_list <- list(
  omic1 = matrix(rnorm(n * 5), n, 5,
                 dimnames = list(paste0("s", 1:n), paste0("g", 1:5))),
  omic2 = matrix(rnorm(n * 4), n, 4,
                 dimnames = list(paste0("s", 1:n), paste0("p", 1:4)))
)
y <- setNames(rnorm(n), paste0("s", 1:n))
lam <- data.frame(lambda = c(0.3, 0.1))
fit <- stabl_multiomic_train_validate(
  x_list, y, family = "gaussian",
  train_idx = 1:30, valid_idx = 31:40,
  lambda_grid = lam, n_bootstraps = 4L,
  hard_threshold = 0.2, cooperative_fusion = TRUE,
  random_state = 1L
)
get_cooperative_diagnostics(fit)   # data.frame of tuning results
# }
```
