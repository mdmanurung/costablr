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
- Per-bootstrap coefficient thresholding follows sklearn `SelectFromModel`
  semantics: features with absolute importance `>= bootstrap_threshold` are
  counted as selected for that bootstrap/lambda.
- Default subsampling policy is `sample_fraction = 0.5`, `replace = FALSE`.
- `stabl_fit()` returns stability scores, threshold diagnostics, and support.
  The end-to-end predictive workflow must then refit an ordinary final model
  on the selected features; `stabl_refit()` owns that compulsory final stage.
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
- `bootstrap_threshold` defines the per-bootstrap absolute-coefficient cutoff.
  R exposes this argument with the upstream STABL effective default `1e-5`.
  Numeric thresholds, `NULL`, `"mean"`, `"median"`, and scaled forms such as
  `"1.25*mean"` follow sklearn `SelectFromModel` threshold syntax; `NULL`
  resolves to `1e-5` for the l1-style learners implemented here.
- Predictor row names, outcome sample IDs, and group sample IDs must be unique
  before name-based alignment.  Duplicate IDs are hard errors because they
  cannot preserve pandas-style one-to-one sample alignment.

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
   - When artificial features are enabled, R rejects configurations whose
     realised $q$ is less than one instead of entering FDP+ with an empty
     artificial block.
2. Generate artificial features $\tilde{X} \in \mathbb{R}^{n \times q}$ using:
   - random permutation of selected original columns (`"random_permutation"`),
   - equicorrelated Gaussian model-X knockoffs (Python
     `artificial_type = "knockoff"`; R `artificial_type = "modelx_knockoff"`), or
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
   R rejects configurations whose realised $m$ is less than one before
   bootstrap sampling starts.
   In R, when `bootstrap_strata` is supplied, the draw is performed within the
   realised interaction of the supplied stratification columns.  When
   `stratify_bootstrap = TRUE` and `bootstrap_strata = NULL`, the outcome
   vector is used as the single stratification factor.  Grouped bootstrap still
   preserves whole groups; grouped stratification requires every group to map
   to exactly one realised stratum.
3. Fit the Base SRM on $(Y, \mathbb{X})_k$ across all values of the regularization parameter(s) $\lambda \in \Lambda$ [5].
4. For each $(k, \lambda)$, derive a binary selection mask over the $p+q$ features.
   For coefficient-based learners this is `abs(coef) >= bootstrap_threshold`,
   matching sklearn `SelectFromModel` bootstrap-level semantics.  This
   bootstrap-level comparator is distinct from the later FDP+/support
   stability comparator, which remains strict `>`.

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
   Because the default grid includes zero, an FDP+-derived $\theta=0$ is valid.
   User-supplied hard-threshold overrides must still be single, finite numeric
   values in `(0, 1]`.

### Step 5: Final Feature Selection and Predictive Refit
1. Core `stabl_fit()` outputs the final selected original-feature set using
   strict thresholding:
   $$
   \hat{S}(\theta) = \{i \in \mathcal{O} : f_i > \theta\}.
   $$
