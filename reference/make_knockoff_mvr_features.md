# Make Model-X MVR Knockoff Artificial Features

Generates **model-X MVR (minimum-variance-reconstructability)** knockoff
features. The S-matrix is solved via `solve_mvr()` (a pure-R coordinate-
descent port of `knockpy.mrc._solve_mvr_ungrouped`), then the knockoff
sample is drawn with `knockoff::create.gaussian(..., diag_s = S)`. This
is a novel feature exclusive to `stablr` — the Python STABL library does
not implement MVR knockoffs. Chunking and fallback behaviour mirror
`make_knockoff_equi_features()`: MVR-solver failure falls back to equi;
`create.gaussian` failure falls back to random permutation.

## Usage

``` r
make_knockoff_mvr_features(x, n_injected, random_state = NULL)
```

## Arguments

  - x:
    
    Numeric matrix of predictors (samples \\(\\times\\) features).

  - n\_injected:
    
    Integer; number of knockoff columns to select.

  - random\_state:
    
    Optional integer seed; passed to `solve_mvr()` for the
    coordinate-shuffle RNG.

## Value

Named list with elements `x_augmented` and `noise_col_indices`; see
`make_rp_features()` for details.
