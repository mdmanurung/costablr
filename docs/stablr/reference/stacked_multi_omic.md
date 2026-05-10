# Stacked Generalization Over Per-Omic Predictions

Finds optimal omic weights by random search, matching the Python
`stacked_multi_omic` algorithm from `stabl/stacked_generalization.py`.
Missing values in `predictions` are handled per-row: rows with all-NA
predictions receive `NA` in the stacked output.

## Usage

``` r
stacked_multi_omic(predictions, y, task_type = c("binary", "regression"),
    n_iter = 10000L, random_state = NULL)
```

## Arguments

- predictions:

  A `data.frame` or numeric matrix with one column per omic and one row
  per sample. Missing values (`NA`) are supported and treated as absent
  omics for those samples.

- y:

  Named numeric outcome vector aligned with rows of `predictions`. For
  `task_type = "binary"` values must be `0`/`1`.

- task_type:

  Either `"binary"` (maximise AUC) or `"regression"` (maximise R²).

- n_iter:

  Number of random weight draws to try. Mirrors `n_iter` in the Python
  implementation (default `10000`).

- random_state:

  Optional integer seed for reproducibility. Saves and restores the RNG
  state on exit so caller state is unaffected.

## Value

A named list with three elements:

- `predictions`:

  `data.frame` with one column per omic plus a
  `"Stacked Gen. Predictions"` column of the best weighted average.

- `weights`:

  `data.frame` with one row per omic and a column `Associated_weight`
  containing the optimal weight.

- `score`:

  Best score achieved (AUC or R²).

## Details

In each of `n_iter` iterations a weight vector is sampled from
`Uniform(0, 10)`. For each sample the weighted average of available omic
predictions is computed (missing omics for that sample are skipped). The
iteration that maximises AUC (binary) or R² (regression) is retained.

## Examples

``` r
set.seed(1)
# Simulate two-omic predictions for 20 binary samples
y    <- rep(c(0L, 1L), 10)
pred <- data.frame(
  omic_a = y + rnorm(20, sd = 0.5),
  omic_b = y + rnorm(20, sd = 1.5)
)
res <- stacked_multi_omic(pred, y, task_type = "binary",
                          n_iter = 200L, random_state = 42L)
res$weights
res$score
```
