# Dispatcher for Artificial Feature Generation

Selects and calls the appropriate artificial-feature generator based on
`type`, returning the augmented predictor matrix together with the
column indices of the injected noise block.

## Usage

``` r
make_artificial_features(x, n_injected, type, random_state = NULL)
```

## Arguments

  - x:
    
    Numeric matrix of predictors (samples \\(\\times\\) features). Must
    have more columns than `n_injected` for random permutation; for
    knockoffs, a fallback to random permutation is attempted when the
    knockoff constructor fails (e.g., rank-deficient input).

  - n\_injected:
    
    Positive integer; number of artificial columns to append. Typically
    `round(ncol(x) * artificial_proportion)` as computed in
    `stabl_fit()`.

  - type:
    
    Character string; one of `"random_permutation"`, `"knockoff"`,
    `"knockoff_equi"`, or `"knockoff_mvr"`.

  - random\_state:
    
    Optional integer; passed to `set.seed()` before any random
    operations for reproducibility. `NULL` leaves the RNG unchanged.
    Seeding happens exactly once in this dispatcher; downstream
    generators inherit the seeded RNG state and do not re-seed (audit
    M-5).

## Value

Named list with two elements:

  - `x_augmented`:
    
    Numeric matrix of size (nrow(x)) \\(\\times\\) (ncol(x) +
    n\_injected) with the artificial columns appended after the original
    features.

  - `noise_col_indices`:
    
    Integer vector of length `n_injected` containing the 1-based indices
    into the **original** `x` columns (not into the artificial block)
    that identify which source features were used to build each
    artificial column. Used by `stabl_fit()` to look up
    sparse-group-lasso group memberships for the artificial block via
    `.append_noise_groups`.

## Details

Injecting artificial features is central to STABL's automatic FDP+
control: by mixing known-noise columns into the predictor matrix
alongside real features, STABL can empirically estimate how often a
variable of pure noise is selected at a given stability threshold. This
observed noise-selection rate drives the FDP+ bound computed in
`compute_fdp_plus()`, eliminating the need to choose a stability
threshold by hand.

Four noise strategies are supported:

  - `"random_permutation"`:
    
    Copies `n_injected` randomly chosen real columns and shuffles each
    copy independently, breaking all signal while preserving marginal
    distributions. Fast and broadly applicable.

  - `"knockoff"`:
    
    Generates **fixed-X** knockoffs via `knockoff::create.fixed()`,
    which preserve the covariance structure of the original features
    under the fixed-design assumption. Kept for backward compatibility.

  - `"knockoff_equi"`:
    
    Generates **model-X equicorrelated** knockoffs via
    `knockoff::create.gaussian(..., method = "equi")`. This matches the
    `GaussianSampler(method='equicorrelated')` call in Python STABL and
    is the parity-correct knockoff type for cross-language comparisons.

  - `"knockoff_mvr"`:
    
    Generates **model-X MVR** (minimum-variance- reconstructability)
    knockoffs. The S-matrix is solved by `solve_mvr()` (a pure-R port of
    `knockpy.mrc`); sampling uses `knockoff::create.gaussian(..., diag_s
    = S)`. This is a novel feature exclusive to `stablr`.

## See also

`compute_fdp_plus()` which consumes the artificial-feature scores,
`stabl_fit()` which calls this function automatically.
