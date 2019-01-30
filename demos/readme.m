sca
qDEBUG = 0;
bgclr       = 255/2;
fixClr      = 0;
fixTime     = .5;
imageTime   = 2;
scr         = max(Screen('Screens'));

addpath(genpath(fullfile(cd,'..')));

try
    % get setup struct (can edit that of course):
    settings = Titta.getDefaults('Tobii Pro Spectrum');
    % custom calibration drawer
    calViz = AnimatedCalibrationDisplay();
    settings.cal.drawFunction = @calViz.doDraw;
    settings.debugMode = true;
    settings.cal.bgColor    = bgclr;
    
    % init
    EThndl          = Titta(settings);
%     EThndl         = ETFhndl.setDummyMode();
    EThndl.init();
    
    % TODO: also implement lab interface. Keep it separate from Titta as
    % they do not _need to_ interact
    %TobiiProLabInstance = [];
    
    if qDEBUG>1
        % make screen partially transparent on OSX and windows vista or
        % higher, so we can debug.
        PsychDebugWindowConfiguration;
    end
    if qDEBUG
        % Be pretty verbose abDout information and hints to optimize your code and system.
        Screen('Preference', 'Verbosity', 4);
    else
        % Only output critical errors and warnings.
        Screen('Preference', 'Verbosity', 2);
    end
    Screen('Preference', 'SyncTestSettings', 0.002);    % the systems are a little noisy, give the test a little more leeway
    [wpnt,winRect] = PsychImaging('OpenWindow', scr, bgclr);
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
    if 0    % to do sequential monocular calibrations for the two eyes
        settings                = EThndl.getOptions();
        settings.calibrateEye   = 'left';
        EThndl.setOptions(settings);
        tobii.calVal{1}         = EThndl.calibrate(wpnt,1);
        settings.calibrateEye   = 'right';
        EThndl.setOptions(settings);
        tobii.calVal{2}         = EThndl.calibrate(wpnt,2);
    else
        tobii.calVal{1}         = EThndl.calibrate(wpnt);
    end
    % TODO for TobiiProLabInstance, something like
    % TobiiProLabInstance.sendTittaCalibration(tobii.calVal{1})
    
    % later:
    EThndl.startRecording('gaze');
    % TobiiProLabInstance.startRecording('gaze');
     
    % send message into ET data file
    EThndl.sendMessage('test');
    
    % First draw a fixation point
    Screen('gluDisk',wpnt,0,winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    % log when fixation dot appeared in eye-tracker time. NB:
    % system_timestamp of the Tobii data uses the same clock as
    % PsychToolbox, so startT as returned by Screen('Flip') can be used
    % directly to segment eye tracking data
    EThndl.sendMessage('FIX ON',startT);
    
    % read in konijntjes image (may want to preload this before the trial
    % to ensure good timing)
    stimFName = 'konijntjes1024x768.jpg';
    im = imread(fullfile(PsychtoolboxRoot,'PsychHardware','EyelinkToolbox','EyelinkDemos','GazeContingentDemos',stimFName));
    tex = Screen('MakeTexture',wpnt,im);
    
    % show on screen and log when it was shown in eye-tracker time.
    % NB: by setting a deadline for the flip, we ensure that the previous
    % screen (fixation point) stays visible for the indicated amount of
    % time. See PsychToolbox demos for further elaboration on this way of
    % timing your script.
    Screen('DrawTexture',wpnt,tex);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);   % bit of slack to make sure requested presentation time can be achieved
    EThndl.sendMessage(sprintf('STIM ON: %s',stimFName),imgT);
    
    % record x seconds of data, then clear screen. Indicate stimulus
    % removed, clean up
    endT = Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.sendMessage(sprintf('STIM OFF: %s',stimFName),endT);
    Screen('Close',tex);
    
    % slightly less precise ISI is fine..., about 1s give or take a frame
    WaitSecs(1);
    
    % repeat the above but show a different image. lets also record some
    % eye images
    %if EThndl.rawBuffers.hasStream('eyeImage')
    %    EThndl.startRecording('eyeImage');
    %end
    % 1. fixation point
    Screen('gluDisk',wpnt,0,winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
    startT = Screen('Flip',wpnt);
    EThndl.sendMessage('FIX ON',startT);
    % 2. image
    stimFName = 'konijntjes1024x768blur.jpg';
    im = imread(fullfile(PsychtoolboxRoot,'PsychHardware','EyelinkToolbox','EyelinkDemos','GazeContingentDemos',stimFName));
    tex = Screen('MakeTexture',wpnt,im);
    Screen('DrawTexture',wpnt,tex);
    imgT = Screen('Flip',wpnt,startT+fixTime-1/hz/2);   % bit of slack to make sure requested presentation time can be achieved
    EThndl.sendMessage(sprintf('STIM ON: %s',stimFName),imgT);
    
    % 4. end recording after x seconds of data again, clear screen.
    Screen('Flip',wpnt,imgT+imageTime-1/hz/2);
    EThndl.sendMessage(sprintf('STIM OFF: %s',stimFName),endT);
    Screen('Close',tex);
    
    % stopping and saving
    %if EThndl.rawBuffers.hasStream('eyeImage')
    %    EThndl.stopRecording('eyeImage');
    %end
    EThndl.stopRecording('gaze');
    EThndl.saveData(fullfile(cd,'t'), true);
    
    % shut down
    EThndl.deInit();
catch me
    sca
    rethrow(me)
end
sca