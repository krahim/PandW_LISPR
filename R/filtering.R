## set local path
##pathToFiles <- "~/PWLisp/"

## set to TRUE and manually source the R file, which will link the dynamic library
## that you build with a make file.

##useFortranLib <-FALSE

## set location of filteringFLIB.R. I use symlinks and keep filteringFLIB.R
## all in same folder.
##pathToFortranSetupFiles <- pathToFiles

##library("multitaper") ## required for dpss filter,
## one can use the zeroth order dpss instead.

##source(paste(pathToFiles, "utilities.R", sep=""))
##source(paste(pathToFiles, "tapers.R", sep=""))


##if(useFortranLib) {
##    ## load dynamic library and fortran versions of the function.
##    source(paste(pathToFortranSetupFiles, "filteringFLIB.R", sep=""))
##}



## ;;; Note: filter-time-series-direct is primarily intended to be used
## ;;; with short filters for which use of fft's would not be effecient.
##   "given
##    [1] time-series (required)
##        ==> a vector containing a time series
##            x_0, x_1, ..., x_{N-1}
##    [2] the-filter (required)
##        ==> a vector containing the filter coefficients
##            g_0, g_1, ..., x_{K-1}
##    [3] start (keyword; 0)
##        ==> start index of time-series to be used
##    [4] end (keyword; length of time-series)
##        ==> 1 + end index of time-series to be used
##    [5] result (keyword; vector of appropriate length)
##        <== vector to contain filtered time series
##                  K-1
##            y_t = SUM g_k x_{t+K-1-k},  t = 0, ..., N-K+1
##                  k=0
##  returns
##    [1] result, a vector containing the filtered time series
##    [2] the number of values in the filtered time series
## ---
## Note: result can be the same as time-series"

## There are two versions, one in R and one in Fortran.
## The filtering package will overwrite this function and
## give an option. 
filterTimeSeriesDirect <- function(timeSeries, theFilter) {
    filterTimeSeriesDirectR(timeSeries, theFilter)
}

## > filterTimeSeriesDirect(c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1,-1))
## $result
##  [1]   1   1   1   1 -10  -2  -2  19   1   2

## $nOutput
## [1] 10

filterTimeSeriesDirectR <- function(timeSeries, theFilter) {
    nFilter <- length(theFilter)
    nFilterM1 <- nFilter -1
    nOutput <- length(timeSeries) - nFilterM1

    theFilter <- rev(theFilter)
    result <- array(NA, nOutput)
    
    for(i in 1:nOutput) {
        result[i] <- timeSeries[i] * theFilter[1]
        for(j in 1:nFilterM1) {
            result[i] <- result[i] + timeSeries[i+j] * theFilter[j +1]
        }
    }
    return(list(result=result, nOutput=nOutput))
}

##filterdirect
##filter( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1,-1))
##filterTimeSeriesDirect( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1,-1))

##convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1,-1), type="filter")
##convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1,-1), conj=FALSE, type="filter")

## > convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1/3,1/3), type="filter")
##  [1]  1.000000e+00  1.666667e+00  2.333333e+00  3.000000e+00  2.960595e-16
##  [6] -4.000000e+00 -5.333333e+00  3.333333e-01  7.000000e+00  8.000000e+00
## > convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1/3,1/3), conj=T, type="filter")
##  [1]  1.000000e+00  1.666667e+00  2.333333e+00  3.000000e+00  2.960595e-16
##  [6] -4.000000e+00 -5.333333e+00  3.333333e-01  7.000000e+00  8.000000e+00
## > filterWfft( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1/3,1/3))$result
##  [1]  1.000000e+00  1.666667e+00  2.333333e+00  3.000000e+00 -1.110223e-16
##  [6] -4.000000e+00 -5.333333e+00  3.333333e-01  7.000000e+00  8.000000e+00

## $nOutput
## [1] 10

## > convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1/3,1/3), conj=T, type="filter")
##  [1]  1.000000e+00  1.666667e+00  2.333333e+00  3.000000e+00  2.960595e-16
##  [6] -4.000000e+00 -5.333333e+00  3.333333e-01  7.000000e+00  8.000000e+00
## > convolve( c(1,2,3,4,5,-5,-7,-9, 10, 11, 13), c(1/3,1/3), type="filter")
## notes on convolve, it seems fine when filters are all positive, there may be some issues with negative values.


