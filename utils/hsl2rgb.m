function rgb = hsl2rgb(hsl)
% takes 0-1 hsl values, outputs 0-255 rgb values
S = hsl(:,2);
L = hsl(:,3);
q = L.*(1 + S).*(L<0.5) + (L+S-L.*S).*(L>=0.5);
p = repmat(2.*L - q,1,3);
q = repmat(q       ,1,3);
t = [mod(hsl(:,1) + 1/3, 1), hsl(:,1) , mod(hsl(:,1) - 1/3, 1)];

rgb = 0 ...
    + (t < 1/6)            .* (p + (q - p) .* 6 .* t) ...
    + (t >= 1/6 & t < 1/2) .* q ...
    + (t >= 1/2 & t < 2/3) .* (p + (q - p) .* (2/3 - t) .* 6) ...
    + (t >= 2/3)           .* p;

rgb = rgb*255;
end