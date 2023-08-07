function [AOI] = loadAOIFolder(stimdir,ext,includeList)
% [AOI] = loadAOIFolder(stimdir)
%
% Leest alle AOIplaten in en maakt er booleanmatrices van

extrain = {};
if nargin>1 && ~isempty(ext)
    extrain = {'[]',ext};
end
if nargin>2 && ~iscell(includeList)
    includeList = {includeList};
end

AOIpl  = FileFromFolder(stimdir,extrain{:});       % Kijk hoeveel AOIs er zijn voor deze stimulus

% filter out AOIs not in the include list, if any
for p=length(AOIpl):-1:1
    if nargin>2 && ~isempty(includeList) && ~ismember(AOIpl(p).fname,includeList)
        AOIpl(p) = [];
    end
end

% early exit if no AOIs
if isempty(AOIpl)
    AOI = [];
    return;
end

% load in AOIs
for q=length(AOIpl):-1:1
    AOIplnaam       = fullfile(stimdir, AOIpl(q).name);
    
    % get type of image
    info = imfinfo(AOIplnaam);
    if strcmp(info.ColorType,'indexed')
        [a,b] = imread(AOIplnaam);
        a = ind2rgb(a,b);
    else
        a = imread(AOIplnaam);
    end
    % convert to double
    if isa(a,'uint8')
        a = double(a)/255;
    end
    % now convert to bool mask
    AOI(q).bool     = a;
    AOI(q).bool     = AOI(q).bool(:,:,1);
    if ~islogical(AOI(q).bool)
        AOI(q).bool = AOI(q).bool > .8;                     % alles boven .8 rekenen we als wit, 0 is zwart
    end
    
    AOI(q).name     = AOIpl(q).fname;                       % AOI naam
    AOI(q).fname    = AOIpl(q).name;                        % AOI naam
end
