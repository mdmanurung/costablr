# Multi-Omic STABL Train/Validation Workflow

Fits
[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
independently on each omic block from a named list, then returns
per-omic fitted objects and selected-feature matrices for downstream
composition. Optional early-fusion, late-fusion, and cooperative-fusion
branches are additive to the per-omic STABL results.

## Usage

``` r
stabl_multiomic_train_validate(
  x_train_list,
  y_train,
  lambda_grid,
  x_valid_list = NULL,
  y_valid = NULL,
  groups_train = NULL,
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

- x_train_list:

  Named list of training omic tables (`data.frame` or numeric matrix),
  each with row names as sample IDs.

- y_train:

  Named outcome vector for training samples.

- lambda_grid:

  Either a shared lambda grid (`data.frame` or `"auto"`) used for all
  omics, or a named list mapping each omic name to its own lambda grid.

- x_valid_list:

  Optional named list of validation omic tables. When supplied, names
  must match `x_train_list` names.

- y_valid:

  Optional named outcome vector for validation samples. When supplied
  together with `x_valid_list`, sample alignment is validated.

- groups_train:

  Optional named grouping vector for training samples. When supplied,
  grouped bootstrap sampling is used in each per-omic fit.

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

  Passed to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- early_fusion:

  Logical. When `TRUE`, a single
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
  is run on the column-bound concatenation of all omic matrices in
  addition to the per-omic fits. Results are returned in the
  `early_fusion` field.

- late_fusion:

  Logical. When `TRUE`, a downstream predictor is fitted per omic on its
  selected features, and
  [`stacked_multi_omic()`](https://gregbellan.github.io/Stabl/stablr/reference/stacked_multi_omic.md)
  combines the per-omic predictions. Requires at least one feature to be
  selected across the omics. The `task_type` (binary vs. regression) is
  inferred from `family`. Results are returned in the `late_fusion`
  field.

- n_iter_lf:

  Number of random weight draws passed to
  [`stacked_multi_omic()`](https://gregbellan.github.io/Stabl/stablr/reference/stacked_multi_omic.md)
  during late fusion. Ignored when `late_fusion = FALSE`.

- cooperative_fusion:

  Logical. When `TRUE`, fit a multiview-based cooperative learning
  branch in addition to the existing per-omic STABL fits. Requires the
  optional `multiview` package.

- rho:

  Numeric scalar or vector of non-negative cooperation strengths. When
  `NULL`, defaults to `0` following
  [`multiview::multiview()`](https://rdrr.io/pkg/multiview/man/multiview.html).

- cooperation_selection:

  Character scalar. Either `"cv"` or `"validation"`. `"cv"` tunes over
  `rho` with shared inner fold assignments. `"validation"` tunes over
  `rho` and `lambda` on the supplied validation set.

- cooperation_selector:

  Character scalar. Selection rule for the cooperative `lambda`.
  `"lambda.1se"` is only available when `cooperation_selection = "cv"`.

- cooperation_type_measure:

  Character scalar controlling the cooperative tuning metric. Supported
  values follow the active `family` and the multiview CV API.

- cooperation_nfolds:

  Number of inner folds used when `cooperation_selection = "cv"`.

- ...:

  Additional arguments forwarded to
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

## Value

A named list with class `"stabl_multiomic_fit"` containing:

- `fits`:

  Named list of per-omic `stabl_fit` objects.

- `selected_features`:

  Named list of selected feature names.

- `selected_train`:

  Named list of training matrices restricted to selected features
  (possibly 0-column).

- `selected_valid`:

  Named list of validation matrices restricted to selected features, or
  `NULL` when no validation input is provided.

- `early_fusion`:

  `NULL` when `early_fusion = FALSE`. Otherwise a list with `fit`,
  `selected_features`, `selected_train`, and `selected_valid` for the
  concatenated single-STABL run.

- `late_fusion`:

  `NULL` when `late_fusion = FALSE`. Otherwise a list with `weights`
  (data.frame), `train_predictions` (data.frame), `valid_predictions`
  (numeric vector or `NULL`), and `score`.

- `cooperative_fusion`:

  Present only when `cooperative_fusion = TRUE`. A list containing the
  selected multiview fit, chosen `rho` and `lambda`, selected features
  per view, train/validation predictions, and tuning diagnostics.
