classdef MultiStepCalController < handle
    properties (Constant)
        pointStateEnum = struct('nothing',0, 'collecting',1, 'discarding',2, 'collected', 3);
    end
    properties (SetAccess=private)
        step                        = 1;            % state

        gazePos;
        gazeOnScreen;                               % true if we have gaze for both eyes and the average position is on screen
        onScreenTimestamp;                          % time of start of episode of gaze on screen
        offScreenTimestamp;                         % time of start of episode of gaze off screen
        onTargetTimestamp;                          % time of start of episode of gaze on video (for calibration)
        latestTimestamp;                            % latest gaze timestamp

        calPoints                   = [];           % ID of calibration points to run by the controller, in provided order
        calPoss                     = [];           % corresponding positions
        calPointsState              = [];
        gazedCalPoint               = nan;
        activeCalPoint              = nan;          % point currently being calibrated or discarded

        gazingOnRewardTarget        = false;
        gazingOnManualPoint         = false;
    end
    properties
        % comms
        EThndl;
        calDisplay;                                 % expected to be a MultiTargetCalibrationDisplay instance
        rewardProvider;

        gazeFetchDur                = 100;          % duration of gaze samples to peek on each iteration (ms, e.g., last 100 ms of gaze)
        gazeAggregationMethod       = 1;            % 1: use mean of all samples during last gazeFetchDur ms, 2: use mean of last valid sample during last gazeFetchDur ms
        minValidGazeFrac            = .5;           % minimum fraction of gaze samples that should be valid. If not exceeded, gaze is counted as offscreen
        maxOffScreenTime            = 300;          % ms.
        scrRes;

        calMargin1                  = .12;          % for step 1 (center point): maximum distance of current gaze from center of screen to be counted as on the center calibration point
        calMargin2                  = .1;           % for step 2+: minimum distance of current gaze from center of screen to be counted as on a given point
        calMarginDirection          = 22.5;         % for step 2+: check if gaze direction w.r.t. center is within this many degrees from a calibration point
        calOnTargetTime             = 800;          % ms
        calAfterEachStep            = false;
        calAOIColor                 = [255 0 0];

        showRewardTargetWhenDone    = true;         % if true, shows a centered square on the screen after the calibration logic is finished and the controller disengages. Gaze on the square triggers rewards (for demo purposes)
        nonActiveRewardDelay        = 500;          % ms, time until reward is dispensed when looking at the (demo) reward square
        rewardTargetRadius          = .15;          % radius, fraction of horizontal screen resolution
        rewardTargetColor           = [255 0 0];

        showGazeToOperator          = true;         % if true, aggregated gaze as used by the controller is drawn as a crosshair on the operator screen
        logTypes                    = 0;            % bitmask: if 0, no logging. bit 1: print basic messages about what its up to. bit 2: print each command received in receiveUpdate(), bit 3: print messages about rewards (many!)
        logReceiver                 = 0;            % if 0: matlab command line. if 1: Titta
    end
    properties (Access=private,Hidden=true)
        isActive                    = false;
        isDone                      = false;
        isShowingRewardTarget       = false;
        isShowingPointManually      = false;
        manualPoint                 = [nan nan nan];
        dispensingReward            = false;
        shouldRewindState           = false;
        shouldClearCal              = false;
        clearCalNow                 = false;
        activationCount             = struct('cal',0, 'val',0);
        shouldUpdateStatusText;
        trackerFrequency;                           % calling obj.EThndl.frequency is blocking when a calibration action is ongoing, so cache the value
        qFloatColorRange;

        awaitingPointResult         = 0;            % 0: not awaiting anything; 1: awaiting point collect result; 2: awaiting point discard result; 3: awaiting compute and apply result; 4: calibration clearing result
        lastUpdate                  = {};

        drawState                   = 0;            % 0: don't issue draws from here; 1: draw command should be given
        drawExtraFrame              = false;        % because command in tick() is only processed in Titta after calibration display is drawn, we need to draw one extra frame here to avoid flashing when starting calibration point collection

        backupPaceDuration          = struct('cal',[],'val',[]);
    end
    
    
    methods
        function obj = MultiStepCalController(EThndl,calDisplay,scrRes,rewardProvider)
            obj.setCleanState();
            obj.EThndl = EThndl;
            assert(isa(calDisplay,"MultiTargetCalibrationDisplay"))
            obj.calDisplay = calDisplay;
            if nargin>2 && ~isempty(scrRes)
                obj.scrRes = scrRes;
            end
            if nargin>3 && ~isempty(rewardProvider)
                obj.rewardProvider = rewardProvider;
            end
        end

        function setCalPoints(obj, calPoints, calPoss)
            assert(~obj.isActive,'cannot set calibration points when already calibrating or calibrated')
            assert(isscalar(calPoints{1}) && all(calPoss{1}==.5),'First step must be a single calibration point at the center of the screen')
            obj.calPoints       = calPoints;                % ID of calibration points to run by the controller, in provided order
            obj.calPoss         = calPoss;                  % corresponding positions
            obj.calPointsState  = cellfun(@(x) repmat(obj.pointStateEnum.nothing, 1, size(x,1)),obj.calPoss,'uni',false);
            if ~isempty(obj.scrRes)
                obj.checkCalPointScale();
            end
        end

        function commands = tick(obj)
            commands = {};
            % returns a commands that the interface should execute.
            % Possible commands are:
            % 'collect_point', 'discard_point', 'compute_and_apply', 'clear', 'disable_controller'
            % a commannd should prepended with 'cal' or 'val' to indicate
            % what mode we expect to be in and depending on the command
            % should be followed by parameters (e.g. which calibration
            % point to collect data for). Example command:
            % {'cal','collect_point', parameters....}
            if ~isempty(obj.rewardProvider)
                obj.rewardProvider.tick();
            end

            nothingToDo = ~obj.isActive && ~obj.isShowingRewardTarget && ~obj.isShowingPointManually;
            % check if reward should be switched off because looking
            % outside of the screen
            offScreenTime = obj.latestTimestamp-obj.offScreenTimestamp;
            if offScreenTime > obj.maxOffScreenTime || nothingToDo
                obj.reward(false);
            end
            if nothingToDo
                return;
            end

            obj.updateGaze();
            if ~obj.isActive && (obj.isShowingRewardTarget || obj.isShowingPointManually)     % check like this: this logic should only kick in when controller is not active
                % check if should give reward for looking at manually shown
                % calibration point or reward target
                if obj.isShowingPointManually
                    if obj.gazingOnManualPoint
                        obj.reward(true);
                    else
                        obj.reward(false);
                    end
                else
                    onDur = obj.latestTimestamp-obj.onTargetTimestamp;
                    if onDur > obj.nonActiveRewardDelay
                        obj.reward(true);
                    else
                        obj.reward(false);
                    end
                end
                return
            end
            
            % got this far: controller is active
            if obj.clearCalNow
                if obj.awaitingPointResult~=4
                    commands = {{'cal','clear'}};
                    obj.awaitingPointResult = 4;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('calibration state is not clean upon controller activation. Requesting to clear it first');
                    end
                elseif obj.awaitingPointResult==4 && ~isempty(obj.lastUpdate) && strcmp(obj.lastUpdate{1},'cal_cleared')
                    obj.awaitingPointResult = 0;
                    obj.clearCalNow = false;
                    obj.lastUpdate = {};
                    obj.isDone = false;
                    obj.step = 1;
                    obj.setCalDisplayPoints();
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('calibration data cleared, starting controller');
                    end
                end
            else
                commands = obj.calibrate();
            end
        end

        function receiveUpdate(obj,~,currentPoint,posNorm,posPix,~,event,callResult)
            % receiveUpdate(titta_instance,currentPoint,posNorm,posPix,stage,event,callResult)
            % we don't need all the input arguments, so we ignore some

            if bitget(obj.logTypes,2)
                obj.log_to_cmd('received event: %s',event);
            end
            % act on event communicated to the controller:
            % NB: some events are of no interest to this controller and
            % thus ignored: val_activate, val_deactivate, val_enter,
            % val_collect_started, val_collect_done, val_discard
            switch event
                case 'cal_activate'
                    % controller activated
                    obj.activationCount.cal = obj.activationCount.cal+1;
                    if obj.activationCount.cal>1 || obj.shouldClearCal
                        obj.clearCalNow = true;
                    else
                        obj.isDone      = false;
                    end
                    obj.lastUpdate = {};
                    obj.awaitingPointResult = 0;
                    obj.isActive = true;
                    obj.step = 1;
                    obj.shouldUpdateStatusText = true;
                    obj.isShowingRewardTarget = false;
                    obj.isShowingPointManually= false;
                    obj.onTargetTimestamp = nan;
                    obj.drawState = 1;
                    obj.setCalDisplayPoints();
                    % backup Titta pacing duration and set to 0, since the
                    % controller controls when data should be collected
                    obj.setTittaPacing('cal','');
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('controller activated for calibration. Activation #%d',obj.activationCount.cal);
                    end
                case 'cal_deactivate'
                    % controller deactivated
                    obj.isActive = false;
                    obj.gazedCalPoint = nan;
                    obj.shouldUpdateStatusText = true;
                    obj.drawState = 0;
                    % backup Titta pacing duration and set to 0, since the
                    % controller controls when data should be collected
                    obj.setTittaPacing('','cal');
                    if obj.showRewardTargetWhenDone
                        obj.enableShowingRewardTarget();
                    end
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('controller deactivated for calibration');
                    end

                case 'cal_enter'
                    % calibration mode entered
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('calibration mode entered');
                    end
                case 'cal_collect_started'
                    % calibration point collection started
                    obj.isShowingPointManually = ~obj.isActive;
                    if obj.isShowingPointManually
                        % get point location
                        obj.manualPoint = [currentPoint posPix];
                    end
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                case 'cal_collect_done'
                    % calibration point collected
                    obj.lastUpdate = {event,currentPoint,posNorm,callResult};
                    success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('calibration point collect: %s',ternary(success,'success','failed'));
                    end
                    % update point status
                    for p=1:length(obj.calPoints)
                        iPoint = find(obj.calPoints{p}==currentPoint);
                        if ~isempty(iPoint) && all(posNorm==obj.calPoss{p}(iPoint,:))
                            obj.calPointsState{p}(iPoint) = ternary(success,obj.pointStateEnum.collected,obj.pointStateEnum.nothing);
                            break;
                        end
                    end
                    if success
                        obj.calDisplay.hidePoint(currentPoint);
                    end
                    obj.shouldClearCal = true;  % mark that we need to clear calibration if controller is activated
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                    obj.isShowingPointManually = false;
                    obj.manualPoint = [nan nan nan];
                case 'cal_discard'
                    % calibration point discarded
                    obj.lastUpdate = {event,currentPoint,posNorm,callResult};
                    if bitget(obj.logTypes,2)
                        success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
                        obj.log_to_cmd('calibration point discard: %s',ternary(success,'success','failed'));
                    end
                    % update point status
                    for p=1:length(obj.calPoints)
                        iPoint = find(obj.calPoints{p}==currentPoint);
                        if ~isempty(iPoint) && all(posNorm==obj.calPoss{p}(iPoint,:))
                            obj.calPointsState{p}(iPoint) = obj.pointStateEnum.nothing;
                            break;
                        end
                    end
                case 'cal_compute_and_apply'
                    % new calibration computed (may have failed)
                    obj.lastUpdate = {event,callResult};
                    obj.shouldClearCal = true;
                    if bitget(obj.logTypes,2)
                        success = callResult.status==0 && strcmpi(callResult.calibrationResult.status,'success');
                        obj.log_to_cmd('calibration compute and apply result received: %s',ternary(success,'success','failed'));
                    end
                case 'cal_load'
                    % a calibration was loaded
                    % mark that we need to clear calibration if controller is activated
                    obj.shouldClearCal = true;
                case 'cal_cleared'
                    % calibration was cleared: now at a blank slate
                    obj.lastUpdate = {event};
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('calibration clear result received');
                    end
                    obj.calPointsState = cellfun(@(x) repmat(obj.pointStateEnum.nothing, 1, size(x,1)),obj.calPoss,'uni',false);
                    obj.shouldClearCal = false;
                case {'cal_finished','val_finished'}
                    % interface exited from calibration or validation
                    % screen: we're done according to operator, clean up
                    if strcmp(event(1:3),'cal')
                        obj.setTittaPacing('','cal');
                    end
                    obj.reward(false);
                    obj.setCleanState();
            end
        end

        function txt = getStatusText(obj,force)
            % return '!!clear_status' if you want to remove the status text
            if nargin<2
                force = false;
            end
            txt = '';
            if ~obj.shouldUpdateStatusText && ~force
                return
            end
            if ~obj.isActive
                txt = 'Inactive';
                if obj.isShowingPointManually
                    txt = [txt ', showing point manually'];
                end
            else
                txt = sprintf('Calibrating step %d (%d left)',obj.step,sum(obj.calPointsState{obj.step}~=obj.pointStateEnum.collected));
            end
            txt = sprintf('%s\nReward: %s',txt,ternary(obj.dispensingReward,'on','off'));
            obj.shouldUpdateStatusText = false;
        end

        function draw(obj,wpnts,tick,sFac,offset)
            % wpnts: two window pointers. first is for participant screen,
            % second for operator
            % sFac and offset are used to scale from participant screen to
            % operator screen, in case they have different resolutions. So
            % always use them
            if ~obj.isActive && ~obj.isShowingRewardTarget && ~obj.isShowingPointManually
                return;
            end

            % now that we have a wpnt, get some needed variables
            if isempty(obj.qFloatColorRange)
                obj.qFloatColorRange    = arrayfun(@(x) Screen('ColorRange',x)==1,wpnts);
            end

            % first participant screen
            if (obj.drawState==1 || obj.drawExtraFrame) && ~obj.isShowingPointManually
                if obj.isActive
                    % Don't call draw here if we've issued a command to collect
                    % calibration data for a point and haven't gotten a status
                    % update yet, then Titta is showing the point for us
                    if obj.awaitingPointResult~=1 || obj.drawExtraFrame
                        obj.calDisplay.doDraw(wpnts(1),'draw',nan,[],tick,'cal');
                    end
                elseif obj.isShowingRewardTarget
                    pos = obj.scrRes/2;
                    sz = 2*obj.rewardTargetRadius*obj.scrRes(1);
                    rect = CenterRectOnPointd([0 0 sz sz],pos(1),pos(2));
                    Screen('FrameOval',wpnts(1),obj.getColorForWindow(1,obj.rewardTargetColor),rect,4);
                end

                if obj.drawExtraFrame
                    obj.drawExtraFrame = false;
                end
            end

            % draw gaze circle(s) for operator
            if obj.isActive
                qActive = obj.calPointsState{obj.step} < obj.pointStateEnum.collected;
                pos = bsxfun(@times,obj.calPoss{obj.step},obj.scrRes(:).');
                pos(~qActive,:) = [];
            elseif obj.isShowingPointManually
                pos = obj.manualPoint(2:3);
            elseif obj.isShowingRewardTarget
                pos = obj.scrRes/2;
            end
            for p=1:size(pos,1)
                if obj.isActive || obj.isShowingPointManually
                    sz = ternary(obj.step==1,obj.calMargin1,obj.calMargin2);
                elseif obj.isShowingRewardTarget
                    sz = obj.rewardTargetRadius;
                end
                sz = 2*sz*obj.scrRes(1);
                lWidth = ternary(obj.isActive && obj.calPoints{obj.step}(p)==obj.gazedCalPoint,8,4);
                if ~obj.isActive || obj.step==1
                    rect = CenterRectOnPointd([0 0 [sz sz]*sFac],pos(p,1)*sFac+offset(1),pos(p,2)*sFac+offset(2));
                    Screen('FrameOval',wpnts(end),obj.getColorForWindow(2,obj.calAOIColor),rect,lWidth);
                else
                    rect = CenterRectOnPointd([0 0 [sz sz]*sFac],obj.scrRes(1)/2*sFac+offset(1),obj.scrRes(2)/2*sFac+offset(2));
                    relPos = pos(p,:)-obj.scrRes(:).'/2;
                    relDir = atan2(relPos(2),relPos(1))*180/pi;
                    relDirFrameArc = relDir+90;         % frame arc is clockwise from vertical
                    Screen('FrameArc',wpnts(end),obj.getColorForWindow(2,obj.calAOIColor),rect,relDirFrameArc-obj.calMarginDirection-1,2*obj.calMarginDirection+1,lWidth,lWidth);
                    % draw arms to far past end of screen
                    center = obj.scrRes(:).'/2*sFac+offset(:).';
                    starts = [center+sz/2*sFac*[cosd(relDir-obj.calMarginDirection) sind(relDir-obj.calMarginDirection)]; center+sz/2*sFac*[cosd(relDir+obj.calMarginDirection) sind(relDir+obj.calMarginDirection)]];
                    ends   = [center+sz*5000*[cosd(relDir-obj.calMarginDirection) sind(relDir-obj.calMarginDirection)]; center+sz*5000*[cosd(relDir+obj.calMarginDirection) sind(relDir+obj.calMarginDirection)]];
                    Screen('DrawLines',wpnts(end),[starts(1,:); ends(1,:); starts(2,:); ends(2,:)].',lWidth,obj.getColorForWindow(2,obj.calAOIColor));
                end
            end

            % draw gaze if wanted
            if obj.showGazeToOperator
                sz = [1/40 1/120]*obj.scrRes(2);
                pos = obj.gazePos;
                rectH = CenterRectOnPointd([0 0        sz ], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
                Screen('FillRect',wpnts(end), obj.getColorForWindow(2,0), rectH);
                Screen('FillRect',wpnts(end), obj.getColorForWindow(2,0), rectV);
            end
        end
    end

    methods (Static)
        function canDo = canControl(type)
            switch type
                case 'calibration'
                    canDo = true;
                case 'validation'
                    canDo = false;
                otherwise
                    error('MultiStepCalController: controller capability "%s" not understood',type)
            end
        end
    end
    
    methods (Access = private, Hidden)
        function setCleanState(obj)
            if bitget(obj.logTypes,1)
                obj.log_to_cmd('cleanup state');
            end
            obj.step                        = 1;

            obj.gazePos                     = [nan nan].';
            obj.gazeOnScreen                = false;
            obj.onScreenTimestamp           = nan;
            obj.offScreenTimestamp          = nan;
            obj.onTargetTimestamp           = nan;
            obj.latestTimestamp             = nan;

            obj.calPoints                   = [];
            obj.calPoss                     = [];
            obj.calPointsState              = [];
            obj.gazedCalPoint               = nan;
            obj.activeCalPoint              = nan;

            obj.gazingOnRewardTarget        = false;
            obj.gazingOnManualPoint         = false;

            obj.isActive                    = false;
            obj.isDone                      = false;
            obj.isShowingRewardTarget       = false;
            obj.isShowingPointManually      = false;
            obj.manualPoint                 = [nan nan nan];
            obj.dispensingReward            = false;
            obj.shouldRewindState           = false;
            obj.shouldClearCal              = false;
            obj.clearCalNow                 = false;
            obj.activationCount             = struct('cal',0, 'val',0);
            obj.shouldUpdateStatusText      = false;
            obj.trackerFrequency            = [];
            obj.qFloatColorRange            = [];

            obj.awaitingPointResult         = 0;
            obj.lastUpdate                  = {};

            obj.drawState                   = 0;
            obj.drawExtraFrame              = false;

            obj.backupPaceDuration          = struct('cal',[],'val',[]);
        end



        function setCalDisplayPoints(obj)
            assert(~isempty(obj.scrRes),'You cannot activate this calibration controller before setting the screen resolution')
            obj.calDisplay.setPoints(obj.calPoints{obj.step}, bsxfun(@times,obj.calPoss{obj.step},obj.scrRes(:).'));
        end


        function updateGaze(obj)
            if isempty(obj.trackerFrequency)
                obj.trackerFrequency = obj.EThndl.frequency;
            end
            gaze = obj.EThndl.buffer.peekN('gaze',round(obj.gazeFetchDur/1000*obj.trackerFrequency));
            if isempty(gaze)
                obj.gazePos = nan;
                obj.calDisplay.setActivePoint(nan);
                return
            end

            obj.latestTimestamp = double(gaze.systemTimeStamp(end))/1000;   % us -> ms
            fValid = mean([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],2);
            if any(fValid>obj.minValidGazeFrac)
                switch obj.gazeAggregationMethod
                    case 1
                        % take mean of valid samples
                        leftGaze = mean(gaze. left.gazePoint.onDisplayArea(:,gaze. left.gazePoint.valid),2,'omitnan').*obj.scrRes(:);
                        rightGaze= mean(gaze.right.gazePoint.onDisplayArea(:,gaze.right.gazePoint.valid),2,'omitnan').*obj.scrRes(:);
                    case 2
                        % use last valid sample
                        qValid = all([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1);
                        iSamp = find(qValid,1,'last');
                        leftGaze = gaze. left.gazePoint.onDisplayArea(:,iSamp).*obj.scrRes(:);
                        rightGaze= gaze.right.gazePoint.onDisplayArea(:,iSamp).*obj.scrRes(:);
                end
                obj.gazePos = mean([leftGaze rightGaze],2);

                obj.gazeOnScreen = obj.gazePos(1) > 0 && obj.gazePos(1)<obj.scrRes(1) && ...
                                   obj.gazePos(2) > 0 && obj.gazePos(2)<obj.scrRes(2);
                if obj.gazeOnScreen
                    obj.offScreenTimestamp = nan;
                    if isnan(obj.onScreenTimestamp)
                        iSamp = find(any([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1),1,'last');
                        obj.onScreenTimestamp = double(gaze.systemTimeStamp(iSamp))/1000;   % us -> ms
                    end
                end
            else
                obj.gazeOnScreen = false;
                obj.gazePos = [nan nan].';
                obj.onScreenTimestamp = nan;
                obj.onTargetTimestamp = nan;
                if isnan(obj.offScreenTimestamp)
                    obj.offScreenTimestamp = double(gaze.systemTimeStamp(1))/1000;  % us -> ms
                end
            end

            % check if gaze is on a calibration target or inside reward
            % square
            % get which points to check against
            if obj.isActive
                qActive = obj.calPointsState{obj.step} < obj.pointStateEnum.collected;
                pointIds = obj.calPoints{obj.step}(qActive);
                pos = bsxfun(@times,obj.calPoss{obj.step},obj.scrRes(:).');
                pos(~qActive,:) = [];
            elseif obj.isShowingPointManually
                pos = obj.manualPoint(2:3);
            elseif obj.isShowingRewardTarget
                pos = obj.scrRes/2;
            else
                return;
            end

            % check if gaze is near any of the targets. Method depends on
            % step
            % If in step 1 or not active, check if gaze close enough to
            % refence point (e.g. center of screen)
            % For later steps, check if gaze in direction of a calibration
            % point and not too close to center point
            if obj.isShowingRewardTarget
                refDist = obj.rewardTargetRadius;
            elseif ~obj.isActive || obj.step==1
                refDist = obj.calMargin1;
            else
                refDist = obj.calMargin2;
            end
            refDist = refDist*obj.scrRes(1);

            qOnPoint = false;
            if ~obj.isActive || obj.step==1
                dist    = hypot(obj.gazePos(1)-pos(:,1), obj.gazePos(2)-pos(:,2));
                [minDist,i] = min(dist);
                if minDist < refDist
                    changed = false;
                    if obj.isActive
                        gazedPoint = pointIds(i);
                        changed = gazedPoint ~= obj.gazedCalPoint;
                        obj.gazedCalPoint = gazedPoint;
                    elseif obj.isShowingPointManually
                        obj.gazingOnManualPoint = true;
                        obj.calDisplay.setActivePoint(obj.manualPoint(1));
                    elseif obj.isShowingRewardTarget
                        obj.gazingOnRewardTarget = true;
                    end
                    if obj.onTargetTimestamp<0 || isnan(obj.onTargetTimestamp) || changed
                        obj.onTargetTimestamp = obj.latestTimestamp;
                    end
                    if changed
                        obj.calDisplay.setActivePoint(obj.gazedCalPoint);
                    end
                    qOnPoint = true;
                end
            else
                % step 2+ check minimum distance
                dist    = hypot(obj.gazePos(1)-obj.scrRes(1)/2, obj.gazePos(2)-obj.scrRes(2)/2);
                if dist > refDist
                    % check angular location close to a target
                    relPos = bsxfun(@minus,pos,obj.scrRes(:).'/2);
                    relDir = atan2(relPos(:,2),relPos(:,1))*180/pi;
                    relDirGaze = atan2(obj.gazePos(2)-obj.scrRes(2)/2, obj.gazePos(1)-obj.scrRes(1)/2)*180/pi;
                    dirOff = relDirGaze-relDir;
                    dirOff(dirOff<-180) = dirOff(dirOff<-180) + 360;
                    dirOff(dirOff> 180) = dirOff(dirOff> 180) - 360;
                    [minDir,i] = min(abs(dirOff));
                    if minDir < obj.calMarginDirection
                        gazedPoint = pointIds(i);
                        changed = gazedPoint ~= obj.gazedCalPoint;
                        obj.gazedCalPoint = gazedPoint;
                        if obj.onTargetTimestamp<0 || isnan(obj.onTargetTimestamp) || changed
                            obj.onTargetTimestamp = obj.latestTimestamp;
                        end
                        if changed
                            obj.calDisplay.setActivePoint(obj.gazedCalPoint);
                        end
                        qOnPoint = true;
                    end
                end
            end
            if ~qOnPoint
                obj.gazedCalPoint = nan;
                obj.calDisplay.setActivePoint(nan);
                obj.gazingOnRewardTarget = false;
                obj.gazingOnManualPoint = false;
                obj.onTargetTimestamp = nan;
            end
        end

        function reward(obj,on)
            on = ~~on;
            if (on && obj.dispensingReward) || (~on && ~obj.dispensingReward)
                % nothing to do, already in expected state
                return
            end
            obj.dispensingReward = on;
            if bitget(obj.logTypes,3)
                obj.log_to_cmd('reward: %s',ternary(on,'on','off'));
            end
            obj.shouldUpdateStatusText = true;
            if isempty(obj.rewardProvider)
                return
            end
            if on
                obj.rewardProvider.start();
            else
                obj.rewardProvider.stop();
            end
        end

        function commands = calibrate(obj)
            commands = {};
            if obj.isDone
                % nothing to do
                return
            elseif obj.awaitingPointResult>0
                % check if should abort calibration point collection
                if obj.awaitingPointResult==1 && obj.gazedCalPoint~=obj.activeCalPoint
                    % request discarding data for this point if its being
                    % collected
                    qIdx = obj.calPoints{obj.step}==obj.activeCalPoint;
                    if obj.calPointsState{obj.step}(qIdx)==obj.pointStateEnum.collecting
                        commands = {{'cal','discard_point', obj.activeCalPoint, obj.calPoss{obj.step}(qIdx,:)}};
                        obj.awaitingPointResult = 2;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('request discarding calibration point %d @ (%.3f,%.3f)',obj.activeCalPoint, obj.calPoss{obj.step}(qIdx,:));
                        end
                    end
                end

                % we're waiting for the result of an action. For easier
                % logic, we put all the response waiting logic here,
                % short-circuiting the below logic that depends on where
                % the subject looks
                if isempty(obj.lastUpdate)
                    return;
                end
                if obj.awaitingPointResult==1 && strcmp(obj.lastUpdate{1},'cal_collect_done')
                    % check this is for the expected point
                    qIdx = obj.calPoints{obj.step}==obj.activeCalPoint;
                    if obj.lastUpdate{2}==obj.activeCalPoint && all(obj.lastUpdate{3}==obj.calPoss{obj.step}(qIdx,:))
                        % check result
                        if obj.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
                            % success, mark point as collected
                            obj.calPointsState{obj.step}(qIdx) = obj.pointStateEnum.collected;
                            % decide next action
                            if any(obj.calPointsState{obj.step} < obj.pointStateEnum.collected)
                                % there are more points to calibrate for
                                % this step
                                obj.awaitingPointResult = 0;
                                obj.shouldUpdateStatusText = true;
                                obj.onTargetTimestamp = nan;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('successfully collected calibration point %d, continue with collection of other point(s) in this step', obj.activeCalPoint);
                                end
                            else
                                % all points collected for this step ->
                                % attempt calibration
                                commands = {{'cal','compute_and_apply'}};
                                obj.awaitingPointResult = 3;
                                obj.shouldUpdateStatusText = true;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('all calibration points successfully collected for this step, requesting computing and applying calibration');
                                end
                            end
                            obj.activeCalPoint = nan;
                        else
                            % failed collecting calibration point, discard
                            % (to be safe its really gone from state,
                            % overkill i think but doesn't hurt)
                            commands = {{'cal','discard_point', obj.activeCalPoint, obj.calPoss{obj.step}(qIdx,:)}};
                            obj.awaitingPointResult = 2;
                            obj.calPointsState{obj.step}(qIdx) = obj.pointStateEnum.discarding;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('failed to collect calibration point %d, requesting to discard it', obj.activeCalPoint);
                            end
                        end
                        obj.drawState = 1;
                    end
                    obj.lastUpdate = {};
                elseif obj.awaitingPointResult==2 && strcmp(obj.lastUpdate{1},'cal_discard')
                    % check this is for the expected point
                    qIdx = obj.calPoints{obj.step}==obj.activeCalPoint;
                    if obj.lastUpdate{2}==obj.activeCalPoint && all(obj.lastUpdate{3}==obj.calPoss{obj.step}(qIdx,:))
                        if obj.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
                            % success, mark point as not collected
                            obj.calPointsState{obj.step}(qIdx) = obj.pointStateEnum.nothing;
                            obj.awaitingPointResult = 0;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('successfully discarded calibration point %d', obj.activeCalPoint);
                            end
                        else
                            error('can''t discard point, something seriously wrong')
                        end
                        obj.activeCalPoint = nan;
                        obj.drawState = 1;
                    end
                    obj.lastUpdate = {};
                elseif obj.awaitingPointResult==3 && strcmp(obj.lastUpdate{1},'cal_compute_and_apply')
                    if obj.lastUpdate{2}.status==0 && strcmpi(obj.lastUpdate{2}.calibrationResult.status,'success')
                        % successful calibration
                        if obj.step < length(obj.calPoints)
                            obj.step = obj.step+1;
                            obj.setCalDisplayPoints();
                            obj.awaitingPointResult = 0;
                            obj.shouldUpdateStatusText = true;
                            obj.onTargetTimestamp = nan;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('calibration successfully applied for this step. Continue with collection of points for next step');
                            end
                        else
                            obj.awaitingPointResult = 0;
                            obj.reward(false);
                            obj.isDone = true;
                            obj.shouldUpdateStatusText = true;
                            obj.calDisplay.setCleanState();
                            commands = {{'cal','disable_controller'}};
                            obj.drawState = 0;
                            if obj.showRewardTargetWhenDone
                                obj.enableShowingRewardTarget();
                            end
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('calibration successfully applied for last step, disabling controller');
                            end
                        end
                    else
                        % failed, start over
                        for p=length(obj.calPoints):-1:1    % reverse so we can set cal state back to first point and await discard of that first point, will arrive last
                            for q=length(obj.calPoints{p}):-1:1
                                commands = [commands {{'cal','discard_point', obj.calPoints{p}(q), obj.calPoss{p}(q,:)}}]; %#ok<AGROW>
                            end
                        end
                        obj.awaitingPointResult = 2;
                        obj.step = 1;
                        obj.setCalDisplayPoints();
                        obj.activeCalPoint = obj.calPoints{1}(1);
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('calibration failed discarding all points and starting over');
                        end
                    end
                    obj.lastUpdate = {};
                elseif ~isempty(obj.lastUpdate)
                    % unexpected (perhaps stale, e.g. from before auto was switched on) update, discard
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('unexpected update from Titta during calibration: %s, discarding',obj.lastUpdate{1});
                    end
                    obj.lastUpdate = {};
                end
            elseif ~isnan(obj.gazedCalPoint)
                obj.reward(true);
                onDur = obj.latestTimestamp-obj.onTargetTimestamp;
                if onDur > obj.calOnTargetTime && obj.awaitingPointResult==0
                    % request calibration point collection
                    obj.activeCalPoint = obj.gazedCalPoint;
                    qIdx = obj.calPoints{obj.step}==obj.activeCalPoint;
                    commands = {{'cal','collect_point', obj.activeCalPoint, obj.calPoss{obj.step}(qIdx,:)}};
                    obj.awaitingPointResult = 1;
                    obj.calPointsState{obj.step}(qIdx) = obj.pointStateEnum.discarding;
                    obj.drawState = 0;
                    obj.drawExtraFrame = true;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('request calibration of point %d @ (%.3f,%.3f)', obj.activeCalPoint, obj.calPoss{obj.step}(qIdx,:));
                    end
                end
            end

            if isnan(obj.gazedCalPoint)
                obj.reward(false);
            end
        end


        function setTittaPacing(obj,set,reset)
            % this can handle setting and resetting pacing for both
            % calibration and validation mode. We use it only for
            % calibration.
            settings = obj.EThndl.getOptions();
            if ~isempty(set)
                obj.backupPaceDuration.(set) = settings.advcal.(set).paceDuration;
                settings.advcal.(set).paceDuration = 0;
                if bitget(obj.logTypes,1)
                    obj.log_to_cmd('setting Titta pacing duration for %s to 0',ternary(strcmpi(set,'cal'),'calibration','validation'));
                end
            end
            if ~isempty(reset) && ~isempty(obj.backupPaceDuration.(reset))
                settings.advcal.(reset).paceDuration = obj.backupPaceDuration.(reset);
                obj.backupPaceDuration.(reset) = [];
                if bitget(obj.logTypes,1)
                    obj.log_to_cmd('resetting Titta pacing duration for %s',ternary(strcmpi(reset,'cal'),'calibration','validation'));
                end
            end
            obj.EThndl.setOptions(settings);
        end


        function enableShowingRewardTarget(obj)
            obj.isShowingRewardTarget = true;
            obj.onTargetTimestamp = nan;
            obj.drawState = 1;
        end


        function log_to_cmd(obj,msg,varargin)
            message = sprintf(['%s: ' msg],mfilename('class'),varargin{:});
            switch obj.logReceiver
                case 0
                    fprintf('%s\n',message);
                case 1
                    obj.EThndl.sendMessage(message);
                otherwise
                    error('logReceived %d unknown',obj.logReceiver);
            end
        end

        function clr = getColorForWindow(obj,wIdx,clr)
            if obj.qFloatColorRange(wIdx)
                clr = double(clr)/255;
            end
        end
    end
end

%% helpers
function out = ternary(cond, a, b)
out = subsref({b; a}, substruct('{}', {cond + 1}));
end