# costablr Domain Context

This context captures the domain language for STABL-based biomarker discovery in costablr.

## Language

**STABL Selector**:
A biomarker-selection analysis that uses subsampling, artificial features, and FDP+ minimization to return selected biomarkers.
_Avoid_: model, predictor, final model

**Final Refit**:
A downstream predictive model trained after biomarker selection using only the selected biomarkers.
_Avoid_: selector, STABL model

**Candidate Biomarker**:
A measured variable considered for selection as a biomarker.
_Avoid_: feature, predictor, column

**Selected Biomarker**:
A candidate biomarker retained by the STABL Selector.
_Avoid_: feature, support feature, selected column

**Artificial Feature**:
A synthetic negative-control variable generated to behave like an uninformative biomarker candidate.
_Avoid_: artificial biomarker, noise biomarker, fake biomarker

**Reliability Threshold**:
The data-driven stability-score cutoff chosen by minimizing FDP+ over candidate thresholds.
_Avoid_: FDR threshold, hard threshold, cutoff

**Base SRM**:
The sparsity-promoting regularized method fitted inside the STABL Selector during each subsampling iteration.
_Avoid_: final model, learner, refit model

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
Multi-omic fusion that combines independently trained per-view Final Refit predictions using learned non-negative view weights.
_Avoid_: validation-set fusion, simple averaging

**Cooperative Fusion**:
Multi-omic comparator strategy that jointly models omic views while allowing view-specific contributions.
_Avoid_: multiview model, cooperative learning branch

## Relationships

- A **STABL Selector** produces zero or more selected biomarkers.
- A **Final Refit** is trained after exactly one **STABL Selector** result.
- A **STABL Selector** fits a **Base SRM** repeatedly across subsamples and regularization settings.
- A **Selected Biomarker** is always a **Candidate Biomarker**.
- An **Artificial Feature** is not a **Candidate Biomarker**.
- A **Candidate Biomarker** becomes a **Selected Biomarker** when its score is greater than or equal to the **Reliability Threshold**, matching the StablSRM paper notation.
- **Artificial Features** are used to estimate FDP+, and FDP+ determines the **Reliability Threshold**.
- A multi-omic analysis contains one or more **Omic Views**.
- **Early Fusion**, **Late Fusion**, **Multi-Omic STABL**, and **Cooperative Fusion** are forms of **Multi-Omic Fusion**.
- **Multi-Omic STABL** combines selected biomarkers, while **Late Fusion** combines prediction outputs.
- **Cooperative Fusion** is outside the formal **Early Fusion** / **Late Fusion** / **Multi-Omic STABL** taxonomy used for StablSRM method parity; treat it as a separate comparator branch.

## Example dialogue

> **Dev:** "If the **STABL Selector** returns no selected biomarkers, do we skip the **Final Refit**?"
> **Domain expert:** "No, the **Final Refit** still represents the downstream predictive stage."

## Flagged ambiguities

- "model" can mean either **STABL Selector** or **Final Refit**; resolved: use the precise term for the stage being discussed.
- "feature" is the implementation/data-column term; resolved: use **Candidate Biomarker** or **Selected Biomarker** in domain language.
- "modality" is an acceptable synonym for **Omic View**, but **Omic View** is preferred in repository documentation.
- Selection follows the paper's greater-than-or-equal notation: **Selected Biomarkers** require scores greater than or equal to the **Reliability Threshold**. This intentionally differs from upstream Python STABL in tie cases.
