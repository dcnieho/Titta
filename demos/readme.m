sca
qDEBUG = 0;
s.bclr              = 255/2;

addpath(genpath(fullfile(cd,'..')));

try
    % get setup struct (can edit that of course):
    settings = Titta.getDefaults('Tobii Pro Spectrum');
    % custom calibration drawer
    calViz = AnimatedCalibrationDisplay();
    settings.cal.drawFunction = @calViz.doDraw;
    settings.debugMode = true;
    
    % init
    EThndl          = Titta(settings);
%     ETFhndl         = ETFhndl.setDummyMode();
    EThndl.init();
    
    % TODO fix this (when calling stop, sensors don't switch off)
    if 0
        ETFhndl.rawBuffers.start('eyeImage')
        WaitSecs(1);
        ETFhndl.rawBuffers.stop('eyeImage')
    end
    
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
    wpnt = PsychImaging('OpenWindow', 0, s.bclr);
    Priority(1);
    Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('Preference', 'TextAlphaBlending', 1);
    Screen('Preference', 'TextAntiAliasing', 2);
    % This preference setting selects the high quality text renderer on
    % each operating system: It is not really needed, as the high quality
    % renderer is the default on all operating systems, so this is more of
    % a "better safe than sorry" setting.
    Screen('Preference', 'TextRenderer', 1);
    KbName('UnifyKeyNames')
    
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
    
    % later:
    EThndl.startRecording('gaze');
     
    % send message into ET data file
    EThndl.sendMessage('test');
    % record 2 seconds of data
    WaitSecs(2);
    
    EThndl.startRecording('eyeImage');
    EThndl.sendMessage('eyes!');
    WaitSecs(.8);
    
    % TODO test peek multiple times, should be able to return same sample.
    % peekTimeRange seems not to work...
    
    
    
    % stopping and saving
    EThndl.stopRecording('eyeImage');
    EThndl.stopRecording('gaze');
    EThndl.saveData(fullfile(cd,'t'), true);
    
    % shut down
    EThndl.deInit();
catch me
    sca
    rethrow(me)
end
sca