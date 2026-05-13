# 02 Interface Compatibility Findings

## Finding INT-001: Duplicate sample IDs pass alignment and are first-matched

- Status: FIXED 2026-05-13. Duplicate predictor, outcome, group, and direct
  subset IDs are now rejected; guarded by
  `tests/testthat/test-audit-input-validation.R`.
- Severity: HIGH
- Locations: `R/input_validation.R:79`, `R/input_validation.R:92`,
  `R/input_validation.R:131`, `R/input_validation.R:133`
- Observation: `validate_sample_alignment()` accepts row names that are
  non-empty, then compares name sets with `setequal()`. It does not check
  `anyDuplicated()` or equal multiplicity. `.subset_outcome_by_ids()` uses
  `match(sample_ids, y_ids)`, which returns the first match for duplicates.
- Dynamic verification: `validate_sample_alignment()` returned invisibly for
  `x` row names `c("s1", "s1", "s2")` and `y` names `c("s1", "s2")`;
  `.subset_outcome_by_ids()` returned `c(s1 = 1, s1 = 1, s2 = 2)`.
- Risk: duplicate predictor rows, outcomes, or groups can be silently reused or
  dropped, violating the pandas-style strict alignment assumption and
  corrupting bootstrap/model inputs.
- Confidence: HIGH.
- Suggested fix: reject duplicate row names, `y` IDs, and `groups` names before
  `setequal()`/`match()`.

## Finding INT-002: Generated feature names cannot subset unnamed matrices

- Status: FIXED 2026-05-13. Fallback feature names are propagated so
  selected-matrix construction works for unnamed matrices; guarded by
  `tests/testthat/test-audit-multiomic-workflows.R`.
- Severity: HIGH
- Locations: `R/stabl_fit.R:226`, `R/stabl_fit.R:227`,
  `R/stabl_accessors.R:133`, `R/multiomic_workflows.R:185`,
  `R/multiomic_workflows.R:600`, `R/multiomic_workflows.R:602`
- Observation: `stabl_fit()` creates fallback names `x.1`, `x.2`, ... when
  `colnames(x)` is `NULL`, but it does not assign those names back to `x` or
  `x_fit`. `get_feature_names_out()` returns the fallback names, and
  `.subset_selected_matrix()` subsets the original matrix/data frame by those
  names.
- Dynamic verification: a no-colname matrix in
  `stabl_multiomic_train_validate()` fit core STABL but then errored while
  building `selected_train`: `undefined columns selected`.
- Risk: single-matrix `stabl_fit()` can appear successful, but downstream
  multi-omic composition and user subsetting fail as soon as unnamed features
  are selected.
- Confidence: HIGH.
- Suggested fix: after generating fallback feature names, assign them to
  `colnames(x)` before artificial-feature generation and downstream use.

## Finding INT-003: Late fusion uses positional `y_train` after core STABL aligned by names

- Status: FIXED 2026-05-13. Named training and validation outcomes are aligned
  once before downstream late/cooperative fusion paths; guarded by
  `tests/testthat/test-audit-multiomic-workflows.R`.
- Severity: HIGH
- Locations: `R/multiomic_workflows.R:114`, `R/multiomic_workflows.R:166`,
  `R/multiomic_workflows.R:288`, `R/multiomic_workflows.R:289`,
  `R/multiomic_workflows.R:308`, `R/multiomic_workflows.R:310`
- Observation: `stabl_multiomic_train_validate()` validates that `y_train`
  names match inputs, and each `stabl_fit()` call realigns internally. The
  later late-fusion branch passes the original `y_train` into
  `.late_fusion_fit_omic()` and passes `unname(y_train)` into
  `stacked_multi_omic()`, so ordering matters again.
- Dynamic verification: ordered and shuffled named `y_train` produced identical
  selected features but different late-fusion train predictions under the same
  seed and input matrices.
- Risk: callers can supply correctly named but shuffled outcomes, get correct
  STABL selection, then train downstream late-fusion predictors against
  misordered outcomes.
- Confidence: HIGH for late fusion. Cooperative-fusion alignment has similar
  positional call sites at `R/multiomic_workflows.R:991` and
  `R/multiomic_workflows.R:1047`, but that branch was not dynamically verified.
