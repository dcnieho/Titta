function [nx, ny, textbounds, cache] = DrawFormattedText2GDI(win, tstring, sx, xalign, sy, yalign, xlayout, baseColor, wrapat, vSpacing, resetStyle, winRect, cacheOnly)
% [nx, ny, textbounds] = DrawFormattedText2GDI(win, tstring [, sx][, sy][, color][, wrapat][, vSpacing][, resetStyle][, winRect][, cacheOnly])
%
% A size/font command before a newline can change the height of that line.
% After the newline it changes the height of the next (new) line. So if you
% want to space two words 'test' and 'text' vertically by white space
% equivalent to 80pts, use: 'test\n<size=80>\n<size>text'. There is an
% empty line between the two new lines, and the size=80 says that this line
% has height of 80pts in the selected font.
%
% One difference in the return values from this function and
% DrawFormattedText is that the new (nx, ny) position of the text drawing
% cursor output is the baseline of the text. So to use (nx,ny) as the new
% start position for connecting further text strings, you need to draw
% these strings with yPositionIsBaseline==true. Another difference is that
% the returned textbounds bounding box includes the height of an empty line
% at the end if the input string ended with a carriage return.
% DrawFormattedText only moved (nx,ny) but did not include the empty line
% in the bounding box. The empty line is also taken into account when
% centering text


%% process input, not in order of input due to interdependencies
if nargin < 1 || isempty(win)
    error('DrawFormattedText2GDI: Windowhandle missing!');
elseif isstruct(win)
    % using cache for drawing
    cache = win;
    ResetTextSetup(cache.win,cache.previous);
    [nx,ny,textbounds] = DoDraw(cache.win,...
        cache.disableClip,...
        cache.px,...
        cache.py,...
        cache.subStrings,...
        cache.switches,...
        cache.fmts,...
        cache.fmtCombs,...
        cache.ssBaseLineOff,...
        cache.winRect,...
        cache.previous);
end

if nargin < 2 || isempty(tstring)
    % Empty text string -> Nothing to do.
    return;
end

% Store data class of input string for later use in re-cast ops:
stringclass = class(tstring);

% Default x start position is left border of window:
xpos = 0;   % default: use provided sx (w.r.t. winRect)
% Default x start position is left of window:
if nargin<3 || isempty(sx)
    sx = 0;
else
    % have text specifying a position at the edge of windowrect?
    if ischar(sx)
        if strcmpi(sx, 'left')
            xpos = 1;
        elseif strcmpi(sx, 'center')
            xpos = 2;
        elseif strcmpi(sx, 'right')
            xpos = 3;
        else
            % Ignore any other crap user may have provided, align to left.
            xpos = 1;
        end
    elseif ~isnumeric(sx)
        % Ignore any other crap user may have provided.
        sx = 0;
    end
end

ypos = 0;   % default: use provided sy (w.r.t. winRect)
% Default y start position is top of window:
if nargin<5 || isempty(sy)
    sy = 0;
else
    % have text specifying a position at the edge of windowrect?
    if ischar(sy)
        if strcmpi(sy, 'top')
            ypos = 1;
        elseif strcmpi(sy, 'center')
            ypos = 2;
        elseif strcmpi(sy, 'bottom')
            ypos = 3;
        else
            % Ignore any other crap user may have provided, align to left.
            ypos = 1;
        end
    elseif ~isnumeric(sy)
        % Ignore any other crap user may have provided.
        sy = 0;
    end
end

%%% now we have a position, figure out how to position box with respect to
%%% that position
% Default x layout is align box to left of specified position
if nargin<4 || isempty(xalign) || ~ischar(xalign)
    xalign = 1;
else
    if strcmpi(xalign, 'left')
        xalign = 1;
    elseif strcmpi(xalign, 'center')
        xalign = 2;
    elseif strcmpi(xalign, 'right')
        xalign = 3;
    else
        % ignore anything else user may have provided
        xalign = 1;
    end
end

% Default y layout is align box below of specified position
if nargin<6 || isempty(yalign) || ~ischar(yalign)
    yalign = 1;
else
    if strcmpi(yalign, 'top')
        yalign = 1;
    elseif strcmpi(yalign, 'center')
        yalign = 2;
    elseif strcmpi(yalign, 'bottom')
        yalign = 3;
    else
        % ignore anything else user may have provided
        yalign = 1;
    end
