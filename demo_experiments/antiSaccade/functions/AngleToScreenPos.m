function pos = AngleToScreenPos(tAngle_, uFOV_)
% Convert angle (in degrees) away from center of screen to position ([-1,1]
% coordinate system), given FOV in degrees
% 
% Input should be a horizontal angle and the horizontal FOV, or a
% vertical angle and the vertical FOV.
%
% Derivation for horizontal case (exactly the same for vertical!):
% tan(uFOV/2) = (ScreenWidth/2)/view_dist
% tan(angle)  = pos/viewdist
% thus:
% (ScreenWidth/2)/tan(uFOV/2) = pos/tan(angle)
%
% tan(angle)  = pos*tan(uFOV/2)/(ScreenWidth/2)
% simplify: because screen coordinate system is from [-1 1], ScreenWidth/2 = 1
% thus: 
% pos         = tan(angle)/tan(uFOV/2)

pos = tand(tAngle_)./tand(uFOV_/2);