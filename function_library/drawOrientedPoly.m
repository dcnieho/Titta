function drawOrientedPoly(wpnt,verts,isConvex,depthOri,rotMat,scaleFac,pos,fillClr,edgeClr,edgeWidth)
persistent minSmoothLineWidth
persistent maxSmoothLineWidth
if isempty(minSmoothLineWidth)
    ver = Screen('Version');
    if ver.major==3 && ver.point<16
        % some conservative/reasonable defaults (old PTB doesn't support
        % this)
        minSmoothLineWidth = 1;
        maxSmoothLineWidth = 5;
    else
        [minSmoothLineWidth, maxSmoothLineWidth] = Screen('DrawLines',wpnt);
    end
end

if isempty(verts)
    return;
end
% project. Drop whole denominator to do pure orthographic, but it think it
% looks a bit nicer with some perspective mixed in there. Too much sucks,
% the higher the simulated z, the more pure orthographic is approached. z=5
% looks nice to me
z=5;
% make 3D verts
verts   = [verts(1,:)*cos(depthOri(1)); verts(2,:)*cos(depthOri(2)); z+verts(1,:)*sin(depthOri(1))+verts(2,:)*sin(depthOri(2))];
proj    = bsxfun(@rdivide,verts(1:2,:),verts(3,:))*z;   % depth is defined by x coord as circle is rotated around yaw axis
% rotate image on projection plane for head roll
proj    = rotMat*proj;
% scale and move to right place
proj    = bsxfun(@plus,proj*scaleFac,pos(:));

% draw fill if any
if ~isempty(fillClr) && (isConvex || ~any(isnan(proj(:)))) % isConvex==0 with nan values crashes PTB
    Screen('FillPoly', wpnt, fillClr, proj.', isConvex);
end
% draw edge, if any
if nargin>=10
    len = size(proj,2);
    idxs = reshape([1:len-1;2:len],1,[]);
    Screen('DrawLines', wpnt, proj(:,idxs), max(min(edgeWidth,maxSmoothLineWidth),minSmoothLineWidth), edgeClr, [],2);
end
end
