#' @title Fit stuff
#'
#' @description XXX
#'
#' @export
#'
#' @param Data XXX
#' @param Meshsize XXX
#' @param x0 XXX
#' @param rtype XXX
#' @param rel.power XXX

NetFit <- function(Data,Meshsize,x0,rtype="norm.loc",rel.power=NULL) {
  if(sum(sort(Meshsize)==Meshsize)!=length(Meshsize))
    stop("Mesh size must be ascending order")
  if(is.null(rel.power)) rel.power=rep(1,length(Meshsize))
  Counts=Data[,-1]
  if(ncol(Counts)!=length(Meshsize))
    stop("Number of mesh sizes should be ",ncol(Counts))
  CountPropns=Counts/apply(Counts,1,sum,na.rm=TRUE)
  fullfit.l=sum(Counts*log(CountPropns),na.rm=TRUE)
  r=selncurves(rtype) #Get selection curve function
  fit=optim(x0,nllhood,Data=Data,Meshsize=Meshsize,r=r,rel.power=rel.power,
            hessian=T,control=list(trace=F))
  cat("Parameters=",fit$par,",    Deviance=",2*(fullfit.l+fit$value),"\n")
  invisible(c(fit,deviance=deviance,rtype=rtype,rel.power=list(rel.power),
              Meshsize=list(Meshsize),Data=list(Data)))
}


#' @title Likelihood function
#'
#' @description XXX
#'
#'
#' @param theta XXX
#' @param Data XXX
#' @param Meshsize XXX
#' @param r XXX
#' @param rel.power XXX
nllhood=function(theta,Data,Meshsize,r,rel.power) {
  lens=Data[,1]; Counts=Data[,-1]
  rmatrix=outer(lens,Meshsize,r,theta)
  rmatrix[is.na(Counts)]=NA #No fitted retention for missing meshsizes
  rmatrix=t(t(rmatrix)*rel.power)
  phi=rmatrix/apply(rmatrix,1,sum,na.rm=TRUE)
  nll=-sum(Counts*log(phi),na.rm=TRUE)
  return(nll) }

#' @title Estimate stuff
#'
#' @description XXX
#'
#' @export
#'
#' @param fit XXX
Estimates <- function(fit) {

  x=fit$par
  varx=solve(fit$hess)
  names=c("Mode(mesh1)","Std dev.(mesh1)")
  switch(fit$rtype,
         "norm.loc"={ pars=x; varpars=varx },
         "norm.sca"={ pars=x; varpars=varx },
         "lognorm"={
           pars=c(exp(x[1]-x[2]^2),sqrt(exp(2*x[1]+x[2]^2)*(exp(x[2]^2)-1)))
           varpars=msm::deltamethod(list(~exp(x1-x2^2),
                                    ~sqrt(exp(2*x1+x2^2)*(exp(x2^2)-1))),x,varx,ses=F)},
         "binorm.sca"={
           pars=c(x[1:4],exp(x[5])/(1+exp(x[5])))
           names=c("Mode1(mesh1)","Std dev.1(mesh1)",
                   "Mode2(mesh1)","Std dev.2(mesh1)","P(mode1)")
           varpars=msm::deltamethod(list(~x1,~x2,~x3,~x4,~exp(x5)/(1+exp(x5))),
                               x,varx,ses=F)},
         "bilognorm"={
           pars=c(exp(x[1]-x[2]^2),sqrt(exp(2*x[1]+x[2]^2)*(exp(x[2]^2)-1)),
                  exp(x[3]-x[4]^2),sqrt(exp(2*x[3]+x[4]^2)*(exp(x[4]^2)-1)),
                  exp(x[5])/(1+exp(x[5])))
           names=c("Mode1(mesh1)","Std dev.1(mesh1)",
                   "Mode2(mesh1)","Std dev.2(mesh1)","P(mode1)")
           varpars=msm::deltamethod(
             list(~exp(x1-x2^2),~sqrt(exp(2*x1+x2^2)*(exp(x2^2)-1)),
                  ~exp(x3-x4^2),~sqrt(exp(2*x3+x4^2)*(exp(x4^2)-1)),
                  ~exp(x5)/(1+exp(x5))),x,varx,ses=F)},
         "tt.logistic"={
           pars=c(-x[1]/x[2],2*(log(3))/x[2],exp(x[3])/(1+exp(x[3])))
           names=c("L50","SR","p")
           varpars=msm::deltamethod(list(~-x1/x2,~2*log(3)/x2,~exp(x3)/(1+exp(x3))),
                               x,varx,ses=F)},
         stop(paste("\n",fit$rtype, "not recognised, possible curve types are \n",
                    "\"norm.loc\", \"norm.sca\", \"lognorm\" \n",
                    "\"binorm.sca\", \"bilognorm\", and \"tt.logistic\""))
  )#End of switch
  estimates=cbind(pars,sqrt(diag(varpars)))
  colnames(estimates)=c("par","s.e.")
  rownames(estimates)=names
  return(estimates)
}

