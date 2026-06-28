# Make Random-Permutation Artificial Features

Randomly selects `n_injected` columns from `x`, copies them, and
shuffles each copy independently. Mirrors the `"random_permutation"`
branch of `Stabl._make_artificial_features()` in the Python STABL
library.

## Usage

``` r
make_rp_features(x, n_injected)
```

## Arguments

  - x:
    
    Numeric matrix of predictors (samples \\(\\times\\) features).

  - n\_injected:
    
    Integer; number of artificial columns to generate.

## Value

Named list:

  - x\_augmented:
    
    Original matrix with artificial columns appended.

  - noise\_col\_indices:
    
    Integer vector (1-based) of original column indices selected as
    sources for the artificial block.
