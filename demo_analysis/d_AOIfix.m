%*****************************************************************
%*****************************************************************

clear variables; clear mex; close all; fclose('all'); clc

dbstop if error % for debugging: trigger a debug point when an error occurs

                                dirs.home       = cd;
cd data;                        dirs.data       = cd;
        cd mat;                 dirs.mat        = cd;
        cd ..;
        cd evt;                 dirs.msgs       = cd;
        cd ..;
        cd fix;                 dirs.fix        = cd;
        cd ..;
        cd AOIfix;              dirs.AOIfix     = cd;
        cd ..;
        cd samples;             dirs.samples    = cd;
        cd ..;
        cd samples_ophak;       dirs.samplesO   = cd;
        cd ..;
cd ..;
cd function_library;            dirs.funclib    = cd;
cd ..;
cd results;                     dirs.results    = cd;
cd ..;
cd stimuli;                     dirs.stim       = cd;
        cd images;              dirs.im         = cd;
        cd ..;
        cd AOIs;                dirs.AOIim      = cd;
cd(dirs.home);

fs = filesep;
addpath(genpath(dirs.funclib));

%*****************************************************************
%*****************************************************************

% settings

whichTasks = {
    'practice',  'screen/(.+): practiceStim.%d$'
    'test',      'screen/(.+): testStim.%d$'
    };

%*****************************************************************

%%% get all trials, parse into subject and stimulus
[files,nfiles] = FileFromFolder(dirs.fix,[],'mat');

if 0
    % filter so we only get data that matches the filter. uses regexp
    filtstr = 'S07';
    results = regexpi({files.name}.',filtstr,'start');
    files   = files(~cellfun(@isempty,results));
    nfiles  = length(files);
end

% load all AOIs
AOI     = loadAllAOIFolders(dirs.AOIim,'png');    % AOI is struct met alle gegevens van de AOI masks
AOInms  = {AOI.name};

% per subject, per trial, read data and see which AOIs fixations are in, if
% any. 0 is other, -1 is out of screen
for p=1:nfiles
    disp(files(p).fname)
    
    fs      = strsplit(files(p).name,' Samples_');
    baseFile= fs{1};
    msgFile = [baseFile ' Samples.txt'];
    fs      = strsplit(files(p).name,'_');
    task    = fs{end-1};
    qTask   = strcmp(task,whichTasks(:,1));
    if ~any(qTask)
        continue;
    end
    run     = sscanf(fs{end},'R%f.txt');
    % load fix data
    dat     = load(fullfile(dirs.fix,[files(p).fname '.mat'])); dat = dat.dat;
    
    if isempty(dat.time)
        warning('no data for %s, empty file',files(p).fname);
        continue;
    end
    
    % get more info about stimulus shown etc
    mat     = load(fullfile(dirs.mat,baseFile),'screens','texs','expt');
    
    msgs    = cellfun(@(x) x.IDmsg,mat.screens,'uni',false);
    matchStr= sprintf(whichTasks{qTask,2},run);
    iWhich  = find(~cellfun(@isempty,regexp(msgs,matchStr)));
    stim    = regexp(msgs{iWhich},matchStr,'tokens','once');
    stim    = stim{1};
    
    qTex    = arrayfun(@(x) strcmp(x.fInfo.name,stim),mat.texs);
    assert(sum(qTex)==1,'No or too many presentation info (texs field) found for this stimulus')
    tex     = mat.texs(qTex);
    qAOI    = strcmp(stim,AOInms);
    assert(sum(qAOI)==1,'No or too many AOIs lists found for this stimulus: %s',stim)
    
    % throw out fixations that onset before first stimulus shown
    qDel = dat.fix.startT<=0;
    fields = fieldnames(dat.fix);
    for f=1:length(fields)
        if ~isscalar(dat.fix.(fields{f}))
            dat.fix.(fields{f})(qDel) = [];
        end
    end
    
    % check sizes are correct, i.e., AOI boolean images macth in size with
    % shown images
    AOIbools    = {AOI(qAOI).AOIs.bool};
    szs         = cellfun(@size,AOIbools,'uni',false);
    assert(isequal(tex.size,szs{:}),'Some AOIs have wrong size (doesn''t match stimulus)');
    
    % see which AOIs fixations are in
    temp    = bepaalAOIfixaties3(AOI(qAOI).AOIs,dat.fix.xpos,dat.fix.ypos,mat.expt.scr.res,tex.scrRect,1./tex.scaleFac);
    
    % use fixation ID to find corresponding info about the fixations.
    % This as one fixation can be in multiple AOIs
    fixAOI          = cell(size(temp,1),13);
    fixAOI(:,4)     = temp(:,1);
    fixAOI(:,12:13) = temp(:,2:3);
    for r=1:size(fixAOI,1)
        fnr = fixAOI{r,4};
        fixAOI(r,[1:3 5:11]) = {task,run,stim,dat.fix.startT(fnr)/1000,dat.fix.dur(fnr)/1000,dat.fix.xpos(fnr),dat.fix.ypos(fnr),dat.fix.RMSxy(fnr),dat.fix.BCEA(fnr),dat.fix.fracinterped(fnr)*100};
    end
    
    % open file, write data
    fid = fopen(fullfile(dirs.AOIfix,[files(p).fname '.txt']),'wt');
    fprintf(fid,'phase\tsequence nr\tstimulus name\tfixNr\tstartT\tduration\tX (pix)\tY (pix)\tRMS\tBCEA\tdata loss (%%)\tAOI nr\tAOI name\n');
    schrijfdata = fixAOI.';
    fprintf(fid,'%s\t%d\t%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.1f\t%d\t%s\n',schrijfdata{:});
    fclose(fid);
end

fclose('all');

rmpath(genpath(dirs.funclib));
