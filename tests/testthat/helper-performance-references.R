.old_r_auc <- function(y, scores) {
  pos <- which(y == 1L)
  n1 <- length(pos)
  n0 <- length(y) - n1
  if (n1 == 0L || n0 == 0L) return(0.5)
  r <- rank(scores, ties.method = "average")
  (sum(r[pos]) - n1 * (n1 + 1L) / 2L) / (n1 * n0)
}

.old_r_squared <- function(y, y_hat) {
  ss_tot <- sum((y - mean(y))^2)
  if (ss_tot == 0) return(0)
  1 - sum((y - y_hat)^2) / ss_tot
}

.old_stacked_multi_omic <- function(predictions, y,
                                    task_type = c("binary", "regression", "multiclass"),
                                    n_iter = 10000L,
                                    random_state = NULL) {
  task_type <- match.arg(task_type)
  if (identical(task_type, "multiclass")) {
    return(.old_stacked_multi_omic_multiclass(
      predictions = predictions,
      y = y,
      n_iter = n_iter,
      random_state = random_state
    ))
  }

  predictions <- as.matrix(predictions)
  n_omics <- ncol(predictions)
  n_samples <- nrow(predictions)

  if (n_omics == 0L) {
    stop("`predictions` must have at least one column.", call. = FALSE)
  }
  if (length(y) != n_samples) {
    stop("`y` must have one value per prediction row.", call. = FALSE)
  }

  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  best_score <- -Inf
  best_weights <- rep(1 / n_omics, n_omics)
  best_probs <- rep(NA_real_, n_samples)

  for (i in seq_len(as.integer(n_iter))) {
    weights <- stats::runif(n_omics, 0, 10)
    w_mat <- matrix(weights, nrow = n_samples, ncol = n_omics, byrow = TRUE)
    is_obs <- !is.na(predictions)
    denom <- rowSums(is_obs * w_mat)
    num <- rowSums(ifelse(is_obs, predictions * w_mat, 0))
    weighted_probs <- ifelse(denom > 0, num / denom, NA_real_)

    complete_idx <- !is.na(weighted_probs) & !is.na(y)
    if (sum(complete_idx) < 2L) next

    score <- tryCatch(
      if (task_type == "binary") {
        .old_r_auc(y[complete_idx], weighted_probs[complete_idx])
      } else {
        .old_r_squared(y[complete_idx], weighted_probs[complete_idx])
      },
      error = function(e) NA_real_
    )

    if (!is.na(score) && score > best_score) {
      best_score <- score
      best_weights <- weights
      best_probs <- weighted_probs
    }
  }

  weights_df <- data.frame(Associated_weight = best_weights,
                           row.names = colnames(predictions))
  preds_df <- as.data.frame(predictions)
  preds_df[["Stacked Gen. Predictions"]] <- best_probs

  list(predictions = preds_df, weights = weights_df, score = best_score)
}

.old_stacked_multi_omic_multiclass <- function(predictions, y,
                                               n_iter = 10000L,
                                               random_state = NULL) {
  arr <- costablr:::.as_multiclass_prediction_array(predictions)
  n_samples <- dim(arr)[[1L]]
  n_classes <- dim(arr)[[2L]]
  n_omics <- dim(arr)[[3L]]
  classes <- dimnames(arr)[[2L]]
  omic_names <- dimnames(arr)[[3L]]

  if (length(y) != n_samples) {
    stop("`y` must have one value per prediction row.", call. = FALSE)
  }
  y <- factor(y, levels = classes)
  if (anyNA(y)) {
    stop(
      "All multiclass `y` labels must be present in prediction probability columns.",
      call. = FALSE
    )
  }

  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) {
      old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    }
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  best_score <- -Inf
  best_loss <- Inf
  best_weights <- rep(1 / n_omics, n_omics)
  best_probs <- matrix(NA_real_, nrow = n_samples, ncol = n_classes,
                       dimnames = list(dimnames(arr)[[1L]], classes))

  for (i in seq_len(as.integer(n_iter))) {
    weights <- stats::runif(n_omics, 0, 10)
    probs <- .old_weighted_multiclass_probabilities(arr, weights)
    loss <- .old_multiclass_log_loss(y, probs)
    score <- -loss
    if (is.finite(score) && score > best_score) {
      best_score <- score
      best_loss <- loss
      best_weights <- weights
      best_probs <- probs
    }
  }

  weights_df <- data.frame(Associated_weight = best_weights,
                           row.names = omic_names)
  preds_df <- as.data.frame(best_probs, check.names = FALSE)
  names(preds_df) <- paste0("prob_", names(preds_df))
  preds_df$predicted_class <- classes[max.col(best_probs, ties.method = "first")]

  list(
    predictions = preds_df,
    weights = weights_df,
    score = best_score,
    log_loss = best_loss,
    levels = classes
  )
}

