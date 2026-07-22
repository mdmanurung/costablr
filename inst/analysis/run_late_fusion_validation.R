#!/usr/bin/env Rscript

# Paired, independent-test validation of OOF versus historical late fusion.
`%||%` <- function(x, y) if (is.null(x)) y else x
.root <- normalizePath(getwd(), mustWork = TRUE)
if (!requireNamespace("pkgload", quietly = TRUE)) stop("pkgload is required.")
pkgload::load_all(.root, quiet = TRUE)

.args <- function(x) {
  out <- list(); i <- 1L
  while (i <= length(x)) {
    key <- sub("^--", "", x[[i]])
    if (i == length(x)) stop("Missing value for --", key)
    out[[key]] <- x[[i + 1L]]; i <- i + 2L
  }
  out
}

.simulate <- function(family, regime, seed, n_train = 90L, n_test = 120L,
                      p = 12L) {
  set.seed(seed)
  n <- n_train + n_test
  ids <- paste0("s", seq_len(n))
  z <- matrix(rnorm(n * p), n, p)
  x1 <- z + matrix(rnorm(n * p, sd = 0.15), n, p)
  x2 <- matrix(rnorm(n * p), n, p)
  colnames(x1) <- paste0("a", seq_len(p)); colnames(x2) <- paste0("b", seq_len(p))
  rownames(x1) <- rownames(x2) <- ids
  eta <- if (regime == "signal") 1.2 * x1[, 1] - x1[, 2] + 0.8 * x2[, 1] else rep(0, n)
  y <- switch(
    family,
    gaussian = eta + rnorm(n),
    binomial = rbinom(n, 1L, plogis(eta)),
    multinomial = {
      latent <- cbind(A = eta, B = -eta, C = 0.3 * x2[, 2]) +
        matrix(rnorm(n * 3L, sd = 0.7), n, 3L)
      factor(c("A", "B", "C")[max.col(latent)], levels = c("A", "B", "C"))
    }
  )
  names(y) <- ids
  tr <- seq_len(n_train); te <- seq.int(n_train + 1L, n)
  list(
    train_x = list(a = x1[tr, , drop = FALSE], b = x2[tr, , drop = FALSE]),
    test_x = list(a = x1[te, , drop = FALSE], b = x2[te, , drop = FALSE]),
    train_y = y[tr], test_y = y[te]
  )
}

.metric <- function(family, truth, pred) {
  if (family == "gaussian") return(stablr:::.r_squared(as.numeric(truth), as.numeric(pred)))
  if (family == "binomial") return(stablr:::.r_auc(as.integer(truth), as.numeric(pred)))
  mean(as.character(truth) == as.character(pred$predicted_class))
}

.train_metric <- function(family, truth, fit) {
  if (family != "multinomial") return(fit$late_fusion$score)
  mean(as.character(truth) ==
         as.character(fit$late_fusion$train_predictions$predicted_class))
}

.fallback_rate <- function(fit) {
  reasons <- unlist(lapply(fit$late_fusion$provenance$folds, `[[`, "fallback_reasons"),
                    use.names = FALSE)
  if (!length(reasons)) return(NA_real_)
  mean(!is.na(reasons) & nzchar(reasons))
}

