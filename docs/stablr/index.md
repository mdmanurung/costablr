# stablr: Sparse and Reliable Biomarker Discovery in R

`stablr` is a pure-R implementation of STABL for sparse, stable
biomarker selection in high-dimensional clinical and omic data. It ports
the parity-critical STABL semantics from the Python implementation while
exposing R-native S3 objects, `glmnet`-ecosystem learners, multi-omic
workflows, visualization helpers, and CSV/disk export utilities.

The package has no Python or tidymodels runtime dependency.

## Feature Summary

- Core STABL selector:
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
- FDP+ thresholding with random-permutation or knockoff artificial
  features
- Lasso, elastic net, adaptive lasso, and optional sparse group lasso
  learners
- Gaussian, binomial, multinomial, and Cox outcome support where the
  backend supports the family
- Classic and group-aware bootstrap sampling with reproducible seeds
- Multi-omic train/validation and outer-CV workflows
- Early fusion, late fusion, and optional cooperative fusion
- S3 accessors, plotting helpers, export helpers, and reproducibility
  metrics

## Installation

From the repository root:

``` r
install.packages("devtools")
devtools::install_local("r-pkg/stablr")
```

Optional functionality uses optional packages:

- `ggplot2`: plotting helpers and saved result figures
- `knockoff`: `artificial_type = "knockoff"`
- `future`, `furrr`: parallel bootstrap execution
- `sparsegl`: `base_learner = "sparse_group_lasso"`
- `multiview`: cooperative multi-omic fusion
- `mixOmics`: TCGA vignette dataset

## Quick Start

``` r
library(stablr)

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

Use larger bootstrap counts and broader lambda grids for final analyses.
The quick-start vignette intentionally uses small settings to keep
package builds fast.

## Main Workflows

### Single-Omic STABL

Use
[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
for one feature matrix. Inputs are aligned by sample names, not
position, so `rownames(x)` must match the names or row names of `y`.

Important arguments:

- `lambda_grid`: a data frame with a `lambda` column, or `"auto"`
- `base_learner`: `"lasso"`, `"elastic_net"`, `"adaptive_lasso"`, or
  `"sparse_group_lasso"`
- `family`: `"gaussian"`, `"binomial"`, `"multinomial"`, or `"cox"`
- `artificial_type`: `"random_permutation"`, `"knockoff"`, or `NULL`
- `groups`: optional named group vector for grouped bootstrap sampling
- `random_state`: top-level seed for reproducible artificial features,
  bootstrap indices, and learner calls

### Multi-Omic Workflows

Use
[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
for named omic lists with optional validation data. Enable
`early_fusion`, `late_fusion`, and `cooperative_fusion` independently.
Use
[`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
when no fixed validation split is available.

Cooperative-fusion results can be inspected with:

``` r
get_cooperative_features(multi_fit)
get_cooperative_diagnostics(multi_fit)
```

Cooperative fusion requires the optional `multiview` package.
Validation-based cooperative tuning is not supported for Cox models.

## API Reference

Core fitting:

- [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md),
  [`auto_lambda_grid()`](https://gregbellan.github.io/Stabl/stablr/reference/auto_lambda_grid.md)
- [`make_glmnet_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_glmnet_adapter.md),
  [`make_adaptive_lasso_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_adaptive_lasso_adapter.md),
  [`make_sgl_adapter()`](https://gregbellan.github.io/Stabl/stablr/reference/make_sgl_adapter.md)

Input validation and bootstrapping:

- [`validate_sample_alignment()`](https://gregbellan.github.io/Stabl/stablr/reference/validate_sample_alignment.md),
  [`validate_multiomic_inputs()`](https://gregbellan.github.io/Stabl/stablr/reference/validate_multiomic_inputs.md)
- [`classic_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/classic_bootstrap_indices.md),
  [`group_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/group_bootstrap_indices.md)

Artificial features and FDP+:

- [`make_artificial_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_artificial_features.md),
  [`make_rp_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_rp_features.md),
  [`make_knockoff_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_knockoff_features.md),
  [`compute_fdp_plus()`](https://gregbellan.github.io/Stabl/stablr/reference/compute_fdp_plus.md)

Accessors:

- [`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md),
  [`get_feature_names_out()`](https://gregbellan.github.io/Stabl/stablr/reference/get_feature_names_out.md),
  [`get_stabl_scores()`](https://gregbellan.github.io/Stabl/stablr/reference/get_stabl_scores.md),
  [`get_importances()`](https://gregbellan.github.io/Stabl/stablr/reference/get_importances.md)
- [`get_cooperative_features()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_features.md),
  [`get_cooperative_diagnostics()`](https://gregbellan.github.io/Stabl/stablr/reference/get_cooperative_diagnostics.md)

Multi-omic workflows:

- [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md),
  [`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
- [`stacked_multi_omic()`](https://gregbellan.github.io/Stabl/stablr/reference/stacked_multi_omic.md),
  [`load_ool_data()`](https://gregbellan.github.io/Stabl/stablr/reference/load_ool_data.md)

Visualization and export:

- [`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md),
  [`plot_fdr_graph()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_fdr_graph.md),
  [`plot_roc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_roc.md),
  [`plot_prc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_prc.md)
- [`boxplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/boxplot_features.md),
  [`scatterplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/scatterplot_features.md)
- [`export_stabl_to_csv()`](https://gregbellan.github.io/Stabl/stablr/reference/export_stabl_to_csv.md),
  [`save_stabl_results()`](https://gregbellan.github.io/Stabl/stablr/reference/save_stabl_results.md)

Selection reproducibility metrics:

- [`jaccard_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/jaccard_similarity.md),
  [`jaccard_matrix()`](https://gregbellan.github.io/Stabl/stablr/reference/jaccard_matrix.md)
- [`adjusted_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity.md),
  [`adjusted_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_values.md),
  [`adjusted_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_measure.md)
- [`pearson_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity.md),
  [`pearson_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity_values.md),
  [`pearson_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity_measure.md)
- [`fdr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fdr_similarity.md),
  [`tpr_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/tpr_similarity.md),
  [`fscore_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/fscore_similarity.md)

## Vignettes

Canonical source vignettes live in `vignettes/`:

- `stablr-intro.Rmd`: quick simulated-data start
- `stablr-multiomic.Rmd`: real OOL multi-omic train/validation workflow
- `stablr-python-parity.Rmd`: Python-to-R workflow mapping
- `stablr-tcga.Rmd`: TCGA Breast Cancer multi-omic workflow
- `stablr-cooperative.Rmd`: cooperative fusion with optional `multiview`

The `doc/` directory is generated by `R CMD build` or
[`devtools::build_vignettes()`](https://devtools.r-lib.org/reference/build_vignettes.html)
and is ignored in this source tree; edit `vignettes/` as the canonical
source.

## Documentation Website

Build the pkgdown site from the repository root:

``` bash
conda run -n R4_51 Rscript -e "pkgdown::build_site('r-pkg/stablr', install = FALSE)"
```

The site reference index is configured in `_pkgdown.yml`.

## Citation

If you use STABL, cite:

Hédou, J., Marić, I., Bellan, G. et al. Discovery of sparse, reliable
omic biomarkers with Stabl. Nat Biotechnol (2024).
<https://doi.org/10.1038/s41587-023-02033-x>