##perhaps try something like...
##Re(fft(Conj(fft(tspad)*fft(fpad)))/256)[3:(length(ts))]

filterWfft_old<- function(timeSeries, filter) {
    ndata <- length(timeSeries)
    nfilter <- length(filter)
    nfft <- 2^(ceiling(log2(ndata)))
    tsPad <- c(timeSeries, rep(0.0, nfft-ndata))
    fPad <- c(filter, rep(0.0, nfft-nfilter))
    return((Re(fft(Conj(fft(tsPad)*fft(fPad))))/nfft)[nfilter:ndata])
}    


## There are two versions, one in R and one in Fortran.
## The filtering package will overwrite this function and
## give an option. 
filterWfft <- function(timeSeries, filter1) {
    filterWfftR(timeSeries, filter1)
}

filterWfftR <- function(timeSeries, filter1) {
    ##           K-1
    ##     y_t = Sum g_k x_{t+K-1-k},  t = 0, ..., N-K+1
    ##           k=0
    ## http://en.wikipedia.org/wiki/Cyclic_convolution
    
    ndata <- length(timeSeries)
    nfilter <- length(filter1)
    ## 4 * next power of 2
    nfft <- 4*2^(ceiling(log2(nfilter)))
    fPad <- c(filter1, rep(0.0, nfft-nfilter))
    blockLen <- nfft - nfilter +1
    nblocks <- floor(ndata / blockLen) +
        if(ndata %% blockLen !=0) 1 else 0
    ##npad <- nblocks*blockLen - nfft
    nResult <- ndata - nfilter + 1
    result <- array(NA, nResult)
    fPad <- fft(fPad)
    i <- 0

    while(i*blockLen + nfft < ndata) {
        tsfft <- fft(timeSeries[(i*blockLen +1) : (i*blockLen + nfft)])
        result[(i*blockLen +1) : (i*blockLen + blockLen)] <-
            (Re(fft(tsfft*fPad, inverse=T)/nfft))[nfilter:nfft]
        i <- i +1
    }
    
    lenLeft <- ndata - i*blockLen  
    if(lenLeft != 0) {
        
        tsfft <- fft(c(timeSeries[(i*blockLen +1) : ndata],
                       array(0.0, nfft - lenLeft)))
        result[(i*blockLen +1) : nResult] <-
            (Re(fft(tsfft*fPad,
                    inverse=T)/nfft))[nfilter:(nfilter + lenLeft - nfilter)]
    }   

    return(list(result=result, nOutput=nResult))
}    


##filterWfft(  c(1,2,3,4,5,-5,-7,-9), c(1,-1))
## $result
## [1]   1   1   1   1 -10  -2  -2

## $nOutput
## [1] 7

## ;-------------------------------------------------------------------------------
## ;-------------------------------------------------------------------------------
## ;;;  The functions  ideal-low-pass-filter-irs
## ;;;                 ideal-high-pass-filter-irs
## ;;;                 ideal-band-pass-filter-irs
## ;;;                 create-least-squares-low-pass-filter
## ;;;                 triangular-convergence-factors
## ;;;                 create-dpss-low-pass-filter
## ;;;                 compose-symmetric-filters
## ;;;  can be used to create a filter (by which we mean a vector containing
## ;;;  the filter coefficients).  The first three of these functions
## ;;;  return a single member of the impulse response sequence for an ideal
## ;;;  low-pass, high-pass or band-pass filter.  The next three functions
## ;;;  can be used to create one of the approximations to an ideal low-pass
## ;;;  filter discussed in Sections 5.8 and 5.9 of the SAPA book.  The
## ;;;  final function takes any number of symmetric filters of odd length
## ;;;  and returns the equivalent composite filter.
## ;-------------------------------------------------------------------------------
## ;-------------------------------------------------------------------------------


