# stablr 0.1.0

## Application-note release candidate

- Pure-R STABL implementation with glmnet backends (lasso, elastic net,
  adaptive lasso, optional sparse group lasso).
- FDP+ thresholding with random-permutation and knockoff artificial features.
- Multi-omic train/validation, outer CV, and nested CV workflows.
- Early, late, and cooperative fusion integration paths.
- Bundled Onset of Labor (OOL) tutorial subset in `inst/extdata/`.
- Python parity fixtures and vignettes for cross-language validation.
- Publication reproduction script: `inst/analysis/generate_publication_parity_table.R`.

## Naming

The package is **`stablr`**. Cooperative multi-omic fusion is a workflow inside
`stablr`, not a separate package (`costablr` is not used).