.old_weighted_multiclass_probabilities <- function(pred_array, weights) {
  n_samples <- dim(pred_array)[[1L]]
  n_classes <- dim(pred_array)[[2L]]
  n_omics <- dim(pred_array)[[3L]]
  out <- matrix(NA_real_, nrow = n_samples, ncol = n_classes,
                dimnames = dimnames(pred_array)[1:2])

  for (i in seq_len(n_samples)) {
    row_probs <- pred_array[i, , , drop = FALSE]
    row_probs <- matrix(row_probs, nrow = n_classes, ncol = n_omics)
    observed <- apply(row_probs, 2L, function(x) all(is.finite(x)))
    if (!any(observed)) next
    w <- weights[observed]
    p <- row_probs[, observed, drop = FALSE] %*% w / sum(w)
    p <- as.numeric(p)
    p[p < 0] <- 0
    if (sum(p) <= 0 || !is.finite(sum(p))) next
    out[i, ] <- p / sum(p)
  }
  out
}

.old_multiclass_log_loss <- function(y, probs, eps = 1e-15) {
  y <- factor(y, levels = colnames(probs))
  idx <- !is.na(y) & apply(probs, 1L, function(x) all(is.finite(x)))
  if (sum(idx) == 0L) return(Inf)
  probs <- pmin(pmax(probs[idx, , drop = FALSE], eps), 1 - eps)
  probs <- probs / rowSums(probs)
  truth_idx <- cbind(seq_len(sum(idx)), as.integer(y[idx]))
  -mean(log(probs[truth_idx]))
}

.old_feature_abs_coefs_batch <- function(fit, lambda_seq, family = "gaussian") {
  col_list <- lapply(lambda_seq, function(s) {
    costablr:::.feature_abs_coefs(fit = fit, s = s, family = family)
  })
  do.call(cbind, col_list)
}

.old_feature_abs_coefs_sparsegl_batch <- function(fit, lambda_seq) {
  col_list <- lapply(lambda_seq, function(s) {
    costablr:::.feature_abs_coefs_sparsegl(fit = fit, s = s)
  })
  do.call(cbind, col_list)
}

.old_group_bootstrap_indices <- function(y, groups, n_subsamples,
                                         replace = FALSE,
                                         stratify = FALSE,
                                         strata = NULL,
                                         seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  if (length(groups) != length(y)) {
    stop("`groups` must be the same length as `y`.", call. = FALSE)
  }

  n <- length(y)
  if (!replace && n_subsamples > n) {
    stop("`n_subsamples` cannot exceed sample size when replace = FALSE.", call. = FALSE)
  }
  if (!is.logical(stratify) || length(stratify) != 1L || is.na(stratify)) {
    stop("`stratify` must be TRUE or FALSE.", call. = FALSE)
  }
  strata_ids <- costablr:::.bootstrap_strata_ids(
    strata = if (isTRUE(stratify) && is.null(strata)) y else strata,
    n = n,
    arg = "strata"
  )

  group_levels <- unique(groups)
  draw_once <- if (!is.null(strata_ids)) {
    function() .old_stratified_group_bootstrap_indices(
      strata_ids = strata_ids,
      groups = groups,
      group_levels = group_levels,
      n_subsamples = n_subsamples,
      replace = replace
    )
  } else {
    function() .old_unstratified_group_bootstrap_indices(
      groups = groups,
      group_levels = group_levels,
      n_subsamples = n_subsamples,
      replace = replace
    )
  }

  sampled_idx <- draw_once()
  if (length(unique(y)) >= 2L) {
    max_retries <- 1000L
    attempt <- 0L
    while (length(unique(y[sampled_idx])) < 2L) {
      attempt <- attempt + 1L
      if (attempt > max_retries) {
        stop(
          "group_bootstrap_indices: could not draw a class-diverse subsample ",
          "after ", max_retries, " attempts. ",
          "Check class balance or group structure.",
          call. = FALSE
        )
      }
      sampled_idx <- draw_once()
    }
  }

  sampled_idx
}

