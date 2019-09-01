clear variables; clear global; clear mex; close all; fclose('all'); clc
%%% NOTE: this code relies on functions from the PsychToolBox package,
%%% please make sure it is installed
%%% it furthermore uses I2MC, make sure you downloaded it and placed it in
%%% /function_library/I2MC

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
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
cd ..;
addpath(genpath(dirs.funclib));                 % add dirs to path

%%% params
disttoscreen = 65;  % cm, change to whatever is appropriate, though it matters little for I2MC
maxMergeDist = 15;
minFixDur    = 60;

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

lastRead= '';
for p=1:nfiles
    fprintf('%s:\n',files(p).fname);
    % load data
    data    = readintfile(fullfile(dirs.samplesO,files(p).name),1,7);
    
    % load session data
    sessionFileName = sprintf('%s.mat',files(p).subj);
    if ~strcmp(lastRead,sessionFileName)
        sess = load(fullfile(dirs.mat,sessionFileName),'expt','geom','settings');
    end
    
    % load messges and trial mat file. We'll need to find when in trial the
    % stimulus came on to use that as t==0
    msgs    = loadMsgs(fullfile(dirs.msgsO,[files(p).fname '.txt']));
    [times,what,msgs] = parseMsgs(msgs);
    
    % event detection
    % make params struct (only have to specify those you want to be
    % different from their defaults)
    if 0
        opt.xres          = dat.expt.winRect(3);
        opt.yres          = dat.expt.winRect(4);
    else
        opt.xres          = 1920;
        opt.yres          = 1080;
    end
    opt.missingx      = nan;
    opt.missingy      = nan;
    opt.scrSz         = [sess.geom.displayArea.width sess.geom.displayArea.height]/10;
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
        opt.downsampFilter=  false;
        opt.downsamples   = [2 3];
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
    [fix,dat]       = I2MCfunc(dat,opt);
    
    % collect info and store
    dat.fix         = fix;
    dat.I2MCopt     = opt;
    save(fullfile(dirs.fix,[files(p).fname '.mat']),'dat');
end

rmpath(genpath(dirs.funclib));                  % cleanup path
