% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/standardFUNs.R
\name{rhFUN}
\alias{rhFUN}
\title{Relative humidity from temperature and water vapor pressure}
\usage{
rhFUN(temp, vapor)
}
\arguments{
\item{temp}{numeric. temperature in celsius}

\item{vapor}{numeric. water vapor pressure in milibars}
}
\value{
a vector of relative humidity values, in decimal.
}
\description{
\code{rhFUN}  Calculates relative humidity from air temperature in Celsius and water vapor pressure in milibars
}
\examples{

rhFUN(25, 20)

rhFUN(25:40, 20:35)

}
