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

classdef AnimatedCalibrationDisplay < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'moving',1, 'shrinking',2 ,'waiting',3 ,'blinking',4);
    end
    properties (Access=private)
        calState;
        currentPoint;
        lastPoint;
        moveStartT;
        shrinkStartT;
        oscillStartT;
        blinkStartT;
        moveDuration;
        moveVec;
        accel;
        scrSize;
    end
    properties
        doShrink            = true;
        shrinkTime          = 0.5;
        doMove              = true;
        moveTime            = 1;        % for whole screen distance, duration will be proportionally shorter when dot moves less than whole screen distance
        moveWithAcceleration= true;
        doOscillate         = true;
        oscillatePeriod     = 1.5;
        blinkInterval       = 0.3;
        blinkCount          = 2;
        fixBackSizeBlink    = 35;
        fixBackSizeMax      = 50;
        fixBackSizeMaxOsc   = 35;
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
        function obj = AnimatedCalibrationDisplay()
            obj.setCleanState();
        end
        
        function setCleanState(obj)
            obj.calState = obj.calStateEnum.undefined;
            obj.currentPoint= nan(1,3);
            obj.lastPoint= nan(1,3);
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
            if isempty(obj.scrSize)
                obj.scrSize = Screen('Rect',wpnt); obj.scrSize(1:2) = [];
            end
            if isempty(obj.qFloatColorRange)
                obj.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % check point changed
            curT = GetSecs;     % instead of using time directly, you could use the 'tick' call sequence number input to this function to animate your display
            if strcmp(drawCmd,'new')
                if obj.doMove && ~isnan(obj.currentPoint(1))
                    obj.calState = obj.calStateEnum.moving;
                    obj.moveStartT = curT;
                    % dot should move at constant speed regardless of
                    % distance to cover, moveTime contains time to move
                    % over width of whole screen. Adjust time to proportion
                    % of screen width covered by current move
                    dist = hypot(obj.currentPoint(2)-pos(1),obj.currentPoint(3)-pos(2));
                    obj.moveDuration = obj.moveTime*dist/obj.scrSize(1);
                    if obj.moveWithAcceleration
                        obj.accel   = dist/(obj.moveDuration/2)^2;  % solve x=.5*a*t^2 for a, use dist/2 for x
                        obj.moveVec = (pos(1:2)-obj.currentPoint(2:3))/dist;
                    end
                elseif obj.doShrink
                    obj.calState = obj.calStateEnum.shrinking;
                    obj.shrinkStartT = curT;
                else
                    obj.calState = obj.calStateEnum.waiting;
                    obj.oscillStartT = curT;
                end
                
                obj.lastPoint       = obj.currentPoint;
                obj.currentPoint    = [currentPoint pos];
            elseif strcmp(drawCmd,'redo')
                % start blink, pause animation.
                obj.calState = obj.calStateEnum.blinking;
                obj.blinkStartT = curT;
            else % drawCmd == 'draw'
                % regular draw: check state transition
                if (obj.calState==obj.calStateEnum.moving && (curT-obj.moveStartT)>obj.moveDuration) || ...
                   (obj.calState==obj.calStateEnum.blinking && (curT-obj.blinkStartT)>obj.blinkInterval*obj.blinkCount*2)
                    % move finished or blink finished
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
            end
            
            % determine current point position
            if obj.calState==obj.calStateEnum.moving
                frac = (curT-obj.moveStartT)/obj.moveDuration;
                if obj.moveWithAcceleration
                    if frac<.5
                        curPos = obj.lastPoint(2:3)    + obj.moveVec*.5*obj.accel*(                 curT-obj.moveStartT)^2;
                    else
                        % implement deceleration by accelerating from the
                        % other side in backward time
                        curPos = obj.currentPoint(2:3) - obj.moveVec*.5*obj.accel*(obj.moveDuration-curT+obj.moveStartT)^2;
                    end
                else
                    curPos = obj.lastPoint(2:3).*(1-frac) + obj.currentPoint(2:3).*frac;
                end
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
            elseif obj.calState==obj.calStateEnum.blinking
                sz   = [obj.fixBackSizeBlink obj.fixFrontSize];
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
            qAllowAcceptKey = ismember(obj.calState,[obj.calStateEnum.shrinking obj.calStateEnum.waiting]);
            
            % draw
            Screen('FillRect',wpnt,obj.getColorForWindow(obj.bgColor)); % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
            if obj.calState~=obj.calStateEnum.blinking || mod((curT-obj.blinkStartT)/obj.blinkInterval/2,1)>.5
                obj.drawAFixPoint(wpnt,curPos,sz);
            end
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
