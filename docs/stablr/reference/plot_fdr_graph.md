# Plot the FDP+ FDR Estimate Curve

Plots the estimated FDR at each stability threshold, with a vertical
dashed line marking the optimal threshold (the one minimising the FDR
estimate). Requires that `object` was fitted with `artificial_type` set
(not `NULL`).

## Usage

``` r
plot_fdr_graph(object, title = "FDR Estimate")
```

## Arguments

- object:

  A fitted `"stabl_fit"` object returned by
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- title:

  Character scalar; plot title. Default `"FDR Estimate"`.

## Value

A `ggplot` object. The curve shows the FDP+ estimate at each candidate
threshold; a vertical dashed line marks the optimal threshold stored in
`object$fdr_min_threshold_`.

## See also

[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md),
[`plot_stabl_path()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_stabl_path.md)
