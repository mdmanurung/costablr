# Make Knockoff Artificial Features

Generates **fixed-X** knockoff features via `knockoff::create.fixed()`,
with column-chunking for datasets that exceed 3 000 features (mirroring
the Python STABL implementation that chunks calls to `GaussianSampler`).
Falls back to random-permutation features when the knockoff constructor
fails (e.g., rank-deficient input).

## Usage

``` r
make_knockoff_features(x, n_injected, random_state = NULL)
```

## Arguments

  - x:
    
    Numeric matrix of predictors (samples \\(\\times\\) features).

  - n\_injected:
    
    Integer; number of knockoff columns to select.

  - random\_state:
    
    Optional integer seed.

## Value

Named list with elements `x_augmented` and `noise_col_indices`; see
`make_rp_features()` for details.
