# Adjusted Similarity Between Two Feature Sets

Computes a chance-corrected similarity between two feature sets. Unlike
[`jaccard_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/jaccard_similarity.md),
the adjusted measure accounts for the expected random overlap given the
sizes of both sets and the total feature universe, so it does not
systematically penalise methods that select many features.

## Usage

``` r
adjusted_similarity(list1, list2, nb_total_elements)
```

## Arguments

- list1:

  Character or integer vector of selected feature identifiers.

- list2:

  Character or integer vector of selected feature identifiers.

- nb_total_elements:

  Integer; total number of candidate features in the universe (i.e. the
  number of columns in the original predictor matrix).

## Value

Numeric scalar in \\(-1, 1\]\\. Values above 0 indicate more overlap
than expected by chance; 1 means perfect agreement; negative values
indicate less overlap than chance.

## Details

The formula is analogous to Cohen's kappa for sets:
\$\$S\_{\text{adj}}(A, B) = \frac{r - \mathbb{E}\[r\]}{\min(k_1, k_2) -
\max(0, k_1 + k_2 - d)}\$\$ where \\r = \|A \cap B\|\\, \\k_i =
\|A_i\|\\, \\d =\\ `nb_total_elements`, and \\\mathbb{E}\[r\] = k_1 k_2
/ d\\.

Returns 0 when either set is empty or equals the full universe (edge
cases where the correction denominator is zero).
