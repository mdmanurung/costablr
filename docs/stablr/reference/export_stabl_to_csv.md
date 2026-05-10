# Export STABL Stability Scores to CSV

Writes the full stability-score matrix, the per-feature maximum
stability scores, and (when artificial features were used) the
corresponding artificial-feature scores to CSV files in the directory
specified by `path`.

## Usage

``` r
export_stabl_to_csv(object, path)
```

## Arguments

- object:

  A fitted `"stabl_fit"` object from
  [`stabl_fit()`](https://gregbellan.github.io/Stabl/stablr/reference/stabl_fit.md).

- path:

  Character string; path to an existing (or to-be-created) directory.

## Value

Invisibly returns `path` (as a normalized string).

## Details

Files written:

- `STABL scores.csv` — full p x L stability score matrix.

- `Max STABL scores.csv` — per-feature maximum stability score, sorted
  descending.

- `STABL artificial scores.csv` — artificial feature scores (only when
  `object$artificial_type` is not `NULL`).

- `Max STABL artificial scores.csv` — artificial max scores, sorted
  descending (only when artificial features were used).
