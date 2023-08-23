function [fixAOI] = detAOIfix(AOIs,ppx,ppy,scrRes,stimRect,imgScale)
%
% For each fixation (ppx, ppy), check if it is in any of the AOIs.
% Fixations can be in multiple AOIs if AOIs overlap
%
% output (cell array):
%   kolom 1: fixation ID, sequential by input
%   kolom 2: AOI nr
%   kolom 3: AOI naam


% prepare output
fixAOI = cell(length(ppx),3);
fixAOI(:,1) = num2cell(1:length(ppx));

% filter out fixations not on the screen
ppx         = ppx(:);
ppy         = ppy(:);
qOnscreen   = ppx>=1 & ppy>=1 & ppx<=scrRes(1) & ppy<=scrRes(2);

fixAOI(~qOnscreen,2) = {-2};
fixAOI(~qOnscreen,3) = {'off screen'};

% filter fixations not on stimulus
qOnstim     = ppx>=stimRect(1)+1/imgScale & ppy>=stimRect(2)+1/imgScale & ppx<=stimRect(3) & ppy<=stimRect(4);
osI         = find(qOnstim);

fixAOI(qOnscreen&~qOnstim,2) = {-1};
fixAOI(qOnscreen&~qOnstim,3) = {'off stimulus'};

% select onscreen data + scale up and offset data
wx          = round((ppx(qOnstim)-stimRect(1))*imgScale);
wy          = round((ppy(qOnstim)-stimRect(2))*imgScale);

if isempty(wx)
    % no fixations on screen
    % already filled output, return
    return;
end

if isempty(AOIs)
    % no AOIs for this stimulus, so no fixations on an AOI
    % early exit
    fixAOI(qOnstim,2) = {0};
    fixAOI(qOnstim,3) = {'other'};
    warning('no AOIs found for %s',stim);
    return;
end

% make 3D AOI boolean, concat all AOIs for the stimulus along third
% dimension
sz          = size(AOIs(1).bool);
bigAOIbool  = cat(3,AOIs.bool);
AOInames    = {AOIs.name};
AOInumbers  = 1:length(AOIs);

%%% check which fixations are in which AOIs
% turn fixation positions into linear indices into bigAOIbool
indmat3D    = repmat(prod(sz)*[0:size(bigAOIbool,3)-1],length(wx),1);  %#ok<NBRAK1> - offset for linear indices in the third dimension
inds        = repmat((wx-1)*sz(1)+wy,1,size(bigAOIbool,3));
inds        = inds+indmat3D;

% use linear indices to see which AOIs each fixation is in
qAOI        = bigAOIbool(inds);                 % every column is an AOI, every row a fixation
qInAOI      = sum(qAOI,2)>0;                    % fixation was in at least one AOI

%%% now add to output
% deal with case of fixation that wasn't in any AOI
fixAOI(osI(~qInAOI),2) = {0};
fixAOI(osI(~qInAOI),3) = {'other'};
% deal with fixations that fell in an AOI
fixAOI(osI(qInAOI),:) = []; % remove and add per fixation, as some fixations are in multiple AOIs
rows = find(qInAOI);
for p=1:length(rows)
    r = rows(p);
    nAOI = sum(qAOI(r,:));
    temp = [num2cell([repmat(osI(r),1,nAOI); AOInumbers(qAOI(r,:))]).', AOInames(qAOI(r,:)).'];
    fixAOI(end+[1:nAOI],:) = temp; %#ok<NBRAK1> 
end

% sort by fix ID to keep original order
[~,i]  = sort([fixAOI{:,1}]);
fixAOI = fixAOI(i,:);
