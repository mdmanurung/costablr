<img width="100%" alt="STABL" src="./front_page.png">

# stablr: STABL in R

This repository contains the original Python STABL reference code and a
production-oriented R reimplementation in `r-pkg/stablr`.

The R package, `stablr`, implements sparse and reliable biomarker discovery for
single-omic and multi-omic datasets. It is pure R, uses the `glmnet` ecosystem
for the main learners, and does not require Python or tidymodels at runtime.

## Current R Package Scope

- Core STABL stability selection via `stabl_fit()`
- FDP+ thresholding with random-permutation or knockoff artificial features
- Lasso, elastic net, adaptive lasso, and optional sparse group lasso learners
- Gaussian, binomial, multinomial, and Cox outcome support where the backend
  learner supports the family
- Strict sample-name alignment checks for matrices, outcomes, and groups
- Classic and group-aware bootstrap sampling
- Multi-omic train/validation and outer-CV workflows
- Early fusion, late fusion, and optional cooperative fusion through
  `multiview`
- Stable S3 accessors, plotting helpers, export helpers, and selection
  reproducibility metrics

The algorithm and parity contract for the R port is maintained in
[STABL.md](STABL.md). Forward work and validation evidence are tracked in
[PLAN.md](PLAN.md), [PROGRESS.md](PROGRESS.md), and [HANDOFF.md](HANDOFF.md).

## Install the R Package

From the repository root:

```r
install.packages("devtools")
devtools::install_local("r-pkg/stablr")
```

Optional features use optional dependencies:

- `ggplot2` for plotting helpers
- `knockoff` for knockoff artificial features
- `future` and `furrr` for parallel bootstrap execution
- `sparsegl` for sparse group lasso
- `multiview` for cooperative multi-omic fusion
- `mixOmics` for the TCGA vignette dataset

## Quick R Example

```r
library(stablr)

set.seed(42)
n <- 80
p <- 20
x <- matrix(
  rnorm(n * p),
  nrow = n,
  dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
)
y <- setNames(1.2 * x[, 1] - 0.8 * x[, 2] + rnorm(n), rownames(x))

lambda_grid <- auto_lambda_grid(x, y, family = "gaussian", n_lambda = 10)

fit <- stabl_fit(
  x = x,
  y = y,
  lambda_grid = lambda_grid,
  family = "gaussian",
  n_bootstraps = 50L,
  artificial_type = "random_permutation",
  random_state = 42L
)

get_feature_names_out(fit)
head(sort(get_importances(fit), decreasing = TRUE))
```

Use more bootstraps, broader lambda grids, and a held-out validation strategy
for final analyses.

## R Documentation

Canonical package documentation lives in `r-pkg/stablr`:

- Package README: [r-pkg/stablr/README.md](r-pkg/stablr/README.md)
- Vignettes: [r-pkg/stablr/vignettes](r-pkg/stablr/vignettes)
- API reference source: roxygen comments in [r-pkg/stablr/R](r-pkg/stablr/R)
- Generated Rd help pages: [r-pkg/stablr/man](r-pkg/stablr/man)
- Python-to-R mapping notes:
  [r-pkg/stablr/docs/PYTHON_TO_R_MAPPING.md](r-pkg/stablr/docs/PYTHON_TO_R_MAPPING.md)

Build vignettes:

```bash
conda run -n R4_51 Rscript -e "devtools::build_vignettes('r-pkg/stablr')"
```

Build the pkgdown documentation website:

```bash
conda run -n R4_51 Rscript -e "pkgdown::build_site('r-pkg/stablr', install = FALSE)"
```

## R Vignettes

- `stablr-intro.Rmd`: quick simulated-data start
- `stablr-multiomic.Rmd`: real OOL multi-omic train/validation workflow
- `stablr-python-parity.Rmd`: Python-to-R workflow mapping
- `stablr-tcga.Rmd`: TCGA Breast Cancer multi-omic workflow
- `stablr-cooperative.Rmd`: cooperative fusion with optional `multiview`

## Python Reference Code

The original Python implementation remains in `stabl/`, with sample scripts in
`Notebook examples/`. Use it as the behavior reference for parity checks; use
`r-pkg/stablr` for the R package.

---

## Original Python STABL README

