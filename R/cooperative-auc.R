# Vendored from CRAN multiview v1.0 (GPL-2). See inst/COPYING.cooperative.

auc=function(y,prob,w){
  if(missing(w))
    survival::concordance(y~prob)$concordance
  else
    survival::concordance(y~prob,weights=w)$concordance
}
