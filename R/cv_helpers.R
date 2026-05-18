# Shared cross-validation fold helpers for multi-omic and nested workflows.

.make_multiomic_cv_folds <- function(sample_ids,
                                     groups,
                                     v,
                                     random_state = NULL) {
  if (length(v) != 1L || is.na(v) || v < 2L) {
    stop("`v` must be a single integer greater than or equal to 2.", call. = FALSE)
  }

  v <- as.integer(v)

  units <- if (is.null(groups)) {
    sample_ids
  } else {
    as.character(unique(unname(groups[sample_ids])))
  }

  if (length(units) < v) {
    stop("The number of folds cannot exceed the number of samples/groups.",
         call. = FALSE)
  }

  ordered_units <- .permute_for_cv(units, random_state)
  unit_to_fold <- rep(seq_len(v), length.out = length(ordered_units))
  names(unit_to_fold) <- ordered_units

  assessment_fold <- if (is.null(groups)) {
    unit_to_fold[sample_ids]
  } else {
    unit_to_fold[as.character(groups[sample_ids])]
  }

  lapply(seq_len(v), function(fold_index) {
    valid_ids <- sample_ids[assessment_fold == fold_index]
    train_ids <- sample_ids[assessment_fold != fold_index]
    list(
      fold = paste0("Fold", fold_index),
      train_ids = train_ids,
      valid_ids = valid_ids
    )
  })
}

.permute_for_cv <- function(x, random_state = NULL) {
  if (is.null(random_state)) {
    return(sample(x, length(x), replace = FALSE))
  }

  if (length(random_state) != 1L || is.na(random_state)) {
    stop("`random_state` must be a single non-missing integer when supplied.",
         call. = FALSE)
  }

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
  sample(x, length(x), replace = FALSE)
}

.make_multiomic_foldid <- function(sample_ids,
                                   groups,
                                   v,
                                   random_state = NULL,
                                   strata = NULL) {
  if (!is.null(strata) && !is.null(groups)) {
    warning(
      "`strata` is ignored when `groups` is supplied; falling back to ",
      "grouped fold assignment.",
      call. = FALSE
    )
    strata <- NULL
  }

  if (!is.null(strata)) {
    return(.stratified_multiomic_foldid(
      sample_ids = sample_ids,
      strata = strata,
      v = v,
      random_state = random_state
    ))
  }

  folds <- .make_multiomic_cv_folds(
    sample_ids = sample_ids,
    groups = groups,
    v = v,
    random_state = random_state
  )

  foldid <- integer(length(sample_ids))
  names(foldid) <- sample_ids

  for (fold_index in seq_along(folds)) {
    foldid[folds[[fold_index]]$valid_ids] <- fold_index
  }

  unname(foldid[sample_ids])
}

.stratified_multiomic_foldid <- function(sample_ids, strata, v,
                                         random_state = NULL) {
  if (length(v) != 1L || is.na(v) || v < 2L) {
    stop("`v` must be a single integer greater than or equal to 2.",
         call. = FALSE)
  }
  if (length(strata) != length(sample_ids)) {
    stop("`strata` must be the same length as `sample_ids`.", call. = FALSE)
  }
  v <- as.integer(v)
  if (length(sample_ids) < v) {
    stop("The number of folds cannot exceed the number of samples.",
         call. = FALSE)
  }

  strata <- factor(strata)
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
  if (!is.null(random_state)) set.seed(as.integer(random_state))

  foldid <- integer(length(sample_ids))
  names(foldid) <- sample_ids

  for (lvl in levels(strata)) {
    cls_idx <- which(strata == lvl)
    if (length(cls_idx) == 0L) next
    shuffled <- sample(sample_ids[cls_idx])
    start <- if (length(shuffled) >= v) 1L else sample.int(v, 1L)
    fold_seq <- ((start - 1L + seq_along(shuffled) - 1L) %% v) + 1L
    foldid[shuffled] <- fold_seq
  }

  unname(foldid[sample_ids])
}

.make_repeated_cv_folds <- function(y, v, repeats = 1L, stratified = TRUE,
                                    random_state = NULL) {
  folds <- list()
  k <- 1L
  for (rep_i in seq_len(as.integer(repeats))) {
    rep_seed <- .derive_nested_seed(random_state, rep_i, 10L)
    rep_folds <- .make_cv_folds(
      y = y,
      v = v,
      stratified = stratified,
      random_state = rep_seed
    )
    for (fold_i in seq_along(rep_folds)) {
      fold <- rep_folds[[fold_i]]
      fold[["repeat"]] <- rep_i
      fold$fold <- paste0("Fold", fold_i)
      fold$fold_id <- paste0("Repeat", rep_i, "_Fold", fold_i)
      folds[[k]] <- fold
      k <- k + 1L
    }
  }
  folds
}

.make_repeated_stratified_folds <- function(y, v, repeats = 1L, random_state = NULL) {
  .make_repeated_cv_folds(
    y = y,
    v = v,
    repeats = repeats,
    stratified = TRUE,
    random_state = random_state
  )
}

.make_cv_folds <- function(y, v, stratified = TRUE, random_state = NULL) {
  if (isTRUE(stratified)) {
    return(.make_stratified_folds(y = y, v = v, random_state = random_state))
  }
  .make_unstratified_folds(y = y, v = v, random_state = random_state)
}

.make_stratified_folds <- function(y, v, random_state = NULL) {
  y <- factor(y)
  v <- as.integer(v)
  if (min(table(y)) < v) {
    stop("Each class must have at least `v` samples for stratified folds.", call. = FALSE)
  }
  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  ids <- names(y)
  fold_ids <- integer(length(y))
  names(fold_ids) <- ids
  for (lvl in levels(y)) {
    class_ids <- sample(ids[y == lvl])
    fold_ids[class_ids] <- rep(seq_len(v), length.out = length(class_ids))
  }

  lapply(seq_len(v), function(i) {
    valid_ids <- names(fold_ids)[fold_ids == i]
    list(
      train_ids = setdiff(ids, valid_ids),
      valid_ids = valid_ids,
      fold = paste0("Fold", i)
    )
  })
}

.make_unstratified_folds <- function(y, v, random_state = NULL) {
  ids <- names(y)
  v <- as.integer(v)
  if (length(ids) < v) {
    stop("The number of samples must be at least `v`.", call. = FALSE)
  }
  if (!is.null(random_state)) {
    old_seed_exists <- exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    if (old_seed_exists) old_seed <- get(".Random.seed", envir = .GlobalEnv, inherits = FALSE)
    on.exit({
      if (old_seed_exists) {
        assign(".Random.seed", old_seed, envir = .GlobalEnv)
      } else if (exists(".Random.seed", envir = .GlobalEnv, inherits = FALSE)) {
        rm(".Random.seed", envir = .GlobalEnv)
      }
    }, add = TRUE)
    set.seed(as.integer(random_state))
  }

  shuffled <- sample(ids)
  fold_ids <- rep(seq_len(v), length.out = length(shuffled))
  names(fold_ids) <- shuffled
  lapply(seq_len(v), function(i) {
    valid_ids <- names(fold_ids)[fold_ids == i]
    list(
      train_ids = setdiff(ids, valid_ids),
      valid_ids = valid_ids,
      fold = paste0("Fold", i)
    )
  })
}
