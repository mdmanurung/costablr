# Internal cooperative-learning backend (vendored multiview engine).

.cooperative_family_to_backend <- function(family) {
  switch(
    family,
    gaussian = stats::gaussian(),
    binomial = stats::binomial(),
    stop(
      "`cooperative_fusion = TRUE` only supports family = 'gaussian' or 'binomial'.",
      call. = FALSE
    )
  )
}

# @noRd
.cooperative_backend_fit <- function(x_list,
                                    y,
                                    family,
                                    rho = 0,
                                    ...) {
  fam <- .cooperative_family_to_backend(family)
  .mv_multiview(
    x_list = x_list,
    y = y,
    family = fam,
    rho = rho,
    ...
  )
}

# @noRd
.cooperative_backend_cv <- function(x_list,
                                   y,
                                   family,
                                   rho = 0,
                                   foldid = NULL,
                                   type.measure = "default",
                                   nfolds = 10,
                                   ...) {
  fam <- .cooperative_family_to_backend(family)
  .mv_cv_multiview(
    x_list = x_list,
    y = y,
    family = fam,
    rho = rho,
    foldid = foldid,
    type.measure = type.measure,
    nfolds = nfolds,
    ...
  )
}

.has_cooperative_backend <- function() {
  TRUE
}
