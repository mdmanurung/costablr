# Python to R Mapping

This file maps the Python STABL surface to the current R package API. The R
package is the active release artifact; Python names are listed here to make
parity reviews and migration work explicit.

## Core Selector Contracts

- `Stabl.fit(X, y, groups=None)`
  - Implemented: `stabl_fit(x, y, groups = NULL, ...)`

- `Stabl.get_support(indices=False, new_hard_threshold=None)`
  - Implemented: `get_support(fit, indices = FALSE, threshold = NULL)`

- `Stabl.get_feature_names_out(input_features=None, new_hard_threshold=None)`
  - Implemented: `get_feature_names_out(fit, new_hard_threshold = NULL)`

- `Stabl.transform(X, new_hard_threshold=None)`
  - Implemented: `transform_stabl(fit, x, new_hard_threshold = NULL)`

## Utility Contracts

- `classic_bootstrap(...)`
  - Implemented: `classic_bootstrap_indices(...)`

- `group_bootstrap(...)`
  - Implemented: `group_bootstrap_indices(...)`

- strict index/alignment assumptions (implicit in Python pipelines)
  - Implemented: `validate_sample_alignment(...)` and `validate_multiomic_inputs(...)`

## Implemented R Extensions

- Artificial feature generation: `make_artificial_features()`,
  `make_rp_features()`, `make_knockoff_features()`,
  `make_knockoff_equi_features()`, `make_knockoff_mvr_features()`
- FDP+ thresholding: `compute_fdp_plus()`
- Lambda-grid helpers: `auto_lambda_grid()`
- Multi-omic train/validation and CV: `stabl_multiomic_train_validate()`,
  `stabl_multiomic_cv()`, `stabl_multiomic_nested_cv()`
- Late-fusion stacking: `stacked_multi_omic()`
- Cooperative multi-view fusion: built into `stabl_multiomic_train_validate()`
  and `stabl_multiomic_cv()` for gaussian and binomial outcomes
- Export helpers: `export_stabl_to_csv()`, `save_stabl_results()`
- Reproducibility metrics: Jaccard, adjusted similarity, Pearson similarity,
  FDR/TPR/F-score similarity helpers
