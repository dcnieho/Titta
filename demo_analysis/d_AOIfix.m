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

dbstop if error % for debugging: trigger a debug point when an error occurs

% setup directories
myDir = fileparts(mfilename('fullpath'));
cd(myDir);
                                dirs.home       = cd;
cd data;                        dirs.data       = cd;
        cd samples_ophak;       dirs.samples    = cd;
cd ..;  cd fixDet;              dirs.fix        = cd;
cd ..;
if ~isdir('AOIfix') %#ok<*ISDIR>
    mkdir(fullfile(cd,'AOIfix'));
end
        cd AOIfix;              dirs.AOIfix     = cd;
cd ..;  cd msgs_ophak;          dirs.msgsO      = cd;
cd ..;  cd mat;                 dirs.mat        = cd;
cd ..;
cd ..;
cd function_library;            dirs.funclib    = cd;
cd ..;
cd AOIs;                        dirs.AOIs       = cd;
cd ..;
cd results;                     dirs.res        = cd;
cd(dirs.home);
addpath(genpath(dirs.funclib));                 % add dirs to path

%*****************************************************************
%*****************************************************************

%%% get all trials, parse into subject and stimulus
[files,nfiles] = FileFromFolder(dirs.fix,[],'mat');
files           = parseFileNames(files);

if 0
    % filter so we only get data that matches the filter. uses regexp
    filtstr = '^(?!01|02|03).*$';
    results = regexpi({files.name}.',filtstr,'start');
    files   = files(~cellfun(@isempty,results));
    nfiles  = length(files);
end

% load all AOIs
AOI     = loadAllAOIFolders(dirs.AOIs,'png');    % AOI is struct met alle gegevens van de AOI masks
AOInms  = {AOI.name};

% per subject, per trial, read data and see which AOIs fixations are in, if
% any. 0 is other (no AOI), -1 is not on stimulus, -2 is out of screen
lastRead= '';
for p=1:nfiles
    disp(files(p).fname)
    
    % load fix data
    dat     = load(fullfile(dirs.fix,[files(p).fname '.mat'])); dat = dat.dat;
    
    if isempty(dat.time)
        warning('no data for %s, empty file',files(p).fname);
        continue;
    end
    
    % get msgs
    msgs    = loadMsgs(fullfile(dirs.msgsO,[files(p).fname '.txt']));
    [times,what,~] = parseMsgs(msgs);

    sessionFileName = sprintf('%s.mat',files(p).subj);
    if ~strcmp(lastRead,sessionFileName)
        sess = load(fullfile(dirs.mat,sessionFileName),'expt');
        lastRead = sessionFileName;
        fInfo = [sess.expt.stim.fInfo];
    end
    qWhich= strcmp({fInfo.name},what{1});
    assert(sum(qWhich)==1,'No or too many presentation info (texs field) found for this stimulus')
    
    % get more info about stimulus shown etc
    tex     = sess.expt.stim(qWhich);
    qAOI    = strcmp(what{1},AOInms);
    assert(sum(qAOI)==1,'No or too many AOIs lists found for this stimulus: %s',what{1})
    
    % throw out fixations that onset before first stimulus shown
    qDel = dat.fix.startT<=0;
    fields = fieldnames(dat.fix);
    for f=1:length(fields)
        if ~isscalar(dat.fix.(fields{f}))
            dat.fix.(fields{f})(qDel) = [];
        end
    end
    
    % check sizes are correct, i.e., AOI boolean images match in size with
    % shown images
    AOIbools    = {AOI(qAOI).AOIs.bool};
    szs         = cellfun(@size,AOIbools,'uni',false);
    assert(isequal(tex.size,szs{:}),'Some AOIs have wrong size (doesn''t match stimulus)');
    
    % see which AOIs fixations are in
    temp    = detAOIfix(AOI(qAOI).AOIs,dat.fix.xpos,dat.fix.ypos,sess.expt.winRect(3:4),tex.scrRect,1./tex.scaleFac);
    
    % use fixation ID to find corresponding info about the fixations.
    % This as one fixation can be in multiple AOIs
    fixAOI          = cell(size(temp,1),11);
    fixAOI(:,2)     = temp(:,1);    % fixation sequence number
    fixAOI(:,10:11) = temp(:,2:3);  % AOI sequence number and name
    for r=1:size(fixAOI,1)
        fnr = fixAOI{r,2};
        fixAOI(r,[1 3:9]) = {what{1},dat.fix.startT(fnr)/1000,dat.fix.dur(fnr)/1000,dat.fix.xpos(fnr),dat.fix.ypos(fnr),dat.fix.RMSxy(fnr),dat.fix.BCEA(fnr),dat.fix.fracinterped(fnr)*100};
    end
    
    % open file, write data
    fid = fopen(fullfile(dirs.AOIfix,[files(p).fname '.tsv']),'wt');
    fprintf(fid,'stimulus name\tfixNr\tstartT\tduration\tX (pix)\tY (pix)\tRMS\tBCEA\tdata loss (%%)\tAOI nr\tAOI name\n');
    schrijfdata = fixAOI.';
    fprintf(fid,'%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.1f\t%d\t%s\n',schrijfdata{:});
    fclose(fid);
end

fclose('all');

rmpath(genpath(dirs.funclib));
