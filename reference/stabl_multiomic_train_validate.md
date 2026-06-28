# Multi-Omic STABL Train/Validation Workflow

Fits `stabl_fit()` independently on each omic block from a named list,
then returns per-omic fitted objects and selected-feature matrices for
downstream composition. Optional early-fusion, late-fusion, and
cooperative-fusion branches are additive to the per-omic STABL results.

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
  stratify_bootstrap = FALSE,
  bootstrap_strata_train = NULL,
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

# S3 method for class 'stabl_multiomic_fit'
print(x, ...)
```

## Arguments

  - x\_train\_list:
    
    Named list of training omic tables (`data.frame` or numeric matrix),
    each with row names as sample IDs.

  - y\_train:
    
    Named outcome vector for training samples.

  - lambda\_grid:
    
    Either a shared lambda grid (`data.frame` or `"auto"`) used for all
    omics, or a named list mapping each omic name to its own lambda
    grid.

  - x\_valid\_list:
    
    Optional named list of validation omic tables. When supplied, names
    must match `x_train_list` names.

  - y\_valid:
    
    Optional named outcome vector for validation samples. When supplied
    together with `x_valid_list`, sample alignment is validated.

  - groups\_train:
    
    Optional named grouping vector for training samples. When supplied,
    grouped bootstrap sampling is used in each per-omic fit.

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
    
    Passed to `stabl_fit()`. When `TRUE`, per-omic and early-fusion
    STABL fits draw class-stratified bootstrap subsamples.

  - bootstrap\_strata\_train:
    
    Optional categorical bootstrap stratification design for training
    samples, forwarded to `stabl_fit()`.

  - l1\_ratio:
    
    Passed to `stabl_fit()` when `lambda_grid = "auto"`. Use this with
    `base_learner = "elastic_net"` to generate alpha-aware auto grids.

  - random\_state:
    
    Integer or `NULL`; top-level seed. Default: `NULL`.

  - early\_fusion:
    
    Logical. When `TRUE`, a single `stabl_fit()` is run on the
    column-bound concatenation of all omic matrices in addition to the
    per-omic fits. Results are returned in the `early_fusion` field.

  - late\_fusion:
    
    Logical. When `TRUE`, a downstream predictor is fitted per omic on
    its selected features, and `stacked_multi_omic()` combines the
    per-omic predictions. If no features are selected for an omic, late
    fusion falls back to class priors for multinomial tasks or the
    train-set mean for other tasks. The `task_type` (binary, regression,
    or multiclass) is inferred from `family`. Results are returned in
    the `late_fusion` field.

  - n\_iter\_lf:
    
    Number of random weight draws passed to `stacked_multi_omic()`
    during late fusion. Ignored when `late_fusion = FALSE`.

  - cooperative\_fusion:
    
    Logical. When `TRUE`, fit a built-in cooperative learning branch
    (vendored multiview engine) in addition to the existing per-omic
    STABL fits. Native v1 supports `family = "gaussian"` and
    `"binomial"` only.

  - rho:
    
    Numeric scalar or vector of non-negative cooperation strengths. When
    `NULL`, defaults to `0`.

  - cooperation\_selection:
    
    Character scalar. Either `"cv"` or `"validation"`. `"cv"` tunes over
    `rho` with shared inner fold assignments. `"validation"` tunes over
    `rho` and `lambda` on the supplied validation set.

  - cooperation\_selector:
    
    Character scalar. Selection rule for the cooperative `lambda`.
    `"lambda.1se"` is only available when `cooperation_selection =
    "cv"`.

  - cooperation\_type\_measure:
    
    Character scalar controlling the cooperative tuning metric.
    Supported values follow the active `family` and the multiview CV
    API.

  - cooperation\_nfolds:
    
    Number of inner folds used when `cooperation_selection = "cv"`.

  - ...:
    
    Additional arguments forwarded to `stabl_fit()`.

  - x:
    
    A numeric matrix or `data.frame` (samples \\(\\times\\) features)
    with row names used as sample IDs.

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
    
    Named list of validation matrices restricted to selected features,
    or `NULL` when no validation input is provided.

  - `early_fusion`:
    
    `NULL` when `early_fusion = FALSE`. Otherwise a list with `fit`,
    `selected_features`, `selected_train`, and `selected_valid` for the
    concatenated single-STABL run.

  - `late_fusion`:
    
    `NULL` when `late_fusion = FALSE`. Otherwise a list with `weights`
    (data.frame), `train_predictions` (data.frame), `valid_predictions`,
    and `score`; multinomial tasks also include `levels`, `log_loss`,
    and classification metrics.

  - `cooperative_fusion`:
    
    Present only when `cooperative_fusion = TRUE`. A list containing the
    selected multiview fit, chosen `rho` and `lambda`, selected features
    per view, train/validation predictions, and tuning diagnostics.

## Functions

  - `print(stabl_multiomic_fit)`: Print a concise summary of a
    `stabl_multiomic_fit` object; invisibly returns `x`.