#' @title Plot stuff
#'
#' @description XXX
#'
#' @export
#'
#' @param fit XXX
#' @param Meshsize XXX
#' @param plotlens XXX
#' @param standardize XXX
#' @param ... XXX
PlotCurves <- function(fit,Meshsize=NULL,plotlens=NULL,standardize=TRUE,...) {
  r=selncurves(fit$rtype) #Get selection curve function
  if(is.null(plotlens)) plotlens=fit$Data[,1]
  if(is.null(Meshsize)) Meshsize=fit$Meshsize
  plot.title=switch(fit$rtype,
                    "norm.loc"="Normal (common spread)",
                    "norm.sca"="Normal",
                    "lognorm"="Lognormal",
                    "binorm.sca"="Bi-normal",
                    "bilognorm"="Bi-lognormal",
                    "tt.logistic"="Control and logistic","")
  rmatrix=outer(plotlens,Meshsize,r,fit$par)
  rmatrix=t(t(rmatrix)*fit$rel.power)
  if(standardize) rmatrix=rmatrix/max(rmatrix)
  matplot(plotlens,rmatrix,type="l",las=1,ylim=c(0,1),
          xlab="Length (cm)",ylab="Relative retention",...)
  #abline(h=seq(0,1,0.25),lty=3)
  lenrmatrix=cbind(plotlens,rmatrix)
  colnames(lenrmatrix)=c("Length",Meshsize)
  invisible(lenrmatrix) }

#' @title Summarise stuff
#'
#' @description XXX
#'
#' @export
#'
#' @param fit XXX
#' @param label XXX
#' @param xlabel XXX
#' @param ylabel XXX
#' @param cex XXX
Summary <- function(fit,label="Deviance residuals",
                 xlabel="Length (cm)",ylabel="Mesh size (cm)",cex=1) {
  r=selncurves(fit$rtype) #Get selection curve function
  lens=fit$Data[,1]; nlens=length(lens)
  Meshsize=fit$Meshsize; nmeshes=length(Meshsize)
  O=fit$Data[,-1]; #Matrix of observed counts
  rmatrix=outer(lens,Meshsize,r,fit$par)
  rmatrix[is.na(O)]=NA #No fitted retention for missing meshsizes
  rmatrix=t(t(rmatrix)*fit$rel.power)
  phi=rmatrix/apply(rmatrix,1,sum,na.rm=TRUE)
  E=apply(O,1,sum,na.rm=TRUE)*phi #Matrix of expected counts
  Pearson.resids=(O-E)/sqrt(E)
  Pearson.chisq=sum(Pearson.resids^2,na.rm=TRUE)
  wk=O*log(O/E); wk[is.na(wk)]=0
  Dev.resids=sign(O-E)*sqrt(2*(E-O+wk))
  Deviance=sum(Dev.resids^2,na.rm=TRUE)
  full.l=sum(-O+O*log(O),na.rm=TRUE)
  null.E=matrix(apply(O,1,mean,na.rm=TRUE),nrow=nlens,ncol=nmeshes)
  null.l=sum(-null.E+O*log(null.E),na.rm=TRUE)
  model.l=sum(-E+O*log(E),na.rm=TRUE)
  NonZeroDat=O[apply(O,1,sum,na.rm=TRUE)>0,]
  d.o.f.=nrow(NonZeroDat)*(nmeshes-1)-length(fit$par)-sum(is.na(NonZeroDat))
  out=rbind(null.l,model.l,full.l,Deviance,Pearson.chisq,d.o.f.)
  AreLensUnique=(length(lens)==length(unique(lens)))
  if(nmeshes>2&AreLensUnique) {
    plot(1,1,xlim=range(lens),xlab=xlabel,ylab=ylabel,
         ylim=range(Meshsize)+(cex/50)*c(-1,1)*(max(Meshsize)-min(Meshsize)),
         yaxt="n",type="n",main=label)
    axis(2,Meshsize,Meshsize,las=1)
    for(i in 1:nlens)
      for(j in 1:nmeshes)
        points(lens[i],Meshsize[j],pch=ifelse(Dev.resids[i,j]>0,16,1),
               cex=3*abs(Dev.resids[i,j])*cex/(abs(max(Dev.resids)))) }
  else
    if(nmeshes==2) {
      Dev.resids.len=sign(Dev.resids[,2])*sqrt(apply(Dev.resids^2,1,sum))
      plot(lens,Dev.resids.len,type=ifelse(AreLensUnique,"h","p"),las=1,
           main=label,xlab=xlabel,ylab=ylabel,cex=cex)
      abline(h=0) }
  return(out)
}


