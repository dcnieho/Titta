function hsl = rgb2hsl(rgb)
% takes 0-255 rgb values, outputs 0-1 hsv values
rgb = rgb(:,1:3)/255;
mx=max(rgb,[],2);%max of the 3 colors
mn=min(rgb,[],2);%min of the 3 colors
d = mx - mn;

% luminance
L = (mx + mn) / 2;

% saturation
S = d./(mx + mn).*(L <= 0.5) + d./(2-mx-mn).*(L > 0.5);

% Hue
H = 0 ...
    + (mx == rgb(:,1)) .* ((rgb(:,2) - rgb(:,3))./d + 6.*(rgb(:,2)<rgb(:,3))) ...
    + (mx == rgb(:,2)) .* ((rgb(:,3) - rgb(:,1))./d + 2)                      ...
    + (mx == rgb(:,3)) .* ((rgb(:,1) - rgb(:,2))./d + 4);
H = H/6;

% correct for achromatic
gray = (mn == mx);
S(gray) = 0;
H(gray) = 0;

% output (all [0 1] range), maps onto 0-360 deg for H, 0-100% for the
% others
hsl=[H, S, L];
end