.capture_fit <- function(args) {
  warnings <- character()
  fit <- tryCatch(
    withCallingHandlers(
      do.call(stabl_multiomic_train_validate, args),
      warning = function(w) {
        warnings <<- c(warnings, conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  list(fit = fit, warnings = unique(warnings))
}

run_late_fusion_validation <- function(out, replicates = 50L, n_bootstraps = 20L,
                                       n_iter = 500L, seed = 220711L) {
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  design <- expand.grid(
    family = c("gaussian", "binomial", "multinomial"),
    regime = c("null", "signal"), replicate = seq_len(replicates),
    stringsAsFactors = FALSE
  )
  rows <- vector("list", nrow(design))
  warning_rows <- list()
  for (i in seq_len(nrow(design))) {
    d <- design[i, ]; fit_seed <- seed + i * 101L
    dat <- .simulate(d$family, d$regime, fit_seed)
    common <- list(
      x_train_list = dat$train_x, y_train = dat$train_y,
      lambda_grid = data.frame(lambda = c(0.2, 0.1, 0.05)),
      x_valid_list = dat$test_x, y_valid = dat$test_y,
      family = d$family, artificial_type = NULL, hard_threshold = 0.25,
      n_bootstraps = n_bootstraps, sample_fraction = 0.7,
      late_fusion = TRUE, late_fusion_nfolds = 5L,
      n_iter_lf = n_iter, random_state = fit_seed
    )
    legacy_result <- .capture_fit(c(common, list(late_fusion_training = "python_legacy")))
    oof_result <- .capture_fit(c(common, list(late_fusion_training = "oof")))
    for (mode in c("python_legacy", "oof")) {
      messages <- if (mode == "oof") oof_result$warnings else legacy_result$warnings
      if (length(messages)) warning_rows[[length(warning_rows) + 1L]] <- data.frame(
        family = d$family, regime = d$regime, replicate = d$replicate,
        seed = fit_seed, mode = mode, warning = messages,
        stringsAsFactors = FALSE
      )
    }
    if (inherits(legacy_result$fit, "error") || inherits(oof_result$fit, "error")) {
      rows[[i]] <- data.frame(
        family = d$family, regime = d$regime, replicate = d$replicate,
        seed = fit_seed, status = "error",
        legacy_train = NA_real_, oof_train = NA_real_,
        legacy_test = NA_real_, oof_test = NA_real_,
        legacy_optimism = NA_real_, oof_optimism = NA_real_,
        oof_fallback_rate = NA_real_,
        error = paste(
          if (inherits(legacy_result$fit, "error")) conditionMessage(legacy_result$fit) else "",
          if (inherits(oof_result$fit, "error")) conditionMessage(oof_result$fit) else "",
          sep = " | "
        ), stringsAsFactors = FALSE
      )
      next
    }
    legacy <- legacy_result$fit
    oof <- oof_result$fit
    legacy_test <- .metric(d$family, dat$test_y, legacy$late_fusion$valid_predictions)
    oof_test <- .metric(d$family, dat$test_y, oof$late_fusion$valid_predictions)
    legacy_train <- .train_metric(d$family, dat$train_y, legacy)
    oof_train <- .train_metric(d$family, dat$train_y, oof)
    rows[[i]] <- data.frame(
      family = d$family, regime = d$regime, replicate = d$replicate,
      seed = fit_seed, status = "ok", legacy_train = legacy_train,
      oof_train = oof_train, legacy_test = legacy_test,
      oof_test = oof_test,
      legacy_optimism = abs(legacy_train - legacy_test),
      oof_optimism = abs(oof_train - oof_test),
      oof_fallback_rate = .fallback_rate(oof), error = "", stringsAsFactors = FALSE
    )
  }
  results <- do.call(rbind, rows)
  groups <- split(results, interaction(results$family, results$regime, drop = TRUE))
  summary <- do.call(rbind, lapply(groups, function(x) data.frame(
    family = x$family[[1L]], regime = x$regime[[1L]], replicates = nrow(x),
    successful_replicates = sum(x$status == "ok"),
    mean_legacy_optimism = mean(x$legacy_optimism),
    mean_oof_optimism = mean(x$oof_optimism),
    mean_test_difference = mean(x$oof_test - x$legacy_test),
    fallback_rate = mean(x$oof_fallback_rate),
    reduced_optimism = all(x$status == "ok") &&
      mean(x$oof_optimism) < mean(x$legacy_optimism),
    noninferior = all(x$status == "ok") &&
      mean(x$oof_test - x$legacy_test) >= -0.02,
    fallback_ok = all(x$status == "ok") &&
      if (x$regime[[1L]] == "signal") mean(x$oof_fallback_rate) < 0.05 else TRUE,
    stringsAsFactors = FALSE
  )))
  results_path <- file.path(out, "late_fusion_replicates.csv")
  summary_path <- file.path(out, "late_fusion_summary.csv")
  warnings_path <- file.path(out, "late_fusion_warnings.csv")
  utils::write.csv(results, results_path, row.names = FALSE)
  utils::write.csv(summary, summary_path, row.names = FALSE)
  warnings <- if (length(warning_rows)) do.call(rbind, warning_rows) else data.frame(
    family = character(), regime = character(), replicate = integer(),
    seed = integer(), mode = character(), warning = character()
  )
  utils::write.csv(warnings, warnings_path, row.names = FALSE)
  writeLines(c(
    paste("R", R.version.string),
    paste("stablr", as.character(utils::packageVersion("stablr"))),
    paste("replicates_per_cell", replicates),
    paste("n_bootstraps", n_bootstraps), paste("n_iter", n_iter),
    "Families: gaussian, binomial, multinomial; regimes: null, signal.",
    "Independent test samples are never used to fit selectors, learners, or weights.",
    "Gates: fallback < 5% in signal, reduced optimism, test noninferiority margin 0.02."
  ), file.path(out, "late_fusion_manifest.txt"))
  if (!all(summary$reduced_optimism & summary$noninferior & summary$fallback_ok)) {
    stop("Late-fusion release gates failed; release must stop.", call. = FALSE)
  }
  invisible(list(results = results_path, summary = summary_path))
}

if (sys.nframe() == 0L) {
  a <- .args(commandArgs(trailingOnly = TRUE))
  if (is.null(a$out)) stop("Usage: run_late_fusion_validation.R --out DIR [--replicates 50]")
  run_late_fusion_validation(
    a$out, as.integer(a$replicates %||% 50L),
    as.integer(a$`n-bootstraps` %||% 20L), as.integer(a$`n-iter` %||% 500L)
  )
}
