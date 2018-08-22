function qIn = inRect(xy,rects)

% check if a single x-y coordinate falls in one or more rects, or if a by
% of x-y coordinates fall in a single rect

if numel(xy)==2
    xy = xy(:);
end

qIn = xy(1,:) >= rects(1,:) & ...
      xy(2,:) >= rects(2,:) & ...
      xy(1,:) <= rects(3,:) & ...
      xy(2,:) <= rects(4,:);
end