end

if nargin<7 || isempty(yalign) || ~ischar(xlayout)
    xlayout = 1;
else
    switch xlayout
        case 'left'
            xlayout = 1;
        case 'center'
            xlayout = 2;
        case 'right'
            xlayout = 3;
        otherwise
            % ignore anything else user may have provided
            xlayout = 1;
    end
end

% Keep current text color if none provided:
if nargin < 8 || isempty(baseColor)
    baseColor = Screen('TextColor', win);
    if baseColor(4)==realmax
        % workaround for bug in Screen('TextColor'): if last color set was
        % not RGBA but something with less bits, alpha is set to realmax.
        % We can safely ignore alpha in that case
        baseColor(4) = [];
    end
end

% No text wrapping by default:
if nargin < 9 || isempty(wrapat)
    wrapat = 0;
end

% No vertical mirroring by default:
if nargin < 10 || isempty(vSpacing)
    vSpacing = 1;
end

% reset text style to normal before interpreting formatting commands? If
% not, active text style at function entry is taken into account when
% processing style toggle tags
if nargin < 11 || isempty(resetStyle)
    resetStyle = 1;
end

% Default rectangle for centering/formatting text is the client rectangle
% of the 'win'dow, but usercode can specify arbitrary override as 11'th arg:
if nargin < 12 || isempty(winRect)
    winRect = Screen('Rect', win);
end

% default actually draw input to screen. optionally just provide catch
if nargin < 13 || isempty(cacheOnly)
    cacheOnly = false;
end

% now process xpos and ypos
switch xpos
    case 0
        % provided sx is in winRect
        sx = sx+winRect(1);
    case 1
        sx = winRect(1);
    case 2
        sx = (winRect(1)+winRect(3))/2;
    case 3
        sx = winRect(3);
end
switch ypos
    case 0
        % provided sy is in winRect
        sy = sy+winRect(2);
    case 1
        sy = winRect(2);
    case 2
        sy = (winRect(2)+winRect(4))/2;
    case 3
        sy = winRect(4);
end

% Need different encoding for repchar that matches class of input tstring:
returnChar = cast(10,stringclass);

% Convert all conventional linefeeds into C-style newlines.
% But if '\n' is already encoded as a char(10) as in Octave, then
% there's no need for replacement.
if char(10) ~= '\n' %#ok<STCMP>
    newlinepos = strfind(char(tstring), '\n');
    while ~isempty(newlinepos)
        % Replace first occurence of '\n' by ASCII or double code 10 aka 'repchar':
        tstring = [ tstring(1:min(newlinepos)-1) returnChar tstring(min(newlinepos)+2:end)];
        % Search next occurence of linefeed (if any) in new expanded string:
        newlinepos = strfind(char(tstring), '\n');
    end
end



% string can contain HTML-like formatting commands. Parse them and turn
% them into formatting indicators, then remove them from the string to draw
[tstring,fmtCombs,fmts,switches,previous] = getFormatting(win,tstring,baseColor,resetStyle);
% check we still have anything to render after formatting tags removed
if isempty(tstring)
    % Empty text string -> Nothing to do.
    return;
end

% Text wrapping requested? NB: formatting tags are removed above, so
% wrapping is correct. Also NB that WrapString only replaces spaces by
% linebreaks and thus does not alter the length of the string or where
% words are placed in it. Our codes.style and codes.color vectors thus remain
% correct.
if wrapat > 0
    % Call WrapString to create a broken up version of the input string
    % that is wrapped around column 'wrapat'
    tstring = WrapString(tstring, wrapat);
end

% Cast curstring back to the class of the original input string, to
% make sure special unicode encoding (e.g., double()'s) does not
% get lost for actual drawing:
tstring = cast(tstring, stringclass);

% now, split text into segments, either when there is a carriage return or
% when the format changes
% find format changes
qSwitch = any(switches,1);
% find carriage returns (can occur at same spot as format change)
% make them their on substring so we can process format changes happening
% at the carriage return properly.
qCRet = tstring==returnChar;
qCRet = ismember(1:length(tstring),[find(qCRet) find(qCRet)+1]);
% split strings
qSplit = qSwitch|qCRet;
% subStrings = accumarray(cumsum(qSplit).'+1,tstring(:),[],@(x) {x.'});
% own implementation to make sure it works on all platform (not sure how
% well the accumarray trick works on Octave). Not any slower either
strI = cumsum(qSplit).'+1;
subStrings = cell(strI(end),1);
for p=1:strI(end)
    subStrings{p} = tstring(strI==p);
