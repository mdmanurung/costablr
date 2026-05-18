# Cooperative-fusion helpers backed by the optional multiview package.

.cooperative_family_to_multiview <- function(family) {
  switch(
    family,
    gaussian = stats::gaussian(),
    binomial = stats::binomial(),
    poisson = stats::poisson(),
    cox = "cox",
    stop(
      "`cooperative_fusion = TRUE` only supports family = 'gaussian', 'binomial', 'poisson', or 'cox'.",
      call. = FALSE
    )
  )
}

.cooperative_prediction_type <- function(family, type_measure) {
  if (identical(type_measure, "class")) {
    return("class")
  }

  if (identical(family, "binomial") && identical(type_measure, "deviance")) {
    return("response")
  }

  "link"
}

.cooperative_metric_direction <- function(type_measure) {
  if (type_measure %in% c("auc", "C")) "max" else "min"
}

.select_cooperative_metric_index <- function(metric_values, direction) {
  if (all(is.na(metric_values))) {
    stop("Cooperative tuning failed: all candidate metric values were NA.",
         call. = FALSE)
  }

  if (identical(direction, "max")) {
    which.max(replace(metric_values, is.na(metric_values), -Inf))
  } else {
    which.min(replace(metric_values, is.na(metric_values), Inf))
  }
}

.cooperative_coerce_binary_outcome <- function(y) {
  if (is.factor(y)) {
    return(as.integer(y) - 1L)
  }

  y_num <- as.numeric(y)
  if (all(sort(unique(y_num)) %in% c(0, 1))) {
    return(as.integer(y_num))
  }

  as.integer(as.factor(y)) - 1L
}

.cooperative_binomial_deviance <- function(pred, y) {
  prob_min <- 1e-05
  prob_max <- 1 - prob_min
  nc <- dim(y)

  if (is.null(nc)) {
    y <- as.factor(y)
    ntab <- table(y)
    nc <- as.integer(length(ntab))
    y <- diag(nc)[as.numeric(y), , drop = FALSE]
  }

  pred <- pmin(pmax(as.numeric(pred), prob_min), prob_max)
  lp <- y[, 1] * log(1 - pred) + y[, 2] * log(pred)
  ly <- log(y)
  ly[y == 0] <- 0
  ly <- drop((y * ly) %*% c(1, 1))
  mean(2 * (ly - lp))
}

.cooperative_poisson_deviance <- function(eta, y) {
  y <- as.numeric(y)
  deveta <- y * eta - exp(eta)
  devy <- y * log(y) - y
  devy[y == 0] <- 0
  mean(2 * (devy - deveta))
}

.cooperative_validation_metric <- function(true_y,
                                           pred_y,
                                           family,
                                           type_measure) {
  switch(
    type_measure,
    mse = mean((as.numeric(true_y) - as.numeric(pred_y))^2),
    class = mean(as.character(true_y) != as.character(pred_y)),
    auc = .r_auc(.cooperative_coerce_binary_outcome(true_y), as.numeric(pred_y)),
    mae = mean(abs(as.numeric(true_y) - as.numeric(pred_y))),
    deviance = switch(
      family,
      gaussian = mean((as.numeric(true_y) - as.numeric(pred_y))^2),
      binomial = .cooperative_binomial_deviance(pred_y, true_y),
      poisson = .cooperative_poisson_deviance(pred_y, true_y),
      stop(
        sprintf(
          "Validation-based cooperative tuning does not support family '%s'.",
          family
        ),
        call. = FALSE
      )
    ),
    stop(sprintf("Unsupported cooperative type measure '%s'.", type_measure),
         call. = FALSE)
  )
}

.cooperative_predict <- function(fit,
                                 newx,
                                 s,
                                 family,
                                 type_measure) {
  prediction_type <- .cooperative_prediction_type(
    family = family,
    type_measure = type_measure
  )

  if (identical(prediction_type, "link")) {
    stats::predict(fit, newx = newx, s = s)
  } else {
    stats::predict(fit, newx = newx, s = s, type = prediction_type)
  }
}

.cooperative_prediction_matrix <- function(pred, n_rows) {
  if (length(dim(pred)) > 2L) {
    pred <- pred[, 1L, , drop = TRUE]
  }

  out <- as.matrix(pred)
  if (nrow(out) != n_rows) {
    out <- matrix(out, nrow = n_rows)
  }
  out
}

.cooperative_prediction_vector <- function(pred, sample_ids) {
  out <- as.vector(pred)
  names(out) <- sample_ids
  out
}