idealLowPassFilterIRS <- function(k, W) {
    ##       "given 
    ##    [1] k (required)
    ##        ==> index of member of impulse response sequence (irs)
    ##            to be calculated (must be an integer)
    ##    [2] W (required)
    ##        ==> the cutoff frequency, standardized such that
    ##             0 < W < 0.5 = Nyquist frequency
    ## returns
    ##    [1] kth member of the impulse response sequence
    ##        for an ideal low-pass filter with cutoff frequency W
    ## ---
    ## Note: see Section 5.8 of the SAPA book"
    ##   ;(assert (and (integerp k) (plusp W) (< W 0.5))
    ##
    stopifnot(k %% 1==0)## is integer
    stopifnot(W > 0) 

    res <- NULL
    if( k == 0) {
        res <- 2*W
    } else {
        res <- (sin (2 * pi * W * k))/ (pi *  k)
    }
    res
}


## (ideal-low-pass-filter-irs 0 0.1)   ;==> 0.2
## (ideal-low-pass-filter-irs 1 0.1)   ;==> 0.1870978567577278
## (ideal-low-pass-filter-irs -1 0.1)  ;==> 0.1870978567577278
## > idealLowPassFilterIRS(0, 0.1)
## [1] 0.2
## > idealLowPassFilterIRS(1, 0.1)
## [1] 0.1870979
## > idealLowPassFilterIRS(-1, 0.1)
## [1] 0.1870979


idealLowPassFilterIRS_vec <- function(vecK, W) {
    res <- NULL
    for( k in vecK) {
        res <- c(res, idealLowPassFilterIRS(k, W))
    }
    res
}
##idealLowPassFilterIRS_vec(c(0,1,-1), 0.1)
##[1] 0.2000000 0.1870979 0.1870979



##;-------------------------------------------------------------------------------
idealHighPassFilterIRS <- function(k, W) {
##   "given
##    [1] k (required)
##        ==> index of member of impulse response sequence (irs)
##            to be calculated (must be an integer)
##    [2] W (required)
##        ==> the cutoff frequency, standardized such that
##             0 < W < 0.5 = Nyquist frequency
## returns
##    [1] kth member of the impulse response sequence
##        for an ideal low-pass filter with cutoff frequency W"
    stopifnot(k %% 1==0)## is integer
    stopifnot(W > 0)
    stopifnot(W < .5)

    res <- NULL
    if( k == 0) {
        res <- 1- 2*W
    } else {
        res <- - (sin (2 * pi * W * k))/ (pi *  k)
    }
    res
}
                                        #|
## (ideal-high-pass-filter-irs 0 0.1)   ;==> 0.8
## (ideal-high-pass-filter-irs 1 0.1)   ;==> -0.1870978567577278
## (ideal-high-pass-filter-irs -1 0.1)  ;==> -0.1870978567577278
## |#

## idealHighPassFilterIRS(0, 0.1) 
## [1] 0.8
## > idealHighPassFilterIRS(0, 0.1)
## [1] 0.8
## > idealHighPassFilterIRS(1, 0.1)
## [1] -0.1870979
## > idealHighPassFilterIRS(-1, 0.1)
## [1] -0.1870979

## ;-------------------------------------------------------------------------------
## ;;; Note: by setting W-high = 0.5, this routine produces the irs for
## ;;;       a high-pass filter;
## ;;;       by setting W-low = 0.5, this routine produces the irs for
## ;;;       a low-pass filter



idealBandPassFilterIRS <- function(k, W.low, W.high) {
##     "given
##    [1] k (required)
##        ==> index of member of impulse response sequence (irs)
##            to be calculated (must be an integer)
##    [2] W-low (required)
##        ==> the low frequency cutoff (in standardized units)
##    [3] W-high (required)
##        ==> the high frequency cutoff (in standardized units
##            so that 0 <= W-low < W-high <= 0.5, the assumed
##            Nyquist frequency).
## returns
##    [1] k-th member of the impulse response sequence
##        for an ideal band-pass filter"
    stopifnot((k %% 1==0) &&  ## is integer
              (W.low != W.high) &&
              ((0 <= W.low) &&
               (W.low <= W.high) &&
               (W.high <= 0.5)))
    width <- W.high - W.low
    res <- NULL
    if( k == 0) {
        res <- 2 * width
    } else {
        res <- (2 * cos(pi * (W.high + W.low) * k) *
                sin(pi * width * k)) / (pi * k)
    }
    res
}

