## -----------------------------------------------------------------------------
knitr::opts_chunk$set(
  collapse  = TRUE,
  comment   = "#>",
  fig.width  = 6,
  fig.height = 4,
  cache      = FALSE,
  cache.path = "stablr-tcga-cache/"
)

## -----------------------------------------------------------------------------
if (!requireNamespace("mixOmics", quietly = TRUE)) {
  stop(
    "This vignette requires mixOmics (Bioconductor). ",
    "Install with: BiocManager::install('mixOmics')"
  )
}
library(stablr)
library(mixOmics)

## -----------------------------------------------------------------------------
data(breast.TCGA)

X_train_mrna  <- breast.TCGA$data.train$mrna
X_train_mirna <- breast.TCGA$data.train$mirna
X_test_mrna   <- breast.TCGA$data.test$mrna
X_test_mirna  <- breast.TCGA$data.test$mirna

cat("Training mRNA:  ", nrow(X_train_mrna),  "x", ncol(X_train_mrna),  "\n")
cat("Training miRNA: ", nrow(X_train_mirna), "x", ncol(X_train_mirna), "\n")
cat("Test mRNA:      ", nrow(X_test_mrna),   "x", ncol(X_test_mrna),   "\n")
cat("Test miRNA:     ", nrow(X_test_mirna),  "x", ncol(X_test_mirna),  "\n")

## -----------------------------------------------------------------------------
subtype_train <- breast.TCGA$data.train$subtype
subtype_test  <- breast.TCGA$data.test$subtype

y_train <- as.integer(subtype_train == "Basal")
y_test  <- as.integer(subtype_test  == "Basal")

names(y_train) <- rownames(X_train_mrna)
names(y_test)  <- rownames(X_test_mrna)

cat("Training: ", sum(y_train), "Basal /", sum(y_train == 0), "non-Basal\n")
cat("Test:     ", sum(y_test),  "Basal /", sum(y_test == 0),  "non-Basal\n")

## -----------------------------------------------------------------------------
lambda_mrna <- auto_lambda_grid(
  X_train_mrna, y_train,
  family   = "binomial",
  n_lambda = 20
)

## -----------------------------------------------------------------------------
fit_mrna <- stabl_fit(
  x               = X_train_mrna,
  y               = y_train,
  lambda_grid     = lambda_mrna,
  family          = "binomial",
  n_bootstraps    = 50L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_mrna

## -----------------------------------------------------------------------------
lambda_mirna <- auto_lambda_grid(
  X_train_mirna, y_train,
  family   = "binomial",
  n_lambda = 20
)

## -----------------------------------------------------------------------------
fit_mirna <- stabl_fit(
  x               = X_train_mirna,
  y               = y_train,
  lambda_grid     = lambda_mirna,
  family          = "binomial",
  n_bootstraps    = 50L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_mirna

## -----------------------------------------------------------------------------
cat("mRNA selected features:\n")
print(get_support(fit_mrna))

cat("\nmiRNA selected features:\n")
print(get_support(fit_mirna))

## -----------------------------------------------------------------------------
print(plot_stabl_path(fit_mrna,  title = "mRNA - stability path"))
print(plot_stabl_path(fit_mirna, title = "miRNA - stability path"))

## -----------------------------------------------------------------------------
lambda_list <- list(
  mrna  = lambda_mrna,
  mirna = lambda_mirna
)

## -----------------------------------------------------------------------------
multi_fit <- stabl_multiomic_train_validate(
  x_train_list    = list(mrna = X_train_mrna,  mirna = X_train_mirna),
  x_valid_list    = list(mrna = X_test_mrna,   mirna = X_test_mirna),
  y_train         = y_train,
  y_valid         = y_test,
  lambda_grid     = lambda_list,
  family          = "binomial",
  n_bootstraps    = 50L,
  artificial_type = "random_permutation",
  random_state    = 42L,
  early_fusion    = TRUE,
  late_fusion     = TRUE
)
multi_fit

## -----------------------------------------------------------------------------
cat("mRNA (integrated):\n")
print(get_support(multi_fit$fits$mrna))

cat("\nmiRNA (integrated):\n")
print(get_support(multi_fit$fits$mirna))

## -----------------------------------------------------------------------------
cat("Early fusion selected features:\n")
print(get_support(multi_fit$early_fusion$fit))

## -----------------------------------------------------------------------------
cat("Late fusion omic weights:\n")
print(multi_fit$late_fusion$weights)

## -----------------------------------------------------------------------------
print(plot_stabl_path(multi_fit$fits$mrna,  title = "Integrated - mRNA"))
print(plot_stabl_path(multi_fit$fits$mirna, title = "Integrated - miRNA"))

## -----------------------------------------------------------------------------
lf_preds <- multi_fit$late_fusion$valid_predictions

plot_roc(y_true = y_test, y_preds = lf_preds,
         title = "Late fusion - ROC curve (test set)")
plot_prc(y_true = y_test, y_preds = lf_preds,
         title = "Late fusion - PRC curve (test set)")

## -----------------------------------------------------------------------------
pred_class <- as.integer(lf_preds >= 0.5)
conf_mat   <- table(Predicted = pred_class, Actual = y_test)
print(conf_mat)

sensitivity <- conf_mat["1", "1"] / sum(conf_mat[, "1"])
specificity <- conf_mat["0", "0"] / sum(conf_mat[, "0"])
ber <- 1 - (sensitivity + specificity) / 2

cat(sprintf("\nSensitivity (Basal):     %.3f\n", sensitivity))
cat(sprintf("Specificity (non-Basal): %.3f\n", specificity))
cat(sprintf("Balanced Error Rate:     %.3f\n", ber))

## -----------------------------------------------------------------------------
mrna_feats <- names(which(get_support(multi_fit$fits$mrna)))
if (length(mrna_feats) > 0) {
  boxplot_features(
    features = mrna_feats,
    x        = X_train_mrna,
    y        = y_train,
    title    = "Top mRNA features - training set",
    ncol     = min(3L, length(mrna_feats))
  )
}

## -----------------------------------------------------------------------------
export_stabl_to_csv(multi_fit$fits$mrna,  path = "tcga_results/mrna")
export_stabl_to_csv(multi_fit$fits$mirna, path = "tcga_results/mirna")

## -----------------------------------------------------------------------------
sessionInfo()

