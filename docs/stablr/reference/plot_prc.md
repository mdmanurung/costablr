# Plot a Precision-Recall Curve

Generates a ggplot2 Precision-Recall Curve (PRC) from binary outcome
labels and predicted probabilities, optionally with iso-F1 contour
lines.

## Usage

``` r
plot_prc(y_true, y_preds, show_iso = TRUE, title = "Precision-Recall Curve")
```

## Arguments

- y_true:

  Integer or logical vector of binary outcomes (1/`TRUE` for the
  positive class). Must be the same length as `y_preds`.

- y_preds:

  Numeric vector of predicted probabilities for the positive class.

- show_iso:

  Logical; if `TRUE` (default), four iso-F1 contour lines at F1 = 0.2,
  0.4, 0.6, 0.8 are drawn as reference guides.

- title:

  Character scalar; plot title. Default `"Precision-Recall Curve"`.

## Value

A `ggplot` object. The AUPRC is shown as a caption.

## Details

Precision-recall curves are preferred over ROC curves when the positive
class is rare (class imbalance), because they focus on the model's
performance on positive predictions without being diluted by the large
number of true negatives. Use this plot after applying STABL feature
selection and fitting a downstream binary classifier. The Area Under the
PRC (AUPRC) is shown in the caption.

## See also

[`plot_roc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_roc.md)
for the ROC curve alternative.
