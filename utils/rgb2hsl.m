function hsl = rgb2hsl(rgb)
% takes 0-255 rgb values, outputs 0-1 hsv values
rgb = rgb(:,1:3)/255;
mx=max(rgb,[],2);%max of the 3 colors
mn=min(rgb,[],2);%min of the 3 colors

L = (mx + mn) / 2;
if (mx == mn)
    H = 0;
    S = 0;
else
    d = mx - mn;
    if L > 0.5
        S = d / (2 - mx - mn);
    else
        S = d / (mx + mn);
    end
    switch (mx)
        case rgb(1)
            H = (rgb(2) - rgb(3)) / d;
            if rgb(2)<rgb(3)
                H = H+6;
            end
        case rgb(2)
            H = (rgb(3) - rgb(1)) / d + 2;
        case rgb(3)
            H = (rgb(1) - rgb(2)) / d + 4;
    end
    H = H/6;
end

% output (all [0 1] range), maps onto 0-360 deg for H, 0-100% for the
% others
hsl=[H, S, L];
end