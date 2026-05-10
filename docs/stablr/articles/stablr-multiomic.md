# Multi-Omic Biomarker Discovery with stablr

## Overview

This vignette demonstrates multi-omic biomarker discovery using the
`stablr` package on a real Onset of Labor (OOL) dataset. The dataset
contains two omic layers (CyTOF and Proteomics) measured in pregnant
women. The prediction target is days-to-onset-of-labor (DOS), a
continuous regression outcome. The settings are intentionally bounded
for package builds while preserving the shape of a real train/validation
analysis.

**Why multi-omic?** Single-omic analyses can miss biomarkers that are
individually weak but collectively informative. By combining immune-cell
profiling (CyTOF) with protein abundance (Proteomics), we can ask
whether each layer contributes independent signal and how to integrate
them optimally.

We cover:

1.  Loading the bundled example data with
    [`load_ool_data()`](https://gregbellan.github.io/Stabl/stablr/reference/load_ool_data.md).
2.  Running per-omic STABL — a useful baseline before integration.
3.  Running the integrated multi-omic workflow with **early fusion** and
    **late fusion**.
4.  Comparing selected features across strategies.
5.  Exporting results.

## Learning objectives

By the end of this vignette you will be able to:

1.  Understand the data structure returned by
    [`load_ool_data()`](https://gregbellan.github.io/Stabl/stablr/reference/load_ool_data.md).
2.  Run STABL independently on each omic and interpret the outputs.
3.  Explain the difference between early fusion and late fusion.
4.  Run
    [`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
    and navigate its result list.
5.  Compare which features appear across integration strategies.
6.  Export results for downstream use.

``` r
library(stablr)
```

------------------------------------------------------------------------

## 1. Load the data

[`load_ool_data()`](https://gregbellan.github.io/Stabl/stablr/reference/load_ool_data.md)
reads the pre-bundled OOL subset directly from the package. No file
paths are needed. It returns a named list with two elements:

- **`$x_list`**: a named list of feature matrices, one per omic layer.
  Each matrix has samples in rows and features in columns, with matching
  row names.
- **`$y`**: a named numeric vector of outcomes (DOS in days), aligned to
  the rows of every matrix in `$x_list`.

``` r
ool_train <- load_ool_data(split = "train")
ool_valid <- load_ool_data(split = "valid")

# Training set dimensions
lapply(ool_train$x_list, dim)
#> $cytof
#> [1] 150 100
#> 
#> $proteomics
#> [1] 150 100
length(ool_train$y)
#> [1] 150

# Validation set dimensions
lapply(ool_valid$x_list, dim)
#> $cytof
#> [1]  21 100
#> 
#> $proteomics
#> [1]  21 100
```

The `lapply(..., dim)` output confirms that CyTOF and Proteomics share
the same number of rows (samples) but differ in columns (features). The
names of rows must match across omics — `stablr` checks this alignment
automatically and stops with an informative error if it detects a
mismatch.

``` r
# Outcome distribution (DOS = days before onset of labor)
summary(ool_train$y)
#>    Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
#> -113.00  -70.75  -35.50  -43.39  -15.00    0.00
```

The [`summary()`](https://rdrr.io/r/base/summary.html) output shows the
range of DOS values. A wide range is expected (e.g. 0-90 days); note
whether the distribution is roughly symmetric or skewed, as this informs
how predictable the outcome may be from molecular data.

------------------------------------------------------------------------

## 2. Per-omic STABL

Before running the integrated pipeline, it is instructive to see which
features STABL selects in each omic independently. This per-omic step
serves two purposes:

1.  **Sanity check** — does each omic contain any signal at all? If
    STABL selects zero features from an omic, that layer may not
    contribute useful information to the integrated analysis.
2.  **Baseline** — the per-omic biomarker lists can be compared to the
    integrated results to see which features survive the joint analysis.

We use `n_bootstraps = 80` and compact 15-point lambda grids throughout
this vignette. Increase to 500-1000 bootstraps and broader grids for
publication-quality results.

**Reading the printed summary:** after printing each fit, look at (1)
the number of features selected and (2) the FDP estimate. A small number
of selected features with a low FDP (\< 0.05) is the ideal outcome.

``` r
lambda_cytof <- auto_lambda_grid(
  ool_train$x_list$cytof, ool_train$y,
  family = "gaussian", n_lambda = 15
)
```

``` r
fit_cytof <- stabl_fit(
  x               = ool_train$x_list$cytof,
  y               = ool_train$y,
  lambda_grid     = lambda_cytof,
  family          = "gaussian",
  n_bootstraps    = 80L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_cytof
#> <stabl_fit>
#>   Features in:      100 
#>   Features selected: 0 
#>   Min FDP+:         1 
#>   FDP+ threshold:   1 
#>   Artificial:       random_permutation
```

``` r
lambda_prot <- auto_lambda_grid(
  ool_train$x_list$proteomics, ool_train$y,
  family = "gaussian", n_lambda = 15
)

fit_prot <- stabl_fit(
  x               = ool_train$x_list$proteomics,
  y               = ool_train$y,
  lambda_grid     = lambda_prot,
  family          = "gaussian",
  n_bootstraps    = 80L,
  artificial_type = "random_permutation",
  random_state    = 42L
)
fit_prot
#> <stabl_fit>
#>   Features in:      100 
#>   Features selected: 2 
#>   Min FDP+:         0.5 
#>   FDP+ threshold:   0.98 
#>   Artificial:       random_permutation
```

[`get_support()`](https://gregbellan.github.io/Stabl/stablr/reference/get_support.md)
returns the feature names that passed the stability threshold in each
omic. Compare the two lists: non-overlapping features suggest
omic-specific biomarkers, while any overlap (if the same molecule is
measured in both layers) indicates high-confidence candidates.

``` r
cat("CyTOF selected features:
")
#> CyTOF selected features:
print(get_support(fit_cytof))
#>     Granulocytes_CREB_unstim    Granulocytes_STAT5_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_p38_unstim    Granulocytes_STAT1_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT3_unstim       Granulocytes_S6_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_IkB_unstim Granulocytes_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>     Granulocytes_NFkB_unstim      Granulocytes_ERK_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT6_unstim           Bcells_CREB_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT5_unstim            Bcells_p38_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT1_unstim          Bcells_STAT3_unstim 
#>                        FALSE                        FALSE 
#>             Bcells_S6_unstim            Bcells_IkB_unstim 
#>                        FALSE                        FALSE 
#>       Bcells_MAPKAPK2_unstim           Bcells_NFkB_unstim 
#>                        FALSE                        FALSE 
#>            Bcells_ERK_unstim          Bcells_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_CREB_unstim            cMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_p38_unstim            cMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT3_unstim               cMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_IkB_unstim         cMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_NFkB_unstim              cMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT6_unstim      CCR2poscMCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT5_unstim       CCR2poscMCs_p38_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT1_unstim     CCR2poscMCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>        CCR2poscMCs_S6_unstim       CCR2poscMCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>  CCR2poscMCs_MAPKAPK2_unstim      CCR2poscMCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>       CCR2poscMCs_ERK_unstim     CCR2poscMCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_CREB_unstim           MDSCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_p38_unstim           MDSCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT3_unstim              MDSCs_S6_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_IkB_unstim        MDSCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_NFkB_unstim             MDSCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT6_unstim              DCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT5_unstim               DCs_p38_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT1_unstim             DCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>                DCs_S6_unstim               DCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>          DCs_MAPKAPK2_unstim              DCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>               DCs_ERK_unstim             DCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_CREB_unstim            mDCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_p38_unstim            mDCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT3_unstim               mDCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_IkB_unstim         mDCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_NFkB_unstim              mDCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT6_unstim             pDCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT5_unstim              pDCs_p38_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT1_unstim            pDCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>               pDCs_S6_unstim              pDCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>         pDCs_MAPKAPK2_unstim             pDCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>              pDCs_ERK_unstim            pDCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_CREB_unstim          intMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_p38_unstim          intMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT3_unstim             intMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_IkB_unstim       intMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_NFkB_unstim            intMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT6_unstim    CCR2posintMCs_CREB_unstim 
#>                        FALSE                        FALSE

cat("
Proteomics selected features:
")
#> 
#> Proteomics selected features:
print(get_support(fit_prot))
#>                       CHIP                      CEBPB 
#>                      FALSE                      FALSE 
#>                        NSE                      PIAS4 
#>                      FALSE                      FALSE 
#>                   IL.10.Ra                      STAT3 
#>                      FALSE                      FALSE 
#>                       IRF1                      c.Jun 
#>                      FALSE                      FALSE 
#>                      Mcl.1                       OAS1 
#>                      FALSE                      FALSE 
#>                      c.Myc                      SMAD3 
#>                      FALSE                      FALSE 
#>                      SMAD2                      IL.23 
#>                      FALSE                      FALSE 
#>                     PDGFRA                      IL.12 
#>                      FALSE                      FALSE 
#>                      STAT1                      STAT6 
#>                      FALSE                      FALSE 
#>                      LRRK2                Osteocalcin 
#>                      FALSE                      FALSE 
#>                       IL.5                       GPDA 
#>                      FALSE                      FALSE 
#>                        IgA                       LPPL 
#>                      FALSE                      FALSE 
#>                      HEMK2                       PDXK 
#>                       TRUE                      FALSE 
#>                       TLR4                       REG4 
#>                      FALSE                      FALSE 
#>                     HSP.27                     YKL.40 
#>                      FALSE                      FALSE 
#>              Alpha.enolase                     Apo.L1 
#>                      FALSE                      FALSE 
#>                       CD38                       CD59 
#>                      FALSE                      FALSE 
#>                      FABPL                     GDF.11 
#>                      FALSE                      FALSE 
#>                        BTC                     HIF.1a 
#>                      FALSE                      FALSE 
#>                     S100A6                     SECTM1 
#>                      FALSE                      FALSE 
#>                      RSPO3                        PSP 
#>                      FALSE                      FALSE 
#>  Apoptosis.regulator.Bcl.W                     VEGF.D 
#>                      FALSE                      FALSE 
#>                       SOST                      FAM3D 
#>                      FALSE                      FALSE 
#>                        CSH                      EFNB1 
#>                      FALSE                      FALSE 
#>                      SNP25                      LYPD3 
#>                      FALSE                      FALSE 
#>                      NEGR1                       BCL6 
#>                      FALSE                      FALSE 
#>                      FSTL1                Osteopontin 
#>                      FALSE                      FALSE 
#>                    Lumican                      CD177 
#>                      FALSE                      FALSE 
#>                       CHKB                      SMOC1 
#>                      FALSE                      FALSE 
#>        protein.Z.inhibitor                      FLRT2 
#>                      FALSE                      FALSE 
#>                      FLRT3                      ISLR2 
#>                      FALSE                      FALSE 
#>                Vitronectin                       DSC2 
#>                      FALSE                      FALSE 
#>                       LDLR                       HXK2 
#>                      FALSE                      FALSE 
#>                       HXK1                      SEM5A 
#>                      FALSE                      FALSE 
#>                      LTBP4                      PIANP 
#>                      FALSE                      FALSE 
#>             Adrenomedullin                     S100A4 
#>                      FALSE                      FALSE 
#>                      RNF43                   TRAIL.R4 
#>                      FALSE                      FALSE 
#>                      ZNRF3                       GI24 
#>                      FALSE                      FALSE 
#>                  Ephrin.A2                       ApoM 
#>                      FALSE                      FALSE 
#>                      IFN.b                      IFN10 
#>                      FALSE                      FALSE 
#>                      IFNA7                      EFNB2 
#>                      FALSE                      FALSE 
#>                      HHLA2                  IL.1.sRII 
#>                      FALSE                      FALSE 
#>                      AMGO2                      RXFP1 
#>                      FALSE                      FALSE 
#>                      C1QR1                       NRG4 
#>                      FALSE                      FALSE 
#>                      H2B2E                       H2A3 
#>                       TRUE                      FALSE 
#>                        H31                      IFN.g 
#>                      FALSE                      FALSE 
#>                     IL.1F8                     IL.1F6 
#>                      FALSE                      FALSE 
#>                       UCRP                  Ephrin.A3 
#>                      FALSE                      FALSE 
#> X14.3.3.protein.beta.alpha                   X14.3.3E 
#>                      FALSE                      FALSE 
#>                  Annexin.V                  Myostatin 
#>                      FALSE                      FALSE
```

**Stability path guidance:** each line in the plot is one feature.
Features with high selection frequencies at moderate penalty levels (the
plateau region of the curve) are the most reliably detected. Features
that spike at very low penalty (far left) and drop quickly are likely
noise rather than signal.

``` r
plot_stabl_path(fit_cytof,     title = "CyTOF - stability path")
```

![Stability paths for CyTOF and
Proteomics](stablr-multiomic_files/figure-html/plot-per-omic-1.png)

``` r
plot_stabl_path(fit_prot,      title = "Proteomics - stability path")
```

![Stability paths for CyTOF and
Proteomics](stablr-multiomic_files/figure-html/plot-per-omic-2.png)

------------------------------------------------------------------------

## 3. Integrated multi-omic workflow

[`stabl_multiomic_train_validate()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_train_validate.md)
orchestrates the full pipeline in a single call. It accepts training and
validation splits and evaluates two complementary integration
strategies:

| Strategy | How it works | Best when |
|----|----|----|
| **Early fusion** | Concatenates all omic matrices into one wide matrix, then runs a *single* STABL fit across all features jointly. | Omics are measured on the same samples; you want a unified biomarker list. |
| **Late fusion** | Fits one STABL + downstream model per omic separately, then learns the optimal weighted combination of predictions on the validation set. | You want to know each omic’s independent predictive contribution. |

Key arguments:

| Argument | Purpose |
|----|----|
| `x_train_list` / `x_valid_list` | Named lists of feature matrices; names must match between train and valid. |
| `lambda_grid` | Named list of lambda grids, one per omic (names must match `x_train_list`). |
| `early_fusion` / `late_fusion` | Toggle each strategy on or off independently. |
| `n_iter_lf` | Number of optimisation iterations for the late-fusion weight search. |

The printed `multi_fit` object summarises the result of every strategy
and reports validation metrics (Spearman rho for regression, AUROC for
classification) so you can compare strategies at a glance.

``` r
# Build per-omic lambda grids
lambda_list <- list(
  cytof      = auto_lambda_grid(ool_train$x_list$cytof,
                                ool_train$y, family = "gaussian", n_lambda = 15),
  proteomics = auto_lambda_grid(ool_train$x_list$proteomics,
                                ool_train$y, family = "gaussian", n_lambda = 15)
)
```

``` r
multi_fit <- stabl_multiomic_train_validate(
  x_train_list    = ool_train$x_list,
  y_train         = ool_train$y,
  lambda_grid     = lambda_list,
  x_valid_list    = ool_valid$x_list,
  y_valid         = ool_valid$y,
  family          = "gaussian",
  n_bootstraps    = 80L,
  artificial_type = "random_permutation",
  early_fusion    = TRUE,
  late_fusion     = TRUE,
  n_iter_lf       = 500L,
  random_state    = 42L
)

multi_fit
#> <stabl_multiomic_fit>
#>   Omics:           2 (cytof, proteomics)
#>   Per-omic selected features:
#>     cytof: 0
#>     proteomics: 2
#>   Validation data:  yes 
#>   Early fusion:     yes (3 features selected) 
#>   Late fusion:      yes (score = 0.3607)
```

------------------------------------------------------------------------

## 4. Exploring results

`multi_fit` is a list with the following elements:

- **`$fits`**: named list of `stabl_fit` objects, one per omic. These
  are the per-omic STABL results produced *within* the joint pipeline.
- **`$early_fusion`**: result of the early-fusion step (if
  `early_fusion = TRUE`), containing `$fit` (a `stabl_fit` on the
  concatenated matrix).
- **`$late_fusion`**: result of the late-fusion step (if
  `late_fusion = TRUE`), containing `$valid_predictions` (validation
  predictions) and `$weights` (per-omic importance weights).

``` r
# Per-omic selected features from the joint pipeline
cat("CyTOF (from multi-omic pipeline):
")
#> CyTOF (from multi-omic pipeline):
print(get_support(multi_fit$fits$cytof))
#>     Granulocytes_CREB_unstim    Granulocytes_STAT5_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_p38_unstim    Granulocytes_STAT1_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT3_unstim       Granulocytes_S6_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_IkB_unstim Granulocytes_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>     Granulocytes_NFkB_unstim      Granulocytes_ERK_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT6_unstim           Bcells_CREB_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT5_unstim            Bcells_p38_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT1_unstim          Bcells_STAT3_unstim 
#>                        FALSE                        FALSE 
#>             Bcells_S6_unstim            Bcells_IkB_unstim 
#>                        FALSE                        FALSE 
#>       Bcells_MAPKAPK2_unstim           Bcells_NFkB_unstim 
#>                        FALSE                        FALSE 
#>            Bcells_ERK_unstim          Bcells_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_CREB_unstim            cMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_p38_unstim            cMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT3_unstim               cMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_IkB_unstim         cMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_NFkB_unstim              cMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT6_unstim      CCR2poscMCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT5_unstim       CCR2poscMCs_p38_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT1_unstim     CCR2poscMCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>        CCR2poscMCs_S6_unstim       CCR2poscMCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>  CCR2poscMCs_MAPKAPK2_unstim      CCR2poscMCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>       CCR2poscMCs_ERK_unstim     CCR2poscMCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_CREB_unstim           MDSCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_p38_unstim           MDSCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT3_unstim              MDSCs_S6_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_IkB_unstim        MDSCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_NFkB_unstim             MDSCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT6_unstim              DCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT5_unstim               DCs_p38_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT1_unstim             DCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>                DCs_S6_unstim               DCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>          DCs_MAPKAPK2_unstim              DCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>               DCs_ERK_unstim             DCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_CREB_unstim            mDCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_p38_unstim            mDCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT3_unstim               mDCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_IkB_unstim         mDCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_NFkB_unstim              mDCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT6_unstim             pDCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT5_unstim              pDCs_p38_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT1_unstim            pDCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>               pDCs_S6_unstim              pDCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>         pDCs_MAPKAPK2_unstim             pDCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>              pDCs_ERK_unstim            pDCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_CREB_unstim          intMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_p38_unstim          intMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT3_unstim             intMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_IkB_unstim       intMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_NFkB_unstim            intMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT6_unstim    CCR2posintMCs_CREB_unstim 
#>                        FALSE                        FALSE

cat("
Proteomics (from multi-omic pipeline):
")
#> 
#> Proteomics (from multi-omic pipeline):
print(get_support(multi_fit$fits$proteomics))
#>                       CHIP                      CEBPB 
#>                      FALSE                      FALSE 
#>                        NSE                      PIAS4 
#>                      FALSE                      FALSE 
#>                   IL.10.Ra                      STAT3 
#>                      FALSE                      FALSE 
#>                       IRF1                      c.Jun 
#>                      FALSE                      FALSE 
#>                      Mcl.1                       OAS1 
#>                      FALSE                      FALSE 
#>                      c.Myc                      SMAD3 
#>                      FALSE                      FALSE 
#>                      SMAD2                      IL.23 
#>                      FALSE                      FALSE 
#>                     PDGFRA                      IL.12 
#>                      FALSE                      FALSE 
#>                      STAT1                      STAT6 
#>                      FALSE                      FALSE 
#>                      LRRK2                Osteocalcin 
#>                      FALSE                      FALSE 
#>                       IL.5                       GPDA 
#>                      FALSE                      FALSE 
#>                        IgA                       LPPL 
#>                      FALSE                      FALSE 
#>                      HEMK2                       PDXK 
#>                       TRUE                      FALSE 
#>                       TLR4                       REG4 
#>                      FALSE                      FALSE 
#>                     HSP.27                     YKL.40 
#>                      FALSE                      FALSE 
#>              Alpha.enolase                     Apo.L1 
#>                      FALSE                      FALSE 
#>                       CD38                       CD59 
#>                      FALSE                      FALSE 
#>                      FABPL                     GDF.11 
#>                      FALSE                      FALSE 
#>                        BTC                     HIF.1a 
#>                      FALSE                      FALSE 
#>                     S100A6                     SECTM1 
#>                      FALSE                      FALSE 
#>                      RSPO3                        PSP 
#>                      FALSE                      FALSE 
#>  Apoptosis.regulator.Bcl.W                     VEGF.D 
#>                      FALSE                      FALSE 
#>                       SOST                      FAM3D 
#>                      FALSE                      FALSE 
#>                        CSH                      EFNB1 
#>                      FALSE                      FALSE 
#>                      SNP25                      LYPD3 
#>                      FALSE                      FALSE 
#>                      NEGR1                       BCL6 
#>                      FALSE                      FALSE 
#>                      FSTL1                Osteopontin 
#>                      FALSE                      FALSE 
#>                    Lumican                      CD177 
#>                      FALSE                      FALSE 
#>                       CHKB                      SMOC1 
#>                      FALSE                      FALSE 
#>        protein.Z.inhibitor                      FLRT2 
#>                      FALSE                      FALSE 
#>                      FLRT3                      ISLR2 
#>                      FALSE                      FALSE 
#>                Vitronectin                       DSC2 
#>                      FALSE                      FALSE 
#>                       LDLR                       HXK2 
#>                      FALSE                      FALSE 
#>                       HXK1                      SEM5A 
#>                      FALSE                      FALSE 
#>                      LTBP4                      PIANP 
#>                      FALSE                      FALSE 
#>             Adrenomedullin                     S100A4 
#>                      FALSE                      FALSE 
#>                      RNF43                   TRAIL.R4 
#>                      FALSE                      FALSE 
#>                      ZNRF3                       GI24 
#>                      FALSE                      FALSE 
#>                  Ephrin.A2                       ApoM 
#>                      FALSE                      FALSE 
#>                      IFN.b                      IFN10 
#>                      FALSE                      FALSE 
#>                      IFNA7                      EFNB2 
#>                      FALSE                      FALSE 
#>                      HHLA2                  IL.1.sRII 
#>                      FALSE                      FALSE 
#>                      AMGO2                      RXFP1 
#>                      FALSE                      FALSE 
#>                      C1QR1                       NRG4 
#>                      FALSE                      FALSE 
#>                      H2B2E                       H2A3 
#>                       TRUE                      FALSE 
#>                        H31                      IFN.g 
#>                      FALSE                      FALSE 
#>                     IL.1F8                     IL.1F6 
#>                      FALSE                      FALSE 
#>                       UCRP                  Ephrin.A3 
#>                      FALSE                      FALSE 
#> X14.3.3.protein.beta.alpha                   X14.3.3E 
#>                      FALSE                      FALSE 
#>                  Annexin.V                  Myostatin 
#>                      FALSE                      FALSE
```

``` r
# Early fusion: joint selection across all omics simultaneously
if (!is.null(multi_fit$early_fusion)) {
  cat("Early fusion selected features:\n")
  print(get_support(multi_fit$early_fusion$fit))
}
#> Early fusion selected features:
#>     Granulocytes_CREB_unstim    Granulocytes_STAT5_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_p38_unstim    Granulocytes_STAT1_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT3_unstim       Granulocytes_S6_unstim 
#>                        FALSE                        FALSE 
#>      Granulocytes_IkB_unstim Granulocytes_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>     Granulocytes_NFkB_unstim      Granulocytes_ERK_unstim 
#>                        FALSE                        FALSE 
#>    Granulocytes_STAT6_unstim           Bcells_CREB_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT5_unstim            Bcells_p38_unstim 
#>                        FALSE                        FALSE 
#>          Bcells_STAT1_unstim          Bcells_STAT3_unstim 
#>                        FALSE                        FALSE 
#>             Bcells_S6_unstim            Bcells_IkB_unstim 
#>                        FALSE                        FALSE 
#>       Bcells_MAPKAPK2_unstim           Bcells_NFkB_unstim 
#>                        FALSE                        FALSE 
#>            Bcells_ERK_unstim          Bcells_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_CREB_unstim            cMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_p38_unstim            cMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT3_unstim               cMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              cMCs_IkB_unstim         cMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             cMCs_NFkB_unstim              cMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            cMCs_STAT6_unstim      CCR2poscMCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT5_unstim       CCR2poscMCs_p38_unstim 
#>                        FALSE                        FALSE 
#>     CCR2poscMCs_STAT1_unstim     CCR2poscMCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>        CCR2poscMCs_S6_unstim       CCR2poscMCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>  CCR2poscMCs_MAPKAPK2_unstim      CCR2poscMCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>       CCR2poscMCs_ERK_unstim     CCR2poscMCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_CREB_unstim           MDSCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_p38_unstim           MDSCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT3_unstim              MDSCs_S6_unstim 
#>                        FALSE                        FALSE 
#>             MDSCs_IkB_unstim        MDSCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>            MDSCs_NFkB_unstim             MDSCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>           MDSCs_STAT6_unstim              DCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT5_unstim               DCs_p38_unstim 
#>                        FALSE                        FALSE 
#>             DCs_STAT1_unstim             DCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>                DCs_S6_unstim               DCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>          DCs_MAPKAPK2_unstim              DCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>               DCs_ERK_unstim             DCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_CREB_unstim            mDCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_p38_unstim            mDCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT3_unstim               mDCs_S6_unstim 
#>                        FALSE                        FALSE 
#>              mDCs_IkB_unstim         mDCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>             mDCs_NFkB_unstim              mDCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>            mDCs_STAT6_unstim             pDCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT5_unstim              pDCs_p38_unstim 
#>                        FALSE                        FALSE 
#>            pDCs_STAT1_unstim            pDCs_STAT3_unstim 
#>                        FALSE                        FALSE 
#>               pDCs_S6_unstim              pDCs_IkB_unstim 
#>                        FALSE                        FALSE 
#>         pDCs_MAPKAPK2_unstim             pDCs_NFkB_unstim 
#>                        FALSE                        FALSE 
#>              pDCs_ERK_unstim            pDCs_STAT6_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_CREB_unstim          intMCs_STAT5_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_p38_unstim          intMCs_STAT1_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT3_unstim             intMCs_S6_unstim 
#>                        FALSE                        FALSE 
#>            intMCs_IkB_unstim       intMCs_MAPKAPK2_unstim 
#>                        FALSE                        FALSE 
#>           intMCs_NFkB_unstim            intMCs_ERK_unstim 
#>                        FALSE                        FALSE 
#>          intMCs_STAT6_unstim    CCR2posintMCs_CREB_unstim 
#>                        FALSE                        FALSE 
#>                         CHIP                        CEBPB 
#>                        FALSE                        FALSE 
#>                          NSE                        PIAS4 
#>                        FALSE                        FALSE 
#>                     IL.10.Ra                        STAT3 
#>                        FALSE                        FALSE 
#>                         IRF1                        c.Jun 
#>                        FALSE                        FALSE 
#>                        Mcl.1                         OAS1 
#>                        FALSE                        FALSE 
#>                        c.Myc                        SMAD3 
#>                        FALSE                        FALSE 
#>                        SMAD2                        IL.23 
#>                        FALSE                        FALSE 
#>                       PDGFRA                        IL.12 
#>                        FALSE                        FALSE 
#>                        STAT1                        STAT6 
#>                        FALSE                        FALSE 
#>                        LRRK2                  Osteocalcin 
#>                        FALSE                        FALSE 
#>                         IL.5                         GPDA 
#>                        FALSE                        FALSE 
#>                          IgA                         LPPL 
#>                        FALSE                        FALSE 
#>                        HEMK2                         PDXK 
#>                         TRUE                        FALSE 
#>                         TLR4                         REG4 
#>                        FALSE                        FALSE 
#>                       HSP.27                       YKL.40 
#>                        FALSE                        FALSE 
#>                Alpha.enolase                       Apo.L1 
#>                        FALSE                        FALSE 
#>                         CD38                         CD59 
#>                        FALSE                        FALSE 
#>                        FABPL                       GDF.11 
#>                        FALSE                        FALSE 
#>                          BTC                       HIF.1a 
#>                        FALSE                        FALSE 
#>                       S100A6                       SECTM1 
#>                        FALSE                        FALSE 
#>                        RSPO3                          PSP 
#>                        FALSE                        FALSE 
#>    Apoptosis.regulator.Bcl.W                       VEGF.D 
#>                        FALSE                        FALSE 
#>                         SOST                        FAM3D 
#>                        FALSE                        FALSE 
#>                          CSH                        EFNB1 
#>                        FALSE                        FALSE 
#>                        SNP25                        LYPD3 
#>                        FALSE                        FALSE 
#>                        NEGR1                         BCL6 
#>                        FALSE                        FALSE 
#>                        FSTL1                  Osteopontin 
#>                        FALSE                        FALSE 
#>                      Lumican                        CD177 
#>                        FALSE                        FALSE 
#>                         CHKB                        SMOC1 
#>                        FALSE                        FALSE 
#>          protein.Z.inhibitor                        FLRT2 
#>                        FALSE                        FALSE 
#>                        FLRT3                        ISLR2 
#>                        FALSE                        FALSE 
#>                  Vitronectin                         DSC2 
#>                        FALSE                        FALSE 
#>                         LDLR                         HXK2 
#>                        FALSE                        FALSE 
#>                         HXK1                        SEM5A 
#>                        FALSE                        FALSE 
#>                        LTBP4                        PIANP 
#>                        FALSE                        FALSE 
#>               Adrenomedullin                       S100A4 
#>                        FALSE                        FALSE 
#>                        RNF43                     TRAIL.R4 
#>                        FALSE                        FALSE 
#>                        ZNRF3                         GI24 
#>                        FALSE                        FALSE 
#>                    Ephrin.A2                         ApoM 
#>                        FALSE                        FALSE 
#>                        IFN.b                        IFN10 
#>                        FALSE                        FALSE 
#>                        IFNA7                        EFNB2 
#>                        FALSE                        FALSE 
#>                        HHLA2                    IL.1.sRII 
#>                        FALSE                        FALSE 
#>                        AMGO2                        RXFP1 
#>                        FALSE                        FALSE 
#>                        C1QR1                         NRG4 
#>                         TRUE                        FALSE 
#>                        H2B2E                         H2A3 
#>                         TRUE                        FALSE 
#>                          H31                        IFN.g 
#>                        FALSE                        FALSE 
#>                       IL.1F8                       IL.1F6 
#>                        FALSE                        FALSE 
#>                         UCRP                    Ephrin.A3 
#>                        FALSE                        FALSE 
#>   X14.3.3.protein.beta.alpha                     X14.3.3E 
#>                        FALSE                        FALSE 
#>                    Annexin.V                    Myostatin 
#>                        FALSE                        FALSE
```

Early fusion features may differ from the per-omic lists because the
joint model sees features from both omics simultaneously. A feature from
one omic that is redundant with a feature from another omic may drop out
of the joint selection — this is the expected behaviour and not a bug.

``` r
# Late fusion: optimal linear combination of per-omic predictions
if (!is.null(multi_fit$late_fusion)) {
  cat("Late fusion validation predictions (first 6):\n")
  print(head(multi_fit$late_fusion$valid_predictions))
}
#> Late fusion validation predictions (first 6):
#>  004_31_A  004_34_B  015_30_A  015_34_B  015_36_C  047_26_A 
#> -83.26806 -76.06326 -79.00563 -62.57699 -70.52840 -73.72743
```

`$valid_predictions` is a numeric vector of predicted DOS values for the
held-out validation set — one prediction per sample. Compare these to
the true values (`ool_valid$y`) to assess predictive performance. The
`$weights` element shows how much each omic contributed to the combined
prediction; a weight near zero for an omic means it added little beyond
the other omic.

``` r
plot_stabl_path(multi_fit$fits$cytof,
                title = "CyTOF (multi-omic pipeline)")
```

![CyTOF stability path from multi-omic
fit](stablr-multiomic_files/figure-html/stability-paths-1.png)

``` r
plot_stabl_path(multi_fit$fits$proteomics,
                title = "Proteomics (multi-omic pipeline)")
```

![CyTOF stability path from multi-omic
fit](stablr-multiomic_files/figure-html/stability-paths-2.png)

------------------------------------------------------------------------

## 5. Export results

[`save_stabl_results()`](https://gregbellan.github.io/Stabl/stablr/reference/save_stabl_results.md)
writes four outputs to disk for a single `stabl_fit` object:

| File                    | Content                                   |
|-------------------------|-------------------------------------------|
| `stability_scores.csv`  | Feature names and their stability scores. |
| `selected_features.csv` | Only the features above the threshold.    |
| `stability_path.pdf`    | The stability path plot.                  |
| `fdr_graph.pdf`         | The FDR graph.                            |

Set `override = TRUE` to overwrite an existing directory; useful in
iterative analyses where you re-run with more bootstraps.

``` r
out_dir <- file.path(tempdir(), "stablr_ool_cytof")

save_stabl_results(
  object    = multi_fit$fits$cytof,
  path      = out_dir,
  x         = ool_train$x_list$cytof,
  y         = ool_train$y,
  task_type = "regression",
  override  = TRUE
)

list.files(out_dir, recursive = TRUE)
#> [1] "FDR Graph.pdf"                          
#> [2] "Max STABL artificial scores.csv"        
#> [3] "Max STABL scores.csv"                   
#> [4] "Selected Features/Selected features.csv"
#> [5] "Stability Path.pdf"                     
#> [6] "STABL artificial scores.csv"            
#> [7] "STABL scores.csv"
```

------------------------------------------------------------------------

## Next steps

- Use
  [`stabl_multiomic_cv()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_multiomic_cv.md)
  for a fully cross-validated evaluation when no pre-defined validation
  split is available.
- Pass `groups` to respect subject-level grouping in bootstrap
  resampling and CV fold construction.
- See
  [`vignette("stablr-intro")`](https://gregbellan.github.io/Stabl/stablr/articles/stablr-intro.md)
  for a walk-through of single-omic usage and alternative learners
  (adaptive lasso, elastic net).
