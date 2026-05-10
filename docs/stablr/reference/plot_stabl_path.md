# Plot the STABL Stability Path

Produces a ggplot2 line chart showing the stability score (frequency of
selection) of each feature across the regularisation path. Selected
features are highlighted in red; noise features are shown in dark grey.
When artificial features were used during fitting, their stability path
is overlaid as thin dotted grey lines. The FDP+-optimal (or hard)
threshold is shown as a dashed horizontal line.

## Usage

``` r
plot_stabl_path(
  object,
  new_hard_threshold = NULL,
  title = "STABL Stability Path"
)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object from
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- new_hard_threshold:

  Numeric in `(0, 1]` or `NULL`. When supplied, overrides the threshold
  stored in `object`.

- title:

  Character; plot title (default `"STABL Stability Path"`).

## Value

A `ggplot` object.

## Details

When the lambda grid contains an `alpha` column (elastic-net mixed-alpha
path), the plot is automatically faceted by `alpha`.
