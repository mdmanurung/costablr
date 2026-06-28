# Compute FDP+ (False Discovery Proportion Upper Bound)

Sweeps a grid of stability-score thresholds and computes the FDP+
estimate at each one, then identifies the threshold that minimises it.
This is a direct port of `Stabl._compute_FDPplus()` from the Python
STABL library.

## Usage

``` r
compute_fdp_plus(
  stabl_scores,
  stabl_scores_artificial,
  artificial_proportion,
  fdr_threshold_range = seq(0, 0.99, by = 0.01)
)
```

## Arguments

  - stabl\_scores:
    
    Numeric matrix (features \\(\\times\\) lambdas) of stability scores
    for the real features.

  - stabl\_scores\_artificial:
    
    Numeric matrix (artificial features \\(\\times\\) lambdas) of
    stability scores for the injected noise features.

  - artificial\_proportion:
    
    Positive numeric scalar; the fraction of artificial features
    relative to real features (used as \\(\\pi\\)).

  - fdr\_threshold\_range:
    
    Numeric vector of threshold values to sweep. Default: `seq(0, 0.99,
    by = 0.01)`, matching Python STABL's `np.arange(0., 1., .01)`.

## Value

Named list:

  - FDRs:
    
    Numeric vector of FDP+ estimates, one per threshold.

  - min\_fdr:
    
    Minimum FDP+ achieved across the threshold range.

  - fdr\_min\_threshold:
    
    Threshold value achieving `min_fdr`, capped at 1.

  - fdrs\_table:
    
    Numeric matrix (lambdas \\(\\times\\) thresholds) of per-lambda FDP+
    values.

## Details

The FDP+ at threshold \\(\\tau\\) is estimated as:
$$\\widehat{\\text{FDP}}(\\tau) = \\frac{(1/\\pi) \\cdot |\\{j :
\\hat{q}\_j^{\\text{art}} \> \\tau\\}| + 1} {\\max(1,\\, |\\{j :
\\hat{q}\_j \> \\tau\\}|)}$$ where \\(\\pi\\) is
`artificial_proportion`, \\(\\hat{q}\_j\\) are the maximum-over-lambda
stability scores for real feature \\(j\\), and
\\(\\hat{q}\_j^{\\text{art}}\\) are the scores for artificial feature
\\(j\\).

## See also

`stabl_fit()` which calls this internally when artificial features are
used, `plot_fdr_graph()` to visualise the FDP+ curve.

## Examples

``` r
# Small synthetic stability-score matrices (3 real + 3 artificial features,
# 2 lambda values)
scores_real <- matrix(c(0.8, 0.6, 0.1, 0.9, 0.5, 0.05), nrow = 3)
scores_art  <- matrix(c(0.1, 0.2, 0.3, 0.15, 0.25, 0.1), nrow = 3)
result <- compute_fdp_plus(scores_real, scores_art,
                           artificial_proportion = 1.0)
result$min_fdr           # minimum FDP+ estimate
result$fdr_min_threshold # threshold that achieves it
```
