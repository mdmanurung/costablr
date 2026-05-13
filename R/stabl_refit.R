#' Fit STABL and Refit an Unpenalized Final Model
#'
#' Runs [stabl_fit()] to select stable features, then refits an ordinary
#' unpenalized predictive model on the selected columns.  This mirrors the
#' Python tutorial pattern where `Stabl` is used as the feature-selection step
#' in a pipeline and a task-appropriate final model is fitted after selection.
#'
#' The final refit is determined by `family`:
#' \describe{
#'   \item{`"gaussian"`}{linear regression via [stats::lm()].}
#'   \item{`"binomial"`}{logistic regression via [stats::glm()] with a logit
#'     link.}
#'   \item{`"multinomial"`}{multinomial logistic regression via
#'     [nnet::multinom()] with no weight decay.}
#'   \item{`"poisson"`}{Poisson regression via [stats::glm()] with a log link.}
#'   \item{`"cox"`}{Cox proportional-hazards regression via
#'     [survival::coxph()].}
#' }
#'
#' If STABL selects no features, the final model is still fitted as an
#' intercept-only model.  This keeps the end-to-end workflow well-defined while
#' preserving the selected-feature set as an empty character vector.
#'
#' @param x A numeric matrix or `data.frame` (samples \eqn{\times} features)
#'   with row names used as sample IDs.
#' @param y A named numeric/factor vector whose names are sample IDs, or a
#'   matrix-like outcome (for example `survival::Surv`) with row names as
#'   sample IDs.
#' @param lambda_grid Passed to [stabl_fit()].
#' @param family Character; one of `"gaussian"`, `"binomial"`,
#'   `"multinomial"`, `"poisson"`, or `"cox"`.  Passed to [stabl_fit()] and
#'   used to choose the final refit model.
#' @param new_hard_threshold Numeric in `(0, 1]` or `NULL`.  When supplied,
#'   overrides the threshold stored in the STABL selector for extracting
#'   selected features before refitting.
#' @param ... Additional arguments forwarded to [stabl_fit()].
#' @param final_model_args Optional named list of extra arguments forwarded to
#'   the final model fitter (`lm`, `glm`, `nnet::multinom`, or
#'   `survival::coxph`).
#'
#' @return An S3 object of class `"stabl_refit"` containing the lower-level
#'   `stabl_fit` object, selected feature names, selected training matrix,
#'   unpenalized final model, and in-sample final-model predictions.
#'
#' @examples
#' set.seed(11)
#' n <- 40L
#' p <- 8L
#' x <- matrix(
#'   rnorm(n * p),
#'   nrow = n,
#'   dimnames = list(paste0("s", seq_len(n)), paste0("f", seq_len(p)))
#' )
#' y <- setNames(1.5 * x[, 1] - x[, 2] + rnorm(n, sd = 0.5), rownames(x))
#'
#' fit <- stabl_refit(
#'   x = x,
#'   y = y,
#'   lambda_grid = data.frame(lambda = c(0.05, 0.02)),
#'   family = "gaussian",
#'   n_bootstraps = 3L,
#'   artificial_type = NULL,
#'   hard_threshold = 1e-9,
#'   sample_fraction = 1,
#'   random_state = 1L
#' )
#' predict(fit, x)
#' @export
stabl_refit <- function(
    x,
    y,
    lambda_grid,
    family = "gaussian",
    new_hard_threshold = NULL,
    ...,
    final_model_args = list()
) {
  if (is.data.frame(x)) x <- as.matrix(x)
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`x` must be a numeric matrix or data.frame.", call. = FALSE)
  }
  if (!is.list(final_model_args) ||
      (length(final_model_args) > 0L &&
       (is.null(names(final_model_args)) ||
        any(is.na(names(final_model_args)) | names(final_model_args) == "")))) {
    stop("`final_model_args` must be a named list.", call. = FALSE)
  }

  task_type <- .stabl_refit_task_type(family)
  validate_sample_alignment(x, y, groups = NULL)
  y_aligned <- .subset_outcome_by_ids(y, rownames(x))

  selector <- stabl_fit(
    x = x,
    y = y_aligned,
    lambda_grid = lambda_grid,
    family = family,
    ...
  )
  selected_features <- get_feature_names_out(
    selector,
    new_hard_threshold = new_hard_threshold
  )
  selected_train <- .stabl_subset_selected_matrix(x, selected_features)

  final_refit <- .fit_stabl_final_model(
    x_train_sel = selected_train,
    y_train = y_aligned,
    task_type = task_type,
    final_model_args = final_model_args
  )

  structure(
    list(
      stabl_fit = selector,
      final_model = final_refit$model,
      final_model_type = final_refit$model_type,
      family = family,
      task_type = task_type,
      selected_features = selected_features,
      selected_train = selected_train,
      training_predictions = final_refit$training_predictions,
      outcome_levels = final_refit$levels,
      new_hard_threshold = new_hard_threshold,
      call = match.call()
    ),
    class = "stabl_refit"
  )
}

