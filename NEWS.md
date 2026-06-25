# stablr 0.1.0

## Publication-readiness blocker remediation

- **License:** corrected `License:` field from `MIT + file LICENSE` to `GPL (>= 2)`
  and removed the MIT `LICENSE` file. The vendored cooperative-learning engine
  under `src/glmnetpp/` is derived from glmnet/multiview (GPL-2); the compiled
  combined work must therefore be GPL. `inst/COPYING.cooperative` already
  documented the GPL-2 component.
- **Repository URLs:** updated `URL:` and `BugReports:` in DESCRIPTION and the
  package URL in `inst/CITATION` from the upstream Python repo
  (`gregbellan/Stabl`) to the canonical R package repo (`mdmanurung/stablr`).
- **Contributors:** added the original STABL method authors (Hédou, Marić, Bellan,
  Gfeller — Nat Biotechnol 2024) and the cooperative-learning/multiview authors
  (Ding, Li, Narasimhan, Tibshirani — PNAS 2022) as `ctb` in `Authors@R`,
  consistent with the already-correct `inst/CITATION` entries.
- **Cox in late fusion:** `late_fusion = TRUE` with `family = "cox"` now throws
  a clear error instead of silently scoring with R-squared and OLS predictors
  (both invalid for censored data). Early-fusion and per-omic cox remain valid.
  Mirrors the existing cooperative-fusion cox guard.
- **README:** documented the C++17 compiler / toolchain requirement (Rtools on
  Windows, Xcode CLT on macOS, gcc/clang on Linux) and added a canonical
  `remotes::install_github()` install path.
- **Vignettes:** added reader-facing `eval = FALSE` callout blocks to the three
  heavy vignettes (`stablr-multiomic`, `stablr-tcga`, `stablr-tcga-nestedcv`)
  explaining that code is illustrative and how to run it.
- **MCC metric:** added Matthews Correlation Coefficient (Gorodkin 2004 multiclass
  formula) to the list returned by `.classification_metrics()`. MCC is a standard
  metric for imbalanced classification, complementing the existing accuracy, BER,
  and macro-F1. Returns 0 for degenerate (all-one-class) predictions.
- **Elastic-net parity disclosure:** the Python-parity fixtures for elastic-net
  models assert *signal ranking* (which features are selected), not bit-identical
  coefficients. R and Python elastic-net implementations use different coordinate
  descent schedules; ranking parity is the appropriate criterion and is explicitly
  documented in the test file.
- **Verification:** `mixOmics` (Suggests) is used only in TCGA vignettes and is
  already guarded by `requireNamespace()` + global `eval = FALSE`; no change
  needed.

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
  `.BOOTSTRAP_COEF_THRESHOLD` named constant; halved pairwise-similarity call
  count in `jaccard_matrix`, `adjusted_similarity_values`, and
  `pearson_similarity_values` via upper-triangle loops.
- **Internal quality:** extracted `.require_ggplot2()` to replace six identical
  inline guards; collapsed `.cooperative_selected_features` two-pass loop to a
  single `lapply`; vectorised the finite-check in `.multiclass_log_loss`;
  extracted `.scores_to_long_df` to deduplicate the real- and
  artificial-feature long-data-frame loops in `plot_stabl_path`.
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
