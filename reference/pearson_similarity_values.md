# Upper-Triangle Pearson Similarity Values

Computes all pairwise Pearson-corrected similarities and returns the
N\\(\\times\\)(N-1)/2 upper-triangle values as a flat vector (same
layout as `adjusted_similarity_values()`, enabling direct comparison
between the two metrics on the same data).

## Usage

``` r
pearson_similarity_values(list_of_lists, d)
```

## Arguments

  - list\_of\_lists:
    
    A list of character/integer vectors, one per run.

  - d:
    
    Integer; total number of candidate features.

## Value

Numeric vector of length N\*(N-1)/2.

## See also

`pearson_similarity()` for the pairwise function,
`pearson_similarity_measure()` for a one-number summary,
`adjusted_similarity_values()` for an alternative chance-correction.

## Examples

``` r
sets <- list(c("f1","f2","f3"), c("f2","f3","f4"), c("f1","f3","f5"))
pearson_similarity_values(sets, d = 10L)
```
