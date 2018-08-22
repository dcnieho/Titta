classdef AnimatedCalibrationDisplay < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'moving',1, 'shrinking',2 ,'waiting',3);
    end
    properties (Access=private)
        calState;
        currentPoint;
        lastPoint;
        moveStartT;
        shrinkStartT;
        oscillStartT;
        moveDuration;
        scrSize;
    end
    properties
        doShrink            = true;
        shrinkTime          = 0.5;
        doMove              = true;
        moveTime            = 1;    % for whole screen distance, duration will be proportionally shorter when dot moves less than whole screen distance
        doOscillate         = true;
        oscillatePeriod     = 1.5;
        fixBackSizeMax      = 50;
        fixBackSizeMaxOsc   = 35;
        fixBackSizeMin      = 15;
        fixFrontSize        = 5;
        fixBackColor        = 0;
        fixFrontColor       = 255;
        bgColor             = 127;
    end
    
    
    methods
        function obj = AnimatedCalibrationDisplay()
            obj.setCleanState();
            % get size of screen. NB: i'm assuming only one screen is
            % attached (more than one is usually a bad idea for timing on
            % Windows!)
            obj.scrSize = Screen('Rect',0); obj.scrSize(1:2) = [];
        end
        
        function setCleanState(obj)
            obj.calState = obj.calStateEnum.undefined;
            obj.currentPoint= nan(1,3);
            obj.lastPoint= nan(1,3);
        end
        
        function qAllowAcceptKey = doDraw(obj,wpnt,currentPoint,pos,~)
            % if called with nan as first input, this is a signal that
            % calibration/validation is done, and cleanup can occur if
            % wanted
            if isnan(wpnt)
                obj.setCleanState();
                return;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the last input to this function to animate based on call sequence number to this function
            if obj.currentPoint(1)~=currentPoint
                if obj.doMove && ~isnan(obj.currentPoint(1))
                    obj.calState = obj.calStateEnum.moving;
                    obj.moveStartT = curT;
                    % dot should move at constant speed regardless of
                    % distance to cover, moveTime contains time to move
                    % over width of whole screen. Adjust time to proportion
                    % of screen covered by current move
                    dist = hypot(obj.currentPoint(2)-pos(1),obj.currentPoint(3)-pos(2));
                    obj.moveDuration = obj.moveTime*dist/obj.scrSize(1);
                elseif obj.doShrink
                    obj.calState = obj.calStateEnum.shrinking;
                    obj.shrinkStartT = curT;
                else
                    obj.calState = obj.calStateEnum.waiting;
                    obj.oscillStartT = curT;
                end
                
                obj.lastPoint       = obj.currentPoint;
                obj.currentPoint    = [currentPoint pos];
            end
            
            % check state transition
            if obj.calState==obj.calStateEnum.moving && (curT-obj.moveStartT)>obj.moveDuration
                if obj.doShrink
                    obj.calState = obj.calStateEnum.shrinking;
                    obj.shrinkStartT = curT;
                else
                    obj.calState = obj.calStateEnum.waiting;
                    obj.oscillStartT = curT;
                end
            elseif obj.calState==obj.calStateEnum.shrinking && (curT-obj.shrinkStartT)>obj.shrinkTime
                obj.calState = obj.calStateEnum.waiting;
                obj.oscillStartT = curT;
            end
            
            % determine current point position
            if obj.calState==obj.calStateEnum.moving
                frac = (curT-obj.moveStartT)/obj.moveDuration;
                curPos = obj.lastPoint(2:3).*(1-frac) + obj.currentPoint(2:3).*frac;
            else
                curPos = obj.currentPoint(2:3);
            end
            
            % determine current point size
            if obj.calState==obj.calStateEnum.moving
                sz   = [obj.fixBackSizeMax obj.fixFrontSize];
            elseif obj.calState==obj.calStateEnum.shrinking
                dSize = obj.fixBackSizeMax-obj.fixBackSizeMin;
                frac = 1 - (curT-obj.shrinkStartT)/obj.shrinkTime;
                sz   = [obj.fixBackSizeMin + frac.*dSize  obj.fixFrontSize];
            else
                if obj.doOscillate
                    dSize = obj.fixBackSizeMaxOsc-obj.fixBackSizeMin;
                    phase = cos((curT-obj.oscillStartT)/obj.oscillatePeriod*2*pi);
                    if obj.doShrink
                        frac = 1-(phase/2+.5);  % start small
                    else
                        frac =    phase/2+.5;   % start big
                    end
                    sz   = [obj.fixBackSizeMin + frac.*dSize  obj.fixFrontSize];
                else
                    sz   = [obj.fixBackSizeMin obj.fixFrontSize];
                end
            end
            
            % determine if we're ready to accept the user pressing the
            % accept calibration point button. User should not be able to
            % press it if point is not yet at the final position
            qAllowAcceptKey = obj.calState~=obj.calStateEnum.moving;
            
            % draw
            obj.drawAFixPoint(wpnt,curPos,sz);
        end
    end
    
    methods (Access = private, Hidden)
        function drawAFixPoint(obj,wpnt,pos,sz)
            % draws Thaler et al. 2012's ABC fixation point
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj. fixBackColor, pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.fixFrontColor, rectH);
                Screen('FillRect',wpnt,obj.fixFrontColor, rectV);
                Screen('gluDisk', wpnt,obj. fixBackColor, pos(p,1), pos(p,2), sz(2)/2);
            end
        end
    end
end