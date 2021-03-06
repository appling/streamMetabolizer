% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calc_velocity.R
\name{calc_velocity}
\alias{calc_velocity}
\title{Estimate velocity from discharge and hydraulic geometry coefficients}
\usage{
calc_velocity(Q, k = u(0.194, "m s^-1"), m = u(0.285, ""))
}
\arguments{
\item{Q}{discharge (m^3 s^-1)}

\item{k}{coefficient representing velocity at unit discharge (usually m/s; e in Raymond et al.)}

\item{m}{exponent in velocity-discharge relation (unitless; f in Raymond et al.)}
}
\value{
v (= V = U), stream flow velcoity, in the same units as k
}
\description{
Uses the relationship \eqn{U=k*Q^m} (parameter names and definitions as in 
Leopold and Maddock, 1953; default values for k and m as in Raymond et al. 
2012)
}
\examples{
Qs <- seq(1,9,2)
calc_velocity(Q=Qs)
calc_velocity(Q=Qs, k=0.4)
library(unitted)
calc_velocity(Q=u(Qs, "m^3 s^-1"), m=u(40))
calc_velocity(Q=u(Qs, "m^3 s^-1"), k=u(0.36, "m s^-1"))
}
\references{
Raymond, Peter A., Christopher J. Zappa, David Butman, Thomas L. 
  Bott, Jody Potter, Patrick Mulholland, Andrew E. Laursen, William H. 
  McDowell, and Denis Newbold. \emph{Scaling the gas transfer velocity and 
  hydraulic geometry in streams and small rivers}. Limnology & Oceanography: 
  Fluids & Environments 2 (2012): 41-53.
  
  Leopold, L.B., and Thomas Maddock Jr. \emph{The Hydraulic Geometry of
  Stream Channels and Some Physiographic Implications}. Report. Professional
  Paper, 1953. USGS Publications Warehouse.
  http://pubs.er.usgs.gov/publication/pp252.
}

