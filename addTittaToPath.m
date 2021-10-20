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
pathExceptions  = [sep '\.git|' sep 'deps|' sep 'demos|' sep '\.vs|' sep 'build'];
qAdd            = cellfun(@isempty,regexpi(opaths,pathExceptions)); % true where regexp _didn't_ match
% also exclude either Windows or Linux mex folder
if IsLinux
    % exclude Windows mex folder
    qAdd = qAdd & cellfun(@isempty,strfind(opaths,'TittaMex/64/Windows'));
else
    % exclude Linux mex folder
    qAdd = qAdd & cellfun(@isempty,strfind(opaths,'TittaMex\64\Linux'));
end
addpath(opaths{qAdd}); savepath;
disp('--->>> Added Titta to the path...')