% Antoniades et al. (2013) standard anti-saccade task: Antoniades et al.
% (2013). An internationally standardised antisaccade protocol. Vision
% Research 84, 1--5.
sca
clear variables

% add Titta folder to path
addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'..','..')));

DEBUGlevel          = 0;

% provide info about your screen (set to defaults for screen of Spectrum)
scr.num             = 0;
scr.rect            = [1920 1080];                          % expected screen resolution   (px)
scr.framerate       = 60;                                   % expected screen refresh rate (hz)
scr.viewdist        = 65;                                   % viewing    distance      (cm)
scr.sizey           = 29.69997;                             % vertical   screen   size (cm)
scr.multiSample     = 8;

bgclr               = 255/2;                                % screen background color (L, or RGB)

% setup eye tracker
qUseDummyMode           = false;
settings                = Titta.getDefaults('Tobii Pro Spectrum');
settings.cal.bgColor    = bgclr;
% custom calibration drawer
calViz                  = AnimatedCalibrationDisplay();
calViz.bgColor          = bgclr;
settings.cal.drawFunction = @(a,b,c,d,e) calViz.doDraw(a,b,c,d,e);

% task parameters, all defaults are per Antoniades et al. (2013)
% block and timing setup
blockSetup      = {'P',60;'A',40;'A',40;'A',40;'P',60};     % blocks and number of trials per block to run: P for pro-saccade and A for anti-saccade
nTrainTrial     = [10 4];                                   % number of training trials for [pro-, anti-saccades]
delayTMean      = 1500;                                     % the mean of the truncated exponential distribution for delay times
delayTLimits    = [1000 3500];                              % the limits of the truncated exponential distribution for delay times
targetDuration  = 1000;                                     % the duration for which the target is shown
breakT          = 60000;                                    % the minimum resting time between blocks (ms)
restT           = 1000;                                     % the blank time between trials
% fixation point
fixBackSize     = 0.25;                                     % degrees
fixFrontSize    = 0.1;                                      % degrees
fixBackColor    = 0;                                        % L or RGB
fixFrontColor   = 255;                                      % L or RGB
% target point
targetDiameter  = 0.5;                                      % degrees
targetColor     = 0;                                        % L or RGB
targetEccentricity  = 8;                                    % degrees

% default text settings
text.font           = 'Consolas';
text.size           = 20;
text.style          = 0;                                    % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
text.wrapAt         = 62;
text.vSpacing       = 1;
text.lineCentOff    = 3;                                    % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
text.color          = 0;                                    % L or RGB




%% prepare run
%%%%%%%%%%%%%%%%%% get display setup
rect                = Screen('Rect',scr.num);
frate               = Screen('FrameRate',scr.num);

%%%%%%%%%%%%%%%%%% fix Windows 7 brokenness
% see http://support.microsoft.com/kb/2006076, 59 Hz == 59.94Hz (and thus == 60 Hz)
if frate==59
    warning('Windows reported 59Hz again, ignoring it and pretending its 60 Hz...'); %#ok<WNTAG>
    frate=60;
end

%%%%%%%%%%%%%%%%%% check and compute display setup
assert(DEBUGlevel || isequal(rect(3:4),scr.rect),'expected resolution of [%s], but got [%s]',num2str(scr.rect),num2str(rect(3:4)));
assert(DEBUGlevel || frate==scr.framerate,'expected framerate of %d, but got %d',scr.framerate,frate);
scr.FOVy        = 2*atand(.5 .* scr.sizey./scr.viewdist);       % Screen's Field of View (degrees)
scr.aspectr     = scr.rect(1) ./ scr.rect(2);                   % aspect ratio
scr.FOVx        = 2*atand(tand(scr.FOVy/2)*scr.aspectr);
scr.center      = scr.rect/2;
scr.flipWaitT   = 1/scr.framerate;

