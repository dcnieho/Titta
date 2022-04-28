function idxStruct = structPathToIdx(varargin)

qCell = false;
if iscell(varargin{1})
    varargin = varargin{1};
end

idxStruct = cell(size(varargin));
for p=1:length(varargin)
    parts = regexp(varargin{p},'\.','split');
    idxStruct{p} = struct('type','.','subs',parts);
end

if isscalar(idxStruct) && ~qCell
    idxStruct = idxStruct{1};
end
