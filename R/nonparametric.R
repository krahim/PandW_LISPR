# The following functions are contained in nonparametric.R
# These functions are loosley based on the lisp code provided with SAPA
# http://lib.stat.cmu.edu/sapaclisp/
# http://lib.stat.cmu.edu/sapaclisp/nonparametric.lisp

# ;;; functions to compute nonparametric spectral estimates ...

# periodogram <- function(timeSeries,
#                   centreData=T,
#                   nNonZeroFreqs="halfNextPowerOf2",
#                   returnEstFor0FreqP=F,
#                   samplingTime=1.0,
#                   sdfTransformation=convertTodB,
#                   returnFourierCoef=F)

# directSpectralEst <- function(   timeSeries,
#                                 centreData=T,
#                                 nNonZeroFreqs="halfNextPowerOf2",
#                                 returnEstFor0FreqP=F,
#                                 samplingTime=1.0,
#                                 dataTaper=NULL,
#                                 dataTaperParameter=NULL,
#                                 recentreAfterTaperingP=T,
#                                 restorePowerOptionP=T,
#                                 sdfTransformation=convertTodB)

# ;;; functions concerning specific lag windows ...
#BartlettLagWindow <- function(tau, m)
#BartlettMtoBandwidth <- function(m, samplingTime=1.0)
#BartlettBandwidthtoM <- function(B_W, samplingTime=1.0)
#BartlettNandMtoDF <- function(N, m, C_h=1.0)
#DaniellLagWindow <- function(tau, m)


#          bartlett-lag-window
#          bartlett-m->bandwidth
#          bartlett-bandwidth->m
#          bartlett-N-m->degrees-of-freedom
#          daniell-lag-window
#          daniell-m->bandwidth
#          daniell-bandwidth->m
#          daniell-N-m->degrees-of-freedom
#          parzen-lag-window
#          parzen-m->bandwidth
#          parzen-bandwidth->m
#          parzen-N-m->degrees-of-freedom
#          papoulis-lag-window
#          papoulis-m->bandwidth
#          papoulis-bandwidth->m
#          papoulis-N-m->degrees-of-freedom
#          ))

# helper functions considered dirty laundry in SAPA code
# getNDFT <- function(nNonZeroFreq, sampleSize)

# getNFreqs <- function(nNonZeroFreq, sampleSize, returnEstFor0FreqP)
################################################################################

# Requires:
##source("~/PWLisp/basicStatistics.R");
##source("~/PWLisp/tapers.R");
##source("~/PWLisp/utilities.R");
##source("~/PWLisp/acvs.R");

################################################################################

getNDFT <- function(nNonZeroFreq, sampleSize) {
   if(is.character(nNonZeroFreq)) {
      return (switch(tolower(nNonZeroFreq),
                  "halfnextpowerof2" =  nextPowerOf2(sampleSize),
                  "nextpowerof2" =  2*nextPowerOf2(sampleSize),
                  "twicenextpowerof2" =  4*nextPowerOf2(sampleSize),
                  "fourier" = sampleSize));
   }
   if(is.numeric(nNonZeroFreq) &&
                  powerOf2(nNonZeroFreq) &&
                  2*nNonZeroFreq >= sampleSize) {
      return(2*nNonZeroFreq);
   }
   return();
}

getNFreqs <- function(nNonZeroFreq, sampleSize, returnEstFor0FreqP) {
   if(!is.logical(returnEstFor0FreqP)) {
      return();
   }
   if(returnEstFor0FreqP) {
      return(1+ getNDFT(nNonZeroFreq, sampleSize) %/% 2);
   }
   return(getNDFT(nNonZeroFreq, sampleSize) %/% 2);
}

