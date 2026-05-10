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
  fdr_threshold_range = seq(0, 1, by = 0.01)
)
```

## Arguments

- stabl_scores:

  Numeric matrix (features \\\times\\ lambdas) of stability scores for
  the real features.

- stabl_scores_artificial:

  Numeric matrix (artificial features \\\times\\ lambdas) of stability
  scores for the injected noise features.

- artificial_proportion:

  Positive numeric scalar; the fraction of artificial features relative
  to real features (used as \\\pi\\).

- fdr_threshold_range:

  Numeric vector of threshold values to sweep. Default:
  `seq(0, 1, by = 0.01)`.

## Value

Named list:

- FDRs:

  Numeric vector of FDP+ estimates, one per threshold.

- min_fdr:

  Minimum FDP+ achieved across the threshold range.

- fdr_min_threshold:

  Threshold value achieving `min_fdr`, capped at 1.

- fdrs_table:

  Numeric matrix (lambdas \\\times\\ thresholds) of per-lambda FDP+
  values.

## Details

The FDP+ at threshold \\\tau\\ is estimated as:
\$\$\widehat{\text{FDP}}(\tau) = \frac{(1/\pi) \cdot \|\\j :
\hat{q}\_j^{\text{art}} \> \tau\\\| + 1} {\max(1,\\ \|\\j : \hat{q}\_j
\> \tau\\\|)}\$\$ where \\\pi\\ is `artificial_proportion`,
\\\hat{q}\_j\\ are the maximum-over-lambda stability scores for real
feature \\j\\, and \\\hat{q}\_j^{\text{art}}\\ are the scores for
artificial feature \\j\\.
