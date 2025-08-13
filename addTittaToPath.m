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
pathExceptions  = [sep '\.git|' sep '\.github|' sep '\.venv|' sep 'deps|' sep 'demos|' sep '\.vs|' sep 'build|' sep 'TittaPy|' sep 'TittaLSLPy|' sep 'cppLSLTest|' sep 'demo_analysis|' sep 'demo_experiments'];

qAdd            = cellfun(@isempty,regexpi(opaths,pathExceptions)); % true where regexp _didn't_ match
addpath(opaths{qAdd});

savepath;
disp('--->>> Added Titta to the path...')
