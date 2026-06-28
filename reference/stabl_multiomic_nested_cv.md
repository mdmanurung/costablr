# Multi-Omic STABL Nested Cross-Validation

Runs a repeated outer cross-validation loop for generalisation
assessment. Within each outer training split, candidate STABL workflows
are compared using an inner cross-validation loop. The selected
candidate is then refit on the full outer-training split and evaluated
once on the held-out outer fold.

## Usage

``` r
stabl_multiomic_nested_cv(
  x_list,
  y,
  candidates = NULL,
  lambda_grid = "auto",
  outer_v = 5L,
  outer_repeats = 1L,
  inner_v = 5L,
  stratified = TRUE,
  strata = NULL,
  strata_bins = 5L,
  metric = c("ber", "accuracy"),
  family = "multinomial",
  n_bootstraps = 100L,
  artificial_type = "random_permutation",
  hard_threshold = NULL,
  random_state = NULL,
  n_lambda = 30L,
  l1_ratio = NULL,
  workers = 1L,
  cv_workers = 1L,
  ...
)

# S3 method for class 'stabl_multiomic_nested_cv'
print(x, ...)
```

## Arguments

  - x\_list:
    
    Named list of omic matrices or data frames with identical sample row
    names.

  - y:
    
    Named factor or character vector aligned to `x_list` rows.

  - candidates:
    
    Optional list of candidate definitions. Each candidate is a list
    with `name` and `blocks`; `blocks` names one or more omics from
    `x_list`. When `NULL`, one candidate is created for each omic plus
    one early-fusion candidate using all omics.

  - lambda\_grid:
    
    Either `"auto"`, a single lambda-grid data frame, or a named list of
    lambda grids. Named entries can match omic names or candidate names.

  - outer\_v:
    
    Number of outer folds per repeat.

  - outer\_repeats:
    
    Number of repeated outer CV rounds.

  - inner\_v:
    
    Number of inner folds used for candidate selection.

  - stratified:
    
    Logical. When `TRUE` (default), outer and inner folds preserve class
    proportions as closely as possible.

  - strata:
    
    Optional named vector used to stratify folds instead of `y`.
    Categorical values are used directly. Numeric values are binned into
    quantile groups before fold assignment.

  - strata\_bins:
    
    Number of quantile bins for numeric `strata`.

  - metric:
    
    Candidate-selection metric, `"ber"` or `"accuracy"`.

  - family:
    
    Passed to `stabl_fit()`. Defaults to `"multinomial"`.

  - n\_bootstraps:
    
    Passed to `stabl_fit()`.

  - artificial\_type:
    
    Passed to `stabl_fit()`.

  - hard\_threshold:
    
    Passed to `stabl_fit()`.

  - random\_state:
    
    Integer or `NULL`; top-level seed. Default: `NULL`.

  - n\_lambda:
    
    Passed to `stabl_fit()` when `lambda_grid = "auto"`.

  - l1\_ratio:
    
    Passed to `stabl_fit()` when `lambda_grid = "auto"`. Use this with
    `base_learner = "elastic_net"` to generate alpha-aware train-fold
    grids.

  - workers:
    
    Passed to `stabl_fit()` for bootstrap-level parallelism.

  - cv\_workers:
    
    Number of outer folds to evaluate in parallel. Uses
    `parallel::mclapply()` on Unix-like systems and falls back to
    sequential execution on Windows.

  - ...:
    
    Additional arguments passed to `stabl_fit()`.

  - x:
    
    A numeric matrix or `data.frame` (samples \\(\\times\\) features)
    with row names used as sample IDs.

## Value

An object of class `"stabl_multiomic_nested_cv"` containing fold
definitions, inner candidate diagnostics, outer held-out predictions,
selected features, and aggregate performance.

## Methods (by generic)

  - `print(stabl_multiomic_nested_cv)`: Print a concise summary of a
    `stabl_multiomic_nested_cv` object; invisibly returns `x`.

## Note

Cooperative fusion (`cooperative_fusion = TRUE`) is not supported in
nested CV. Use `stabl_multiomic_train_validate()` or
`stabl_multiomic_cv()` for cooperative workflows.
