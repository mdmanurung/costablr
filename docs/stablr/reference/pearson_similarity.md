# Pearson-Corrected Similarity Between Two Feature Sets

Computes a Pearson-correlation-inspired similarity that corrects for
expected random intersection. This is a second chance-correction
approach (alongside
[`adjusted_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity.md))
that normalises by the geometric mean of the within-set variances under
independent Bernoulli sampling.

## Usage

``` r
pearson_similarity(list_i, list_j, d)
```

## Arguments

- list_i:

  Character or integer vector of selected feature identifiers.

- list_j:

  Character or integer vector of selected feature identifiers.

- d:

  Integer; total number of candidate features in the universe.

## Value

Numeric scalar. Positive values indicate more overlap than chance; the
maximum is typically close to 1 for perfectly matching sets.

## Details

The formula is: \$\$S\_{\text{Pearson}}(A, B) = \frac{r - k_i k_j / d}{d
\cdot \upsilon_i \upsilon_j}\$\$ where \\r = \|A \cap B\|\\, \\k_i =
\|A_i\|\\, \\d\\ is the universe size, and \\\upsilon_i = \sqrt{\pi_i
(1 - \pi_i)}\\ with \\\pi_i = k_i / d\\.

Edge cases: returns 1 when both sets are empty or both equal the
universe; returns 0 when one set is empty or equals the universe.
