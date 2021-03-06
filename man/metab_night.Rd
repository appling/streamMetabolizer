% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/metab_night.R
\name{metab_night}
\alias{metab_night}
\title{Nighttime regression for K estimation}
\usage{
metab_night(specs = specs(mm_name("night")), data = mm_data(solar.time,
  DO.obs, DO.sat, depth, temp.water, light), data_daily = mm_data(NULL),
  info = NULL)
}
\arguments{
\item{specs}{a list of model specifications and parameters for a model. 
Although this may be specified manually (it's just a list), it is easier
and safer to use \code{\link{specs}} to generate the list, because the set
of required parameters and their defaults depends on the model given in the
\code{model_name} argument to \code{specs}. The help file for 
\code{\link{specs}} lists the necessary parameters, describes them in 
detail, and gives default values.}

\item{data}{data.frame of input data at the temporal resolution of raw 
observations (unit-value). Columns must have the same names, units, and 
format as the default. See the \strong{'Formatting \code{data}'} section 
below for a full description.}

\item{data_daily}{data.frame containing inputs with a daily timestep. See the
\strong{'Formatting \code{data_daily}'} section below for a full 
description.}

\item{info}{any information, in any format, that you would like to store 
within the metab_model object}
}
\value{
A metab_night object containing the fitted model. This object can be 
  inspected with the functions in the \code{\link{metab_model_interface}}.
}
\description{
Fits a model to estimate K from nighttime input data on DO, temperature, 
light, etc. The default day start & end are 12 noon on the preceding to 
present day; the algorithm then filters the data to just those time points 
for which light is very low.
}
\examples{
dat <- data_metab('3', day_start=12, day_end=35)
mm <- metab_night(data=dat)
predict_metab(mm)
\dontrun{
plot_DO_preds(predict_DO(mm))
}
}
\author{
Alison Appling, Maite Arroita, Bob Hall
}
\seealso{
Other metab_model: \code{\link{metab_Kmodel}},
  \code{\link{metab_bayes}}, \code{\link{metab_mle}},
  \code{\link{metab_sim}}
}

