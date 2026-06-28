# Classic Bootstrap Sampler Indices

Draws a random set of row indices from a training set for a single STABL
bootstrap iteration. This is the standard (non-grouped) sampler used
when all samples are independent.

## Usage

``` r
classic_bootstrap_indices(
  y,
  n_subsamples,
  replace = TRUE,
  class_weights = NULL,
  stratify = FALSE,
  strata = NULL,
  seed = NULL
)
```

## Arguments

  - y:
    
    Outcome vector whose length equals the number of training samples.
    Values are only examined to check class diversity and to apply
    `class_weights`; the type is arbitrary (numeric, factor, character).

  - n\_subsamples:
    
    Positive integer; number of row indices to draw. Must not exceed
    `length(y)` when `replace = FALSE`.

  - replace:
    
    Logical; sample with replacement? Default `TRUE`.

  - class\_weights:
    
    Optional named numeric vector keyed by class labels (as produced by
    `as.character(y)`). When `NULL` all samples are equally likely.

  - stratify:
    
    Logical; if `TRUE`, draw approximately the same class proportions as
    `y` by sampling within each outcome class. This is useful for small
    or imbalanced classification tasks where unstratified subsampling
    can produce very sparse minority-class bootstraps. Default `FALSE`
    preserves the original STABL sampling behavior.

  - strata:
    
    Optional categorical stratification design. Provide a vector for one
    stratification factor, or a `data.frame`/matrix/list for a joint
    design across multiple factors. Bootstrap samples are drawn within
    the interaction of all supplied columns. When `NULL`, no
    stratification is used unless `stratify = TRUE`, in which case `y`
    is used as the strata.

  - seed:
    
    Optional integer; passed to `set.seed()` before sampling for
    reproducibility. `NULL` leaves the RNG state unchanged.

## Value

Integer vector of length `n_subsamples` containing 1-based row indices
into the training set.

## Details

STABL accumulates how often each feature is selected across many
bootstrap subsamples; these subsamples must be drawn consistently to
avoid bias. This function centralises that sampling so that
class-imbalance handling and the "degenerate bootstrap" guard (see
below) are applied uniformly.

**Class weighting:** When `class_weights` is supplied each sample's
inclusion probability is proportional to the weight of its class. This
is useful for imbalanced binary or multi-class outcomes where unweighted
subsampling would frequently produce single-class bootstraps.

**Degenerate bootstrap guard:** When the drawn subsample contains only
one unique class but the full outcome contains at least two, the
function retries (without a seed) until a class-diverse subsample is
found. This prevents downstream model failures in classifiers that
require at least two classes.

## See also

`group_bootstrap_indices()` for repeated-measures/grouped data,
`stabl_fit()` which calls this sampler automatically.

## Examples

``` r
set.seed(42L)
y <- c(rep(0, 15), rep(1, 15))  # balanced binary outcome
idx <- classic_bootstrap_indices(y, n_subsamples = 20L, seed = 1L)
table(y[idx])  # class distribution in the bootstrap

# Stratified sampling preserves class proportions
idx_str <- classic_bootstrap_indices(y, n_subsamples = 20L,
                                     stratify = TRUE, seed = 1L)
table(y[idx_str])
```