#similar to the lisp SAPA code
periodogram <- function(timeSeries,
                   centreData=TRUE,
                   nNonZeroFreqs="halfNextPowerOf2",
                   returnEstFor0FreqP=FALSE,
                   samplingTime=1.0,
                   sdfTransformation=convertTodB,
                   returnFourierCoef=FALSE) {#,
                   #freqTransformation=NULL) {
   sampleSize <- length(timeSeries);
   nFreqs <- getNFreqs(nNonZeroFreqs, sampleSize, returnEstFor0FreqP);
   nDFT <- getNDFT(nNonZeroFreqs, sampleSize);
   offSet <- if(returnEstFor0FreqP) 0 else 1;
   fiddleFactorSDF <- samplingTime / as.double(sampleSize);
   fiddleFactorFreq <- 1 / as.double(nDFT * samplingTime);
   FourierCoef <- NULL;
   sdf <- NULL;
   if(centreData) {
      sdf <- timeSeries - mean(timeSeries);
   } else {
       sdf <- timeSeries;
   }
   sdf <- c(sdf, rep(0.0, nDFT-sampleSize));
   sdf <- fft(sdf);
   if(returnFourierCoef) {
      FourierCoef <- sdf[(1+offSet):(nFreqs+offSet)]*sqrt(fiddleFactorSDF);
   }
   sdf <- abs(sdf[(1+offSet):(nFreqs+offSet)])^2*fiddleFactorSDF;
   if(is.function(sdfTransformation)) {
      sdf <- sdfTransformation(sdf);
   }
   resultFreqs <- ((0+offSet):(nFreqs+offSet-1))*fiddleFactorFreq;
   return(list(   sdf=sdf,
                  resultFreqs=resultFreqs,
                  nFreqs=nFreqs,
                  FourierCoef=FourierCoef));
}

#Percival Sum test from page 325 6.6c
#this is also used to test the lisp code provided with
#SAPA.

#for (N in c(5, 8, 9, 22, 32, 63, 64, 65)) {
#   timeSeries <- rnorm(N,mean=100);
#   #note Percival do not calculate the sample variance
#   #correction factor (n-1)/n
#   sigma2 <- sampleVariance.bias(timeSeries);
#   samplingTime <- .25;
#   thePeriodogram <- periodogram(timeSeries,
#                     nNonZeroFreqs="Fourier",
#                     sdfTransformation=F,
#                     samplingTime=samplingTime);
#   Nminusf <- length(thePeriodogram$sdf);
#   ParsevalSum <- 0;
#   if((N%%2) ==0 ) {
#      ParsevalSum <- ((2* sum(thePeriodogram$sdf[1:(Nminusf-1)]) +
#                              thePeriodogram$sdf[Nminusf]) /
#                                 (N * samplingTime))
#   }
#   else {
#      ParsevalSum <- ((2* sum(thePeriodogram$sdf)) / (N * samplingTime));
#   }
#   cat(paste(  " n = ",
#         format(N, width=2),
#         ", N-f = ",
#         format(Nminusf, width=2) ,
#         ": ", round(sigma2, digits=12),
#         " ",
#         round(ParsevalSum, digits=12),
#         " ",
#         format(ParsevalSum/sigma2, nsmall=12), "\n"));
#}


directSpectralEst <- function(   timeSeries,
                                 centreData=TRUE,
                                 nNonZeroFreqs="halfNextPowerOf2",
                                 returnEstFor0FreqP=FALSE,
                                 samplingTime=1.0,
                                 dataTaper=NULL,
                                 dataTaperParameter=NULL,
                                 recentreAfterTaperingP=TRUE,
                                 restorePowerOptionP=TRUE,
                                 sdfTransformation=convertTodB) {
   if(!is.function(dataTaper)) {
      cat("DataTaper must be a function\n");
      return();
   }
   sampleSize <- length(timeSeries);
   nFreqs <- getNFreqs(nNonZeroFreqs, sampleSize, returnEstFor0FreqP);
   nDFT <- getNDFT(nNonZeroFreqs, sampleSize);
   offSet <- if(returnEstFor0FreqP) 0 else 1;
   fiddleFactorSDF <- samplingTime / as.double(sampleSize);
   fiddleFactorFreq <- 1 / as.double(nDFT * samplingTime);
   if(centreData) {
      timeSeries <- timeSeries - mean(timeSeries);
   }
   scratch <- taperTimeSeries(  timeSeries,
                     dataTaperFn=dataTaper,
                     taperParameter=dataTaperParameter,
                     recentreAfterTaperingP=recentreAfterTaperingP,
                     restorePowerOptionP=restorePowerOptionP);
   sdf <- scratch$result;
   resACVS <- acvs(sdf, centreDataP=FALSE);
   sdf <- c(sdf, rep(0.0, nDFT-sampleSize));
   sdf <- fft(sdf);
   sdf <- abs(sdf[(1+offSet):(nFreqs+offSet)])^2*fiddleFactorSDF;
   if(is.function(sdfTransformation)) {
      sdf <- sdfTransformation(sdf);
   }
   resultFreqs <- ((0+offSet):(nFreqs+offSet-1))*fiddleFactorFreq;
   return(list(   sdf=sdf,
                  resultFreqs=resultFreqs,
                  nFreqs=nFreqs,
                  C_h=scratch$C_h,
                  resultACVS=resACVS$acvs));
}