% check timing parameters
checkTime(delayTMean    ,{'scalar'} ,'delayTMean (the mean of the truncated exponential distribution for delay times)',scr.framerate);
checkTime(delayTLimits  ,{'numel',2},'delayTLimits (the limits of the truncated exponential distribution for delay times)',scr.framerate);
checkTime(targetDuration,{'scalar'} ,'targetDuration (the duration for which the target is shown)',scr.framerate);
checkTime(breakT        ,{'scalar'} ,'breakT (the minimum resting time between blocks)',scr.framerate);
checkTime(restT         ,{'scalar'} ,'restT (the blank time between trials)',scr.framerate);

% setup colors
bgclr           = color2RGBA(bgclr);
fixBackColor    = color2RGBA(fixBackColor);
fixFrontColor   = color2RGBA(fixFrontColor);
targetColor     = color2RGBA(targetColor);
text.color      = color2RGBA(text.color);
% insert training blocks
bIdx = find(strcmp(blockSetup(:,1),'P'));
if ~isempty(bIdx)
    blockSetup = [blockSetup(1:bIdx-1,:); {'TP',nTrainTrial(1)}; blockSetup(bIdx:end,:)];
end
bIdx = find(strcmp(blockSetup(:,1),'A'));
if ~isempty(bIdx)
    blockSetup = [blockSetup(1:bIdx-1,:); {'TA',nTrainTrial(2)}; blockSetup(bIdx:end,:)];
end
% prepare display geometry
targetEccentricity = AngleToScreenPos(targetEccentricity,scr.FOVx)/2*scr.rect(1);   % /2 for scaling [-1 1] range of AngleToScreenPos to [0 1]
targetDiameter     = AngleToScreenPos(targetDiameter    ,scr.FOVx)/2*scr.rect(1);
fixBackSize        = AngleToScreenPos(fixBackSize       ,scr.FOVx)/2*scr.rect(1);
fixFrontSize       = AngleToScreenPos(fixFrontSize      ,scr.FOVx)/2*scr.rect(1);

% generate trials
nTrials = [0 blockSetup{:,2}];
data.trials = struct('tNr',num2cell(1:sum(nTrials)));
[data.trials.qFirstOfBlock] = deal(false);
[data.trials.qLastOfBlock]  = deal(false);
[data.trials.instruct]      = deal(struct('text',''));
dealFun = @(x)x{:};                     % like deal, but no shit that we first have to create a cell variable that we then feed it with {:}
rafz    = @(x)ceil(abs(x)).*sign(x);    % round away from zero
delayTs = [delayTLimits(1) : 1000/scr.framerate : delayTLimits(2)];    % possible delay times, discretized to frames in the interval
for p=1:size(blockSetup,1)
    idxs = sum(nTrials(1:p))+[1:nTrials(p+1)];
    [data.trials(idxs).bNr]       = deal(p);
    [data.trials(idxs).bTNr]      = dealFun(num2cell(1:nTrials(p+1)));
    [data.trials(idxs).blockType] = deal(blockSetup{p,1}(end));
    [data.trials(idxs).qTraining] = deal(blockSetup{p,1}(1)=='T');
    [data.trials(idxs).dir]       = dealFun(num2cell(rafz(rand(1,nTrials(p+1))*2-1)));  % equal probability for each trial instead of balanced number
    data.trials(idxs(1)).qFirstOfBlock = true;
    data.trials(idxs(end)).qLastOfBlock= true;
    [data.trials(idxs).delayT]    = dealFun(num2cell(truncExpRandDiscrete([1,nTrials(p+1)],delayTMean,delayTs)));
    % setup instructions
    if blockSetup{p,1}(end)=='P'
        if blockSetup{p,1}(1)=='T'
            data.trials(idxs(1)).instruct.text = 'In this task, a central black dot will be shown. Look at the central dot; and as soon as a new dot appears on the left or right, <u><i>look at it<i><u> as fast as you can.\n\nYou will now first do a brief practice.\n\n\nPress the spacebar to continue...';
        else
            data.trials(idxs(1)).instruct.text = 'Now, look at the central dot; and as soon as a new dot appears on the left or right, <u><i>look at it<i><u> as fast as you can.\n\n\nPress the spacebar to continue...';
        end
    else
        if blockSetup{p,1}(1)=='T'
            data.trials(idxs(1)).instruct.text = 'Your task will now be different. As before, look at the central dot; but as soon as a new dot appears, <u><i>look away from it<i><u> in the opposite direction of where the dot appeared, as fast as you can. So if the new dot appears on the left, look to the right. You will probably sometimes make mistakes, and this is perfectly normal.\n\nYou will now first do a brief practice.\n\n\nPress the spacebar to continue...';
        else
            data.trials(idxs(1)).instruct.text = 'Now, look at the central dot; but as soon as a new dot appears, <u><i>look away from it<i><u> in the opposite direction of where the dot appeared, as fast as you can. So if the new dot appears on the left, look at the right. You will probably sometimes make mistakes, and this is perfectly normal.\n\n\nPress the spacebar to continue...';
        end
    end
