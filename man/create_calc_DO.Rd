% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/create_calc_DO.R
\name{create_calc_DO}
\alias{create_calc_DO}
\title{Create a function to compute the numerical integration of a dDOdt function}
\usage{
create_calc_DO(calc_dDOdt, err_obs_iid = FALSE, err_proc_iid = FALSE,
  ode_method = environment(dDOdt)$ode_method)
}
\arguments{
\item{calc_dDOdt}{a function as from \code{create_calc_dDOdt}}

\item{err_obs_iid}{logical. Should IID observation error be included? If not,
the model will be fit to the differences in successive DO measurements, 
rather than to the DO measurements themselves.}

\item{err_proc_iid}{logical. Should IID process error be included?}

\item{ode_method}{The method to use in solving the ordinary differential 
equation for DO. Euler: dDOdt from t=1 to t=2 is solely a function of GPP, 
ER, DO, etc. at t=1. pairmeans: dDOdt from t=1 to t=2 is a function of the 
mean values of GPP, ER, etc. across t=1 and t=2.}
}
\value{
a function that will return a negative log likelihood of the data
  given a set of metab.pars
}
\description{
Create a function to compute the numerical integration of a dDOdt function
}
\examples{
\dontrun{
# prepare data for examples
data <- data_metab('3','30')[97:144,]
preds.init <- as.list(dplyr::select(
  predict_metab(metab(specs(mm_name('mle', ode_method='pairmeans')), data=data)),
  GPP.daily=GPP, ER.daily=ER, K600.daily=K600))
DOtime <- data$solar.time
dDOtime <- data$solar.time[-nrow(data)] + (data$solar.time[2] - data$solar.time[1])/2

# integration of dDOdt by Euler, trapezoid, rk4, and lsoda methods
plot(x=DOtime, y=data$DO.obs, pch=3, cex=0.6)
# euler
dDOdt <- create_calc_dDOdt(data, ode_method='Euler', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='Euler')
DO.mod.euler <- DO(metab.pars=preds.init)
lines(x=DOtime, y=DO.mod.euler, type='l', col='chartreuse3')
# trapezoid=pairmeans
dDOdt <- create_calc_dDOdt(data, ode_method='trapezoid', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='trapezoid')
DO.mod.trap <- DO(metab.pars=preds.init)
lines(x=DOtime, y=DO.mod.trap, type='l', col='gold')
# lsoda
dDOdt <- create_calc_dDOdt(data, ode_method='lsoda', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='lsoda')
DO.mod <- DO(metab.pars=preds.init)
lines(x=DOtime, y=DO.mod, type='l', col='navy')
# rk4
dDOdt <- create_calc_dDOdt(data, ode_method='rk4', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='rk4')
DO.mod <- DO(metab.pars=preds.init)
lines(x=DOtime, y=DO.mod, type='l', col='magenta')

# show that method='euler' really is Euler by several integration implementations
plot(x=DOtime, y=data$DO.obs, col='black', pch=3, cex=0.6)
# dDOdt
dDOdt <- create_calc_dDOdt(data, ode_method='Euler', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO.mod.dDOdt <- data$DO.obs[1]
for(t in 2:nrow(data)) { DO.mod.dDOdt[t] <-
  DO.mod.dDOdt[t-1] + dDOdt(t-1, c(DO.mod=DO.mod.dDOdt[t-1]), preds.init)$dDOdt }
lines(x=DOtime, y=DO.mod.dDOdt, col='purple')
# ode
DO.mod.ode <- deSolve::ode(y=c(DO.mod=data$DO.obs[1]), parms=preds.init,
  times=1:nrow(data), func=dDOdt, method='euler')[,'DO.mod']
lines(x=DOtime, y=DO.mod.ode, col='blue')
# DO
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='Euler')
DO.mod.DO <- DO(preds.init)
lines(x=DOtime, y=DO.mod.DO, col='chartreuse3')

# show that method='trapezoid' really is pairmeans by several implementations
plot(x=DOtime, y=data$DO.obs, col='black', pch=3, cex=0.6)
# dDOdt
dDOdt <- create_calc_dDOdt(data, ode_method='trapezoid', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO.mod.dDOdt <- data$DO.obs[1]
for(t in 2:nrow(data)) { DO.mod.dDOdt[t] <-
  DO.mod.dDOdt[t-1] + dDOdt(t-1, c(DO.mod=DO.mod.dDOdt[t-1]), preds.init)$dDOdt }
lines(x=DOtime, y=DO.mod.dDOdt, col='purple')
# DO
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='trapezoid')
DO.mod.pm.DO <- DO(preds.init)
lines(x=DOtime, y=DO.mod.pm.DO, col='forestgreen', lty=3)
# rk2 should be similar, but not identical, to pairmeans
dDOdt <- create_calc_dDOdt(data, ode_method='rk2', GPP_fun='linlight',
  ER_fun='constant', deficit_src='DO_mod')
DO <- create_calc_DO(dDOdt, err_obs_iid=TRUE, ode_method='rk2')
DO.mod.pm.rk2 <- DO(preds.init)
lines(x=DOtime, y=DO.mod.pm.rk2, col='red', lty=4)
}
}