#directSpectralEst(  c(1,2,3,4,5,6,7,8,9,10,11,12),
#   dataTaper=dpssDataTaper,
#   dataTaperParameter=2)

#ts <- scan("rants.txt");
#directSpectralEst(ts, dataTaper=dpssDataTaper, dataTaperParameter=4, nNonZeroFreqs="Fourier", sdfTransformation=F, samplingTime=.25);
#for( N in c(5, 8, 9, 22, 32, 63, 64, 65) ) {
#   timeSeries <- rnorm(N,mean=100);
#   #note Percival do not calculate the sample variance
#   #correction factor (n-1)/n
#   sigma2 <- sampleVariance.bias(timeSeries);
#   samplingTime <- .25;
#   theSdfEst <- directSpectralEst(timeSeries,
#                              dataTaper=dpssDataTaper,
#                              dataTaperParameter=4,
#                              nNonZeroFreqs="Fourier",
#                              sdfTransformation=F,
#                              samplingTime=samplingTime);
#
#   Nminusf <- length(theSdfEst$sdf);
#   ParsevalSum <- 0;
#   if((N%%2) ==0 ) {
#      ParsevalSum <- ((2* sum(theSdfEst$sdf[1:(Nminusf-1)]) +
#                              theSdfEst$sdf[Nminusf]) /
#                                 (N * samplingTime))
#   }
#   else {
#      ParsevalSum <- ((2* sum(theSdfEst$sdf)) / (N * samplingTime));
#   }
#   cat(paste(  " n = ",
#         format(N, width=2),
#         ", N-f = ",
#         format(Nminusf, width=2) ,
#         ": ", round(sigma2, digits=14),
#         " ",
#         round(ParsevalSum, digits=14),
#         " ",
#         format(ParsevalSum/sigma2, digits=14, nsmall=12), "\n"));
#}
#n =   5 , N-f =   2 :  0.71619022954226   0.71619022954226   1.000000000000
#n =   8 , N-f =   4 :  0.62352763344154   0.62352763344154   1.000000000000
#n =   9 , N-f =   4 :  0.80443487719459   0.80443487719459   1.000000000000
#n =  22 , N-f =  11 :  0.80783804889857   0.80783804889857   1.000000000000
#n =  32 , N-f =  16 :  1.28715872491984   1.28715872491984   1.000000000000
#n =  63 , N-f =  31 :  1.52495082812021   1.52495082812021   1.000000000000
#n =  64 , N-f =  32 :  0.92795120431285   0.92795120431285   1.000000000000
#n =  65 , N-f =  32 :  1.09915628934468   1.09915628934468   1.000000000000

#Note: see Equation (260) of the SAPA book
#      or Priestley, page 439, Equation (6.2.65)"
BartlettLagWindow <- function(tau, m) {
   if(m < 0) {
      return();
   }
   if(abs(tau) < m) {
      return(1 - abs(tau)/m);
   }
   return(0);
}

#Note: see Table 269 of the SAPA book"
BartlettMtoBandwidth <- function(m, samplingTime=1.0) {
   return(1.5/(m*samplingTime));
}

#Note: see Table 269 of the SAPA book
BartlettBandwidthtoM <- function(B_W, samplingTime=1.0) {
   m <- max(1, round(1.5/(B_W*samplingTime)));
   return(list(m=m, B_W=BartlettMtoBandwidth(m)));
}

BartlettNandMtoDF <- function(N, m, C_h=1.0) {
    ##Note: see Table 269 of the SAPA book"
    return((3.0*N)/(m*C_h));
}


