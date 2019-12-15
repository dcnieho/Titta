% this demo code is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

clear all
sca

DEBUGlevel              = 0;
fixClrs                 = [0 255];
bgClr                   = 127;
useAnimatedCalibration  = true;
doBimonocularCalibration= false;
% task parameters
fixTime                 = .5;           % s
dur                     = 4;            % s
cps                     = 0.375;        % Hz
range                   = [0.1 0.9];    % fraction of screen width and height
phase_off               = -pi/2;
scr                     = max(Screen('Screens'));

addpath(genpath(fullfile(fileparts(mfilename('fullpath')),'..')));

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
    % 2. validation result screen
    settings.UI.val.bgColor                 = bgClr;
    settings.UI.val.avg.text.color          = fixClrs(1);
    settings.UI.val.fixBackColor            = fixClrs(1);
    settings.UI.val.fixFrontColor           = fixClrs(2);
    settings.UI.val.onlineGaze.fixBackColor = fixClrs(1);
    settings.UI.val.onlineGaze.fixFrontColor= fixClrs(2);
    % calibration display
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
    
    % init
    EThndl          = Titta(settings);
    EThndl          = EThndl.setDummyMode();    % just for internal testing, enabling dummy mode for this readme makes little sense as a demo
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
    
    % precompute target trajectory
    nFrame = hz*dur;
    stim.t = linspace(0,dur,nFrame);
    stim.x = linspace(range(1),range(2),nFrame) * winRect(3);
    stim.y = (diff(range)/2 * sin(cps*2*pi*stim.t+phase_off) + mean(range)) * winRect(4);
    
    
    % later:
    EThndl.buffer.start('gaze');
    WaitSecs(.8);   % wait for eye tracker to start and gaze to be picked up
    
    % First draw a fixation point
    Screen('gluDisk',wpnt,fixClrs(1),stim.x(1),stim.y(1),round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    % log when fixation dot appeared in eye-tracker time. NB:
    % system_timestamp of the Tobii data uses the same clock as
    % PsychToolbox, so startT as returned by Screen('Flip') can be used
    % directly to segment eye tracking data
    EThndl.sendMessage(sprintf('FIX ON (%.1f,%.1f)',stim.x(1),stim.y(1)),startT);
    
    % show animation and log when each frame was shown in eye-tracker time.
    % NB: by setting a deadline for the flip, we ensure that the previous
    % screen (fixation point) stays visible for the indicated amount of
    % time. See PsychToolbox demos for further elaboration on this way of
    % timing your script.
    nextFlipT   = startT+fixTime-1/hz/2;    % bit of slack to make sure requested presentation time can be achieved
    frameT      = nan(1,nFrame);
    for f=1:nFrame
        Screen('gluDisk',wpnt,fixClrs(1),stim.x(f),stim.y(f),round(winRect(3)/160));
        frameT(f)   = Screen('Flip',wpnt,nextFlipT);
        EThndl.sendMessage(sprintf('PURSUIT AT (%.1f,%.1f)',stim.x(f),stim.y(f)),frameT(f));
        
        nextFlipT   = frameT(f)+.5/hz;  % we want to show a new location each frame, but ask for a bit early to provide the needed slack
    end
    
    % Clear screen and indicate that the stimulus was removed
    endT = Screen('Flip',wpnt,nextFlipT);
    EThndl.sendMessage('STIM OFF',endT);
    
    % stop recording
    EThndl.buffer.stop('gaze');
    
    % get our gaze data conveniently from buffer before we drain it with
    % EThndl.collectSessionData() below. Note that we peek, not consume, so
    % that all data remains in the buffer to store to file.
    gazeData = EThndl.buffer.peekTimeRange('gaze',startT,endT);
    
    % save data to mat file, adding info about the experiment
    dat                 = EThndl.collectSessionData();
    dat.expt.winRect    = winRect;
    dat.expt.stim       = stim;
    save(EThndl.getFileName(fullfile(cd,'t'), true),'-struct','dat');
    % NB: if you don't want to add anything to the saved data, you can use
    % EThndl.saveData directly
    
    % shut down
    EThndl.deInit();
catch me
    sca
    rethrow(me)
end
sca

% make plot, showing fixation and pursuit interval, data for both eyes.
