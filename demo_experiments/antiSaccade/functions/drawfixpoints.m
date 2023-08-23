function drawfixpoints(wpnt,pos,type,sz,color,eye)

for r=1:length(type)
    % get setup for this fixation point. Unrolled from using structfun with
    % error handler as it saves a factor 23 (and still a factor 7 when set
    % up such that the errorhandler is not needed)
    fp.type     = type{r};
    fp.size     = sz{r};
    fp.color    = color{r};
    fp.xPix     = pos(1);
    fp.yPix     = pos(2);
    
    drawfixpoint(wpnt,fp,eye);
end