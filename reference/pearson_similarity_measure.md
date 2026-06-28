# Summary Statistic of Pearson Similarity Values

Convenience wrapper analogous to `adjusted_similarity_measure()` but
using the Pearson-corrected similarity. See `pearson_similarity()` for a
description of the underlying metric and when to prefer it over the
adjusted similarity.

## Usage

``` r
pearson_similarity_measure(list_of_lists, d, stat = "median")
```

## Arguments

  - list\_of\_lists:
    
    A list of character/integer vectors, one per run.

  - d:
    
    Integer; total number of candidate features.

  - stat:
    
    Character; `"median"` (default) or `"mean"`.

## Value

A named list with `statistic` and `err` (see
`adjusted_similarity_measure()` for the exact definitions).

## See also

`pearson_similarity_values()`, `adjusted_similarity_measure()`

## Examples

``` r
sets <- list(c("f1","f2","f3"), c("f2","f3","f4"), c("f1","f3","f5"))
pearson_similarity_measure(sets, d = 10L)
pearson_similarity_measure(sets, d = 10L, stat = "mean")
```