#' @export
predict.stabl_refit <- function(object,
                                newdata = NULL,
                                type = "response",
                                ...) {
  if (!inherits(object, "stabl_refit")) {
    stop("`object` must be a `stabl_refit` object.", call. = FALSE)
  }

  x_selected <- if (is.null(newdata)) {
    object$selected_train
  } else {
    .stabl_subset_refit_newdata(newdata, object$selected_features)
  }

  final_refit <- list(
    model = object$final_model,
    model_type = object$final_model_type,
    task_type = object$task_type,
    levels = object$outcome_levels
  )
  .predict_stabl_final_model(final_refit, x_selected, type = type, ...)
}

#' @export
print.stabl_refit <- function(x, ...) {
  cat("<stabl_refit>\n")
  cat("  Family:           ", x$family, "\n", sep = "")
  cat("  Final model:      ", x$final_model_type, "\n", sep = "")
  cat("  Features selected:", length(x$selected_features), "\n")
  if (length(x$selected_features) > 0L) {
    cat("  Selected:         ",
        paste(utils::head(x$selected_features, 6L), collapse = ", "),
        if (length(x$selected_features) > 6L) ", ..." else "",
        "\n", sep = "")
  }
  invisible(x)
}

.stabl_refit_task_type <- function(family) {
  switch(
    family,
    gaussian = "regression",
    binomial = "binary",
    multinomial = "multiclass",
    poisson = "poisson",
    cox = "cox",
    stop(
      "`stabl_refit()` supports family = 'gaussian', 'binomial', 'multinomial', 'poisson', or 'cox'.",
      call. = FALSE
    )
  )
}