end

%% run
% TODO: known issue: ball can get stuck in paddle. check order of update
% operations each frame

try 
    % init
    EThndl          = Titta(settings);
    if qUseDummyMode
        EThndl          = EThndl.setDummyMode();
    end
    EThndl.init();
    
    
    if DEBUGlevel>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    wpnt = PsychImaging('OpenWindow', scr, bgclr, [], [], [], [], 4);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
    
    % do calibration, start recording
    calValInfo = EThndl.calibrate(wpnt);
    EThndl.buffer.start('gaze');
    
    
    
    
    % clear flip
    clearTime = Screen('Flip',wpnt);
    for p=1:length(data.trials)
        if data.trials(p).bTNr==1
            ETSendMessageFun(sprintf('BLOCK START %d: %s',data.trials(p).bNr,blockSetup{data.trials(p).bNr,1}));
        end
        ETSendMessageFun(sprintf('FIX ON %d (%d %d)',p,scr.center));
        if ~isempty(data.trials(p).instruct.text)
            insText                     = data.trials(p).instruct.text;
            data.trials(p).instruct     = drawInstruction(insText,addToStruct(text,'color',[0 0 0 255]),wpnt,{'space'},scr.flipWaitT,ETSendMessageFun);
            data.trials(p).instruct.text= insText;
            clearTime                   = data.trials(p).instruct.Toffset;
        end
        
        % draw fixation target after restT
        drawfixpoints(wpnt,scr.center,{'.','.'},{fixBackSize fixFrontSize},{fixBackColor fixFrontColor},1);
        data.trials(p).fixOnsetT  = Screen('Flip',wpnt,clearTime+restT/1000-scr.flipWaitT+1/1000);
        ETSendMessageFun(sprintf('FIX ON %d (%d %d)',p,scr.center));
        
        % draw saccade (anti-)target after delayT
        pos = scr.center;
        pos(1) = pos(1)+data.trials(p).dir*targetEccentricity;
        drawfixpoints(wpnt,pos,{'.'},{targetDiameter},{targetColor},1);
        data.trials(p).targetOnsetT  = Screen('Flip',wpnt,data.trials(p).fixOnsetT+data.trials(p).delayT/1000-scr.flipWaitT+1/1000);
        ETSendMessageFun(sprintf('TARGET ON %d (%d %d)',p,round(pos)));
        
        % clear after targetDuration
        data.trials(p).targetOffsetT = Screen('Flip',wpnt,data.trials(p).targetOnsetT+targetDuration/1000-scr.flipWaitT+1/1000);
        clearTime = data.trials(p).targetOffsetT;
        ETSendMessageFun(sprintf('TARGET OFF %d (%d %d)',p,round(pos)));
        
        % break if after last of block and not training.
        if data.trials(p).qLastOfBlock && ~data.trials(p).qTraining && p~=length(data.trials)
            ETSendMessageFun('BREAK START');
            displaybreak(breakT/1000,wpnt,addToStruct(text,'color',[200 0 0 255]),0,'keyboard','space',ETSendMessageFun);
            clearTime = Screen('Flip',wpnt);
            ETSendMessageFun('BREAK OFF');
        end
        if p==length(data.trials) || data.trials(p+1).bTNr==1
            ETSendMessageFun(sprintf('BLOCK END %d: %s',data.trials(p).bNr,blockSetup{data.trials(p).bNr,1}));
        end
    end
    
    
    
    
    
    
    
    paddlePos = XMAX/2;     % start in center of screen horizontally
    paddle.translate([paddlePos 0]);
    qWin = false;
    flips = [];
    while true
        [~,~,keyCode] = KbCheck;
        if KbMapKey(27,keyCode) % 27 is escape
            qSave = false;
            break;
        end
        
        % draw objects
        % 1. blocks
        for b=1:length(blocks)
            verts = blocks(b).vertices;
            Screen('FillPoly' ,wpnt,blockFillClr,verts,1);
            verts = verts+[1 -1 -1 1; 1 1 -1 -1].'*2;
            Screen('FramePoly',wpnt,blockEdgeClr,verts,2);
        end
        % 2. paddle
        Screen('FillPoly' ,wpnt,paddleFillClr,paddle.vertices,1);
        % 3. ball
        ballPos  = ball.pos;
        ballRect = CenterRectOnPointd([0 0 [2 2]*ball.r],ballPos(1),ballPos(2));
        Screen('FillOval', wpnt, ballFillClr, ballRect);
        
        flips(end+1) = Screen('Flip',wpnt);
        
        % update paddle
        % 1. get eye data, determine how far to move
        samp    = EThndl.buffer.consumeN('gaze');
        % see if have a sample with both eyes
        qSelect = samp.left.gazePoint.valid & samp.left.gazePoint.valid;
        if ~any(qSelect)
            % if not, see if have sample for one of the eyes
            qSelect = samp.left.gazePoint.valid | samp.right.gazePoint.valid;
        end
        i = find(qSelect,1,'last');
        % if have some form of eye position, update paddle position
        if ~isempty(i)
            gazeX   = [samp.left.gazePoint.onDisplayArea(1,i) samp.right.gazePoint.onDisplayArea(1,i)];
            gazeX   = mean(gazeX(~isnan(gazeX)))*width;
            trans   = gazeX-paddlePos;
            % 2. clamp paddle position to play area
            if paddlePos+trans-paddleWidth/2<XMIN
                add = XMIN-(paddlePos+trans-paddleWidth/2);
                trans = trans+add;
            elseif paddlePos+trans+paddleWidth/2>XMAX
                sub = paddlePos+trans+paddleWidth/2 - XMAX;
                trans = trans-sub;
            end
            % 3. update its position
            paddlePos = paddlePos+trans;
            paddle.translate([trans 0]);
        end
        
        % update ball
        [collided,colPos] = ball.update([blocks worldBounds paddle],1:length(blocks));
        blocks(collided) = [];
        if isempty(blocks)
            % all blocks gone, done
            qWin = true;
            break;
        end
        if ~isempty(colPos) && any(colPos(:,2)==YMAX)
            % ball went off bottom of screen, you lost
            break;
        end
    end
    
    % stopping
    EThndl.buffer.stop('gaze');
    
    % show performance feedback
    if qWin
        str = 'You won!';
    else
        str = 'Game over';
    end
    str = sprintf('<size=26>%s\n%d points',str,(nBlockInRow*nRow-length(blocks))*pointsPerBlock);
    if exist('libptbdrawtext_ftgl64.dll','file')
        % DrawFormattedText2 is 64bit matlab only (on Windows)
        DrawFormattedText2(str,'win',wpnt,'sx','center', 'sy','center', 'xalign','center', 'yalign','center','xlayout','center','baseColor',0);
    else
        % fallback for 32bit matlab on Windows (TODO: what to support on
        % the other platforms here)?
        DrawFormattedText2GDI(wpnt,str,'center','center','center','center','center',0);
    end
    Screen('Flip',wpnt);
    WaitSecs(3);
catch me
    sca
    rethrow(me)
end
% shut down
EThndl.deInit();
sca