# Make Model-X Equicorrelated Knockoff Artificial Features

Generates **model-X equicorrelated** knockoff features via
`knockoff::create.gaussian(..., method = "equi")`. This matches the
`GaussianSampler(X, method='equicorrelated')` call used by the Python
STABL library, making it the parity-correct knockoff type for
cross-language comparisons. Column-chunking for datasets that exceed 3
000 features is applied (same as `make_knockoff_features()`). Falls back
to random-permutation features when the knockoff constructor fails.

## Usage

``` r
make_knockoff_equi_features(x, n_injected, random_state = NULL)
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
