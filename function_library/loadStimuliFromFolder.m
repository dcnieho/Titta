function [texs] = loadStimuliFromFolder(fold,extsOrFileNames,wpnt,scrSize,qDontScaleUp)

if nargin<5 || isempty(qDontScaleUp)
    qDontScaleUp = true;
end

if ~exist(fold,'dir')
    error('stimulus folder does not exist: %s',fold);
end

% prep filter, if any
if ~iscell(extsOrFileNames)
    extsOrFileNames = {extsOrFileNames};
end
[~,~,exts] = cellfun(@fileparts,extsOrFileNames,'uni',false);
qHaveFileFilter = ~any(cellfun(@isempty,exts));
if ~qHaveFileFilter
    % if no exts, only filename, then its actually a simple extension
    % filter (assumpion: we don't have image files without extention)
    exts = extsOrFileNames;
else
    % list of filenames, first get unique extensions to filter in
    % FileFromFolder
    exts = unique(exts);
    for e=1:length(exts)
        if exts{e}(1)=='.'
            exts{e}(1) = [];
        end
    end
end

% get stimuli
stims = FileFromFolder(fold,[],exts);
if qHaveFileFilter
    stimns = {stims.name};
    qPresent = ismember(extsOrFileNames,stimns);
    if ~all(qPresent)
        % error message missing stim files
    end
    % removed files we don't need from list to be loaded
    stims(~ismember(stimns,extsOrFileNames)) = [];
end

% now load one by one and (if wpnt provided) create textures
for p=1:length(stims)
    stimName = fullfile(fold,stims(p).name);
    
    tex = loadStimulus(stimName,wpnt,scrSize,qDontScaleUp);
    if p==1
        texs = tex;
    else
        texs = [texs tex]; %#ok<AGROW>
    end
end
