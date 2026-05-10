# Package index

## Core STABL Engine

Fit single-matrix STABL selectors and compute FDP+ thresholds.

- [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
  : Fit STABL (Stability-Penalized Feature Selection)
- [`auto_lambda_grid()`](https://gregbellan.github.io/Stabl/stablr/reference/auto_lambda_grid.md)
  : Build a Data-Driven Lambda Grid
- [`compute_fdp_plus()`](https://gregbellan.github.io/Stabl/stablr/reference/compute_fdp_plus.md)
  : Compute FDP+ (False Discovery Proportion Upper Bound)

## Learner Adapters

Public learner factories for glmnet-family and sparse-group backends.

- [`make_glmnet_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_glmnet_adapter.md)
  : Build a glmnet Learner Adapter
- [`make_adaptive_lasso_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_adaptive_lasso_adapter.md)
  : Build an Adaptive Lasso Learner Adapter
- [`make_sgl_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_sgl_adapter.md)
  : Build a Sparse Group Lasso Learner Adapter

## Artificial Features

Decoy-feature generation for FDP+ calibration.

- [`make_artificial_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_artificial_features.md)
  : Dispatcher for Artificial Feature Generation
- [`make_rp_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_rp_features.md)
  : Make Random-Permutation Artificial Features
- [`make_knockoff_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_knockoff_features.md)
  : Make Knockoff Artificial Features

## Input Validation and Bootstrapping

- [`validate_sample_alignment()`](https://gregbellan.github.io/Stabl/stablr/reference/validate_sample_alignment.md)
  : Validate Sample Alignment Across Inputs
- [`validate_multiomic_inputs()`](https://gregbellan.github.io/Stabl/stablr/reference/validate_multiomic_inputs.md)
  : Validate Multi-Omic Input Contract
- [`classic_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/classic_bootstrap_indices.md)
  : Classic Bootstrap Sampler Indices
- [`group_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/group_bootstrap_indices.md)
  : Group-Aware Bootstrap Sampler Indices

## Accessors

- [`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
  : Get the Feature Selection Mask from a Fitted STABL Object
- [`get_feature_names_out()`](https://gregbellan.github.io/Stabl/stablr/reference/get_feature_names_out.md)
  : Get the Names of Selected Features from a Fitted STABL Object
- [`get_stabl_scores()`](https://gregbellan.github.io/Stabl/stablr/reference/get_stabl_scores.md)
  : Get the Full Stability Score Matrix from a Fitted STABL Object
- [`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md)
  : Get Per-Feature Importance Scores (Maximum Stability Score)
- [`get_cooperative_features()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_features.md)
  : Get Cooperative-Fusion Selected Features
- [`get_cooperative_diagnostics()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_diagnostics.md)
  : Get Cooperative-Fusion Tuning Diagnostics

## Multi-Omic Workflows

- [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
  : Multi-Omic STABL Train/Validation Workflow
- [`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
  : Multi-Omic STABL Cross-Validation Workflow
- [`stacked_multi_omic()`](https://gregbellan.github.io/Stabl/stablr/reference/stacked_multi_omic.md)
  : Stacked Generalization Over Per-Omic Predictions
- [`load_ool_data()`](https://gregbellan.github.io/Stabl/stablr/reference/load_ool_data.md)
  : Load the Onset of Labor example dataset

## Visualization

- [`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md)
  : Plot the STABL Stability Path
- [`plot_fdr_graph()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_fdr_graph.md)
  : Plot the FDP+ FDR Estimate Curve
- [`plot_roc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_roc.md)
  : Plot a ROC Curve
- [`plot_prc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_prc.md)
  : Plot a Precision-Recall Curve
- [`boxplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/boxplot_features.md)
  : Boxplots of Selected Features Grouped by Outcome
- [`scatterplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/scatterplot_features.md)
  : Scatterplots of Selected Features Against a Continuous Outcome

## Export

- [`export_stabl_to_csv()`](https://gregbellan.github.io/Stabl/stablr/reference/export_stabl_to_csv.md)
  : Export STABL Stability Scores to CSV
- [`save_stabl_results()`](https://gregbellan.github.io/Stabl/stablr/reference/save_stabl_results.md)
  : Save All STABL Results to Disk

## Selection Similarity Metrics

- [`jaccard_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/jaccard_similarity.md)
  : Jaccard Similarity Between Two Feature Sets
- [`jaccard_matrix()`](https://gregbellan.github.io/Stabl/stablr/reference/jaccard_matrix.md)
  : Pairwise Jaccard Matrix from a List of Feature Sets
- [`adjusted_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity.md)
  : Adjusted Similarity Between Two Feature Sets
- [`adjusted_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_values.md)
  : Upper-Triangle Adjusted Similarity Values
- [`adjusted_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_measure.md)
  : Summary Statistic of Adjusted Similarity Values
- [`pearson_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity.md)
  : Pearson-Corrected Similarity Between Two Feature Sets
- [`pearson_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity_values.md)
  : Upper-Triangle Pearson Similarity Values
- [`pearson_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity_measure.md)
  : Summary Statistic of Pearson Similarity Values
- [`fdr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fdr_similarity.md)
  : FDR Between Two Feature Sets
- [`tpr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/tpr_similarity.md)
  : TPR Between Two Feature Sets
- [`fscore_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fscore_similarity.md)
  : F-Score Between Two Feature Sets
