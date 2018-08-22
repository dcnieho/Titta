function fhndl = cursorUpdater(cursors)

if nargin<1 || isempty(cursors)
    fhndl.update = @(~,~) 1;   % dummy function that swallows arguments and is noop
    fhndl.reset  = @(~,~) 1;
    return;
end

% process cursors
cursorRects = [cursors.rect{:}];
% cursor looks are numbered IDs as eaten by ShowMouse. -1 means hide cursor
cursorLooks = [cursors.cursor cursors.other];
cursorIdxs  = SmartVec(1:length(cursors.rect),cellfun(@(x) size(x,2),cursors.rect),0);
currCursor  = nan;
% optional (default on) reset of cursor when calling reset(). Have it as an
% option as some function out of the reach of the user always call reset
% upon exit, user can here configure if it actually does something
qCursorReset = true;
if isfield(cursors,'qReset')
    qCursorReset = cursors.qReset;
end
% if resetting, indicate what cursor to reset to. if empty, we reset to
% cursors.other.
cursorReset = [];
if isfield(cursors,'reset')
    cursorReset = cursors.reset;
end

fhndl.update = @update;
fhndl.reset  = @reset;

    function update(x,y)
        if isempty(cursorRects)
            idx = [];
        else
            % get in which rect, if any. If rects overlap, first in the list is
            % used
            idx = find(inRect([x y],cursorRects),1);
        end
        
        % get corresponding cursor
        if isempty(idx)
            curr = cursorLooks(end);
        else
            curr = cursorLooks(cursorIdxs(idx));
        end
        
        % see if need to change
        if currCursor ~= curr
            if curr==-1
                HideCursor();
            else
                ShowCursor(curr);
            end
            currCursor = curr;
        end
    end

    function reset()
        if ~qCursorReset
            return;
        end
        
        if ~isempty(cursorReset)
            curr = cursorReset;
        else
            curr = cursorLooks(end);
        end
        if curr==-1
            HideCursor();
        else
            ShowCursor(curr);
        end
    end

end