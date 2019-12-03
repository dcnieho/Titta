function y = truncExpRandDiscrete(s,mu,vals)
% y = truncExpRand(s,mu,lower,upper)
% generate random numbers from a truncated exponential distribution
% sampled at the provided values. So output only contains values in vals
% s is the shape of the output, [M N ...]
%
% See also truncExpRand
%
% example:
% isi = 1000/60;
% vals= [1000:isi:3500];
% s   = truncExpRandDiscrete([1,30000000],1500,vals);
% n   = histc(s,vals);
% p   = exppdf(vals,1500);
% bar(vals,n./sum(n),'histc')
% hold on, plot(vals+isi/2,p./sum(p),'r')

exppdf = @(x,mu) exp(-x ./ mu) ./ mu;

ps     = exppdf(vals,mu);
cdf    = cumsum(ps(:))./sum(ps);

% do inverse transform sampling, using emperical cdf
pin    = rand(s);

% now use the cdf to look up the corresponding value from vals for each
% sample
y      = interp1(cdf,vals,pin,'next','extrap'); % extrap needed as interval (0, cdf(1)] is outside the input range and would map to nan otherwise
