# Validate Sample Alignment Across Inputs

Checks that the predictor matrix, outcome vector, and optional group
vector all refer to exactly the same set of samples (by name), and that
they can be safely aligned before modelling.

## Usage

``` r
validate_sample_alignment(x, y, groups = NULL)
```

## Arguments

  - x:
    
    A `data.frame` or numeric matrix with non-empty, non-`NA` row names
    used as sample IDs.

  - y:
    
    A named vector (or matrix-like object such as `survival::Surv` with
    row names) whose names identify the samples. The set of names in `y`
    must be identical to the set of row names in `x`; order does not
    need to match.

  - groups:
    
    Optional named vector where names are sample IDs and values are
    group memberships. When supplied, its name set must also match
    `rownames(x)`. Pass `NULL` to skip group validation.

## Value

Invisibly returns `TRUE` when all checks pass. Raises an informative
error as soon as the first violation is found.

## Details

STABL enforces strict name-based alignment (rather than positional
alignment) to mirror the pandas index-alignment semantics of the Python
reference implementation and to prevent silent sample-order bugs that
could corrupt stability scores or introduce outcome leakage.

This function is called automatically by `stabl_fit()` and
`stabl_multiomic_train_validate()`; you only need to call it directly
when building a custom pre-processing step that receives `x` and `y`
separately.

## See also

`validate_multiomic_inputs()` for multi-omic list inputs.