.fit_stabl_final_model <- function(x_train_sel,
                                   y_train,
                                   task_type,
                                   levels = NULL,
                                   final_model_args = list()) {
  if (!is.list(final_model_args) ||
      (length(final_model_args) > 0L &&
       (is.null(names(final_model_args)) ||
        any(is.na(names(final_model_args)) | names(final_model_args) == "")))) {
    stop("`final_model_args` must be a named list.", call. = FALSE)
  }

  task_type <- match.arg(
    task_type,
    c("binary", "regression", "multiclass", "poisson", "cox")
  )
  train_df <- .stabl_predictor_frame(x_train_sel)
  outcome_col <- .stabl_outcome_column(names(train_df))
  formula <- stats::as.formula(
    paste(outcome_col, "~", if (ncol(train_df) == 0L) "1" else ".")
  )

  if (identical(task_type, "regression")) {
    if (!is.numeric(y_train)) {
      stop("Gaussian final refit requires a numeric outcome.", call. = FALSE)
    }
    train_df[[outcome_col]] <- unname(as.numeric(y_train))
    model <- do.call(
      stats::lm,
      c(list(formula = formula, data = train_df), final_model_args)
    )
    predictions <- unname(stats::predict(model, newdata = train_df))
    return(list(
      model = model,
      model_type = "lm",
      task_type = task_type,
      levels = NULL,
      training_predictions = predictions
    ))
  }

  if (identical(task_type, "binary")) {
    y_factor <- droplevels(factor(y_train))
    if (length(levels(y_factor)) != 2L) {
      stop("Binomial final refit requires exactly two outcome classes.",
           call. = FALSE)
    }
    train_df[[outcome_col]] <- y_factor
    model <- do.call(
      stats::glm,
      c(
        list(
          formula = formula,
          family = stats::binomial(link = "logit"),
          data = train_df
        ),
        final_model_args
      )
    )
    predictions <- unname(stats::predict(
      model,
      newdata = train_df,
      type = "response"
    ))
    return(list(
      model = model,
      model_type = "glm_binomial",
      task_type = task_type,
      levels = levels(y_factor),
      training_predictions = predictions
    ))
  }

  if (identical(task_type, "poisson")) {
    if (!is.numeric(y_train)) {
      stop("Poisson final refit requires a numeric count outcome.",
           call. = FALSE)
    }
    train_df[[outcome_col]] <- unname(as.numeric(y_train))
    model <- do.call(
      stats::glm,
      c(
        list(
          formula = formula,
          family = stats::poisson(link = "log"),
          data = train_df
        ),
        final_model_args
      )
    )
    predictions <- unname(stats::predict(
      model,
      newdata = train_df,
      type = "response"
    ))
    return(list(
      model = model,
      model_type = "glm_poisson",
      task_type = task_type,
      levels = NULL,
      training_predictions = predictions
    ))
  }

  if (identical(task_type, "cox")) {
    if (!requireNamespace("survival", quietly = TRUE)) {
      stop(
        "Package 'survival' is required for Cox final refit. ",
        "Install it with: install.packages(\"survival\")",
        call. = FALSE
      )
    }
    if (!inherits(y_train, "Surv")) {
      stop("Cox final refit requires a `survival::Surv` outcome.",
           call. = FALSE)
    }
    train_df[[outcome_col]] <- y_train
    model <- do.call(
      survival::coxph,
      c(list(formula = formula, data = train_df), final_model_args)
    )
    predictions <- unname(stats::predict(
      model,
      newdata = train_df,
      type = "lp"
    ))
    return(list(
      model = model,
      model_type = "coxph",
      task_type = task_type,
      levels = NULL,
      training_predictions = predictions
    ))
  }

  if (!requireNamespace("nnet", quietly = TRUE)) {
    stop(
      "Package 'nnet' is required for multinomial final refit. ",
      "Install it with: install.packages(\"nnet\")",
      call. = FALSE
    )
  }
  y_factor <- factor(y_train, levels = levels %||% levels(factor(y_train)))
  if (anyNA(y_factor)) {
    stop("Multinomial final refit received labels outside `levels`.",
         call. = FALSE)
  }
  if (length(levels(y_factor)) < 2L) {
    stop("Multinomial final refit requires at least two outcome classes.",
         call. = FALSE)
  }
  train_df[[outcome_col]] <- y_factor
  multinom_args <- c(list(formula = formula, data = train_df), final_model_args)
  if (!"trace" %in% names(multinom_args)) {
    multinom_args$trace <- FALSE
  }
  model <- do.call(nnet::multinom, multinom_args)
  predictions <- .stabl_multinom_prob_matrix(
    stats::predict(model, newdata = train_df, type = "probs"),
    levels = levels(y_factor),
    row_names = rownames(train_df)
  )
  list(
    model = model,
    model_type = "multinom",
    task_type = task_type,
    levels = levels(y_factor),
    training_predictions = predictions
  )
}

