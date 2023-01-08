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
pathExceptions  = [sep '\.git|' sep '\.github|' sep '\.venv|' sep 'deps|' sep 'demos|' sep '\.vs|' sep 'build|' sep 'TittaPy'];
qAdd            = cellfun(@isempty,regexpi(opaths,pathExceptions)); % true where regexp _didn't_ match
% also exclude either Windows or Linux mex folder
if IsLinux
    % exclude Windows and OSX mex folders
    qAdd = qAdd & contains(opaths,'TittaMex/64/Windows');
    qAdd = qAdd & contains(opaths,'TittaMex/64/OSX');
elseif IsOSX
    % exclude Windows and Linux mex folders
    qAdd = qAdd & contains(opaths,'TittaMex/64/Windows');
    qAdd = qAdd & contains(opaths,'TittaMex/64/Linux');
else
    % exclude Linux ans OSX mex folders
    qAdd = qAdd & contains(opaths,'TittaMex/64/Linux');
    qAdd = qAdd & contains(opaths,'TittaMex/64/OSX');
end
addpath(opaths{qAdd}); savepath;
disp('--->>> Added Titta to the path...')
