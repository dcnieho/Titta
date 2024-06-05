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
runInDummyMode          = false;
scr                     = max(Screen('Screens'));
% task parameters
fixTime                 = 1.2;          % s
dur                     = 4;            % s
cps                     = 0.375;        % Hz
range                   = [0.1 0.9];    % fraction of screen width and height
phase_off               = -pi/2;

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
    if runInDummyMode
        EThndl          = EThndl.setDummyMode();
    end
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
    Screen('gluDisk',wpnt,fixClrs(2),stim.x(1),stim.y(1),round(winRect(3)/250));
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
    % I'm not going to use that however, just showing whats possible.
    
    % save data to mat file, adding info about the experiment
    dat                 = EThndl.collectSessionData();
    dat.expt.resolution = winRect(3:4);
    dat.expt.stim       = stim;
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

% make plot, showing fixation and pursuit interval, data for both eyes.
% select relevant part of data and plot it
ETdat   = dat.data.gaze;
msgs    = dat.messages;
% get what happened when from message log
iStart  = find(~cellfun(@isempty,strfind(msgs(:,2),'FIX ON')));     %#ok<STRCLFH>
iPursuit= find(~cellfun(@isempty,strfind(msgs(:,2),'PURSUIT AT'))); %#ok<STRCLFH>
iEnd    = find(strcmp(msgs(:,2),'STIM OFF'),1,'last');
Ts      = cat(1,msgs{iStart,1},msgs{iPursuit,1},msgs{iEnd,1});
startT  = Ts(1);
endT    = Ts(end);
Ts      = double(Ts-startT)/1000;   % convert to ms, relative to start time
% get dot positions during fixation and pursuit stimulus
posF    = sscanf(msgs{iStart,2},'FIX ON (%f,%f)');
posP    = cellfun(@(x) sscanf(x,'PURSUIT AT (%f,%f)'),msgs(iPursuit,2),'uni',false);
posP    = cat(2,posP{:});
pos     = [posF posP];
% double them up so we can accurately represent sample-and-hold nature of a
% screen in our plots
Ts      = reshape([Ts(1:end-1) Ts(2:end)].',1,[]);
pos     = reshape([pos;pos],2,[]);

% convert gaze data to deg offset from center of screen (fixation point)
if runInDummyMode
    [lx, ly]    = deal([]);
    [rx, ry]    = deal([]);
    t           = [];
else
    left.x  = ETdat. left.gazePoint.onDisplayArea(1,:) * dat.expt.winRect(3);
    left.y  = ETdat. left.gazePoint.onDisplayArea(2,:) * dat.expt.winRect(4);
    right.x = ETdat.right.gazePoint.onDisplayArea(1,:) * dat.expt.winRect(3);
    right.y = ETdat.right.gazePoint.onDisplayArea(2,:) * dat.expt.winRect(4);
    
    qDat    = ETdat.systemTimeStamp>=startT & ETdat.systemTimeStamp<=endT;
    t       = ETdat.systemTimeStamp(qDat); t=double(t-startT)/1000;
    lx      = left.x(qDat);
    ly      = left.y(qDat);
    rx      = right.x(qDat);
    ry      = right.y(qDat);
end


eyeColors = {[255 127   0],[  0  95 191]};
newline = sprintf('\n'); %#ok<SPRINTFN>
f       = figure;
ax(1)   = subplot(2,1,1);
hold on
hs      = plot(Ts,pos(1,:),'k');
hl      = plot(t,lx,'Color',eyeColors{1}/255);
hr      = plot(t,rx,'Color',eyeColors{2}/255);
xlim(Ts([1 end]))
ylim([0 dat.expt.winRect(3)]);
ylabel(['Horizontal gaze' newline 'position (pixels)'])
legend([hs hl hr],'dot position','left gaze','right gaze','Location','NorthWest')

ax(2)   = subplot(2,1,2);
hold on
hs      = plot(Ts,pos(2,:),'k');
hl      = plot(t,ly,'Color',eyeColors{1}/255);
hr      = plot(t,ry,'Color',eyeColors{2}/255);
xlim(Ts([1 end]))
ylim([0 dat.expt.winRect(4)]);
ylabel(['Vertical gaze' newline 'position (pixels)'])
xlabel('Time (ms)');

linkaxes(ax,'x');
if isprop(f,'WindowState')
    f.WindowState = 'maximized';
end
zoom on
