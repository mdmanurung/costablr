# costablr — Refactoring Tracker & Session Bootstrap

> **For a fresh LLM session:** Read this entire file before touching any code.
> It contains everything needed to continue the refactoring with no other context.

---

## What this project is

`costablr` is a **pure-R package** that ports the Python STABL algorithm for
sparse, reliable biomarker discovery in high-dimensional omic data. It provides
bootstrap stability selection with FDP+ threshold control, multiple penalised-
regression backends (lasso, elastic net, adaptive lasso, sparse group lasso),
and multi-omic workflows (early/late/cooperative fusion). No Python runtime
dependency; no tidymodels dependency. Status: pre-CRAN, core port complete.

The refactoring goal is **one-person maintainability**: reduce cognitive load,
remove duplication, and add missing test coverage — without changing any
user-visible behaviour.

---

## How to run tests

```bash
# Always use the R4_51 conda environment
conda run -n R4_51 Rscript -e "devtools::test()"

# Filter to a single file
conda run -n R4_51 Rscript -e "devtools::test(filter = 'metrics')"

# R CMD check (0 errors required)
conda run -n R4_51 Rscript -e "rcmdcheck::rcmdcheck('.', args = '--no-manual')"
```

**Green baseline (as of 2026-05-18, after completed PRs):**
`FAIL 0 | WARN 2 (pre-existing future/R version) | SKIP 2 (pre-existing) | PASS 1691`

The PASS count started at 1603. Any PR must leave FAIL at 0.

---

## Repository layout (R package)

```
costablr/
├── R/                    ← all R source (edit these)
├── src/                  ← C++ via RcppArmadillo (mvr_knockoff.cpp, corr_groups.cpp)
├── tests/testthat/       ← test files (add new ones here)
├── vignettes/            ← 5 rendered vignettes (.Rmd)
├── inst/                 ← package data, SLURM scripts
├── audit/                ← post-hoc audit findings (documentation only)
├── REFACTORING.md        ← THIS FILE
├── STABL.md              ← algorithm semantics & parity contract (read-only reference)
└── DESCRIPTION / NAMESPACE
```

---

## R source files — current state

| File | Lines | Responsibility | Test file |
|---|---|---|---|
| `R/multiomic_workflows.R` | **1,962** | Multi-omic orchestration + cooperative fusion (~700 L) + late-fusion stacking (~360 L) + CV fold helpers — **OVERSIZED, target < 800** | test-multiomic-workflows.R |
| `R/nested_cv.R` | **723** | Outer/inner nested CV + fold creation + prediction + metrics — **OVERSIZED, target < 450** | test-nested-cv.R |
| `R/learner_adapters.R` | 800 | Factory functions: glmnet, adaptive lasso, sparse group lasso adapters | (via stabl-fit tests) |
| `R/stabl_fit.R` | 696 | Core bootstrap stability-selection loop, FDP+ orchestration | test-stabl-fit.R |
| `R/visualization.R` | 608 | ggplot2 plots: stability path, FDR graph, ROC/PRC, boxplots | **test-visualization.R** ✅ |
| `R/bootstrap_helpers.R` | 562 | Classic + group-aware bootstrap index generation | test-bootstrap-helpers.R |
| `R/stabl_refit.R` | 528 | Selection → unpenalised final model (lm/glm/multinom/coxph) | test-stabl-refit.R |
| `R/stabl_accessors.R` | 436 | S3 getters: get_support, get_feature_names_out, get_importances, etc. | test-stabl-accessors.R |
| `R/metrics.R` | 406 | Jaccard/adjusted/pearson similarity, FDR/TPR/F-score + `.r_auc`/`.r_squared` | **test-metrics.R** ✅ |
| `R/input_validation.R` | 359 | Sample-alignment contracts, multi-omic input validation | test-input-validation.R |
| `R/mvr_knockoff.R` | 253 | R-fallback MVR knockoff solver (C++ primary in `src/`) | test-mvr-knockoff.R |
| `R/exports.R` | 233 | CSV export + full-results-to-disk orchestration | **test-exports.R** ✅ |
| `R/artificial_features.R` | 228 | RP / model-X / MVR knockoff generation | test-artificial-features-parity.R |
| `R/fdp_control.R` | 76 | FDP+ vectorised threshold sweep | (indirect via fdp-plus-invariants) |
| `R/data_helpers.R` | 80 | `load_ool_data()` example dataset loader | (none) |
| `R/RcppExports.R` | 11 | Auto-generated Rcpp binding — **never edit manually** | (via C++ tests) |

