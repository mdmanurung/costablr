# Validate Multi-Omic Input Contract

Enforces the canonical `stablr` input contract for multi-omic analyses:
a named list of omic tables with identical sample IDs and row order
across all views, plus strict alignment with the outcome and optional
group vectors.

## Usage

``` r
validate_multiomic_inputs(x_list, y, groups = NULL)
```

## Arguments

  - x\_list:
    
    Named list of `data.frame` or numeric matrix omic tables. Each table
    must have non-empty row names identifying samples. All tables must
    have the same set of row names **in the same order**.

  - y:
    
    Named outcome vector aligned to the samples in `x_list`. The name
    set must match the row names of every omic table.

  - groups:
    
    Optional named group vector. When supplied its names must match the
    sample IDs in `x_list`. Pass `NULL` to skip group validation.

## Value

Invisibly returns `TRUE` when all checks pass. Raises an informative
error as soon as the first violation is found.

## Details

Multi-omic analyses require that all omic matrices have exactly the same
rows in exactly the same order so that row-wise operations (bootstrap
sampling, cooperative learning) are coherent. This function catches
mismatches early and provides informative error messages naming the
offending omic layer, which is much easier to diagnose than silent
misalignment detected later in the modelling pipeline.

## See also

`validate_sample_alignment()` for single-omic inputs,
`stabl_multiomic_train_validate()` which calls this automatically.
