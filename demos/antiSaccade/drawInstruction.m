function data = drawInstruction(text,textSetup,wpnt,keys,ETSendMessageFun,flipWhen)

if nargin<8 || isempty(flipWhen)
    % default, flip at next possible moment
    flipWhen = 0;
end


% prepare output struct
data.Tonset  = [];
data.Toffset = [];

data.Tonset  = drawtext(text,textSetup,wpnt,flipWhen);
ETSendMessageFun('Instruction ON');

while true
    [~,keyCode] = KbStrokeWait();
    if any(ismember(lower(KbName(keyCode)),lower(keys)))
        break;
    end
end
data.Toffset = Screen('Flip',wpnt);
ETSendMessageFun('Instruction OFF');

