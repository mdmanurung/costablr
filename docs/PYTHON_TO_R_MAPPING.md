# Python to R Mapping (Initial)

This file maps existing Python surfaces to planned R symbols. It is a working
document and should be updated as implementation proceeds.

## Core Selector Contracts

- `Stabl.fit(X, y, groups=None)`
  - Planned: `stabl_fit(x, y, groups = NULL, ...)`

- `Stabl.get_support(indices=False, new_hard_threshold=None)`
  - Planned: `stabl_support(fit, indices = FALSE, threshold = NULL)`

- `Stabl.get_feature_names_out(input_features=None, new_hard_threshold=None)`
  - Planned: `stabl_feature_names(fit, input_features = NULL, threshold = NULL)`

- `Stabl.transform(X, new_hard_threshold=None)`
  - Planned: `stabl_transform(fit, x, threshold = NULL)`

## Utility Contracts

- `classic_bootstrap(...)`
  - Implemented: `classic_bootstrap_indices(...)`

- `group_bootstrap(...)`
  - Implemented: `group_bootstrap_indices(...)`

- strict index/alignment assumptions (implicit in Python pipelines)
  - Implemented: `validate_sample_alignment(...)` and `validate_multiomic_inputs(...)`

## Next Mapping Targets

- artificial feature generation (`random_permutation`, Python `knockoff`
  mapped to R `modelx_knockoff`, and R `mvr_knockoff`)
- FDR/FDP threshold computation and storage
- stability path export helpers
- CV and train/validation orchestration
- late-fusion stacked weighting behavior