.cooperative_coefficient_table <- function(fit, s) {
  fit_core <- if (inherits(fit, "cv.multiview")) fit$multiview.fit else fit
  coef_mat <- as.matrix(stats::coef(fit, s = s))
  coef_vec <- as.numeric(coef_mat)

  col_names <- unlist(fit_core$colnames_list)
  view <- rep(names(fit_core$p_x), unlist(fit_core$p_x))

  if (length(coef_vec) == length(col_names) + 1L) {
    coef_vec <- coef_vec[-1L]
  }

  if (length(coef_vec) != length(col_names)) {
    stop(
      "Cooperative coefficient extraction failed: coefficient length did not match the multiview feature layout.",
      call. = FALSE
    )
  }

  data.frame(
    view = view,
    view_col = col_names,
    coef = coef_vec,
    stringsAsFactors = FALSE
  )
}

.cooperative_selected_features <- function(coef_table, omic_names) {
  out <- setNames(vector("list", length(omic_names)), omic_names)

  for (omic in omic_names) {
    out[[omic]] <- character(0)
  }

  if (is.null(coef_table) || nrow(coef_table) == 0L) {
    return(out)
  }

  for (omic in omic_names) {
    keep <- coef_table$view == omic & coef_table$coef != 0
    out[[omic]] <- unique(as.character(coef_table$view_col[keep]))
  }

  out
}

.augment_multiomic_fold_diagnostics <- function(diagnostics, fold_fit) {
  cooperative <- fold_fit$cooperative_fusion
  if (is.null(cooperative)) {
    return(diagnostics)
  }

  diagnostics$cooperative_rho <- cooperative$rho
  diagnostics$cooperative_lambda <- cooperative$selected_lambda
  diagnostics$cooperative_selection <- cooperative$selection
  diagnostics$cooperative_selector <- cooperative$selector
  diagnostics$cooperative_type_measure <- cooperative$type_measure
  diagnostics$cooperative_score <- cooperative$score
  diagnostics$cooperative_prediction_type <- cooperative$prediction_type
  diagnostics$cooperative_n_selected <- vapply(
    diagnostics$omic,
    function(omic) length(cooperative$selected_features[[omic]]),
    integer(1L)
  )

  diagnostics
}

