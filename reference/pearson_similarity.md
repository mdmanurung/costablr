# Pearson-Corrected Similarity Between Two Feature Sets

Computes a Pearson-correlation-inspired similarity that corrects for
expected random intersection. This is a second chance-correction
approach (alongside `adjusted_similarity()`) that normalises by the
geometric mean of the within-set variances under independent Bernoulli
sampling.

## Usage

``` r
pearson_similarity(list_i, list_j, d)
```

## Arguments

  - list\_i:
    
    Character or integer vector of selected feature identifiers.

  - list\_j:
    
    Character or integer vector of selected feature identifiers.

  - d:
    
    Integer; total number of candidate features in the universe.

## Value

Numeric scalar. Positive values indicate more overlap than chance; the
maximum is typically close to 1 for perfectly matching sets.

## Details

The formula is: $$S\_{\\text{Pearson}}(A, B) = \\frac{r - k\_i k\_j /
d}{d \\cdot \\upsilon\_i \\upsilon\_j}$$ where \\(r = |A \\cap B|\\),
\\(k\_i = |A\_i|\\), \\(d\\) is the universe size, and \\(\\upsilon\_i =
\\sqrt{\\pi\_i (1 - \\pi\_i)}\\) with \\(\\pi\_i = k\_i / d\\).

Edge cases: returns 1 when both sets are empty or both equal the
universe; returns 0 when one set is empty or equals the universe.

## See also

`pearson_similarity_values()` for computing all pairwise values at once,
`pearson_similarity_measure()` for a summary statistic,
`adjusted_similarity()` for an alternative chance-correction.

## Examples

``` r
pearson_similarity(c("f1","f2","f3"), c("f2","f3","f4"), d = 10L)
pearson_similarity(c("f1","f2"),      c("f1","f2"),      d = 10L) # near 1
pearson_similarity(character(0),      c("f1","f2"),      d = 10L) # 0
```
