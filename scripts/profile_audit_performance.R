#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

script_file <- tryCatch(normalizePath(sys.frame(1)$ofile, mustWork = TRUE),
                        error = function(e) NA_character_)
repo_root <- if (!is.na(script_file)) {
  normalizePath(file.path(dirname(script_file), ".."), mustWork = FALSE)
} else {
  normalizePath(getwd(), mustWork = TRUE)
}
if (!file.exists(file.path(repo_root, "DESCRIPTION"))) {
  repo_root <- normalizePath(getwd(), mustWork = TRUE)
}

load_costablr_source <- function(root) {
  if (requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(root, quiet = TRUE)
  } else {
    library(costablr)
  }
  source(file.path(root, "tests/testthat/helper-performance-references.R"),
         local = globalenv())
}

elapsed_seconds <- function(fun) {
  gc()
  unname(system.time(invisible(fun()))[["elapsed"]])
}

allocated_bytes <- function(fun) {
  tmp <- tempfile("costablr-rprofmem-")
  on.exit(unlink(tmp), add = TRUE)
  gc()
  utils::Rprofmem(tmp)
  on.exit(utils::Rprofmem(NULL), add = TRUE)
  invisible(fun())
  utils::Rprofmem(NULL)
  lines <- readLines(tmp, warn = FALSE)
  bytes <- suppressWarnings(as.numeric(sub(" .*", "", lines)))
  sum(bytes, na.rm = TRUE)
}

improvement <- function(old, new) {
  if (!is.finite(old) || old <= 0) {
    return(NA_real_)
  }
  1 - new / old
}

same_numeric_object <- function(old, new, tolerance = 1e-12) {
  isTRUE(all.equal(old, new, tolerance = tolerance, check.attributes = TRUE))
}

measure_pair <- function(label, old_fun, new_fun, parity_fun,
                         reps = 3L, mem_reps = 1L, warmup = 1L,
                         min_improvement = 0.10) {
  for (i in seq_len(warmup)) {
    invisible(old_fun())
    invisible(new_fun())
  }

  old_out <- old_fun()
  new_out <- new_fun()
  parity <- isTRUE(parity_fun(old_out, new_out))

  old_time <- replicate(reps, elapsed_seconds(old_fun))
  new_time <- replicate(reps, elapsed_seconds(new_fun))
  old_mem <- replicate(mem_reps, allocated_bytes(old_fun))
  new_mem <- replicate(mem_reps, allocated_bytes(new_fun))

  old_time_med <- stats::median(old_time)
  new_time_med <- stats::median(new_time)
  old_mem_med <- stats::median(old_mem)
  new_mem_med <- stats::median(new_mem)
  time_gain <- improvement(old_time_med, new_time_med)
  mem_gain <- improvement(old_mem_med, new_mem_med)

  keep <- parity &&
    ((is.finite(time_gain) && time_gain >= min_improvement) ||
       (is.finite(mem_gain) && mem_gain >= min_improvement))

  data.frame(
    finding = label,
    parity = parity,
    old_time_median_s = old_time_med,
    new_time_median_s = new_time_med,
    time_improvement_pct = 100 * time_gain,
    old_alloc_median_mb = old_mem_med / 1024^2,
    new_alloc_median_mb = new_mem_med / 1024^2,
    memory_improvement_pct = 100 * mem_gain,
    decision = if (keep) "KEEP" else "DISCARD_OR_REWORK",
    stringsAsFactors = FALSE
  )
}

profile_mvr_current <- function() {
  set.seed(707)
  p <- 24L
  rho <- 0.45
  Sigma <- rho^abs(outer(seq_len(p), seq_len(p), "-"))
  elapsed <- elapsed_seconds(function() {
    costablr:::.solve_mvr(Sigma, num_iter = 5L, use_cpp = TRUE)
  })
  data.frame(
    finding = "NAT-003-current-mvr-profile",
    parity = NA,
    old_time_median_s = NA_real_,
    new_time_median_s = elapsed,
    time_improvement_pct = NA_real_,
    old_alloc_median_mb = NA_real_,
    new_alloc_median_mb = NA_real_,
    memory_improvement_pct = NA_real_,
    decision = "INFO_ONLY",
    stringsAsFactors = FALSE
  )
}

make_binary_regression_case <- function() {
  set.seed(1001)
  n <- 1200L
  n_omics <- 6L
  predictions <- matrix(rnorm(n * n_omics), nrow = n)
  predictions[sample(length(predictions), size = floor(0.15 * length(predictions)))] <- NA_real_
  dimnames(predictions) <- list(paste0("s", seq_len(n)), paste0("omic", seq_len(n_omics)))
  y <- as.integer(rowSums(replace(predictions[, 1:2, drop = FALSE],
                                  is.na(predictions[, 1:2, drop = FALSE]), 0)) > 0)
  list(predictions = predictions, y = y)
}

make_multiclass_case <- function() {
  set.seed(1002)
  n <- 420L
  classes <- paste0("C", seq_len(5L))
  make_probs <- function() {
    raw <- matrix(stats::runif(n * length(classes)), nrow = n)
    raw <- raw / rowSums(raw)
    dimnames(raw) <- list(paste0("s", seq_len(n)), classes)
    raw
  }
  predictions <- stats::setNames(replicate(5L, make_probs(), simplify = FALSE),
                                 paste0("omic", seq_len(5L)))
  predictions[[2L]][seq(10L, n, by = 23L), ] <- NA_real_
  predictions[[4L]][seq(7L, n, by = 29L), 3L] <- NA_real_
  y <- sample(classes, n, replace = TRUE)
  list(predictions = predictions, y = y)
}

