\name{stabl_multiomic_nested_cv}
\alias{stabl_multiomic_nested_cv}
\title{Multi-Omic STABL Nested Cross-Validation}
\usage{
stabl_multiomic_nested_cv(
  x_list,
  y,
  candidates = NULL,
  lambda_grid = "auto",
  outer_v = 5L,
  outer_repeats = 1L,
  inner_v = 5L,
  stratified = TRUE,
  strata = NULL,
  strata_bins = 5L,
  metric = c("ber", "accuracy"),
  family = "multinomial",
  n_bootstraps = 100L,
  artificial_type = "random_permutation",
  hard_threshold = NULL,
  random_state = NULL,
  n_lambda = 30L,
  l1_ratio = NULL,
  workers = 1L,
  cv_workers = 1L,
  ...
)
}
\arguments{
\item{x_list}{Named list of omic matrices or data frames with identical sample row names.}

\item{y}{Named factor or character vector aligned to \code{x_list} rows.}

\item{candidates}{Optional list of candidate definitions. Each candidate is a list with \code{name} and \code{blocks}; \code{blocks} names one or more omics from \code{x_list}. When \code{NULL}, one candidate is created for each omic plus one early-fusion candidate using all omics.}

\item{lambda_grid}{Either \code{"auto"}, a single lambda-grid data frame, or a named list of lambda grids. Named entries can match omic names or candidate names.}

\item{outer_v}{Number of outer folds per repeat.}

\item{outer_repeats}{Number of repeated outer CV rounds.}

\item{inner_v}{Number of inner folds used for candidate selection.}

\item{stratified}{Logical. When \code{TRUE} (default), outer and inner folds preserve class proportions as closely as possible.}

\item{strata}{Optional named vector used to stratify folds instead of \code{y}. Categorical values are used directly. Numeric values are binned into quantile groups before fold assignment.}

\item{strata_bins}{Number of quantile bins for numeric \code{strata}.}

\item{metric}{Candidate-selection metric, \code{"ber"} or \code{"accuracy"}.}

\item{family}{Passed to \code{\link[=stabl_fit]{stabl_fit()}}. Defaults to \code{"multinomial"}.}

\item{n_bootstraps}{Passed to \code{\link[=stabl_fit]{stabl_fit()}}.}

\item{artificial_type}{Passed to \code{\link[=stabl_fit]{stabl_fit()}}.}

\item{hard_threshold}{Passed to \code{\link[=stabl_fit]{stabl_fit()}}.}

\item{random_state}{Optional integer seed.}

\item{n_lambda}{Passed to \code{\link[=stabl_fit]{stabl_fit()}} when \code{lambda_grid = "auto"}.}

\item{l1_ratio}{Passed to \code{\link[=stabl_fit]{stabl_fit()}} when \code{lambda_grid = "auto"}. Use this with \code{base_learner = "elastic_net"} to generate alpha-aware auto grids.}

\item{workers}{Passed to \code{\link[=stabl_fit]{stabl_fit()}} for bootstrap-level parallelism.}

\item{cv_workers}{Number of outer folds to evaluate in parallel. Uses \code{parallel::mclapply()} on Unix-like systems and falls back to sequential execution on Windows.}

\item{...}{Additional arguments passed to \code{\link[=stabl_fit]{stabl_fit()}}.}
}
\note{
Cooperative fusion (\code{cooperative_fusion = TRUE}) is not supported in nested CV.
Use \code{\link[=stabl_multiomic_train_validate]{stabl_multiomic_train_validate()}} or
\code{\link[=stabl_multiomic_cv]{stabl_multiomic_cv()}} for cooperative workflows.
}
\value{
An object of class \code{"stabl_multiomic_nested_cv"} containing fold definitions, inner candidate diagnostics, outer held-out predictions, selected features, and aggregate performance.
}
\description{
Runs a repeated outer cross-validation loop for generalisation assessment. Within each outer training split, candidate STABL workflows are compared using an inner cross-validation loop. The selected candidate is then refit on the full outer-training split and evaluated once on the held-out outer fold.
}
\seealso{
\code{\link[=stabl_fit]{stabl_fit()}}, \code{\link[=stabl_multiomic_cv]{stabl_multiomic_cv()}}
}