DaniellLagWindow <- function(tau, m) {
    ##   "given the lag tau and window parameter m,
    ## returns the value of the Daniell lag window
    ## ---
    ## Note: see equation between Equations (264a) and (264b) of the SAPA book
    ##       or Priestley, page 441, Equation (6.2.73)"
    if(m <= 0) {
        return();
    }
    if(tau == 0) {
        return(1.0);
    }
    ratio <- pi*tau/m;
    return(sin(ratio)/ratio);
}

DaniellMtoBandwidth <- function(m, samplingTime=1.0) {
    ##    "given window parameter m and sampling time,
    ## returns bandwidth B_W for the Daniell smoothing window
    ## ---
    ## Note: see Table 269 of the SAPA book"  
    return(1/(m*samplingTime))
}

DaniellBandwidthtoM <- function(B_W, samplingTime=1.0) {
    ##   "given desired smoothing window bandwidth B_W and sampling time,
    ## returns 
    ##    [1] window parameter m required to approximately achieve B_W
    ##        using the Daneill lag window
    ##    [2] actual B_W achieved (in fact, this is always equal to B_W,
    ##        but we return it anyway for consistency with other lag windows)
    ## ---
    ## Note: see Table 269 of the SAPA book"
    return(list(m=1/(B_W*samplingTime), B_W=B_W))
}

DaniellNandMtoDF <- function(N, m, C_h = 1.0) {
    ##   "given sample size N, window parameter m and
    ## variance inflation factor C_h,
    ##   returns equivalent degrees of freedom nu for Daniell lag window
    ## ---
    ## Note: see Table 269 of the SAPA book"
    return((2.0*N)/(m*C_h))
}

########################################lag window stuff
#######################################################################
## wosa and lag window material may not be 100%
## wosa passes some checks...

