function addTittaToPath()
% adds titta to path, ignoring at least some of the unneeded folders
mpath           = path;
mpath           = strsplit(mpath, pathsep);
opath           = fileparts(mfilename('fullpath'));

% remove any old path values
opathesc        = regexptranslate('escape',opath);
qTittaPath      = ~cellfun(@isempty,regexpi(mpath,opathesc));
if any(qTittaPath)
    rmpath(mpath{qTittaPath});
end

% add new paths
opaths          = genpath(opath);
opaths          = strsplit(opaths,pathsep);
sep             = regexptranslate('escape',filesep);
pathExceptions  = [sep '\.git|' sep '\.github|' sep '\.venv|' sep 'deps|' sep 'demos|' sep '\.vs|' sep 'build|' sep 'TittaPy|' sep 'demo_analysis|' sep 'demo_experiments'];
qAdd            = cellfun(@isempty,regexpi(opaths,pathExceptions)); % true where regexp _didn't_ match
% also exclude Windows, Linux or OSX mex folders, as needed
% need to know what platform we're on
isWin    = strcmp(computer,'PCWIN')                             || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<STREMP>
isLinux  = strcmp(computer,'GLNX86')                            || strcmp(computer,'GLNXA64') || ~isempty(strfind(computer, 'linux-gnu')); %#ok<STREMP>
isOSX    = strcmp(computer,'MAC')    || strcmp(computer,'MACI') || strcmp(computer, 'MACI64') || ~isempty(strfind(computer, 'apple-darwin')); %#ok<STREMP>
if ~isWin && ~isLinux && ~isOSX
    error('unsupported platform')
end
if ~isLinux
    % exclude Linux mex folder
    qAdd = qAdd & cellfun(@isempty,regexpi(opaths,'TittaMex(\/|\\)64(\/|\\)Linux'));
end
if ~isOSX
    % exclude OSX mex folder
    qAdd = qAdd & cellfun(@isempty,regexpi(opaths,'TittaMex(\/|\\)64(\/|\\)OSX'));
end
if ~isWin
    % exclude Windows mex folder
    qAdd = qAdd & cellfun(@isempty,regexpi(opaths,'TittaMex(\/|\\)64(\/|\\)Windows'));
end
addpath(opaths{qAdd}); savepath;
disp('--->>> Added Titta to the path...')
