# STABL Algorithm Contract

## Document Role

This file is the algorithmic contract for the R implementation of STABL in
`costablr`.

The Nature Biotechnology StablSRM methods description is the mathematical
method reference. The upstream Python STABL implementation, currently audited
against `gregbellan/Stabl@1d07f85a13cfbecb4f08ce21075bf4fbb8e34678`, remains
the executable reference for implementation details unless this document
records an explicit paper-method decision.

- Planning and phase gates are tracked in `PLAN.md`.
- Implemented work and validation evidence are tracked in `PROGRESS.md`.
- Fresh-session execution state is tracked in `HANDOFF.md`.
- Agent workflow policy is defined in `AGENTS.md`.

When implementation changes core STABL semantics, update this document first.

## Master Reference Summary

STABL is a feature-selection framework built on stability selection. It:

1. augments the original covariates with artificial features that behave like
   uninformative variables;
2. repeatedly fits a sparsity-promoting regularization method on subsamples;
3. estimates each feature's maximum selection frequency across a regularization
   grid;
4. constructs an augmented false discovery proportion surrogate, FDP+;
5. chooses a data-driven reliability threshold by minimizing FDP+;
6. fits the final predictive model using only the selected original features.

The paper denotes the procedure as StablSRM once a base sparsity-promoting
regularization method, such as lasso, elastic net, adaptive lasso, or sparse
group lasso, has been selected.

## Reconciled Repository Decisions

The following repository decisions are the authoritative reconciliations for
`costablr`:

- **Thresholding precedence:** for FDP+ counts and final support, `costablr`
  follows the paper's greater-than-or-equal (`>=`) notation. This intentionally
  differs from the upstream Python implementation, which uses strict
  greater-than (`>`) comparisons in tie cases.
- **Artificial-feature count:** the paper's main construction uses one
  artificial feature per original feature. `costablr` generalizes this with
  `artificial_proportion = pi`, so the realised artificial count is
  `q = floor(p * pi)`, matching Python. With the default `pi = 1`, `q = p`,
  so the paper default remains intact.
- **FDP+ scaling:** because artificial-feature count is configurable, FDP+
  uses the `(1 / pi)` scaling factor from the Python STABL implementation.
- **Bootstrap-level feature masks:** the paper writes
  `beta_j(k, lambda) != 0`. `costablr` mirrors sklearn `SelectFromModel`
  semantics by counting a feature as selected in a bootstrap fit when
  `abs(coef) >= bootstrap_threshold`, with default `bootstrap_threshold = 1e-5`.
  This per-bootstrap coefficient comparator is separate from the final
  stability-score comparator, which is `>=`.
- **Explore fallback:** Python lowers the final cutoff to the `n_explore`-th
  largest score minus `0.01` when no features pass and `explore = TRUE`, then
  `costablr` reapplies paper-notation `>=` support extraction. This can select
  more than `n_explore` features when scores are tied, including all-zero
  stability scores.
- **Auto lambda:** explicit user-provided `lambda_grid` values are preserved.
  For `lambda_grid = "auto"`, gaussian lasso/elastic-net paths use Python's
  `||X'Y||_inf / (n * l1_ratio)` scale and
  `geomspace(lambda_max / 30, lambda_max + 5, n_lambda)`. Classification paths
  approximate Python's increasing `C_min` to `100 * C_min` `l1_min_c()` grid
  and map it to glmnet's inverse penalty scale (`lambda = 1 / C`). Cox remains
  an R-only glmnet-native path because upstream Python STABL has no Cox backend.
- **Subsampling policy:** the paper uses subsamples of size `floor(n / 2)`
  without replacement. `costablr` defaults to the same policy via
  `sample_fraction = 0.5` and `replace = FALSE`, while exposing both controls.
- **Artificial-feature generators:** the paper lists random permutations and
  MX knockoffs. `costablr` supports `"random_permutation"`,
  `"modelx_knockoff"` as the MX counterpart, and R-only `"mvr_knockoff"`.
- **Selector/refit boundary:** the StablSRM method includes both selection and
  the final constrained estimate. In code, `stabl_fit()` owns Steps 1-5:
  stability scores, FDP+ diagnostics, reliability threshold, and support.
  `stabl_refit()` and the workflow-level refit branches own Step 6, the
  downstream final predictive refit.

These decisions are parity-critical unless a future change explicitly updates
this contract, implementation, and tests together. The `>=` stability-score
threshold decision is a deliberate paper-method divergence from upstream Python
tie handling.

## Formal Single-View Algorithm

### Inputs

- `X in R^{n x p}`: original covariate matrix with `n` samples and `p`
  candidate features.
