# stablr: Sparse and Reliable Biomarker Discovery in R

The `stablr` package is a pure-R port of the STABL algorithm for sparse, reliable feature selection and biomarker discovery. It supports regression, classification, and multi-omic workflows, with strict parity to the Python reference implementation.

## Features
- Lasso, elastic net, adaptive lasso, and sparse group lasso adapters
- Regression, classification, and Cox survival support
- Multi-omic integration (early, late, and cooperative fusion)
- FDP+ thresholding and artificial feature injection
- Export and visualization utilities

## Installation

```r
# From the repository root
# install.packages("devtools")
devtools::install_local("r-pkg/stablr")
```

## Getting Started

See the vignettes in `vignettes/` for end-to-end examples:
- `stablr-intro.Rmd`: Basic regression and feature selection
- `stablr-multiomic.Rmd`: Multi-omic and classification workflows

## Documentation

- Function reference: see help pages for all exported functions
- Algorithm contract: see `STABL.md` in the repository root
- For Python-to-R migration notes, see `docs/PYTHON_TO_R_MAPPING.md`

## Citation

If you use `stablr`, please cite:

Hédou, J., Marić, I., Bellan, G. et al. Discovery of sparse, reliable omic biomarkers with Stabl. Nat Biotechnol (2024). https://doi.org/10.1038/s41587-023-02033-x
