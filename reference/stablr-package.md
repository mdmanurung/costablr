# stablr: Sparse and Reliable Biomarker Discovery in R

`stablr` is a pure-R implementation of STABL for sparse, stable
biomarker selection in high-dimensional clinical and omic datasets. The
package provides a core bootstrap stability-selection engine, FDP+
threshold calibration with artificial features, glmnet-family learner
adapters, and multi-omic workflows for per-omic, early-fusion,
late-fusion, and cooperative-fusion analyses.

## Main workflows

  - `stabl_fit()` fits the core single-matrix STABL selector.

  - `stabl_multiomic_train_validate()` runs train/validation multi-omic
    workflows with optional early, late, and cooperative fusion.

  - `stabl_multiomic_cv()` runs outer cross-validation for named
    multi-omic inputs, preserving optional group structure.

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

`stabl_fit()`, `stabl_multiomic_train_validate()`, `get_support()`,
`get_importances()`, `plot_stabl_path()`

## Author

**Maintainer**: Mikaël Manurung <mikhael.manurung@gmail.com>

Authors:

  - Mikaël Manurung <mikhael.manurung@gmail.com>

Other contributors:

  - Jean Hédou (Original STABL method (Hédou et al., Nat Biotechnol
    2024)) \[contributor\]

  - Ivana Marić (Original STABL method (Hédou et al., Nat Biotechnol
    2024)) \[contributor\]

  - Gregory Bellan (Original STABL method (Hédou et al., Nat Biotechnol
    2024)) \[contributor\]

  - David Gfeller (Original STABL method (Hédou et al., Nat Biotechnol
    2024)) \[contributor\]

  - Daisy Yi Ding (Cooperative learning / multiview method (Ding et al.,
    PNAS 2022)) \[contributor\]

  - Shuangning Li (Cooperative learning / multiview method (Ding et al.,
    PNAS 2022)) \[contributor\]

  - Balasubramanian Narasimhan (Cooperative learning / multiview method
    (Ding et al., PNAS 2022)) \[contributor\]

  - Robert J. Tibshirani (Cooperative learning / multiview method (Ding
    et al., PNAS 2022)) \[contributor\]
