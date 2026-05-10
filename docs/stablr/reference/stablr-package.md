# stablr: Sparse and Reliable Biomarker Discovery in R

`stablr` is a pure-R implementation of STABL for sparse, stable
biomarker selection in high-dimensional clinical and omic datasets. The
package provides a core bootstrap stability-selection engine, FDP+
threshold calibration with artificial features, glmnet-family learner
adapters, and multi-omic workflows for per-omic, early-fusion,
late-fusion, and cooperative-fusion analyses.

## Main workflows

- [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
  fits the core single-matrix STABL selector.

- [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
  runs train/validation multi-omic workflows with optional early, late,
  and cooperative fusion.

- [`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
  runs outer cross-validation for named multi-omic inputs, preserving
  optional group structure.

## Learners and outcomes

The core selector supports lasso, elastic net, adaptive lasso, and
optional sparse group lasso backends. Supported `glmnet` families
include Gaussian, binomial, multinomial, and Cox where the selected
backend supports them.

## Outputs

Fitted objects expose stable S3 accessors for support masks, selected
feature names, stability scores, importances, cooperative-fusion
features, and cooperative diagnostics. Plotting and export helpers
provide stability paths, FDP+ curves, ROC/PRC plots, selected-feature
visualizations, and CSV output.

## See also

[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md),
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md),
[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md),
[`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md),
[`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md)

## Author

**Maintainer**: stablr contributors <maintainer@example.org>

Authors:

- stablr contributors <maintainer@example.org>
