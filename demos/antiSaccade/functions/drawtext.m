function swaptime = drawtext(text, textSetup, w, flipWhen, qCenterEachLine)
if nargin<5 || ~isempty(qCenterEachLine)
    qCenterEachLine = false;
end

% check which text drawer function is being used
isWin = streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<*STREMP>
usingFTGLTextRenderer = (~isWin || ~~exist('libptbdrawtext_ftgl64.dll','file')) && Screen('Preference','TextRenderer')==1;    % check if we're not on Windows, or if on Windows that we the high quality text renderer is used (was never supported for 32bit PTB, so check only for 64bit)

if usingFTGLTextRenderer
    % this one comes with PsychToolbox
    extra = {};
    if qCenterEachLine
        extra = [extra {'xlayout', 'center'}];
    end
    DrawFormattedText2(text, 'win', w, ...
        'sx', 'center', 'xalign', 'center', 'sy', 'center', 'yalign', 'center', ...
        'baseColor', textSetup.color, ...
        'wrapat', textSetup.wrapAt, ...
        'vSpacing', textSetup.vSpacing,...
        extra{:});
else
    % this one is supplied with Titta
    if qCenterEachLine
        xlayout = 'center';
    else
        xlayout = 'left';
    end
    DrawFormattedText2GDI(w,text,'center','center','center','center',xlayout,textSetup.color,textSetup.wrapAt,textSetup.vSpacing);
end
swaptime = Screen('Flip',w,flipWhen);