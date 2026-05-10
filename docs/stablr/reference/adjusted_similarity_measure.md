# Summary Statistic of Adjusted Similarity Values

Convenience wrapper that computes all pairwise adjusted similarities
(via
[`adjusted_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_values.md))
and reduces them to a single location statistic with an associated
spread measure. Useful for reporting a single reproducibility number per
STABL configuration in benchmarking tables.

## Usage

``` r
adjusted_similarity_measure(list_of_lists, nb_total_elements, stat = "median")
```

## Arguments

- list_of_lists:

  A list of character/integer vectors, one per run.

- nb_total_elements:

  Integer; total number of candidate features.

- stat:

  Character; `"median"` (default, robust to outliers) or `"mean"`.

## Value

A named list with two elements:

- `statistic`:

  The median (or mean) of adjusted-similarity values.

- `err`:

  For `"median"`: the 25th and 75th percentile vector (IQR bounds). For
  `"mean"`: the root-mean-squared deviation (RMSD / population SD).
