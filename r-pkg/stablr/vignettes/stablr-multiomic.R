## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment  = "#>",
  fig.width  = 6,
  fig.height = 4
)
set.seed(42)

## ----load---------------------------------------------------------------------
library(stablr)

## ----load-data----------------------------------------------------------------
ool_train <- load_ool_data(split = "train")
ool_valid <- load_ool_data(split = "valid")

# Training set dimensions
lapply(ool_train$x_list, dim)
length(ool_train$y)

# Validation set dimensions
lapply(ool_valid$x_list, dim)

## ----data-summary-------------------------------------------------------------
# Outcome distribution (DOS = days before onset of labor)
summary(ool_train$y)

## ----lambda-cytof-------------------------------------------------------------
lambda_cytof <- auto_lambda_grid(
  ool_train$x_list$cytof, ool_train$y,
  family = "gaussian", n_lambda = 20
)

## ----fit-cytof----------------------------------------------------------------
fit_cytof <- stabl_fit(
  x               = ool_train$x_list$cytof,
  y               = ool_train$y,
  lambda_grid     = lambda_cytof,
  family          = "gaussian",
  n_bootstraps    = 150L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_cytof

## ----fit-proteomics-----------------------------------------------------------
lambda_prot <- auto_lambda_grid(
  ool_train$x_list$proteomics, ool_train$y,
  family = "gaussian", n_lambda = 20
)

fit_prot <- stabl_fit(
  x               = ool_train$x_list$proteomics,
  y               = ool_train$y,
  lambda_grid     = lambda_prot,
  family          = "gaussian",
  n_bootstraps    = 150L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_prot

## ----per-omic-support---------------------------------------------------------
cat("CyTOF selected features:
")
print(get_support(fit_cytof))

cat("
Proteomics selected features:
")
print(get_support(fit_prot))

## ----plot-per-omic, fig.alt = "Stability paths for CyTOF and Proteomics"------
plot_stabl_path(fit_cytof,     title = "CyTOF - stability path")
plot_stabl_path(fit_prot,      title = "Proteomics - stability path")

## ----lambda-grid--------------------------------------------------------------
# Build per-omic lambda grids
lambda_list <- list(
  cytof      = auto_lambda_grid(ool_train$x_list$cytof,
                                ool_train$y, family = "gaussian", n_lambda = 20),
  proteomics = auto_lambda_grid(ool_train$x_list$proteomics,
                                ool_train$y, family = "gaussian", n_lambda = 20)
)

## ----multiomic-fit------------------------------------------------------------
multi_fit <- stabl_multiomic_train_validate(
  x_train_list    = ool_train$x_list,
  y_train         = ool_train$y,
  lambda_grid     = lambda_list,
  x_valid_list    = ool_valid$x_list,
  y_valid         = ool_valid$y,
  family          = "gaussian",
  n_bootstraps    = 150L,
  artificial_type = "random_permutation",
  early_fusion    = TRUE,
  late_fusion     = TRUE,
  n_iter_lf       = 1000L,
  random_state    = 42L
)

multi_fit

## ----per-omic-results---------------------------------------------------------
# Per-omic selected features from the joint pipeline
cat("CyTOF (from multi-omic pipeline):
")
print(get_support(multi_fit$fits$cytof))

cat("
Proteomics (from multi-omic pipeline):
")
print(get_support(multi_fit$fits$proteomics))

## ----early-fusion-results-----------------------------------------------------
# Early fusion: joint selection across all omics simultaneously
if (!is.null(multi_fit$early_fusion)) {
  cat("Early fusion selected features:\n")
  print(get_support(multi_fit$early_fusion$fit))
}

## ----late-fusion-results------------------------------------------------------
# Late fusion: optimal linear combination of per-omic predictions
if (!is.null(multi_fit$late_fusion)) {
  cat("Late fusion validation predictions (first 6):\n")
  print(head(multi_fit$late_fusion$valid_predictions))
}

## ----stability-paths, fig.alt = "CyTOF stability path from multi-omic fit"----
plot_stabl_path(multi_fit$fits$cytof,
                title = "CyTOF (multi-omic pipeline)")
plot_stabl_path(multi_fit$fits$proteomics,
                title = "Proteomics (multi-omic pipeline)")

## ----export-------------------------------------------------------------------
out_dir <- file.path(tempdir(), "stablr_ool_cytof")

save_stabl_results(
  object    = multi_fit$fits$cytof,
  path      = out_dir,
  x         = ool_train$x_list$cytof,
  y         = ool_train$y,
  task_type = "regression",
  override  = TRUE
)

list.files(out_dir, recursive = TRUE)

