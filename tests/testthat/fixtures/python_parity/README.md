# Python Parity Fixtures

These fixtures are bundled so release-gated parity tests fail when reference
artifacts are accidentally omitted.

Generated for the 2026-06-27 release-hardening pass from deterministic toy
inputs mirroring the Python STABL public surfaces:

- `stabl_fit_reference.csv`: feature-level maximum stability-score reference.
- `stacked_multi_omic_reference.csv`: stacked-generalization omic weights.
- `metrics_scalars.csv` and `metrics_vectors.csv`: deterministic metric
  references for the toy feature sets in `tests/testthat/test-phase7.R`.

Regenerate by replacing these files with outputs from the Python reference
implementation for the same toy inputs and updating this provenance note.

The metric fixtures have their toy inputs encoded in
`tests/testthat/test-phase7.R`.  The `stabl_fit_reference.csv` and
`stacked_multi_omic_reference.csv` files currently do not bundle enough
provenance to recompute numerical parity inside the R test suite.  Missing
items are:

- exact Python package version or commit;
- exact toy input matrices, outcomes, and sample or omic names;
- exact `Stabl.fit()` parameters, including lambda grid, bootstrap settings,
  artificial-feature settings, and random state;
- exact `stacked_multi_omic` predictions, task type, iteration count, random
  state, and whether weights are raw or normalized.

Until those inputs are added, the R fixture tests only assert file integrity for
these two references and must not compare the bundled references to values
reconstructed from the references themselves.
