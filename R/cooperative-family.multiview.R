# Vendored from CRAN multiview v1.0 (GPL-2). See inst/COPYING.cooperative.



family.multiview <- function(object, ...) {
    ## families=c(elnet = "gaussian", lognet = "binomial", fishnet = "poisson",
    ##            multnet = "multinomial", coxnet = "cox", mrelnet = "mgaussian")
    ## cl <- class(object)[1]
    ## families[cl]
    fam <- object$family
    if (is.character(fam)) fam else fam$family
}



family.cv.multiview <- function(object, ...) family(object$multiview.fit)
