# The Stabl Method: Step-by-Step Algorithm for Code Conversion

## Document Role

This file is the algorithmic and parity contract for the Python-to-R reimplementation.

- Planning and phase gates are tracked in `PLAN.md`.
- Implemented work and validation evidence are tracked in `PROGRESS.md`.
- Agent workflow policy is defined in `AGENTS.md`.

When implementation changes core STABL semantics, update this document first.

## Parity-Critical Invariants

The following behaviors are parity-critical for the R reimplementation and
must remain explicit in code and tests:

- FDP+ and support-mask thresholding use strict `>` comparison.
- Default subsampling policy is `sample_fraction = 0.5`, `replace = FALSE`.
- Core STABL fit returns stability scores, threshold diagnostics, and support;
   downstream predictive refit is a separate workflow stage.
- Artificial-feature scaling in FDP+ uses the `(1 / pi)` factor.

## Parameter Mapping (Python to R)

- `artificial_proportion` controls injected artificial-feature count.
- `sample_fraction` controls bootstrap subsample size via `floor(sample_fraction * n)`.
- `replace` controls with/without replacement bootstrap sampling.
- R adds optional `bootstrap_strata` / `stratify_bootstrap` controls for
  stratified bootstrap subsampling. Defaults remain unstratified for parity.
- `l1_ratio` is forwarded to `auto_lambda_grid()` for elastic-net paths in
  `stabl_fit()` and the multi-omic workflow helpers. It is additive API
  surface and does not change default lasso or parity behavior when `NULL`.
- `fdr_threshold_range` defines the threshold sweep used in FDP+ minimization.

**Inputs:**
*   $X \in \mathbb{R}^{n \times p}$: Observation matrix containing $n$ samples and $p$ features [1].
*   $Y \in \mathbb{R}^n$: Vector of clinical outcomes [1].
*   **Base SRM**: A Sparsity-promoting Regularization Method (e.g., Lasso, Elastic Net, Adaptive Lasso, or Sparse Group Lasso) [2-4].
*   $B$: Number of subsampling iterations [5].
*   $\Lambda$: Grid of regularization parameters for the chosen Base SRM [5].
*   $\pi \in (0, 1]$: Artificial-feature proportion (`artificial_proportion`, default $\pi = 1$).
*   $s > 0$: Subsample fraction (`sample_fraction`, default $s = 0.5$).
*   `replace`: Whether sampling is with replacement (default `FALSE`).
*   Optional R-only bootstrap stratification design (`bootstrap_strata`): one
    categorical factor or a joint design across multiple categorical factors.
    Named vectors and matrix/data-frame row names are aligned to sample IDs.
    Full-length unnamed/implicit designs are treated positionally, except that
    numeric-looking row names are still treated as sample IDs when their set
    matches the sample IDs.

### Step 1: Noise Injection (Creating Artificial Features)
1. Compute the number of injected artificial features $q$ from $p$ and $\pi$.
   - Python implementation: $q = \lfloor p\pi \rfloor$.
   - R implementation: $q = \mathrm{round}(p\pi)$.
   - With the default $\pi = 1$, this gives $q = p$.
2. Generate artificial features $\tilde{X} \in \mathbb{R}^{n \times q}$ using:
   - random permutation of selected original columns (`"random_permutation"`),
   - equicorrelated Gaussian model-X knockoffs (`"modelx_knockoff"`), or
   - Gaussian MVR knockoffs (`"mvr_knockoff"`).
   In the R implementation, model-X artificial features are generated with
   `knockoff::create.gaussian(..., method = "equi")` from Gaussian moments
   estimated on the current feature block.  MVR knockoffs use an internal
   RcppArmadillo diagonal S-matrix solver and Gaussian model-X sampler.
   Covariance estimates are symmetrized and diagonally shrunk until positive
   definite before construction; if valid knockoffs cannot be sampled for a
   block, that block falls back to random-permutation artificial features with
   a warning.
3. Concatenate original and artificial blocks:
   $\mathbb{X} = [X | \tilde{X}] \in \mathbb{R}^{n \times (p+q)}$.
4. Define index sets:
   - originals: $\mathcal{O} = \{1, \dots, p\}$,
   - artificials: $\mathcal{A} = \{p+1, \dots, p+q\}$.

### Step 2: Subsampling and Model Fitting
1. Iterate $k$ from $1$ to $B$ [5].
2. For each iteration $k$, draw a random subsample of size
   $m = \lfloor sn \rfloor$ from $(Y, \mathbb{X})$.
   The default is $s=0.5$ and `replace=FALSE`.
   In R, when `bootstrap_strata` is supplied, the draw is performed within the
   realised interaction of the supplied stratification columns.  When
   `stratify_bootstrap = TRUE` and `bootstrap_strata = NULL`, the outcome
   vector is used as the single stratification factor.  Grouped bootstrap still
   preserves whole groups; grouped stratification requires every group to map
   to exactly one realised stratum.
3. Fit the Base SRM on $(Y, \mathbb{X})_k$ across all values of the regularization parameter(s) $\lambda \in \Lambda$ [5].
4. For each $(k, \lambda)$, derive a binary selection mask over the $p+q$ features (typically using non-zero/thresholded coefficients).

