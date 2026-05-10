# Group-Aware Bootstrap Sampler Indices

Draws row indices for a single STABL bootstrap iteration by sampling
**groups** rather than individual samples. Use this instead of
[`classic_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/classic_bootstrap_indices.md)
whenever the training data contains repeated measurements or known
clusters (e.g. multiple time-points per subject, technical replicates,
or family members).

## Usage

``` r
group_bootstrap_indices(y, groups, n_subsamples, replace = FALSE, seed = NULL)
```

## Arguments

- y:

  Outcome vector with the same length as `groups`.

- groups:

  Vector of group identifiers (same length as `y`). Values may be any
  type that supports [`unique()`](https://rdrr.io/r/base/unique.html)
  and equality comparison.

- n_subsamples:

  Positive integer; target number of rows in the subsample. The actual
  count may differ slightly due to whole-group granularity (whole groups
  are always preserved; the realised count is the smallest group-aligned
  value `>= n_subsamples`).

- replace:

  Logical; may the same group be sampled more than once? Default
  `FALSE`.

- seed:

  Optional integer; passed to
  [`set.seed()`](https://rdrr.io/r/base/Random.html) before sampling.
  `NULL` leaves the RNG state unchanged.

## Value

Integer vector of 1-based row indices into the training set.

## Details

**Why group-level sampling prevents leakage:** If individual rows from
the same subject appear in both the bootstrap subsample and its
complement, the stability score becomes inflated because the learner can
partially memorise subject-level patterns. By sampling complete groups,
the subsample and its "holdout" are subject-disjoint, preserving the
independence assumption underlying STABL's FDP+ guarantee.

**How groups are sampled:** Groups are drawn one at a time (without
replacement by default) until the running tally of included rows reaches
or exceeds `n_subsamples`. Whole groups are always kept intact: if the
last added group causes the count to exceed `n_subsamples`, the surplus
rows are *not* trimmed. This guarantees the strongest leakage prevention
(the subsample and its complement are always group-disjoint), at the
cost of a slightly variable subsample size. When `replace = TRUE` the
same group may be drawn multiple times (useful when there are very few
groups).

**Degenerate bootstrap guard:** As with
[`classic_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/classic_bootstrap_indices.md),
if the final subsample contains only one unique class the function
retries until a class-diverse sample is obtained.

## See also

[`classic_bootstrap_indices()`](https://gregbellan.github.io/Stabl/stablr/reference/classic_bootstrap_indices.md)
for independent-sample data,
[`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md)
which calls this sampler automatically when `groups` is supplied.
