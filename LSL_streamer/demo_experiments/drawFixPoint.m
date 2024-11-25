function drawFixPoint(wpnt,pos,sz,fixBackColor,fixFrontColor)
% draws Thaler et al. 2012's ABC fixation point
for p=1:size(pos,1)
    rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
    rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
    Screen('gluDisk', wpnt, fixBackColor, pos(p,1), pos(p,2), sz(1)/2);
    Screen('FillRect',wpnt,fixFrontColor, rectH);
    Screen('FillRect',wpnt,fixFrontColor, rectV);
    Screen('gluDisk', wpnt, fixBackColor, pos(p,1), pos(p,2), sz(2)/2);
end