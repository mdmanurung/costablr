# Stacked Generalization Over Per-Omic Predictions

Finds optimal omic weights by random search, matching the Python
`stacked_multi_omic` algorithm from `stabl/stacked_generalization.py`.
Missing values in `predictions` are handled per-row: rows with all-NA
predictions receive `NA` in the stacked output.

## Usage

``` r
stacked_multi_omic(predictions, y, task_type = c("binary", "regression",
    "multiclass"),
    n_iter = 10000L, random_state = NULL)
```

## Arguments

  - predictions:
    
    For `task_type = "binary"` or `"regression"`, a `data.frame` or
    numeric matrix with one column per omic and one row per sample. For
    `task_type = "multiclass"`, a named list of class-probability
    matrices/data frames, one per omic, with samples in rows and classes
    in columns.

  - y:
    
    Named numeric outcome vector aligned with rows of `predictions`. For
    `task_type = "binary"` values must be `0`/`1`; for `task_type =
    "multiclass"`, values are coerced to a factor with levels matching
    the probability columns, and every label must be present in those
    columns.

  - task\_type:
    
    `"binary"` (maximise AUC), `"regression"` (maximise R²), or
    `"multiclass"` (minimise multiclass log loss).

  - n\_iter:
    
    Number of random weight draws to try. Mirrors `n_iter` in the Python
    implementation (default `10000`).

  - random\_state:
    
    Optional integer seed for reproducibility. Saves and restores the
    RNG state on exit so caller state is unaffected.

## Value

A named list with three elements:

  - `predictions`:
    
    `data.frame` with one column per omic plus a `"Stacked Gen.
    Predictions"` column of the best weighted average.

  - `weights`:
    
    `data.frame` with one row per omic and a column `Associated_weight`
    containing the optimal weight.

  - `score`:
    
    Best score achieved (AUC, R², or negative log loss).

## Details

In each of `n_iter` iterations a weight vector is sampled from
`Uniform(0, 10)`. For each sample the weighted average of available omic
predictions is computed (missing omics for that sample are skipped). For
binary and regression tasks, candidate weighted predictions are
evaluated in chunks after drawing the same row-wise candidate weights as
the scalar reference loop. The strict `score > best_score` incumbent
update is still applied in candidate order, so seeded RNG order and
first-maximum tie parity are preserved. The multiclass path remains
scalar by design because per-sample probability normalization and tie
parity are the release priority. The iteration that maximises AUC
(binary), R² (regression), or negative multiclass log loss is retained.

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
