function data = convToDeg(gazeData,geom)
% distance w.r.t. center of screen, which is at (0.5,0.5)

% 1. get center of screen in UCS
xVec    = geom.displayArea.topRight    - geom.displayArea.topLeft;
yVec    = geom.displayArea.bottomRight - geom.displayArea.topRight;
refPos  = geom.displayArea.topLeft + 0.5*xVec + 0.5*yVec;

% 2. get direction of offset on screen, so we can decompose angle below
offOnScreenADCS  = gazeData.gazePoint.onDisplayArea-[.5 .5].';
offOnScreenCm    = offOnScreenADCS .* [geom.displayArea.width geom.displayArea.height].';
offOnScreenDir   = atan2(offOnScreenCm(2,:),offOnScreenCm(1,:));

% 3. get anglular distance refpoint->gazepoint, as seen from eye's position
vecToPoint  = refPos - gazeData.gazeOrigin.inUserCoords;
gazeVec     = gazeData.gazePoint.inUserCoords - gazeData.gazeOrigin.inUserCoords;
angs2D      = AngleBetweenVectors(vecToPoint,gazeVec);

% 4. decompose this 2D angular distance into x and y components
out         = angs2D .* [cos(offOnScreenDir); sin(offOnScreenDir)];
data.x      = out(1,:);
data.y      = out(2,:);
end


function angle = AngleBetweenVectors(a,b)
angle = atan2(sqrt(sum(cross(a,b,1).^2,1)),dot(a,b,1))*180/pi;
end