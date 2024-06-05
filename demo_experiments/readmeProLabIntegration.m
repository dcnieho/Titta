% this demo code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% This script shows the integration with Tobii Pro Lab using the
% TalkToProLab class included with Titta.
% To run this demo,
% 1) Open an External Presenter project in Tobii Pro Lab, make sure its
%    name matches the TobiiProLabProject variable below.
% 2) Navigate to the 'record'-tab in Pro Lab
% 3) Make sure that the External presenter button is red and says 'not
%    connected'
% 4) Run this script
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

clear all
sca

DEBUGlevel              = 0;
fixClrs                 = [0 255];
bgClr                   = 127;
useAnimatedCalibration  = true;
doBimonocularCalibration= false;
scr                     = max(Screen('Screens'));
% task parameters
fixTime                 = .5;
imageTime               = 4;

TobiiProLabProject      = 'EPTest'; % to use external presenter functionality, provide the name of the external presenter project here
TobiiProLabParticipant  = 'tester';
TobiiProLabRecordingName= 'recording1';

% You can run addTittaToPath once to "install" it, or you can simply add a
% call to it in your script so each time you want to use Titta, it is
% ensured it is on path
home = cd;
cd ..;
addTittaToPath;
cd(home);

try
    % get setup struct (can edit that of course):
    settings = Titta.getDefaults('Tobii Pro Spectrum');
    % request some debug output to command window, can skip for normal use
    settings.debugMode      = true;
    % customize colors of setup and calibration interface (yes, colors of
    % everything can be set, so there is a lot here).
    % 1. setup screen
    settings.UI.setup.bgColor       = bgClr;
    settings.UI.setup.instruct.color= fixClrs(1);
    settings.UI.setup.fixBackColor  = fixClrs(1);
    settings.UI.setup.fixFrontColor = fixClrs(2);
    % 2. calibration display
    if useAnimatedCalibration
        % custom calibration drawer
        calViz                      = AnimatedCalibrationDisplay();
        settings.cal.drawFunction   = @calViz.doDraw;
        calViz.bgColor              = bgClr;
        calViz.fixBackColor         = fixClrs(1);
        calViz.fixFrontColor        = fixClrs(2);
    else
        % set color of built-in fixation points
        settings.cal.bgColor        = bgClr;
        settings.cal.fixBackColor   = fixClrs(1);
        settings.cal.fixFrontColor  = fixClrs(2);
    end
    % 3. validation result screen
    settings.UI.val.bgColor                 = bgClr;
    settings.UI.val.avg.text.color          = fixClrs(1);
    settings.UI.val.fixBackColor            = fixClrs(1);
    settings.UI.val.fixFrontColor           = fixClrs(2);
    settings.UI.val.onlineGaze.fixBackColor = fixClrs(1);
    settings.UI.val.onlineGaze.fixFrontColor= fixClrs(2);
    
    % init
    EThndl          = Titta(settings);
    % EThndl          = EThndl.setDummyMode();    % just for internal testing, enabling dummy mode for this readme makes little sense as a demo
    EThndl.init();
    
    % get class for integration with Tobii Pro Lab
    if isempty(TobiiProLabProject)
        TalkToProLabInstance = TalkToProLabDummyMode();
    else
        TalkToProLabInstance = TalkToProLab(TobiiProLabProject);
    end
    % create participant (setting second parameter to true means that no
    % error is thrown if a participant by that name already exists, instead
    % a new recording is added to that participant.
    TalkToProLabInstance.createParticipant(TobiiProLabParticipant,true);
    
    if DEBUGlevel>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    if DEBUGlevel
        % Be pretty verbose about information and hints to optimize your code and system.
        Screen('Preference', 'Verbosity', 4);
    else
        % Only output critical errors and warnings.
        Screen('Preference', 'Verbosity', 2);
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    [wpnt,winRect] = PsychImaging('OpenWindow', scr, bgClr, [], [], [], [], 4);
    hz=Screen('NominalFrameRate', wpnt);
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
    
    % do calibration
    try
        ListenChar(-1);
    catch ME
        % old PTBs don't have mode -1, use 2 instead which also supresses
        % keypresses from leaking through to matlab
        ListenChar(2);
    end
    if doBimonocularCalibration
        % do sequential monocular calibrations for the two eyes
        settings                = EThndl.getOptions();
        settings.calibrateEye   = 'left';
        settings.UI.button.setup.cal.string = 'calibrate left eye (<i>spacebar<i>)';
        str = settings.UI.button.val.continue.string;
        settings.UI.button.val.continue.string = 'calibrate other eye (<i>spacebar<i>)';
        EThndl.setOptions(settings);
        tobii.calVal{1}         = EThndl.calibrate(wpnt,1);
        if ~tobii.calVal{1}.wasSkipped
            settings.calibrateEye   = 'right';
            settings.UI.button.setup.cal.string = 'calibrate right eye (<i>spacebar<i>)';
            settings.UI.button.val.continue.string = str;
            EThndl.setOptions(settings);
            tobii.calVal{2}         = EThndl.calibrate(wpnt,2);
        end
    else
        % do binocular calibration
        tobii.calVal{1}         = EThndl.calibrate(wpnt);
    end
    ListenChar(0);
    
    % prep stimuli (get rabbits) - preload these before the trials to
    % ensure good timing
    rabbits = loadStimuliFromFolder(fullfile(PsychtoolboxRoot,'PsychDemos'),{'konijntjes1024x768.jpg','konijntjes1024x768blur.jpg'},wpnt,winRect(3:4));
    
    % later:
    EThndl.buffer.start('gaze');
    % also start Pro Lab recording
    fprintf('Current Pro Lab state: %s\n',TalkToProLabInstance.getExternalPresenterState()); % just to show this function in the API as well, startRecording() by default checks state first
    TalkToProLabInstance.startRecording(TobiiProLabRecordingName,RectWidth(winRect),RectHeight(winRect));
    % send info about validation quality to Pro Lab
    % if you have information about your participant, its a good idea to
    % send it here too using similar calls
    for c=1:length(tobii.calVal)
        if isfield(tobii.calVal{c}.attempt{end},'valReviewStatus') && tobii.calVal{c}.attempt{end}.valReviewStatus==1
            TalkToProLabInstance.sendCustomEvent([],'validationResult',EThndl.getValidationQualityMessage(tobii.calVal{c}));
        end
    end
    WaitSecs(.8);   % wait for eye tracker to start and gaze to be picked up
    
    % send message into ET data file
    EThndl.sendMessage('test');
    
    % First draw a fixation point
    Screen('gluDisk',wpnt,fixClrs(1),winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    % log when fixation dot appeared in eye-tracker time. NB:
    % system_timestamp of the Tobii data uses the same clock as
    % PsychToolbox, so startT as returned by Screen('Flip') can be used
    % directly to segment eye tracking data
    EThndl.sendMessage('FIX ON',startT);
    % take screenshot to be uploaded to pro lab if this image doesn't exist
    % yet
    fixMediaID = TalkToProLabInstance.findMedia('fixationPoint');
    if isempty(fixMediaID)
        screenShotFixPoint = Screen('GetImage', wpnt);
    end
    
    % show on screen and log when it was shown in eye-tracker time.
    % NB: by setting a deadline for the flip, we ensure that the previous
    % screen (fixation point) stays visible for the indicated amount of
    % time. See PsychToolbox demos for further elaboration on this way of
    % timing your script.
    Screen('DrawTexture',wpnt,rabbits(1).tex,[],rabbits(1).scrRect);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);                   % bit of slack to make sure requested presentation time can be achieved
    EThndl.sendMessage(sprintf('STIM ON: %s [%.0f %.0f %.0f %.0f]',rabbits(1).fInfo.name,rabbits(1).scrRect),imgT);
    
    % record x seconds of data, then clear screen. Indicate stimulus
    % removed, clean up
    endT = Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.sendMessage(sprintf('STIM OFF: %s',rabbits(1).fInfo.name),endT);
    Screen('Close',rabbits(1).tex);
    
    % upload screens for this trial to Pro Lab
    if isempty(fixMediaID)
        fixMediaID = TalkToProLabInstance.uploadMedia(screenShotFixPoint,'fixationPoint');
        % add AOI around fixation point location
        fixRect = CenterRectOnPoint([0 0 1 1]*round(winRect(3)/100*4),winRect(3)/2,winRect(4)/2);   % make AOI twice the size of the fixation point (and *2 again because radius->diameter, *2 to double size, so *4 in total)
        vertices= fixRect([1 3 3 1; 2 2 4 4]);
        TalkToProLabInstance.attachAOIToImage('fixationPoint','fixationPoint',[255 0 0],vertices,TalkToProLabInstance.makeAOITag('fixPoint','points'));
    end
    konijnMediaID = TalkToProLabInstance.findMedia('konijntjes_nonblur');
    if isempty(konijnMediaID)
        stimFName = fullfile(rabbits(1).fInfo.folder,rabbits(1).fInfo.name);
        konijnMediaID = TalkToProLabInstance.uploadMedia(stimFName,'konijntjes_nonblur');
    end
    % send stimulus events to Pro Lab, delinianating what happened when in
    % time
    TalkToProLabInstance.sendStimulusEvent(fixMediaID,[],startT);
    TalkToProLabInstance.sendStimulusEvent(konijnMediaID,rabbits(1).scrRect,imgT,endT,bgClr);
    
    % slightly less precise ISI is fine..., about 1s give or take a frame
    % or continue immediately if the above upload actions took longer than
    % a second.
    WaitSecs(1-(GetSecs-endT));
    
    % repeat the above but show a different image. lets also record some
    % eye images, if supported on connected eye tracker
    if EThndl.buffer.hasStream('eyeImage')
        EThndl.buffer.start('eyeImage');
    end
    % 1. fixation point
    Screen('gluDisk',wpnt,fixClrs(1),winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    EThndl.sendMessage('FIX ON',startT);
    % 2. image
    Screen('DrawTexture',wpnt,rabbits(2).tex,[],rabbits(2).scrRect);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);                   % bit of slack to make sure requested presentation time can be achieved
    EThndl.sendMessage(sprintf('STIM ON: %s [%.0f %.0f %.0f %.0f]',rabbits(2).fInfo.name,rabbits(2).scrRect),imgT);
    
    % 4. end recording after x seconds of data again, clear screen.
    endT = Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.sendMessage(sprintf('STIM OFF: %s',rabbits(2).fInfo.name),endT);
    Screen('Close',rabbits(2).tex);
    
    % stop recording
    if EThndl.buffer.hasStream('eyeImage')
        EThndl.buffer.stop('eyeImage');
    end
    EThndl.buffer.stop('gaze');
    TalkToProLabInstance.stopRecording();
    
    % upload media and send stimulus events for second trial
    % NB: fixation point we have already uploaded, so no need to do it again
    konijnBlurMediaID = TalkToProLabInstance.findMedia('konijntjes_blur');
    if isempty(konijnBlurMediaID)
        stimFName = fullfile(rabbits(2).fInfo.folder,rabbits(2).fInfo.name);
        konijnBlurMediaID = TalkToProLabInstance.uploadMedia(stimFName,'konijntjes_blur');
    end
    % send events
    TalkToProLabInstance.sendStimulusEvent(fixMediaID,[],startT);
    TalkToProLabInstance.sendStimulusEvent(konijnBlurMediaID,rabbits(2).scrRect,imgT,endT,bgClr);
    
    % save data to mat file, adding info about the experiment
    dat = EThndl.collectSessionData();
    dat.expt.resolution = winRect(3:4);
    dat.expt.stim       = rabbits;
    EThndl.saveData(dat, fullfile(cd,'t'), true);
    % if you want to (also) save the data to Apache Parquet and json files
    % that can easily be read in Python (Apache Parquet files are supported
    % by Pandas), use:
    % EThndl.saveDataToParquet(dat, fullfile(cd,'t'), true);
    % All gaze data columns and messages can be dumped to tsv files using:
    % EThndl.saveGazeDataToTSV(dat, fullfile(cd,'t'), true);
    
    % finalize recording in Pro Lab (NB: must go into lab and confirm)
    TalkToProLabInstance.finalizeRecording();
    
    % shut down
    EThndl.deInit();
    TalkToProLabInstance.disconnect();
catch me
    sca
    ListenChar(0);
    rethrow(me)
end
sca
