# TCGA Benchmark Plan

This file records the publication-readiness plan for the TCGA head-to-head
benchmark referenced by the vignettes.  It complements
`inst/analysis/README.md`, which covers simulation-based methodology checks.

## Objective

Compare `stablr` and mixOmics DIABLO on the same TCGA breast cancer
classification task using nested cross-validation, without leaking feature
selection or tuning information across train/test boundaries.

## Dataset And Blocks

- Source: `mixOmics::breast.TCGA`.
- Outcome: PAM50 class labels used in the nested-CV vignette.
- Blocks: mRNA and miRNA for the primary benchmark, because both are available
  for the full sample set used there.
- Protein data are reserved for sensitivity analyses when the sample definition
  is made explicit.

## Primary Design

- Use outer folds only for performance estimation.
- Perform all STABL feature selection, downstream refitting, DIABLO component
  tuning, and DIABLO `keepX` tuning inside the corresponding training split.
- Report balanced error rate, accuracy, and confusion matrices on held-out outer
  folds.
- Report feature recurrence across outer folds rather than one full-data marker
  list.

## Methods

- `stablr`: per-block and early-fusion multinomial workflows with
  artificial-feature calibration and inner-CV candidate selection.
- DIABLO: `block.plsda()`, `perf()`, `tune.block.splsda()`, and locked
  weighted-vote `centroids.dist` prediction on each outer test fold.

## Artifacts

The external SLURM runner should write these cache files outside the installed
package:

- `tcga_nestedcv_results.rds`: complete nested-CV result object.
- `tcga_nestedcv_performance.csv`: aggregate and paired-fold performance.
- `tcga_nestedcv_feature_recurrence.csv`: selected-feature recurrence by method
  and block.
- `tcga_nestedcv_feature_overlap.csv`: overlap summaries for selected features.

The vignettes may read and display these artifacts when present, but benchmark
results are not bundled with the package unless the cache is explicitly added.

## Publication Readiness Gates

- Confirm package-rendered vignettes do not fabricate or imply missing results.
- Record random seeds, fold assignments, package versions, and command lines in
  the cache metadata.
- Inspect paired outer-fold deltas and class-wise recalls before declaring a
  method-level performance difference.
- Treat marker conclusions as exploratory until validated on an external cohort
  or a clearly separated confirmatory analysis.

## Phases

- Phase 1: produce the nested-CV cache and exported CSVs with fixed seeds and
  documented fold assignments.
- Phase 2: review paired outer-fold deltas, class-wise recalls, and feature
  recurrence stability for manuscript tables.
- Phase 3: add sensitivity or confirmatory analyses, such as protein-block
  variants or external-cohort validation, without replacing the Phase 1 cache.