.cooperative_multiomic_fit <- function(x_train_list,
                                       y_train,
                                       x_valid_list = NULL,
                                       y_valid = NULL,
                                       groups_train = NULL,
                                       family = "gaussian",
                                       random_state = NULL,
                                       cooperative_args,
                                       foldid = NULL) {
  if (identical(family, "multinomial")) {
    return(.cooperative_multiomic_fit_ovr(
      x_train_list = x_train_list,
      y_train = y_train,
      x_valid_list = x_valid_list,
      y_valid = y_valid,
      groups_train = groups_train,
      random_state = random_state,
      cooperative_args = cooperative_args
    ))
  }

  omic_names <- names(x_train_list)
  x_train_mv <- .coerce_multiomic_matrix_list(x_train_list)
  x_valid_mv <- if (is.null(x_valid_list)) NULL else .coerce_multiomic_matrix_list(x_valid_list)
  mv_family <- .cooperative_family_to_multiview(family)
  direction <- .cooperative_metric_direction(cooperative_args$cooperation_type_measure)

  if (identical(cooperative_args$cooperative_selection, "cv")) {
    if (is.null(foldid)) {
      foldid <- .make_multiomic_foldid(
        sample_ids = rownames(x_train_mv[[1L]]),
        groups = groups_train,
        v = cooperative_args$cooperation_nfolds,
        random_state = random_state
      )
    } else if (length(foldid) != nrow(x_train_mv[[1L]])) {
      stop("Shared cooperative `foldid` must have one value per training sample.",
           call. = FALSE)
    }

    cv_fits <- lapply(cooperative_args$rho, function(rho_value) {
      multiview::cv.multiview(
        x_list = x_train_mv,
        y = y_train,
        family = mv_family,
        rho = rho_value,
        type.measure = cooperative_args$cooperation_type_measure,
        foldid = foldid
      )
    })

    diagnostics <- do.call(rbind, lapply(seq_along(cv_fits), function(i) {
      fit <- cv_fits[[i]]
      selector <- cooperative_args$cooperation_selector
      lambda_value <- unname(fit[[selector]])
      lambda_index <- match(lambda_value, fit$lambda)
      data.frame(
        rho = cooperative_args$rho[[i]],
        lambda = lambda_value,
        metric_value = fit$cvm[[lambda_index]],
        selected = FALSE,
        stringsAsFactors = FALSE
      )
    }))

    best_index <- .select_cooperative_metric_index(diagnostics$metric_value,
                                                   direction)
    diagnostics$selected[[best_index]] <- TRUE

    best_fit <- cv_fits[[best_index]]
    best_rho <- diagnostics$rho[[best_index]]
    best_lambda <- diagnostics$lambda[[best_index]]
    best_score <- diagnostics$metric_value[[best_index]]
    selector <- cooperative_args$cooperation_selector

    train_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_train_mv,
      s = selector,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    valid_pred <- if (is.null(x_valid_mv)) {
      NULL
    } else {
      .cooperative_predict(
        fit = best_fit,
        newx = x_valid_mv,
        s = selector,
        family = family,
        type_measure = cooperative_args$cooperation_type_measure
      )
    }
    coef_table <- .cooperative_coefficient_table(best_fit, s = selector)
  } else {
    foldid <- NULL
    mv_fits <- lapply(cooperative_args$rho, function(rho_value) {
      multiview::multiview(
        x_list = x_train_mv,
        y = y_train,
        family = mv_family,
        rho = rho_value
      )
    })

    diagnostics_list <- vector("list", length(mv_fits))
    candidate_metric <- numeric(length(mv_fits))
    candidate_lambda <- numeric(length(mv_fits))

    for (i in seq_along(mv_fits)) {
      fit <- mv_fits[[i]]
      pred_path <- .cooperative_predict(
        fit = fit,
        newx = x_valid_mv,
        s = fit$lambda,
        family = family,
        type_measure = cooperative_args$cooperation_type_measure
      )
      pred_path <- .cooperative_prediction_matrix(pred_path, length(y_valid))

      metric_path <- vapply(seq_along(fit$lambda), function(lambda_index) {
        .cooperative_validation_metric(
          true_y = y_valid,
          pred_y = pred_path[, lambda_index],
          family = family,
          type_measure = cooperative_args$cooperation_type_measure
        )
      }, numeric(1L))

      selected_index <- .select_cooperative_metric_index(metric_path, direction)
      candidate_metric[[i]] <- metric_path[[selected_index]]
      candidate_lambda[[i]] <- fit$lambda[[selected_index]]
      diagnostics_list[[i]] <- data.frame(
        rho = cooperative_args$rho[[i]],
        lambda = fit$lambda,
        metric_value = metric_path,
        selected = FALSE,
        stringsAsFactors = FALSE
      )
    }

    best_index <- .select_cooperative_metric_index(candidate_metric, direction)
    best_fit <- mv_fits[[best_index]]
    best_rho <- cooperative_args$rho[[best_index]]
    best_lambda <- candidate_lambda[[best_index]]
    best_score <- candidate_metric[[best_index]]
    selector <- "lambda.min"

    diagnostics <- do.call(rbind, diagnostics_list)
    selected_row <- which(diagnostics$rho == best_rho & diagnostics$lambda == best_lambda)[1L]
    diagnostics$selected[[selected_row]] <- TRUE

    train_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_train_mv,
      s = best_lambda,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    valid_pred <- .cooperative_predict(
      fit = best_fit,
      newx = x_valid_mv,
      s = best_lambda,
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    )
    coef_table <- .cooperative_coefficient_table(best_fit, s = best_lambda)
  }

  selected_features <- .cooperative_selected_features(coef_table, omic_names)
  selected_train <- setNames(vector("list", length(omic_names)), omic_names)
  selected_valid <- if (is.null(x_valid_list)) NULL else setNames(vector("list", length(omic_names)), omic_names)

  for (omic in omic_names) {
    selected_train[[omic]] <- .subset_selected_matrix(x_train_list[[omic]], selected_features[[omic]])
    if (!is.null(selected_valid)) {
      selected_valid[[omic]] <- .subset_selected_matrix(x_valid_list[[omic]], selected_features[[omic]])
    }
  }

  list(
    fit = best_fit,
    rho = best_rho,
    rho_grid = cooperative_args$rho,
    selection = cooperative_args$cooperative_selection,
    selector = selector,
    type_measure = cooperative_args$cooperation_type_measure,
    prediction_type = .cooperative_prediction_type(
      family = family,
      type_measure = cooperative_args$cooperation_type_measure
    ),
    score = best_score,
    selected_lambda = best_lambda,
    selected_features = selected_features,
    selected_train = selected_train,
    selected_valid = selected_valid,
    train_predictions = .cooperative_prediction_vector(
      train_pred,
      rownames(x_train_mv[[1L]])
    ),
    valid_predictions = if (is.null(valid_pred)) NULL else {
      .cooperative_prediction_vector(valid_pred, rownames(x_valid_mv[[1L]]))
    },
    diagnostics = diagnostics,
    foldid = foldid
  )
}

