# STABL Python Package — Deep Reference

> **Purpose of this document**: A comprehensive, implementation-level reference for every module in `stabl/`. Intended for all audiences — R developers reimplementing features, new contributors learning the codebase, and end users understanding capabilities.  
> **Python source root**: `stabl/`  
> **Algorithm contract**: [`STABL.md`](STABL.md)  
> **R port status**: tracked separately in [`PLAN.md`](PLAN.md) and [`PROGRESS.md`](PROGRESS.md)

---

## Table of Contents

1. [Algorithm Overview](#1-algorithm-overview)
2. [Module Roles & Dependency Map](#2-module-roles--dependency-map)
3. [End-to-End Walkthrough](#3-end-to-end-walkthrough)
4. [Module Reference](#4-module-reference)
   - [4.1 `stabl.py` — Core Estimator](#41-stablpy--core-estimator)
   - [4.2 `preprocessing.py` — Filtering](#42-preprocessingpy--filtering)
   - [4.3 `adaptive.py` — Adaptive Estimators](#43-adaptivepy--adaptive-estimators)
   - [4.4 `utils.py` — ML Utilities](#44-utilspy--ml-utilities)
   - [4.5 `metrics.py` — Feature-Selection Metrics](#45-metricspy--feature-selection-metrics)
   - [4.6 `visualization.py` — Plotting](#46-visualizationpy--plotting)
   - [4.7 `pipelines_utils.py` — Benchmarking Utilities](#47-pipelines_utilspy--benchmarking-utilities)
   - [4.8 `stacked_generalization.py` — Late Fusion](#48-stacked_generalizationpy--late-fusion)
   - [4.9 `multi_omic_pipelines.py` — High-Level Pipelines](#49-multi_omic_pipelinespy--high-level-pipelines)
   - [4.10 `unionfind.py` — Union-Find](#410-unionfindpy--union-find)
   - [4.11 `data.py` — Dataset Loaders](#411-datapy--dataset-loaders)
5. [Key Constants & Defaults](#5-key-constants--defaults)
6. [Feature Checklist](#6-feature-checklist)

---

## 1. Algorithm Overview

STABL (**S**tability-**T**hresholding with **A**rtificial **B**iomarkers and **L**asso) is a stability-selection method for sparse, reliable biomarker discovery that controls the expected False Discovery Proportion (FDP) using injected artificial features.

### Mathematical Inputs

| Symbol | Description | Python parameter |
|--------|-------------|-----------------|
| $X \in \mathbb{R}^{n \times p}$ | Observation matrix ($n$ samples, $p$ features) | — |
| $Y \in \mathbb{R}^n$ | Clinical outcomes | — |
| Base SRM | Sparsity-promoting regularization method | `base_estimator` |
| $B$ | Number of bootstrap/subsampling iterations | `n_bootstraps` (default 1000) |
| $\Lambda$ | Grid of regularization parameters | `lambda_grid` |
| $\pi \in (0, 1]$ | Artificial-feature proportion | `artificial_proportion` (default 1.0) |
| $s > 0$ | Subsample fraction | `sample_fraction` (default 0.5) |
| `replace` | Sampling with replacement | `replace` (default False) |

### Five-Step Algorithm

**Step 1 — Noise Injection**

Compute $q = \lfloor p\pi \rfloor$ artificial features. Generate $\tilde{X} \in \mathbb{R}^{n \times q}$ by either random column permutation or Gaussian knockoff. Concatenate:
$$\mathbb{X} = [X \mid \tilde{X}] \in \mathbb{R}^{n \times (p+q)}$$
Define index sets: originals $\mathcal{O} = \{1,\dots,p\}$, artificials $\mathcal{A} = \{p+1,\dots,p+q\}$.

**Step 2 — Subsampling and Model Fitting**

For each iteration $k = 1,\dots,B$: draw $m = \lfloor sn \rfloor$ samples, fit the Base SRM on the subsample across all $\lambda \in \Lambda$, record a binary selection mask per $(k,\lambda)$.

**Step 3 — Feature Selection Frequencies**

For each feature $j$ and $\lambda$:
$$s_j(\lambda) = \frac{1}{B}\sum_{k=1}^B \mathbf{1}[j\text{ selected in }(k,\lambda)]$$
STABL importance score:
$$f_j = \max_{\lambda \in \Lambda} s_j(\lambda)$$

**Step 4 — FDP+ Threshold Optimization**

Sweep threshold grid $t \in [0,1]$ (default step 0.01). For each $t$:
$$FDP_+(t) = \frac{1 + \frac{1}{\pi}\sum_{j \in \mathcal{A}} \mathbf{1}[f_j > t]}{\max\!\left(1,\, \sum_{j \in \mathcal{O}} \mathbf{1}[f_j > t]\right)}$$
Optimal threshold:
$$\theta \in \arg\min_t FDP_+(t)$$
Fallback: $\theta = 1$ if $\min_t FDP_+(t) > 1$.

**Step 5 — Final Feature Selection**

$$\hat{S}(\theta) = \{i \in \mathcal{O} : f_i > \theta\}$$
(strict inequality). Downstream predictive refitting on $\hat{S}$ is a separate pipeline step.

### Python vs. R Differences

| Aspect | Python | R |
|--------|--------|---|
| Artificial-feature count | $q = \lfloor p\pi \rfloor$ (`floor`) | $q = \mathrm{round}(p\pi)$ |
| FDP+ threshold grid default | `np.arange(0., 1., .01)` | `seq(0, 1, by = 0.01)` |
| Grouped bootstrap internals | `GroupShuffleSplit`-based | Different internals, same intent |
| Comparison operator | strict `>` everywhere | strict `>` everywhere |

---

## 2. Module Roles & Dependency Map

### Module Roles

| Module | Role |
|--------|------|
| `stabl.py` | Core STABL estimator: bootstrap loop, artificial features, FDP+ computation, sklearn API |
| `preprocessing.py` | Sample- and feature-level NaN filtering (sklearn-compatible) |
| `adaptive.py` | Iteratively re-weighted Lasso and Logistic Lasso (Adaptive Lasso variants) |
| `utils.py` | Lambda grid auto-tuning, non-partition CV predict/gridsearch, bootstrap CI, permutation test |
| `metrics.py` | Feature-selection reliability metrics: Jaccard, adjusted similarity, Pearson similarity, FDR, TPR, F-score |
| `visualization.py` | All plots: ROC/PRC curves, feature boxplots/scatterplots, FDP+ graphs, stability paths |
| `pipelines_utils.py` | Benchmarking: scores tables, p-value tables, feature tables, prediction plots, `BenchmarkWrapper` |
| `stacked_generalization.py` | Late fusion via random-search over weighted combinations of per-omic predictions |
| `multi_omic_pipelines.py` | High-level orchestration: multi-omic CV and train-validation benchmarking pipelines |
| `unionfind.py` | Union-Find data structure for grouping correlated features (SGL support) |
| `data.py` | Dataset loaders for six benchmark datasets |
| `__init__.py` | Empty — all imports are explicit in consumer code |

### Dependency Graph

```
__init__.py          (empty namespace)

unionfind.py
    ↑
    └─── stabl.py  ◄─── multi_omic_pipelines.py ◄─── benchmark scripts
    └─── multi_omic_pipelines.py

preprocessing.py
    ↑
    └─── multi_omic_pipelines.py
    └─── data.py

adaptive.py
    ↑
    └─── benchmark scripts (not imported within package core)

utils.py
    ↑
    └─── stabl.py  (auto_mode_lambda_grid)
    └─── visualization.py  (compute_CI)
    └─── pipelines_utils.py  (compute_CI, permutation_test_between_clfs)

visualization.py
    ↑
    └─── stabl.py  (boxplot_features, scatterplot_features)
    └─── pipelines_utils.py  (all plot functions)

metrics.py
    ↑
    └─── pipelines_utils.py  (jaccard_matrix)
    └─── multi_omic_pipelines.py

pipelines_utils.py
    ↑
    └─── multi_omic_pipelines.py

stacked_generalization.py
    ↑
    └─── multi_omic_pipelines.py  (late_fusion_cv, late_fusion_validation)

data.py
    ↑
    └─── benchmark scripts
```

---

## 3. End-to-End Walkthrough

This section traces the execution path for a typical single-omic CV benchmark run using `multi_omic_stabl_cv`.

```
1. Load dataset
   data.py: load_covid_19(data_path)
   → (train_data_dict, valid_data_dict, y_train, y_valid, patients_id, "binary")

2. Configure estimators
   stabl.py: Stabl(base_estimator=LogisticRegression(...), lambda_grid="auto", n_bootstraps=1000)
   adaptive.py: ALasso(...), ALogitLasso(...)

3. Outer CV loop [multi_omic_pipelines.py: multi_omic_stabl_cv]
   ├── For each fold (train_idx, test_idx):
   │   ├── preprocessing.py: remove_low_info_samples → preprocessing.fit_transform
   │   │   (VarianceThreshold → LowInfoFilter → SimpleImputer → StandardScaler)
   │   │
   │   ├── stabl.fit(X_train, y_train)  [stabl.py]
   │   │   ├── _validate_input()
   │   │   ├── _check_lambda_grid()  → if "auto": _get_optimized_lambda_grid()
   │   │   │   └── utils.py: auto_mode_lambda_grid(X, y, task_type)
   │   │   ├── _make_artificial_features()
   │   │   │   └── random permutation OR knockpy.GaussianSampler
   │   │   ├── _make_groups()  (if perc_corr_group_threshold set)
   │   │   │   └── unionfind.py: UnionFind.union() for correlated feature pairs
   │   │   ├── _bootstrap_generator(n_bootstraps, classic_bootstrap or group_bootstrap, ...)
   │   │   ├── Main loop over ParameterGrid(fitted_lambda_grid_):
   │   │   │   └── joblib.Parallel: fit_bootstrapped_sample(base_estimator, X_aug, y, λ)
   │   │   │       └── SelectFromModel.get_support() → bool mask
   │   │   └── _compute_FDPplus()
   │   │       → FDRs_, fdrs_table, fdr_min_threshold_
   │   │
   │   ├── stabl.get_support() → selected feature indices
   │   │   └── _get_support_mask()  (uses fdr_min_threshold_ or hard_threshold)
   │   │
   │   ├── (fold 1 only) save_stabl_results(stabl, path, df_X, y, ...)
   │   │   ├── export_stabl_to_csv → STABL scores.csv, Max STABL scores.csv
   │   │   ├── plot_fdr_graph → FDR graph PNG
   │   │   ├── plot_stabl_path → stability path PNG
   │   │   └── visualization.py: boxplot_features / scatterplot_features
   │   │
   │   ├── Baseline models: Lasso, ALasso, ElasticNet fitted; get_support() collected
   │   │
   │   └── predictions accumulated per model per fold
   │
   ├── late_fusion_cv(predictions_lf_dict, y, ...) [if late_fusion=True]
   │   └── stacked_generalization.py: stacked_multi_omic(df_predictions, y, "binary")
   │
   └── Results saved:
       ├── pipelines_utils.py: compute_scores_table → Scores training CV.csv
       ├── pipelines_utils.py: compute_pvalues_table → p-values/{metric}.csv
       └── pipelines_utils.py: save_plots → ROC/PRC/boxplot PNGs

4. Performance evaluation
   utils.py: compute_CI(y_true, y_preds, scoring="roc_auc")
   metrics.py: jaccard_matrix(list_of_selected_per_fold) → CVS score
```

---

## 4. Module Reference

---

### 4.1 `stabl.py` — Core Estimator

**Internal functions** (not part of the public API):

---

#### `classic_bootstrap(y, n_subsamples, replace=True, class_weight=None, rng=np.random.default_rng(None), **kwargs)`

Draw bootstrap sample indices from a dataset.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `y` | array (n,) | — | Outcome array; used for class-balanced weighting |
| `n_subsamples` | int | — | Number of indices to draw |
| `replace` | bool | `True` | Sampling with replacement |
| `class_weight` | None \| `"balanced"` \| dict | `None` | If `"balanced"`: use `compute_sample_weight`; dict: `{class: weight}` |
| `rng` | `np.random.Generator` | `default_rng(None)` | Random generator |

**Algorithm**: Computes sampling probabilities from `class_weight`, then calls `rng.choice(n_samples, size=n_subsamples, replace=replace, p=sampling_probs)`. **Recursive guard**: if resulting sample contains only one class, re-draws recursively.

**Returns**: `ndarray (n_subsamples,)` — sample indices

---

#### `group_bootstrap(y, n_subsamples, groups, replace=False, rng=np.random.RandomState(None), **kwargs)`

Bootstrap at the group level (e.g., per patient) to prevent data leakage.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `y` | array (n,) | — | Outcome array (for single-class guard) |
| `n_subsamples` | int | — | Target number of individual samples |
| `groups` | array (n,) | — | Group labels for each sample |
| `replace` | bool | `False` | Group-level replacement |
| `rng` | `np.random.RandomState` | — | Random state |

**Algorithm**: Uses `GroupShuffleSplit` to draw whole groups until at least `n_subsamples` individual samples are collected. Same recursive single-class guard as `classic_bootstrap`.

**Returns**: `ndarray` — sample indices belonging to selected groups

---

#### `_bootstrap_generator(n_bootstraps, bootstrap_func, y, n_subsamples, replace, random_state=None, **kwargs)`

Pre-generate all bootstrap index sets before the main training loop (deterministic, reproducible).

**Returns**: `list` of length `n_bootstraps`, each element an index array

---

#### `fit_bootstrapped_sample(base_estimator, X, y, lambda_val, corr_groups=None, threshold=None)`

Fit the base estimator on one bootstrap subsample for one lambda value; return a binary selection mask.

**Algorithm**:
1. `estimator = clone(base_estimator)`
2. `estimator.set_params(**lambda_val)`
3. If `corr_groups` is not None: `estimator.set_params(groups=corr_groups)` (SGL path)
4. `estimator.fit(X, y)`
5. `SelectFromModel(estimator, threshold=threshold, prefit=True).get_support()`

**Returns**: `ndarray (n_features,)` bool — selection mask

---

#### `export_stabl_to_csv(stabl, path)`

Export stability score matrices to CSV for post-hoc analysis.

**Files saved**:
- `{path}/STABL scores.csv` — full score matrix `(features × lambdas)`
- `{path}/Max STABL scores.csv` — max score per original feature, sorted descending
- `{path}/STABL artificial scores.csv` — artificial feature score matrix (if artificials used)
- `{path}/Max STABL artificial scores.csv` — max artificial scores, sorted descending

---

#### `plot_fdr_graph(stabl, show_fig, export_file, path, figsize)`

Plot FDP+ vs. threshold curve with optimal threshold marked.

**Returns**: `(fig, ax)`

---

#### `plot_fdr_graph_table(stabl, show_fig, export_file, path, figsize)`

Extended FDP+ plot showing per-lambda FDP+ curves (thin lines) alongside the global curve. Marks both the global optimum and per-lambda optima.

**Returns**: `(fig, ax)`

---

#### `plot_stabl_path(stabl, new_hard_threshold, show_fig, export_file, path, figsize)`

Plot stability selection paths: selection frequency vs. regularization parameter.

**Behavior**:
- Single-parameter grids (alpha or C): one panel
- Two-parameter grids (l1_ratio + alpha/C): one panel per l1_ratio value
- Selected features: red lines; unselected: gray lines; artificial features: dotted gray; threshold: horizontal dashed line

**Returns**: `(fig, ax, x_list, x_order)`

---

#### `save_stabl_results(stabl, path, df_X, y, figure_fmt, new_hard_threshold, task_type, override)`

Orchestrator that saves all STABL outputs to disk.

**Calls** (in order):
1. `export_stabl_to_csv`
2. `plot_fdr_graph` and `plot_fdr_graph_table`
3. `plot_stabl_path`
4. Saves `Selected Features/Selected features.csv`
5. `boxplot_features` (binary/multiclass) or `scatterplot_features` (regression) per selected feature

---

### `Stabl(SelectorMixin, BaseEstimator)` — Main Class

```python
Stabl(
    base_estimator=LogisticRegression(
        penalty='l1', solver='liblinear',
        class_weight='balanced', max_iter=1e6, random_state=42
    ),
    lambda_grid=None,              # default: {"C": np.linspace(0.01, 1, 10)}
    n_lambda=None,
    n_bootstraps=1000,
    artificial_type="random_permutation",
    artificial_proportion=1.0,
    sample_fraction=0.5,
    replace=False,
    hard_threshold=None,
    fdr_threshold_range=None,      # default: np.arange(0., 1., .01)
    explore=False,
    n_explore=5,
    bootstrap_func=classic_bootstrap,
    sample_weight_bootstrap=None,
    bootstrap_threshold=1e-5,
    perc_corr_group_threshold=None,
    sgl_groups=None,
    verbose=0,
    n_jobs=-1,
    random_state=None
)
```

#### Constructor Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `base_estimator` | sklearn estimator | LogisticRegression(L1, liblinear) | Sparsity-promoting base SRM |
| `lambda_grid` | dict \| list of dicts \| `"auto"` \| None | `{"C": linspace(0.01,1,10)}` | Regularization parameter grid. `"auto"` computes from data via `auto_mode_lambda_grid` |
| `n_lambda` | int \| None | None | If set, passed to `auto_mode_lambda_grid` as `n_lambda` |
| `n_bootstraps` | int | 1000 | Number of bootstrap iterations ($B$) |
| `artificial_type` | `"random_permutation"` \| `"knockoff"` \| None | `"random_permutation"` | Type of artificial features. None disables FDP+ control; `hard_threshold` must be set |
| `artificial_proportion` | float | 1.0 | $\pi$ — ratio of artificial to real features |
| `sample_fraction` | float | 0.5 | $s$ — proportion of samples per bootstrap |
| `replace` | bool | False | Sampling with replacement |
| `hard_threshold` | float \| None | None | Override FDP+ threshold with a fixed value |
| `fdr_threshold_range` | array \| None | `np.arange(0., 1., .01)` | Grid of candidate thresholds for FDP+ sweep |
| `explore` | bool | False | If True and FDP+ selects 0 features, fall back to top-`n_explore` features |
| `n_explore` | int | 5 | Number of features to return in explore fallback mode |
| `bootstrap_func` | callable | `classic_bootstrap` | Bootstrap sampling function; swap with `group_bootstrap` for grouped data |
| `sample_weight_bootstrap` | None \| `"balanced"` \| dict | None | Class-balancing passed to `bootstrap_func` as `class_weight` |
| `bootstrap_threshold` | float | 1e-5 | Coefficient magnitude threshold for `SelectFromModel` per bootstrap fit |
| `perc_corr_group_threshold` | float \| None | None | Correlation percentile above which features are grouped (for SGL). Triggers `_make_groups` |
| `sgl_groups` | list \| None | None | User-supplied feature groups for SGL (overrides `perc_corr_group_threshold`) |
| `verbose` | int | 0 | Verbosity level for `tqdm` progress bars |
| `n_jobs` | int | -1 | Joblib parallelism (-1 = all cores) |
| `random_state` | int \| None | None | Seed for all bootstrap random generators |

#### Fitted Attributes

| Attribute | Type | Description |
|-----------|------|-------------|
| `stabl_scores_` | ndarray (p, n_λ) | Bootstrap selection frequency per original feature per lambda |
| `stabl_scores_artificial_` | ndarray (q, n_λ) | Bootstrap selection frequency per artificial feature per lambda |
| `X_artificial_` | ndarray (n, q) | Generated artificial features matrix |
| `FDRs_` | ndarray (n_thresholds,) | FDP+ value at each threshold in `fdr_threshold_range` |
| `fdrs_table` | ndarray (n_λ, n_thresholds) | FDP+ per (lambda, threshold) |
| `min_fdr_` | float | Minimum FDP+ value achieved |
| `fdr_min_threshold_` | float | Threshold $\theta$ achieving `min_fdr_` |
| `fitted_lambda_grid_` | dict | The actual lambda grid used (after "auto" resolution) |
| `explore_threshold` | float \| None | Active threshold in explore mode; None otherwise |
| `feature_names_in_` | ndarray | Feature names from input DataFrame (sklearn convention) |

#### Methods

| Method | Signature | Description | Returns |
|--------|-----------|-------------|---------|
| `fit` | `fit(X, y, groups=None)` | Main training loop | `self` |
| `get_support` | `get_support(indices=False, new_hard_threshold=None)` | Feature selection mask/indices | bool array or int array |
| `get_feature_names_out` | `get_feature_names_out(input_features=None, new_hard_threshold=None)` | Names of selected features | str array |
| `transform` | `transform(X, new_hard_threshold=None)` | Reduce X to selected columns | ndarray |
| `get_importances` | `get_importances()` | Max stability score per feature ($f_j$) | ndarray (p,) |
| `_get_support_mask` | `_get_support_mask(new_hard_threshold=None)` | Core boolean mask logic; handles explore | bool array |
| `_make_artificial_features` | internal | Generate and concatenate artificial features | ndarray |
| `_compute_FDPplus` | internal | Compute `FDRs_`, `fdrs_table`, `fdr_min_threshold_` | None |
| `_make_groups` | internal | Build SGL groups via UnionFind from correlation or user input | list of arrays |
| `_check_lambda_grid` | internal | Validate lambda_grid including "auto" mode | None |
| `_get_optimized_lambda_grid` | internal | Compute auto grid from data | dict or list of dicts |
| `_validate_input` | internal | Check all constructor parameters | None |
| `get_different_parameters` | `get_different_parameters()` | Keys varied across the lambda grid | list of str |

#### `fit` Algorithm Detail

```
fit(X, y, groups=None):
1. _validate_input()
2. _validate_data(X, y)  [sklearn]
3. n_subsamples = floor(sample_fraction * n_samples)
4. _check_lambda_grid()
   └─ if "auto": fitted_lambda_grid_ = _get_optimized_lambda_grid()
      └─ calls utils.auto_mode_lambda_grid(X, y, task_type, l1_ratio, n_lambda)
5. if artificial_type is not None:
   └─ _make_artificial_features()
      ├─ "random_permutation": shuffle each of q randomly chosen columns
      └─ "knockoff": knockpy.GaussianSampler(X).sample_knockoffs()
      X_aug = [X | X_artificial_]
6. if perc_corr_group_threshold or sgl_groups:
   └─ corr_groups = _make_groups()
      └─ UnionFind merges features with |corr| > percentile(all_corr, threshold)
7. bootstraps = _bootstrap_generator(n_bootstraps, bootstrap_func, ...)
8. For each λ in ParameterGrid(fitted_lambda_grid_):
   └─ Parallel(n_jobs): [fit_bootstrapped_sample(estimator, X_aug[boot_idx], y[boot_idx], λ)
                          for boot_idx in bootstraps]
   └─ accumulate stabl_scores_[:, λ_idx] += selection_mask / n_bootstraps
   (stabl_scores_artificial_ for the artificial columns)
9. if artificial_type is not None: _compute_FDPplus()
10. return self
```

#### `_get_support_mask` Logic

```
_get_support_mask(new_hard_threshold=None):
1. check_is_fitted(self)
2. threshold = new_hard_threshold
               ?? hard_threshold
               ?? fdr_min_threshold_
3. max_scores = stabl_scores_.max(axis=1)  [= f_j]
4. mask = (max_scores > threshold)          [strict >]
5. if mask.sum() == 0 and explore:
   └─ explore_threshold = min score of top n_explore features - 0.01
   └─ mask = (max_scores > explore_threshold)
6. return mask
```

---

### 4.2 `preprocessing.py` — Filtering

---

#### `remove_low_info_samples(X, threshold=1.0)`

Remove samples whose NaN fraction meets or exceeds a threshold.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `X` | array-like (n, p) | — | Input data |
| `threshold` | float | 1.0 | NaN fraction above which a sample is dropped |

**Algorithm**: `nan_fraction = np.isnan(X).mean(axis=1)`, return `X[nan_fraction < threshold]`.  
**Raises**: `ValueError` if `threshold` not in [0, 1].  
**Returns**: `DataFrame/array` with samples whose NaN fraction is strictly less than `threshold`

---

#### `LowInfoFilter(SelectorMixin, BaseEstimator)`

sklearn-compatible feature selector that removes features with too many NaN values.

```python
LowInfoFilter(max_nan_fraction=0.2)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_nan_fraction` | float | 0.2 | Features with NaN proportion > this are removed |

**Fitted attributes**:
- `nan_counts_`: ndarray (p,) — NaN count per feature
- `n_samples`: int — number of training samples

**Methods**:

| Method | Description | Returns |
|--------|-------------|---------|
| `fit(X, y=None)` | Compute `nan_counts_`; validates with `allow_nan` | self |
| `_get_support_mask()` | `nan_counts_ <= max_nan_fraction * n_samples` | bool (p,) |
| `_more_tags()` | Returns `{"allow_nan": True}` | dict |

**Raises**: `ValueError` if no features survive the filter.

**Usage in standard preprocessing pipeline**:
```python
preprocessing = Pipeline([
    ("variance", VarianceThreshold(0.01)),
    ("lif", LowInfoFilter()),
    ("impute", SimpleImputer(strategy="median")),
    ("std", StandardScaler())
])
```

---

### 4.3 `adaptive.py` — Adaptive Estimators

---

#### `ALasso(Lasso)`

Adaptive Lasso for regression via iterative feature re-weighting (Zou 2006).

```python
ALasso(
    n_iter_lasso=2,
    alpha=1.0,
    *, fit_intercept=True, precompute=False, copy_X=True,
    max_iter=int(1e6), tol=1e-4, warm_start=False,
    positive=False, random_state=None, selection="cyclic"
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `n_iter_lasso` | int | 2 | Re-weighting iterations |
| All others | — | — | Identical to `sklearn.linear_model.Lasso` |

**`fit` Algorithm**:
```
weights = ones(p)
for _ in range(n_iter_lasso):
    X_w = X / weights
    super().fit(X_w, y)              # sklearn Lasso on scaled features
    coef_ = coef_ / weights          # rescale coefficients back
    weights = 1 / (2 * sqrt(|coef_|) + eps)   # Zou 2006 update
```

---

#### `ALogitLasso(LogisticRegression)`

Adaptive Lasso for classification via iterative feature re-weighting.

```python
ALogitLasso(
    n_iter_lasso=2,
    penalty="l1",
    *, dual=False, tol=1e-4, C=1.0,
    fit_intercept=True, intercept_scaling=1,
    class_weight="balanced", random_state=None,
    solver="liblinear", max_iter=int(1e6),
    multi_class="auto", verbose=0,
    warm_start=False, n_jobs=None, l1_ratio=None,
    norm_order=1
)
```

| Extra Parameter | Type | Default | Description |
|-----------------|------|---------|-------------|
| `n_iter_lasso` | int | 2 | Re-weighting iterations |
| `norm_order` | int \| inf | 1 | Norm order for multiclass coef_ normalization (2D coef_ arrays) |

**`fit` Algorithm**: Identical re-weighting structure to `ALasso` but calls `LogisticRegression.fit` on scaled features.

---

### 4.4 `utils.py` — ML Utilities

---

#### `auto_mode_lambda_grid(X, y, task_type, l1_ratio=None, n_lambda=30)`

Compute a data-driven regularization grid for L1-penalized estimators.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `X` | array (n, p) | — | Input data |
| `y` | array (n,) | — | Outcomes |
| `task_type` | str | — | `"classification"` or `"regression"` |
| `l1_ratio` | float \| list \| None | None | ElasticNet mixing parameter(s). None treated as 1.0 |
| `n_lambda` | int | 30 | Number of lambda values per l1_ratio |

**Algorithm**:
- Classification: `min_C = sklearn.svm.l1_min_c(X, y, loss="log")`, grid = `np.linspace(min_C, min_C * 100, n_lambda)`
- Regression: `l_max = ||X^T y||_∞ / (n * l1_r)`, grid = `np.geomspace(l_max/30, l_max+5, n_lambda)`
- Multi-ratio: returns a list of dicts (one per ratio, each including `"l1_ratio": [l1]`)

**Returns**: `dict` or `list of dicts` — ParameterGrid-compatible

---

#### `fit_predict(estimator, X, y, train, test, task_type)`

Fit estimator on train, predict on test. Returns full-length array with NaN for non-test indices. Designed for joblib parallelism.

**Returns**: ndarray (n,) with NaN for train indices; or (n, n_classes) for multiclass

---

#### `nonpartition_cross_val_predict(estimator, X, y, task_type, splitter, groups=None)`

Cross-validation where samples can appear in multiple test folds. Final prediction = median across folds.

**Algorithm**: Parallel `fit_predict` for each fold; aggregate via `np.nanmedian`. For multiclass, renormalizes median predictions to sum to 1.

**Returns**: `(predictions [B × n], median_prediction [n])`

---

#### `nonpartition_gridsearch(estimator, param_grid, X, y, task_type, splitter=RepeatedKFold(5,10), groups=None)`

Grid search using non-partitioning CV. Scores pooled predictions (not per-fold). Refits best params on full data.

**Scoring**: ROC-AUC (binary), R2 (regression), OvR-ROC-AUC (multiclass)

**Returns**: `(fitted_estimator, best_params dict, best_predictions array)`

---

#### `loo_gridsearch(estimator, param_grid, X, y, task_type, cv=LeaveOneOut(), groups=None)`

Grid search using LOO-CV (or LOGO with `GroupShuffleSplit`). Evaluates pooled LOO predictions.

**Returns**: `best_params dict` — does NOT refit; caller responsible for final fit

---

#### `compute_CI(y_true, y_preds, confidence_level=0.95, scoring="roc_auc", return_CI_predictions=False)`

Bootstrap confidence interval for a prediction metric (1000 resamples).

| Supported scoring | Notes |
|-------------------|-------|
| `"roc_auc"` | Re-samples until both classes present |
| `"average_precision"` | Re-samples until both classes present |
| `"prc_auc"` | Re-samples until both classes present |
| `"roc_auc_ovr"` | One-vs-rest; no stratification needed |
| `"r2"` | Direct resample |
| `"rmse"` | Direct resample |
| `"mae"` | Direct resample |

**Returns**: `(CI_low, CI_high)`.  
If `return_CI_predictions=True` (AUC metrics only): also returns a DataFrame of bootstrap samples at the CI bounds.

---

#### `permutation_test_between_clfs(y_true, pred_probas_1, pred_probas_2, scoring="roc_auc", n_repeats=1000)`

Two-sided permutation test for the difference in performance between two classifiers.

**Algorithm**: Compute observed score difference; randomly swap predictions 1000 times; compute fraction of random differences ≥ |observed| (two-sided).

**Returns**: `(observed_difference: float, p_value: float)`

---

### 4.5 `metrics.py` — Feature-Selection Metrics

All functions operate on lists of feature names (or indices).

---

#### `jaccard_similarity(list1, list2) → float`

$|A \cap B| / |A \cup B|$. Returns 0 when both empty.

---

#### `jaccard_matrix(list_of_lists, remove_diag=True) → ndarray`

Pairwise Jaccard similarity matrix. Used to compute Cross-Validation Stability (CVS).  
`remove_diag=True` returns only the upper-triangle values (excluding diagonal 1s).

---

#### `adjusted_similarity(list1, list2, nb_total_elements) → float`

Chance-adjusted feature overlap ∈ (-1, 1].

$$\text{adj\_sim} = \frac{r - k_1 k_2/d}{\min(k_1, k_2) - \max(0, k_1+k_2-d)}$$

where $r = |A \cap B|$, $k_i = |A_i|$, $d$ = total features. Handles edge cases (empty sets, full sets).

---

#### `adjusted_similarity_values(list_of_lists, nb_total_elements) → ndarray`

Upper-triangle values of the pairwise adjusted similarity matrix; shape `(n(n-1)/2,)`.

---

#### `adjusted_similarity_measure(list_of_lists, nb_total_elements, stat="median") → (statistic, err)`

Summary statistic over all pairwise adjusted similarities.  
`stat="median"` → `(median, [Q1, Q3])`; `stat="mean"` → `(mean, std)`

---

#### `pearson_similarity(list_i, list_j, d) → float`

Pearson-type feature-set correlation:
$$\frac{r - E[r]}{d \cdot \sigma_i \cdot \sigma_j}$$
where $E[r] = k_i k_j / d$.

---

#### `pearson_similarity_values(list_of_lists, d) → ndarray`

Upper-triangle Pearson similarity values; shape `(n(n-1)/2,)`.

---

#### `pearson_similarity_measure(list_of_lists, d, stat="median") → (statistic, err)`

Summary statistic over pairwise Pearson similarities.

---

#### `fdr_similarity(list1, list2) → float`

$FP / (TP + FP)$ where `list2` is ground truth. Returns 0 if `list1` is empty.

---

#### `tpr_similarity(list1, list2) → float`

$TP / (TP + FN)$ where `list2` is ground truth.

---

#### `fscore_similarity(list1, list2, beta=1) → float`

$F_\beta$ score balancing FDR and TPR. $\beta < 1$ weights precision higher; $\beta > 1$ weights recall higher.

---

### 4.6 `visualization.py` — Plotting

**Module-level palette**:
```python
colors = ['#a8e6ce','#dcedc2','#ffd3b5','#ffaaa6','#ff8c94','#e3819d','#a188b7','#487fad']
surge_palette = sns.color_palette(colors)
```

---

#### `plot_roc(y_true, y_preds, show_fig, show_CI, CI_level, export_file, path, **kwargs)`

Plot ROC curve. Annotates AUC. If `show_CI=True`: fetches CI-bound prediction arrays via `compute_CI(return_CI_predictions=True)` and overlays the corresponding ROC curves as dashed pink lines.

**Returns**: `(fig, ax)`

---

#### `plot_prc(y_true, y_preds, show_fig, show_CI, show_iso, CI_level, export_file, path, **kwargs)`

Plot Precision-Recall curve. Annotates AUPRC. Optional:
- `show_CI`: overlay CI-bound PRC curves
- `show_iso`: add iso-F1 lines via `add_iso_lines`

**Returns**: `(fig, ax)`

---

#### `boxplot_features(features, df_X, y, categorical_features, cmap, show_zero, show_fig, export_file, path, fmt)`

Boxplot + strip plot of selected features vs. binary/multiclass outcome.

| Parameter | Type | Description |
|-----------|------|-------------|
| `features` | list | Feature names to plot |
| `df_X` | DataFrame | Feature matrix |
| `y` | Series | Binary/multiclass outcome |
| `categorical_features` | list \| int | Feature names to treat as categorical, or max unique-value count threshold |
| `show_zero` | bool | Force y-axis to include 0 |

Categorical features → bar chart; continuous features → boxplot + strip plot.

---

#### `scatterplot_features(features, df_X, y, categorical_features, cmap, show_fig, export_file, path, fmt, **kwargs)`

Scatter plot (continuous outcome) or boxplot (categorical feature) of selected features vs. regression outcome.

---

#### `boxplot_binary_predictions(y_true, y_preds, show_fig, export_file, path, figsize, classes, **kwargs)`

Boxplot + strip plot of predicted probabilities grouped by class. Annotates with:
- AUROC ± 95% CI
- AUPRC ± 95% CI

**Returns**: `(fig, ax)`

---

#### `scatterplot_regression_predictions(y_true, y_preds, show_fig, export_file, paths, linear_estimation, **kwargs)`

Scatter plot: predicted vs. actual. Annotates with R², RMSE, MAE (each with bootstrap CI) and Pearson r. Optional: overlay linear regression line.

**Returns**: `(fig, ax)`

---

#### `make_beautiful_axis(ax, plot_type, gridline_axis)`

Standardize axis appearance.

| `plot_type` value | Effect |
|-------------------|--------|
| `"roc"` | ROC-specific spine/tick style |
| `"prc"` | PRC-specific spine/tick style |
| `"barplot"` | Barplot style |
| `"boxplot"` | Boxplot style |
| `"scatterplot"` | Scatterplot style |

Removes top/right spines, adds grids, styles labels.

**Returns**: `ax`

---

#### `add_iso_lines(ax, iso_number=4)`

Add iso-F1 curves to a PRC plot.  
For each F1 in `np.linspace(0.2, 0.8, iso_number)`: plots $y = F \cdot x / (2x - F)$.

---

#### Internal helpers

| Function | Description |
|----------|-------------|
| `_adjust_box_widths(fig, fac, barplot=False)` | Rescale seaborn boxplot/barplot box widths by factor `fac` |
| `_is_categorical(df, feature, categorical_features)` | True if feature name in list, or `df[feature].nunique() <= categorical_features` (int threshold) |

---

### 4.7 `pipelines_utils.py` — Benchmarking Utilities

---

#### `save_plots(predictions_dict, y, task_type, save_path)`

Save prediction plots for all models to `{save_path}/{model_name}/`.

| `task_type` | Plots saved |
|-------------|-------------|
| `"binary"` | ROC curve, PRC curve, boxplot of predictions, predictions CSV |
| `"regression"` | Scatter plot of predictions, predictions CSV |

---

#### `compute_scores_table(predictions_dict, y, task_type, selected_features_dict=None) → DataFrame`

Build summary performance table.

**Binary metrics** (each as `"value [CI_lo, CI_hi]"`):
- ROC AUC
- Average Precision

**Regression metrics** (each as `"value [CI_lo, CI_hi]"`):
- R²
- RMSE
- MAE

**Feature metrics** (as `"median [Q1, Q3]"`):
- N features selected per fold
- CVS (Cross-Validation Stability) = median Jaccard similarity across folds

**Returns**: `pd.DataFrame` (index = model names, columns = metrics)

---

#### `compute_pvalues_table(predictions_dict, y, task_type, selected_features_dict=None) → dict of DataFrames`

Pairwise significance testing between all model pairs.

| Metric | Test |
|--------|------|
| ROC AUC | `permutation_test_between_clfs` |
| Average Precision | `permutation_test_between_clfs` |
| N features | Mann-Whitney U |
| CVS | Mann-Whitney U |
| Regression predictions | Mann-Whitney U |

**Returns**: `dict` — key = metric name, value = `pd.DataFrame` (n_models × n_models p-values)

---

#### `compute_features_table(selected_features_dict, X_train, y_train, X_test=None, y_test=None, task_type="binary") → DataFrame`

Feature-level summary: boolean columns indicating which models selected each feature, plus per-feature significance tests.

| `task_type` | Tests |
|-------------|-------|
| `"binary"` | Mann-Whitney U, t-test (on train; optionally also test) |
| `"regression"` | Pearson r, Spearman r (on train; optionally also test) |

**Returns**: `pd.DataFrame` (index = feature names)

---

#### `BenchmarkWrapper`

Uniform adapter to plug any sklearn-compatible estimator into the STABL benchmarking framework.

```python
BenchmarkWrapper(
    model,
    fit=None,
    predict=None,
    use_predict_proba=True,
    get_support=None,
    get_importances=None,
    threshold=1e-5
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `model` | estimator | — | Wrapped estimator |
| `fit` | callable \| None | None | Custom fit function; auto-detected from `model` if None |
| `predict` | callable \| None | None | Custom predict; uses `predict_proba` if `use_predict_proba=True` and available |
| `get_support` | callable \| None | None | Custom support getter; else derived via `SelectFromModel`-style thresholding |
| `get_importances` | callable \| None | None | Custom importance getter; else from `coef_` or `feature_importances_` |
| `threshold` | float | 1e-5 | Magnitude cutoff for support derivation |

**Internal methods**:
- `_set_attr(attr, value)` — auto-resolve attributes from model
- `_get_importances()` — calls sklearn's `_get_feature_importances` on `model` or `model.best_estimator_`
- `_get_support(indices=False)` — applies `threshold` to importances

---

### 4.8 `stacked_generalization.py` — Late Fusion

---

#### `stacked_multi_omic(df_predictions, y, task_type, n_iter=10000) → (DataFrame, DataFrame)`

Late fusion via random-search over weighted combinations of per-omic predictions.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `df_predictions` | DataFrame | — | Columns = per-omic predictions; NaN-safe |
| `y` | Series | — | Outcomes |
| `task_type` | str | — | `"binary"` or `"regression"` |
| `n_iter` | int | 10000 | Number of random weight vectors to evaluate |

**Algorithm**:
```
For i in range(n_iter):
    w ~ Uniform(0, 10)^K   (K = number of omics)
    weighted_pred[i] = Σ_k(w_k * pred_k) / Σ_k(w_k * 1[pred_k ≠ NaN])
    score[i] = ROC-AUC(y, weighted_pred[i])   # binary
               R2(y, weighted_pred[i])          # regression
best_weights = w[argmax(score)]
```

NaN-safe: samples missing predictions from some omics still contribute via the available omics.

**Returns**:
- `df_predictions` with a `"Stacked Gen. Predictions"` column added
- `df_weights` — DataFrame of best weight per omic

---

### 4.9 `multi_omic_pipelines.py` — High-Level Pipelines

#### Module-Level Constants

```python
outter_cv = RepeatedStratifiedKFold(n_splits=5, n_repeats=20, random_state=42)
inner_reg_cv = RepeatedKFold(n_splits=5, n_repeats=5, random_state=42)
inner_cv = RepeatedStratifiedKFold(n_splits=5, n_repeats=5, random_state=42)
inner_group_cv = GroupShuffleSplit(n_splits=25, test_size=0.2, random_state=42)
nb_param = 50

logit = LogisticRegression(penalty=None, class_weight="balanced", max_iter=1e6, random_state=42)
linreg = LinearRegression()

preprocessing = Pipeline([
    ("variance", VarianceThreshold(0.01)),
    ("lif", LowInfoFilter()),
    ("impute", SimpleImputer(strategy="median")),
    ("std", StandardScaler())
])
```

---

#### Internal: `_make_groups(X, percentile) → list of ndarray`

Correlation-based feature grouping via UnionFind. Merges feature pairs with `|corr(i,j)| > np.percentile(all_corr, percentile)`.

---

#### `multi_omic_stabl_cv(data_dict, y, outer_splitter, estimators, task_type, save_path, models, outer_groups, early_fusion, late_fusion, n_iter_lf)`

Full k-fold cross-validation benchmark of STABL and baseline models across all omics.

| Parameter | Type | Description |
|-----------|------|-------------|
| `data_dict` | `{omic: DataFrame}` | Training data per omic |
| `y` | Series | Outcomes (index-aligned) |
| `outer_splitter` | sklearn splitter | Outer CV strategy |
| `estimators` | dict | Keys: `"lasso"`, `"alasso"`, `"en"`, `"stabl_lasso"`, `"stabl_alasso"`, `"stabl_en"` |
| `models` | list of str | Which models to run |
| `outer_groups` | Series \| None | Group labels for group-based CV |
| `early_fusion` | bool | Concatenate all omics before fitting baseline models |
| `late_fusion` | bool | Combine per-omic predictions via `stacked_multi_omic` |
| `n_iter_lf` | int | Random search iterations for late fusion |

**Inner loop (per fold, per omic)**:
1. `remove_low_info_samples` → `preprocessing.fit_transform`
2. `stabl.fit(X_train, y_train)` → selected features collected
3. Fold-1 only: `save_stabl_results`
4. Baseline models (Lasso/ALasso/ElasticNet) fitted; predictions collected
5. Combined feature matrix from STABL selections → refit `logit`/`linreg` → store predictions
6. Late fusion: `late_fusion_cv` if enabled
7. Early fusion: concatenate all omics, fit each baseline

**Files saved**:
- `{save_path}/Training CV/Selected Features {model}.csv`
- `{save_path}/Training CV/STABL Lasso results on {omic}/` (fold 1)
- `{save_path}/Summary/Scores training CV.csv`
- `{save_path}/Training CV/p-values/{metric}.csv`
- Prediction plots

**Returns**: `predictions_dict` — `{model_name: pd.Series of median predictions}`

---

#### `multi_omic_stabl(data_dict, y, estimators, task_type, save_path, models, stabl_params, groups, early_fusion, X_test, y_test, n_iter_lf)`

Train-validation version: fit on full training set, evaluate on held-out validation.

**Additional parameters**:

| Parameter | Type | Description |
|-----------|------|-------------|
| `stabl_params` | `{"model": {"omic": lambda_grid}}` | Per-omic lambda grid overrides applied via `stabl.set_params(lambda_grid=...)` |
| `X_test` | `{omic: DataFrame}` \| None | Held-out validation data |
| `y_test` | Series \| None | Held-out outcomes |

**Key differences from CV version**:
- No outer fold loop; trains once on full data
- Applies `stabl_params` overrides per omic
- Saves baseline model coefficient CSVs per omic
- Computes and saves scores/p-values against `y_test`

**Returns**: test-set `predictions_dict`

---

#### `late_fusion_cv(predictions_lf_dict, y, task_type, save_path, n_iter=10000)`

Late fusion for CV mode: stacks per-omic predictions (median across folds) for each model.

**Returns**: `{model_name: pd.Series of stacked predictions}`

---

#### `late_fusion_validation(predictions_train_dict, predictions_valid_dict, y, task_type, save_path, n_iter)`

Late fusion for train-validation mode: learns weights from training predictions, applies same weights to validation.

**Algorithm**:
1. `stacked_multi_omic(train_predictions, y_train)` → `best_weights`
2. Apply `best_weights` to `valid_predictions`: $\hat{y}_{test} = \sum_k w_k \hat{p}^{test}_{ik} / \sum_k w_k$

**Returns**: `{model_name: pd.Series of test predictions}` or `None` if no validation data

---

### 4.10 `unionfind.py` — Union-Find

#### `UnionFind`

Weighted-quick-union with path compression. Stores arbitrary immutable objects as elements.

```python
UnionFind(elements=None)
```

**Internal state**:
- `_par`: parent index array
- `_siz`: component size array
- `_indx`: element → index dict
- `_elts`: element list

**Methods**:

| Method | Signature | Description | Returns |
|--------|-----------|-------------|---------|
| `__len__` | `len(uf)` | Number of elements | int |
| `__contains__` | `x in uf` | Membership test | bool |
| `__getitem__` | `uf[i]` | Element at index `i` | element |
| `__setitem__` | `uf[i] = x` | Set element at index `i` | None |
| `add` | `add(x)` | Add element as its own component; no-op if present | None |
| `find` | `find(x)` | Root of x's component (applies path compression) | int (root index) |
| `connected` | `connected(x, y)` | Whether x and y share a component | bool |
| `union` | `union(x, y)` | Merge components of x and y (weighted union); adds if not present | None |
| `component` | `component(x)` | All elements in x's component | set |
| `components` | `components()` | All disjoint components | list of sets |
| `component_mapping` | `component_mapping()` | Element → component set mapping | dict |

---

### 4.11 `data.py` — Dataset Loaders

All loaders return a standardized 6-tuple:
```
(train_data_dict, valid_data_dict, y_train, y_valid, patients_id, task_type)
```
`valid_data_dict`, `y_valid`, `patients_id` may be `None`.

---

| Function | Dataset | Omics | Task | Has Validation | Notable Preprocessing |
|----------|---------|-------|------|----------------|-----------------------|
| `load_onset_of_labor(data_path)` | Onset of Labor | CyTOF, Proteomics | regression | Yes (DOS) | `np.sinh(x)*5` on CyTOF validation |
| `load_onset_of_labor_cv(data_path)` | Onset of Labor CV | CyTOF, Proteomics, Metabolomics | regression | No | — |
| `load_dream(data_path)` | DREAM preterm birth | Phylotype, Taxonomy | binary | No | — |
| `load_cfrna(data_path, percentile=None)` | cfRNA Preeclampsia | CFRNA | binary | No | `remove_low_info_samples`, `log2(x+1)` transform, optional variance percentile filter |
| `load_covid_19(data_path)` | COVID-19 severity | Proteomics | binary | Yes | — |
| `load_ssi(data_path)` | Surgical Site Infection | CyTOF, Proteomics | binary | No | — |

---

## 5. Key Constants & Defaults

| Location | Name | Value | Purpose |
|----------|------|-------|---------|
| `stabl.py` | Default `base_estimator` | `LogisticRegression(penalty='l1', solver='liblinear', class_weight='balanced', max_iter=1e6, random_state=42)` | Default SRM |
| `stabl.py` | Default `lambda_grid` | `{"C": np.linspace(0.01, 1, 10)}` | Default regularization grid |
| `stabl.py` | Default `fdr_threshold_range` | `np.arange(0., 1., .01)` | FDP+ threshold sweep grid |
| `stabl.py` | Default `n_bootstraps` | 1000 | Bootstrap iterations |
| `stabl.py` | Default `sample_fraction` | 0.5 | Subsampling fraction $s$ |
| `stabl.py` | Default `artificial_proportion` | 1.0 | $\pi$ parameter |
| `stabl.py` | Default `bootstrap_threshold` | 1e-5 | SelectFromModel coefficient cutoff |
| `stabl.py` | Default `n_explore` | 5 | Explore-mode fallback feature count |
| `multi_omic_pipelines.py` | `outter_cv` | `RepeatedStratifiedKFold(n_splits=5, n_repeats=20, random_state=42)` | Default outer CV |
| `multi_omic_pipelines.py` | `inner_cv` | `RepeatedStratifiedKFold(n_splits=5, n_repeats=5, random_state=42)` | Default inner CV |
| `multi_omic_pipelines.py` | `inner_group_cv` | `GroupShuffleSplit(n_splits=25, test_size=0.2, random_state=42)` | Grouped inner CV |
| `multi_omic_pipelines.py` | Standard preprocessing | `VarianceThreshold(0.01) → LowInfoFilter() → SimpleImputer(median) → StandardScaler()` | Per-fold preprocessing |
| `utils.py` | `compute_CI` resamples | 1000 | Bootstrap CI resamples |
| `stacked_generalization.py` | Weight range | `Uniform(0, 10)` | Random weight search range |
| `visualization.py` | `surge_palette` | 8-color hex palette | Default plot colors |

---

## 6. Feature Checklist

> Use this checklist when tracking R reimplementation coverage. Mark items `[x]` when the corresponding R behavior is implemented and validated.

### Core STABL Algorithm

- [ ] Bootstrap sampling — classic (ungrouped), configurable replacement
- [ ] Bootstrap sampling — group-level (prevent leakage), `GroupShuffleSplit`-based
- [ ] Pre-generation of all bootstrap index sets (deterministic, reproducible)
- [ ] Class-balanced bootstrap weighting (`class_weight="balanced"` or dict)
- [ ] Artificial feature generation — random permutation (`artificial_type="random_permutation"`)
- [ ] Artificial feature generation — Gaussian knockoff (`artificial_type="knockoff"`, `knockpy.GaussianSampler`)
- [ ] No artificial features — hard threshold mode (`artificial_type=None`, `hard_threshold` required)
- [ ] Artificial proportion $\pi$ control (`artificial_proportion`)
- [ ] Subsampling fraction $s$ control (`sample_fraction`)
- [ ] Sampling with or without replacement (`replace`)
- [ ] Per-bootstrap `SelectFromModel` coefficient threshold (`bootstrap_threshold=1e-5`)
- [ ] FDP+ computation over threshold grid (`fdr_threshold_range`)
- [ ] Per-lambda FDP+ table (`fdrs_table`)
- [ ] Optimal threshold selection (`fdr_min_threshold_`, fallback to 1 if `min_fdr_ > 1`)
- [ ] Explore mode — fallback to top-N features when FDP+ selects 0 (`explore`, `n_explore`)
- [ ] Correlation-based feature grouping for SGL (`perc_corr_group_threshold`)
- [ ] User-supplied SGL groups (`sgl_groups`)
- [ ] Regularization grid — user-supplied dict
- [ ] Regularization grid — user-supplied list of dicts (multi-ratio)
- [ ] Regularization grid — auto mode (`lambda_grid="auto"`)
- [ ] sklearn `SelectorMixin` interface: `fit`, `transform`, `get_support`, `get_feature_names_out`
- [ ] `get_importances()` — returns max stability score $f_j$ per feature
- [ ] Fitted attributes: `stabl_scores_`, `stabl_scores_artificial_`, `X_artificial_`, `FDRs_`, `min_fdr_`, `fdr_min_threshold_`
- [ ] `get_different_parameters()` — returns which keys are varied in the lambda grid
- [ ] `n_jobs` parallelism for bootstrap loop

### Adaptive Estimators

- [ ] Adaptive Lasso for regression (`ALasso`) — iterative re-weighting, Zou 2006
- [ ] Adaptive Logistic Lasso for classification (`ALogitLasso`) — iterative re-weighting
- [ ] Configurable number of re-weighting iterations (`n_iter_lasso`)
- [ ] Multiclass coefficient norm order (`norm_order` in `ALogitLasso`)

### Preprocessing

- [ ] Sample-level NaN filter (`remove_low_info_samples`, threshold = NaN fraction)
- [ ] Feature-level NaN filter, sklearn transformer (`LowInfoFilter`, `max_nan_fraction`)
- [ ] Standard preprocessing pipeline: `VarianceThreshold(0.01)` → `LowInfoFilter()` → `SimpleImputer(median)` → `StandardScaler()`

### Lambda Grid Utilities

- [ ] Auto classification grid: `l1_min_c`-based, `linspace(min_C, min_C*100, n_lambda)`
- [ ] Auto regression grid: geomspace, `l_max = ||X^T y||_∞ / (n * l1_r)`
- [ ] Multi-ratio grid support: list of dicts, one per l1_ratio value

### Cross-Validation Utilities

- [ ] Non-partition cross-val predict (median aggregation across folds)
- [ ] Non-partition grid search (pooled scoring, refit on full data)
- [ ] LOO grid search (pooled LOO scoring, no refit)
- [ ] `fit_predict` — single fold fit-and-predict helper

### Metrics

- [ ] Jaccard similarity (pairwise)
- [ ] Jaccard matrix (cross-fold; optional diagonal removal)
- [ ] Adjusted similarity (chance-corrected)
- [ ] Adjusted similarity values (upper triangle)
- [ ] Adjusted similarity measure (median/mean summary)
- [ ] Pearson similarity (feature-set correlation)
- [ ] Pearson similarity values (upper triangle)
- [ ] Pearson similarity measure
- [ ] FDR similarity (vs. ground truth)
- [ ] TPR similarity (vs. ground truth)
- [ ] F-score similarity (configurable $\beta$)

### Visualization

- [ ] ROC curve with optional bootstrap CI curves
- [ ] Precision-Recall curve with optional CI and iso-F1 lines
- [ ] Iso-F1 line overlay utility
- [ ] Boxplot of selected features — binary/multiclass outcome
- [ ] Scatter plot of selected features — regression outcome
- [ ] Categorical feature detection (name list or unique-count threshold)
- [ ] Boxplot of binary predictions (AUROC + AUPRC annotation)
- [ ] Scatter plot of regression predictions (R², RMSE, MAE, Pearson r annotation)
- [ ] FDP+ graph — optimal threshold highlighted
- [ ] FDP+ graph with per-lambda curves
- [ ] Stability path plot (single-parameter grid)
- [ ] Stability path plot (multi-ratio grid, one panel per l1_ratio)
- [ ] Axis beautification utility (`make_beautiful_axis`)
- [ ] Custom 8-color surge palette

### Benchmarking & Reporting

- [ ] Scores summary table with bootstrap CI (binary: ROC AUC, Avg. Precision; regression: R², RMSE, MAE)
- [ ] N features per fold (median [IQR]) in scores table
- [ ] CVS (Cross-Validation Stability = median Jaccard) in scores table
- [ ] Pairwise p-value table (permutation test for AUC; Mann-Whitney for others)
- [ ] Features table (per-feature significance tests: Mann-Whitney / t-test for binary; Pearson / Spearman for regression)
- [ ] Save prediction plots by task type (ROC, PRC, boxplot / scatter)
- [ ] `BenchmarkWrapper` — plug any estimator into benchmarking framework
- [ ] Bootstrap CI (1000 resamples): ROC AUC, Avg. Precision, PRC AUC, OvR ROC AUC, R², RMSE, MAE

### Multi-Omic Pipelines

- [ ] CV mode — `multi_omic_stabl_cv` (repeated stratified k-fold outer loop)
- [ ] Train-validation mode — `multi_omic_stabl` (fit once, evaluate on hold-out)
- [ ] Per-omic lambda grid override (`stabl_params` nested dict)
- [ ] Early fusion (concatenate all omics before fitting baseline models)
- [ ] Late fusion CV (`late_fusion_cv`)
- [ ] Late fusion validation — weights from training, applied to test (`late_fusion_validation`)
- [ ] Group-based outer CV splitting (`outer_groups`)
- [ ] Per-fold STABL result saving (fold 1 output)
- [ ] Baseline models: Lasso, ALasso, ElasticNet per omic
- [ ] Combined feature refit: `logit` / `linreg` on STABL-selected features from all omics

### Late Fusion

- [ ] NaN-safe weighted-mean prediction combiner
- [ ] Random search over weight vectors (`n_iter` configurable)
- [ ] Task-adaptive scoring: ROC-AUC for binary, R² for regression
- [ ] Weight export (`df_weights` DataFrame)

### Data Loaders

- [ ] `load_onset_of_labor` (CyTOF + Proteomics, regression, with validation)
- [ ] `load_onset_of_labor_cv` (CyTOF + Proteomics + Metabolomics, regression, CV variant)
- [ ] `load_dream` (Phylotype + Taxonomy, binary)
- [ ] `load_cfrna` (cfRNA, binary, `log2(x+1)` transform, optional variance filter)
- [ ] `load_covid_19` (Proteomics, binary, with validation set)
- [ ] `load_ssi` (CyTOF + Proteomics, binary)

### Output / Export

- [ ] Export STABL score matrix to CSV (full matrix: features × lambdas)
- [ ] Export max STABL scores to CSV (sorted descending)
- [ ] Export artificial feature score matrix to CSV
- [ ] Export selected features list to CSV
- [ ] Export FDP+ graph (PNG/PDF/SVG)
- [ ] Export per-lambda FDP+ graph
- [ ] Export stability path plot
- [ ] Export per-feature boxplots / scatter plots
- [ ] Export scores summary CSV
- [ ] Export p-values CSV (one file per metric)
- [ ] Export baseline model coefficient CSVs
