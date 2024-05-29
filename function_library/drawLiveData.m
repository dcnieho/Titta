function drawLiveData(wpnt,eyeData,dataWindowLength,clrL,clrR,pointSz,scrRes,sFac,offset)

dataWindowLength = dataWindowLength*1000;   % s -> ms

% deal with optional parameters used when live display screen is smaller
% than participant screen
if nargin<8 || isempty(sFac)
    sFac = 1;
end
if nargin<9 || isempty(offset)
    offset = 0;
end

qShowLeft   = ~isempty(clrL);
if qShowLeft
    clrsL   = [clrL; [clrL(1:3) clrL(4)/3]];
end
qShowRight  = ~isempty(clrR);
if qShowRight
    clrsR   = [clrR; [clrR(1:3) clrR(4)/3]];
end
point       = pointSz.*[0 0 1 1];
if ~isempty(eyeData.systemTimeStamp)
    age= double(abs(eyeData.systemTimeStamp-eyeData.systemTimeStamp(end)))/1000;    % ms
    if qShowLeft
        qValid = eyeData. left.gazePoint.valid;
        lE = bsxfun(@plus,bsxfun(@times,eyeData. left.gazePoint.onDisplayArea(:,qValid),scrRes(:))*sFac,offset(:));
        if ~isempty(lE)
            clrs = interp1([0;dataWindowLength],clrsL,age(qValid)).';
            lE = CenterRectOnPointd(point,lE(1,:).',lE(2,:).');
            Screen('FillOval', wpnt, clrs, lE.', 2*pi*pointSz);
        end
    end
    if qShowRight
        qValid = eyeData.right.gazePoint.valid;
        rE = bsxfun(@plus,bsxfun(@times,eyeData.right.gazePoint.onDisplayArea(:,qValid),scrRes(:))*sFac,offset(:));
        if ~isempty(rE)
            clrs = interp1([0;dataWindowLength],clrsR,age(qValid)).';
            rE = CenterRectOnPointd(point,rE(1,:).',rE(2,:).');
            Screen('FillOval', wpnt, clrs, rE.', 2*pi*pointSz);
        end
    end
end