# Methodology Validation Experiments

`run_methodology_validation.R` runs deterministic simulation experiments that
evaluate methodological concerns without changing package runtime behavior.

## Hypotheses

1. FDP+ thresholding should avoid all-feature collapse under null data, including
   correlated predictor settings.
2. In signal settings, empirical FDP and TPR should quantify the calibration and
   power tradeoff for each artificial-feature strategy.
3. Knockoff fallback frequency should be observable from captured warnings and
   from the additive provenance now stored on fitted objects.
4. Bundled Python metric fixtures should remain numerically identical to exported
   R metric functions.

## Default Run

```sh
Rscript inst/analysis/run_methodology_validation.R --out /tmp/stablr-methodology
```

Defaults are bounded for local development: 3 replicates, 12 bootstraps per fit,
6 auto-lambda values, and `random_permutation,knockoff_equi` artificial features
across four scenarios:

- `null_independent`: low-dimensional independent null predictors.
- `null_correlated`: low-dimensional correlated null predictors.
- `signal_correlated`: low-dimensional correlated predictors with 5 signals.
- `signal_high_dim`: high-dimensional correlated predictors with 5 signals.

Scale up with CLI flags such as `--replicates`, `--n-bootstraps`, `--n-lambda`,
`--artificial-types random_permutation,knockoff_equi,knockoff_mvr`, and
`--scenarios`.

## Artifacts

All artifacts are written under the user-specified `--out` directory.

- `methodology_validation_replicates.csv`: one row per scenario, replicate, and
  artificial-feature strategy. Columns include scenario metadata, warning counts,
  selected-feature counts, true positives, false positives, empirical FDP, TPR,
  FDP+ minimum and threshold, real/artificial stability-score summaries, selected
  feature names, and any error text.
- `methodology_validation_summary.csv`: grouped means by scenario and artificial
  type, including empirical FDP exceedance rate relative to `--target-fdp`,
  fallback rates, and elapsed time.
- `methodology_validation_warnings.csv`: captured warning messages with scenario,
  replicate, artificial type, and warning index. Random-permutation fallback and
  MVR-to-equi fallback rates are derived from this table; fitted objects also
  expose `artificial_provenance` for direct per-fit reporting.
- `python_metrics_parity.csv`: observed R metric values compared against bundled
  Python parity fixtures with absolute error and `ok`/`mismatch` status.
- `methodology_validation_manifest.txt`: run settings, hypotheses, and artifact
  paths.

## Non-Additions

The runner deliberately does not change FDP+ thresholding or promote any new
artificial-feature strategy to a default. Methodological changes should be
evaluated with these artifacts before they are added to package runtime paths.