- Suggested fix: align `y_train` and `y_valid` once to `rownames(x_train_list[[1]])`
  and validation row names immediately after validation, then use aligned
  objects for all downstream branches.

## Finding INT-004: Validation predictors without `y_valid` return empty late-fusion predictions

- Status: FIXED 2026-05-13. Validation predictions are sized from validation
  predictor rows when `y_valid` is absent; guarded by
  `tests/testthat/test-audit-multiomic-workflows.R`.
- Severity: MEDIUM
- Locations: `R/multiomic_workflows.R:120`, `R/multiomic_workflows.R:592`,
  `R/multiomic_workflows.R:268`, `R/multiomic_workflows.R:271`,
  `R/multiomic_workflows.R:303`, `R/multiomic_workflows.R:322`
- Observation: validation matrices are allowed without `y_valid`. For
  non-multiclass late fusion, `valid_preds` is allocated with
  `nrow = length(y_valid)`, which is zero when `y_valid = NULL`, then
  predictions from non-empty `x_valid_sel` are assigned into that zero-row
  matrix.
- Dynamic verification: gaussian late fusion with `x_valid_list` and
  `y_valid = NULL` returned `fit$late_fusion$valid_predictions` as
  `logical(0)` and emitted a zero-extent matrix warning.
- Risk: validation predictions are silently unusable whenever outcomes are
  unavailable, even though validation feature matrices were supplied.
- Confidence: HIGH.
- Suggested fix: allocate validation prediction storage from `nrow()` of the
  validation matrix, not from `length(y_valid)`, and only compute validation
  scores when `y_valid` is supplied.

## Finding INT-005: `stacked_multi_omic()` accepts recycled outcome lengths

- Status: FIXED 2026-05-13. Binary/regression stacking now requires one
  outcome per prediction row; guarded by
  `tests/testthat/test-audit-multiomic-workflows.R`.
- Severity: MEDIUM
- Locations: `R/multiomic_workflows.R:1230`, `R/multiomic_workflows.R:1265`,
  `R/multiomic_workflows.R:1270`, `R/multiomic_workflows.R:1272`
- Observation: binary/regression stacking coerces predictions to a matrix but
  does not check `length(y) == nrow(predictions)`. It builds `complete_idx`
  with vectorized `&` and indexes `y` positionally.
- Dynamic verification: four prediction rows with `y = c(0, 1)` produced a
  result with four prediction rows and score `1` because the two-element
  outcome was recycled without warning.
- Risk: accidental short outcomes can produce plausible scores and weights on
  the wrong labels.
- Confidence: HIGH.
- Suggested fix: require `length(y) == nrow(predictions)` for binary and
  regression paths, mirroring the multiclass check at
  `R/multiomic_workflows.R:1303`.

## Finding INT-006: Direct Rcpp MVR boundary accepts malformed update orders

- Status: FIXED 2026-05-13. The native MVR boundary now rejects
  non-permutation update-order rows, matching the R wrapper guard; covered by
  `tests/testthat/test-audit-mvr-boundary.R`.
- Severity: LOW
- Locations: `R/RcppExports.R:4`, `R/RcppExports.R:5`,
  `R/mvr_knockoff.R:63`, `R/mvr_knockoff.R:78`,
  `src/mvr_knockoff.cpp:90`, `src/mvr_knockoff.cpp:105`
- Observation: `.solve_mvr()` validates each `update_order` row as a
  permutation of `1:p`, but the generated `mvr_solve_ungrouped_cpp()` wrapper
  is directly callable inside the namespace. The C++ boundary checks only
  dimensions and range, not duplicate/missing coordinates.
- Dynamic verification: `costablr:::mvr_solve_ungrouped_cpp()` accepted
  `matrix(c(1, 1, 2, 3), nrow = 1)` for `p = 4`, while `.solve_mvr()`
  rejected it.
- Risk: internal tests or future code can bypass the R wrapper and get solver
  behavior that cannot occur through the public MVR path.
- Confidence: HIGH.
- Suggested fix: add the permutation check in C++ too, or make the exported
  wrapper name private enough that direct calls are clearly unsupported.
