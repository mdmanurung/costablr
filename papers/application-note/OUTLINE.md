# Application Note Outline — stablr

**Target:** Bioinformatics Advances, Application Note (~4 pages)  
**Title (draft):** stablr: an R package for stability-based biomarker discovery with FDP+ control

## Structured abstract (≤200 words)

### Summary

High-dimensional omic studies need sparse, reproducible biomarker sets. STABL
addresses this via bootstrap stability selection with FDP+ calibration
(Hédou et al., Nat Biotechnol 2024), but the reference implementation requires
Python. **stablr** provides a pure-R port built on `glmnet`, with grouped
bootstrap sampling, knockoff and random-permutation artificial features, and
multi-omic early, late, and cooperative fusion workflows. We validate the R
implementation on the Onset of Labor proteomics tutorial dataset at
publication-scale settings (500 bootstraps, knockoff null features) and report
concordance with the reference tutorial feature set.

### Availability and Implementation

Package name: **stablr**. Language: R (≥4.4). License: MIT. Source:
`https://github.com/gregbellan/Stabl/tree/main/r-pkg/stablr`. Install:
`devtools::install_local("r-pkg/stablr")`. Core entry point: `stabl_fit()`.
Bundled OOL data in `inst/extdata/`. Optional: `knockoff`, `multiview`,
`sparsegl`, `mixOmics`.

### Contact

mikhael.manurung@gmail.com

### Supplementary information

Parity metrics CSV, extended vignettes, Python cross-reference notebook mapping.

---

## Main text section plan (~2,400 words body budget)

| Section | Words | Content |
|---------|-------|---------|
| Introduction | 400 | STABL problem; R ecosystem gap; stablr scope; cite Nat Biotechnol 2024 |
| Implementation | 800 | `stabl_fit()` pipeline; FDP+; learners; multi-omic wrappers; naming note |
| Validation | 600 | OOL proteomics table; Figure 2; tutorial recall; runtime |
| Use case snippet | 300 | 10-line install + fit example |
| Availability | 200 | Versions, deps, Zenodo DOI (at submission) |
| References | — | ≤15: STABL paper, glmnet, knockoff, multiview, R |

## Figures (max 3)

1. **Workflow schematic** — data → bootstrap STABL → FDP+ threshold → features
2. **OOL validation** — FDP+ curve + stability path (`plot_fdr_graph`, `plot_stabl_path`)
3. **Table 1** — n, p, B, \|S\|, tutorial recall 7/7, runtime (preferred over third figure)

## What we explicitly do not claim

- Novel STABL methodology (cite original paper)
- Full reproduction of all five clinical datasets from Nat Biotechnol
- Cooperative fusion as peer-reviewed extension of STABL core
- AURORA immune-signature biology (separate application manuscript)

## Naming checklist before submission

- [ ] Title contains `stablr`
- [ ] Abstract uses `stablr`, not `costablr`
- [ ] `library(stablr)` in code example
- [ ] Availability block lists package name `stablr`
- [ ] Zenodo archive labeled `stablr`
- [ ] No `costablr` in repo grep

## Reproduction commands

```bash
# Requires Sample Data/Onset of Labor at repo root (manuscript reference).
conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R

# Development smoke check on bundled extdata only:
conda run -n R4_51 Rscript r-pkg/stablr/inst/analysis/generate_publication_parity_table.R --allow-bundled
```
