# stablr 0.1.0

## Quality and publication-readiness sweep

- **Infrastructure:** corrected `License:` field; lowered `Depends: R (>=
  4.1.0)` from 4.4.0; moved package-level doc to `R/stablr-package.R`; guarded
  `save_stabl_results()` against a missing ggplot2 Suggests dep; removed stray
  `Rplots.pdf` build artifacts.
- **Documentation:** documented all four `print.*` S3 methods; added `@examples`
  to all 54 exported symbols; replaced duplicated `@param` blocks with
  `@inheritParams stabl_fit`; added `@seealso` cross-links across the metrics
  family and `compute_fdp_plus`.
- **Correctness:** guarded cooperative lambda-index lookup against float
  mismatch; fixed integer overflow in `.derive_nested_seed` for large fold
  counts; added explicit `stop()` default to the cooperation `type_measure`
  switch; replaced `seq(start+1, start+n)` with `seq_len(n)` idiom at all index
  ranges; added tie-policy comments at every `which.min`/`which.max` site.
- **Performance:** centralised `rowMaxs` helper with edge-case fast paths for
  0-row and 1-column matrices; eliminated quadratic `c(accumulator, chunk)`
  vector growth in three bootstrap helpers; extracted
  `.BOOTSTRAP_COEF_THRESHOLD` named constant.
- **Tests:** added tests for `get_stabl_scores` and `load_ool_data`; modernised
  `skip()` to `skip_if()` idiom; test baseline 1553 pass / 0 fail.
- **CI:** added `.github/workflows/R-CMD-check.yaml` (ubuntu release+devel,
  macOS release) with a separate covr/Codecov coverage job; gated heavy
  vignettes (`stablr-multiomic`, `stablr-tcga`, `stablr-tcga-nestedcv`) with
  `eval = FALSE` in their setup chunks.

## Native cooperative learning (multiview engine)

- Vendored CRAN `multiview` v1.0 cooperative-learning engine (GPL-2 submodule in
  `inst/COPYING.cooperative`) for gaussian and binomial cooperative fusion.
- No runtime dependency on the external `multiview` package for cooperative
  workflows.
- Compiled C++ core (`wls_exp`, glmnetpp headers) with `NeedsCompilation: yes`.
- New `vignette("stablr-advanced")` documents Cox, knockoffs, grouped bootstrap,
  reproducibility metrics, export helpers, and outer CV.

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