- `Y`: outcome vector or outcome object aligned to the samples of `X`.
- Base SRM: a sparsity-promoting regularization method.
- `B`: number of subsampling iterations.
- `Lambda`: regularization-parameter grid.
- `pi in (0, 1]`: artificial-feature proportion.
- `s > 0`: subsample fraction, default `0.5`.
- `replace`: whether subsampling is with replacement, default `FALSE`.

R-specific inputs include optional grouped bootstrap sampling and optional
bootstrap stratification. These are workflow hardening extensions and do not
change the default STABL contract.

### Step 1: Artificial Noise Injection

From the original matrix `X = (X_1, ..., X_p)`, generate an artificial-feature
matrix `X_tilde in R^{n x q}`, where:

- in the paper's default construction, `q = p`;
- in `costablr`, `q = floor(p * pi)`, and `pi = 1` gives `q = p`.

Artificial features may be generated by random permutation, Gaussian model-X
knockoffs, or Gaussian MVR knockoffs.

Concatenate original and artificial features:

```text
X_aug = [X | X_tilde] in R^{n x (p + q)}
```

Define index sets:

```text
O = {1, ..., p}
A = {p + 1, ..., p + q}
```

For sparse group lasso, every artificial feature inherits the group assignment
of its original feature source.

### Step 2: Subsampling and Base SRM Fitting

For each subsampling iteration `k in {1, ..., B}`, draw a subsample of size:

```text
m = floor(s * n)
```

from `(Y, X_aug)`. The default `s = 0.5`, `replace = FALSE` matches the paper's
`floor(n / 2)` without-replacement design.

For each regularization setting `lambda in Lambda`, fit the selected Base SRM
on the subsampled augmented data. This yields coefficient estimates:

```text
beta_hat(k, lambda) =
  (beta_hat_1(k, lambda), ..., beta_hat_{p + q}(k, lambda))^T
```

For coefficient-based learners, convert each fit to a binary selected-feature
mask using:

```text
abs(beta_hat_j(k, lambda)) >= bootstrap_threshold
```

This bootstrap-level `>=` comparator is applied to fitted coefficients. It is
the same closed-threshold convention used by paper-notation FDP+ and support
thresholding, though it applies to fitted coefficients rather than stability
scores.

### Step 3: Maximum Selection Frequency

For each original or artificial feature `j`, compute its selection frequency at
each regularization setting:

```text
s_j(lambda) = (1 / B) * sum_{k = 1}^{B} I[j selected in (k, lambda)]
```

Then compute the STABL score as the maximum over the regularization grid:

```text
f_j = max_{lambda in Lambda} s_j(lambda)
```

For elastic net and sparse group lasso, `Lambda` may represent a multi-parameter
grid; the maximum is still taken over the realised grid rows.

### Step 4: FDP+ Surrogate

For a candidate stability threshold `t`, `costablr` counts selected original and
artificial features using the paper's `>=` comparator. This intentionally
differs from the executable Python code's strict `>` tie behavior:

```text
N_real(t) = sum_{j in O} I[f_j >= t]
N_art(t)  = sum_{j in A} I[f_j >= t]
```

The augmented FDP surrogate is:

```text
FDP_+(t) = (1 + (1 / pi) * N_art(t)) / max(1, N_real(t))
```

The additive `1` in the numerator, denominator floor, `(1 / pi)` scaling, and
paper-notation `>=` comparator are all part of the repository contract.

### Step 5: Reliability Threshold and Selected Set

Evaluate FDP+ over `fdr_threshold_range`:

```text
T = seq(0, 0.99, by = 0.01)
```

by default, matching Python STABL's `np.arange(0., 1., .01)`.

The reliability threshold is:

```text
theta in argmin_{t in T} FDP_+(t)
```

with implementation fallback `theta = 1` when the minimum FDP+ exceeds `1`.
Because the default grid includes zero, a data-driven `theta = 0` is valid.
Under paper-notation `>=` support semantics, `theta = 1` selects features with
stability score exactly `1`, and `theta = 0` selects all features with valid
stability scores, including scores exactly `0`.

The final selected original-feature set is:

```text
S_hat(theta) = {j in O : f_j >= theta}
```

User-supplied threshold overrides must still be finite numeric values in
`(0, 1]`.

### Step 6: Final Predictive Estimate

The paper's final Stabl estimate can be written as fitting a final predictive
model under the support constraint:

```text
beta_hat_Stabl in argmin_b L(Y, X b)
subject to b_i = 0 for i not in S_hat(theta)
```

For squared-error regression, `L(Y, X b) = ||Y - X b||_2^2`. For classification,
Poisson, and Cox workflows, the final loss is the task-appropriate model loss.