#given
#[1] acvs (required)
#    ==> vector containing autocovariance sequence
#[2] lag-window-function (required)
#    ==> function of a single variable that computes the value
#        of the lag window for a given lag
#[3] max-lag (keyword; (1- (length acvs)))
#    ==> maximum lag in acvs to be used
#[4] N-ts (keyword; length of acvs)
#    ==> length of the time series from which acvs was constructed;
#        this is needed to compute equivalent degrees of freedom
#[5] N-nonzero-freqs (keyword; :half-next-power-of-2)
#    ==> specifies at how many nonzero frequencies
#        direct spectral estimate is to be computed -- choices are:
#        :half-next-power-of-2
#         ==> 1/2 * power of two >= sample size;
#        :next-power-of-2
#         ==> power of two >= sample size;
#        :twice-next-power-of-2
#         ==> 2 * power of two >= sample size;
#        :Fourier
#         ==> just at Fourier frequencies
#         -- or --
#        any power of 2 >= 1/2 * [power of two >= sample size]
#[6] return-est-for-0-freq-p (keyword; nil)
#    ==> if t, sdf is computed at zero frequency;
#        otherwise, it is not computed.
#[7] sampling-time (keyword; 1.0)
#    ==> sampling time (called delta t in the SAPA book)
#[8] scratch-dft (keyword; vector of correct length)
#    ==> vector in which the in-place dft is done
#[9] C_h (keyword; 1.0)
#    ==> variance inflation factor due to tapering
#[10] sdf-transformation (keyword; #'convert-to-dB)
#    ==> a function of one argument or nil;
#        if bound to a function, the function is used
#        to transform all elements of result-sdf
#[11] result-sdf (keyword; vector of correct length)
#    <== vector into which lag window spectral estimates are placed;
#        it must be exactly of the length dictated
#        by N-nonzero-freqs and return-est-for-0-freq-p
#[12] return-frequencies-p (keyword; t)
#    ==> if t, the frequencies associated with the spectral estimate
#        are computed and returned in result-freq
#[13] freq-transformation (keyword; nil)
#    ==> a function of one argument or nil;
#        if bound to a function, the function is used
#        to transform all elements of result-freq
#        (ignored unless return-frequencies-p is true)
#[14] result-freq (keyword; nil or vector of correct length)
#    <== not used if return-frequencies-p nil; otherwise,
#        vector of length dictated by
#        N-nonzero-freqs and return-est-for-0-freq-p
#        into which the frequencies associated with the values
#        in result-sdf are placed
#returns
#[1] result-sdf, a vector holding
#    the properly transformed sdf
#[2] result-freq (if return-frequencies-p is t),
#    where result-freq is a vector holding
#    the properly transformed frequencies
#    associated with values in  result-sdf
#     -- or --
#    nil (if return-frequencies-p is nil)
#[3] the length of the vector result-sdf
#[4] the equivalent degrees of freedom
#[5] the smoothing window bandwidth
#---
#Note: see Section 6.7 of the SAPA book
#;;; Note: in what follows, we assume that the lag window
#;;;       at lag 0 is unity (see Equation (240a) of the SAPA book)
lagWindowSpectralEst <- function( acvs_,
                                 lagWindowFn,
                                 windowParameterM,
                                 maxLag=length(acvs_) -1,
                                 N_ts=length(acvs_),
                                 nNonZeroFreqs="halfNextPowerOf2",
                                 returnEstFor0FreqP=FALSE,
                                 samplingTime=1.0,
                                 C_h=1.0,
                                 sdfTransformation=convertTodB) {

   N_acvs <- maxLag +1;
   nFreqs <- getNFreqs(nNonZeroFreqs, N_acvs, returnEstFor0FreqP);
   nDFT <- getNDFT(nNonZeroFreqs, N_acvs);
   scratchDFT <- array(NA, nDFT);
   offSet <- if(returnEstFor0FreqP) 0 else 1;
   fiddleFactorFreq <- 1 / as.double(nDFT * samplingTime);
   B_Wbot <- 1.0;

   if(nDFT <= 2*maxLag) {
      scratchDFT[1] <- acvs_[1];
      tau_ <- 1;
      for(i in 0:(maxLag -1) ) {
         tauIndex <- tau_ +1;
         lagWindowValue <- lagWindowFn(tau_, windowParameterM);
         B_Wbot <- B_Wbot + 2*lagWindowValue^2;
         scratchDFT[tauIndex] <- 2*lagWindowValue*acvs_[tauIndex];
         tau_ <- tau_ +1;
      }
      scratchDFT[maxLag+1:(nDFT-(maxLag+1)+1)] <- array(0, nDFT-maxLag);
   } else {
      scratchDFT[1] <- acvs_[1];
      tau_ <- 1;
      tauIndex <- tau_ +1;
      tauBackward <- nDFT -1;
      tauBackwardIndex <- tauBackward +1;
      for(i in 0:(maxLag-1) ) {
         lagWindowValue <- lagWindowFn(tau_, windowParameterM);
         B_Wbot <- B_Wbot + 2*lagWindowValue^2;
         scratchDFT[tauBackwardIndex] <- lagWindowValue*acvs_[tauIndex];
         scratchDFT[tauIndex] <- scratchDFT[tauBackwardIndex];
         tau_ <- tau_ +1;
         tauIndex <- tau_ +1;
         tauBackward <- tauBackward -1;
         tauBackwardIndex <- tauBackward +1;
      }
      scratchDFT[tauIndex:(tauBackwardIndex)] <- 
         array(0, tauBackwardIndex-tauIndex+1);
   }
   scratchDFT <- fft(scratchDFT);
   scratchDFT <- Re(scratchDFT[(1+offSet):(nFreqs+offSet)])*samplingTime;
   if(is.function(sdfTransformation)) {
      scratchDFT <- sdfTransformation(scratchDFT);
   }
   resultFreqs <- ((0+offSet):(nFreqs+offSet-1))*fiddleFactorFreq;
   B_W <- 1/(samplingTime*B_Wbot);
   return(list( resultSDF=scratchDFT,
               resultFreqs=resultFreqs,
               equivalentDOF=(2*N_ts*B_W*samplingTime)/C_h, #;equivalent dof
               B_W=B_W)); #;smoothing window bandwidt
}


#twentyPTts <- c(71.0,  63.0,  70.0,  88.0,  99.0, 90.0, 110.0, 135.0, 128.0, 154.0,
#                   156.0, 141.0, 131.0, 132.0, 141.0, 104.0, 136.0, 146.0, 124.0, 129.0);
#samplingTime <- 0.25;
#theacvs <- acvs(twentyPTts);
#Parzen15sdfest <-  lagWindowSpectralEst(
#                           theacvs$acvs,
#                           parzenLagWindow,
#                           15,
#                           nNonZeroFreqs="Fourier",
#                           samplingTime=samplingTime)
                           
