closedCapM0 <-
function(CH, ci = 0.95, ciType=c("normal", "MARK")) {
  # CH is a 1/0 capture history matrix, animals x occasions, OR
  #  a vector of capture frequencies of length equal to the number
  #  of occasions - trailing zeros are required.
  # ci is the required confidence interval
  # ciType is the method of calculation
  
  if (is.matrix(CH) || is.data.frame(CH)) {
    n.occ <- ncol(CH)
    freq <- tabulate(rowSums(CH), nbins=n.occ)
  } else {
    freq <- round(CH)
    n.occ <- length(freq)
  }
  crit <- fixCI(ci)
  ciType <- match.arg(ciType)

  N.cap <- sum(freq)  # Number of individual animals captured
  n.snap <- sum(freq * (1:length(freq))) # Total number of capture events
  beta.mat <- matrix(NA_real_, 2, 4) # objects to hold output
  colnames(beta.mat) <- c("est", "SE", "lowCI", "uppCI")
  rownames(beta.mat) <- c("Nhat", "phat")
  varcov <- NULL
  logLik <- NA_real_
#  if(sum(freq[-1]) > 1) {  # Need recaptures
  if(sum(freq[-1]) > 0) {  # Need recaptures
    nll <- function(params) {
      N <- min(exp(params[1]) + N.cap, 1e+300, .Machine$double.xmax)
      p <- plogis(params[2])
      tmp <- lgamma(N + 1) - lgamma(N - N.cap + 1) + n.snap*log(p) +
            (N*n.occ - n.snap)*log(1-p)
      return(min(-tmp, .Machine$double.xmax))
    }
    params <- c(log(5), 0)
    res <- nlm(nll, params, hessian=TRUE, iterlim=1000)
    if(res$code > 2)   # exit code 1 or 2 is ok.
      warning(paste("Convergence may not have been reached (code", res$code, ")"))
    beta.mat[,1] <- res$estimate
    # varcov0 <- try(solve(res$hessian), silent=TRUE)
    varcov0 <- try(chol2inv(chol(res$hessian)), silent=TRUE)
    # if (!inherits(varcov0, "try-error") && all(diag(varcov0) > 0)) {
    if (!inherits(varcov0, "try-error")) {
      varcov <- varcov0
      beta.mat[, 2] <- suppressWarnings(sqrt(diag(varcov)))
      beta.mat[, 3:4] <- sweep(outer(beta.mat[, 2], crit), 1, res$estimate, "+")
      logLik <- -res$minimum
    }
  }
  if(ciType == "normal") {
    Nhat <- exp(beta.mat[1, -2]) + N.cap
  } else {
    Nhat <- getMARKci(beta.mat[1, 1], beta.mat[1, 2], ci) + N.cap
  }

  out <- list(call = match.call(),
          beta = beta.mat,
          beta.vcv = varcov,
          real = rbind(Nhat, plogis(beta.mat[2, -2, drop=FALSE])),
          logLik = c(logLik=logLik, df=2, nobs=N.cap * n.occ))
  class(out) <- c("wiqid", "list")
  return(out)
}