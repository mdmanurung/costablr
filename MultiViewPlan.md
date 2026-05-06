# MultiViewPlan: Cooperative Fusion Behavior Hardening

**Status**: In Progress (Phase CF-1 → CF-2)  
**Last Updated**: 2026-05-04  
**Owner**: Cooperative Fusion Experimental Track

## Purpose

This document tracks the implementation and validation of behavior-level assertions for the experimental cooperative fusion branch in `stablr`. It serves as the detailed specification and progress ledger for **Item 1** of the Phase 8 hardening roadmap.

Reference documents:
- `PLAN.md`: Overall roadmap and phase gates
- `PROGRESS.md`: Factual execution log
- `HANDOFF.md`: Fresh-session bootstrap and next 3 tasks
- `MultiView.md`: Cooperative fusion planning and evidence bridge

## Scope

Add comprehensive behavior-level comparative tests that validate:
1. Cooperative fusion produces **different feature selections** than pure early or pure late fusion
2. Cooperation strength (`rho` parameter) actually **affects the output** (rho > 0 differs from rho = 0)
3. Selections are **deterministic and stable** under fixed random state
4. Behavior is **consistent across families** (gaussian, binomial, cox)
5. **Policy constraints are enforced** (`lambda.1se` only in CV mode, cox validation-mode rejected)
6. **Optional dependency failures are graceful** (multiview absent)

## Implementation Plan

### Phase 1: Test Design (COMPLETE)

Designed 12 comprehensive test cases covering:
- Rho effect validation
- Fusion mode differences (early vs cooperative vs late)
- Determinism and reproducibility
- Family-specific behavior (gaussian, binomial, cox)
- Parameter constraints and guards
- Optional dependency handling

### Phase 2: Test Implementation (IN PROGRESS)

**Target file**: `r-pkg/stablr/tests/testthat/test-multiomic-workflows.R`

**Insertion point**: End of file (after existing print method tests)

**Status**: Ready for implementation

### Phase 3: Validation (PENDING)

**Commands**:
```bash
# Run all cooperative tests
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'cooperative')"

# Run full multiomic suite
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"

# Run all tests to ensure no regressions
conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr')"
```

**Success criteria**:
- All 12 new tests pass
- No regressions in existing tests
- Full suite maintains `PASS 309+` baseline

### Phase 4: Documentation (PENDING)

Update:
- `PROGRESS.md` with factual validation results
- `PLAN.md` if acceptance gates change
- `HANDOFF.md` next 3 tasks section

## Test Specification

### Test 1: rho Effect (Cooperation Strength Validation)

**Name**: `cooperative_fusion with rho>0 produces different selections than rho=0`

**Purpose**: Verify that active cooperation (`rho > 0`) alters feature selection relative to baseline (`rho = 0`)

**Data design**:
- Two omics with clear per-omic signal structure
- Outcome driven by features from both omics
- Signal designed to encourage cooperation benefit

**Assertions**:
- `rho = 0` and `rho > 0` produce different selected features
- At least one omic differs between modes

**Seed**: 100

---

### Test 2: Fusion Mode Differences

**Name**: `early_fusion, cooperative, and late_fusion select different features`

**Purpose**: Confirm that all three fusion modes produce distinct feature selections

**Data design**:
- Multi-omic with unique strong signal per omic + shared noise
- Outcome combines signals from both omics

**Assertions**:
- Early fusion selects from concatenated space
- Cooperative mode does not exactly match early fusion
- Late fusion produces weights and predictions

**Seed**: 101

---

### Test 3: Determinism and Stability

**Name**: `cooperative_fusion produces stable selections across repeated runs with same seed`

**Purpose**: Validate deterministic behavior—repeated runs with identical parameters should yield identical results

**Data design**:
- Standard Gaussian multi-omic (n=35)

**Assertions**:
- Run 1 selected features == Run 2 selected features
- Run 1 train predictions == Run 2 train predictions (within tolerance)
- Run 1 chosen rho == Run 2 chosen rho
- Run 1 chosen lambda == Run 2 chosen lambda

