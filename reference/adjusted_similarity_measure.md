# Summary Statistic of Adjusted Similarity Values

Convenience wrapper that computes all pairwise adjusted similarities
(via `adjusted_similarity_values()`) and reduces them to a single
location statistic with an associated spread measure. Useful for
reporting a single reproducibility number per STABL configuration in
benchmarking tables.

## Usage

``` r
adjusted_similarity_measure(list_of_lists, nb_total_elements, stat = "median")
```

## Arguments

  - list\_of\_lists:
    
    A list of character/integer vectors, one per run.

  - nb\_total\_elements:
    
    Integer; total number of candidate features.

  - stat:
    
    Character; `"median"` (default, robust to outliers) or `"mean"`.

## Value

A named list with two elements:

  - `statistic`:
    
    The median (or mean) of adjusted-similarity values.

  - `err`:
    
    For `"median"`: the 25th and 75th percentile vector (IQR bounds).
    For `"mean"`: the root-mean-squared deviation (RMSD / population
    SD).

## See also

`adjusted_similarity_values()`, `pearson_similarity_measure()`

## Examples

``` r
sets <- list(c("f1","f2","f3"), c("f2","f3","f4"), c("f1","f3","f5"))
adjusted_similarity_measure(sets, nb_total_elements = 10L)
adjusted_similarity_measure(sets, nb_total_elements = 10L, stat = "mean")
```
