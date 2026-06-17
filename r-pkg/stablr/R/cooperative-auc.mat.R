# Vendored from CRAN multiview v1.0 (GPL-2). See inst/COPYING.cooperative.

auc.mat=function(y,prob,weights=rep(1,nrow(y))){
    Weights=as.vector(weights*y)
    ny=nrow(y)
    Y=rep(c(0,1),c(ny,ny))
    Prob=c(prob,prob)
    auc(Y,Prob,Weights)
  }

  
