# Multi-Omic STABL Cross-Validation Workflow

Builds deterministic fold splits over a named multi-omic input, fits
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
on each training fold, and returns fold-wise selection diagnostics
together with selected train/validation matrices for downstream
inspection.

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
```

## Arguments

- x_list:

  Named list of omic tables (`data.frame` or numeric matrix), each with
  row names as sample IDs.

- y:

  Named outcome vector.

- lambda_grid:

  Either a shared lambda grid (`data.frame` or `"auto"`) used for all
  omics, or a named list mapping each omic name to its own lambda grid.

- v:

  Number of folds. Must be at least 2.

- groups:

  Optional named grouping vector. When supplied, all samples in the same
  group are assigned to the same assessment fold.

- base_learner:

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- family:

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- n_bootstraps:

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- artificial_type:

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- hard_threshold:

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- random_state:

  Optional integer seed used for deterministic fold assignment and
  forwarded to each per-fold
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
  call.

- early_fusion:

  Logical. Forwarded to each per-fold
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
  call.

- late_fusion:

  Logical. Forwarded to each per-fold
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
  call.

- n_iter_lf:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- cooperative_fusion:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- rho:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- cooperation_selection:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- cooperation_selector:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- cooperation_type_measure:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- cooperation_nfolds:

  Forwarded to
  [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md).

- ...:

  Additional arguments forwarded to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

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
forwarded to each fold-specific
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
call.
