# Reproducible Python parity fixtures

These fixtures freeze exact, solver-independent algorithm contracts against
[`gregbellan/Stabl`](https://github.com/gregbellan/Stabl) commit
`1d07f85a13cfbecb4f08ce21075bf4fbb8e34678` (package version 1.0.0).
They are regenerated with Python 3.11 from explicit inputs, and package checks
consume only the committed CSV/JSON files. Python is **not** needed to install
or check `stablr`.

## Reproduce

Create the pinned environment and checkout, then run the generator:

```sh
conda env create -f tests/testthat/fixtures/python_parity/environment.yml
git clone https://github.com/gregbellan/Stabl.git /tmp/Stabl-reference
git -C /tmp/Stabl-reference checkout 1d07f85a13cfbecb4f08ce21075bf4fbb8e34678
conda run -n stablr-python-parity python \
  tests/testthat/fixtures/python_parity/generate.py \
  --reference-checkout /tmp/Stabl-reference
(cd tests/testthat/fixtures/python_parity && sha256sum -c manifest.sha256)
```

Regeneration is byte-deterministic for the pinned environment. `generate.py`
verifies the checkout commit before writing anything. The manifest covers the
generator, environment definition, provenance, all inputs, and all numerical
outputs.

## Contract map

- `input_matrix.csv`, `outcomes.csv`, `bootstrap_schedule.csv`,
  `artificial_matrix.csv`, `artificial_provenance.csv`, and `lambda_grid.csv`
  are explicit deterministic inputs and provenance.
- `selection_masks.csv` is the complete boolean selection schedule (eight
  bootstraps by three lambda values) used to test score accumulation exactly.
- `stability_scores.csv`, `fdp_plus_curve.csv`,
  `fdp_plus_by_lambda.csv`, and `stabl_fit_reference.csv` freeze accumulated
  scores, strict-threshold FDP+, first-minimum handling, ranking, and support.
  The generator executes the exact pinned `_compute_FDPplus()` and
  `_get_support_mask()` method bodies extracted from the reference source AST.
- `stacking_predictions.csv`, `stacking_outcomes.csv`, and
  `stacking_candidate_weights.csv` are the shared stacking inputs. The pinned
  `stacked_multi_omic()` is run with those candidate rows in order.
  `stacking_candidate_scores.csv`, `stacked_multi_omic_reference.csv`, and
  `stacking_predictions_reference.csv` freeze the chosen row, raw and
  normalized weights, missing-value behavior, score, predictions, and the
  first-winner policy when later candidates tie.
- `metrics_scalars.csv` and `metrics_vectors.csv` are produced by the pinned
  Python metric functions for the inputs documented in
  `tests/testthat/test-phase7.R`.
- `solver_input_matrix.csv`, `solver_outcomes.csv`, and
  `solver_bootstrap_schedule.csv` are shared end-to-end solver inputs.
  `solver_cases.csv` and `solver_lambda_grid.csv` predeclare the corresponding
  Python and R penalties and family-specific acceptance gates.
  `solver_reference.csv` contains Python 3.11/scikit-learn stability rankings
  and supports for Gaussian and binomial lasso, multinomial lasso, and
  Gaussian elastic net. R recomputes each case with glmnet on the identical
  bootstrap samples and requires the declared Spearman, top-five overlap,
  Jaccard, planted-signal, and non-constant-score gates.
- `provenance.json` is the machine-readable reference/environment/contract
  record. `manifest.sha256` is the integrity manifest.

## Deliberate limitation

The small accumulation selection masks are explicit inputs, not solver output.
This is intentional: exact coefficient equality is not portable across glmnet
and scikit-learn. They provide exact parity evidence for accumulation, FDP+,
thresholds, support-from-frozen-scores, metric functions, and stacking. The
separate solver fixtures therefore use predeclared ranking/support contracts
and must not be represented as coefficient parity. None of these fixtures is
evidence of statistical calibration or universal FDP control.