.cooperative_multiomic_fit_ovr <- function(x_train_list,
                                           y_train,
                                           x_valid_list = NULL,
                                           y_valid = NULL,
                                           groups_train = NULL,
                                           random_state = NULL,
                                           cooperative_args) {
  omic_names <- names(x_train_list)
  x_train_mv <- .coerce_multiomic_matrix_list(x_train_list)
  x_valid_mv <- if (is.null(x_valid_list)) NULL else .coerce_multiomic_matrix_list(x_valid_list)

  y_train_factor <- droplevels(factor(y_train))
  names(y_train_factor) <- names(y_train)
  class_levels <- levels(y_train_factor)
  if (length(class_levels) < 3L) {
    stop(
      "One-vs-rest cooperative fusion for `family = 'multinomial'` requires at least three training classes; use `family = 'binomial'` for two-class cooperative fusion.",
      call. = FALSE
    )
  }

  y_valid_factor <- NULL
  if (!is.null(y_valid)) {
    y_valid_factor <- factor(y_valid, levels = class_levels)
    names(y_valid_factor) <- names(y_valid)
    if (anyNA(y_valid_factor)) {
      stop(
        "Validation labels for one-vs-rest cooperative fusion must all be present in the training classes.",
        call. = FALSE
      )
    }
  }

  shared_foldid <- NULL
  if (identical(cooperative_args$cooperative_selection, "cv")) {
    shared_foldid <- .make_multiomic_foldid(
      sample_ids = rownames(x_train_mv[[1L]]),
      groups = groups_train,
      v = cooperative_args$cooperation_nfolds,
      random_state = random_state,
      strata = if (is.null(groups_train)) y_train_factor else NULL
    )
  }

  class_args <- cooperative_args
  class_args$task_type <- "binomial"

  class_results <- setNames(vector("list", length(class_levels)), class_levels)
  for (class_level in class_levels) {
    y_binary <- setNames(
      as.integer(y_train_factor == class_level),
      names(y_train_factor)
    )
    y_valid_binary <- if (is.null(y_valid_factor)) {
      NULL
    } else {
      setNames(as.integer(y_valid_factor == class_level), names(y_valid_factor))
    }

    class_results[[class_level]] <- .cooperative_multiomic_fit(
      x_train_list = x_train_list,
      y_train = y_binary,
      x_valid_list = x_valid_list,
      y_valid = y_valid_binary,
      groups_train = groups_train,
      family = "binomial",
      random_state = random_state,
      cooperative_args = class_args,
      foldid = shared_foldid
    )
  }

  selected_features_by_class <- lapply(class_results, function(result) {
    result$selected_features
  })
  selected_features <- .cooperative_union_selected_features(
    selected_features_by_class = selected_features_by_class,
    omic_names = omic_names
  )

  selected_train <- setNames(vector("list", length(omic_names)), omic_names)
  selected_valid <- if (is.null(x_valid_list)) NULL else setNames(vector("list", length(omic_names)), omic_names)
  for (omic in omic_names) {
    selected_train[[omic]] <- .subset_selected_matrix(x_train_list[[omic]], selected_features[[omic]])
    if (!is.null(selected_valid)) {
      selected_valid[[omic]] <- .subset_selected_matrix(x_valid_list[[omic]], selected_features[[omic]])
    }
  }

  train_prob <- .cooperative_ovr_probability_matrix(
    class_results = class_results,
    newx = x_train_mv,
    sample_ids = rownames(x_train_mv[[1L]]),
    class_levels = class_levels
  )
  train_predictions <- .cooperative_ovr_prediction_frame(train_prob)
  log_loss <- .multiclass_log_loss(y_train_factor, train_prob)

  valid_prob <- NULL
  valid_predictions <- NULL
  valid_log_loss <- NULL
  valid_metrics <- NULL
  if (!is.null(x_valid_mv)) {
    valid_prob <- .cooperative_ovr_probability_matrix(
      class_results = class_results,
      newx = x_valid_mv,
      sample_ids = rownames(x_valid_mv[[1L]]),
      class_levels = class_levels
    )
    valid_predictions <- .cooperative_ovr_prediction_frame(valid_prob)
    if (!is.null(y_valid_factor)) {
      valid_log_loss <- .multiclass_log_loss(y_valid_factor, valid_prob)
      valid_metrics <- .classification_metrics(
        truth = factor(y_valid_factor, levels = class_levels),
        predicted = factor(valid_predictions$predicted_class,
                           levels = class_levels)
      )
    }
  }

  diagnostics <- do.call(rbind, lapply(class_levels, function(class_level) {
    data.frame(
      class = class_level,
      class_results[[class_level]]$diagnostics,
      stringsAsFactors = FALSE
    )
  }))
  rownames(diagnostics) <- NULL

  class_summary <- do.call(rbind, lapply(class_levels, function(class_level) {
    result <- class_results[[class_level]]
    data.frame(
      class = class_level,
      rho = result$rho,
      selected_lambda = result$selected_lambda,
      score = result$score,
      n_selected = sum(vapply(result$selected_features, length, integer(1L))),
      stringsAsFactors = FALSE
    )
  }))
  rownames(class_summary) <- NULL

  fitted_models <- lapply(class_results, function(result) result$fit)

  out <- list(
    fit = fitted_models,
    task_type = "multiclass_ovr",
    levels = class_levels,
    class_results = class_results,
    class_summary = class_summary,
    selected_features_by_class = selected_features_by_class,
    rho = NA_real_,
    rho_grid = cooperative_args$rho,
    selection = cooperative_args$cooperative_selection,
    selector = cooperative_args$cooperation_selector,
    type_measure = cooperative_args$cooperation_type_measure,
    prediction_type = "response",
    score = -log_loss,
    log_loss = log_loss,
    selected_lambda = NA_real_,
    selected_features = selected_features,
    selected_train = selected_train,
    selected_valid = selected_valid,
    train_predictions = train_predictions,
    valid_predictions = valid_predictions,
    train_metrics = .classification_metrics(
      truth = factor(y_train_factor, levels = class_levels),
      predicted = factor(train_predictions$predicted_class,
                         levels = class_levels)
    ),
    diagnostics = diagnostics,
    foldid = shared_foldid
  )

  if (!is.null(valid_log_loss)) {
    out$valid_log_loss <- valid_log_loss
  }
  if (!is.null(valid_metrics)) {
    out$valid_metrics <- valid_metrics
  }

  out
}

