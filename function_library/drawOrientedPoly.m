function drawOrientedPoly(wpnt,verts,isConvex,depthOri,rotMat,scaleFac,pos,fillClr,edgeClr,edgeWidth)
if isempty(verts)
    return;
end
% project. Drop whole denominator to do pure orthographic, but it think it
% looks a bit nicer with some perspective mixed in there. Too much sucks,
% the higher the simulated z, the more pure orthographic is approached. z=5
% looks nice to me
z=5;
depthOri = depthOri*1.25;   % exaggerate head depth rotation a bit, looks more like the eye images and simply makes it more visible
proj = bsxfun(@rdivide,[verts(1,:)*cos(depthOri); verts(2,:)],(z+verts(1,:)*sin(depthOri)))*z; % depth is defined by x coord as circle is rotated around yaw axis
% rotate image on projection plane for head roll
proj = rotMat*proj;
% scale and move to right place
proj = bsxfun(@plus,proj*scaleFac,pos(:));

% draw fill if any
if ~isempty(fillClr)
    Screen('FillPoly', wpnt, fillClr, proj.', isConvex);
end
% draw edge, if any
if nargin>=10
    len = size(proj,2);
    idxs = reshape([1:len-1;2:len],1,[]);
    Screen('DrawLines', wpnt, proj(:,idxs), edgeWidth, edgeClr, [],2);
end
end
