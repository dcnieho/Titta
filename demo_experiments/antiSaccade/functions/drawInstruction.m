function [data,scrShot] = drawInstruction(text,textSetup,wpnt,keys,ETSendMessageFun,flipWhen,qDoScreenShot)

if nargin<6 || isempty(flipWhen)
    % default, flip at next possible moment
    flipWhen = 0;
end
if nargin<7 || isempty(qDoScreenShot)
    qDoScreenShot = false;
end


% prepare output struct
data.Tonset  = [];
data.Toffset = [];

data.Tonset  = drawtext(text,textSetup,wpnt,flipWhen);
ETSendMessageFun('Instruction ON',data.Tonset);

scrShot = [];
if qDoScreenShot
    scrShot = Screen('GetImage', wpnt);
end

while true && ~isempty(keys)
    [~,keyCode] = KbStrokeWait();
    if any(ismember(lower(KbName(keyCode)),lower(keys)))
        break;
    end
end
data.Toffset = Screen('Flip',wpnt);
ETSendMessageFun('Instruction OFF',data.Toffset);