## ;;; low-pass
## (ideal-band-pass-filter-irs  0 0.0 0.1)   ;==>  0.2
## (ideal-band-pass-filter-irs  1 0.0 0.1)   ;==>  0.1870978567577278
## (ideal-band-pass-filter-irs -1 0.0 0.1)   ;==>  0.1870978567577278
## ;;; high-pass
## (ideal-band-pass-filter-irs  0 0.3 0.5)   ;==>  0.4
## (ideal-band-pass-filter-irs  1 0.3 0.5)   ;==> -0.3027306914562628
## (ideal-band-pass-filter-irs -1 0.3 0.5)   ;==> -0.3027306914562628

## >  idealBandPassFilterIRS(0, 0.0, 0.1)
## [1] 0.2
## > idealBandPassFilterIRS(0, 0.0, 0.1)
## [1] 0.2
## > idealBandPassFilterIRS(1, 0.0, 0.1)
## [1] 0.1870979
## > idealBandPassFilterIRS(-1, 0.0, 0.1)
## [1] 0.1870979
## > idealBandPassFilterIRS(0, 0.3, 0.5)
## [1] 0.4
## > idealBandPassFilterIRS(1, 0.3, 0.5)
## [1] -0.3027307
## > idealBandPassFilterIRS(-1, 0.3, 0.5)
## [1] -0.3027307

##;-------------------------------------------------------------------------------
createLeastSquaresLowPassFilter <- function(
    filterLength,
    W,
    convergenceFactors_vec=NULL,
    nyquistFrequency=0.5) {
    
##   "given
##    [1] filter-length (required)
##        ==> an odd positive integer = 2L +1
##    [2] W (required)
##        ==> a cutoff frequency greater than 0
##            and less than the Nyquist frequency
##    [3] convergence-factors (keyword; nil)
##        ==> a one-argument function that maps
##            an integer to a convergence factor;
##            nil is also acceptable, in which case
##            no convergence factors are used
##    [4] Nyquist-frequency (keyword; 0.5)
##        ==> the Nyquist frequency
##    [5] result (keyword; vector of length filter-length)
##        <== vector of length filter-length
##            into which filter coefficients
##            are placed (returned by the function)
## uses a least squares approximation to a low-pass filter and
## returns
##    [1] a symmetric low-pass filter of length 2L+1
##        and a gain of unity at zero frequency;
##        i.e., result(0) = result(2L)
##              result(1) = result(2L-1)
##              etc., and
##              (sum result) = 1.0
## ---
## Note: see Section 5.8 of the SAPA book;
##       (aref result 0)       corresponds to element -L of the filter;
##       (aref result L)       corresponds to element  0 of the filter;
##       (aref result (* 2 L)) corresponds to element  L of the filter"
    stopifnot((filterLength > 0) &&
              (filterLength %% 2 == 1) &&
              (W > 0) &&
              (nyquistFrequency > 0) &&
              ((0 < W) && (W < nyquistFrequency)))
    ##  ;;; convert W from user units to standardized units ...
    if(nyquistFrequency != 0.5) {
        W <- W / (2 * nyquistFrequency)
    }
    L <- (filterLength -1) / 2
    minusLtoL <- (-L):L
    ## perhaps we need apply
    result <- idealLowPassFilterIRS_vec(minusLtoL, W)
    if(! is.null(convergenceFactors_vec) ) {
        ## check this
        minusLtoL <- convergenceFactors_vec(minusLtoL, filterLength)
        result <- result * minusLtoL
    }
    result <- result/sum(result)
    result
}

## > createLeastSquaresLowPassFilter(5, 0.1)
## [1] 0.1726089 0.2133564 0.2280693 0.2133564 0.1726089
## > sum(createLeastSquaresLowPassFilter(5, 0.1))
## [1] 1


triangularConvergenceFactors <- function(k, filterLength) {
    absK <- abs(k)
    res <- NULL
    if(absK > trunc(filterLength/2)) {
        res <- 0
    } else {
        res <- (1- (2 * absK) / (filterLength +1))
    }
    res
}

