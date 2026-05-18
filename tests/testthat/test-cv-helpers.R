test_that("multiomic foldid helpers preserve fixed seeded assignments", {
  sample_ids <- paste0("s", seq_len(20L))
  strata <- rep(c("A", "B"), each = 10L)
  groups <- setNames(rep(paste0("g", seq_len(4L)), each = 5L), sample_ids)

  expect_identical(
    .stratified_multiomic_foldid(
      sample_ids = sample_ids,
      strata = strata,
      v = 5L,
      random_state = 42L
    ),
    c(1L, 5L, 5L, 1L, 2L, 2L, 4L, 4L, 3L, 3L,
      4L, 2L, 5L, 3L, 5L, 3L, 2L, 1L, 4L, 1L)
  )

  expect_identical(
    .make_multiomic_foldid(
      sample_ids = sample_ids,
      groups = NULL,
      v = 5L,
      random_state = 42L
    ),
    c(3L, 1L, 3L, 5L, 2L, 4L, 5L, 4L, 2L, 4L,
      5L, 2L, 4L, 5L, 1L, 1L, 1L, 3L, 3L, 2L)
  )

  group_foldid <- .make_multiomic_foldid(
    sample_ids = sample_ids,
    groups = groups,
    v = 2L,
    random_state = 42L
  )
  expect_identical(
    group_foldid,
    c(1L, 1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L, 2L,
      1L, 1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L, 2L)
  )
  expect_equal(
    as.integer(tapply(group_foldid, groups, function(x) length(unique(x)))),
    rep(1L, 4L)
  )
})

test_that("nested CV fold helpers preserve fixed seeded assignments", {
  sample_ids <- paste0("s", seq_len(20L))
  y <- setNames(factor(rep(c("A", "B"), each = 10L)), sample_ids)

  stratified <- .make_cv_folds(
    y = y,
    v = 5L,
    stratified = TRUE,
    random_state = 42L
  )
  expect_identical(
    lapply(stratified, `[[`, "valid_ids"),
    list(
      c("s1", "s4", "s18", "s20"),
      c("s5", "s6", "s12", "s17"),
      c("s9", "s10", "s14", "s16"),
      c("s7", "s8", "s11", "s19"),
      c("s2", "s3", "s13", "s15")
    )
  )

  unstratified <- .make_cv_folds(
    y = y,
    v = 5L,
    stratified = FALSE,
    random_state = 42L
  )
  expect_identical(
    lapply(unstratified, `[[`, "valid_ids"),
    list(
      c("s17", "s2", "s16", "s15"),
      c("s5", "s20", "s9", "s12"),
      c("s1", "s18", "s19", "s3"),
      c("s10", "s8", "s6", "s13"),
      c("s4", "s7", "s14", "s11")
    )
  )
})

test_that("repeated nested CV folds preserve repeat metadata and assignments", {
  sample_ids <- paste0("s", seq_len(20L))
  y <- setNames(factor(rep(c("A", "B"), each = 10L)), sample_ids)

  repeated <- .make_repeated_cv_folds(
    y = y,
    v = 5L,
    repeats = 2L,
    stratified = TRUE,
    random_state = 42L
  )
  summary <- lapply(repeated, function(fold) {
    list(
      fold_id = fold$fold_id,
      repeat_id = fold[["repeat"]],
      fold = fold$fold,
      valid_ids = fold$valid_ids
    )
  })

  expect_identical(
    summary,
    list(
      list(fold_id = "Repeat1_Fold1", repeat_id = 1L, fold = "Fold1",
           valid_ids = c("s6", "s8", "s15", "s17")),
      list(fold_id = "Repeat1_Fold2", repeat_id = 1L, fold = "Fold2",
           valid_ids = c("s5", "s7", "s13", "s14")),
      list(fold_id = "Repeat1_Fold3", repeat_id = 1L, fold = "Fold3",
           valid_ids = c("s1", "s2", "s11", "s19")),
      list(fold_id = "Repeat1_Fold4", repeat_id = 1L, fold = "Fold4",
           valid_ids = c("s3", "s10", "s16", "s18")),
      list(fold_id = "Repeat1_Fold5", repeat_id = 1L, fold = "Fold5",
           valid_ids = c("s4", "s9", "s12", "s20")),
      list(fold_id = "Repeat2_Fold1", repeat_id = 2L, fold = "Fold1",
           valid_ids = c("s1", "s6", "s12", "s15")),
      list(fold_id = "Repeat2_Fold2", repeat_id = 2L, fold = "Fold2",
           valid_ids = c("s8", "s9", "s11", "s17")),
      list(fold_id = "Repeat2_Fold3", repeat_id = 2L, fold = "Fold3",
           valid_ids = c("s4", "s5", "s18", "s20")),
      list(fold_id = "Repeat2_Fold4", repeat_id = 2L, fold = "Fold4",
           valid_ids = c("s3", "s10", "s16", "s19")),
      list(fold_id = "Repeat2_Fold5", repeat_id = 2L, fold = "Fold5",
           valid_ids = c("s2", "s7", "s13", "s14"))
    )
  )
})
