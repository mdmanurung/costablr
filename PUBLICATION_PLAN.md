# stablr Application Note — Revised Publication Plan

**Target venue:** Bioinformatics Advances (Application Note, ~4 pages)  
**Package name:** `stablr` (never `costablr` or `co-stablr`)  
**Status:** In progress — package hardening phase  
**Last revised:** 2026-06-17 (post multi-panel review)

## Multi-panel review synthesis

Three reviewers evaluated the plan on 2026-06-17:

| Panel | Verdict | Key action |
|-------|---------|------------|
| Journal editor | Scope fits Application Note if framed as R implementation | Ship extdata, real metadata, one parity figure |
| R package engineer | BLOCK until extdata + fixtures restored | Green `R CMD check`, CITATION/NEWS |
| Methods validator | Parity sufficient with quantitative metrics | Jaccard + Spearman table, not just 7/7 recall |

### Consensus decisions

1. **Framing:** Software availability for the R/glmnet ecosystem — not a new STABL method paper.
2. **Primary validation:** Publication-scale Python parity on bundled OOL proteomics (500 bootstraps, knockoffs).
3. **Defer:** AURORA n=38 biology, TCGA nested-CV vs DIABLO, full Nature Biotech 5-dataset reproduction.
4. **Naming:** Package = `stablr`; method = STABL; Python = Stabl; cooperative fusion = feature inside `stablr`.
5. **Release gate:** Tag `v0.1.0` + Zenodo DOI before manuscript submission.

---

## Phase 0 — Repository recovery (P0) ✅ partial

- [x] Restore `r-pkg/stablr/` from git HEAD
- [x] Restore `PLAN.md`, `HANDOFF.md`, `PROGRESS.md`, `STABL.md`
- [x] Generate `inst/extdata/` OOL subset from Sample Data
- [x] Restore Python parity fixtures from release tarball
- [ ] Commit restored artifacts (awaiting user request)

## Phase 1 — Package hardening (P0)

- [x] Fix `generate_ool_extdata.R` script path resolution
- [x] Bump version to `0.1.0`
- [x] Add `inst/CITATION` (STABL paper + software)
- [x] Add `NEWS.md`
- [x] Replace placeholder `Authors@R` with maintainer contact
- [x] Remove `@keywords internal` from package documentation
- [ ] Regenerate `man/stablr-package.Rd` via `roxygen2::roxygenise()`
- [ ] `devtools::test()` — target FAIL 0
- [ ] `R CMD check --no-manual` — target Status: OK

## Phase 2 — Validation bundle (P1)

- [x] Add `inst/analysis/generate_publication_parity_table.R`
- [x] Run publication-scale OOL proteomics fit (500 bootstraps, seed 42)
- [x] Export parity metrics CSV: 7/7 tutorial recall, Jaccard 0.78, 9 selected
- [ ] Generate Figure 1 (workflow schematic) — manuscript asset
- [ ] Generate Figure 2 (FDP+ curve + stability path) — from OOL fit
- [ ] Write divergence ledger paragraph (glmnet vs sklearn, documented in STABL.md)

## Phase 3 — Manuscript draft (P1)

Working title (software name required):

> **stablr: an R package for stability-based biomarker discovery with FDP+ control**

- [x] Outline at `papers/application-note/OUTLINE.md`
- [ ] OUP LaTeX template draft (≤4 pages, ≤3 figures/tables, ≤15 refs)
- [ ] Structured abstract: Summary / Availability / Contact / Supplementary
- [ ] Table 1: OOL parity metrics vs Python tutorial reference

## Phase 4 — Submission package (P0 before submit)

- [ ] GitHub release `v0.1.0`
- [ ] Zenodo archive with DOI
- [ ] pkgdown site live at documented URL
- [ ] Supplementary: source tarball, parity CSV, vignette HTML
- [ ] ISCB member APC discount (optional)

---

## Figure and table plan (main text, max 3)

| Asset | Content |
|-------|---------|
| Fig 1 | Workflow: bootstrap → stability scores → FDP+ → selected features |
| Fig 2 | OOL proteomics: `plot_fdr_graph()` + `plot_stabl_path()` |
| Table 1 | Parity: \|S_Py\|, \|S_R\|, Jaccard, tutorial recall, ρ, runtime |

**Supplementary only:** COVID case study, cooperative fusion, TCGA, multi-omic late fusion.

---

## Desk-rejection risks (monitor)

- Placeholder maintainer email → fixed in 0.1.0
- Missing bundled data → fixed via `inst/extdata/`
- Method novelty overclaim → cite Nat Biotechnol 2024 prominently
- Broken software URL at submission → Zenodo + GitHub tag required
- `costablr` naming anywhere → grep audit before submit

---

## Implementation log

| Date | Item | Status |
|------|------|--------|
| 2026-06-17 | Multi-panel review | Complete |
| 2026-06-17 | Restore package source | Complete |
| 2026-06-17 | Generate `inst/extdata/` | Complete |
| 2026-06-17 | Restore parity fixtures | Complete |
| 2026-06-17 | CITATION, NEWS, DESCRIPTION 0.1.0 | Complete |
| 2026-06-17 | Publication parity rerun (full OOL tutorial data) | 7/7 recall, 0.27 min |
