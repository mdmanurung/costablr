# Plot a ROC Curve

Generates a ggplot2 ROC (Receiver Operating Characteristic) curve from
binary outcome labels and predicted probabilities, together with the
chance-level diagonal for reference.

## Usage

``` r
plot_roc(y_true, y_preds, title = "ROC Curve")
```

## Arguments

- y_true:

  Integer or logical vector of binary outcomes (1/`TRUE` for the
  positive class, 0/`FALSE` for the negative class). Must be the same
  length as `y_preds`.

- y_preds:

  Numeric vector of predicted probabilities for the positive class.
  Values must be in \\\[0, 1\]\\ for interpretable results.

- title:

  Character scalar; plot title. Default `"ROC Curve"`.

## Value

A `ggplot` object. The AUC is shown as a caption.

## Details

ROC curves visualise the trade-off between sensitivity (TPR) and
specificity (1 - FPR) across all possible classification thresholds. Use
this plot to assess overall discriminative ability after applying STABL
feature selection and fitting a downstream classifier on the selected
features. The Area Under the Curve (AUC) is shown in the caption.

## See also

[`plot_prc()`](https://gregbellan.github.io/Stabl/stablr/reference/plot_prc.md)
for precision-recall curves (preferred when classes are severely
imbalanced).