# Discovery of sparse, reliable omic biomarkers with Stabl
[![DOI](https://img.shields.io/badge/DOI-doi:10.1038/s41587--023--02033--x-blue.svg)](https://doi.org/10.1038/s41587-023-02033-x)
[![Python version](https://img.shields.io/badge/Python-3.7%E2%80%933.12-blue.svg)](https://github.com/gregbellan/Stabl)
[![BSD 3-Clause Clear license](https://img.shields.io/badge/License-BSD%203%E2%80%93Clause-yellow.svg)](https://github.com/gregbellan/Stabl/blob/main/LICENSE)
[![BSD 3-Clause Clear license](https://img.shields.io/badge/Open-Source-orange.svg)](https://github.com/gregbellan/Stabl/blob/main/LICENSE)


[![Last full release](https://img.shields.io/badge/release-v1.0.0-blue.svg)](https://GitHub.com/gregbellan/Stabl/releases/)
[![Last light-weight release](https://img.shields.io/badge/Light--weight%20release-v1.0.0--lw-blue.svg)](https://GitHub.com/gregbellan/Stabl/releases/)
[![GitHub latest commit](https://badgen.net/github/last-commit/gregbellan/Stabl)](https://GitHub.com/gregbellan/Stabl/commit/)

[![GitHub forks](https://img.shields.io/github/forks/gregbellan/Stabl.svg?style=social&label=Fork&maxAge=2592000)](https://GitHub.com/gregbellan/Stabl/network/)
[![GitHub stars](https://img.shields.io/github/stars/gregbellan/Stabl.svg?style=social&label=Star&maxAge=2592000)](https://GitHub.com/gregbellan/Stabl/stargazers/)
[![GitHub watchers](https://img.shields.io/github/watchers/gregbellan/Stabl.svg?style=social&label=Watch&maxAge=2592000)](https://GitHub.com/gregbellan/Stabl/watchers/)

This is a scikit-learn compatible Python implementation of Stabl, coupled with useful functions and
example notebooks to rerun the analyses on the different use cases located in the `sample data` folder


## Abstract
Adoption of high-content omic technologies in clinical studies, coupled with computational methods, has yielded an abundance of candidate
biomarkers. However, translating such fndings into bona fde clinical biomarkers remains challenging. To facilitate this process, we introduce
Stabl, a general machine learning method that identifes a sparse, reliable set of biomarkers by integrating noise injection and a data-driven signal-to- noise threshold into multivariable predictive modeling. Evaluation of Stabl on synthetic datasets and fve independent clinical studies demonstrates improved biomarker sparsity and reliability compared to commonly used
sparsity-promoting regularization methods while maintaining predictive performance; it distills datasets containing 1,400–35,000 features down to 4–34 candidate biomarkers. Stabl extends to multi-omic integration tasks, enabling biological interpretation of complex predictive models, as it hones in on a shortlist of proteomic, metabolomic and cytometric events predicting labor onset, microbial biomarkers of pre-term birth and a pre-operative immune signature of post-surgical infections. 

Full content: https://rdcu.be/du2gB

### Cite us

```
Hédou, J., Marić, I., Bellan, G. et al. Discovery of sparse, reliable omic biomarkers with Stabl. Nat Biotechnol (2024). https://doi.org/10.1038/s41587-023-02033-x
```

or by following this [link](https://www.nature.com/articles/s41587-023-02033-x#citeas)

## Light-weight version

### Requirements

Python version : from 3.7 up to 3.12

Python packages:

* joblib == 1.3.2
* tqdm == 4.66.1
* matplotlib == 3.8.2
* numpy == 1.26.2
* knockpy == 1.3.1
* scikit-learn == 1.3.2
* seaborn == 0.13.0
* pandas == 2.1.4
* statsmodels == 0.14.0
* openpyxl == 3.1.2
* adjustText == 0.8
* scipy == 1.11.4
* osqp == 0.6.3

### Installation

In order to install the light-weight version of the library, you have two options:

1. Install directly from github:

```
pip install git+https://github.com/gregbellan/Stabl.git@v1.0.1-lw
```
2. Clone the repository and install the library:

    a. Download Stabl:

    ```
    git clone https://github.com/gregbellan/Stabl.git@stabl_lw
    ```
    b. Install requirements and Stabl:

    ```
    cd Stabl
    pip install .
    ```

The general installation time is less than 10 seconds, and have been tested on mac OS and linux system.

You may need to install CMake to fully use the library. Please refer to the section [CMake installation](#cmake-installation) in full version installation for more details.


## Full version

### Requirements

Python version : from 3.7 up to 3.10

Python packages:

* joblib == 1.1.0
* tqdm == 4.64.0
* matplotlib == 3.5.2
* numpy == 1.23.1
* cmake == 3.27.1
* knockpy == 1.2
* scikit-learn == 1.1.2
* seaborn == 0.12.0
* groupyr == 0.3.2
* pandas == 1.4.2
* statsmodels == 0.14.0
* openpyxl == 3.0.7
* adjustText == 0.8
* scipy == 1.10.1
* julia == 0.6.1
* osqp == 0.6.2


Julia package for noise generation (version 1.9.2) :

* Bigsimr == 0.8.7
* Distributions == 0.25.98
* PyCall == 1.96.1

### Installation

#### Julia installation
To install Julia, please follow these instructions: 

1. Download Julia from [here](https://julialang.org/downloads/).
2. Follow the instructions for your operating system [here](https://julialang.org/downloads/platform/).
3. Install the required julia packages :
    ```

    julia -e 'using Pkg; Pkg.add(name="Bigsimr", version="0.8.7"); Pkg.add(name="Distributions", version="0.25.98"); Pkg.add(name="PyCall", version="1.96.1"); Pkg.add("IJulia")'

    ```
4. Finally, install Julia for python:
    ```
    pip install julia
    python -c "import julia; julia.install()"
    ``` 

#### CMake installation

In order to install the python libraries required to generate the noise, we need to install :
* CMake (v3.27.4 for MacOS)

You can install this module by :
* using the default system package manager, like on this [website](https://cgold.readthedocs.io/en/latest/first-step/installation.html)
* following instructions on [CMake](https://cmake.org/install/).


#### Python installation (>= 3.7 and < 3.11)

Install Directly from github (install latest release):

```
pip install git+https://github.com/gregbellan/Stabl.git
pip install numpy==1.23.2

```
or 

---

Download Stabl:

```
git clone https://github.com/gregbellan/Stabl.git
```
Install requirements and Stabl:

```
cd Stabl
pip install .
pip install numpy==1.23.2
```

The general installation time is less than 10 seconds, and have been tested on mac OS and linux system.

> **_NOTE:_**  There is a behavior with Julia library:
> - you can run the script in a notebook, but you need to run the import block two times. The first will throw an error and the second one will finalize the import.
> - It is not possible to run the script in command line if you are installing the library with conda
> To resolve this issue, either you install the library without conda or you run the script into a notebook.
> 
> If there is still an issue with Julia in a notebook, run the following command in the first cell of the notebook:
> ```
> from julia.api import Julia
> jl = Julia(compiled_modules=False) 
> ```

## Use of the library

To use the library and the associated benchmark in the folder `Notebook examples`, you need to download the repository :

```
git clone https://github.com/gregbellan/Stabl.git
cd Stabl/
unzip Sample\ Data/data.zip -d Sample\ Data/
```

### Benchmarks
* `Tutorial Notebook.ipynb`: Tutorial on how to use the library
* `run_cv_*.py`: Python scripts to run the sample datas in Cross-Validation
* `run_val_*.py`: Python scripts to run the sample datas in Training-Validation
* `run_synthetic_*.py`: Python scripts to run the synthetic benchmarks. _Available only for the full version of the library._

> **_NOTE:_** 
> The different scripts may take some time to begin because of the dependence with julia. However, once started, the 
> time to run should come back to normal.

## Input data
When using your own data, you have to provide

* The preprocessed input data matrix (preferably a pandas DataFrame having column names)
* The outcomes (preferably a pandas Series having a names)
* (Input Data and outcomes should have the same indices)

## Sample Data

The "Sample Data" folder contains data for the following use cases:
### Onset of Labor
#### Training
* **Outcome**: Days before Labor, `150` samples — `53` patients 
* **Proteomics**: `150` samples — `1317` biomarkers
* **CyTOF**: `150` samples — `1502` biomarkers
* **Metabolomics**: `150` samples — `3529` biomarkers 
#### Validation
* **Outcome**: Days before Labor, `27` samples — `10` patients 
* **Proteomics**: `21` samples — `1317` biomarkers
* **CyTOF**: `27` samples — `1502` biomarkers

### COVID-19
#### Training
* **Outcome**: Mild/Moderate (`43`) Vs. Severe (`25`)
* **Proteomics**: `68` samples — `1463` biomarkers
#### Validation
* **Outcome**: Mild/Moderate (`125`) Vs. Severe (`659`)
* **Proteomics**: `784` samples — `1420` biomarkers

### CFRNA Preeclampsia
#### Training
* **Outcome**: Control (`63`) Vs. Preeclampsia (`96`) — `48` patients
* **CFRNA**: `159` samples — `37184` biomarkers

### Surgical Site Infections (SSI)
#### Training
* **Outcome**: Control (`77`) Vs. SSI (`16`)
* **CyTOF**: `93` samples — `1125` biomarkers
* **Proteomics**: `91` samples — `721` biomarkers

### Dream
#### Training
* **Outcome**: Preterm (`609`) Vs. Non-preterm (`960`) - 580 patients
* **Taxonomy**: `1569` samples — `3725` biomarkers
* **Phylotype**: `1569` samples — `5468` biomarkers
