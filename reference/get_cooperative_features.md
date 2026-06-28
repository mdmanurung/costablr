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
    `stabl_multiomic_train_validate()` with `cooperative_fusion = TRUE`,
    or a `"stabl_multiomic_cv"` object returned by
    `stabl_multiomic_cv()` with `cooperative_fusion = TRUE`.

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

`get_cooperative_diagnostics()`, `stabl_multiomic_train_validate()`,
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
get_cooperative_features(fit)           # named list of feature vectors
get_cooperative_features(fit, "omic1") # one view only
# }
```
