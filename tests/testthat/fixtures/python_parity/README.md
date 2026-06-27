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
