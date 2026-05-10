# Upper-Triangle Adjusted Similarity Values

Computes the full pairwise adjusted-similarity matrix for N feature sets
and returns only the N\\\times\\(N-1)/2 off-diagonal upper-triangle
values as a flat vector. This format is convenient for computing summary
statistics (see
[`adjusted_similarity_measure()`](https://gregbellan.github.io/Stabl/stablr/reference/adjusted_similarity_measure.md))
or for Wilcoxon/permutation tests comparing reproducibility across
methods.

## Usage

``` r
adjusted_similarity_values(list_of_lists, nb_total_elements)
```

## Arguments

- list_of_lists:

  A list of character/integer vectors, one per STABL run.

- nb_total_elements:

  Integer; total number of candidate features.

## Value

Numeric vector of length N\*(N-1)/2 containing the pairwise
adjusted-similarity values for all unique pairs (row-major
upper-triangle order, matching the Python convention).