In `costablr`:

- `stabl_fit()` stops after computing `S_hat(theta)` and selector diagnostics.
- `stabl_refit()` performs the end-to-end final refit on `X_{S_hat(theta)}`.
- If no features pass the reliability threshold, the final refit remains
  explicit and is fitted as an intercept-only model where the family supports
  that behavior.

## Formal Multi-Omic Distinction

Let `X_1, ..., X_M` be aligned omic views measured on the same samples.

### Early Fusion

Early fusion concatenates all omic views before selection or prediction:

```text
X_combined = [X_1 | ... | X_M]
```

The algorithm then trains in one unified feature space. If STABL is applied
after this concatenation, it computes one artificial-feature construction, one
FDP+ curve, and one reliability threshold over the combined feature space.

In `costablr`, Early Fusion prefixes every candidate biomarker in the
concatenated matrix with its omic-view name using `__`, for example
`cytof__CD4_T`. This keeps same-named biomarkers from different omic views
distinct during selection and downstream refit. Original feature names may
contain `__`; parsers must treat only the first `__` as the delimiter between
omic view and original feature name. Omic view names must not contain `__`.

Because Early Fusion has a single concatenated input space, it must use a
single shared lambda grid. In `costablr`, `early_fusion = TRUE` accepts
`lambda_grid = "auto"` or one shared `data.frame`. Named per-omic lambda-grid
lists are rejected for Early Fusion instead of silently using one view's grid.

### Late Fusion

Late fusion trains separate per-view predictive models and combines their
prediction outputs, for example by averaging predictions or by fitting a second
model on those predictions.

In `costablr`, `stabl_multiomic_train_validate(late_fusion = TRUE)` implements
prediction-level fusion: each omic view receives its own STABL selector and
final refit, and `stacked_multi_omic()` combines the per-view predictions with
learned non-negative view weights. This is downstream workflow logic, not part
of the core STABL selector.

Late Fusion for `family = "cox"` is intentionally unsupported in the current
implementation. The existing stacker optimizes binary AUC, regression R^2, or
multiclass log loss; treating Cox risk scores as ordinary regression
predictions would ignore censoring and event indicators. A future Cox Late
Fusion implementation should reuse the weight-search and weighted-risk-score
combination structure, but it must add a survival-specific objective such as a
concordance metric over `survival::Surv(time, event)` outcomes.

### Multi-Omic STABL

Multi-Omic STABL, corresponding to the paper's StablSRM multi-omic integration,
is distinct from late fusion:

1. Run Steps 1-5 independently for each omic view `X_m`.
2. Obtain a view-specific FDP+ curve and reliability threshold `theta_m`.
3. Select view-specific reliable features:

   ```text
   S_hat_m(theta_m) = {j in O_m : f_{m,j} > theta_m}
   ```

4. Concatenate only the selected original features across views:

   ```text
   X_selected = [X_1,S_hat_1 | ... | X_M,S_hat_M]
   ```

   In `costablr`, selected-feature columns in this final layer use the same
   Omic View prefixing policy as Early Fusion: `<Omic View>__<original
   feature>`, for example
   `cytof__CD4_T`, even when original feature names are globally unique. This
   preserves provenance and prevents silent name collisions. The implementation
   exposes a mapping from final-layer feature names to
   `(omic view, original feature)` pairs. Original feature names may themselves
   contain `__`; parsers must treat only the first `__` as the delimiter between
   omic view and original feature name. Omic view names must not contain `__`,
   because that would make the prefix boundary ambiguous.

5. Perform Step 6 once on `X_selected`, so the final predictive model can weigh
   reliable biological features from different omic views against one another
   in a single model.

This selected-biomarker final layer must not be described as late fusion:
late fusion combines predictions, while Multi-Omic STABL combines selected
features before the final predictive refit.

Current implementation note: the `multiomic_stabl = TRUE` option on
`stabl_multiomic_train_validate()` exposes this selected-feature final layer as
the `$multiomic_stabl` result branch. `stabl_multiomic_cv()` forwards the same
flag to fold-specific train/validation fits. Nested-CV integration is
intentionally separate because `stabl_multiomic_nested_cv()` uses an explicit
candidate-type abstraction.

The `$multiomic_stabl` branch is additive. Enabling it does not replace the
top-level per-view `fits`, `selected_features`, `selected_train`, or `refits`.
Those top-level objects remain per-view diagnostics and per-view Final Refits.
The paper-level combined final estimate lives in `$multiomic_stabl$refit`.

