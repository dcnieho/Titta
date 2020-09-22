function addTittaToPath()
% adds titta to path, ignoring at least some of the unneeded folders
mpath			= path;
mpath			= strsplit(mpath, pathsep);
opath			= fileparts(mfilename('fullpath'));
for i = 1:length(mpath)
	if ~isempty(regexpi(mpath{i},opath))
		rmpath(mpath{i}); % remove any old path values
	end
end
opaths			= genpath(opath); 
opaths			= strsplit(opaths,pathsep);
newpaths		= {};
sep             = regexptranslate('escape',filesep);
pathExceptions  = [sep '\.git|' sep 'src|' sep 'deps'];
for i=1:length(opaths)
	if isempty(regexpi(opaths{i},pathExceptions))
		newpaths{end+1}=opaths{i};
	end
end
newpaths = strjoin(newpaths,pathsep);
addpath(newpaths); savepath;
disp('--->>> Added Titta to the path...')