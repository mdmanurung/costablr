# Adjusted Similarity Between Two Feature Sets

Computes a chance-corrected similarity between two feature sets. Unlike
`jaccard_similarity()`, the adjusted measure accounts for the expected
random overlap given the sizes of both sets and the total feature
universe, so it does not systematically penalise methods that select
many features.

## Usage

``` r
adjusted_similarity(list1, list2, nb_total_elements)
```

## Arguments

  - list1:
    
    Character or integer vector of selected feature identifiers.

  - list2:
    
    Character or integer vector of selected feature identifiers.

  - nb\_total\_elements:
    
    Integer; total number of candidate features in the universe (i.e.
    the number of columns in the original predictor matrix).

## Value

Numeric scalar in \\((-1, 1\]\\). Values above 0 indicate more overlap
than expected by chance; 1 means perfect agreement; negative values
indicate less overlap than chance.

## Details

The formula is analogous to Cohen's kappa for sets:
$$S\_{\\text{adj}}(A, B) = \\frac{r - \\mathbb{E}\[r\]}{\\min(k\_1,
k\_2) - \\max(0, k\_1 + k\_2 - d)}$$ where \\(r = |A \\cap B|\\),
\\(k\_i = |A\_i|\\), \\(d =\\) `nb_total_elements`, and
\\(\\mathbb{E}\[r\] = k\_1 k\_2 / d\\).

Returns 0 when either set is empty or equals the full universe (edge
cases where the correction denominator is zero).

## See also

`adjusted_similarity_values()` for computing all pairwise values at
once, `adjusted_similarity_measure()` for a summary statistic,
`jaccard_similarity()` for the non-chance-corrected alternative.

## Examples

``` r
# 10-feature universe; sets A and B share 2 out of 3 features each
adjusted_similarity(c("f1","f2","f3"), c("f2","f3","f4"), nb_total_elements = 10L)
adjusted_similarity(c("f1","f2"),      c("f1","f2"),      nb_total_elements = 10L) # 1
adjusted_similarity(character(0),      c("f1"),           nb_total_elements = 10L) # 0
```