#Error in 2 * lagWindowValue * acvs_[tauIndex] :
#        non-numeric argument to binary operator
#lagWindowSpectralEst(
#                           theacvs$acvs,
#                           parzenLagWindow,
#                           5,
#                           #maxLag=2,
#                           nNonZeroFreqs="nextPowerOf2",
#                           samplingTime=samplingTime)


##wosa checks out...
## given
## [1] time-series (required)
##  ==> a vector of real-valued numbers
## [2] block-size (required)
##  ==> a power of two
## [3] proportion-of-overlap (keyword; 0.5)
##  ==> number greater than 0 and less than 1
## [4] oversampling-factor (keyword; 1)
##  ==> a factor that controls the number of frequencies
##      at which the wosa spectral estimate is computed;
##      this factor should be an integer power of two
##      such as 1, 2, 4, etc; for example,
##      1 yields Fourier frequencies for block-size;
##      2 yields grid twice as fine as Fourier frequencies;
##      4 yields griid 4 times as fine as Fourier frequencies;
##      etc.
## [5] center-data (keyword; t)
##  ==> if t, subtract sample mean from time series;
##      if a number, subtracts that number from time series;
##      if nil, time-series is not centered
## [6] start (keyword; 0)
##  ==> start index of vector to be used
## [7] end (keyword; length of time-series)
##  ==> 1 + end index of vector to be used
## [8] return-est-for-0-freq-p (keyword; nil)
##  ==> if t, sdf is computed at zero frequency;
##      otherwise, it is not computed.
## [9] sampling-time (keyword; 1.0)
##  ==> sampling time (called delta t in the SAPA book)
## [10] scratch-dft (keyword; vector of correct length)
##  ==> vector in which the in-place dft is done
## [11] data-taper (keyword; #'Hanning-data-taper!)
##  ==> a tapering function or nil
## [12] data-taper-parameters (keyword; nil)
##  ==> parameters for tapering function (not used
##      if data-taper is nil); the default of nil
##      is appropriate for the Hanning data taper
##      because it does not have any parameters
## [13] restore-power-option-p (keyword; t)
##  ==> if t and data-taper is non-nil,
##      normalizes tapered series to have same
##      sum of squares as before tapering
## [14] sdf-transformation (keyword; #'convert-to-dB)
##  ==> a function of one argument or nil;
##      if bound to a function, the function is used
##      to transform all elements of result-sdf
## [15] result-sdf (keyword; vector of correct length)
##  <== vector into which wosa sdf estimate is placed;
##      it must be EXACTLY of the length dictated
##      by block-size, oversampling-factor and return-est-for-0-freq-p
## [16] return-sdf-estimates-for-each-block-p (keyword; t)
##  ==> if t, individual spectra for each block are returned in a list;
##      note that these spectra are untransformed
##      (i.e., the option sdf-transformation applies only
##      to the final wosa estimate)
## [17] return-frequencies-p (keyword; t)
##  ==> if t, the frequencies associated with the spectral estimate
##      are computed and returned in result-freq
## [18] freq-transformation (keyword; nil)
##  ==> a function of one argument or nil;
##      if bound to a function, the function is used
##      to transform all elements of result-freq
##      (ignored unless return-frequencies-p is true)
## [19] result-freq (keyword; nil or vector of correct length)
##  <== not used if return-frequencies-p nil; otherwise,
##      vector of length dictated by
##      block-size, oversampling-factor and return-est-for-0-freq-p
##      into which the frequencies associated with the values
##      in result-sdf are placed
## returns
## [1] wosa spectral estimate
## [2] associated frequencies
## [3] equivalent degrees of freedom
## [4] list of individual direct spectral estimates
wosaSpectralEst <- function(timeSeries,
                        blockSize,
                        proportionOfOverlap=0.5,
                        oversamplingFactor=1,
                        centreData=T,
                        returnEstFor0FreqP=TRUE,
                        samplingTime=1.0,
                        dataTaper=HanningDataTaper,
                        dataTaperParameter=NULL,
                        ##recentreAfterTaperingP=T, #added option
                        restorePowerOptionP=TRUE,
                        sdfTransformation=convertTodB) {
   
    nDFT <- oversamplingFactor*blockSize 
    scratchDFT = array(NA, nDFT)
    centredTimeSeries <- timeSeries
    if(centreData) {
        centredTimeSeries <-  centredTimeSeries -
            mean(centredTimeSeries)
    }

    nFreqs <- wosaGetNFreqs(blockSize,
                            oversamplingFactor,
                            returnEstFor0FreqP)
    offsetFreq <- if(returnEstFor0FreqP) 0 else 1
    sampleSize <- length(timeSeries)
    numberOfBlocks <-
        calculateNumberOfBlocks(sampleSize,
                                blockSize,
                                proportionOfOverlap)
    mIndividualSDFs <- matrix(NA, nFreqs, numberOfBlocks)
    vectorWithDataTaper <- NULL
    if(!is.null(dataTaper)) {
        vectorWithDataTaper <-
            taperTimeSeries(array(1.0, blockSize),
                            dataTaperFn=dataTaper,
                            taperParameter=dataTaperParameter,
                            recentreAfterTaperingP=FALSE,
                            restorePowerOptionP=FALSE)$result
    } else {
        vectorWithDataTaper <- array(1.0, blockSize)
    }
   
    fiddleFactorSDF <- samplingTime / as.double(blockSize)
    fiddleFactorFreq <- 1 / as.double(nDFT * samplingTime)
    offsetBlock <- NULL
    resultSDF <- array(0.0, nFreqs)
    for( k in 0:(numberOfBlocks -1) ) {
        offsetBlock <-
            getOffsetTokthBlock(sampleSize,
                                blockSize,
                                numberOfBlocks,
                                k)
        scratchDFT[1:blockSize] <- 
            centredTimeSeries[(offsetBlock+1):
                              (offsetBlock+blockSize)]
        if(nDFT > blockSize) {
            scratchDFT[(blockSize+1):nDFT] <-
                array(0.0, nDFT-blockSize)
        }
        if(!is.null(dataTaper)) {
          sumOfSquaresBefore <- NULL
          if(restorePowerOptionP) {
              sumOfSquaresBefore <- sum(scratchDFT[1:blockSize]^2)
          }
          ##print(vectorWithDataTaper)
          ##print(blockSize)
          scratchDFT[1:blockSize] <-
              scratchDFT[1:blockSize] * vectorWithDataTaper
          if(restorePowerOptionP) {
              multFactor <- sqrt(sumOfSquaresBefore /
                                 (sum(scratchDFT[1:blockSize]^2)))
              scratchDFT[1:blockSize] <-
                  scratchDFT[1:blockSize] * multFactor
          }
      }
        ##print(scratchDFT)
        scratchDFT <- fft(scratchDFT)
        ## use scratchDFT2 to ensure no complex numbers remain
        ## when squaring oonly part of the array
        scratchDFT2 <- fiddleFactorSDF *
            abs(scratchDFT[(1+offsetFreq):(nFreqs+offsetFreq)])^2
        mIndividualSDFs[,k+1] <-  scratchDFT2
        resultSDF <- resultSDF + scratchDFT2
    }
    resultSDF <- resultSDF / numberOfBlocks
    if(is.function(sdfTransformation)) {
        resultSDF <- sdfTransformation(resultSDF)
   }
    resultFreqs <- ((0+offsetFreq):(nFreqs+offsetFreq-1))*
        fiddleFactorFreq
    return(list(resultSDF=resultSDF,
                resultFreqs=resultFreqs,
                equivWOSA_dof=equivalentDOFforWOSA(sampleSize,
                blockSize,
                numberOfBlocks,
                vectorWithDataTaper),
                mIndividualSDFs=mIndividualSDFs))
}

