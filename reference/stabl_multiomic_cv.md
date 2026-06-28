# Multi-Omic STABL Cross-Validation Workflow

Builds deterministic fold splits over a named multi-omic input, fits
`stabl_multiomic_train_validate()` on each training fold, and returns
fold-wise selection diagnostics together with selected train/validation
matrices for downstream inspection.

## Usage

``` r
stabl_multiomic_cv(
  x_list,
  y,
  lambda_grid,
  v = 5L,
  groups = NULL,
  base_learner = "lasso",
  family = "gaussian",
  n_bootstraps = 100L,
  artificial_type = "random_permutation",
  hard_threshold = NULL,
  stratify_bootstrap = FALSE,
  bootstrap_strata = NULL,
  l1_ratio = NULL,
  random_state = NULL,
  early_fusion = FALSE,
  late_fusion = FALSE,
  n_iter_lf = 10000L,
  cooperative_fusion = FALSE,
  rho = NULL,
  cooperation_selection = c("cv", "validation"),
  cooperation_selector = c("lambda.min", "lambda.1se"),
  cooperation_type_measure = "default",
  cooperation_nfolds = 5L,
  ...
)

# S3 method for class 'stabl_multiomic_cv'
print(x, ...)
```

## Arguments

  - x\_list:
    
    Named list of omic tables (`data.frame` or numeric matrix), each
    with row names as sample IDs.

  - y:
    
    Named outcome vector.

  - lambda\_grid:
    
    Either a shared lambda grid (`data.frame` or `"auto"`) used for all
    omics, or a named list mapping each omic name to its own lambda
    grid.

  - v:
    
    Number of folds. Must be at least 2.

  - groups:
    
    Optional named grouping vector. When supplied, all samples in the
    same group are assigned to the same assessment fold.

  - base\_learner:
    
    Passed to `stabl_fit()`.

  - family:
    
    Character; `glmnet` response family (`"gaussian"`, `"binomial"`,
    `"multinomial"`, or `"cox"`). Default: `"gaussian"`.

  - n\_bootstraps:
    
    Passed to `stabl_fit()`.

  - artificial\_type:
    
    Passed to `stabl_fit()`.

  - hard\_threshold:
    
    Passed to `stabl_fit()`.

  - stratify\_bootstrap:
    
    Passed to `stabl_fit()`.

  - bootstrap\_strata:
    
    Optional categorical bootstrap stratification design forwarded to
    `stabl_fit()` for each training fold.

  - l1\_ratio:
    
    Passed to `stabl_fit()` when `lambda_grid = "auto"`.

  - random\_state:
    
    Optional integer seed used for deterministic fold assignment and
    forwarded to each per-fold `stabl_fit()` call.

  - early\_fusion:
    
    Logical. Forwarded to each per-fold
    `stabl_multiomic_train_validate()` call.

  - late\_fusion:
    
    Logical. Forwarded to each per-fold
    `stabl_multiomic_train_validate()` call.

  - n\_iter\_lf:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - cooperative\_fusion:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - rho:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - cooperation\_selection:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - cooperation\_selector:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - cooperation\_type\_measure:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - cooperation\_nfolds:
    
    Forwarded to `stabl_multiomic_train_validate()`.

  - ...:
    
    Additional arguments forwarded to `stabl_fit()`.

  - x:
    
    A numeric matrix or `data.frame` (samples \\(\\times\\) features)
    with row names used as sample IDs.

## Value

A list with class `"stabl_multiomic_cv"` containing:

  - `folds`:
    
    List of fold descriptors with `fold`, `train_ids`, and `valid_ids`.

  - `fold_results`:
    
    Named list of per-fold `stabl_multiomic_fit` results.

  - `diagnostics`:
    
    Data frame with one row per fold/omic and columns `fold`, `omic`,
    `n_selected`, `threshold`, and `max_score`.

## Details

Optional early-fusion, late-fusion, and cooperative-fusion branches are
forwarded to each fold-specific `stabl_multiomic_train_validate()` call.

## Methods (by generic)

  - `print(stabl_multiomic_cv)`: Print a concise summary of a
    `stabl_multiomic_cv` object; invisibly returns `x`.