Early Fusion, Late Fusion, and Multi-Omic STABL are additive comparison
branches in `costablr`. A workflow call may enable `early_fusion = TRUE`,
`late_fusion = TRUE`, and `multiomic_stabl = TRUE` simultaneously. Their
outputs must remain separated under `$early_fusion`, `$late_fusion`, and
`$multiomic_stabl`, because each branch represents a different integration
strategy.

For `stabl_multiomic_cv()`, the top-level `$diagnostics` table remains a
per-fold, per-Omic View selector diagnostic table. It summarizes the
view-specific Steps 1-5 that produce each `S_hat_m(theta_m)`. When
`multiomic_stabl = TRUE`, combined final-layer details such as the selected
prefixed feature matrix, provenance map, predictions, metrics, and final refit
remain inside each `fold_results[[fold]]$multiomic_stabl` branch. Do not add a
synthetic "combined" Omic View row to `$diagnostics` unless that is introduced
as an explicit API change with its own documented semantics.

### Cooperative Fusion Comparator

Cooperative Fusion is an additional comparator workflow in `costablr`, not a
member of the formal Early Fusion / Late Fusion / Multi-Omic STABL taxonomy
used for StablSRM method parity. It uses the maintained `multiview` integration
path to jointly model Omic Views while allowing view-specific contributions.
Do not describe Cooperative Fusion as Early Fusion, Late Fusion, or
Multi-Omic STABL.

When enabled, `cooperative_fusion = TRUE` remains an additive branch. Its
results live under `$cooperative_fusion` and do not replace `$early_fusion`,
`$late_fusion`, `$multiomic_stabl`, or the top-level per-view STABL Selector
outputs.

## Python-to-R Parity Notes

- Python and R use `q = floor(p * pi)` for artificial-feature count. The paper
  default `q = p` is recovered when `pi = 1`.
- Python labels Gaussian model-X knockoffs as `"knockoff"`; R uses
  `"modelx_knockoff"` and additionally supports `"mvr_knockoff"`.
- R uses paper-notation `>=` for FDP+ counts and support extraction. This is an
  intentional divergence from upstream Python's strict `>` tie behavior.
- Both use `abs(coef) >= bootstrap_threshold` for per-bootstrap coefficient
  masks.
- Both pass the requested `artificial_proportion` directly to FDP+ scaling,
  rather than correcting by the realised artificial-feature count.
- R adds optional bootstrap stratification while preserving unstratified
  defaults for parity.
- Python and R lower the `explore = TRUE` fallback cutoff to the
  `n_explore`-th largest score minus `0.01`; R then applies paper-notation
  `>=` support extraction. Ties can therefore select more than `n_explore`
  features.
- Gaussian auto-lambda mode follows Python's regression formula. Binomial and
  multinomial auto-lambda mode follows the same `C_min` to `100 * C_min`
  regularization-strength shape, mapped to glmnet lambda scale; exact numeric
  equality to sklearn is not guaranteed because `sklearn.svm.l1_min_c()` and
  glmnet use different objective scalings.

## Reviewer Checklist

- Verify paper-notation `>=` is used in FDP+ and final support extraction.
- Verify per-bootstrap masks use `>= bootstrap_threshold`.
- Verify `floor(p * artificial_proportion)` is used for artificial-feature
  count.
- Verify default subsampling is `sample_fraction = 0.5`, `replace = FALSE`.
- Verify FDP+ includes the additive `1`, denominator floor, and `(1 / pi)`
  artificial-feature scaling.
- Verify `explore = TRUE` uses the Python cutoff-lowering rule and documents
  possible tie over-selection.
- Verify gaussian/binomial/multinomial auto-lambda grids follow the Python
  shape, with Cox kept as an R-only glmnet-native path.
- Verify `stabl_fit()` remains the selector boundary.
- Verify `stabl_refit()` owns the final predictive refit.
- Verify late fusion is described as prediction-level fusion.
- Verify Multi-Omic STABL is described as selected-feature concatenation
  followed by one final predictive refit.

## R Implementation Mapping

- Input checks/alignment: `R/input_validation.R`
- Bootstrap samplers: `R/bootstrap_helpers.R`
- Artificial features: `R/artificial_features.R`, `R/mvr_knockoff.R`
- Base SRM adapters: `R/learner_adapters.R`
- FDP+ and thresholding: `R/fdp_control.R`
- Core STABL selector: `R/stabl_fit.R`
- Single-matrix final refit: `R/stabl_refit.R`
- Output API and accessors: `R/stabl_accessors.R`
- Multi-omic workflows: `R/multiomic_workflows.R`, `R/late_fusion.R`,
  `R/cooperative_fusion.R`, `R/nested_cv.R`
