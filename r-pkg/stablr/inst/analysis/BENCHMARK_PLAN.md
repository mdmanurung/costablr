# Benchmark plan: stablr vs Python STABL vs DIABLO

This document defines a reproducible, fair comparison program across three
toolchains that answer **related but not identical** scientific questions.

| Toolchain | Primary question | Reference implementation |
|-----------|------------------|--------------------------|
| **Python STABL** | Which features are **stably selected** with FDP+ control? | `stabl/` (reference) |
| **stablr** | Same stability-selection semantics in R + multi-omic fusion | `r-pkg/stablr` |
| **DIABLO** (mixOmics) | How do blocks combine in a **sparse latent discriminant** space? | `mixOmics::block.splsda` |

Benchmarks must state the evaluation layer explicitly:

1. **Selection layer** — feature lists, stability/recurrence, FDP proxies.
2. **Prediction layer** — held-out accuracy / BER / survival C-index after a
   declared downstream model (required for DIABLO vs stablr classification).

---

## Phase 0 — Vignette and infrastructure audit (complete / ongoing)

| Vignette | Coverage | DIABLO / Python STABL link |
|----------|----------|----------------------------|
| `stablr-intro` | Single-omic STABL, learners, plots | Points to `stablr-python-parity` |
| `stablr-multiomic` | OOL early/late fusion, export | Python tutorial preprocessing note |
| `stablr-cooperative` | Native cooperative fusion (gaussian/binomial) | No DIABLO analogue |
| `stablr-advanced` | Cox, multinomial, knockoffs, grouped bootstrap, outer CV | Extends intro; no head-to-head |
| `stablr-python-parity` | Workflow mapping OOL + COVID to Python notebook | **Primary Python STABL parity surface** |
| `stablr-tcga` | TCGA workflow translation + qualitative mixOmics table | Qualitative comparison only |
| `stablr-tcga-nestedcv` | Nested-CV head-to-head vs DIABLO (cache-driven) | **Primary DIABLO benchmark vignette** |

Existing analysis scripts:

- `inst/analysis/generate_publication_parity_table.R` — OOL proteomics vs Python scores.
- `inst/analysis/run_tcga_nestedcv.R` + `tcga_nestedcv.slurm` — TCGA nested-CV vs DIABLO.
- `tests/testthat/test-python-parity-fixtures.R` — frozen numeric parity vs Python.

---

## Phase 1 — Python STABL parity (selection semantics)

**Goal:** Demonstrate that `stablr` reproduces Python STABL **selection** behaviour on
fixed seeds, not that R beats Python on prediction.

### Datasets

| Dataset | Task | Source | Already in repo? |
|---------|------|--------|------------------|
| OOL proteomics train | Gaussian regression | `Sample Data/Onset of Labor` | Yes (tutorial + bundled subset) |
| COVID proteomics | Binomial | `Sample Data/COVID-19` | Tutorial only |
| Frozen fixtures | gaussian/binomial/elastic-net | `tests/testthat/fixtures/python_parity/` | Yes |
| Nature Biotech Table 1 cohorts | Mixed | Paper supplementary | **Backlog** (5 datasets) |

### Metrics (selection layer)

| Metric | Definition | Pass criterion |
|--------|------------|----------------|
| Max-score correlation | `cor(R_max, Py_max)` per feature | ≥ 0.95 (fixtures); ≥ 0.90 publication |
| Support Jaccard | Selected feature sets | ≥ 0.80 on full tutorial settings |
| Threshold delta | `|fdr_min_threshold_R - fdr_min_threshold_Py|` | ≤ 0.05 |
| Lambda grid alignment | Same `n_lambda`, same `lambda` sequence | Exact on shared preprocessing |

### Protocol

1. Shared preprocessing chain (variance filter → missingness → median impute → scale).
2. Fixed `random_state = 42`, `n_bootstraps` matched to notebook (500 OOL, 1000 COVID).
3. Artificial features: knockoff (OOL), random permutation (COVID default).
4. Run `generate_publication_parity_table.R` → manuscript artifact CSV.
5. CI gate: `test-python-parity-fixtures.R` on every PR.

### Deliverables

- [ ] Publication parity table in `papers/application-note/artifacts/`
- [ ] CI badge / test filter `python-parity` green on HPC (`R4_51`)
- [ ] Vignette `stablr-python-parity.Rmd` documents extended vs quick-build settings

---

## Phase 2 — DIABLO head-to-head (prediction + recurrence)

**Goal:** Compare **honest nested-CV predictive performance** and **feature
recurrence** on a shared multi-block classification task.

**Existing implementation:** `run_tcga_nestedcv.R` (mRNA + miRNA, PAM50 3-class).

### Fairness contract (must hold for all methods)

