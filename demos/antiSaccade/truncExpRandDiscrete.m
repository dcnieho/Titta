function y = truncExpRandDiscrete(s,mu,vals)
% y = truncExpRand(s,mu,lower,upper)
% generate random numbers from a truncated exponential distribution
% sampled at the provided values. So output only contains values in vals
% s is the shape of the output, [M N ...]
%
% See also truncExpRand
%
% example:
% vals=[1000:1000/60:3500];
% s=truncExpRandDiscrete([1,1000000],1500,vals);
% n=histc(s,vals);
% p=exppdf(vals,1500);
% bar(vals,n./sum(n),'histc')
% hold on, plot(vals,p./sum(p),'r')

exppdf = @(x,mu) exp(-x ./ mu) ./ mu;

ps     = exppdf(vals,mu);
cdf    = cumsum(ps(:))./sum(ps);

% do inverse transform sampling, using emperical cdf
pin    = rand(s);

% bin the samples, as cdf is discrete
[~,x]  = histc(pin,[0;cdf]);

y      = vals(x);