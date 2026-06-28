# Plot the FDP+ FDR Estimate Curve

Displays how the estimated False Discovery Proportion (FDP+) changes
across the full range of candidate stability thresholds, and marks the
threshold that achieves the minimum FDR estimate.

## Usage

``` r
plot_fdr_graph(object, title = "FDR Estimate", fdr_target = 0.05)
```

## Arguments

  - object:
    
    A fitted `"stabl_fit"` object returned by `stabl_fit()`.

  - title:
    
    Character scalar; plot title. Default `"FDR Estimate"`.

  - fdr\_target:
    
    Numeric scalar or `NULL`; FDP target shown as a horizontal dashed
    line. Use `NULL` to omit the target line. Default `0.05`.

## Value

A `ggplot` object. The curve shows the FDP+ estimate at each candidate
threshold; a vertical dashed line marks the optimal threshold stored in
`object$fdr_min_threshold_`; a horizontal dashed line marks `fdr_target`
when supplied.

## Details

This diagnostic is essential for understanding why a particular
stability threshold was chosen during fitting. A well-calibrated run
will show a clear "valley" — a region where the FDP+ is minimised —
confirming that the artificial-feature injection produced a meaningful
separation between real signal and noise. Flat or monotone curves
indicate that the regularisation grid may need adjustment or that the
signal is very weak.

Requires that `object` was fitted with `artificial_type` set (not
`NULL`).

## See also

`stabl_fit()`, `plot_stabl_path()`

## Examples

``` r
# \donttest{
if (requireNamespace("ggplot2", quietly = TRUE)) {
  set.seed(1L)
  x <- matrix(rnorm(60 * 8), 60, 8,
               dimnames = list(paste0("s", 1:60), paste0("f", 1:8)))
  y <- setNames(rnorm(60), rownames(x))
  fit <- stabl_fit(x, y,
                   lambda_grid        = data.frame(lambda = c(0.3, 0.1, 0.05)),
                   n_bootstraps       = 6L,
                   hard_threshold     = NULL,
                   artificial_type    = "random_permutation",
                   random_state       = 1L)
  plot_fdr_graph(fit)
}
# }
```
