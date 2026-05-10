# Upper-Triangle Pearson Similarity Values

Computes all pairwise Pearson-corrected similarities and returns the
N\\\times\\(N-1)/2 upper-triangle values as a flat vector (same layout
as
[`adjusted_similarity_values()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_values.md),
enabling direct comparison between the two metrics on the same data).

## Usage

``` r
pearson_similarity_values(list_of_lists, d)
```

## Arguments

- list_of_lists:

  A list of character/integer vectors, one per run.

- d:

  Integer; total number of candidate features.

## Value

Numeric vector of length N\*(N-1)/2.
