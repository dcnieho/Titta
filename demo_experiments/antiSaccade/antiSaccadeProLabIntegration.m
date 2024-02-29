function antiSaccadeProLabIntegration(varargin)
% this demo code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8
%
% This implements:
% Antoniades et al. (2013). An internationally standardised antisaccade
% protocol. Vision Research 84, 1--5.
%
% To run
% 1) In Pro Lab, make a new External Presenter project with the name
%    'antiSaccade'. Open this project and select the recording tab.
% 2) In Pro Lab, navigate to the 'record'-tab and make sure that the
%    External presenter button is red and says 'not connected'.
% 2) In this code, make sure the size of the screen (sv.scr.rect below),
%    its framerate (sv.scr.framerate) and other settings match your setup.
% 3) First, the stimuli need to be uploaded to Pro Lab. Below, set
%    sv.proLab.doDryRun to true and run this code.
% 4) Once finished, set sv.doDryRun back to false. You are now ready to run
%    the demo. Check that the correct eye tracker is set with the command
%    Titta.getDefaults('Tobii Pro Spectrum') below.
% 5) By default, this code runs a brief demo instead of the protocol
%    recommended by Antoniades et al. The full protocol would take over 15
%    minutes. To run the full protocol, set qDemo below to false.
% 6) Once the recording has completed, switch to Pro Lab to view the data
%    in its analysis view.

if nargin<1
    doDemo  = true;
    sv      = antiSaccadeParameters(doDemo,true);
else
    sv      = varargin{1};
end

% sv.proLab.doDryRun = true;

%% prepare run
addpath(fullfile(cd,'functions'))
%%%%%%%%%%%%%%%%%% get display setup
rect                = Screen('Rect',sv.scr.num);
frate               = Screen('FrameRate',sv.scr.num);

%%%%%%%%%%%%%%%%%% fix Windows 7 brokenness
% see http://support.microsoft.com/kb/2006076, 59 Hz == 59.94Hz (and thus == 60 Hz)
if frate==59
    warning('Windows reported 59Hz again, ignoring it and pretending its 60 Hz...'); %#ok<WNTAG>
    frate=60;
end

%%%%%%%%%%%%%%%%%% check and compute display setup
assert(sv.DEBUGlevel || isequal(rect(3:4),sv.scr.rect),'expected resolution of [%s], but got [%s]',num2str(sv.scr.rect),num2str(rect(3:4)));
assert(sv.DEBUGlevel || frate==sv.scr.framerate,'expected framerate of %d, but got %d',sv.scr.framerate,frate);
sv.scr.FOVy        = 2*atand(.5 .* sv.scr.sizey./sv.scr.viewdist);       % Screen's Field of View (degrees)
sv.scr.aspectr     = sv.scr.rect(1) ./ sv.scr.rect(2);                   % aspect ratio
sv.scr.FOVx        = 2*atand(tand(sv.scr.FOVy/2)*sv.scr.aspectr);
sv.scr.center      = sv.scr.rect/2;
sv.scr.flipWaitT   = 1/sv.scr.framerate;

% check timing parameters
checkTime(sv.delayTMean    ,{'scalar'} ,'sv.delayTMean (the mean of the truncated exponential distribution for delay times)',sv.scr.framerate);
checkTime(sv.delayTLimits  ,{'numel',2},'sv.delayTLimits (the limits of the truncated exponential distribution for delay times)',sv.scr.framerate);
checkTime(sv.targetDuration,{'scalar'} ,'sv.targetDuration (the duration for which the target is shown)',sv.scr.framerate);
checkTime(sv.breakT        ,{'scalar'} ,'sv.breakT (the minimum resting time between blocks)',sv.scr.framerate);
checkTime(sv.restT         ,{'scalar'} ,'sv.restT (the blank time between trials)',sv.scr.framerate);

% setup colors
sv.bgclr        = color2RGBA(sv.bgclr);
sv.fixBackColor = color2RGBA(sv.fixBackColor);
sv.fixFrontColor= color2RGBA(sv.fixFrontColor);
sv.targetColor  = color2RGBA(sv.targetColor);
sv.text.color   = color2RGBA(sv.text.color);
% insert training blocks
bIdx = find(strcmp(sv.blockSetup(:,1),'P'));
if ~isempty(bIdx)
    sv.blockSetup = [sv.blockSetup(1:bIdx-1,:); {'TP',sv.nTrainTrial(1)}; sv.blockSetup(bIdx:end,:)];
