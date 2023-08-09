function [AOI] = loadAllAOIFolders(stimdir,ext,includeFolderList,includeAOIList)
% [AOI] = loadAllAOIFolders(stimdir,ext,includeList,includeAOIList)
% 
% For all stimuli, reads all AOI images and turns them into boolean masks,
% organized by stimulus

if nargin<2
    ext = '';
end
if nargin>2 && ~iscell(includeFolderList)
    includeFolderList = {includeFolderList};
end
if nargin<4
    includeAOIList = {};
end

foldnm      = FolderFromFolder(stimdir);

i=1;
for p=length(foldnm):-1:1
    if nargin>2 && ~isempty(includeFolderList) && ~ismember(foldnm(p).name,includeFolderList)
        continue;
    end
    AOI(i).name = foldnm(p).name;
    AOI(i).AOIs = loadAOIFolder(fullfile(stimdir, foldnm(p).name),ext,includeAOIList);
    i=i+1;
end