end
% get which format to use for each substring, and what attributes are
% changed (if any)
fmtCombs = fmtCombs(qSplit);
switches = switches(:,qSplit);
% code when to perform linefeeds.
qLineFeed= cellfun(@(x) ~isempty(x) && x(1)==returnChar,subStrings).';
% we have an empty up front if there is a format change or carriage return
% first in the string
if isempty(subStrings{1}) && ~qCRet(1)
    % remove it if it is a switch from the default format, but not if we
    % start with a carriage return
    subStrings(1) = [];
    qLineFeed(1)  = [];
else
    % we also need to know about the substring before the first split
    fmtCombs = [1          fmtCombs];
    switches = [false(4,1) switches];
end
% if trailing carriage return, this should lead to a trailing empty line,
% add it here.
if tstring(end)==returnChar
    subStrings{end+1}   = '';
    fmtCombs(end+1)     = fmtCombs(end);
    switches(:,end+1)   = switches(:,end);
    qLineFeed(end+1)    = false;
end
% remove those linefeeds from the characters to draw
subStrings(qLineFeed) = cellfun(@(x) x(2:end),subStrings(qLineFeed),'uni',false);
% NB: keep substrings that are now empty as they still signal linefeeds and
% empty lines, and format changes can still occur for those empty substrings

% get number of lines.
numlines   = length(strfind(char(tstring), char(10))) + 1;
% vectors for width and height of each line, as well as starting x
lWidth          = zeros(1,numlines);
lHeight         = zeros(1,numlines);
lBaseLineOff    = zeros(2,numlines);
sWidth          = zeros(1,length(subStrings));
px              = zeros(1,length(subStrings));
py              = zeros(1,length(subStrings));
% get which substring belong to each line
substrIdxs      = [0 cumsum(qLineFeed(1:end-1))];
if ~qLineFeed(1)
    substrIdxs = substrIdxs+1;
end
% process each line, keep some variables per segment
ssHeights     = zeros(1,length(subStrings));
ssBaseLineOff = zeros(2,length(subStrings));
for p=1:numlines
    % get which substrings belong to this line
    qSubStr = substrIdxs==p;
    
    % to get line width and height, get textbounds of each string and add
    % them together
    for q=find(qSubStr)
        % do format change if needed
        if any(switches(:,q))
            fmt = fmts(:,fmtCombs(q));
            DoFormatChange(win,switches(:,q),fmt);
        end
        if isempty(subStrings{q})
            [nbox,bbox] = Screen('TextBounds', win,           'X',0,0,1);
        else
            [nbox,bbox] = Screen('TextBounds', win, subStrings{q},0,0,1);
            sWidth(q) = nbox(3);
        end
        ssHeights(q) = nbox(4);
        ssBaseLineOff(:,q) = abs(bbox([2 4])+1);  % off by 1 in the C code (line 1157 in Psychtoolbox-3 / PsychSourceGL / Source / Common / Screen / SCREENDrawText.c)?
    end
    
    % get width of each line
    lWidth(p)  = sum(sWidth(qSubStr));
    
    % get text height. Vertical spacing of this function is not like
    % DrawFormattedText, where text height is simply textsize. This ignores
    % vertical descenders and is overall a crude estimate. Here we use
    % bounding box instead of textsize as the base height.
    lHeight(p) = max(ssHeights(qSubStr));
    
    % get largest offset of ink from baseline for each line
    lBaseLineOff(:,p)   = [min(ssBaseLineOff(1,qSubStr)) max(ssBaseLineOff(2,qSubStr))];
end
% don't forget to set style back to what it should be
ResetTextSetup(win,previous);

% now place lines. first place bounding box
mWidth      = max(lWidth);
totHeight   = lBaseLineOff(1,1) + sum(round((.22*lHeight(1:end-1)+.78*lHeight(2:end))*vSpacing)) + lBaseLineOff(2,end);
bbox        = [0 0 mWidth totHeight];
bWidth = bbox(3)-bbox(1);
bHeight= bbox(4)-bbox(2);

