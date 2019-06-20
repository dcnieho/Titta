function displaybreak(duration,w,textSetup,key,ETSendMessageFun)

duration = round(duration);

swaptime = 0;
while duration>0
    text = sprintf('break\\n\\n%d seconds',duration);

    if swaptime==0
        when = 0;
    else
        when = swaptime+1;
    end
    swaptime = drawtext(text,textSetup,w,when);
    ETSendMessageFun(sprintf('BREAK ON %d',duration));

    duration = duration-1;
end

% mandatory break time elapsed, wait for key press
if strcmp(key,'space')
    keyName = 'the spacebar';
else
    keyName = key;
end
drawtext(sprintf('Press %s to continue...',keyName),textSetup,w,swaptime+1);
ETSendMessageFun('BREAK ON 0');
while true
    [~,keyCode] = KbPressWait();
    if any(ismember(lower(KbName(keyCode)),lower(key)))
        break;
    end
end