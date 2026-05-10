# Summary Statistic of Pearson Similarity Values

Convenience wrapper analogous to
[`adjusted_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_measure.md)
but using the Pearson-corrected similarity. See
[`pearson_similarity()`](https://gregbellan.github.io/Stabl/stablr/reference/pearson_similarity.md)
for a description of the underlying metric and when to prefer it over
the adjusted similarity.

## Usage

``` r
pearson_similarity_measure(list_of_lists, d, stat = "median")
```

## Arguments

- list_of_lists:

  A list of character/integer vectors, one per run.

- d:

  Integer; total number of candidate features.

- stat:

  Character; `"median"` (default) or `"mean"`.

## Value

A named list with `statistic` and `err` (see
[`adjusted_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_measure.md)
for the exact definitions).
