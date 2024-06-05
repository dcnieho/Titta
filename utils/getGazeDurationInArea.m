function [dur,currentlyInArea] = getGazeDurationInArea(EThndl,tobiiStartT,tobiiEndT,winRes,poly,qOnlyLastFix)
if isempty(tobiiEndT)
    tobiiEndT = inf;
end
gazeData = EThndl.buffer.peekTimeRange('gaze',tobiiStartT,tobiiEndT);
% average left and right eye, convert to pixels
gazePos = bsxfun(@times,mean(cat(3,gazeData.left.gazePoint.onDisplayArea,gazeData.right.gazePoint.onDisplayArea),3,'omitnan'),winRes(:));
% get episodes gaze is inside area
inside  = inpolygon(gazePos(1,:),gazePos(2,:),poly(1,:),poly(2,:));
[on,off]= bool2bounds(inside);
% determine gaze duration
if ~isempty(on)
    if qOnlyLastFix
        % duration of last episode that gaze was in area
        on = on(end);
        off=off(end);
    else
        % total duration of all gaze in area
    end
    dur = sum(gazeData.systemTimeStamp(off)-gazeData.systemTimeStamp(on));  % microseconds
else
    dur = 0;
end

dur = dur/1000/1000;    % us -> s

% determine if gaze is currently (i.e., at endT) inside the area
currentlyInArea = ~isempty(off) && off(end)==length(inside);
