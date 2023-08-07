function [y,usedmu] = truncExpRand(s,mu,lower,upper,doFixUpMean)
% [y,usedmu] = truncExpRand(s,mu,lower,upper,doFixUpMean)
% generate random numbers from a truncated exponential distribution
% s is the shape of the output, [M N ...]
%
% See also truncExpRandDiscrete
%
% example:
% [a,usedmu]=truncExpRand([1,10000000],500,200,5000);
% hist(a,1000)
% mean(a)
%
% NB: due to truncation, the mean of the sample does not equal the
% requested mean. This can be fixed up through a quick optimization
% procedure (idea courtesy of Jeff Mulligan, see
% https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2008&L=EYE-MOVEMENT&O=D&P=2504).
% This changes the rate parameter (1/mu) of the exponential distribution so
% that the requested mean is achieved:
% [a,usedmu]=truncExpRand([1,10000000],500,200,5000,true);
% hist(a,1000)
% mean(a)
%
% NB further that while this distribution is used to e.g. create a constant
% Hazard function (constant conditional probability that stimulus appears
% at time t given that it did not appear yet) for stimulus appearance,
% truncating it makes that impossible. To see the achieved conditional
% probabilities:
%
% exppdf = @(x,mu) exp(-x ./ mu) ./ mu;
% vals= 200:5000;
% p   = exppdf(vals,usedmu);
% cumprob = fliplr(cumsum(fliplr(p)));
% condprob = p./cumprob;
% plot(vals,condprob)
%
% This code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

expcdf = @(x,mu) -expm1(-(x./mu));
expinv = @(p,mu) mu .* -log1p(-p);

if nargin>4 && doFixUpMean
    % because of truncation, mean of sample is not equal to requested mean.
    % correct for this so that sample has wanted mean
    currentmean = @(mu) (exp(-lower/mu)*(lower+mu)-exp(-upper/mu)*(upper+mu))/(expcdf(upper,mu)-expcdf(lower,mu));
    targetmean  = mu;
    usedmu      = fminsearch(@(mu) abs(targetmean-currentmean(mu)),mu);
else
    usedmu      = mu;
end

plower =expcdf(lower,usedmu);
pupper =expcdf(upper,usedmu);

pin = rand(s);

% go through invCDF: inverse transform sampling
p = plower + pin*(pupper-plower);   % truncate and scale so that integral of truncated distribution is 1
y = expinv(p,usedmu);