2. End-to-end predictive STABL workflows then refit an unpenalized final model
   on \(X_{\hat{S}}\), matching the Python tutorial pipeline pattern
   (`Stabl` feature selection followed by `LogisticRegression(penalty=None)`;
   see the fixed tutorial notebook reference:
   https://github.com/gregbellan/Stabl/blob/1d07f85a13cfbecb4f08ce21075bf4fbb8e34678/Notebook%20examples/Tutorial%20Notebook.ipynb).
3. In this R package, `stabl_refit()` is the canonical single-matrix
   end-to-end API:
   - `family = "gaussian"` refits `stats::lm()`.
   - `family = "binomial"` refits `stats::glm(..., family = binomial(link = "logit"))`.
   - `family = "multinomial"` refits `nnet::multinom()` with no weight decay.
   - `family = "poisson"` refits `stats::glm(..., family = poisson(link = "log"))`.
   - `family = "cox"` refits `survival::coxph()`.
   If no features pass the STABL threshold, the final model is still fitted as
   an intercept-only model so the final stage remains present and explicit.
   `predict.stabl_refit(newdata = ...)` requires a numeric matrix/data frame
   with non-empty, unique row names and all selected feature columns.
4. `stabl_multiomic_train_validate(late_fusion = TRUE)` uses the same
   unpenalized final-refit helper per omic before stacking per-view
   predictions.

### Quick Python-vs-R Differences (Implementation Notes)
- Artificial-feature count:
   - Python uses $q = \lfloor p\pi \rfloor$.
   - R uses $q = \mathrm{round}(p\pi)$.
- Artificial-feature type labels:
   - Python supports `"random_permutation"` and `"knockoff"`.
   - R supports `"random_permutation"`, `"modelx_knockoff"`, and
     `"mvr_knockoff"`; R `"modelx_knockoff"` is the semantic counterpart of
     Python `"knockoff"`, while `"mvr_knockoff"` is R-only.
- Bootstrap implementation details:
   - Both support grouped and ungrouped sampling, same default policy ($s=0.5$, `replace=FALSE`).
   - Grouped bootstrap internals differ but target the same leakage-prevention intent.
   - R additionally supports optional stratified bootstrap designs; this is
     R-only and disabled by default to preserve Python parity.
- Thresholding comparator:
   - Both use strict $>$ for FDP+ and support-mask selection.
- Bootstrap coefficient comparator:
   - Both use $|coef| >= bootstrap_threshold$ when turning a single fitted
     bootstrap model into a selected-feature mask.
- FDP+ threshold grid defaults:
   - Python default is `np.arange(0., 1., .01)`.
   - R default is `seq(0, 0.99, by = 0.01)`.
- Core/output workflow boundary:
   - `stabl_fit()` stops at stability scores + thresholding + feature support.
   - `stabl_refit()` is the package-level end-to-end fit that performs the
     compulsory final predictive refit on selected features.
- Bootstrap selection threshold (`bootstrap_threshold`):
   - Both Python (`stabl/stabl.py:942`) and R expose
     `bootstrap_threshold`, with an effective default of `1e-5` as the
     absolute-coefficient cutoff that decides whether a feature is "selected"
     in a single bootstrap fit.
   - R supports numeric thresholds, `NULL`, `"mean"`, `"median"`, and scaled
     forms such as `"1.25*mean"` to mirror sklearn `SelectFromModel`
     threshold syntax.
- Artificial-feature column-source sampling (random permutation):
   - Both Python (`stabl/stabl.py:1382-1383`) and R draw the source column
     for each artificial feature with `replace = FALSE`.
- Artificial-feature realised count:
   - Both Python (`stabl/stabl.py:1426` and `stabl/stabl.py:1431-1433`)
     and R pass the requested `artificial_proportion` directly to the FDP+
     scaling factor `1/π` (no realised-vs-requested correction).
- Explore fallback when no feature passes the stability threshold:
   - Python lowers the cutoff to the `n_explore`-th largest score minus `0.01`,
     so tied scores can select more than `n_explore` features.
   - R selects exactly the top `n_explore` features by score order. This is an
     intentional R hardening difference and does not affect default parity
     because `explore = FALSE`.
- Direct model-X helper seeding:
   - `make_modelx_knockoff_features(random_state = ...)` uses a scoped RNG
     state and restores the caller's RNG on exit.  The higher-level
     `make_artificial_features()` dispatcher seeds once before calling the
     selected generator.

### Reviewer Checklist

- Verify strict-threshold comparator (`>`) is used in both FDP+ and support extraction.
- Verify per-bootstrap coefficient masks use `>= bootstrap_threshold`.
- Verify default subsample policy matches documented defaults.
- Verify FDP+ expression includes `(1 / pi)` artificial-feature scaling.
- Verify `stabl_fit()` remains the selector boundary and `stabl_refit()`
  performs the final unpenalized predictive refit.

### R Implementation Mapping

- Input checks/alignment: `R/input_validation.R`
- Bootstrap samplers: `R/bootstrap_helpers.R`
- Artificial features (random permutation, model-X knockoff, MVR knockoff):
  `R/artificial_features.R`, `R/mvr_knockoff.R`
- Base learner adapters: `R/learner_adapters.R`
- FDP+ and thresholding: `R/fdp_control.R`
- Core orchestration: `R/stabl_fit.R`
- End-to-end single-matrix refit: `R/stabl_refit.R`
- Output API (S3/accessors): `R/stabl_accessors.R`

### Non-Goals Of Core `stabl_fit()`

- Core `stabl_fit()` does not itself perform final downstream predictive
  refitting; use `stabl_refit()` for the compulsory end-to-end final model.
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
- `stabl_multiomic_train_validate(cooperative_fusion = TRUE)` supports
  `family = "multinomial"` as workflow-level automatic one-vs-rest
  cooperative fusion: one binomial `multiview` model is fitted per class,
  class response probabilities are row-normalized, and selected features are
  exposed both by class and as a per-view union. Native multinomial
  optimization inside `multiview` remains out of scope.