---

## Key data flow (read before any PR touching these paths)

```
stabl_fit(x, y, lambda_grid, ...)
  ← validate_sample_alignment()        [input_validation.R]
  ← classic/group_bootstrap_indices()  [bootstrap_helpers.R]
  ← make_glmnet/adaptive/sgl_adapter() [learner_adapters.R]
  ← make_artificial_features()         [artificial_features.R → mvr_knockoff.R → src/mvr_knockoff.cpp]
  ← compute_fdp_plus()                 [fdp_control.R]
  → S3 object "stabl_fit"

stabl_refit()  ←  stabl_fit()  →  final model (lm / glm / multinom / coxph)

stabl_multiomic_train_validate()   [multiomic_workflows.R:95]
  ← per-omic stabl_fit()
  ← .resolve_multiomic_lambda_grid() [multiomic_workflows.R:620]
  ← .cooperative_multiomic_fit()     [multiomic_workflows.R:1123]  ← target of PR-11
  ← stacked_multi_omic()             [multiomic_workflows.R:1611]  ← target of PR-10
  → S3 "stabl_multiomic_fit"

stabl_multiomic_nested_cv()        [nested_cv.R:50]
  ← .make_repeated_cv_folds()       [nested_cv.R:328]              ← target of PR-9
  ← .evaluate_stabl_candidates_inner() [nested_cv.R:443]
  ← stabl_multiomic_train_validate()
  → S3 "stabl_multiomic_nested_cv"
```

---

## S3 classes produced

| Class | Constructor | Key fields |
|---|---|---|
| `stabl_fit` | `stabl_fit()` | `stabl_scores_` (p×L matrix), `fdr_min_threshold_`, `hard_threshold`, `feature_names`, `artificial_type`, `fitted_lambda_grid` |
| `stabl_refit` | `stabl_refit()` | inherits `stabl_fit` fields + `final_model_`, `family` |
| `stabl_multiomic_fit` | `stabl_multiomic_train_validate()` | `fits`, `refits`, `selected_features`, `early_fusion`, `late_fusion`, `cooperative_fusion` |
| `stabl_multiomic_cv` | `stabl_multiomic_cv()` | per-fold summaries of the above |
| `stabl_multiomic_nested_cv` | `stabl_multiomic_nested_cv()` | outer-fold results, candidate selection |

---

## Invariants — never break these

1. **FDP+ semantics** (STABL.md is authoritative):
   - Threshold sweep uses strict `>` comparison.
   - Bootstrap thresholding: `|coef| >= bootstrap_threshold` (not `>`).
   - Artificial feature scaling uses `(1/pi)` factor.
   - Changing any of these requires a Python cross-check + new parity test.

2. **Accessor contract**: code must read `stabl_fit` results only through
   `get_support()`, `get_feature_names_out()`, `get_importances()`, etc.
   Never `$`-index the S3 object directly in tests or vignettes (so the
   internal structure can evolve).

3. **Parallelism**: only `future`/`furrr` for bootstrap-level parallelism.
   No new `parallel::mclapply` calls.

4. **Optional dependencies**: always guard with
   `requireNamespace("pkg", quietly = TRUE)` before use. Add to DESCRIPTION
   `Suggests:`, never `Imports:`.

5. **Every new exported function** needs at least one test before merging.

6. **Test gate**: `devtools::test()` must return FAIL 0 after every PR.

---

## PR tracker

### Completed ✅