switch xalign
    case 1
        xoff = 0;
    case 2
        xoff = -bWidth/2;
    case 3
        xoff = -bWidth;
end
switch yalign
    case 1
        yoff = 0;
    case 2
        yoff = -bHeight/2;
    case 3
        yoff = -bHeight;
end

bbox = OffsetRect(bbox,sx+xoff,sy+yoff);

% now, figure out where to place individual lines and substrings into this
% bbox
for p=1:numlines
    % get which substrings belong to this line
    qSubStr = substrIdxs==p;
    idxs = find(qSubStr);
    
    % get center of line w.r.t. bbox left edge
    switch xlayout
        case 1
            % align to left at sx
            lc  = lWidth(p)/2;
        case {2,4}
            % center or justify line in bbox
            lc  = (bbox(3)-bbox(1))/2;
        case 3
            % align to right of window
            lc  = bbox(3)-bbox(1) - lWidth(p)/2;
    end
    off =  cumsum([0 sWidth(idxs(1:end-1))]) - lWidth(p)/2;
    px(qSubStr) = lc+off;
    
    if p>1
        % add baseline skip for current line if not first line, thats the
        % carriage return. See note above about how Word does text layout.
        idx = find(qSubStr,1,'first');
        py(idx:end) = py(idx) + round((.22*lHeight(p-1)+.78*lHeight(p))*vSpacing);
    else
        % we're drawing with yPositionIsBaseline==true, correct for that
        py(:) = min(ssBaseLineOff(1,qSubStr));
    end
end
% now we have positions in the bbox, add bbox position to place them in the
% right place on the screen
px = px+bbox(1);
py = py+bbox(2);

%% done processing inputs, do text drawing
% Disable culling/clipping if bounding box is requested as 3rd return
% argument, or if forcefully disabled. Unless clipping is forcefully
% enabled.
disableClip = nargout >= 3;

if ~cacheOnly
    [nx,ny,textbounds] = DoDraw(win,disableClip,px,py,subStrings,switches,fmts,fmtCombs,ssBaseLineOff,winRect,previous);
else
    [nx,ny] = deal([]);
    textbounds = bbox;
end
if nargout>3
    % make cache
    cache.win = win;
    cache.disableClip = disableClip;
    cache.px = px;
    cache.py = py;
    cache.bbox = textbounds;
    cache.subStrings = subStrings;
    cache.switches = switches;
    cache.fmts = fmts;
    cache.fmtCombs = fmtCombs;
    cache.ssBaseLineOff = ssBaseLineOff;
    cache.winRect = winRect;
    cache.previous = previous;
end


function [nx,ny,textbounds] = DoDraw(win,disableClip,px,py,subStrings,switches,fmts,fmtCombs,ssBaseLineOff,winRect,previous)


% Is the OpenGL userspace context for this 'windowPtr' active, as required?
[previouswin, IsOpenGLRendering] = Screen('GetOpenGLDrawMode');

% OpenGL rendering for this window active?
if IsOpenGLRendering
    % Yes. We need to disable OpenGL mode for that other window and
    % switch to our window:
    Screen('EndOpenGL', win);
end

% Init bbox:
minx = inf;
miny = inf;
maxx = 0;
maxy = 0;