## (setf 20-pt-ts #(71.0  63.0  70.0  88.0  99.0  90.0 110.0 135.0 128.0 154.0
##                    156.0 141.0 131.0 132.0 141.0 104.0 136.0 146.0 124.0 129.0))
## twentyPtTs <- c(71.0,  63.0,  70.0,  88.0,  99.0,  90.0, 110.0, 135.0, 128.0, 154.0, 156.0, 141.0, 131.0, 132.0, 141.0, 104.0, 136.0, 146.0, 124.0, 129)
## samplingTime = .25
## proportionOfOverlap=0.5
## oversamplingFactor=1
## centreData=T
## returnEstFor0FreqP=T
## samplingTime=1.0
## dataTaper=HanningDataTaper
## dataTaperParameter=NULL
## ##recentreAfterTaperingP=T, #added option
## restorePowerOptionP=T

## sdfTransformation=convertTodB

## timeSeries = twentyPtTs
## blockSize=4
## oversamplingFactor=4
## samplingTime=.25
## ##  (wosa-spectral-estimate
## ##                 20-pt-ts
## ##                 4
## ##                 :oversampling-factor 4
## ##                 :sampling-time sampling-time)
## wosaSpectralEst(twentyPtTs,
##                 4,
##                 ##oversamplingFactor=4,
##                  samplingTime=samplingTime)
## twentyPtTs <- c(71.0,  63.0,  70.0,  88.0,  99.0,  90.0, 110.0, 135.0, 128.0, 154.0, 156.0, 141.0, 131.0, 132.0, 141.0, 104.0, 136.0, 146.0, 124.0, 129)
## samplingTime = .25
## proportionOfOverlap=0.5
## oversamplingFactor=1
## centreData=T
## returnEstFor0FreqP=T
## samplingTime=1.0
## dataTaper=HanningDataTaper
## dataTaperParameter=NULL
## ##recentreAfterTaperingP=T, #added option
## restorePowerOptionP=T