.old_unstratified_group_bootstrap_indices <- function(groups, group_levels,
                                                      n_subsamples, replace) {
  remaining <- group_levels
  sampled_idx <- integer(0)

  while (length(sampled_idx) < n_subsamples && length(remaining) > 0L) {
    pick_pos <- sample.int(length(remaining), size = 1L)
    g <- remaining[[pick_pos]]
    remaining <- if (replace) remaining else remaining[-pick_pos]
    sampled_idx <- if (replace) {
      c(sampled_idx, which(groups == g))
    } else {
      unique(c(sampled_idx, which(groups == g)))
    }
  }

  sampled_idx
}

.old_stratified_group_bootstrap_indices <- function(strata_ids, groups, group_levels,
                                                    n_subsamples, replace) {
  group_strata <- vapply(group_levels, function(g) {
    stratum <- unique(as.character(strata_ids[groups == g]))
    if (length(stratum) != 1L) {
      stop(
        "Grouped stratified bootstrap requires each group to map to exactly ",
        "one realised stratum.",
        call. = FALSE
      )
    }
    stratum
  }, character(1L))

  target_counts <- costablr:::.stratified_counts(strata_ids, n_subsamples, replace)
  sampled_idx <- integer(0)

  for (stratum in names(target_counts)) {
    remaining <- group_levels[group_strata == stratum]
    stratum_idx <- integer(0)

    while (length(stratum_idx) < target_counts[[stratum]] && length(remaining) > 0L) {
      pick_pos <- sample.int(length(remaining), size = 1L)
      g <- remaining[[pick_pos]]
      remaining <- if (replace) remaining else remaining[-pick_pos]
      stratum_idx <- if (replace) {
        c(stratum_idx, which(groups == g))
      } else {
        unique(c(stratum_idx, which(groups == g)))
      }
    }

    if (length(stratum_idx) < target_counts[[stratum]]) {
      stop(
        "Could not satisfy grouped stratified bootstrap target for stratum `",
        stratum, "`.",
        call. = FALSE
      )
    }
    sampled_idx <- if (replace) {
      c(sampled_idx, stratum_idx)
    } else {
      unique(c(sampled_idx, stratum_idx))
    }
  }

  sample(sampled_idx, length(sampled_idx), replace = FALSE)
}

.old_build_corr_groups <- function(x, percentile) {
  if (!is.numeric(percentile) || length(percentile) != 1L ||
      percentile <= 0 || percentile > 100) {
    stop("`corr_group_threshold` must be a numeric scalar in (0, 100].", call. = FALSE)
  }

  p <- ncol(x)
  if (p <= 1L) {
    return(rep.int(1L, p))
  }

  corr <- suppressWarnings(stats::cor(x, use = "pairwise.complete.obs"))
  corr[is.na(corr)] <- 0
  corr_vals <- corr[upper.tri(corr, diag = FALSE)]
  cutoff <- as.numeric(stats::quantile(corr_vals, probs = percentile / 100,
                                       names = FALSE, na.rm = TRUE)) - 0.1

  .old_corr_groups_from_corr(corr, cutoff)
}

.old_corr_groups_from_corr <- function(corr, cutoff) {
  p <- ncol(corr)
  parent <- seq_len(p)
  find_root <- function(i) {
    while (parent[[i]] != i) {
      parent[[i]] <<- parent[[parent[[i]]]]
      i <- parent[[i]]
    }
    i
  }
  union_nodes <- function(i, j) {
    ri <- find_root(i)
    rj <- find_root(j)
    if (ri != rj) parent[[rj]] <<- ri
  }

  for (i in seq_len(p - 1L)) {
    for (j in (i + 1L):p) {
      if (corr[[i, j]] > cutoff) union_nodes(i, j)
    }
  }

  roots <- vapply(seq_len(p), find_root, integer(1L))
  as.integer(as.factor(roots))
}

.old_append_noise_groups <- function(groups, noise_col_indices, total_p) {
  if (is.null(noise_col_indices)) {
    return(groups)
  }

  out <- as.integer(groups)
  next_gid <- max(out)
  for (src in noise_col_indices) {
    src <- as.integer(src)
    if (!is.na(src) && src >= 1L && src <= length(groups)) {
      out <- c(out, groups[[src]])
    } else {
      next_gid <- next_gid + 1L
      out <- c(out, next_gid)
    }
  }

  if (length(out) != total_p) {
    stop("Sparse-group feature-group construction failed due to length mismatch.", call. = FALSE)
  }

  out
}

.same_partition <- function(a, b) {
  outer(a, a, "==") == outer(b, b, "==")
}
