function [y,usedmu] = truncExpRandDiscrete(s,mu,vals,doFixUpMean)
% [y,usedmu] = truncExpRandDiscrete(s,mu,vals,doFixUpMean)
% generate random numbers from a truncated exponential distribution
% sampled at the provided values. So output only contains values in vals
% s is the shape of the output, [M N ...]
%
% See also truncExpRand
%
% example:
% isi = 1000/60;
% vals= [1000:isi:3500];
% [s,usedmu] = truncExpRandDiscrete([1,10000000],1500,vals);
% n   = histc(s,vals);
% p   = exppdf(vals,1500);
% bar(vals,n./sum(n),'histc')
% hold on, plot(vals+isi/2,p./sum(p),'r')
% mean(s)
%
% NB: due to truncation, the mean of the sample does not equal the
% requested mean. This can be fixed up through a quick optimization
% procedure (idea courtesy of Jeff Mulligan, see
% https://www.jiscmail.ac.uk/cgi-bin/wa-jisc.exe?A2=ind2008&L=EYE-MOVEMENT&O=D&P=2504).
% This changes the rate parameter (1/mu) of the exponential distribution so
% that the requested mean is achieved:
% [s,usedmu]=truncExpRandDiscrete([1,1000000],1500,vals,true);
% mean(s)
% Note that this is still not perfect due to discretization of the output
% (correction is done for an continuous distribution), but close (for the
% parameters of this example).
%
% NB further that while this distribution is used to e.g. create a constant
% Hazard function (constant conditional probability that stimulus appears
% at time t given that it did not appear yet) for stimulus appearance,
% truncating it makes that impossible. To see the achieved conditional
% probabilities:
%
% exppdf = @(x,mu) exp(-x ./ mu) ./ mu;
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

exppdf = @(x,mu) exp(-x ./ mu) ./ mu;

if nargin>3 && doFixUpMean
    % because of truncation, mean of sample is not equal to requested mean.
    % correct for this so that sample has wanted mean
    lower       = min(vals);
    upper       = max(vals);
    expcdf      = @(x,mu) -expm1(-(x./mu));
    currentmean = @(mu) (exp(-lower/mu)*(lower+mu)-exp(-upper/mu)*(upper+mu))/(expcdf(upper,mu)-expcdf(lower,mu));
    targetmean  = mu;
    usedmu      = fminsearch(@(mu) abs(targetmean-currentmean(mu)),mu);
else
    usedmu      = mu;
end

ps     = exppdf(vals,usedmu);
cdf    = cumsum(ps(:))./sum(ps);

% do inverse transform sampling, using emperical cdf
pin    = rand(s);

% now use the cdf to look up the corresponding value from vals for each
% sample
y      = interp1(cdf,vals,pin,'next','extrap'); % extrap needed as interval (0, cdf(1)] is outside the input range and would map to nan otherwise
