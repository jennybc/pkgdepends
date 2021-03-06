% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/solve.R
\name{remotes__create_lp_problem}
\alias{remotes__create_lp_problem}
\title{Create the LP problem that solves the installation}
\usage{
remotes__create_lp_problem(self, private, pkgs)
}
\arguments{
\item{pkgs}{Resolution data frame, that contains the locally installed
packages as well.}
}
\value{
An S3 object for a linear (integer) optimization problem,
to be used with \code{\link[lpSolve:lp]{lpSolve::lp()}} (eventually).
}
\description{
Each row in the resolution data frame is an installation candidate.
Each row corresponds to a binary variable \eqn{p_i}{p[i]}, which is
1 if that package will be installed.
}
\details{
The constraints we have:
\enumerate{
\item For each package \eqn{k}, we need exactly one candidate to be
installed: \eqn{\sum_{i\in k} p_i=1}{sum(p[i], i in k) = 1}.
\item All dependency versions must be satisfied.
\item For all packages, the selected package must satisfy all refs
for that package.
}

And we want to minimize package downloads and package compilation:
4. If a package is already installed, prefer the installed version,
if possible.
5. If a package is available as a binary, prefer the binary version,
if possible.
6. Can't install failed resolutions.
We do this by assigning cost 0 to installed versions, cost 1 to
binary packages, and cost 2 to source packages. Then we minimize the
total cost, while satisfying the constraints.
}
\keyword{internal}
