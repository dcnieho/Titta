% This class is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta or this class, please cite the following paper:
%
% Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A toolbox
% for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers. Behavior Research Methods.
% doi: https://doi.org/10.3758/s13428-020-01358-8

classdef MultiTargetCalibrationDisplay < handle
    properties (Access=private)
        pointIds;
        pointPoss;
        pointShown;
        pointActive = nan;
        oscillStartT;
    end
    properties
        doOscillate         = true;
        oscillatePeriod     = 1.5;
        fixBackSizeMax      = 35;
        fixBackSizeMin      = 15;
        fixFrontSize        = 5;
        fixBackColor        = 0;
        fixFrontColor       = 255;
        bgColor             = 127;
    end
    properties (Access=private, Hidden = true)
        qFloatColorRange    = [];
    end
    
    
    methods
        function obj = MultiTargetCalibrationDisplay()
            obj.setCleanState();
        end
        
        function setCleanState(obj)
            obj.pointIds = [];
            obj.pointPoss = [];
            obj.pointShown = [];
            obj.pointActive = nan;  % index into pointIds, pointPoss and pointShown
            obj.oscillStartT = [];
        end

        function setPoints(obj, pointIds, pointPoss)
            % NB: positions should be in pixels
            nPoint = length(pointIds);
            assert(nPoint==size(pointPoss,1))
            obj.pointIds = pointIds;
            obj.pointPoss = pointPoss;
            obj.pointShown = true(1,nPoint);
            obj.pointActive = nan;
        end

        function setActivePoint(obj, pointId)
            if isnan(pointId)
                obj.pointActive = nan;
                obj.oscillStartT = [];
                return
            end
            if ~isnan(obj.pointActive) && obj.pointIds(obj.pointActive)==pointId
                % indicated point is already active, nothing to do
                return
            end
            qPoint = pointId==obj.pointIds;
            if any(qPoint)
                obj.pointActive = find(qPoint,1);
                obj.oscillStartT = GetSecs();
            end
        end

        function hidePoint(obj, pointId)
            qPoint = pointId==obj.pointIds;
            assert(sum(qPoint)==1,'point %d not known',pointId);
            obj.pointShown(qPoint) = false;
        end
        
        function qAllowAcceptKey = doDraw(obj,wpnt,drawCmd,currentPoint,pos,~,~)
            % last two inputs, tick (monotonously increasing integer) and
            % stage ("cal" or "val") are not used in this code
            
            % if called with drawCmd == 'fullCleanUp', this is a signal
            % that calibration/validation is done, and cleanup can occur if
            % wanted. If called with drawCmd == 'sequenceCleanUp' that
            % means there should be a gap in the drawing sequence (e.g. no
            % smooth animation between two positions). For this one we can
            % just clean up state in both cases.
            if ismember(drawCmd,{'fullCleanUp','sequenceCleanUp'})
                obj.setCleanState();
                return;
            end
            
            % now that we have a wpnt, get some needed variables
            if isempty(obj.qFloatColorRange)
                obj.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % check point changed
            curT = GetSecs();       % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
            if strcmp(drawCmd,'new')
                if ~isnan(currentPoint)
                    if ~ismember(currentPoint, obj.pointIds)
                        % replace points, needed e.g. when manually showing
                        % a point
                        obj.pointIds = currentPoint;
                        obj.pointPoss = pos;
                        obj.pointShown = true;
                    end
                    
                    obj.setActivePoint(currentPoint);
                end
            elseif strcmp(drawCmd,'redo')
                % restart animation
                obj.oscillStartT = curT;
            else % drawCmd == 'draw'
                % nothing to do
            end
            
            % draw points
            Screen('FillRect',wpnt,obj.getColorForWindow(obj.bgColor)); % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
            for p=1:length(obj.pointIds)
                if ~obj.pointShown(p)
                    continue
                end
                % determine current point position
                pos = obj.pointPoss(p,:);

                % determine current point size
                if p==obj.pointActive && obj.doOscillate
                    dSize = obj.fixBackSizeMax-obj.fixBackSizeMin;
                    phase = cos((curT-obj.oscillStartT)/obj.oscillatePeriod*2*pi);
                    frac = 1-(phase/2+.5);  % start small
                    sz   = [obj.fixBackSizeMin + frac.*dSize  obj.fixFrontSize];
                else
                    sz   = [obj.fixBackSizeMin obj.fixFrontSize];
                end

                % draw
                obj.drawAFixPoint(wpnt,pos,sz);
            end

            qAllowAcceptKey = true;
        end
    end
    
    methods (Access = private, Hidden)
        function drawAFixPoint(obj,wpnt,pos,sz)
            % draws Thaler et al. 2012's ABC fixation point
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj.getColorForWindow(obj. fixBackColor), pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.getColorForWindow(obj.fixFrontColor), rectH);
                Screen('FillRect',wpnt,obj.getColorForWindow(obj.fixFrontColor), rectV);
                Screen('gluDisk', wpnt,obj.getColorForWindow(obj. fixBackColor), pos(p,1), pos(p,2), sz(2)/2);
            end
        end
        
        function clr = getColorForWindow(obj,clr)
            if obj.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end
