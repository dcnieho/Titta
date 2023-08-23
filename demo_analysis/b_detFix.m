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

clear variables; clear global; clear mex; close all; fclose('all'); clc
%%% it furthermore uses I2MC, make sure you downloaded it and placed it in
%%% /function_library/I2MC

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
myDir = fileparts(mfilename('fullpath'));
cd(myDir);
cd data;                        dirs.data       = cd;
        cd samples_ophak;       dirs.samplesO   = cd;
cd ..;
if ~isdir('fixDet') %#ok<*ISDIR>
    mkdir(fullfile(cd,'fixDet'));
end
        cd fixDet;              dirs.fix        = cd;
cd ..;  cd msgs_ophak;          dirs.msgsO      = cd;
cd ..;  cd mat;                 dirs.mat        = cd;
cd ..;
cd ..;  cd function_library;    dirs.funclib    = cd;
cd ..;  cd results;             dirs.out        = cd;
cd ..;
addpath(genpath(dirs.funclib));                 % add dirs to path

%%% params
disttoscreen = 65;  % cm, change to whatever is appropriate, though it matters little for I2MC
maxMergeDist = 15;
minFixDur    = 60;

%%% check I2MC (fixation classifier) is available
assert(~~exist('I2MCfunc','file'),'It appears that I2MC is not available. please follow the instructions in /demo_analysis/function_library/I2MC/get_I2MC.txt to download it.')

%%% get all trials, parse into subject and stimulus
[files,nfiles]  = FileFromFolder(dirs.samplesO,[],'txt');
files           = parseFileNames(files);

if 0
    % filter so we only get data that matches the filter. uses regexp
    filtstr = '^(?!01|02|03).*$';
    results = regexpi({files.name}.',filtstr,'start');
    files   = files(~cellfun(@isempty,results));
    nfiles  = length(files);
end

% create textfile and open for writing fixations
fid = fopen(fullfile(dirs.out,'allfixations.txt'),'w');
fprintf(fid,'Subject\tRunNr\tFixStart\tFixEnd\tFixDur\tXPos\tYPos\tRMSxy\tBCEA\tFixRangeX\tFixRangeY\n');

lastRead= '';
for p=1:nfiles
    fprintf('%s:\n',files(p).fname);
    % load data
    data    = readNumericFile(fullfile(dirs.samplesO,files(p).name),7,1);
    
    % load session data
    sessionFileName = sprintf('%s.mat',files(p).subj);
    if ~strcmp(lastRead,sessionFileName)
        sess = load(fullfile(dirs.mat,sessionFileName),'expt','geometry','settings','systemInfo');
    end
    
    % load messges and trial mat file. We'll need to find when in trial the
    % stimulus came on to use that as t==0
    msgs    = loadMsgs(fullfile(dirs.msgsO,[files(p).fname '.txt']));
    [times,what,msgs] = parseMsgs(msgs);
    
    % event detection
    % make params struct (only have to specify those you want to be
    % different from their defaults)
    opt.xres          = sess.expt.winRect(3);
    opt.yres          = sess.expt.winRect(4);
    opt.missingx      = nan;
    opt.missingy      = nan;
    opt.scrSz         = [sess.geometry.displayArea.width sess.geometry.displayArea.height]/10;  % mm -> cm
    opt.disttoscreen  = disttoscreen;
    opt.freq          = sess.settings.freq;
    if opt.freq>120
        opt.downsamples   = [2 5 10];
        opt.chebyOrder    = 8;
    elseif opt.freq==120
        opt.downsamples   = [2 3 5];
        opt.chebyOrder    = 7;
    else
        % 90 Hz, 60 Hz, 30 Hz
        opt.downsampFilter= false;
        opt.downsamples   = [2 3];
    end
    if strcmp(sess.systemInfo.model,'X2-30_Compact')
        if sess.settings.freq==40
            % for some weird reason the X2-30 reports 40Hz even though it is 30
            opt.freq = 30;
        end
    end
    if opt.freq==30
        warning('Be careful about using I2MC with data that is only 30 Hz. In a brief test, this did not appear to work well with the settings in this file.')
    end
    if (~isfield(opt,'downsampFilter') || opt.downsampFilter) && ~exist('cheby1','file')
        warning('By default, I2MC runs a Chebyshev filter over the data as part of its operation. It appears that this filter (the function ''cheby1'' from the signal processing toolbox) is not available in your installation. I am thus disabling the filter.')
        opt.downsampFilter= false;
    end
    opt.maxMergeDist  = maxMergeDist;
    opt.minFixDur     = minFixDur;
    
    % make data struct
    clear dat;
    dat.time        = (data(:,1)-double(times.start))./1000; % mu_s to ms, make samples relative to onset of picture
    dat.left.X      = data(:,2);
    dat.left.Y      = data(:,3);
    dat.right.X     = data(:,4);
    dat.right.Y     = data(:,5);
    dat.left.pupil  = data(:,6);    % add pupil data to file. not used by I2MC but good for plotting
    dat.right.pupil = data(:,7);
    [fix,dat]       = I2MCfunc(dat,opt);
    
    % collect info and store
    dat.fix         = fix;
    dat.I2MCopt     = opt;
    save(fullfile(dirs.fix,[files(p).fname '.mat']),'dat');
    
    % also store to text file
    for f=1:numel(fix.start)
        fprintf(fid,'%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\n',files(p).subj, files(p).runnr, [fix.startT(f) fix.endT(f) fix.dur(f) fix.xpos(f) fix.ypos(f) fix.RMSxy(f), fix.BCEA(f), fix.fixRangeX(f), fix.fixRangeY(f)]);
    end
end

rmpath(genpath(dirs.funclib));                  % cleanup path
