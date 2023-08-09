function img = drawAOIsOnImage(img,q,clr,t)
% img = drawAOIsOnImage(img,q,clr,t)
%
% Takes an AOI boolean matrix (a matrix with the same resolution as the
% image, and which is true at locations inside the AOI and false everywhere
% else) and plot it on the image. At the AOI locations the provided color
% will be added to the image with the indicated transparency value, the
% rest or the image remains untouched. The edge of the AOI will be written
% with transparency t(2), the rest with t(1).

assert(all(AltSize(img,[1 2])==size(q)),'image and mask do not match in size')
if size(img,3)==1
    img = repmat(img,[1 1 3]);
end
if isa(img,'uint16')
    img = uint8(img ./ 256);
end

if ~isscalar(t) && exist('bwperim','file')==2
    % get perimeter
    perim = bwperim(q,8);
    inner = q & ~perim;

    img = transBoolean(img,inner,clr,t(1));
    img = transBoolean(img,perim,clr,t(2));
else
    img = transBoolean(img,q,clr,t(1));
end



function img = transBoolean(img,q,clr,t)
temp            = zeros(size(img,1),size(img,2),3);
blank           = temp(:,:,1);

for p=1:3
    temp2       = blank;
    temp2(q)    = clr(p);
    temp(:,:,p) = temp2;
end

% make 3D boolean
q       = cat(3,q,q,q);

% add the images
plaat   = uint8(round((1-t)*img)) + uint8(round((t)*temp));

% replace only those pixels where boolean is true
img(q)  = plaat(q);