### Step 3: Compute Feature Selection Frequencies
1. For each feature $j \in \{1, \dots, p+q\}$ and each $\lambda \in \Lambda$, compute bootstrap selection frequency:
   $$
   s_j(\lambda) = \frac{1}{B}\sum_{k=1}^B \mathbf{1}[j\text{ selected in }(k,\lambda)].
   $$
2. Define the STABL importance score as the maximum across the lambda grid:
   $$
   f_j = \max_{\lambda \in \Lambda} s_j(\lambda).
   $$

### Step 4: Compute the Data-Driven Reliability Threshold ($\theta$)
1. Evaluate potential thresholds $t$ on a grid (default: `seq(0, 0.99, by=0.01)` in R; `np.arange(0.,1.,.01)` in Python).
2. For each $t$, compute the surrogate FDP+ using strict comparison (`>` in code):
   $$
   FDP_+(t) = \frac{1 + \frac{1}{\pi}\sum_{j \in \mathcal{A}} \mathbf{1}[f_j > t]}{\max\left(1, \sum_{j \in \mathcal{O}} \mathbf{1}[f_j > t]\right)}.
   $$
3. Find the optimal reliability threshold $\theta$ that minimizes this function across all possible values of $t$:
   $$
   θ \in \arg\min_t FDP_+(t),
   $$
   with implementation fallback $\theta=1$ if the minimum FDP+ exceeds 1.

### Step 5: Final Feature Selection and Model Fit
1. Core STABL outputs the final selected original-feature set using strict thresholding:
   $$
   \hat{S}(\theta) = \{i \in \mathcal{O} : f_i > \theta\}.
   $$
2. In this repository, the core STABL fit stage stops at selection (scores, FDP+, and support mask). Any downstream predictive refit on selected variables is a separate pipeline step.

### Quick Python-vs-R Differences (Implementation Notes)
- Artificial-feature count:
   - Python uses $q = \lfloor p\pi \rfloor$.
   - R uses $q = \mathrm{round}(p\pi)$.
- Bootstrap implementation details:
   - Both support grouped and ungrouped sampling, same default policy ($s=0.5$, `replace=FALSE`).
   - Grouped bootstrap internals differ but target the same leakage-prevention intent.
   - R additionally supports optional stratified bootstrap designs; this is
     R-only and disabled by default to preserve Python parity.
- Thresholding comparator:
   - Both use strict $>$ for FDP+ and support-mask selection.
- FDP+ threshold grid defaults:
   - Python default is `np.arange(0., 1., .01)`.
   - R default is `seq(0, 0.99, by = 0.01)`.
- Core output contract:
   - Both core fit paths stop at stability scores + thresholding + feature support; final predictive refit is handled downstream.
- Bootstrap selection threshold (`bootstrap_threshold`):
   - Both Python (`stabl/stabl.py:973`) and R use `1e-5` as the absolute-coefficient cutoff that decides whether a feature is "selected" in a single bootstrap fit.  This is intentionally identical; do not change one without the other.
- Artificial-feature column-source sampling (random permutation):
   - Both Python (`stabl/stabl.py:1428`) and R draw the source column for each artificial feature with `replace = FALSE`.
- Artificial-feature realised count:
   - Both Python (`stabl/stabl.py:1474`) and R pass the requested `artificial_proportion` directly to the FDP+ scaling factor `1/π` (no realised-vs-requested correction).

### Reviewer Checklist

- Verify strict-threshold comparator (`>`) is used in both FDP+ and support extraction.
- Verify default subsample policy matches documented defaults.
- Verify FDP+ expression includes `(1 / pi)` artificial-feature scaling.
- Verify core fit output boundary does not include final predictive refit.

### R Implementation Mapping

- Input checks/alignment: `R/input_validation.R`
- Bootstrap samplers: `R/bootstrap_helpers.R`
- Artificial features (random permutation, model-X knockoff, MVR knockoff):
  `R/artificial_features.R`, `R/mvr_knockoff.R`
- Base learner adapters: `R/learner_adapters.R`
- FDP+ and thresholding: `R/fdp_control.R`
- Core orchestration: `R/stabl_fit.R`
- Output API (S3/accessors): `R/stabl_accessors.R`

### Non-Goals Of Core STABL Fit

- Core fit does not perform final downstream predictive refitting.
- Core fit does not own full benchmark orchestration from `Notebook examples/`.
- Core fit does not replace higher-level multi-omic workflow composition.

### Higher-Level Multi-Omic Workflow Semantics

- `stabl_multiomic_train_validate(late_fusion = TRUE)` is downstream workflow
  logic, not part of the core STABL selector. For `family = "multinomial"`, it
  now performs true multiclass late fusion by stacking per-view class
  probability matrices and selecting non-negative view weights by multiclass
  log loss.
- Multinomial late fusion uses per-view class-prior probabilities as the
  fallback when no features are selected for a view or the downstream refit
  fails. Binary/regression late fusion keeps the existing scalar prediction
  contract.
- Multiclass probability stacking requires every outcome label to be present
  in the supplied probability-column levels; mismatches are errors rather than
  silently dropped samples.
- Cooperative fusion remains restricted to families supported by `multiview`;
  multinomial cooperative learning is intentionally rejected. Multiclass
  cooperative analyses should be expressed as explicit one-vs-rest binomial
  branches when needed.
