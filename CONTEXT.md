# costablr Domain Context

This context captures the domain language for STABL-based biomarker discovery in costablr.

## Language

**STABL Selector**:
A biomarker-selection analysis that uses subsampling, artificial features, and FDP+ minimization to return selected biomarkers.
_Avoid_: model, predictor, final model

**Final Refit**:
A downstream predictive model trained after biomarker selection using only the selected biomarkers.
_Avoid_: selector, STABL model

**SuperLearner Final Refit**:
A Final Refit that ensembles candidate predictive algorithms after STABL selection using only selected biomarkers.
_Avoid_: Base SRM, STABL Selector, SuperLearner selector

**Candidate Biomarker**:
A measured variable considered for selection as a biomarker.
_Avoid_: feature, predictor, column

**Selected Biomarker**:
A candidate biomarker retained by the STABL Selector.
_Avoid_: feature, support feature, selected column

**Consensus Biomarker Set**:
Selected biomarkers retained because they recur across multiple STABL Selector runs under a predefined agreement rule.
_Avoid_: SuperLearner output, prediction ensemble, final model features

**Base-SRM Consensus**:
A Consensus Biomarker Set derived from STABL Selector runs that differ by Base SRM.
_Avoid_: repeated-seed consensus, cross-validation consensus

**Majority Consensus Rule**:
An agreement rule that retains a biomarker when it is selected by at least half of the compared STABL Selector runs, rounded up.
_Avoid_: union rule, strict intersection rule

**Artificial Feature**:
A synthetic negative-control variable generated to behave like an uninformative biomarker candidate.
_Avoid_: artificial biomarker, noise biomarker, fake biomarker

**Reliability Threshold**:
The data-driven stability-score cutoff chosen by minimizing FDP+ over candidate thresholds.
_Avoid_: FDR threshold, hard threshold, cutoff

**Base SRM**:
The sparsity-promoting regularized method fitted inside the STABL Selector during each subsampling iteration.
_Avoid_: final model, learner, refit model

**Per-View Predictor**:
A predictive model trained using one Omic View to produce prediction outputs for fusion.
_Avoid_: Final Refit when no STABL Selector was used

**Omic View**:
One assay-specific biomarker table measured on the shared sample set in a multi-omic analysis.
_Also acceptable_: modality
_Avoid_: layer, block, omic table

**Multi-Omic Fusion**:
An analysis strategy that combines multiple omic views.
_Avoid_: multi-omic workflow, view workflow

**Multi-Omic STABL**:
Multi-omic integration that runs a STABL Selector separately for each Omic View, concatenates the selected biomarkers, and trains one Final Refit on the combined selected biomarker set.
_Also acceptable_: StablSRM multi-omic integration
_Avoid_: late fusion, early fusion

**Early Fusion**:
Multi-omic fusion that combines omic views before STABL selection.
_Avoid_: concatenation, stacked input

**Late Fusion**:
Multi-omic fusion that combines prediction outputs from independently trained Per-View Predictors. Canonical Late Fusion does not require STABL selection and does not concatenate selected biomarkers.
_Avoid_: validation-set fusion, simple averaging

**STABL-Selected Late Fusion**:
A hybrid comparator that runs a STABL Selector and Final Refit separately within each Omic View, then combines the per-view prediction outputs.
_Avoid_: canonical Late Fusion when comparing against the paper taxonomy

**Cooperative STABL**:
A downstream fusion strategy that first obtains Selected Biomarkers separately within each Omic View, then jointly fits view-specific predictors on those selected biomarkers with an agreement penalty.
_Avoid_: STABL-Selected Late Fusion, Multi-Omic STABL, raw Cooperative Fusion

**Cooperative Fusion**:
Multi-omic comparator strategy that jointly models omic views with an agreement penalty encouraging view-specific predictions to align.
_Avoid_: multiview model, cooperative learning branch

## Relationships

