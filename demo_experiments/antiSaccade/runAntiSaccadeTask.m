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
% Before running, make sure the size of the screen (settings.scr.rect
% below), its framerate (settings.scr.framerate) and other settings match
% your setup.
%
% When running the version with Tobii Pro Lab integration, additional
% running instructions are provided in antiSaccadeProLabIntegration.m
%
% Note that by default, this code runs a brief demo instead of the protocol
% recommended by Antoniades et al. The full protocol would take over 15
% minutes. To run the full protocol, set doDemo below to false.

%%% setup:
sca
clear variables

% add functions folder and Titta folder to path
% You can run addTittaToPath once to "install" it, or you can simply add a
% call to it in your script so each time you want to use Titta, it is
% ensured it is on path
home = cd;
cd ..; cd ..;
addTittaToPath;
cd(home);
myDir = fileparts(mfilename('fullpath'));
addpath(genpath(myDir));


%%% ask user some questions about what they want to run
fprintf('Do you want to run a short demo version (<a href="">Y</a>),\nor the long Antoniades et al. protocol (<a href="">N</a>)?: ')
answer = input('','s');
assert(~isempty(answer),'provide an answer: Y or N');
doDemo = ~strcmpi(answer,'n');    % if true, do a short run of pro- and antisaccades for demo purposes. If false, run recommended Antoniades et al. protocol.

fprintf('Do you want to use Tobii Pro Lab integration (<a href="">Y</a>),\nor not (<a href="">N</a>)?: ')
answer = input('','s');
assert(~isempty(answer),'provide an answer: Y or N');
useProLab = strcmpi(answer,'y');

%%% now run
% 1. get default settings for task
settings = antiSaccadeParameters(doDemo,useProLab);

% 2. change settings you want here, e.g.:
% 2.1 different eye tracker:
% settings.ET.settings = Titta.getDefaults('Tobii Pro Nano');
% 2.2 use eye tracker in dummy mode
% settings.ET.useDummyMode = true;
% 2.3 screen setup:
% settings.scr.rect       = [1680 1050];
% settings.scr.framerate  = 60;
% ... and possibly more, such as screen size and viewing distance
% 2.4 if using Pro Lab integration, you would probably want to change some
%     of these variables:
% settings.proLab.projectName
% settings.proLab.participant
% settings.proLab.RecordingName
% 2.5 furthermore the first time you run with pro lab integration, you must
%     set this to upload the stimuli. after that, set it back to false.
% settings.proLab.doDryRun = true;

% 3. now run task
if useProLab
    antiSaccadeProLabIntegration(settings);
else
    antiSaccade(settings);
end
