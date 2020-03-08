function sv = antiSaccadeParameters(doDemo,useProLabIntegration)
% This demo code is part of Titta, a toolbox providing convenient access to
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
%
% input parameters:
% - doDemo:               if true, do a short run of pro- and antisaccades
%                         for demo purposes. If false, run recommended
%                         Antoniades et al. protocol.
% - useProLabIntegration: if true, additional settings for the integration
%                         with Tobii Pro Lab are provided.


if nargin<1 || isempty(doDemo)
    doDemo = false;
end
if nargin<2 || isempty(useProLabIntegration)
    useProLabIntegration = false;
end

sv.DEBUGlevel               = 0;

% provide info about your screen (set to defaults for screen of Spectrum)
sv.scr.num                  = 0;
sv.scr.rect                 = [1920 1080];                      % expected screen resolution   (px)
sv.scr.framerate            = 60;                               % expected screen refresh rate (hz)
sv.scr.viewdist             = 65;                               % viewing    distance      (cm)
sv.scr.sizey                = 29.69997;                         % vertical   screen   size (cm)
sv.scr.multiSample          = 8;

sv.bgclr                    = 127;                              % screen background color (L, or RGB): here midgray

% setup eye tracker
sv.ET.useDummyMode          = false;
sv.ET.settings              = Titta.getDefaults('Tobii Pro Spectrum');
sv.ET.settings.cal.bgColor  = sv.bgclr;
% custom calibration drawer
calViz                      = AnimatedCalibrationDisplay();
calViz.bgColor              = sv.bgclr;
sv.ET.settings.cal.drawFunction = @calViz.doDraw;

% task parameters, either in brief demo mode or with all defaults as per
% the protocol recommended by Antoniades et al. (2013)
if doDemo
    sv.blockSetup       = {'P',10;'A',10};                      % blocks and number of trials per block to run: P for pro-saccade and A for anti-saccade
    sv.nTrainTrial      = [4 4];                                % number of training trials for [pro-, anti-saccades]
    sv.delayTMean       = 1500;                                 % the mean of the truncated exponential distribution for delay times
    sv.delayTLimits     = [1000 3500];                          % the limits of the truncated exponential distribution for delay times
    sv.breakT           = 5000;                                 % the minimum resting time between blocks (ms)
else
    sv.blockSetup       = {'P',60;'A',40;'A',40;'A',40;'P',60}; % blocks and number of trials per block to run: P for pro-saccade and A for anti-saccade
    sv.nTrainTrial      = [10 4];                               % number of training trials for [pro-, anti-saccades]
    sv.delayTMean       = 1500;                                 % the mean of the truncated exponential distribution for delay times
    sv.delayTLimits     = [1000 3500];                          % the limits of the truncated exponential distribution for delay times
    sv.breakT           = 60000;                                % the minimum resting time between blocks (ms)
end
sv.targetDuration       = 1000;                                 % the duration for which the target is shown
sv.restT                = 1000;                                 % the blank time between trials
% fixation point
sv.fixBackSize          = 0.25;                                 % degrees
sv.fixFrontSize         = 0.1;                                  % degrees
sv.fixBackColor         = 0;                                    % L or RGB
sv.fixFrontColor        = 255;                                  % L or RGB
% target point
sv.targetDiameter       = 0.5;                                  % degrees
sv.targetColor          = 0;                                    % L or RGB
sv.targetEccentricity   = 8;                                    % degrees

% default text settings
sv.text.font            = 'Consolas';
sv.text.size            = 20;
sv.text.style           = 0;                                    % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
sv.text.wrapAt          = 62;
sv.text.vSpacing        = 1;
sv.text.lineCentOff     = 3;                                    % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
sv.text.color           = 0;                                    % L or RGB

if useProLabIntegration
    sv.proLab.doDryRun      = false;                            % if true, do a dry run that just uploads the needed media to Pro Lab
    sv.proLab.useProLabDummyMode= false;
    sv.proLab.projectName       = 'antiSaccade';                % to use external presenter functionality, provide the name of the external presenter project here
    sv.proLab.participant       = 'tester';
    sv.proLab.recordingName     = 'recording1';
    sv.proLab.maxFixDist        = 2;                            % maximum distance gaze may stray from fixation point (not part of standard protocol, adjust to your needs)
    sv.proLab.minSacAmp         = 2;                            % minimum amplitude of saccade (not part of standard protocol, adjust to your needs)
    sv.proLab.maxSacDir         = 70;                           % maximum angle off from correct direction (not part of standard protocol, adjust to your needs)
    sv.proLab.AOInVertices      = 20;                           % number of vertices for cirle AOI
end