1. No feature filtering, scaling, or selection on the full dataset before outer CV.
2. Same sample set and outcome definition for both methods (protein block excluded
   when not available for all samples — current design).
3. Report **outer-fold** metrics only; inner folds used for tuning only.
4. Document downstream prediction rule for stablr (candidate workflows:
   mRNA-only, miRNA-only, early fusion; inner-CV BER picks candidate).
5. Document DIABLO pipeline: `block.plsda` → `perf` (ncomp) → `tune.block.splsda`
   (keepX) → `centroids.dist` prediction.
6. Report paired fold-wise deltas + bootstrap CI on mean delta (not only aggregate).

### Metrics

| Layer | Metric | stablr | DIABLO |
|-------|--------|--------|--------|
| Prediction | Accuracy, balanced error rate, macro-F1 | Outer CV | Outer CV |
| Prediction | Per-class recall / confusion | Yes | Yes |
| Selection | Feature recurrence frequency | Per outer train | `selectVar` loadings |
| Selection | Median #features per fold | Yes | keepX sum |
| Selection | Cross-method Jaccard (recurrent sets) | Yes | Yes |
| Compute | Wall time per outer fold | Log | Log |

### Extensions (Phase 2b)

| Extension | Rationale |
|-----------|-----------|
| Add **late fusion** and **cooperative** stablr candidates | Tests integration modes DIABLO does not offer |
| Add **sgccaDA** (mixOmics Chapter 6) as third baseline | Matches original TCGA vignette reference |
| Repeat with **protein block** on train-only subset | Sensitivity analysis (n reduced) |
| 5×2 or 10×10 nested CV | Reduce variance vs current k-fold |
| External validation on held-out `breast.TCGA` test labels | Confirmatory (not used for tuning) |

### Deliverables

- [ ] Full (non-smoke) `tcga_nestedcv_results.rds` on SLURM
- [ ] CSV exports: performance, recurrence, overlap (already scripted)
- [ ] Vignette `stablr-tcga-nestedcv.Rmd` renders with cache
- [ ] One-page interpretation table (pros/cons) in vignette — see below

---

## Phase 3 — Unified benchmark matrix (stablr integration modes)

Run all stablr fusion modes under **identical** STABL settings on the same folds:

| Mode | Function | Comparable to DIABLO? |
|------|----------|---------------------|
| Per-omic | `fits$<omic>` only | Partially (single block DIABLO) |
| Early fusion | `early_fusion` | No direct analogue |
| Late fusion | `late_fusion` | Ensemble, not latent |
| Cooperative | `cooperative_fusion` | Closest philosophically (multi-block coupling) |

Fixed STABL hyperparameters per dataset; only fusion mode varies.

Metrics: same as Phase 2 + stability of selected features across outer folds
(`jaccard_matrix` on per-fold selections).

---

## Phase 4 — Reporting and objectivity rules

### What we can claim

- stablr **matches** Python STABL on selection metrics under stated preprocessing.
- On TCGA nested-CV, method A has lower BER than method B **on this dataset,
  this tuning budget, this fold scheme** (report CIs).
- Feature lists **overlap partially** between stability selection and DIABLO
  loadings; recurrence profiles differ.

### What we cannot claim

- stablr is universally better than DIABLO for prediction (dataset-dependent).
- DIABLO features are “unstable” — it does not optimise stability; different objective.
- Cooperative fusion equals DIABLO when `rho = 0` (early fusion STABL ≠ DIABLO).

### Suggested manuscript figure set

1. Python parity: score scatter + support Venn (OOL).
2. TCGA: paired BER dot plot per outer fold (stablr vs DIABLO).
3. TCGA: recurrence bar chart per block (top 20 features).
4. Runtime / selection sparsity trade-off panel.

---

## Implementation checklist

| ID | Task | Owner script | Status |
|----|------|--------------|--------|
| B1 | Full TCGA nested-CV run | `tcga_nestedcv.slurm` | Pending full run |
| B2 | OOL publication parity | `generate_publication_parity_table.R` | Script exists |
| B3 | Add cooperative candidate to TCGA benchmark | `run_tcga_nestedcv.R` | Not started |
| B4 | Add sgccaDA baseline | new helper in `run_tcga_nestedcv.R` | Not started |
| B5 | Bootstrap CI on paired fold deltas | vignette or script | Not started |
| B6 | Nature Biotech 5-dataset port | new `run_nb_benchmark.R` | Backlog |
| B7 | Benchmark summary CSV → pkgdown article | `docs/stablr/articles/` | After B1–B2 |

---

## Environment

```bash
# Python parity
conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R

# TCGA smoke
conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/run_tcga_nestedcv.R \
  --cache /tmp/tcga_nestedcv_smoke.rds --force --smoke

# TCGA production
sbatch r-pkg/stablr/inst/analysis/tcga_nestedcv.slurm

# Tests
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter='parity')"
```