end
bIdx = find(strcmp(sv.blockSetup(:,1),'A'));
if ~isempty(bIdx)
    sv.blockSetup = [sv.blockSetup(1:bIdx-1,:); {'TA',sv.nTrainTrial(2)}; sv.blockSetup(bIdx:end,:)];
end
% prepare display geometry
sv.targetEccentricityPix= AngleToScreenPos(sv.targetEccentricity,sv.scr.FOVx)/2*sv.scr.rect(1);   % /2 for scaling [-1 1] range of AngleToScreenPos to [0 1]
sv.targetDiameterPix    = AngleToScreenPos(sv.targetDiameter    ,sv.scr.FOVx)/2*sv.scr.rect(1);
sv.fixBackSizePix       = AngleToScreenPos(sv.fixBackSize       ,sv.scr.FOVx)/2*sv.scr.rect(1);
sv.fixFrontSizePix      = AngleToScreenPos(sv.fixFrontSize      ,sv.scr.FOVx)/2*sv.scr.rect(1);
maxFixDistPix           = AngleToScreenPos(sv.proLab.maxFixDist ,sv.scr.FOVx)/2*sv.scr.rect(1);
minSacAmpPix            = AngleToScreenPos(sv.proLab.minSacAmp  ,sv.scr.FOVx)/2*sv.scr.rect(1);

% generate trials
dealFun = @(x)x{:};                     % like deal, but no shit that we first have to create a cell variable that we then feed it with {:}
if sv.proLab.doDryRun
    sv.blockSetup = {'TP',1;'P',1;'TA',1;'A',1};
end
nTrials = [0 sv.blockSetup{:,2}];
data.trials = struct('tNr',num2cell(1:sum(nTrials)));
[data.trials.qFirstOfBlock] = deal(false);
[data.trials.qLastOfBlock]  = deal(false);
[data.trials.instruct]      = deal(struct('text',''));
rafz    = @(x)ceil(abs(x)).*sign(x);    % round away from zero
delayTs = [sv.delayTLimits(1) : 1000/sv.scr.framerate : sv.delayTLimits(2)];    % possible delay times, discretized to frames in the interval
for p=1:size(sv.blockSetup,1)
    idxs = sum(nTrials(1:p))+[1:nTrials(p+1)];
    [data.trials(idxs).bNr]       = deal(p);
    [data.trials(idxs).bTNr]      = dealFun(num2cell(1:nTrials(p+1)));
    [data.trials(idxs).blockType] = deal(sv.blockSetup{p,1}(end));
    [data.trials(idxs).qTraining] = deal(sv.blockSetup{p,1}(1)=='T');
    [data.trials(idxs).dir]       = dealFun(num2cell(rafz(rand(1,nTrials(p+1))*2-1)));  % equal probability for each trial instead of balanced number
    data.trials(idxs(1)).qFirstOfBlock = true;
    data.trials(idxs(end)).qLastOfBlock= true;
    [data.trials(idxs).delayT]    = dealFun(num2cell(truncExpRandDiscrete([1,nTrials(p+1)],sv.delayTMean,delayTs)));
    % setup instructions
    if sv.blockSetup{p,1}(end)=='P'
        if sv.blockSetup{p,1}(1)=='T'
            data.trials(idxs(1)).instruct.text = 'In this task, a central black dot will be shown. Look at the central dot; and as soon as a new dot appears on the left or right, <u><i>look at it<i><u> as fast as you can.\n\nYou will now first do a brief practice.\n\n\nPress the spacebar to continue...';
        else
            data.trials(idxs(1)).instruct.text = 'Now, look at the central dot; and as soon as a new dot appears on the left or right, <u><i>look at it<i><u> as fast as you can.\n\n\nPress the spacebar to continue...';
        end
    else
        if sv.blockSetup{p,1}(1)=='T'
            data.trials(idxs(1)).instruct.text = 'Your task will now be different. As before, look at the central dot; but as soon as a new dot appears, <u><i>look away from it<i><u> in the opposite direction of where the dot appeared, as fast as you can. So if the new dot appears on the left, look to the right. You will probably sometimes make mistakes, and this is perfectly normal.\n\nYou will now first do a brief practice.\n\n\nPress the spacebar to continue...';
        else
            data.trials(idxs(1)).instruct.text = 'Now, look at the central dot; but as soon as a new dot appears, <u><i>look away from it<i><u> in the opposite direction of where the dot appeared, as fast as you can. So if the new dot appears on the left, look at the right. You will probably sometimes make mistakes, and this is perfectly normal.\n\n\nPress the spacebar to continue...';
        end
    end
end
if sv.proLab.doDryRun
    [data.trials.dir]           = dealFun(num2cell([-1 1 -1 1]));
    [data.trials.delayT]        = deal(500);
