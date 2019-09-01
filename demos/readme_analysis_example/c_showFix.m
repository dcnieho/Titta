clear variables; clear global; clear mex; close all; fclose('all'); clc
%%% NOTE: this code relies on functions from the PsychToolBox package,
%%% please make sure it is installed

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
                                dirs.home       = cd;
cd data;                        dirs.data       = cd;
        cd samples_ophak;       dirs.samples    = cd;
cd ..;  cd fixDet;              dirs.fix        = cd;
cd ..;  cd msgs_ophak;          dirs.msgsO      = cd;
cd ..;  cd mat;                 dirs.mat        = cd;
cd ..;
cd ..;
cd function_library;            dirs.funclib    = cd;
cd ..;
cd results;                     dirs.res        = cd;
cd(dirs.home);
addpath(genpath(dirs.funclib));                 % add dirs to path


%%% get all trials, parse into subject and stimulus
[files,nfiles]  = FileFromFolder(dirs.fix,[],'mat');
files           = parseFileNames(files);

if 0
    % filter so we only get data that matches the filter. uses regexp
    filtstr = '^(?!01|02|03).*$';
    results = regexpi({files.name}.',filtstr,'start');
    files   = files(~cellfun(@isempty,results));
    nfiles  = length(files);
end

fhndl   = -1;
lastRead= '';
for p=1:nfiles
    % load fix data
    dat  = load(fullfile(dirs.fix,[files(p).fname '.mat'])); dat = dat.dat;
    if isempty(dat.time)
        warning('no data for %s, empty file',files(p).fname);
        continue;
    end
    
    % get msgs
    msgs    = loadMsgs(fullfile(dirs.msgsO,[files(p).fname '.txt']));
    [times,what,msgs] = parseMsgs(msgs);

    sessionFileName = sprintf('%s.mat',files(p).subj);
    if ~strcmp(lastRead,sessionFileName)
        sess = load(fullfile(dirs.mat,sessionFileName),'expt','geom','settings');
    end
    
    % load img, if only one
    if 0
        imgFile  = fullfile(sess.expt.stimDir,what{1});
    else
        imgFile = what{1};
    end
    if ~exist(imgFile,'file')
        img      = [];
    else
        img.data = imread(imgFile);
        % centered on screen
        if 0
            stimRect = CenterRect([0 0 size(img.data,2) size(img.data,1)],sess.expt.winRect);
        else
            stimRect = CenterRect([0 0 size(img.data,2) size(img.data,1)],[0 0 1920 1080]);
        end
        img.x    = linspace(stimRect(1),stimRect(3),size(img.data,2));
        img.y    = linspace(stimRect(2),stimRect(4),size(img.data,1));
    end
    
    % plot
    if ~ishghandle(fhndl)
        fhndl = figure('Units','normalized','Position',[0 0 1 1]);  % make fullscreen figure
    else
        figure(fhndl);
        clf;
    end
    set(fhndl,'Visible','on');  % assert visibility to bring window to front again after keypress
    drawFix(dat,dat.fix,[dat.I2MCopt.xres dat.I2MCopt.yres],img,[dat.I2MCopt.missingx dat.I2MCopt.missingy],sprintf('subj %s, trial %03d, stim: %s',files(p).subj,files(p).runnr,what{1}));
    pause
    if ~ishghandle(fhndl)
        return;
    end
end

rmpath(genpath(dirs.funclib));                  % cleanup path