make_coeff_case <- function() {
  set.seed(1003)
  n <- 180L
  p <- 90L
  x <- matrix(rnorm(n * p), nrow = n)
  y <- rnorm(n)
  fit <- glmnet::glmnet(x, y, family = "gaussian", nlambda = 45L)
  list(fit = fit, lambda = fit$lambda)
}

make_group_case <- function() {
  n_groups <- 420L
  groups <- rep(paste0("id", seq_len(n_groups)), each = 3L)
  y <- rep(c("case", "control"), length.out = length(groups))
  list(groups = groups, y = y)
}

make_corr_case <- function() {
  set.seed(1004)
  n <- 70L
  p <- 1000L
  x <- matrix(rnorm(n * p), nrow = n)
  latent <- matrix(rnorm(n * 12L), nrow = n)
  for (j in seq_len(120L)) {
    x[, j] <- latent[, ((j - 1L) %% ncol(latent)) + 1L] + rnorm(n, sd = 0.04)
  }
  x[seq(1L, n, by = 9L), 5L] <- NA_real_
  x[, p] <- 1
  corr <- suppressWarnings(stats::cor(x, use = "pairwise.complete.obs"))
  corr[is.na(corr)] <- 0
  corr_vals <- corr[upper.tri(corr, diag = FALSE)]
  cutoff <- as.numeric(stats::quantile(corr_vals, probs = 0.95,
                                       names = FALSE, na.rm = TRUE)) - 0.1
  list(x = x, corr = corr, cutoff = cutoff)
}

main <- function() {
  load_costablr_source(repo_root)
  min_improvement <- as.numeric(Sys.getenv("COSTABLR_PERF_MIN_IMPROVEMENT", "0.10"))

  br <- make_binary_regression_case()
  mc <- make_multiclass_case()
  cf <- make_coeff_case()
  gp <- make_group_case()
  cr <- make_corr_case()

  results <- list(
    measure_pair(
      "PERF-001-binary-stacking",
      old_fun = function() .old_stacked_multi_omic(
        br$predictions, br$y, "binary", n_iter = 600L, random_state = 11L
      ),
      new_fun = function() stacked_multi_omic(
        br$predictions, br$y, "binary", n_iter = 600L, random_state = 11L
      ),
      parity_fun = same_numeric_object,
      min_improvement = min_improvement
    ),
    measure_pair(
      "PERF-002-multiclass-stacking",
      old_fun = function() .old_stacked_multi_omic(
        mc$predictions, mc$y, "multiclass", n_iter = 250L, random_state = 12L
      ),
      new_fun = function() stacked_multi_omic(
        mc$predictions, mc$y, "multiclass", n_iter = 250L, random_state = 12L
      ),
      parity_fun = same_numeric_object,
      min_improvement = min_improvement
    ),
    measure_pair(
      "PERF-003-glmnet-coef-batch",
      old_fun = function() .old_feature_abs_coefs_batch(
        cf$fit, cf$lambda, family = "gaussian"
      ),
      new_fun = function() costablr:::.feature_abs_coefs_batch(
        cf$fit, cf$lambda, family = "gaussian"
      ),
      parity_fun = function(old, new) {
        isTRUE(all.equal(old, new, tolerance = 1e-12, check.attributes = FALSE))
      },
      min_improvement = min_improvement
    ),
    measure_pair(
      "PERF-005-grouped-bootstrap-sampler",
      old_fun = function() {
        set.seed(13L)
        out <- vector("list", 70L)
        for (i in seq_along(out)) {
          out[[i]] <- .old_group_bootstrap_indices(
            y = gp$y,
            groups = gp$groups,
            n_subsamples = 630L,
            replace = FALSE
          )
        }
        out
      },
      new_fun = function() {
        set.seed(13L)
        sampler <- costablr:::.make_group_bootstrap_sampler(
          y = gp$y,
          groups = gp$groups,
          n_subsamples = 630L,
          replace = FALSE
        )
        out <- vector("list", 70L)
        for (i in seq_along(out)) {
          out[[i]] <- sampler()
        }
        out
      },
      parity_fun = identical,
      reps = 4L,
      min_improvement = min_improvement
    ),
    measure_pair(
      "PERF-006-correlation-union",
      old_fun = function() .old_corr_groups_from_corr(cr$corr, cr$cutoff),
      new_fun = function() costablr:::.corr_groups_from_corr(cr$corr, cr$cutoff),
      parity_fun = function(old, new) {
        isTRUE(all(.same_partition(old, new)))
      },
      reps = 4L,
      min_improvement = min_improvement
    ),
    profile_mvr_current()
  )

  out <- do.call(rbind, results)
  print(out, row.names = FALSE, digits = 4)

  gated <- out$decision != "INFO_ONLY"
  if (any(out$decision[gated] != "KEEP")) {
    failed <- paste(out$finding[gated][out$decision[gated] != "KEEP"], collapse = ", ")
    stop("Profiling gate failed for: ", failed, call. = FALSE)
  }
}

main()