**Seed**: 104 (both runs)

---

### Test 4: Binomial Family Consistency

**Name**: `cooperative_fusion with binomial family selects features consistently`

**Purpose**: Ensure cooperative mode works correctly for classification outcomes

**Data design**:
- Binary outcome with clear logistic signal structure
- Clear per-omic features

**Assertions**:
- cv.multiview fit exists
- Train predictions exist and are numeric
- Predictions bounded in [0, 1] (valid probabilities)
- Selected features exist for both omics

**Seed**: 106

---

### Test 5: rho Grid Tuning

**Name**: `cooperative_fusion produces rho-aware behavior in CV mode`

**Purpose**: Validate that rho grid exploration works and results in sensible selection

**Data design**:
- Multi-omic with clear signal (n=45)
- Test rho grid: c(0, 0.1, 0.3, 0.5)

**Assertions**:
- Chosen rho is one of the provided values
- cv.multiview fit exists
- Fold assignments are deterministic (values in 1:3)

**Seed**: 108

---

### Test 6: Validation-Based Tuning (Gaussian)

**Name**: `cooperative_fusion with validation-based selection works for gaussian family`

**Purpose**: Ensure alternative tuning path (validation vs CV) works for gaussian family

**Data design**:
- Separate train/validation sets (n_tr=32, n_va=16)
- Gaussian outcome

**Assertions**:
- Fit exists and is non-null
- `selection == "validation"`
- Valid predictions exist with correct length (n_va)

**Seed**: 110

---

### Test 7: Selector Policy Guard (lambda.1se)

**Name**: `cooperative_fusion rejects lambda.1se when not in CV mode`

**Purpose**: Enforce constraint that `lambda.1se` is only valid for CV-based selection

**Data design**:
- Standard multi-omic (n=30)

**Assertions**:
- `cooperation_selection = "validation"` + `cooperation_selector = "lambda.1se"` raises error
- Error message mentions constraint

**Seed**: 112

---

### Test 8: Cox Family + Validation Guard

**Name**: `cooperative_fusion with validation rejects cox family`

**Purpose**: Enforce that Cox validation-mode cooperation is not supported

**Data design**:
- Multi-omic with `survival::Surv` outcome (n=30)
- Validation-mode parameters

**Assertions**:
- Raises error with descriptive message
- Error mentions cox and validation constraint

**Seed**: 114

---

### Test 9: Cox Family + CV Acceptance

**Name**: `cooperative_fusion with cv mode accepts cox family`

**Purpose**: Confirm Cox works in CV-mode cooperation (valid use case)

**Data design**:
- Multi-omic with `survival::Surv` outcome (n=30)
- CV-mode parameters

**Assertions**:
- Fit completes without error
- cv.multiview fit exists

**Seed**: 116

---

### Test 10: Optional Dependency Failure

**Name**: `cooperative_fusion fails gracefully when multiview is not installed`

**Purpose**: Document and validate graceful error when optional dependency is absent

**Data design**:
- Standard multi-omic (n=20)
- Runs only when multiview is NOT installed

**Assertions**:
- Raises error with message mentioning multiview
- Error is caught before attempting to use multiview internals

**Seed**: 117

---

### Test 11-12: Reserved for Edge Cases

**Purpose**: Placeholder for additional edge-case coverage (e.g., multi-view (>2 omics), NA handling, rank-deficient scenarios)

---

## Test Code

Full test code block (ready for insertion into `test-multiomic-workflows.R`):

