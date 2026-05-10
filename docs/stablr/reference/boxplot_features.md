# Boxplots of Selected Features Grouped by Outcome

Produces a ggplot2 figure with one facet per selected feature, showing
the distribution of each feature's values stratified by the outcome
class. Intended for binary and multiclass classification tasks after
STABL feature selection; complements
[`scatterplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/scatterplot_features.md)
for regression tasks.

## Usage

``` r
boxplot_features(features, x, y, title = "Selected Features", ncol = 3L)
```

## Arguments

- features:

  Character vector of feature names to plot. Features not present as
  columns in `x` are silently skipped.

- x:

  Numeric matrix or data frame of predictors. Column names must include
  all elements of `features`.

- y:

  Factor, character, or integer vector of class labels. Must have the
  same number of elements as `nrow(x)`.

- title:

  Character scalar; plot title. Default `"Selected Features"`.

- ncol:

  Positive integer; number of facet columns in the grid. Default 3.

## Value

A `ggplot` object with one facet panel per feature.

## See also

[`scatterplot_features()`](https://gregbellan.github.io/Stabl/stablr/reference/scatterplot_features.md)
for regression tasks,
[`save_stabl_results()`](https://gregbellan.github.io/Stabl/stablr/reference/save_stabl_results.md)
which calls this automatically.