## sdfTransformation=convertTodB

## timeSeries = twentyPtTs
## blockSize=4
## oversamplingFactor=4
## samplingTime=.25
## ##  (wosa-spectral-estimate
## ##                 20-pt-ts
## ##                 4
## ##                 :oversampling-factor 4
## ##                 :sampling-time sampling-time)
## wosaSpectralEst(twentyPtTs,
##                 4,
##                 ##oversamplingFactor=4,
##                  samplingTime=samplingTime)



#;;; The next 5 functions support wosa-spectral-estimate
wosaGetNFreqs <- function(blockSize,
            oversamplingFactor,
            returnEstFor0FreqP) {
   temp <- oversamplingFactor*blockSize/2;
   if(returnEstFor0FreqP) {
      return(temp +1);
   }
   return(temp);
}

#wosaGetNFreqs(256, 1, T)
##;==> 129
#wosaGetNFreqs(256, 1, F)
##;==> 128
#wosaGetNFreqs(256, 2, T)
##;==> 257
#wosaGetNFreqs(256, 2, F)
##;==> 256
#
calculateNumberOfBlocks <- function(sampleSize,
                           blockSize,
                           proportionOfOverlap) {
   return(trunc(as.double(sampleSize - blockSize) /
         (blockSize*(1.0 - proportionOfOverlap))) +1);
}

getOffsetTokthBlock <- function(sampleSize,
               blockSize,
               numberOfBlocks,
               k) {
   if(numberOfBlocks > 1) {
      return(trunc(k*(sampleSize - blockSize)/(numberOfBlocks -1)));
   }
   return(0);
}

#given the sample size N, the block size N_S, the number of blocks N_B,
#and the values of the data taper,
#returns the equivalent degrees of freedom for wosa
#using Equation (292b) of the SAPA book
equivalentDOFforWOSA <- function(N, N_S, N_B, vectorWithDataTaper) {
   acsTaper <- acvs(vectorWithDataTaper, centreDataP=FALSE, acsP=TRUE)$acvs;
   temp_ <- if(N_B == 1 ) 0 else (N-N_S)/(N_B -1);
   nShift <- round(temp_);
   acsTaper <- acsTaper^2;

   sum_ <- 0;
   m <- 0;
   for ( mM1 in 0:(N_B -2) ) {
      m <- m +1;
      if( m*nShift < N_S) {
         sum_ <- sum_ + (N_B - m) * acsTaper[(m*nShift)+1];
      } else {
         break;
      }
   }
   return( (2*N_B)/(((2.0*sum_) / as.double(N_B)) +1));
}
## for( N_S in c(64, 16, 8)) {
##    print(equivalentDOFforWOSA(1024, N_S,
##       calculateNumberOfBlocks(1024, N_S, .5),
##       HanningDataTaper(array(1.0, N_S))$taperedTS));
## }
#;==>  58.45100403500567
#;    233.79011528097186
#;    453.1836628613355
