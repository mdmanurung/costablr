## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment  = "#>",
  fig.width  = 6,
  fig.height = 4
)
set.seed(42)

## ----install, eval = FALSE----------------------------------------------------
# # From the repository root after cloning:
# devtools::install("r-pkg/stablr")

## ----load---------------------------------------------------------------------
library(stablr)

## ----sim-binary---------------------------------------------------------------
n <- 150; p <- 30; n_signal <- 5
X_bin <- matrix(rnorm(n * p), nrow = n,
                dimnames = list(paste0("s", seq_len(n)),
                                paste0("F", seq_len(p))))

# True signal in the first 5 features
beta_bin       <- c(rep(1.5, n_signal), rep(0, p - n_signal))
log_odds       <- X_bin %*% beta_bin
y_bin          <- rbinom(n, size = 1, prob = plogis(log_odds))
names(y_bin)   <- rownames(X_bin)
table(y_bin)

## ----fit-binary---------------------------------------------------------------
lambda_bin <- auto_lambda_grid(X_bin, y_bin, family = "binomial", n_lambda = 20)

fit_bin <- stabl_fit(
  x               = X_bin,
  y               = y_bin,
  lambda_grid     = lambda_bin,
  family          = "binomial",
  n_bootstraps    = 100L,
  artificial_type = "random_permutation",
  random_state    = 42L
)

fit_bin

## ----results-binary-----------------------------------------------------------
# Features selected at the STABL threshold
get_support(fit_bin)

# Stability scores for all features (sorted descending)
head(get_importances(fit_bin), 10)

## ----plot-binary, fig.alt = "Stability path for binary classification"--------
plot_stabl_path(fit_bin, title = "Binary classification - stability path")

## ----fdr-binary, fig.alt = "FDR estimate graph for binary classification"-----
plot_fdr_graph(fit_bin, title = "Binary classification - FDR estimate")

## ----sim-reg------------------------------------------------------------------
X_reg <- matrix(rnorm(n * p), nrow = n,
                dimnames = list(paste0("s", seq_len(n)),
                                paste0("F", seq_len(p))))
beta_reg     <- c(rep(2, n_signal), rep(0, p - n_signal))
y_reg        <- X_reg %*% beta_reg + rnorm(n, sd = 1)
names(y_reg) <- rownames(X_reg)

## ----fit-reg------------------------------------------------------------------
lambda_reg <- auto_lambda_grid(X_reg, y_reg, family = "gaussian", n_lambda = 20)

fit_reg <- stabl_fit(
  x               = X_reg,
  y               = y_reg,
  lambda_grid     = lambda_reg,
  family          = "gaussian",
  n_bootstraps    = 100L,
  artificial_type = "random_permutation",
  random_state    = 42L
)

fit_reg

## ----results-reg--------------------------------------------------------------
get_support(fit_reg)
head(get_importances(fit_reg), 10)

## ----plot-reg, fig.alt = "Stability path for regression"----------------------
plot_stabl_path(fit_reg, title = "Regression - stability path")

## ----adaptive-lasso-----------------------------------------------------------
lambda_ada <- auto_lambda_grid(X_bin, y_bin, family = "binomial", n_lambda = 20)

fit_ada <- stabl_fit(
  x               = X_bin,
  y               = y_bin,
  lambda_grid     = lambda_ada,
  base_learner    = "adaptive_lasso",
  family          = "binomial",
  n_bootstraps    = 100L,
  artificial_type = "random_permutation",
  random_state    = 42L
)

get_support(fit_ada)

## ----elastic-net--------------------------------------------------------------
lambda_en <- auto_lambda_grid(
  X_bin, y_bin,
  family = "binomial", n_lambda = 10,
  l1_ratio = c(0.5, 0.9)
)

fit_en <- stabl_fit(
  x               = X_bin,
  y               = y_bin,
  lambda_grid     = lambda_en,
  base_learner    = "elastic_net",
  family          = "binomial",
  n_bootstraps    = 100L,
  artificial_type = "random_permutation",
  random_state    = 42L
)

get_support(fit_en)

