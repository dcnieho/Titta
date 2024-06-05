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
    % customize colors of setup and calibration interface (colors of
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
    % callback function for completion of each calibration point
    settings.cal.pointNotifyFunction = @demoCalCompletionFun;
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
    
    % shut down
    EThndl.deInit();
catch me
    sca
    ListenChar(0);
    rethrow(me)
end
sca
