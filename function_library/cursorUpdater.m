% This class is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta or this function, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

classdef cursorUpdater < handle
    properties
        usingPoly
        cursorPolys
        cursorRects
        nAOI
        nElemPerAOI
        cursorLooks
        cursorIdxs
        qCursorReset    = true;
        cursorReset
        
        currCursor      = nan;
    end
    properties (Access=private, Hidden=true)
    end
    
    methods
        function this = cursorUpdater(cursors)
            this.updateCursors(cursors);
        end
        
        function update(this,x,y)
            if this.usingPoly
                idx = [];
                % get in which poly, if any. If polys overlap, first in the
                % list is used
                for p=1:this.nAOI
                    if inPoly([x y],this.cursorPolys{p})
                        idx = p;
                        break;
                    end
                end
            else
                if isempty(this.cursorRects)
                    idx = [];
                else
                    % get in which rect, if any. If rects overlap, first in
                    % the list is used
                    idx = find(inRect([x y],[this.cursorRects{:}]),1);
                end
            end
            
            % get corresponding cursor
            if isempty(idx)
                curr = this.cursorLooks(end);
            else
                curr = this.cursorLooks(this.cursorIdxs(idx));
            end
            
            % see if need to change
            if this.currCursor ~= curr
                if curr==-1
                    HideCursor();
                else
                    ShowCursor(curr);
                end
                this.currCursor = curr;
            end
        end
        
        function updateCursors(this,cursors)
            % process rects/polys
            this.usingPoly = isfield(cursors,'poly');
            if this.usingPoly
                this.cursorPolys = cursors.poly;
                this.nAOI        = length(this.cursorPolys);
                this.nElemPerAOI = ones(1,this.nAOI);
            else
                if ~iscell(cursors.rect)
                    cursors.rect = num2cell(cursors.rect,1);
                end
                this.cursorRects = cursors.rect;
                this.nAOI        = size(cursors.rect,2);
                this.nElemPerAOI = cellfun(@(x) size(x,2),cursors.rect);
            end
            % cursor looks are numbered IDs as eaten by ShowMouse. -1 means
            % hide cursor
            this.cursorLooks = [cursors.cursor cursors.other];
            this.cursorIdxs  = SmartVec(1:this.nAOI,this.nElemPerAOI,0);
            
            % optional (default on) reset of cursor when calling reset().
            % Have it as an option as some function out of the reach of the
            % user always call reset upon exit, user can here configure if
            % it actually does something
            this.qCursorReset = true;
            if isfield(cursors,'qReset')
                this.qCursorReset = cursors.qReset;
            end
            % if resetting, indicate what cursor to reset to. if empty, we
            % reset to cursors.other.
            this.cursorReset = [];
            if isfield(cursors,'reset')
                this.cursorReset = cursors.reset;
            end
        end
        
        function reset(this)
            if ~this.qCursorReset
                return;
            end
            
            if ~isempty(this.cursorReset)
                curr = this.cursorReset;
            else
                curr = this.cursorLooks(end);
            end
            if curr==-1
                HideCursor();
            else
                ShowCursor(curr);
            end
        end
    end
end