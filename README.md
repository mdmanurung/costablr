# costablr: Sparse and Reliable Biomarker Discovery in R

`costablr` is an R implementation of STABL for sparse, stable biomarker
selection in high-dimensional clinical and omic data. It ports the
parity-critical STABL semantics from the Python implementation while exposing
R-native S3 objects, `glmnet`-ecosystem learners, object-consuming multi-omic
workflows, visualization helpers, and CSV/disk export utilities.

The package has no Python or tidymodels runtime dependency.

## Feature Summary

- Core single-matrix STABL selector: `stabl_fit()`
- End-to-end selector plus unpenalized final refit: `stabl_refit()`
- FDP+ thresholding with random-permutation, Gaussian model-X knockoff, or
  MVR knockoff artificial features
- Lasso, elastic net, adaptive lasso, and optional sparse group lasso learners
- Gaussian, binomial, multinomial, and Cox STABL selector paths where the
  backend supports the family; `stabl_refit()` also supports Poisson final
  refits
- Classic and group-aware bootstrap sampling with reproducible seeds
- Optional bootstrap stratification and `future`/`furrr` bootstrap parallelism
- Preferred STABL-selected multi-omic API:
  `stabl_per_omic()` followed by `stabl_late_fusion()`,
  `stabl_multiomics()`, or `stabl_cooperative()`
- Train/validation, outer-CV, and nested-CV multi-omic workflows
- Early Fusion, canonical Late Fusion, STABL-Selected Late Fusion,
  Multi-Omic STABL, and optional Cooperative Fusion wrapper branches
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
- `nnet`: multinomial final refit in `stabl_refit()`
- `survival`: Cox final refit in `stabl_refit()`
- `multiview`: cooperative multi-omic fusion
- `mixOmics`: TCGA vignette dataset

The MVR knockoff solver uses compiled RcppArmadillo code through the package
build, not a Python runtime.

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
Use `stabl_refit()` when you also want the final unpenalized model on the
selected features:

```r
refit <- stabl_refit(
  x = x,
  y = y,
  lambda_grid = lambda_grid,
  family = "gaussian",
  n_bootstraps = 50L,
  artificial_type = "random_permutation",
  random_state = 42L
)

predict(refit, newdata = x)
```

Important arguments:

- `lambda_grid`: a data frame with a `lambda` column, or `"auto"`; elastic-net
  grids may also include an `alpha` column
- `base_learner`: `"lasso"`, `"elastic_net"`, `"adaptive_lasso"`, or
  `"sparse_group_lasso"`
- `family`: documented selector paths are `"gaussian"`, `"binomial"`,
  `"multinomial"`, and `"cox"`; `stabl_refit()` also supports a Poisson final
  refit path
- `artificial_type`: `"random_permutation"`, `"modelx_knockoff"`,
  `"mvr_knockoff"`, or `NULL`
- `groups`: optional named group vector for grouped bootstrap sampling
- `stratify_bootstrap` / `bootstrap_strata`: optional categorical bootstrap
  stratification
- `bootstrap_threshold`: per-bootstrap coefficient cutoff; default `1e-5`
- `workers`: bootstrap-level parallel workers when optional parallel packages
  are installed
- `random_state`: top-level seed for reproducible artificial features,
  bootstrap indices, and learner calls

### Multi-Omic Workflows

For STABL-selected multi-omic workflows, prefer the explicit object-consuming
API. It runs per-omic STABL selection once, then lets downstream methods
consume the resulting artifact:

```r
per_omic <- stabl_per_omic(
  x_train_list = x_train_list,
  y_train = y_train,
  lambda_grid = lambda_grid,
  x_valid_list = x_valid_list,
  y_valid = y_valid,
  family = "gaussian",
  n_bootstraps = 100L,
  random_state = 42L
)

selected_late <- stabl_late_fusion(per_omic)
multiomics <- stabl_multiomics(per_omic)
cooperative <- stabl_cooperative(per_omic)
```

`stabl_per_omic()` runs independent STABL selection per Omic View and returns a
reusable selection artifact for a fixed train/validation analysis.
`stabl_late_fusion(per_omic)` stacks predictions from the per-omic final
refits, `stabl_multiomics(per_omic)` concatenates the STABL-selected biomarkers
into one final-layer refit, and `stabl_cooperative(per_omic)` fits the optional
cooperative final layer on selected features. Build a fresh `stabl_per_omic()`
object inside each outer CV training fold when estimating generalization.

The older orchestration wrappers remain available. Use
`stabl_multiomic_train_validate()` for named omic lists with optional
validation data, and `stabl_multiomic_cv()` when no fixed validation split is
available. Their optional branches are additive: `early_fusion`,
canonical prediction-level `late_fusion`, `stabl_selected_late_fusion`,
`multiomic_stabl`, and `cooperative_fusion`.

Use `stabl_multiomic_nested_cv()` for the explicit nested-CV candidate workflow
used by the TCGA benchmark scaffold. It has its own candidate abstraction rather
than forwarding the object-consuming API directly.

Cooperative-fusion results can be inspected with:

```r
get_cooperative_features(multi_fit)
get_cooperative_diagnostics(multi_fit)
```

Cooperative fusion requires the optional `multiview` package. Validation-based
cooperative tuning is not supported for Cox models.

## API Reference

Core fitting:

- `stabl_fit()`, `stabl_refit()`, `auto_lambda_grid()`
- `make_glmnet_adapter()`, `make_adaptive_lasso_adapter()`, `make_sgl_adapter()`

Input validation and bootstrapping:

- `validate_sample_alignment()`, `validate_multiomic_inputs()`
- `classic_bootstrap_indices()`, `group_bootstrap_indices()`

Artificial features and FDP+:

- `make_artificial_features()`, `compute_fdp_plus()`

Accessors:

- `get_support()`, `get_feature_names_out()`, `get_stabl_scores()`,
  `get_importances()`
- `get_cooperative_features()`, `get_cooperative_diagnostics()`

Multi-omic workflows:

- `stabl_per_omic()`, `stabl_late_fusion()`, `stabl_multiomics()`,
  `stabl_cooperative()`
- `stabl_multiomic_train_validate()`, `stabl_multiomic_cv()`,
  `stabl_multiomic_nested_cv()`
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