.cooperative_union_selected_features <- function(selected_features_by_class,
                                                 omic_names) {
  out <- setNames(vector("list", length(omic_names)), omic_names)
  for (omic in omic_names) {
    out[[omic]] <- unique(unlist(
      lapply(selected_features_by_class, function(class_features) {
        class_features[[omic]]
      }),
      use.names = FALSE
    ))
    if (is.null(out[[omic]])) {
      out[[omic]] <- character(0)
    }
  }
  out
}

.cooperative_binomial_response_predict <- function(fit,
                                                   newx,
                                                   s,
                                                   sample_ids) {
  pred <- stats::predict(fit, newx = newx, s = s, type = "response")
  pred_mat <- .cooperative_prediction_matrix(pred, length(sample_ids))
  out <- as.numeric(pred_mat[, 1L])
  names(out) <- sample_ids
  out
}

.cooperative_ovr_probability_matrix <- function(class_results,
                                                newx,
                                                sample_ids,
                                                class_levels,
                                                eps = 1e-15) {
  prob <- matrix(
    NA_real_,
    nrow = length(sample_ids),
    ncol = length(class_levels),
    dimnames = list(sample_ids, class_levels)
  )

  for (class_level in class_levels) {
    result <- class_results[[class_level]]
    s <- if (identical(result$selection, "cv")) {
      result$selector
    } else {
      result$selected_lambda
    }
    prob[, class_level] <- .cooperative_binomial_response_predict(
      fit = result$fit,
      newx = newx,
      s = s,
      sample_ids = sample_ids
    )
  }

  prob[!is.finite(prob)] <- eps
  prob <- pmin(pmax(prob, eps), 1 - eps)

  row_totals <- rowSums(prob)
  bad_rows <- !is.finite(row_totals) | row_totals <= 0
  if (any(bad_rows)) {
    prob[bad_rows, ] <- 1 / ncol(prob)
    row_totals <- rowSums(prob)
  }

  prob / row_totals
}

.cooperative_ovr_prediction_frame <- function(prob) {
  out <- as.data.frame(prob, check.names = FALSE)
  names(out) <- paste0("prob_", names(out))
  class_levels <- colnames(prob)
  out$predicted_class <- class_levels[max.col(prob, ties.method = "first")]
  out
}