| PR | What was done | Files changed |
|---|---|---|
| PR-0 | Created `.lintr` config with intentional suppressions | `.lintr` (new) |
| PR-1 | Merged `audits/` into `audit/`; removed stale `.Rbuildignore` entry; fixed HANDOFF.md reference | `audit/` (2 files added), `.Rbuildignore`, `HANDOFF.md` |
| PR-3 | Added `test-metrics.R` — 52 tests covering all 13 exported metric functions | `tests/testthat/test-metrics.R` (new) |
| PR-4 | Moved `.r_auc()` / `.r_squared()` from `multiomic_workflows.R` → `metrics.R`; added 6 tests | `R/metrics.R`, `R/multiomic_workflows.R`, `test-metrics.R` |
| PR-5 | Centralized threshold fallback into private `.resolve_threshold()` and reused it from support accessors and stability-path plotting | `R/stabl_accessors.R`, `R/visualization.R`, `test-audit-stabl-accessors.R` |
| PR-6 | Added `test-visualization.R` (12 tests) and `test-exports.R` (8 tests) | `tests/testthat/test-visualization.R` (new), `tests/testthat/test-exports.R` (new) |
| PR-7 | Added artificial-feature fallback metadata and persisted `artificial_type_used_` on `stabl_fit` objects | `R/artificial_features.R`, `R/mvr_knockoff.R`, `R/stabl_fit.R`, `R/stabl_accessors.R`, artificial/MVR/STABL tests |
| PR-8 | Documented and warned about nested-CV parallelism interactions between `cv_workers`, `workers`, and active `future` plans | `R/nested_cv.R`, `tests/testthat/test-nested-cv.R` |
| PR-9 | Extracted shared multiomic and nested-CV fold helpers into `R/cv_helpers.R` after adding fixed-seed characterization tests | `R/cv_helpers.R`, `R/multiomic_workflows.R`, `R/nested_cv.R`, `tests/testthat/test-cv-helpers.R` |
| PR-10 | Extracted exported `stacked_multi_omic()` and late-fusion/stacking helpers into `R/late_fusion.R` | `R/late_fusion.R`, `R/multiomic_workflows.R` |
| PR-11 | Extracted cooperative-fusion helpers into `R/cooperative_fusion.R` and reduced `multiomic_workflows.R` below 800 lines | `R/cooperative_fusion.R`, `R/multiomic_workflows.R` |
| PR-2A | Added human-facing maintainer docs without moving canonical agent/session docs; kept new root docs out of source builds | `ARCHITECTURE.md`, `TODO.md`, `CONTRIBUTING.md`, `.Rbuildignore` |
| PR-12 prep | Added parallel-determinism characterization tests before any backend migration | `tests/testthat/test-parallel-determinism.R` |

---

### Next up — implement in this order

---

#### PR-12 — Unify parallelism backend `[large, HIGH RISK — pending confirmation]`

**Problem:** `stabl_fit()` uses `furrr::future_map` for bootstrap parallelism.
`stabl_multiomic_nested_cv()` uses a separate `cv_workers` fork. A user who
calls `future::plan(multisession, workers = 4)` before nested CV ends up with
4 × cv_workers processes; nested `future` plans silently degrade or error.

**Safety prep complete:**

- `tests/testthat/test-parallel-determinism.R` runs `stabl_fit()` with
  `workers = 1` vs `workers = 2` on identical fixed seeds and asserts
  identical stability scores.
- The same test file runs `stabl_multiomic_nested_cv()` with `cv_workers = 1`
  vs `cv_workers = 2` on fixed seeds and asserts identical predictions and
  diagnostics on Unix-like systems.

**What to do if approved:**
1. Replace the `cv_workers` fork in `nested_cv.R` with
   `furrr::future_map`-over-outer-folds wrapped in
   `future::plan(sequential)` inside each fold worker (so bootstrap-level
   parallelism is suppressed when fold-level is active).
2. Keep the old `cv_workers` code path under `use_legacy_workers = FALSE`
   for one release cycle as a rollback option.

**Rollback:** `git revert <PR-12 commit>` restores `cv_workers` immediately.

**Verify:** `devtools::test()` FAIL 0 with `workers = 2`; determinism tests pass.

---

## Size targets

| File | Lines now | Target | Achieved by |
|---|---|---|---|
| `R/multiomic_workflows.R` | 754 | < 800 | PR-9 + PR-10 + PR-11 |
| `R/nested_cv.R` | 653 | < 450 | PR-9 moved shared fold helpers; additional reductions deferred |

## Test file targets

| Module | Test file | Status |
|---|---|---|
| `metrics.R` | `test-metrics.R` | ✅ |
| `visualization.R` | `test-visualization.R` | ✅ |
| `exports.R` | `test-exports.R` | ✅ |
| `cv_helpers.R` (new) | `test-cv-helpers.R` | ✅ |
| Parallel determinism | `test-parallel-determinism.R` | ✅ safety prep complete; backend migration pending confirmation |
