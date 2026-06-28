# Package index

## Package Overview

<!-- end list -->

  - `stablr` `stablr-package` : stablr: Sparse and Reliable Biomarker
    Discovery in R

## Core STABL Engine

Fit single-matrix STABL selectors and compute FDP+ thresholds.

<!-- end list -->

  - `stabl_fit()` `print(<stabl_fit>)` : Fit STABL (Stability-Penalized
    Feature Selection)
  - `auto_lambda_grid()` : Build a Data-Driven Lambda Grid
  - `compute_fdp_plus()` : Compute FDP+ (False Discovery Proportion
    Upper Bound)

## Learner Adapters

Public learner factories for glmnet-family and sparse-group backends.

<!-- end list -->

  - `make_glmnet_adapter()` : Build a glmnet Learner Adapter
  - `make_adaptive_lasso_adapter()` : Build an Adaptive Lasso Learner
    Adapter
  - `make_sgl_adapter()` : Build a Sparse Group Lasso Learner Adapter

## Artificial Features

Decoy-feature generation for FDP+ calibration.

<!-- end list -->

  - `make_artificial_features()` : Dispatcher for Artificial Feature
    Generation

## Input Validation and Bootstrapping

<!-- end list -->

  - `validate_sample_alignment()` : Validate Sample Alignment Across
    Inputs
  - `validate_multiomic_inputs()` : Validate Multi-Omic Input Contract
  - `classic_bootstrap_indices()` : Classic Bootstrap Sampler Indices
  - `group_bootstrap_indices()` : Group-Aware Bootstrap Sampler Indices

## Accessors

<!-- end list -->

  - `get_support()` : Get the Feature Selection Mask from a Fitted STABL
    Object
  - `get_feature_names_out()` : Get the Names of Selected Features from
    a Fitted STABL Object
  - `transform_stabl()` : Transform New Data to the Selected STABL
    Feature Set
  - `get_stabl_scores()` : Get the Full Stability Score Matrix from a
    Fitted STABL Object
  - `get_importances()` : Get Per-Feature Importance Scores (Maximum
    Stability Score)
  - `get_cooperative_features()` : Get Cooperative-Fusion Selected
    Features
  - `get_cooperative_diagnostics()` : Get Cooperative-Fusion Tuning
    Diagnostics

## Multi-Omic Workflows

<!-- end list -->

  - `stabl_multiomic_train_validate()` `print(<stabl_multiomic_fit>)` :
    Multi-Omic STABL Train/Validation Workflow
  - `stabl_multiomic_cv()` `print(<stabl_multiomic_cv>)` : Multi-Omic
    STABL Cross-Validation Workflow
  - `stabl_multiomic_nested_cv()` `print(<stabl_multiomic_nested_cv>)` :
    Multi-Omic STABL Nested Cross-Validation
  - `stacked_multi_omic()` : Stacked Generalization Over Per-Omic
    Predictions
  - `load_ool_data()` : Load the Onset of Labor example dataset

## Visualization

<!-- end list -->

  - `plot_stabl_path()` : Plot the STABL Stability Path
  - `plot_fdr_graph()` : Plot the FDP+ FDR Estimate Curve
  - `plot_roc()` : Plot a ROC Curve
  - `plot_prc()` : Plot a Precision-Recall Curve
  - `boxplot_features()` : Boxplots of Selected Features Grouped by
    Outcome
  - `scatterplot_features()` : Scatterplots of Selected Features Against
    a Continuous Outcome

## Export

<!-- end list -->

  - `export_stabl_to_csv()` : Export STABL Stability Scores to CSV
  - `save_stabl_results()` : Save All STABL Results to Disk

## Selection Similarity Metrics

<!-- end list -->

  - `jaccard_similarity()` : Jaccard Similarity Between Two Feature Sets
  - `jaccard_matrix()` : Pairwise Jaccard Matrix from a List of Feature
    Sets
  - `adjusted_similarity()` : Adjusted Similarity Between Two Feature
    Sets
  - `adjusted_similarity_values()` : Upper-Triangle Adjusted Similarity
    Values
  - `adjusted_similarity_measure()` : Summary Statistic of Adjusted
    Similarity Values
  - `pearson_similarity()` : Pearson-Corrected Similarity Between Two
    Feature Sets
  - `pearson_similarity_values()` : Upper-Triangle Pearson Similarity
    Values
  - `pearson_similarity_measure()` : Summary Statistic of Pearson
    Similarity Values
  - `fdr_similarity()` : FDR Between Two Feature Sets
  - `tpr_similarity()` : TPR Between Two Feature Sets
  - `fscore_similarity()` : F-Score Between Two Feature Sets
