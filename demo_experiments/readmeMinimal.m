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

scr                     = max(Screen('Screens'));
% task parameters
fixTime                 = .5;   % duration fixation point shown (s)
imageTime               = 4;    % duration image shown (s)
ITI                     = 1;    % inter-trial-interval (s)

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
    % calibration display - use custom calibration drawer
    calViz                      = AnimatedCalibrationDisplay();
    settings.cal.drawFunction   = @calViz.doDraw;
    
    % init
    EThndl = Titta(settings);
    EThndl.init();
    
    % open PTB screen
    [wpnt,winRect] = Screen('OpenWindow', scr, 127, [], [], [], [], 4);
    hz=Screen('NominalFrameRate', wpnt);
    Priority(1);
    KbName('UnifyKeyNames');    % for correct operation of the setup/calibration interface, calling this is required
    
    % do calibration (info about validation accuracy will be stored in eye
    % tracker messages, and more info is collected by the
    % EThndl.collectSessionData() call below)
    ListenChar(-1);
    EThndl.calibrate(wpnt);
    ListenChar(0);
    
    % prep stimuli (get rabbits) - preload these before the trials to
    % ensure good timing
    rabbits = loadStimuliFromFolder(fullfile(PsychtoolboxRoot,'PsychDemos'),{'konijntjes1024x768.jpg','konijntjes1024x768blur.jpg'},wpnt,winRect(3:4));
    
    % later:
    EThndl.buffer.start('gaze');
    WaitSecs(.8);   % wait for eye tracker to start and gaze to be picked up
    
    % do trials
    T       = Screen('Flip',wpnt);
    % NB: Timing in PsychToolbox is best done by setting a deadline for
    % each flip. This technique works by ensuring that the previous screen
    % (e.g., fixation point) stays visible for the indicated amount of
    % time. See PsychToolbox demos for further elaboration on this way of
    % timing your script.
    presT   = T+1/hz/2; % next possible flip, with a bit of slack to make sure requested presentation time can be achieved
    for p=1:length(rabbits)
        % First draw a fixation point
        Screen('gluDisk',wpnt,0,winRect(3)/2,winRect(4)/2,round(winRect(3)/100));
        startT = Screen('Flip',wpnt,presT);
        % log when fixation dot appeared in eye-tracker time. NB:
        % system_timestamp of the Tobii data uses the same clock as
        % PsychToolbox, so startT as returned by Screen('Flip') can be used
        % directly to segment eye tracking data
        EThndl.sendMessage('FIX ON',startT);
        
        % show image on screen after requested duration of fixation point
        presT= startT+fixTime-1/hz/2;
        Screen('DrawTexture',wpnt,rabbits(p).tex,[],rabbits(p).scrRect);
        imgT = Screen('Flip',wpnt,presT);
        % log when it was shown
        EThndl.sendMessage(sprintf('STIM ON: %s [%.0f %.0f %.0f %.0f]',rabbits(p).fInfo.name,rabbits(p).scrRect),imgT);
        
        % record x seconds of data, then clear screen (flip without drawing
        % anything).
        presT= imgT+imageTime-1/hz/2;
        endT = Screen('Flip',wpnt,presT);
        % log when stimulus was removed from screen
        EThndl.sendMessage(sprintf('STIM OFF: %s',rabbits(p).fInfo.name),endT);
        % clean up
        Screen('Close',rabbits(p).tex);
        
        % set up when next fixation point should be shown
        presT= endT+1-1/hz/2;
    end
    
    % stop recording
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