% Draw the substrings
for p=1:length(subStrings)
    curstring = subStrings{p};
    yp = py(p);
    xp = px(p);
    
    % do format change if needed
    if any(switches(:,p))
        fmt = fmts(:,fmtCombs(p));
        DoFormatChange(win,switches(:,p),fmt);
    end
    
    % Perform crude clipping against upper and lower window borders for this text snippet.
    % If it is clearly outside the window and would get clipped away by the renderer anyway,
    % we can safe ourselves the trouble of processing it:
    if ~isempty(curstring) && (disableClip || ((yp + ssBaseLineOff(2,p) >= winRect(2)) && (yp + ssBaseLineOff(1,p) <= winRect(4))))
        % Inside crude clipping area. Need to draw.
        clipOrEmpty = false;
    else
        % Skip this text line draw call, as it would be clipped away
        % anyway.
        clipOrEmpty = true;
    end
    
    % Any string to draw?
    if ~clipOrEmpty
        if IsWin && isa(curstring, 'char')
            % On Windows, a single ampersand & is translated into a control
            % character to enable underlined text. To avoid this and actually
            % draw & symbols in text as & symbols in text, we need to store
            % them as two && symbols. -> Replace all single & by &&.
            % Only works with characters, not doubles, so we can't do this
            % when string is represented as double-encoded Unicode.
            pos = strfind(curstring, '&');
            for q=length(pos):-1:1
                curstring     = [curstring(1:pos(q)) '&' curstring(pos(q)+1:end)];
            end
        end
        
        [nx,ny] = Screen('DrawText', win, curstring, xp, yp,[],[],1);
        
        % for debug, draw bounding box and baseline
        % [~,bbox] = Screen('TextBounds', win, curstring, xp, yp ,1);
        % Screen('FrameRect',win,[0 255 0],bbox);
        % Screen('DrawLine',win,[0 255 255],xp,yp,nx,ny);
    else
        % This is an empty substring (pure linefeed). Just update cursor
        % position:
        nx = xp;
        ny = yp;
    end
    
    % Update bounding box:
    minx = min([minx , xp, nx]);
    maxx = max([maxx , xp, nx]);
    miny = min([miny , yp, ny-ssBaseLineOff(1,p)]);
    maxy = max([maxy , yp, ny+ssBaseLineOff(2,p)]);
end

% Create final bounding box:
textbounds = [minx, miny, maxx, maxy];

% Create new cursor position. The cursor is positioned to allow
% to continue to print text directly after the drawn text (if you set
% yPositionIsBaseline==true at least)
% Basically behaves like printf or fprintf formatting.
nx = xp;
ny = yp;

% Our work is done. clean up
% reset text style etc
ResetTextSetup(win,previous);

% If a different window than our target window was active, we'll switch
% back to that window and its state:
if previouswin > 0
    if previouswin ~= win
        % Different window was active before our invocation:
        
        % Was that window in 3D mode, i.e., OpenGL rendering for that window was active?
        if IsOpenGLRendering
            % Yes. We need to switch that window back into 3D OpenGL mode:
            Screen('BeginOpenGL', previouswin);
        else
            % No. We just perform a dummy call that will switch back to that
            % window:
            Screen('GetWindowInfo', previouswin);
        end
    else
        % Our window was active beforehand.
        if IsOpenGLRendering
            % Was in 3D mode. We need to switch back to 3D:
            Screen('BeginOpenGL', previouswin);
        end
    end
end

return;



%% helpers
function [tstring,fmtCombs,fmts,switches,previous] = getFormatting(win,tstring,startColor,resetStyle)
% This function parses tags out of the text and turns them into formatting
% textstyles, colors, font and text sizes to use when drawing.
% allowable codes:
% - <i> To toggle italicization
% - <b> To toggle bolding
% - <u> To toggle underlining
% - <color=HEX>   To switch to a new color
% - <font=name>   To switch to a new font
% - <size=number> To switch to a new font size
% The <color>, <font> and <size> tags can be provided empty (i.e., without
% argument), in which case they cause to revert back to the color, font or
% size active before the previous switch. Multiple of these in a row go
% back further in history (until start color, font, size is reached).
% To escape a tag, prepend it with a slash, e.g., /<color>. If you want a
% slash right in front of a tag, escape it by making it a double /. All
% other slashes should not be escaped.

% get current active text options
previous.style  = Screen('TextStyle', win);
previous.size   = Screen('TextSize' , win);
previous.font   = Screen('TextFont' , win);
% baseColor is given as input as its convenient for user to be able to set
% it and consistent with other text drawing functions.
previous.color  = startColor;    % keep copy of numeric representation (if its hex, its converted to numeric below when checking base.color)

% get starting text options
base = previous;
if resetStyle
    base.style = 0;
end

% convert color to hex
if isnumeric(base.color)
    % convert to hex
    base.color = sprintf('%0*X',[repmat(2,size(base.color));base.color]);
    % TODO: what to do if floating point buffer and colors range from 0--1?
    % What to do about high precision (10bit) value specs?
