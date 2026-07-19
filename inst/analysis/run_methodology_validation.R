#!/usr/bin/env Rscript

# Deterministic, bounded methodology validation experiments for stablr.
# This file is intentionally outside R/ so experiments can observe proposed
# methodology changes without changing package runtime behavior.

.parse_cli_args <- function(args) {
  if ("--help" %in% args || "-h" %in% args) {
    return(list(help = TRUE))
  }

  out <- list()
  i <- 1L
  while (i <= length(args)) {
    key <- args[[i]]
    if (!startsWith(key, "--")) {
      stop("Unexpected positional argument: ", key, call. = FALSE)
    }
    if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
      stop("Missing value for ", key, call. = FALSE)
    }
    out[[sub("^-+", "", key)]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out
}

.usage <- function() {
  paste(
    "Usage:",
    "  run_methodology_validation.R --out /tmp/output-dir [options]",
    "",
    "Options:",
    "  --replicates N              Monte Carlo replicates per scenario/type. Default: 3",
    "  --n-bootstraps N            STABL bootstraps per fit. Default: 12",
    "  --n-lambda N                Auto lambda-grid size. Default: 6",
    "  --artificial-types CSV      Default: random_permutation,knockoff_equi",
    "  --scenarios CSV             Default: all bounded scenarios",
    "  --seed N                    Top-level seed. Default: 270627",
    "  --target-fdp X              Calibration reference threshold. Default: 0.1",
    "",
    "Artifacts:",
    "  methodology_validation_replicates.csv",
    "  methodology_validation_summary.csv",
    "  methodology_validation_warnings.csv",
    "  python_metrics_parity.csv",
    "  methodology_validation_manifest.txt",
    sep = "\n"
  )
}

.csv_arg <- function(value, default) {
  if (is.null(value) || !nzchar(value)) return(default)
  trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
}

.int_arg <- function(value, default, name, min = 1L) {
  if (is.null(value) || !nzchar(value)) return(default)
  out <- suppressWarnings(as.integer(value))
  if (is.na(out) || out < min) {
    stop("`--", name, "` must be an integer >= ", min, ".", call. = FALSE)
  }
  out
}

.num_arg <- function(value, default, name, min = -Inf, max = Inf) {
  if (is.null(value) || !nzchar(value)) return(default)
  out <- suppressWarnings(as.numeric(value))
  if (is.na(out) || out < min || out > max) {
    stop("`--", name, "` must be numeric in [", min, ", ", max, "].", call. = FALSE)
  }
  out
}

.default_scenarios <- function() {
  data.frame(
    scenario = c(
      "null_independent",
      "null_correlated",
      "signal_correlated",
      "signal_high_dim"
    ),
    regime = c("null", "null", "signal", "signal"),
    profile = c("low_dim", "low_dim", "low_dim", "high_dim"),
    n = c(60L, 60L, 60L, 45L),
    p = c(30L, 30L, 30L, 75L),
    n_signal = c(0L, 0L, 5L, 5L),
    correlation = c(0.0, 0.7, 0.7, 0.6),
    noise_sd = c(1.0, 1.0, 0.8, 0.8),
    stringsAsFactors = FALSE
  )
}

.select_scenarios <- function(ids) {
  scenarios <- .default_scenarios()
  if (identical(ids, "all")) return(scenarios)
  unknown <- setdiff(ids, scenarios$scenario)
  if (length(unknown)) {
    stop("Unknown scenario(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  scenarios[match(ids, scenarios$scenario), , drop = FALSE]
}

.ar1_matrix <- function(p, rho) {
  idx <- seq_len(p)
  outer(idx, idx, function(i, j) rho^abs(i - j))
}

.simulate_scenario <- function(scenario, seed) {
  set.seed(seed)
  sigma <- .ar1_matrix(scenario$p, scenario$correlation)
  z <- matrix(stats::rnorm(scenario$n * scenario$p), nrow = scenario$n)
  x <- z %*% chol(sigma)
  x <- scale(x)
  x <- matrix(
    as.numeric(x),
    nrow = scenario$n,
    dimnames = list(
      paste0("s", seq_len(scenario$n)),
      paste0("f", seq_len(scenario$p))
    )
  )

  if (scenario$n_signal > 0L) {
    beta <- seq(1.0, 0.45, length.out = scenario$n_signal)
    eta <- drop(x[, seq_len(scenario$n_signal), drop = FALSE] %*% beta)
    eta <- eta / stats::sd(eta)
    y <- eta + stats::rnorm(scenario$n, sd = scenario$noise_sd)
    signal <- paste0("f", seq_len(scenario$n_signal))
  } else {
    y <- stats::rnorm(scenario$n, sd = scenario$noise_sd)
    signal <- character(0L)
  }

  list(
    x = x,
    y = stats::setNames(y, rownames(x)),
    signal = signal
  )
}

.fit_with_warning_capture <- function(data, artificial_type, n_bootstraps,
                                      n_lambda, seed) {
  warnings <- character()
  elapsed <- system.time({
    fit <- tryCatch(
      withCallingHandlers(
        stablr::stabl_fit(
          x = data$x,
          y = data$y,
          lambda_grid = "auto",
          n_lambda = n_lambda,
          n_bootstraps = n_bootstraps,
          artificial_type = artificial_type,
          random_state = seed
        ),
        warning = function(w) {
          warnings <<- c(warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) e
    )
  })

  list(
    fit = fit,
    warnings = warnings,
    elapsed_sec = unname(elapsed[["elapsed"]])
  )
}

.empty_replicate_row <- function() {
  data.frame(
    scenario = character(),
    regime = character(),
    correlation = numeric(),
    profile = character(),
    replicate = integer(),
    artificial_type = character(),
    status = character(),
    n = integer(),
    p = integer(),
    n_signal = integer(),
    n_bootstraps = integer(),
    n_lambda = integer(),
    fallback_random_permutation_warnings = integer(),
    fallback_equi_warnings = integer(),
    warning_count = integer(),
    elapsed_sec = numeric(),
    n_selected = integer(),
    true_positives = integer(),
    false_positives = integer(),
    empirical_fdp = numeric(),
    tpr = numeric(),
    min_fdp_plus = numeric(),
    fdp_threshold = numeric(),
    mean_max_real_score = numeric(),
    mean_max_artificial_score = numeric(),
    max_artificial_score = numeric(),
    selected_features = character(),
    error = character(),
    stringsAsFactors = FALSE
  )
}

.replicate_row <- function(scenario, replicate, artificial_type, status,
                           n_bootstraps, n_lambda, warnings, elapsed_sec,
                           selected = character(), signal = character(),
                           fit = NULL, error = "") {
  fp <- length(setdiff(selected, signal))
  tp <- length(intersect(selected, signal))
  n_selected <- length(selected)
  art_scores <- if (!is.null(fit)) fit$stabl_scores_artificial_ else NULL
  real_scores <- if (!is.null(fit)) fit$stabl_scores_ else NULL

  data.frame(
    scenario = scenario$scenario,
    regime = scenario$regime,
    correlation = scenario$correlation,
    profile = scenario$profile,
    replicate = replicate,
    artificial_type = artificial_type,
    status = status,
    n = scenario$n,
    p = scenario$p,
    n_signal = scenario$n_signal,
    n_bootstraps = n_bootstraps,
    n_lambda = n_lambda,
    fallback_random_permutation_warnings = sum(grepl("falling back to random permutation", warnings, fixed = TRUE)),
    fallback_equi_warnings = sum(grepl("using equi S", warnings, fixed = TRUE)),
    warning_count = length(warnings),
    elapsed_sec = elapsed_sec,
    n_selected = n_selected,
    true_positives = tp,
    false_positives = fp,
    empirical_fdp = fp / max(1L, n_selected),
    tpr = if (length(signal)) tp / length(signal) else NA_real_,
    min_fdp_plus = if (!is.null(fit)) fit$min_fdr_ else NA_real_,
    fdp_threshold = if (!is.null(fit)) fit$fdr_min_threshold_ else NA_real_,
    mean_max_real_score = if (!is.null(real_scores)) mean(apply(real_scores, 1L, max)) else NA_real_,
    mean_max_artificial_score = if (!is.null(art_scores)) mean(apply(art_scores, 1L, max)) else NA_real_,
    max_artificial_score = if (!is.null(art_scores)) max(apply(art_scores, 1L, max)) else NA_real_,
    selected_features = paste(selected, collapse = ";"),
    error = error,
    stringsAsFactors = FALSE
  )
}

.warning_rows <- function(scenario, replicate, artificial_type, warnings) {
  if (!length(warnings)) {
    return(data.frame(
      scenario = character(),
      replicate = integer(),
      artificial_type = character(),
      warning_index = integer(),
      warning = character(),
      stringsAsFactors = FALSE
    ))
  }
  data.frame(
    scenario = scenario$scenario,
    replicate = replicate,
    artificial_type = artificial_type,
    warning_index = seq_along(warnings),
    warning = warnings,
    stringsAsFactors = FALSE
  )
}

.run_one_condition <- function(scenario, replicate, artificial_type,
                               n_bootstraps, n_lambda, seed) {
  if (startsWith(artificial_type, "knockoff") &&
      !requireNamespace("knockoff", quietly = TRUE)) {
    return(list(
      replicate = .replicate_row(
        scenario = scenario,
        replicate = replicate,
        artificial_type = artificial_type,
        status = "skipped_missing_knockoff",
        n_bootstraps = n_bootstraps,
        n_lambda = n_lambda,
        warnings = character(),
        elapsed_sec = NA_real_,
        error = "The optional knockoff package is not installed."
      ),
      warnings = .warning_rows(scenario, replicate, artificial_type, character())
    ))
  }

  data <- .simulate_scenario(scenario, seed = seed)
  result <- .fit_with_warning_capture(
    data = data,
    artificial_type = artificial_type,
    n_bootstraps = n_bootstraps,
    n_lambda = n_lambda,
    seed = seed
  )

  if (inherits(result$fit, "error")) {
    row <- .replicate_row(
      scenario = scenario,
      replicate = replicate,
      artificial_type = artificial_type,
      status = "error",
      n_bootstraps = n_bootstraps,
      n_lambda = n_lambda,
      warnings = result$warnings,
      elapsed_sec = result$elapsed_sec,
      error = conditionMessage(result$fit)
    )
  } else {
    selected <- stablr::get_feature_names_out(result$fit)
    row <- .replicate_row(
      scenario = scenario,
      replicate = replicate,
      artificial_type = artificial_type,
      status = "ok",
      n_bootstraps = n_bootstraps,
      n_lambda = n_lambda,
      warnings = result$warnings,
      elapsed_sec = result$elapsed_sec,
      selected = selected,
      signal = data$signal,
      fit = result$fit
    )
  }

  list(
    replicate = row,
    warnings = .warning_rows(
      scenario = scenario,
      replicate = replicate,
      artificial_type = artificial_type,
      warnings = result$warnings
    )
  )
}

.mean_or_na <- function(x) {
  x <- x[is.finite(x)]
  if (!length(x)) NA_real_ else mean(x)
}

.summarise_replicates <- function(rows, target_fdp) {
  if (!nrow(rows)) {
    return(data.frame(
      scenario = character(),
      artificial_type = character(),
      profile = character(),
      regime = character(),
      correlation = numeric(),
      n = integer(),
      p = integer(),
      n_signal = integer(),
      replicates = integer(),
      ok_replicates = integer(),
      mean_selected = numeric(),
      mean_empirical_fdp = numeric(),
      mean_tpr = numeric(),
      empirical_fdp_exceedance_rate = numeric(),
      mean_min_fdp_plus = numeric(),
      mean_fdp_threshold = numeric(),
      fallback_random_permutation_rate = numeric(),
      fallback_equi_rate = numeric(),
      mean_elapsed_sec = numeric(),
      stringsAsFactors = FALSE
    ))
  }

  groups <- unique(rows[c("scenario", "artificial_type")])
  summaries <- vector("list", nrow(groups))
  for (i in seq_len(nrow(groups))) {
    idx <- rows$scenario == groups$scenario[[i]] &
      rows$artificial_type == groups$artificial_type[[i]]
    d <- rows[idx, , drop = FALSE]
    ok <- d$status == "ok"
    summaries[[i]] <- data.frame(
      scenario = d$scenario[[1L]],
      artificial_type = d$artificial_type[[1L]],
      profile = d$profile[[1L]],
      regime = d$regime[[1L]],
      correlation = d$correlation[[1L]],
      n = d$n[[1L]],
      p = d$p[[1L]],
      n_signal = d$n_signal[[1L]],
      replicates = nrow(d),
      ok_replicates = sum(ok),
      mean_selected = .mean_or_na(d$n_selected[ok]),
      mean_empirical_fdp = .mean_or_na(d$empirical_fdp[ok]),
      mean_tpr = .mean_or_na(d$tpr[ok]),
      empirical_fdp_exceedance_rate = .mean_or_na(as.numeric(d$empirical_fdp[ok] > target_fdp)),
      mean_min_fdp_plus = .mean_or_na(d$min_fdp_plus[ok]),
      mean_fdp_threshold = .mean_or_na(d$fdp_threshold[ok]),
      fallback_random_permutation_rate = .mean_or_na(as.numeric(d$fallback_random_permutation_warnings[ok] > 0L)),
      fallback_equi_rate = .mean_or_na(as.numeric(d$fallback_equi_warnings[ok] > 0L)),
      mean_elapsed_sec = .mean_or_na(d$elapsed_sec[ok]),
      stringsAsFactors = FALSE
    )
  }
  do.call(rbind, summaries)
}

.find_package_root <- function(start = getwd()) {
  path <- normalizePath(start, mustWork = TRUE)
  repeat {
    desc <- file.path(path, "DESCRIPTION")
    if (file.exists(desc)) {
      fields <- read.dcf(desc)
      if (identical(unname(fields[1L, "Package"]), "stablr")) return(path)
    }
    parent <- dirname(path)
    if (identical(parent, path)) return(NA_character_)
    path <- parent
  }
}

.metric_inputs <- function() {
  list(
    pair_pred = c("f1", "f2", "f5"),
    pair_true = c("f2", "f3", "f6"),
    list_of_lists = list(
      c("f1", "f2", "f3"),
      c("f2", "f3", "f4"),
      c("f1", "f4"),
      character(0)
    ),
    nb_total = 8L,
    d = 8L
  )
}

.similarity_scalar_observations <- function(inp) {
  adj_median <- stablr::adjusted_similarity_measure(inp$list_of_lists, inp$nb_total)
  adj_mean <- stablr::adjusted_similarity_measure(inp$list_of_lists, inp$nb_total, stat = "mean")
  pear_median <- stablr::pearson_similarity_measure(inp$list_of_lists, inp$d)
  pear_mean <- stablr::pearson_similarity_measure(inp$list_of_lists, inp$d, stat = "mean")

  c(
    jaccard_similarity_pair = stablr::jaccard_similarity(inp$pair_pred, inp$pair_true),
    adjusted_similarity_pair = stablr::adjusted_similarity(inp$pair_pred, inp$pair_true, inp$nb_total),
    pearson_similarity_pair = stablr::pearson_similarity(inp$pair_pred, inp$pair_true, inp$d),
    fdr_similarity_pair = stablr::fdr_similarity(inp$pair_pred, inp$pair_true),
    tpr_similarity_pair = stablr::tpr_similarity(inp$pair_pred, inp$pair_true),
    fscore_similarity_beta1_pair = stablr::fscore_similarity(inp$pair_pred, inp$pair_true, beta = 1),
    fscore_similarity_beta2_pair = stablr::fscore_similarity(inp$pair_pred, inp$pair_true, beta = 2),
    adjusted_similarity_measure_median_stat = adj_median$statistic,
    adjusted_similarity_measure_median_err_q25 = unname(adj_median$err[[1L]]),
    adjusted_similarity_measure_median_err_q75 = unname(adj_median$err[[2L]]),
    adjusted_similarity_measure_mean_stat = adj_mean$statistic,
    adjusted_similarity_measure_mean_err_sd = adj_mean$err,
    pearson_similarity_measure_median_stat = pear_median$statistic,
    pearson_similarity_measure_median_err_q25 = unname(pear_median$err[[1L]]),
    pearson_similarity_measure_median_err_q75 = unname(pear_median$err[[2L]]),
    pearson_similarity_measure_mean_stat = pear_mean$statistic,
    pearson_similarity_measure_mean_err_sd = pear_mean$err
  )
}

.similarity_vector_observations <- function(inp) {
  jaccard <- stablr::jaccard_matrix(inp$list_of_lists, remove_diag = TRUE)
  list(
    jaccard_matrix_remove_diag_rowmajor = as.vector(t(jaccard)),
    adjusted_similarity_values = stablr::adjusted_similarity_values(inp$list_of_lists, inp$nb_total),
    pearson_similarity_values = stablr::pearson_similarity_values(inp$list_of_lists, inp$d)
  )
}

.run_python_metrics_parity <- function(package_root, tolerance = 1e-12) {
  schema <- data.frame(
    metric = character(),
    index = integer(),
    reference = numeric(),
    observed = numeric(),
    abs_error = numeric(),
    status = character(),
    stringsAsFactors = FALSE
  )
  if (is.na(package_root)) {
    return(rbind(schema, data.frame(
      metric = "python_parity_fixture_dir",
      index = NA_integer_,
      reference = NA_real_,
      observed = NA_real_,
      abs_error = NA_real_,
      status = "skipped_package_root_not_found",
      stringsAsFactors = FALSE
    )))
  }

  fixture_dir <- file.path(package_root, "tests", "testthat", "fixtures", "python_parity")
  scalar_file <- file.path(fixture_dir, "metrics_scalars.csv")
  vector_file <- file.path(fixture_dir, "metrics_vectors.csv")
  if (!file.exists(scalar_file) || !file.exists(vector_file)) {
    return(rbind(schema, data.frame(
      metric = "python_parity_fixtures",
      index = NA_integer_,
      reference = NA_real_,
      observed = NA_real_,
      abs_error = NA_real_,
      status = "skipped_missing_fixture",
      stringsAsFactors = FALSE
    )))
  }

  scalars <- utils::read.csv(scalar_file, stringsAsFactors = FALSE, check.names = FALSE)
  vectors <- utils::read.csv(vector_file, stringsAsFactors = FALSE, check.names = FALSE)
  inp <- .metric_inputs()
  observed_scalars <- .similarity_scalar_observations(inp)
  observed_vectors <- .similarity_vector_observations(inp)

  scalar_rows <- lapply(seq_len(nrow(scalars)), function(i) {
    metric <- scalars$metric[[i]]
    observed <- unname(observed_scalars[[metric]])
    err <- abs(observed - scalars$value[[i]])
    data.frame(
      metric = metric,
      index = NA_integer_,
      reference = scalars$value[[i]],
      observed = observed,
      abs_error = err,
      status = if (is.finite(err) && err <= tolerance) "ok" else "mismatch",
      stringsAsFactors = FALSE
    )
  })

  vector_rows <- lapply(split(vectors, vectors$metric), function(ref) {
    metric <- ref$metric[[1L]]
    ref <- ref[order(ref$index), , drop = FALSE]
    observed <- observed_vectors[[metric]]
    n <- max(length(observed), nrow(ref))
    data.frame(
      metric = metric,
      index = seq_len(n),
      reference = c(ref$value, rep(NA_real_, n - nrow(ref))),
      observed = c(observed, rep(NA_real_, n - length(observed))),
      abs_error = abs(c(observed, rep(NA_real_, n - length(observed))) -
                        c(ref$value, rep(NA_real_, n - nrow(ref)))),
      status = ifelse(
        is.finite(abs(c(observed, rep(NA_real_, n - length(observed))) -
                        c(ref$value, rep(NA_real_, n - nrow(ref))))) &
          abs(c(observed, rep(NA_real_, n - length(observed))) -
                c(ref$value, rep(NA_real_, n - nrow(ref)))) <= tolerance,
        "ok",
        "mismatch"
      ),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, c(list(schema), scalar_rows, vector_rows))
}

.write_manifest <- function(path, settings, artifacts) {
  lines <- c(
    "stablr methodology validation manifest",
    paste0("created_at: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    paste0("seed: ", settings$seed),
    paste0("replicates: ", settings$replicates),
    paste0("n_bootstraps: ", settings$n_bootstraps),
    paste0("n_lambda: ", settings$n_lambda),
    paste0("target_fdp: ", settings$target_fdp),
    paste0("artificial_types: ", paste(settings$artificial_types, collapse = ",")),
    paste0("scenarios: ", paste(settings$scenarios$scenario, collapse = ",")),
    "",
    "hypotheses:",
    "1. FDP+ should avoid all-feature collapse under null settings, including correlated predictors.",
    "2. In signal settings, empirical FDP and TPR quantify the calibration-power tradeoff across artificial-feature strategies.",
    "3. Knockoff fallback frequency should be visible through warnings and additive fit provenance.",
    "4. Bundled Python metric fixtures should remain numerically identical to exported R metrics.",
    "",
    "artifacts:",
    paste0("replicates: ", artifacts$replicates),
    paste0("summary: ", artifacts$summary),
    paste0("warnings: ", artifacts$warnings),
    paste0("parity: ", artifacts$parity)
  )
  writeLines(lines, con = path)
}

run_methodology_validation <- function(out,
                                       replicates = 3L,
                                       n_bootstraps = 12L,
                                       n_lambda = 6L,
                                       artificial_types = c("random_permutation", "knockoff_equi"),
                                       scenario_ids = "all",
                                       seed = 270627L,
                                       target_fdp = 0.1) {
  if (missing(out) || is.null(out) || !nzchar(out)) {
    stop("`out` must be a non-empty output directory.", call. = FALSE)
  }
  replicates <- as.integer(replicates)
  n_bootstraps <- as.integer(n_bootstraps)
  n_lambda <- as.integer(n_lambda)
  seed <- as.integer(seed)
  if (any(is.na(c(replicates, n_bootstraps, n_lambda, seed))) ||
      replicates < 1L || n_bootstraps < 1L || n_lambda < 1L) {
    stop("`replicates`, `n_bootstraps`, `n_lambda`, and `seed` must be positive integers.",
         call. = FALSE)
  }
  if (!is.numeric(target_fdp) || length(target_fdp) != 1L ||
      is.na(target_fdp) || target_fdp < 0 || target_fdp > 1) {
    stop("`target_fdp` must be a numeric scalar in [0, 1].", call. = FALSE)
  }

  scenarios <- .select_scenarios(scenario_ids)
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  out <- normalizePath(out, mustWork = TRUE)

  replicate_rows <- list()
  warning_rows <- list()
  k <- 0L
  for (scenario_i in seq_len(nrow(scenarios))) {
    scenario <- scenarios[scenario_i, , drop = FALSE]
    for (replicate in seq_len(replicates)) {
      data_seed <- seed + scenario_i * 100000L + replicate * 1000L
      for (type_i in seq_along(artificial_types)) {
        fit_seed <- data_seed + type_i
        result <- .run_one_condition(
          scenario = scenario,
          replicate = replicate,
          artificial_type = artificial_types[[type_i]],
          n_bootstraps = n_bootstraps,
          n_lambda = n_lambda,
          seed = fit_seed
        )
        k <- k + 1L
        replicate_rows[[k]] <- result$replicate
        warning_rows[[k]] <- result$warnings
      }
    }
  }

  replicates_df <- if (length(replicate_rows)) {
    do.call(rbind, replicate_rows)
  } else {
    .empty_replicate_row()
  }
  warnings_df <- if (length(warning_rows)) {
    do.call(rbind, warning_rows)
  } else {
    .warning_rows(scenarios[1L, , drop = FALSE], 1L, "", character())
  }
  summary_df <- .summarise_replicates(replicates_df, target_fdp = target_fdp)
  parity_df <- .run_python_metrics_parity(.find_package_root())

  artifacts <- list(
    replicates = file.path(out, "methodology_validation_replicates.csv"),
    summary = file.path(out, "methodology_validation_summary.csv"),
    warnings = file.path(out, "methodology_validation_warnings.csv"),
    parity = file.path(out, "python_metrics_parity.csv"),
    manifest = file.path(out, "methodology_validation_manifest.txt")
  )

  utils::write.csv(replicates_df, artifacts$replicates, row.names = FALSE)
  utils::write.csv(summary_df, artifacts$summary, row.names = FALSE)
  utils::write.csv(warnings_df, artifacts$warnings, row.names = FALSE)
  utils::write.csv(parity_df, artifacts$parity, row.names = FALSE)
  .write_manifest(
    path = artifacts$manifest,
    settings = list(
      seed = seed,
      replicates = replicates,
      n_bootstraps = n_bootstraps,
      n_lambda = n_lambda,
      target_fdp = target_fdp,
      artificial_types = artificial_types,
      scenarios = scenarios
    ),
    artifacts = artifacts
  )

  artifacts
}

.main <- function(args = commandArgs(trailingOnly = TRUE)) {
  parsed <- .parse_cli_args(args)
  if (isTRUE(parsed$help)) {
    cat(.usage(), "\n")
    return(invisible(0L))
  }
  if (is.null(parsed$out) || !nzchar(parsed$out)) {
    stop(.usage(), call. = FALSE)
  }

  artifacts <- run_methodology_validation(
    out = parsed$out,
    replicates = .int_arg(parsed$replicates, 3L, "replicates"),
    n_bootstraps = .int_arg(parsed[["n-bootstraps"]], 12L, "n-bootstraps"),
    n_lambda = .int_arg(parsed[["n-lambda"]], 6L, "n-lambda"),
    artificial_types = .csv_arg(parsed[["artificial-types"]],
                                c("random_permutation", "knockoff_equi")),
    scenario_ids = .csv_arg(parsed$scenarios, "all"),
    seed = .int_arg(parsed$seed, 270627L, "seed"),
    target_fdp = .num_arg(parsed[["target-fdp"]], 0.1, "target-fdp", min = 0, max = 1)
  )

  message("Wrote methodology validation artifacts:")
  for (name in names(artifacts)) {
    message("  ", name, ": ", artifacts[[name]])
  }
  invisible(artifacts)
}

if (identical(environment(), globalenv()) && !interactive()) {
  .main()
}