.predict_stabl_final_model <- function(final_refit,
                                       x_selected,
                                       type = "response",
                                       ...) {
  task_type <- final_refit$task_type
  new_df <- .stabl_predictor_frame(x_selected)

  if (identical(task_type, "regression")) {
    type <- match.arg(type, c("response", "link"))
    return(unname(stats::predict(final_refit$model, newdata = new_df, ...)))
  }

  if (identical(task_type, "binary")) {
    type <- match.arg(type, c("response", "link", "class"))
    if (identical(type, "class")) {
      probs <- unname(stats::predict(
        final_refit$model,
        newdata = new_df,
        type = "response",
        ...
      ))
      return(factor(
        ifelse(probs >= 0.5, final_refit$levels[[2L]], final_refit$levels[[1L]]),
        levels = final_refit$levels
      ))
    }
    return(unname(stats::predict(
      final_refit$model,
      newdata = new_df,
      type = type,
      ...
    )))
  }

  if (identical(task_type, "poisson")) {
    type <- match.arg(type, c("response", "link"))
    return(unname(stats::predict(
      final_refit$model,
      newdata = new_df,
      type = type,
      ...
    )))
  }

  if (identical(task_type, "cox")) {
    type <- match.arg(type, c("response", "link", "risk", "expected", "terms"))
    predict_type <- if (identical(type, "response")) "risk" else type
    return(unname(stats::predict(
      final_refit$model,
      newdata = new_df,
      type = predict_type,
      ...
    )))
  }

  type <- match.arg(type, c("response", "class"))
  if (identical(type, "class")) {
    return(stats::predict(final_refit$model, newdata = new_df, type = "class", ...))
  }
  .stabl_multinom_prob_matrix(
    stats::predict(final_refit$model, newdata = new_df, type = "probs", ...),
    levels = final_refit$levels,
    row_names = rownames(new_df)
  )
}

.stabl_subset_selected_matrix <- function(x, selected_features) {
  if (length(selected_features) == 0L) {
    return(matrix(
      numeric(0L),
      nrow = nrow(x),
      ncol = 0L,
      dimnames = list(rownames(x), character(0L))
    ))
  }
  x[, selected_features, drop = FALSE]
}

.stabl_subset_refit_newdata <- function(newdata, selected_features) {
  if (is.data.frame(newdata)) newdata <- as.matrix(newdata)
  if (!is.matrix(newdata) || !is.numeric(newdata)) {
    stop("`newdata` must be a numeric matrix or data.frame.", call. = FALSE)
  }
  if (length(selected_features) == 0L) {
    return(matrix(
      numeric(0L),
      nrow = nrow(newdata),
      ncol = 0L,
      dimnames = list(rownames(newdata), character(0L))
    ))
  }
  if (is.null(colnames(newdata))) {
    stop("`newdata` must have column names for STABL-selected features.",
         call. = FALSE)
  }
  missing_features <- setdiff(selected_features, colnames(newdata))
  if (length(missing_features) > 0L) {
    stop(
      "`newdata` is missing selected feature columns: ",
      paste(missing_features, collapse = ", "),
      call. = FALSE
    )
  }
  newdata[, selected_features, drop = FALSE]
}

.stabl_predictor_frame <- function(x_selected) {
  if (ncol(x_selected) == 0L) {
    row_ids <- rownames(x_selected)
    if (is.null(row_ids)) {
      row_ids <- as.character(seq_len(nrow(x_selected)))
    }
    return(structure(
      list(),
      names = character(0L),
      row.names = row_ids,
      class = "data.frame"
    ))
  }
  out <- as.data.frame(x_selected, optional = TRUE)
  row_ids <- rownames(x_selected)
  if (!is.null(row_ids)) {
    rownames(out) <- row_ids
  }
  out
}

.stabl_outcome_column <- function(existing_names) {
  candidate <- ".stabl_y"
  while (candidate %in% existing_names) {
    candidate <- paste0(candidate, "_")
  }
  candidate
}

.stabl_multinom_prob_matrix <- function(pred, levels, row_names) {
  if (is.null(dim(pred))) {
    if (length(levels) != 2L) {
      stop("Unexpected multinomial probability vector for more than two classes.",
           call. = FALSE)
    }
    pred <- cbind(1 - as.numeric(pred), as.numeric(pred))
    colnames(pred) <- levels
  } else {
    pred <- as.matrix(pred)
    pred <- pred[, levels, drop = FALSE]
  }
  rownames(pred) <- row_names
  pred
}