## (triangular-convergence-factors -2 3)  ;==> 0.0
## (triangular-convergence-factors -1 3)  ;==> 0.5
## (triangular-convergence-factors  0 3)  ;==> 1.0
## (triangular-convergence-factors  1 3)  ;==> 0.5
## (triangular-convergence-factors  2 3)  ;==> 0.0    
## > triangularConvergenceFactors(-2, 3)
## [1] 0
## > triangularConvergenceFactors(-1, 3)
## [1] 0.5
## > triangularConvergenceFactors(0, 3)
## [1] 1
## > triangularConvergenceFactors(1, 3)
## [1] 0.5
## > triangularConvergenceFactors(2, 3)
## [1] 0

triangularConvergenceFactors_vec <- function(kVec, filterLength) {
    res <- NULL
    for( k in kVec) {
        res <- c(res, triangularConvergenceFactors(k, filterLength))
    }
    res
}

## > triangularConvergenceFactors_vec((-2):2, 3)
## [1] 0.0 0.5 1.0 0.5 0.0


## (create-least-squares-low-pass-filter
##  5 0.1
##  :convergence-factors
##  #'(lambda (k) (triangular-convergence-factors k 5)))
## ;==> #(0.09167422811028572 0.22663115545827048 0.3633892328628876 0.22663115545827048 0.09167422811028572)

## createLeastSquaresLowPassFilter(5, 0.1,
##     convergenceFactors_vec=triangularConvergenceFactors_vec)
## [1] 0.09167423 0.22663116 0.36338923 0.22663116 0.09167423


## (sum (create-least-squares-low-pass-filter
##       5 0.1
##       :convergence-factors
##       #'(lambda (k) (triangular-convergence-factors k 5))))
## ;==> 1.0

## > sum(createLeastSquaresLowPassFilter(5, 0.1,
## +                                     convergenceFactors_vec=
## +                                     triangularConvergenceFactors_vec))
## [1] 1



createDPSS_LowPassFilter <- function(filterLength,
                                     delta,
                                     W,
                                     nyquistFrequency=0.5,
                                     useTridiagDPSS=TRUE) {
    ##   "given
    ##    [1] filter-length (required)
    ##        ==> an odd positive integer = 2L +1
    ##    [2] delta (required)
    ##        ==> ``W'' parameter for dpss in user
    ##            units (see page 182 of the SAPA book)
    ##    [2] W (required)
    ##        ==> a cutoff frequency greater than 0
    ##            and less than the Nyquist frequency
    ##    [3] Nyquist-frequency (keyword; 0.5)
    ##        ==> the Nyquist frequency
    ##    [4] result (keyword; vector of length filter-length)
    ##        <== vector of length filter-length
    ##            into which filter coefficients
    ##            are placed (returned by the function)
    ##    [5] useTridiagDPSS=TRUE use tridiagonal dpss from multitaper package
    ##        and if FALSE use the zeroth order dpss taper from tapers.R
    ## uses a dpss as convergence factors in least squares approximation
    ## to a low-pass filter and
    ## returns
    ##    [1] a symmetric low-pass filter of length 2L+1
    ##        and a gain of unity at zero frequency;
    ##        i.e., result(0) = result(2L)
    ##              result(1) = result(2L-1)
    ##              etc., and
    ##              (sum result) = 1.0
    ## ---
    ## Note: see Section 5.9 of the SAPA book;
    ##       (aref result 0)       corresponds to element -L of the filter;
    ##       (aref result L)       corresponds to element  0 of the filter;
    ##       (aref result (* 2 L)) corresponds to element  L of the filter"

    stopifnot((filterLength > 0) &&
              (filterLength %% 2 == 1) &&
              (delta > 0) &&
              (W > 0) &&
              (nyquistFrequency > 0) &&
              ((0 < W) && (W < nyquistFrequency)))

    ##  ;;; convert W from user units to standardized units ...
    if(nyquistFrequency != 0.5) {
        delta <- delta / (2 * nyquistFrequency)
        W <- W / (2 * nyquistFrequency)
    }
    L <- (filterLength -1) / 2
    minusLtoL <- (-L):L
    result <- idealLowPassFilterIRS_vec(minusLtoL, W)
    ## taper with dpss dpssDataTaper in "tapers.R"
    dpssV <- NULL
    if(useTridiagDPSS) {
        dpssV <- dpss(filterLength, k=1,
                      nw=(filterLength*delta))$v
    } else { 
        dpssV <- dpssDataTaper(rep(1, filterLength),
                               taperParameter=(filterLength * delta))$taperedTS
    }
    result <-  result * dpssV
    result <- result/sum(result)
    result

}

