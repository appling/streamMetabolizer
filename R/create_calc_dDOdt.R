#' Create a function that generates a 1-day timeseries of DO.mod
#'
#' Creates a closure that bundles data and helper functions into a single
#' function that returns dDOdt in gO2 m^-3 timestep^-1 for any given time t.
#'
#' @param data data.frame as in \code{\link{metab}}, except that data must
#'   contain exactly one date worth of inputs (~24 hours according to
#'   \code{\link{specs}$day_start} and \code{\link{specs}$day_end}).
#' @inheritParams mm_name
#' @return a function that accepts args \code{t} (the time in 0:(n-1) where n is
#'   the number of timesteps), \code{DO.mod.t} (the value of DO.mod at time t in
#'   gO2 m^-3), and \code{metab} (a list of metabolism parameters; to see which
#'   parameters should be included in this list, create \code{dDOdt} with this
#'   function and then call \code{environment(dDOdt)$metab.needs})
#' @import dplyr
#' @import unitted
#' @export
#' @examples
#' \dontrun{
#' data <- data_metab('1','30')
#' dDOdt.obs <- diff(data$DO.obs)
#' preds.init <- as.list(dplyr::select(
#'   predict_metab(metab(specs(mm_name('mle', ode_method='Euler')), data=data)),
#'   GPP.daily=GPP, ER.daily=ER, K600.daily=K600))
#' DOtime <- data$solar.time
#' dDOtime <- data$solar.time[-nrow(data)] + (data$solar.time[2] - data$solar.time[1])/2
#'
#' # args to create_calc_dDOdt determine which values are needed in metab.pars
#' dDOdt <- create_calc_dDOdt(data, ode_method='pairmeans', GPP_fun='satlight',
#'   ER_fun='q10temp', deficit_src='DO_mod')
#' names(formals(dDOdt)) # always the same: args to pass to dDOdt()
#' environment(dDOdt)$metab.needs # get the names to be included in metab.pars
#' dDOdt(t=28, state=c(DO.mod=data$DO.obs[28]),
#'   metab.pars=list(Pmax=0.2, alpha=0.01, ER20=-0.05, K600.daily=3))$dDOdt
#'
#' # different required args; try in a timeseries
#' dDOdt <- create_calc_dDOdt(data, ode_method='Euler', GPP_fun='linlight',
#'   ER_fun='constant', deficit_src='DO_mod')
#' environment(dDOdt)$metab.needs # get the names to be included in metab
#' # approximate dDOdt and DO using DO.obs for DO deficits & Eulerian integration
#' dDOdt.mod.m <- sapply(1:47, function(t) dDOdt(t=t, state=c(DO.mod=data$DO.obs[t]),
#'   metab.pars=list(GPP.daily=2, ER.daily=-1.4, K600.daily=21))$dDOdt)
#' DO.mod.m <- cumsum(c(data$DO.obs[1], dDOdt.mod))
#' plot(x=DOtime, y=data$DO.obs)
#' lines(x=DOtime, y=DO.mod.m, type='l', col='purple')
#' plot(x=dDOtime, y=dDOdt.obs)
#' lines(x=dDOtime, y=dDOdt.mod.m, type='l', col='blue')
#'
#' # compute & plot a full timeseries with ode() integration
#' dDOdt <- create_calc_dDOdt(data, ode_method='Euler', GPP_fun='linlight',
#'   ER_fun='constant', deficit_src='DO_mod')
#' DO.mod.o <- ode(
#'   y=c(DO.mod=data$DO.obs[1]),
#'   parms=list(GPP.daily=2, ER.daily=-1.4, K600.daily=21),
#'   times=1:nrow(data), func=dDOdt, method='euler')[,'DO.mod']
#' plot(x=DOtime, y=data$DO.obs)
#' lines(x=DOtime, y=DO.mod.m, type='l', col='purple')
#' lines(x=DOtime, y=DO.mod.o, type='l', col='red')
#' dDOdt.mod.o <- diff(DO.mod)
#' plot(x=dDOtime, y=dDOdt.obs)
#' lines(x=dDOtime, y=dDOdt.mod.m, type='l', col='blue')
#' lines(x=dDOtime, y=dDOdt.mod.o, type='l', col='forestgreen')
#'
#' # see how values of metab.pars affect the dDOdt predictions
#' library(dplyr); library(ggplot2); library(tidyr)
#' dDOdt <- create_calc_dDOdt(data, ode_method='Euler', GPP_fun='linlight',
#'   ER_fun='constant', deficit_src='DO_mod')
#' apply_dDOdt <- function(t, GPP.daily, ER.daily, K600.daily) {
#'   dDOdt(t=t, state=c(DO.mod=data$DO.obs[t]),
#'     metab.pars=list(GPP.daily=GPP.daily, ER.daily=ER.daily, K600.daily=K600.daily)
#'   )$dDOdt
#' }
#' dDO.preds <- mutate(
#'   data,
#'   dDO.preds.base = sapply(1:nrow(data), apply_dDOdt, 3, -5, 15),
#'   dDO.preds.dblGPP = sapply(1:nrow(data), apply_dDOdt, 6, -5, 15),
#'   dDO.preds.dblER = sapply(1:nrow(data), apply_dDOdt, 3, -10, 15),
#'   dDO.preds.dblK = sapply(1:nrow(data), apply_dDOdt, 3, -5, 30))
#' dDO.preds %>%
#'   select(solar.time, starts_with('dDO.preds')) %>%
#'   gather(key=dDO.series, value=dDO.dt, starts_with('dDO.preds')) %>%
#'   ggplot(aes(x=solar.time, y=dDO.dt, color=dDO.series)) + geom_line()
#' }
create_calc_dDOdt <- function(data, ode_method, GPP_fun, ER_fun, deficit_src) {

  # simplify time indexing. we've guaranteed in mm_model_by_ply that the
  # timesteps are regular
  data$t <- seq_len(nrow(data))

  # define the forcing (temp.water, light, DO.sat, etc.) interpolations and
  # other inputs to include in the dDOdt() closure
  switch(
    ode_method,
    # the simplest methods only require values at integer values of t
    Euler=, trapezoid=, pairmeans={
      DO.obs <- function(t) data[t, 'DO.obs']
      DO.sat <- function(t) data[t, 'DO.sat']
      depth <- function(t) data[t, 'depth']
      temp.water <- function(t) data[t, 'temp.water']
      light <- function(t) data[t, 'light']
      data$KO2.conv <- convert_k600_to_kGAS(k600=1, temperature=data[, 'temp.water'], gas="O2")
      KO2.conv <- function(t) data[t, 'KO2.conv']
    },
    { # other methods require functions that can be applied at non-integer values of t
      DO.obs <- approxfun(data$t, data$DO.obs, rule=2)
      DO.sat <- approxfun(data$t, data$DO.sat, rule=2)
      depth <- approxfun(data$t, data$depth, rule=2)
      temp.water <- approxfun(data$t, data$temp.water, rule=2)
      light <- approxfun(data$t, data$light, rule=2)
      KO2.conv <- function(t) convert_k600_to_kGAS(k600=1, temperature=temp.water(t), gas="O2")
    }
  )
  timestep.days <- suppressWarnings(mean(as.numeric(diff(unitted::v(data$solar.time)), units="days"), na.rm=TRUE))

  # collect the required metab.pars parameter names in a vector called metab.needs
  metab.needs <- c()

  # GPP: instantaneous gross primary production at time t in gO2 m^-2 d^-1
  GPP <- switch(
    GPP_fun,
    linlight=(function(){
      # normalize light by the sum of light in the first 24 hours of the time window
      mean.light <- with(
        list(in.solar.day = data$solar.time < (data$solar.time[1] + as.difftime(1, units='days'))),
        mean(data$light[in.solar.day]))
      metab.needs <<- c(metab.needs, 'GPP.daily')
      function(t, metab.pars) with(metab.pars, {
        GPP.daily * light(t) / mean.light
      })
    })(),
    satlight=(function(){
      metab.needs <<- c(metab.needs, c('Pmax','alpha'))
      function(t, metab.pars) with(metab.pars, {
        Pmax * tanh(alpha * light(t) / Pmax)
      })
    })(),
    satlightq10temp=(function(){
      metab.needs <<- c(metab.needs, c('Pmax','alpha'))
      function(t, metab.pars) with(metab.pars, {
        Pmax * tanh(alpha * light(t) / Pmax) * 1.036 ^ (temp.water(t) - 20)
      })
    })()
  )

  # ER: instantaneous ecosystem respiration at time t in d^-1
  ER <- switch(
    ER_fun,
    constant=(function(){
      metab.needs <<- c(metab.needs, 'ER.daily')
      function(t, metab.pars) with(metab.pars, {
        ER.daily
      })
    })(),
    q10temp=(function(){
      # song_methods_2016 cite Gulliver & Stefan 1984; Parkhill & Gulliver 1999
      metab.needs <<- c(metab.needs, 'ER20')
      function(t, metab.pars) with(metab.pars, {
        ER20 * 1.045 ^ (temp.water(t) - 20)
      })
    })()
  )

  # D: instantaneous reaeration rate at time t in gO2 m^-3 d^-1
  D <- switch(
    deficit_src,
    DO_obs=(function(){
      metab.needs <<- c(metab.needs, 'K600.daily')
      function(t, DO.mod.t, metab.pars) with(metab.pars, {
        K600.daily * KO2.conv(t) * (DO.sat(t) - DO.obs(t))
      })
    })(),
    DO_mod=(function(){
      metab.needs <<- c(metab.needs, 'K600.daily')
      function(t, DO.mod.t, metab.pars) with(metab.pars, {
        K600.daily * KO2.conv(t) * (DO.sat(t) - DO.mod.t)
      })
    })()
  )

  # dDOdt: instantaneous rate of change in DO at time t in gO2 m^-3 timestep^-1
  dDOdt <- switch(
    ode_method,
    ### 'pairmeans' and 'trapezoid' are identical and are the analytical
    ### solution to a trapezoid rule with this starting point:
    # DO.mod[t+1] =
    #   DO.mod[t]
    # + (GPP.daily * (frac.GPP[t]+frac.GPP[t+1])/2) / (depth[t]+depth[t+1])/2
    # + (ER.daily * (frac.ER[t]+frac.ER[t+1])/2) / (depth[t]+depth[t+1])/2
    # + k.O2.daily * (frac.k.O2[t](DO.sat[t] - DO.mod[t]) + frac.k.O2[t+1](DO.sat[t+1] - DO.mod[t+1]))/2
    ### and this solution:
    # DO.mod[t+1] - DO.mod[t] =
    #   (- DO.mod[t] * k.O2.daily * (frac.k.O2[t]+frac.k.O2[t+1])/2
    #    + (GPP.daily * (frac.GPP[t]+frac.GPP[t+1])/2) / (depth[t]+depth[t+1])/2
    #    + (ER.daily * (frac.ER[t]+frac.ER[t+1])/2) / (depth[t]+depth[t+1])/2
    #    + k.O2.daily * (frac.k.O2[t]*DO.sat[t] + frac.k.O2[t+1]*DO.sat[t+1])/2 )
    # / (1 + k.O2.daily*frac.k.O2[t+1]/2)
    trapezoid=, pairmeans={
      function(t, state, metab.pars){
        # pm = pairmeans
        pm <- function(fun, ...) mean(fun(c(t, t+1), ...))
        with(c(state, metab.pars), {
          list(
            dDOdt=(
              - DO.mod * K600.daily * pm(KO2.conv) +
                pm(GPP, metab.pars)/pm(depth) +
                pm(ER, metab.pars)/pm(depth) +
                K600.daily * (KO2.conv(t)*DO.sat(t) + KO2.conv(t+1)*DO.sat(t+1))/2
            ) * timestep.days / (1 + timestep.days * K600.daily * KO2.conv(t+1)/2))
        })
      }
    },
    # all other methods use a straightforward calculation of dDOdt at values of
    # t and DO.mod.t as requested by the ODE solver
    function(t, state, metab.pars){
      with(c(state, metab.pars), {
        list(
          dDOdt=(
            GPP(t, metab.pars)/depth(t) +
              ER(t, metab.pars)/depth(t) +
              D(t, DO.mod, metab.pars)) *
            timestep.days)
      })
    }
  )

  # return the closure, which wraps up the final dDOdt code, light(), DO.sat(),
  # depth(), GPP(), ER(), D(), and anything else defined within create_calc_dDOdt
  # into one bundle
  dDOdt
}