end

%% run
try 
    % init
    EThndl          = Titta(sv.ET.settings);
    if sv.ET.useDummyMode || sv.proLab.doDryRun
        EThndl          = EThndl.setDummyMode();
    end
    EThndl.init();
    % get class for integration with Tobii Pro Lab
    if sv.proLab.useProLabDummyMode
        TalkToProLabInstance = TalkToProLabDummyMode();
    else
        TalkToProLabInstance = TalkToProLab(sv.proLab.projectName);
    end
    % create participant (setting second parameter to true means that if a
    % participant by that name already exists
    if ~sv.proLab.doDryRun
        TalkToProLabInstance.createParticipant(sv.proLab.participant,true);
    end
    if ~sv.proLab.doDryRun
        % get media information from Pro Lab, will produce error if not found
        breakID         = TalkToProLabInstance.findMedia('break',true);
        blankID         = TalkToProLabInstance.findMedia('blank',true);
        fixID           = TalkToProLabInstance.findMedia('fixationPoint',true);
        leftAID         = TalkToProLabInstance.findMedia('leftTarget_AntiSac',true);
        leftPID         = TalkToProLabInstance.findMedia('leftTarget_ProSac',true);
        rightAID        = TalkToProLabInstance.findMedia('rightTarget_AntiSac',true);
        rightPID        = TalkToProLabInstance.findMedia('rightTarget_ProSac',true);
        proTrainInsID   = TalkToProLabInstance.findMedia('ProSacTrainInstruction',true);
        proInsID        = TalkToProLabInstance.findMedia('ProSacInstruction',true);
        antiTrainInsID  = TalkToProLabInstance.findMedia('AntiSacTrainInstruction',true);
        antiInsID       = TalkToProLabInstance.findMedia('AntiSacInstruction',true);
    end
    
    if sv.DEBUGlevel>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    wpnt = PsychImaging('OpenWindow', sv.scr.num, sv.bgclr, [], [], [], [], sv.scr.multiSample);
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
    try
        ListenChar(-1);
    catch ME
        % old PTBs don't have mode -1, use 2 instead which also supresses
        % keypresses from leaking through to matlab
        ListenChar(2);
    end
    calValInfo = EThndl.calibrate(wpnt);
    ListenChar(0);
    EThndl.buffer.start('gaze');
    if ~sv.proLab.doDryRun
        TalkToProLabInstance.startRecording(sv.proLab.recordingName,sv.scr.rect(1),sv.scr.rect(2));
    end
    
    % clear flip
    clearTime = Screen('Flip',wpnt);
    % run all trials
    for p=1:length(data.trials)
        if data.trials(p).bTNr==1
            EThndl.sendMessage(sprintf('BLOCK START %d: %s',data.trials(p).bNr,sv.blockSetup{data.trials(p).bNr,1}));
        end
        if ~isempty(data.trials(p).instruct.text)
            insText                             = data.trials(p).instruct.text;
            keys = {};
            if ~sv.proLab.doDryRun
                keys = {'space'};
            end
            [data.trials(p).instruct,scrShot]   = drawInstruction(insText,addToStruct(sv.text,'color',[0 0 0 255]),wpnt,keys,@EThndl.sendMessage,[],sv.proLab.doDryRun);
            data.trials(p).instruct.text        = insText;
            clearTime                           = data.trials(p).instruct.Toffset;
            % construct name
            if data.trials(p).blockType=='P'
                instrName = 'ProSac';
            else
                instrName = 'AntiSac';
            end
            if data.trials(p).qTraining
                instrName = [instrName 'Train'];
            end
            instrName = [instrName 'Instruction'];
            instrID = TalkToProLabInstance.findMedia(instrName);
            if sv.proLab.doDryRun
                if isempty(instrID)
                    instrID = TalkToProLabInstance.uploadMedia(scrShot,instrName);
                end
            else
                % notify pro lab of instruction text onset, and following
                % blank onset
                TalkToProLabInstance.sendStimulusEvent(instrID,[0 0 sv.scr.rect],data.trials(p).instruct.Tonset,[]);
                TalkToProLabInstance.sendStimulusEvent(blankID,[0 0 sv.scr.rect],data.trials(p).instruct.Toffset,[]);
            end
        end
        
        % draw fixation target after sv.restT
        drawfixpoints(wpnt,sv.scr.center,{'.','.'},{sv.fixBackSizePix sv.fixFrontSizePix},{sv.fixBackColor sv.fixFrontColor},1);
        data.trials(p).fixOnsetT  = Screen('Flip',wpnt,clearTime+sv.restT/1000-sv.scr.flipWaitT+1/1000);
        EThndl.sendMessage(sprintf('FIX ON %d (%d %d)',p,sv.scr.center),data.trials(p).fixOnsetT);
        if sv.proLab.doDryRun
            % screenshot and upload fixation point, if not already done
            fixID = TalkToProLabInstance.findMedia('fixationPoint');
            if isempty(fixID)
                screenShot = Screen('GetImage', wpnt);
                fixID = TalkToProLabInstance.uploadMedia(screenShot,'fixationPoint');
                % set AOI
                angs = linspace(0,2*pi,sv.proLab.AOInVertices+1); angs(end) = [];
                AOIvertsR = bsxfun(@plus,maxFixDistPix*[cos(angs); sin(angs)],sv.scr.center(:));
                TalkToProLabInstance.attachAOIToImage('fixationPoint','fixationPoint',[255 0 0],AOIvertsR);
            end
        else
            % notify pro lab of stimulus onset
            TalkToProLabInstance.sendStimulusEvent(fixID,[0 0 sv.scr.rect],data.trials(p).fixOnsetT,[]);
        end
        
        % draw saccade (anti-)target after delayT
        pos = sv.scr.center;
        pos(1) = pos(1)+data.trials(p).dir*sv.targetEccentricityPix;
        drawfixpoints(wpnt,pos,{'.'},{sv.targetDiameterPix},{sv.targetColor},1);
        data.trials(p).targetOnsetT  = Screen('Flip',wpnt,data.trials(p).fixOnsetT+data.trials(p).delayT/1000-sv.scr.flipWaitT+1/1000);
        EThndl.sendMessage(sprintf('TARGET ON %d (%d %d)',p,round(pos)),data.trials(p).targetOnsetT);
        if data.trials(p).dir==-1
            target = 'left';
        else
            target = 'right';
        end
        tarLbl = [target 'Target'];
        if sv.proLab.doDryRun
            % screenshot and upload fixation point, if not already done
            % do one for pro- and one for antisaccade
            for t=1:2
                fullTarLbl = [tarLbl '_ProSac'];
                condLbl = 'prosaccade';
                if t==2
                    fullTarLbl = [tarLbl '_AntiSac'];
                    condLbl = 'antisaccade';
                end
                targetID = TalkToProLabInstance.findMedia(fullTarLbl);
                if isempty(targetID)
                    screenShot = Screen('GetImage', wpnt);
                    targetID = TalkToProLabInstance.uploadMedia(screenShot,fullTarLbl);
                    % set AOI
                    angs = linspace(-sv.proLab.maxSacDir,sv.proLab.maxSacDir,sv.proLab.AOInVertices);
                    AOIvertsR = bsxfun(@plus,minSacAmpPix*[cosd(angs); sind(angs)],sv.scr.center(:));
                    hOff = sv.scr.rect(2)/2*tand(90-sv.proLab.maxSacDir);
                    if hOff>sv.scr.rect(1)/2
                        vOff = sv.scr.rect(1)/2*tand(sv.proLab.maxSacDir);
                        AOIvertsR = [AOIvertsR [sv.scr.rect(1) sv.scr.rect(1); sv.scr.center(2)+vOff sv.scr.center(2)-vOff]];
                    else
                        hOff = hOff + sv.scr.rect(1)/2;
                        AOIvertsR = [AOIvertsR [hOff sv.scr.rect(1) sv.scr.rect(1) hOff; sv.scr.rect(2) sv.scr.rect(2) 0 0]];
                    end
                    if data.trials(p).dir==-1
                        AOIvertsL = AOIvertsR;
                        AOIvertsL(1,:) = sv.scr.rect(1)-AOIvertsL(1,:);
                    end
                    lbl1 = 'correct';
                    lbl2 = 'wrong';
                    if t==2
                        % swap correct and wrong for antisaccades
                        [lbl1,lbl2] = deal(lbl2,lbl1);
                    end
                    if data.trials(p).dir==-1
                        % target on left, denote left as pro response,
                        % right as anti response
                        TalkToProLabInstance.attachAOIToImage(fullTarLbl,lbl1,[0 255 0],AOIvertsL,TalkToProLab.makeAOITag(lbl1,condLbl));
                        TalkToProLabInstance.attachAOIToImage(fullTarLbl,lbl2,[255 0 0],AOIvertsR,TalkToProLab.makeAOITag(lbl2,condLbl));
                    else
                        % target on right, denote right as pro response, left
                        % as anti response
                        TalkToProLabInstance.attachAOIToImage(fullTarLbl,lbl1,[0 255 0],AOIvertsR,TalkToProLab.makeAOITag(lbl1,condLbl));
                        TalkToProLabInstance.attachAOIToImage(fullTarLbl,lbl2,[255 0 0],AOIvertsL,TalkToProLab.makeAOITag(lbl2,condLbl));
                    end
                end
            end
        else
            if strcmpi(data.trials(p).blockType,'a')
                if data.trials(p).dir==-1
                    tarID = leftAID;
                else
                    tarID = rightAID;
                end
            else
                if data.trials(p).dir==-1
                    tarID = leftPID;
                else
                    tarID = rightPID;
                end
            end
            % notify pro lab of stimulus onset
            TalkToProLabInstance.sendStimulusEvent(tarID,[0 0 sv.scr.rect],data.trials(p).targetOnsetT,[]);
        end
        
        % clear after sv.targetDuration
        data.trials(p).targetOffsetT = Screen('Flip',wpnt,data.trials(p).targetOnsetT+sv.targetDuration/1000-sv.scr.flipWaitT+1/1000);
        clearTime = data.trials(p).targetOffsetT;
        EThndl.sendMessage(sprintf('TARGET OFF %d (%d %d)',p,round(pos)),clearTime);
        if sv.proLab.doDryRun
            blankID = TalkToProLabInstance.findMedia('blank');
            if isempty(blankID)
                screenShot = Screen('GetImage', wpnt);
                blankID = TalkToProLabInstance.uploadMedia(screenShot,'blank');
            end
        elseif p~=length(data.trials)
            % notify pro lab of stimulus onset
            TalkToProLabInstance.sendStimulusEvent(blankID,[0 0 sv.scr.rect],data.trials(p).targetOffsetT,[]);
        end
        
        % break if after last of block and not training.
        if data.trials(p).qLastOfBlock && ~data.trials(p).qTraining && p~=length(data.trials) && ~sv.proLab.doDryRun
            EThndl.sendMessage('BREAK START');
            displaybreak(sv.breakT/1000,wpnt,addToStruct(sv.text,'color',[200 0 0 255]),'space',@EThndl.sendMessage);
            clearTime = Screen('Flip',wpnt);
            EThndl.sendMessage('BREAK OFF',clearTime);
            % notify pro lab of stimulus onset
            TalkToProLabInstance.sendStimulusEvent(breakID,[0 0 sv.scr.rect],data.trials(p).targetOffsetT+1/sv.scr.framerate,[]);
            TalkToProLabInstance.sendStimulusEvent(blankID,[0 0 sv.scr.rect],clearTime,[]);
        end
        if sv.proLab.doDryRun
            breakID = TalkToProLabInstance.findMedia('break');
            if isempty(breakID)
                drawtext('BREAK',addToStruct(sv.text,'color',[200 0 0 255]),wpnt,0);
                screenShot = Screen('GetImage', wpnt);
                breakID = TalkToProLabInstance.uploadMedia(screenShot,'break');
            end
        end
        if p==length(data.trials) || data.trials(p+1).bTNr==1
            EThndl.sendMessage(sprintf('BLOCK END %d: %s',data.trials(p).bNr,sv.blockSetup{data.trials(p).bNr,1}));
        end
    end
    
    % stopping
    EThndl.buffer.stop('gaze');
    if ~sv.proLab.doDryRun
        TalkToProLabInstance.sendStimulusEvent(blankID,[0 0 sv.scr.rect],data.trials(p).targetOffsetT,GetSecs);  % last event must have an end time
        TalkToProLabInstance.stopRecording();
    end
    
    % save data to mat file
    if ~sv.proLab.doDryRun
        data        = EThndl.collectSessionData();
        data.setup  = sv;
        EThndl.saveData(data, fullfile(cd,'antiSac.mat'), true);
        % if you want to (also) save the data to Apache Parquet and json
        % files that can easily be read in Python (Apache Parquet files are
        % supported by Pandas), use:
        % EThndl.saveDataToParquet(data, fullfile(cd,'antiSac'), true);
        % All gaze data columns and messages can be dumped to tsv files
        % using:
        % EThndl.saveGazeDataToTSV(data, fullfile(cd,'antiSac'), true);
    end
    % finalize recording in Pro Lab (NB: must go into lab and confirm)
    if ~sv.proLab.doDryRun
        TalkToProLabInstance.finalizeRecording();
    end
    
    % shut down
    EThndl.deInit();
    if ~sv.proLab.doDryRun
        TalkToProLabInstance.disconnect();
    end
catch me
    sca
    ListenChar(0);
    rethrow(me)
end
% shut down
EThndl.deInit();
sca