## createDPSS_LowPassFilter( 5, 0.04, 0.1)
## sum(createDPSS_LowPassFilter( 5, 0.04, 0.1))

## #|
## (create-dpss-low-pass-filter 5 0.04 0.1)
## ;==> #(0.16887701282533799 0.21504897804256012 0.23214801826420375 0.21504897804256012 0.16887701282533799)

## (sum (create-dpss-low-pass-filter 5 0.04 0.1))
## ;==> 0.9999999999999999
## |#

composeTwoSymmetricFilters <- function(filter1, filter2)  {
    ## "given any number of symmetric filters
    ## (each of odd length and each represented
    ## by a vector of coefficients),
    ## returns the composite filter
    ## that will produce an output
    ## identical to that obtained
    ## by cascading the individual filters" 
    halfLengthFilter1 <- (length(filter1) -1) /2
    halfLengthFilter2 <- (length(filter2) -1) /2
    stopifnot(halfLengthFilter1 %% 1 == 0,
              halfLengthFilter2 %% 1 == 0)
    K <- min(halfLengthFilter1, halfLengthFilter2)
    L <- max(halfLengthFilter2, halfLengthFilter2)
    KplusL <- K + L
    TwoxKplusL <- 2 * KplusL
    shortLength <- 1 + 2*K
    ##indexOfLastShort <- shortLength -1 ## this is for zero based
    compositeFilter <- rep(0, 1 + TwoxKplusL)

    shortFilter <- NULL
    longFilter <- NULL
    if(halfLengthFilter1 <= halfLengthFilter2) {
        shortFilter <- filter1
        longFilter <- filter2
    } else {
        shortFilter <- filter2
        longFilter <- filter1
    }
    ## caution indexing swich
    for( j in 1:(1+ KplusL) )
    {
        for( m in 1:min(j, shortLength)) {
            compositeFilter[j] <-  compositeFilter[j] +
                shortFilter[shortLength - m +1] *
                    longFilter[j - m +1]
        }
        compositeFilter[TwoxKplusL -j +2] <-
            compositeFilter[j]
            
    }
    compositeFilter
}

## > composeTwoSymmetricFilters(c(1/4, 1/2, 1/4), c(1/4, 1/2, 1/4))
## [1] 0.0625 0.2500 0.3750 0.2500 0.0625
## > composeTwoSymmetricFilters(c(1/8, 1/4, 1/4, 1/4, 1/8), c(1/4, 1/2, 1/4))
## [1] 0.03125 0.12500 0.21875 0.12500 0.03125
## > composeTwoSymmetricFilters(c(1/4, 1/2, 1/4),
## +                            composeTwoSymmetricFilters(c(1/4, 1/2, 1/4), c(1/4, 1/2, 1/4)))
## [1] 0.015625 0.093750 0.234375 0.312500 0.234375 0.093750 0.015625
## > composeTwoSymmetricFilters(c(0.0625, 0.25, 0.375, 0.25, 0.0625), c(1/4, 1/2, 1/4))
## [1] 0.015625 0.093750 0.234375 0.093750 0.015625
## > composeTwoSymmetricFilters(c(1/4, 1/2, 1/4), c(0.0625, 0.25, 0.375, 0.25, 0.0625))
## [1] 0.015625 0.093750 0.234375 0.312500 0.234375 0.093750 0.015625


##   [44]> (setf a (make-array 5))
## #(NIL NIL NIL NIL NIL)
## [45]> (dotimes (i 5 a) (setf (aref a i) (+ i 0)))
## #(0 1 2 3 4)

## lisp loops start at zero and go to 1-value
## the indexe is 0 

