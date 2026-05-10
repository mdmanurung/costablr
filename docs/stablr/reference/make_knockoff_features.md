# Make Knockoff Artificial Features

Generates model-X knockoff features via
[`knockoff::create.fixed()`](https://rdrr.io/pkg/knockoff/man/create.fixed.html),
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

  Numeric matrix of predictors (samples \\\times\\ features).

- n_injected:

  Integer; number of knockoff columns to select.

- random_state:

  Optional integer seed.

## Value

Named list with elements `x_augmented` and `noise_col_indices`; see
[`make_rp_features()`](https://gregbellan.github.io/Stabl/stablr/reference/make_rp_features.md)
for details.