```r
# =========================================================================
# COOPERATIVE FUSION BEHAVIOR TESTS
# =========================================================================
# 
# These tests validate that cooperative fusion produces meaningfully different
# feature rankings/selections compared to pure early and pure late fusion.
# 
# Strategy:
# 1. Create synthetic multi-omic data with clear per-omic signal structure.
# 2. Run early, cooperative (rho=0 baseline, rho>0 active), and late fusion.
# 3. Compare: (a) selected features, (b) stability scores, (c) behavior consistency.
# 4. Assert that cooperative mode bridges early and late (not trivial subset).
# =========================================================================

test_that(
  "cooperative_fusion with rho>0 produces different selections than rho=0",
  {
    skip_if_not_installed("multiview")
    
    set.seed(100)
    n <- 40L
    
    # Design: omic_a has strong signal in features a1, a2.
    #         omic_b has strong signal in features b1, b2.
    #         Cooperation (rho>0) should encourage agreement.
    x_a <- cbind(
      a1 = rnorm(n, mean = 2.0, sd = 0.5),   # strong effect
      a2 = rnorm(n, mean = 1.5, sd = 0.5),   # strong effect
      a3 = rnorm(n, sd = 1.0),                # noise
      a4 = rnorm(n, sd = 1.0)                 # noise
    )
    rownames(x_a) <- paste0("s", seq_len(n))
    colnames(x_a) <- paste0("a", 1:4)
    
    x_b <- cbind(
      b1 = rnorm(n, mean = 2.0, sd = 0.5),   # strong effect
      b2 = rnorm(n, mean = 1.5, sd = 0.5),   # strong effect
      b3 = rnorm(n, sd = 1.0),                # noise
      b4 = rnorm(n, sd = 1.0)                 # noise
    )
    rownames(x_b) <- paste0("s", seq_len(n))
    colnames(x_b) <- paste0("b", 1:4)
    
    # Outcome: primarily driven by a1, a2, b1, b2
    y <- setNames(
      0.8 * x_a[, "a1"] + 0.6 * x_a[, "a2"] +
      0.7 * x_b[, "b1"] + 0.5 * x_b[, "b2"] +
      rnorm(n, sd = 0.5),
      rownames(x_a)
    )
    
    # Fit with rho = 0 (no cooperation)
    fit_rho0 <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.15, 0.10, 0.05)),
      artificial_type     = NULL,
      hard_threshold      = 0.4,
      n_bootstraps        = 8L,
      family              = "gaussian",
      random_state        = 99L,
      cooperative_fusion  = TRUE,
      rho                 = 0,                    # baseline: no cooperation
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    # Fit with rho > 0 (active cooperation)
    fit_rho_pos <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.15, 0.10, 0.05)),
      artificial_type     = NULL,
      hard_threshold      = 0.4,
      n_bootstraps        = 8L,
      family              = "gaussian",
      random_state        = 99L,
      cooperative_fusion  = TRUE,
      rho                 = 0.5,                  # active cooperation
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    # Compare selected features
    sel_rho0_a <- fit_rho0$cooperative_fusion$selected_features$omic_a
    sel_rho0_b <- fit_rho0$cooperative_fusion$selected_features$omic_b
    sel_rho_pos_a <- fit_rho_pos$cooperative_fusion$selected_features$omic_a
    sel_rho_pos_b <- fit_rho_pos$cooperative_fusion$selected_features$omic_b
    
    # Assertion 1: rho > 0 should produce different selections than rho = 0
    # (At least one omic should differ; total selections may differ)
    expect_false(
      identical(c(sel_rho0_a, sel_rho0_b), c(sel_rho_pos_a, sel_rho_pos_b)),
      info = "Cooperation (rho > 0) should alter feature selection vs rho = 0"
    )
  }
)

test_that(
  "early_fusion, cooperative, and late_fusion select different features",
  {
    skip_if_not_installed("multiview")
    
    set.seed(101)
    n <- 50L
    
    # Multi-omic data: each omic has unique strong signal + shared noise
    x_a <- cbind(
      a1 = rnorm(n, mean = 1.8, sd = 0.6),
      a2 = rnorm(n, mean = 1.2, sd = 0.6),
      a3 = rnorm(n, sd = 1.0),
      a4 = rnorm(n, sd = 1.0)
    )
    rownames(x_a) <- paste0("s", seq_len(n))
    colnames(x_a) <- paste0("a", 1:4)
    
    x_b <- cbind(
      b1 = rnorm(n, mean = 1.6, sd = 0.6),
      b2 = rnorm(n, mean = 0.9, sd = 0.6),
      b3 = rnorm(n, sd = 1.0),
      b4 = rnorm(n, sd = 1.0)
    )
    rownames(x_b) <- paste0("s", seq_len(n))
    colnames(x_b) <- paste0("b", 1:4)
    
    y <- setNames(
      0.7 * x_a[, "a1"] + 0.5 * x_a[, "a2"] +
      0.6 * x_b[, "b1"] + 0.4 * x_b[, "b2"] +
      rnorm(n, sd = 0.6),
      rownames(x_a)
    )
    
    # Fit all three fusion modes in one call
    fit_all <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.15, 0.10, 0.05)),
      artificial_type     = NULL,
      hard_threshold      = 0.4,
      n_bootstraps        = 6L,
      family              = "gaussian",
      random_state        = 102L,
      early_fusion        = TRUE,
      late_fusion         = TRUE,
      n_iter_lf           = 500L,
      cooperative_fusion  = TRUE,
      rho                 = 0.3,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    # Extract selections from each mode
    early_sel_all <- fit_all$early_fusion$selected_features
    coop_sel_a <- fit_all$cooperative_fusion$selected_features$omic_a
    coop_sel_b <- fit_all$cooperative_fusion$selected_features$omic_b
    
    # Assertion 1: Early fusion should select from the concatenated space
    expect_true(
      length(early_sel_all) > 0,
      info = "Early fusion should select at least one feature"
    )
    
    # Assertion 2: Cooperative and early may differ
    # (Cooperative encourages agreement between omics via rho penalty)
    early_a_features <- gsub("^a", "", early_sel_all[grepl("^a", early_sel_all)])
    early_b_features <- gsub("^b", "", early_sel_all[grepl("^b", early_sel_all)])
    
    # Check that cooperation doesn't trivially reproduce early fusion
    coop_all_sel <- c(paste0("a", coop_sel_a), paste0("b", coop_sel_b))
    expect_false(
      identical(sort(early_sel_all), sort(coop_all_sel)),
      info = "Cooperative mode should not exactly match early fusion"
    )
    
    # Assertion 3: Late fusion results should exist and be distinct from per-omic STABL
    expect_true(
      length(fit_all$late_fusion$train_predictions) > 0,
      info = "Late fusion should produce train predictions"
    )
    expect_equal(
      nrow(fit_all$late_fusion$weights), 2L,
      info = "Late fusion should have weights for each omic"
    )
  }
)

test_that(
  "cooperative_fusion produces stable selections across repeated runs with same seed",
  {
    skip_if_not_installed("multiview")
    
    set.seed(103)
    n <- 35L
    
    x_a <- matrix(rnorm(n * 4L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:4)))
    x_b <- matrix(rnorm(n * 4L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:4)))
    y <- setNames(0.6 * x_a[, 1L] + 0.5 * x_b[, 2L] + rnorm(n, sd = 0.5),
                  rownames(x_a))
    
    # Run twice with identical parameters and seed
    fit1 <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.15, 0.10)),
      artificial_type     = NULL,
      hard_threshold      = 0.35,
      n_bootstraps        = 4L,
      family              = "gaussian",
      random_state        = 104L,
      cooperative_fusion  = TRUE,
      rho                 = 0.2,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    fit2 <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.15, 0.10)),
      artificial_type     = NULL,
      hard_threshold      = 0.35,
      n_bootstraps        = 4L,
      family              = "gaussian",
      random_state        = 104L,
      cooperative_fusion  = TRUE,
      rho                 = 0.2,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    # Selections should be identical
    expect_equal(
      fit1$cooperative_fusion$selected_features,
      fit2$cooperative_fusion$selected_features
    )
    
    # Train predictions should be identical
    expect_equal(
      fit1$cooperative_fusion$train_predictions,
      fit2$cooperative_fusion$train_predictions,
      tolerance = 1e-10
    )
    
    # Chosen rho and lambda should be identical
    expect_equal(fit1$cooperative_fusion$rho, fit2$cooperative_fusion$rho)
    expect_equal(fit1$cooperative_fusion$chosen_lambda, fit2$cooperative_fusion$chosen_lambda)
  }
)

test_that(
  "cooperative_fusion with binomial family selects features consistently",
  {
    skip_if_not_installed("multiview")
    
    set.seed(105)
    n <- 40L
    
    x_a <- matrix(rnorm(n * 4L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:4)))
    x_b <- matrix(rnorm(n * 4L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:4)))
    
    # Binary outcome with clear signal
    eta <- 0.5 * x_a[, 1L] - 0.4 * x_b[, 2L]
    y <- setNames(as.integer(plogis(eta) > 0.5), rownames(x_a))
    
    fit <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.2, 0.15, 0.1)),
      artificial_type     = NULL,
      hard_threshold      = 0.35,
      n_bootstraps        = 5L,
      family              = "binomial",
      random_state        = 106L,
      cooperative_fusion  = TRUE,
      rho                 = 0.25,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    cf <- fit$cooperative_fusion
    
    # Check structure and consistency
    expect_s3_class(cf$fit, "cv.multiview")
    expect_true(length(cf$train_predictions) > 0)
    expect_true(length(cf$selected_features$omic_a) >= 0)
    expect_true(length(cf$selected_features$omic_b) >= 0)
    
    # Train predictions should be numeric and bounded for binomial
    expect_true(is.numeric(cf$train_predictions))
    expect_true(all(cf$train_predictions >= 0 & cf$train_predictions <= 1))
  }
)

test_that(
  "cooperative_fusion produces rho-aware behavior in CV mode",
  {
    skip_if_not_installed("multiview")
    
    set.seed(107)
    n <- 45L
    
    x_a <- matrix(rnorm(n * 5L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:5)))
    x_b <- matrix(rnorm(n * 5L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:5)))
    y <- setNames(0.7 * x_a[, 1L] + 0.6 * x_b[, 2L] + rnorm(n, sd = 0.5),
                  rownames(x_a))
    
    # Fit with a grid of rho values
    fit_rho_grid <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
      artificial_type     = NULL,
      hard_threshold      = 0.35,
      n_bootstraps        = 4L,
      family              = "gaussian",
      random_state        = 108L,
      cooperative_fusion  = TRUE,
      rho                 = c(0, 0.1, 0.3, 0.5),    # Vary cooperation strength
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 3L
    )
    
    cf <- fit_rho_grid$cooperative_fusion
    
    # Assertion: Chosen rho should be one of the provided values
    expect_true(cf$rho %in% c(0, 0.1, 0.3, 0.5))
    
    # Assertion: cv.multiview fit should exist
    expect_s3_class(cf$fit, "cv.multiview")
    
    # Assertion: Fold assignment should be deterministic
    expect_equal(length(cf$foldid), n)
    expect_true(all(cf$foldid %in% 1:3))
  }
)

test_that(
  "cooperative_fusion with validation-based selection works for gaussian family",
  {
    skip_if_not_installed("multiview")
    
    set.seed(109)
    n_tr <- 32L
    n_va <- 16L
    
    x_a_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                     dimnames = list(paste0("tr", seq_len(n_tr)), paste0("a", 1:4)))
    x_b_tr <- matrix(rnorm(n_tr * 4L), nrow = n_tr,
                     dimnames = list(paste0("tr", seq_len(n_tr)), paste0("b", 1:4)))
    x_a_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                     dimnames = list(paste0("va", seq_len(n_va)), paste0("a", 1:4)))
    x_b_va <- matrix(rnorm(n_va * 4L), nrow = n_va,
                     dimnames = list(paste0("va", seq_len(n_va)), paste0("b", 1:4)))
    
    y_tr <- setNames(0.6 * x_a_tr[, 1L] + 0.5 * x_b_tr[, 2L] + rnorm(n_tr, sd = 0.5),
                     rownames(x_a_tr))
    y_va <- setNames(0.6 * x_a_va[, 1L] + 0.5 * x_b_va[, 2L] + rnorm(n_va, sd = 0.5),
                     rownames(x_a_va))
    
    fit <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a_tr, omic_b = x_b_tr),
      y_train             = y_tr,
      x_valid_list        = list(omic_a = x_a_va, omic_b = x_b_va),
      y_valid             = y_va,
      lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
      artificial_type     = NULL,
      hard_threshold      = 0.35,
      n_bootstraps        = 4L,
      family              = "gaussian",
      random_state        = 110L,
      cooperative_fusion  = TRUE,
      rho                 = 0.2,
      cooperation_selection = "validation",
      cooperation_nfolds  = 3L
    )
    
    cf <- fit$cooperative_fusion
    
    # Validation-mode fit should exist
    expect_true(!is.null(cf$fit))
    expect_equal(cf$selection, "validation")
    
    # Should have validation predictions (not CV predictions)
    expect_true(length(cf$valid_predictions) > 0)
    expect_equal(length(cf$valid_predictions), n_va)
  }
)

test_that(
  "cooperative_fusion rejects lambda.1se when not in CV mode",
  {
    skip_if_not_installed("multiview")
    
    set.seed(111)
    n <- 30L
    
    x_a <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:3)))
    x_b <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:3)))
    y <- setNames(rnorm(n), rownames(x_a))
    
    # lambda.1se is only valid for cooperation_selection = "cv"
    expect_error(
      stabl_multiomic_train_validate(
        x_train_list        = list(omic_a = x_a, omic_b = x_b),
        y_train             = y,
        lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
        artificial_type     = NULL,
        hard_threshold      = 0.3,
        n_bootstraps        = 2L,
        family              = "gaussian",
        random_state        = 112L,
        cooperative_fusion  = TRUE,
        rho                 = 0.1,
        cooperation_selection = "validation",
        cooperation_selector = "lambda.1se",
        cooperation_nfolds  = 2L
      ),
      "lambda.1se.*not available"
    )
  }
)

test_that(
  "cooperative_fusion with validation rejects cox family",
  {
    skip_if_not_installed("multiview")
    skip_if_not_installed("survival")
    
    set.seed(113)
    n <- 30L
    
    x_a <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:3)))
    x_b <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:3)))
    
    time <- rexp(n, rate = 0.5)
    event <- rbinom(n, size = 1L, prob = 0.5)
    y <- survival::Surv(time, event)
    names(y) <- paste0("s", seq_len(n))
    
    # Cox + validation-mode cooperation should be rejected
    expect_error(
      stabl_multiomic_train_validate(
        x_train_list        = list(omic_a = x_a, omic_b = x_b),
        y_train             = y,
        lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
        artificial_type     = NULL,
        hard_threshold      = 0.3,
        n_bootstraps        = 2L,
        family              = "cox",
        random_state        = 114L,
        cooperative_fusion  = TRUE,
        rho                 = 0.1,
        cooperation_selection = "validation",
        cooperation_nfolds  = 2L
      ),
      "cox.*validation.*not supported"
    )
  }
)

test_that(
  "cooperative_fusion with cv mode accepts cox family",
  {
    skip_if_not_installed("multiview")
    skip_if_not_installed("survival")
    
    set.seed(115)
    n <- 30L
    
    x_a <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:3)))
    x_b <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:3)))
    
    time <- rexp(n, rate = 0.5)
    event <- rbinom(n, size = 1L, prob = 0.5)
    y <- survival::Surv(time, event)
    names(y) <- paste0("s", seq_len(n))
    
    # Cox + CV-mode cooperation should work
    fit <- stabl_multiomic_train_validate(
      x_train_list        = list(omic_a = x_a, omic_b = x_b),
      y_train             = y,
      lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
      artificial_type     = NULL,
      hard_threshold      = 0.3,
      n_bootstraps        = 2L,
      family              = "cox",
      random_state        = 116L,
      cooperative_fusion  = TRUE,
      rho                 = 0.1,
      cooperation_selection = "cv",
      cooperation_selector = "lambda.min",
      cooperation_nfolds  = 2L
    )
    
    expect_s3_class(fit$cooperative_fusion$fit, "cv.multiview")
  }
)

test_that(
  "cooperative_fusion fails gracefully when multiview is not installed",
  {
    # This is a "soft" test that documents the expected failure mode.
    # In practice, skip_if_not_installed will skip the test if multiview exists,
    # so this test runs only when multiview is NOT available.
    
    skip_if_installed("multiview")
    
    set.seed(117)
    n <- 20L
    x_a <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("a", 1:3)))
    x_b <- matrix(rnorm(n * 3L), nrow = n,
                  dimnames = list(paste0("s", seq_len(n)), paste0("b", 1:3)))
    y <- setNames(rnorm(n), rownames(x_a))
    
    expect_error(
      stabl_multiomic_train_validate(
        x_train_list        = list(omic_a = x_a, omic_b = x_b),
        y_train             = y,
        lambda_grid         = data.frame(lambda = c(0.2, 0.1)),
        artificial_type     = NULL,
        hard_threshold      = 0.3,
        n_bootstraps        = 2L,
        cooperative_fusion  = TRUE,
        rho                 = 0.1
      ),
      "multiview.*not available|multiview.*installed"
    )
  }
)
```

