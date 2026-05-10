# Save All STABL Results to Disk

Writes a complete set of STABL result artefacts — stability scores, the
list of selected features, the FDR diagnostic graph, the stability path
plot, and per-feature distribution plots — into a single output
directory. This is the recommended way to persist and share results from
a single
[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
call.

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

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- path:

  Character string; path to the output directory. Created recursively if
  it does not already exist. Raises an error if the directory exists and
  `override = FALSE`.

- x:

  Numeric matrix of predictors used to fit `object`. Required for
  per-feature distribution plots; must contain at least the selected
  feature columns.

- y:

  Outcome vector, factor, or
  [`survival::Surv`](https://rdrr.io/pkg/survival/man/Surv.html) object
  used to fit `object`. Required for per-feature distribution plots.

- figure_fmt:

  Character; graphics device extension used when saving plots. Common
  choices: `"pdf"` (default, publication quality), `"png"`, `"svg"`.

- new_hard_threshold:

  Numeric in `(0, 1]` or `NULL`. When supplied, overrides the stored
  threshold for support extraction and stability-path plotting.

- task_type:

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
[`export_stabl_to_csv()`](https://gregbellan.github.io/Stabl/stablr/reference/export_stabl_to_csv.md)
for tabular data,
[`plot_fdr_graph()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_fdr_graph.md)
and
[`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md)
for diagnostic plots, and
[`boxplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/boxplot_features.md)
or
[`scatterplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/scatterplot_features.md)
for per-feature distribution visualisations. All graphics are saved
using
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html)
in the format specified by `figure_fmt`.

## See also

[`export_stabl_to_csv()`](https://gregbellan.github.io/Stabl/stablr/reference/export_stabl_to_csv.md)
for the CSV-only variant,
[`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md),
[`plot_fdr_graph()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_fdr_graph.md)