else
    % if user provided hex input, store in format we can use in PTB later
    previous.color = hex2dec(reshape(previous.color,2,[]).').';
end

% prepare outputs
% these outputs have same length as string to draw and for each character
% indicate its style and color
codes.style     = repmat(base.style,size(tstring));
tables.color    = {base.color};
tables.font     = {base.font};
codes.color     = ones(size(tstring));                  % 1 indicates startColor, all is in startColor unless user provides color tags telling us otherwise
codes.font      = codes.color;                          % 1 indicates default font, all is in default font unless user provides color tags telling us otherwise
codes.size      = repmat(previous.size,size(tstring));

%% first process tags that don't have further specifiers (<b>, <i>, <u>)
% find tag locations. (?<!(?<!/)/) matches tags with zero or more than one
% slashes in front of them
[tagis ,tagie ,tagt ] = regexp(tstring,'(?i)(?<!(?<!/)/)<(i|b|u)>','start','end','tokens');
if ~isempty(tagis)
    % get full text for each tags and indices to where it is in the input
    % string
    tagi  = [tagis; tagie].';
    tagt  = cat(1,tagt{:});
    
    % fill up output, indicating the style code applicable to each
    % character
    if ~isempty(tagt)
        currStyle = codes.style(1);
        for p=1:length(tagt)
            % the below code snippet is a comment, decribing what the line
            % below does
            % switch formatCodes{p}
            %     case 'i'
            %         fBit = log2(2)+1;
            %     case 'b'
            %         fBit = log2(1)+1;
            %     case 'u'
            %         fBit = log2(4)+1;
            % end
            fBit = floor((double(tagt{p})-'b')/7)+1;
            currStyle = bitset(currStyle,fBit,~bitget(currStyle,fBit));
            codes.style(tagi(p,2):end) = currStyle;
        end
    end
    % now mark active formatting commands to be stripped from text
    toStrip = bsxfun(@plus,tagi(:,1),0:2);      % tags are always three characters long
    toStrip = toStrip(:).';
else
    toStrip = [];
end

%% now process tag that have further specifiers (<color=x>, <font=x>, <size=x>)
% find tag locations. also match empty tags. even if only empty tags, we
% still want to remove them. Ill formed tags with equals sign but no
% argument, or tags with tags inside, are not matched. (?<!(?<!/)/) matches
% tags with zero or more than one slashes in front of them
[tagis ,tagie ,tagt ] = regexp(tstring,'(?i)(?<!(?<!/)/)<(color|font|size)=([^<>]+?)>|(?<!(?<!/)/)<(color|font|size)>','start','end','tokens');
if ~isempty(tagis)
    % get full text for each tags and indices to where it is in the input
    % string
    tagi  = [tagis; tagie].';
    
    % use a simple stack/state machine as we need to maintain a history.
    % empty tags means go back to previous color/size/font
    % (crappy stacks, end of array is top of stack)
    colorStack = 1;         % index in tables.color
    fontStack  = 1;         % index in tables.font
    sizeStack  = codes.size(1);
    
    for p=1:size(tagi,1)
        % check if tag has argument
        if ~isscalar(tagt{p})
            switch tagt{p}{1}
                case 'color'
                    color = tagt{p}{2};
                    % check color is valid
                    assert(any(length(color)==[1 2 6 8]),'DrawFormattedText2GDI: color tag argument must be a hex value of length 1, 2, 6, or 8')
                    assert(all(isstrprop(color,'xdigit')),'DrawFormattedText2GDI: color tag argument must be specified in hex values')
                    % find new color or add to table
                    iColor = find(strcmpi(tables.color,color),1);
                    if isempty(iColor)
                        tables.color{end+1} = upper(color);
                        iColor = length(tables.color);
                    end
                    % add to stack front
                    colorStack(end+1) = iColor; %#ok<AGROW>
                    % mark all next text as having this color
                    codes.color(tagi(p,2):end) = iColor;
                case 'font'
                    font = tagt{p}{2};  % no checks on whether it is valid
                    % find new color or add to table
                    iFont = find(strcmpi(tables.font,font),1);
                    if isempty(iFont)
                        tables.font{end+1} = font;
                        iFont = length(tables.font);
                    end
                    % add to stack front
                    fontStack(end+1) = iFont; %#ok<AGROW>
                    % mark all next text as having this color
                    codes.font(tagi(p,2):end) = iFont;
                case 'size'
                    fsize = str2double(tagt{p}{2});
                    assert(~isnan(fsize),'DrawFormattedText2GDI: size tag argument must be a number')
                    % add to stack front
                    sizeStack(end+1) = fsize; %#ok<AGROW>
                    % mark all next text as having this color
                    codes.size(tagi(p,2):end) = fsize;
            end
        else
            switch tagt{p}{1}
                case 'color'
                    % if not already reached end of history, revert to
                    % previous color for rest of text
                    if ~isscalar(colorStack)
                        % pop color of stack
                        colorStack(end) = [];
                        % mark all next text as having this color
                        codes.color(tagi(p,2):end) = colorStack(end);
                    end
                case 'font'
                    % if not already reached end of history, revert to
                    % previous color for rest of text
                    if ~isscalar(fontStack)
                        % pop font of stack
                        fontStack(end) = [];
                        % mark all next text as having this font
                        codes.font(tagi(p,2):end) = fontStack(end);
                    end
                case 'size'
                    % if not already reached end of history, revert to
                    % previous color for rest of text
                    if ~isscalar(sizeStack)
                        % pop size of stack
                        sizeStack(end) = [];
                        % mark all next text as having this size
                        codes.size(tagi(p,2):end) = sizeStack(end);
                    end
            end
        end
    end
    
    % now mark active formatting commands to be stripped from text (NB:
    % despite growing array, this is faster than something preallocated)
    for p=1:size(tagi,1)
        toStrip = [toStrip tagi(p,1):tagi(p,2)]; %#ok<AGROW>
    end
end
% now strip active formatting commands from text
% add escape slashes from any escaped tags. also when double slashed,
% we should remove one
toStrip = [toStrip regexp(tstring,'(?i)/<(i|b|u|color|font|size)','start')];
tstring    (toStrip) = [];
codes.style(toStrip) = [];
codes.color(toStrip) = [];
codes.font (toStrip) = [];
codes.size (toStrip) = [];

% process colors, hex->dec
for p=1:length(tables.color)
    % above we made sure all colors are uppercase and valid hex
    % then, convert letter to their numerical value
    % -48 for numbers (ascii<=64)
    % -55 for letters (ascii>64)
    tables.color{p} = tables.color{p}-48-(tables.color{p}>64)*7;
    % then, sum in pairs, while multiplying first of each pair by its base, 16
    tables.color{p} = sum([tables.color{p}(1:2:end)*16;tables.color{p}(2:2:end)]);
end

% consolidate codes into one, indicating unique combinations. Also produce
% four boolean vectors indicating what changed upon a style change.
% last, output a table that for each unique combination indicates what the
% style, font, color and size are
c = [codes.style; codes.color; codes.font; codes.size];
% where do changes occur?
switches = logical(diff([[previous.style; 1; 1; previous.size] c],[],2));
% get unique formats and where each of these formats is to be applied
if 0
    [format,~,fmtCombs] = unique(c.','rows');
    format = format.';
    fmtCombs = fmtCombs.';
else
    % do required functionality myself to be way faster
    i=sortrowsc(c.',1:4);
    groupsSortA = [true any(c(:,i(1:end-1)) ~= c(:,i(2:end)),1)];
    format = c(:,i(groupsSortA));
    fmtCombs = cumsum(groupsSortA);
    fmtCombs(i) = fmtCombs;
end
% build table with info about each unique format combination
fmts = num2cell(format);
% two columns are indices into table, do indexing
fmts(2,:) = tables.color(format(2,:));
fmts(3,:) = tables.font (format(3,:));


function DoFormatChange(win,switches,fmt)
% rows in switches / columns in format:
% 1: style, 2: color, 3: font, 4: size

% font and style: if we cange font, always set style with the same
% command. Always works and sometimes needed with some exotic fonts
% (see Screen('TextFont?') )
if switches(3)
    Screen('TextFont', win,fmt{3},fmt{1});
elseif switches(1)
    Screen('TextStyle',win,fmt{1});
end
% color, set through this command. drawing commands below do not
% set color
if switches(2)
    Screen('TextColor',win,fmt{2});
end
% size
if switches(4)
    Screen('TextSize',win,fmt{4});
end

function ResetTextSetup(win,previous)
Screen('TextFont',win,previous.font,previous.style);
Screen('TextSize',win,previous.size);
Screen('TextColor',win,previous.color); % setting the baseColor input, not color before function entered. Consistent with other text drawing functions