#Curves to be added include:
#tt.richards, for richards fit to trouser trawl data
#gamma, for net selectivity.

#' @title Selection curves
#'
#' @description XXX
#'
#' @export
#'
#' @param rtype XXX
selncurves=function(rtype) {
  switch(rtype,
         "norm.loc"={
           r=function(lens,Meshsize,th) {
             relsize=Meshsize/Meshsize[1]
             seln=exp(-(lens-th[1]*relsize)^2/(2*th[2]^2))
             return(seln) } },
         "norm.sca"={
           r=function(lens,Meshsize,th) {
             relsize=Meshsize/Meshsize[1]
             seln=exp(-(lens-th[1]*relsize)^2/(2*th[2]^2*relsize^2))
             return(seln) } },
         "lognorm"={
           r=function(lens,Meshsize,th) {
             relsize=Meshsize/Meshsize[1]
             seln=(relsize/lens)*exp(th[1]-th[2]^2/2)
             seln=seln*exp( -(log(lens)-th[1]-log(relsize))^2/(2*th[2]^2) )
             return(seln) } },
         "binorm.sca"={
           r=function(lens,Meshsize,th) {
             relsize=Meshsize/Meshsize[1]
             seln1=exp(-(lens-th[1]*relsize)^2/(2*th[2]^2*relsize^2))
             seln2=exp(-(lens-th[3]*relsize)^2/(2*th[4]^2*relsize^2))
             p=exp(th[5])/(1+exp(th[5])) #i.e., th[5]=logit(p)
             seln=p*seln1+(1-p)*seln2
             return(seln) } },
         "bilognorm"={
           r=function(lens,Meshsize,th) {
             relsize=Meshsize/Meshsize[1]
             seln1=(relsize/lens)*exp(th[1]-th[2]^2/2)
             seln1=seln1*exp( -(log(lens)-th[1]-log(relsize))^2/(2*th[2]^2) )
             seln2=(relsize/lens)*exp(th[3]-th[4]^2/2)
             seln2=seln2*exp( -(log(lens)-th[3]-log(relsize))^2/(2*th[4]^2) )
             p=exp(th[5])/(1+exp(th[5])) #i.e., th[5]=logit(p)
             seln=p*seln1+(1-p)*seln2
             return(seln) } },
         "tt.logistic"={
           r=function(lens,Meshsize,th) {
             control=(Meshsize==Meshsize[1])
             p=exp(th[3])/(1+exp(th[3])) #i.e., th[3]=logit(p)
             wk=exp(th[1]+th[2]*lens)
             lselect=wk/(1+wk)
             seln=(1-p)*control+p*lselect*(1-control)
             return(seln) } },
         stop(paste("\n",rtype, "not recognised, possible curve types are \n",
                    "\"norm.loc\", \"norm.sca\", \"lognorm\" \n",
                    "\"binorm.sca\", \"bilognorm\", and \"tt.logistic\""))
  )#End of switch
  return(r) }
