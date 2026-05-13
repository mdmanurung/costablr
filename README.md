# costablr: Sparse and Reliable Biomarker Discovery in R

`costablr` is a pure-R implementation of STABL for sparse, stable biomarker
selection in high-dimensional clinical and omic data. It ports the
parity-critical STABL semantics from the Python implementation while exposing
R-native S3 objects, `glmnet`-ecosystem learners, multi-omic workflows,
visualization helpers, and CSV/disk export utilities.

The package has no Python or tidymodels runtime dependency.

## Feature Summary

- Core STABL selector: `stabl_fit()`
- FDP+ thresholding with random-permutation, Gaussian model-X knockoff, or
  MVR knockoff artificial features
- Lasso, elastic net, adaptive lasso, and optional sparse group lasso learners
- Gaussian, binomial, multinomial, and Cox outcome support where the backend
  supports the family
- Classic and group-aware bootstrap sampling with reproducible seeds
- Multi-omic train/validation and outer-CV workflows
- Early fusion, late fusion, and optional cooperative fusion
- S3 accessors, plotting helpers, export helpers, and reproducibility metrics

## Installation

From the repository root:

```r
install.packages("devtools")
devtools::install_local(".")
```

Optional functionality uses optional packages:

- `ggplot2`: plotting helpers and saved result figures
- `knockoff`: Gaussian model-X knockoffs for
  `artificial_type = "modelx_knockoff"`
- `future`, `furrr`: parallel bootstrap execution
- `sparsegl`: `base_learner = "sparse_group_lasso"`
- `multiview`: cooperative multi-omic fusion
- `mixOmics`: TCGA vignette dataset

## Quick Start

```r
library(costablr)

set.seed(42)
n <- 80
p <- 20
x <- matrix(
  rnorm(n * p),
  nrow = n,
  dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
)
y <- setNames(1.2 * x[, 1] - 0.8 * x[, 2] + rnorm(n), rownames(x))

lambda_grid <- auto_lambda_grid(x, y, family = "gaussian", n_lambda = 10)

fit <- stabl_fit(
  x = x,
  y = y,
  lambda_grid = lambda_grid,
  family = "gaussian",
  n_bootstraps = 50L,
  artificial_type = "random_permutation",
  random_state = 42L
)

get_feature_names_out(fit)
head(sort(get_importances(fit), decreasing = TRUE))
```

Use larger bootstrap counts and broader lambda grids for final analyses. The
quick-start vignette intentionally uses small settings to keep package builds
fast.

## Main Workflows

### Single-Omic STABL

Use `stabl_fit()` for one feature matrix. Inputs are aligned by sample names,
not position, so `rownames(x)` must match the names or row names of `y`.

Important arguments:

- `lambda_grid`: a data frame with a `lambda` column, or `"auto"`
- `base_learner`: `"lasso"`, `"elastic_net"`, `"adaptive_lasso"`, or
  `"sparse_group_lasso"`
- `family`: `"gaussian"`, `"binomial"`, `"multinomial"`, or `"cox"`
- `artificial_type`: `"random_permutation"`, `"modelx_knockoff"`,
  `"mvr_knockoff"`, or `NULL`
- `groups`: optional named group vector for grouped bootstrap sampling
- `random_state`: top-level seed for reproducible artificial features,
  bootstrap indices, and learner calls

### Multi-Omic Workflows

Use `stabl_multiomic_train_validate()` for named omic lists with optional
validation data. Enable `early_fusion`, `late_fusion`, and
`cooperative_fusion` independently. Use `stabl_multiomic_cv()` when no fixed
validation split is available.

Cooperative-fusion results can be inspected with:

```r
get_cooperative_features(multi_fit)
get_cooperative_diagnostics(multi_fit)
```

Cooperative fusion requires the optional `multiview` package. Validation-based
cooperative tuning is not supported for Cox models.

## API Reference

Core fitting:

- `stabl_fit()`, `auto_lambda_grid()`
- `make_glmnet_adapter()`, `make_adaptive_lasso_adapter()`, `make_sgl_adapter()`

Input validation and bootstrapping:

- `validate_sample_alignment()`, `validate_multiomic_inputs()`
- `classic_bootstrap_indices()`, `group_bootstrap_indices()`

Artificial features and FDP+:

- `make_artificial_features()`, `make_rp_features()`, `compute_fdp_plus()`

Accessors:

- `get_support()`, `get_feature_names_out()`, `get_stabl_scores()`,
  `get_importances()`
- `get_cooperative_features()`, `get_cooperative_diagnostics()`

Multi-omic workflows:

- `stabl_multiomic_train_validate()`, `stabl_multiomic_cv()`
- `stacked_multi_omic()`, `load_ool_data()`

Visualization and export:

- `plot_stabl_path()`, `plot_fdr_graph()`, `plot_roc()`, `plot_prc()`
- `boxplot_features()`, `scatterplot_features()`
- `export_stabl_to_csv()`, `save_stabl_results()`

Selection reproducibility metrics:

- `jaccard_similarity()`, `jaccard_matrix()`
- `adjusted_similarity()`, `adjusted_similarity_values()`,
  `adjusted_similarity_measure()`
- `pearson_similarity()`, `pearson_similarity_values()`,
  `pearson_similarity_measure()`
- `fdr_similarity()`, `tpr_similarity()`, `fscore_similarity()`

## Vignettes

Canonical source vignettes live in `vignettes/`:

- `costablr-intro.Rmd`: quick simulated-data start
- `costablr-multiomic.Rmd`: real OOL multi-omic train/validation workflow
- `costablr-python-parity.Rmd`: Python-to-R workflow mapping
- `costablr-tcga.Rmd`: TCGA Breast Cancer multi-omic workflow
- `costablr-cooperative.Rmd`: cooperative fusion with optional `multiview`

The `doc/` directory is generated by `R CMD build` or
`devtools::build_vignettes()` and is ignored in this source tree; edit
`vignettes/` as the canonical source.

## Documentation Website

Build the pkgdown site from the repository root:

```bash
conda run -n R4_51 Rscript -e "pkgdown::build_site('.', install = FALSE)"
```

The site reference index is configured in `_pkgdown.yml`.

## Citation

If you use STABL, cite:

Hédou, J., Marić, I., Bellan, G. et al. Discovery of sparse, reliable omic
biomarkers with Stabl. Nat Biotechnol (2024).
https://doi.org/10.1038/s41587-023-02033-x
