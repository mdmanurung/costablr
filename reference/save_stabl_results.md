# Save All STABL Results to Disk

Writes a complete set of STABL result artefacts — stability scores, the
list of selected features, the FDR diagnostic graph, the stability path
plot, and per-feature distribution plots — into a single output
directory. This is the recommended way to persist and share results from
a single `stabl_fit()` call.

## Usage

``` r
save_stabl_results(
  object,
  path,
  x,
  y,
  figure_fmt = "pdf",
  new_hard_threshold = NULL,
  task_type = "binary",
  override = FALSE
)
```

## Arguments

  - object:
    
    A fitted `"stabl_fit"` object returned by `stabl_fit()`.

  - path:
    
    Character string; path to the output directory. Created recursively
    if it does not already exist. Raises an error if the directory
    exists and `override = FALSE`.

  - x:
    
    Numeric matrix of predictors used to fit `object`. Required for
    per-feature distribution plots; must contain at least the selected
    feature columns.

  - y:
    
    Outcome vector, factor, or `survival::Surv` object used to fit
    `object`. Required for per-feature distribution plots.

  - figure\_fmt:
    
    Character; graphics device extension used when saving plots. Common
    choices: `"pdf"` (default, publication quality), `"png"`, `"svg"`.

  - new\_hard\_threshold:
    
    Numeric in `(0, 1]` or `NULL`. When supplied, overrides the stored
    threshold for support extraction and stability-path plotting.

  - task\_type:
    
    Character; one of `"binary"` (default), `"multiclass"`, or
    `"regression"`. Determines which per-feature plot is generated:
    grouped boxplots for classification, LOESS scatter for regression.

  - override:
    
    Logical; if `TRUE`, an existing directory with the same path is
    accepted and its contents may be overwritten. Default `FALSE`.

## Value

Invisibly returns `path` as a normalised absolute string.

## Details

The function orchestrates several lower-level helpers:
`export_stabl_to_csv()` for tabular data, `plot_fdr_graph()` and
`plot_stabl_path()` for diagnostic plots, and `boxplot_features()` or
`scatterplot_features()` for per-feature distribution visualisations.
All graphics are saved using `ggplot2::ggsave()` in the format specified
by `figure_fmt`.

## See also

`export_stabl_to_csv()` for the CSV-only variant, `plot_stabl_path()`,
`plot_fdr_graph()`

## Examples

``` r
# \donttest{
if (requireNamespace("ggplot2", quietly = TRUE)) {
  set.seed(1L)
  x <- matrix(rnorm(40 * 6), 40, 6,
               dimnames = list(paste0("s", 1:40), paste0("f", 1:6)))
  y <- setNames(rnorm(40), rownames(x))
  fit <- stabl_fit(x, y,
                   lambda_grid  = data.frame(lambda = c(0.3, 0.1, 0.05)),
                   n_bootstraps = 6L, hard_threshold = 0.3, random_state = 1L)
  out_dir <- file.path(tempdir(), "stabl_results")
  save_stabl_results(fit, out_dir, x = x, y = y,
                     task_type = "regression", figure_fmt = "png")
  list.files(out_dir)
}
# }
```