- A **STABL Selector** produces zero or more selected biomarkers.
- `stabl_fit()` is the canonical public API for a single-view **STABL Selector**.
- `stabl_per_omic()` is the canonical public API for fitting independent **STABL Selectors** across multiple **Omic Views**.
- `stabl_multiomics()` is the canonical public API name for paper-level **Multi-Omic STABL**.
- `stabl_late_fusion()` is the canonical public API name for **STABL-Selected Late Fusion**.
- `stabl_cooperative()` is the canonical public API name for **Cooperative STABL**.
- A **STABL Selector** does not own multi-omic fusion behavior.
- `stabl_per_omic()` may include independent per-omic **Final Refits** for downstream prediction, but those refits are not multi-omic fusion.
- Downstream STABL fusion functions consume a `stabl_per_omic()` result rather than rerunning per-omic selection from raw inputs.
- A `stabl_per_omic()` result is reusable for fixed train/validation analysis, but it must be created inside each training fold for cross-validation performance estimation.
- Public modeling functions should each represent one clear method or evaluation target; avoid functions whose behavior is primarily controlled by many fusion flags.
- Public STABL method names use `multiomic` rather than `multiview`; use **Omic View** in prose and reserve `multiview` for the external package or general machine-learning literature.
- A **Final Refit** is trained after exactly one **STABL Selector** result.
- A **SuperLearner Final Refit** is a type of **Final Refit**, not a **Base SRM**.
- A **Consensus Biomarker Set** is derived from two or more **STABL Selector** runs.
- A **Base-SRM Consensus** compares STABL Selector runs over the same candidate biomarkers while varying the Base SRM.
- The default agreement rule for **Base-SRM Consensus** is the **Majority Consensus Rule**.
- A **STABL Selector** fits a **Base SRM** repeatedly across subsamples and regularization settings.
- A **Per-View Predictor** may be trained with or without a preceding **STABL Selector**.
- A **Selected Biomarker** is always a **Candidate Biomarker**.
- An **Artificial Feature** is not a **Candidate Biomarker**.
- A **Candidate Biomarker** becomes a **Selected Biomarker** when its score is greater than or equal to the **Reliability Threshold**, matching the StablSRM paper-method implementation.
- **Artificial Features** are used to estimate FDP+, and FDP+ determines the **Reliability Threshold**.
- A multi-omic analysis contains one or more **Omic Views**.
- **Early Fusion**, **Late Fusion**, **Multi-Omic STABL**, and **Cooperative Fusion** are forms of **Multi-Omic Fusion**.
- **Multi-Omic STABL** combines selected biomarkers, while **Late Fusion** combines prediction outputs.
- **STABL-Selected Late Fusion** combines prediction outputs after per-view STABL selection; it is a useful hybrid comparator, not canonical **Late Fusion**.
- **STABL-Selected Late Fusion** remains a strict late-fusion strategy: per-view predictors are fitted independently before their prediction outputs are combined.
- **Cooperative STABL** reuses the selected-biomarker boundary from per-view STABL, but its final predictive stage is a joint agreement-penalized fit rather than prediction stacking.
- **Cooperative STABL** differs from **Multi-Omic STABL** because it preserves view-specific predictive components and explicitly penalizes disagreement between them.
- **Cooperative Fusion** is outside the formal **Early Fusion** / **Late Fusion** / **Multi-Omic STABL** taxonomy used for StablSRM method parity; treat it as a separate comparator branch.
- **Cooperative Fusion** differs from **Late Fusion** because it couples view-specific predictors during fitting through an agreement penalty rather than combining already-fitted prediction outputs only after training.

## Example dialogue

> **Dev:** "If the **STABL Selector** returns no selected biomarkers, do we skip the **Final Refit**?"
> **Domain expert:** "No, the **Final Refit** still represents the downstream predictive stage."

## Flagged ambiguities

- "model" can mean either **STABL Selector** or **Final Refit**; resolved: use the precise term for the stage being discussed.
- "STABL base model" can mean either the **Base SRM** inside one selector or separate **STABL Selector** runs using different Base SRMs; resolved: say **Base SRM** for the inner sparse method and "STABL Selector run" for a full selection analysis.
- "feature" is the implementation/data-column term; resolved: use **Candidate Biomarker** or **Selected Biomarker** in domain language.
- "modality" is an acceptable synonym for **Omic View**, but **Omic View** is preferred in repository documentation.
- "SuperLearner" can mean an ensemble method generally or a STABL-stage learner; resolved: use **SuperLearner Final Refit** for the downstream predictive stage after STABL selection.
- "robust biomarkers" can mean prediction-important variables or recurrent STABL selections; resolved: use **Consensus Biomarker Set** for recurrent selections across STABL Selector runs.
- Selection follows the paper-method greater-than-or-equal rule: **Selected Biomarkers** require scores greater than or equal to the **Reliability Threshold**. This intentionally differs from upstream Python STABL in tie cases.
- "late fusion" can refer either to canonical prediction-level fusion or the current STABL-selected hybrid; resolved: use **Late Fusion** for the canonical baseline and **STABL-Selected Late Fusion** for the hybrid.