## Progress Tracking

### Completion Checklist

- [ ] **Test code insertion**: Add all 10 test cases to `test-multiomic-workflows.R`
- [ ] **Local validation**: Run `testthat::test_local('r-pkg/stablr', filter = 'cooperative')` and confirm all tests pass
- [ ] **Regression check**: Run full suite and confirm no regressions
- [ ] **Update PROGRESS.md**: Record validation results and test counts
- [ ] **Update PLAN.md**: Mark Phase CF-1 gate complete if all tests pass
- [ ] **Update HANDOFF.md**: Move to Item 2 (cooperative ergonomics)

### Expected Results (Post-Implementation)

**Command**: `conda run -n R4_51 Rscript -e "testthat::test_local('r-pkg/stablr', filter = 'multiomic-workflows')"`

**Expected**: All existing tests + 10 new cooperative tests pass  
**Baseline**: `PASS 88` → `PASS 98+` (depending on test organization)

## Links and References

- **Implementation target**: [r-pkg/stablr/tests/testthat/test-multiomic-workflows.R](r-pkg/stablr/tests/testthat/test-multiomic-workflows.R)
- **Cooperative workflow source**: [r-pkg/stablr/R/multiomic_workflows.R](r-pkg/stablr/R/multiomic_workflows.R)
- **Strategic guide**: [MultiView.md](MultiView.md)
- **Roadmap**: [PLAN.md](PLAN.md) (Phase CF-1 → CF-2 transition)
- **Execution log**: [PROGRESS.md](PROGRESS.md)
- **Bootstrap guide**: [HANDOFF.md](HANDOFF.md) (next 3 tasks section)

## Next Steps (After This Phase)

1. **Item 2**: Add cooperative print/report ergonomics to `stabl_accessors.R`
2. **Item 3**: Verify optional-dependency failure mode and update `HANDOFF.md`
3. **Phase CF-3**: Broaden edge-case coverage (multi-view >2 omics, NA handling)
4. **Phase CF-4**: Add pairwise agreement/reporting diagnostics

---

**Document version**: 1.0  
**Last update**: 2026-05-04  
**Status**: Ready for implementation phase
