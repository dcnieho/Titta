classdef NonHumanPrimateCalController < handle
    properties (Constant)
        stateEnum = struct('cal_positioning', 0, 'cal_gazing',1, 'cal_calibrating',2, 'cal_done',3, ...
                           'val_validating' ,12, 'val_done'  ,13);
        pointStateEnum = struct('nothing',0, 'showing',1, 'collecting',2, 'discarding',3, 'collected', 4);
    end
    properties (SetAccess=private)
        % state
        stage;

        gazeOnScreen;                               % true if we have gaze for both eyes and the average position is on screen
        leftGaze;
        rightGaze;
        meanGaze;
        onScreenTimestamp;                          % time of start of episode of gaze on screen
        offScreenTimestamp;                         % time of start of episode of gaze off screen
        onVideoTimestamp;                           % time of start of episode of gaze on video (for calibration)
        latestTimestamp;                            % latest gaze timestamp

        onScreenTimeThresh;
        videoSize;

        calPoint;
        calPoints                   = [];           % ID of calibration points to run by the controller, in provided order
        calPoss                     = [];           % corresponding positions
        calPointsState              = [];

        valPoint;
        valPoints                   = [];           % ID of calibration points to run by the controller, in provided order
        valPoss                     = [];           % corresponding positions
        valPointsState              = [];
    end
    properties
        % comms
        EThndl;
        calDisplay;                                 % expected to be a VideoCalibrationDisplay instance
        rewardProvider;

        forceRewardButton           = '';           % if provided, when key press on this button is detected, reward is forced on
        skipTrainingButton          = '';           % if training, when key press on this button is detected and we're in calibration stage, skip forward to 'cal_calibrating' state (i.e. skip positioning and gazing training)

        gazeFetchDur                = 100;          % duration of gaze samples to peek on each iteration (ms, e.g., last 100 ms of gaze)
        gazeAggregationMethod       = 1;            % 1: use mean of all samples during last gazeFetchDur ms, 2: use mean of last valid sample during last gazeFetchDur ms
        minValidGazeFrac            = .5;
        scrRes;

        maxOffScreenTime            = 40/60*1000;
        onScreenTimeThreshCap       = 400;          % maximum time animal will be required to keep gaze onscreen for rewards
        onScreenTimeThreshIncRate   = 0.01;         % chance to increase onscreen time threshold

        videoShrinkTime             = 1000;         % how long eyes on video before video shrinks
        videoShrinkRate             = 0.01;         % chance to decrease video size
        
        videoSizes                  = [
                                    1600 1600;
                                    1200 1200;
                                    800 800;
                                    600 600;
                                    500 500;
                                    400 400;
                                    300 300;
                                    ];
        calVideoSize                = [300 300];
        calShowVideoWhenDone        = true;
        calVideoSizeWhenDone        = [600 600];
        calWhenDoneRewardDistFac    = .5;           % fraction of video width (so 0.5 means gaze anywhere on video, since distance is from center)
        calWhenDoneRewardTime       = 500;          % ms

        valVideoSize                = [300 300];
        valShowVideoWhenDone        = true;
        valVideoSizeWhenDone        = [600 600];
        valWhenDoneRewardDistFac    = .5;           % fraction of video width (so 0.5 means gaze anywhere on video, since distance is from center)
        valWhenDoneRewardTime       = 500;          % ms

        calOnTargetTime             = 500;          % ms
        calOnTargetDistFac          = 1/3;          % max gaze distance to be considered close enough to a point to attempt calibration (factor of vertical size of screen)
        calAfterFirstCollected      = false;        % if true, a calibration compute_and_apply command will be given after the first calibration point is successfully collected, before continueing to collect the next calibration point

        valOnTargetDist             = 150;          % pixels
        valOnTargetTime             = 500;          % ms
        valRandomizeTargets         = true;

        reEntryStateCal             = NonHumanPrimateCalController.stateEnum.cal_calibrating;    % when reactivating controller, discard state up to beginning of this state
        reEntryStateVal             = NonHumanPrimateCalController.stateEnum.val_validating;     % when reactivating controller, discard state up to beginning of this state

        videoRectColor              = [255 0 0];    % color in which to draw the rect indicating where the video is shown on the screen
        showGazeToOperator          = true;         % if true, aggregated gaze as used by the controller is drawn as a crosshair on the operator screen
        logTypes                    = 0;            % bitmask: if 0, no logging. bit 1: print basic messages about what its up to. bit 2: print each command received in receiveUpdate(), bit 3: print messages about rewards (many!)
        logReceiver                 = 0;            % if 0: matlab command line. if 1: Titta
    end
    properties (Access=private,Hidden=true)
        isActive                    = false;
        isNonActiveShowingVideo     = false;
        isShowingPointManually      = false;
        dispensingReward            = false;
        dispensingForcedReward      = false;
        controlState                = NonHumanPrimateCalController.stateEnum.cal_positioning;
        shouldRewindState           = false;
        shouldClearCal              = false;
        clearCalNow                 = false;
        clearValNow                 = false;
        activationCount             = struct('cal',0, 'val',0);
        shouldUpdateStatusText;
        trackerFrequency;                           % calling obj.EThndl.frequency is blocking when a calibration action is ongoing, so cache the value

        awaitingPointResult         = 0;            % 0: not awaiting anything; 1: awaiting point collect result; 2: awaiting point discard result; 3: awaiting compute and apply result; 4: calibration clearing result
        lastUpdate                  = {};

        drawState                   = 0;            % 0: don't issue draws from here; 1: new command should be given to drawer; 2: regular draw command should be given
        drawExtraFrame              = false;        % because command in tick() is only processed in Titta after fixation point is drawn, we need to draw one extra frame here to avoid flashing when starting calibration point collection

        backupPaceDuration          = struct('cal',[],'val',[]);
    end
    
    
    methods
        function obj = NonHumanPrimateCalController(EThndl,calDisplay,scrRes,rewardProvider)
            obj.setCleanState();
            obj.EThndl = EThndl;
            assert(isa(calDisplay,"VideoCalibrationDisplay"))
            obj.calDisplay = calDisplay;
            if nargin>2 && ~isempty(scrRes)
                obj.scrRes = scrRes;
            end
            if nargin>3 && ~isempty(rewardProvider)
                obj.rewardProvider = rewardProvider;
            end
        end

        function setCalPoints(obj, calPoints,calPoss)
            assert(ismember(obj.controlState,[obj.stateEnum.cal_positioning obj.stateEnum.cal_gazing]),'cannot set calibration points when already calibrating or calibrated')
            assert(length(unique(calPoints))==length(calPoints),'At least one calibration point ID is specified more than once. Specify each calibration point only once.')
            obj.calPoints       = calPoints;                % ID of calibration points to run by the controller, in provided order
            obj.calPoss         = calPoss;                  % corresponding positions
            obj.calPointsState  = repmat(obj.pointStateEnum.nothing, 1, size(obj.calPoss,1));
        end

        function setValPoints(obj, valPoints,valPoss)
            assert(obj.controlState < obj.stateEnum.val_validating,'cannot set validation points when already validating or validated')
            assert(length(unique(valPoints))==length(valPoints),'At least one validation point ID is specified more than once. Specify each validation point only once.')
            obj.valPoints       = valPoints;                % ID of calibration points to run by the controller, in provided order
            obj.valPoss         = valPoss;                  % corresponding positions
            obj.valPointsState  = repmat(obj.pointStateEnum.nothing, 1, size(obj.valPoss,1));
        end

        function commands = tick(obj)
            commands = {};
            if (~isempty(obj.forceRewardButton) && ~isempty(obj.rewardProvider)) || ~isempty(obj.skipTrainingButton)
                [~,~,keyCode] = KbCheck();
                if any(keyCode)
                    if ~isempty(obj.forceRewardButton) && any(ismember(KbName(keyCode),{obj.forceRewardButton}))
                        obj.dispensingForcedReward = true;
                        obj.reward(true);
                    elseif ~isempty(obj.skipTrainingButton) && any(ismember(KbName(keyCode),{obj.skipTrainingButton}))
                        obj.controlState = obj.stateEnum.cal_calibrating;
                        obj.drawState = 1;
                        obj.calDisplay.videoSize = obj.calVideoSize;
                        obj.shouldUpdateStatusText = true;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('calibrating (skipped forward by key press)');
                        end
                    end
                elseif obj.dispensingForcedReward
                    obj.dispensingForcedReward = false;
                    obj.reward(false);
                end
            end
            if ~isempty(obj.rewardProvider)
                obj.rewardProvider.tick();
            end
            if ~obj.isActive && ~obj.isNonActiveShowingVideo && ~obj.isShowingPointManually
                return;
            end
            obj.updateGaze();
            offScreenTime = obj.latestTimestamp-obj.offScreenTimestamp;
            if ~obj.isActive && (obj.isNonActiveShowingVideo || obj.isShowingPointManually)     % check like this: this logic should only kick in when controller is not active
                % check if should be giving reward: when gaze on/near video
                obj.determineNonActiveReward();
                return
            end
            
            % normal controller active mode
            if strcmp(obj.stage,'cal')
                if offScreenTime > obj.maxOffScreenTime
                    obj.reward(false);
                end
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
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('calibration data cleared, starting controller');
                        end
                    end
                else
                    switch obj.controlState
                        case obj.stateEnum.cal_positioning
                            if obj.shouldRewindState
                                obj.onScreenTimeThresh = 1;
                                obj.shouldRewindState = false;
                                obj.drawState = 1;
                                obj.shouldUpdateStatusText = true;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('rewinding state: reset looking threshold');
                                end
                            elseif obj.onScreenTimeThresh < obj.onScreenTimeThreshCap
                                % training to position and look at screen
                                obj.trainLookScreen();
                            else
                                obj.controlState = obj.stateEnum.cal_gazing;
                                obj.drawState = 1;
                                obj.shouldUpdateStatusText = true;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('training to look at video');
                                end
                            end
                        case obj.stateEnum.cal_gazing
                            if obj.shouldRewindState
                                obj.videoSize = 1;
                                obj.drawState = 1;
                                obj.shouldUpdateStatusText = true;
                                if obj.reEntryStateCal<obj.stateEnum.cal_gazing
                                    obj.controlState = obj.stateEnum.cal_positioning;
                                else
                                    obj.shouldRewindState = false;
                                end
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('rewinding state: reset video size');
                                end
                            elseif obj.videoSize < size(obj.videoSizes,1)
                                % training to look at video
                                obj.trainLookVideo();
                            else
                                obj.controlState = obj.stateEnum.cal_calibrating;
                                obj.drawState = 1;
                                obj.calDisplay.videoSize = obj.calVideoSize;
                                obj.shouldUpdateStatusText = true;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('calibrating');
                                end
                            end
                        case obj.stateEnum.cal_calibrating
                            % calibrating
                            commands = obj.calibrate();
                        case obj.stateEnum.cal_done
                            % procedure is done: nothing to do
                    end
                end
            else
                % validation
                if obj.clearValNow
                    if obj.awaitingPointResult~=2
                        obj.valPoint = 1;
                        if obj.valRandomizeTargets
                            order = randperm(length(obj.valPoints));
                            obj.valPoints = obj.valPoints(order);
                            obj.valPoss   = obj.valPoss(order,:);
                        end
                        % ensure we're in clean state
                        for p=length(obj.valPoints):-1:1    % reverse so we can set val state back to first point and await discard of that first point, will arrive last
                            commands = [commands {{'val','discard_point', obj.valPoints(p), obj.valPoss(p,:)}}]; %#ok<AGROW> 
                        end
                        obj.awaitingPointResult = 2;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('clearing validation state to be sure its clean upon controller activation');
                        end
                    elseif obj.awaitingPointResult==2 && ~isempty(obj.lastUpdate) && strcmp(obj.lastUpdate{1},'val_discard')
                        % check this is for the expected point
                        if obj.lastUpdate{2}==obj.valPoints(obj.valPoint) && all(obj.lastUpdate{3}==obj.valPoss(obj.valPoint,:))
                            obj.awaitingPointResult = 0;
                            obj.clearValNow = false;
                            obj.shouldUpdateStatusText = true;
                            obj.lastUpdate = {};
                            obj.drawState = 1;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('validation data cleared, starting controller');
                            end
                        end
                    end
                else
                    switch obj.controlState
                        case obj.stateEnum.val_validating
                            % validating
                            commands = obj.validate();
                        case obj.stateEnum.val_done
                            % procedure is done: nothing to do
                    end
                end
            end
        end

        function receiveUpdate(obj,~,currentPoint,posNorm,~,~,type,callResult)
            % inputs: titta_instance, currentPoint, posNorm, posPix, stage, type, callResult

            % event communicated to the controller:
            if bitget(obj.logTypes,2)
                obj.log_to_cmd('received update of type: %s',type);
            end
            switch type
                case {'cal_activate','val_activate'}
                    mode = type(1:3);
                    isCal = strcmpi(mode,'cal');
                    obj.activationCount.(mode) = obj.activationCount.(mode)+1;
                    if isCal
                        if obj.activationCount.cal>1 && obj.controlState>=obj.reEntryStateCal
                            obj.shouldRewindState = true;
                            if obj.controlState>obj.reEntryStateCal
                                if obj.controlState > obj.stateEnum.cal_done
                                    obj.controlState = obj.stateEnum.cal_done;
                                end
                                obj.controlState = obj.controlState-1;
                            end
                        elseif obj.shouldClearCal
                            obj.clearCalNow = true;
                        end
                        if obj.activationCount.cal==1 && obj.controlState>obj.stateEnum.cal_done
                            obj.controlState = obj.stateEnum.cal_positioning;
                        end
                    else
                        obj.clearValNow = true; % always issue a validation clear, in case there is any data
                        obj.controlState = obj.stateEnum.val_validating;
                        obj.shouldUpdateStatusText = true;
                        obj.calDisplay.videoSize = obj.valVideoSize;
                    end
                    obj.lastUpdate = {};
                    obj.awaitingPointResult = 0;
                    obj.isActive = true;
                    obj.shouldUpdateStatusText = true;
                    obj.isNonActiveShowingVideo = false;
                    obj.onVideoTimestamp = nan;
                    % backup Titta pacing duration and set to 0, since the
                    % controller controls when data should be collected
                    obj.setTittaPacing(type(1:3),'');
                    if bitget(obj.logTypes,1)
                        if isCal
                            obj.log_to_cmd('controller activated for calibration. Activation #%d',obj.activationCount.(mode));
                        else
                            obj.log_to_cmd('controller activated for validation. Activation #%d',obj.activationCount.(mode));
                        end
                    end
                case {'cal_deactivate','val_deactivate'}
                    obj.isActive = false;
                    obj.shouldUpdateStatusText = true;
                    % backup Titta pacing duration and set to 0, since the
                    % controller controls when data should be collected
                    obj.setTittaPacing('',type(1:3));
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('controller deactivated for %s',ternary(startsWith(type,'cal'),'calibration','validation'));
                    end
                % cal/val mode switches
                case 'cal_enter'
                    obj.stage = 'cal';
                    if obj.isActive
                        obj.setTittaPacing('cal','val');
                    elseif obj.isNonActiveShowingVideo
                        obj.setupNonActiveVideo();
                    end
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('calibration mode entered');
                    end
                case 'val_enter'
                    obj.stage = 'val';
                    if obj.isActive
                        obj.setTittaPacing('val','cal');
                    elseif obj.isNonActiveShowingVideo
                        obj.setupNonActiveVideo();
                    end
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('validation mode entered');
                    end
                case 'cal_collect_started'
                    obj.calDisplay.videoSize = obj.calVideoSize;
                    obj.isShowingPointManually = ~obj.isActive;
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                case 'val_collect_started'
                    obj.calDisplay.videoSize = obj.valVideoSize;
                    obj.isShowingPointManually = ~obj.isActive;
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                % calibration point collected
                case 'cal_collect_done'
                    obj.lastUpdate = {type,currentPoint,posNorm,callResult};
                    if bitget(obj.logTypes,2)
                        success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
                        obj.log_to_cmd('calibration point collect: %s',ternary(success,'success','failed'));
                    end
                    % update point status
                    iPoint = find(obj.calPoints==currentPoint);
                    if ~isempty(iPoint) && all(posNorm==obj.calPoss(iPoint,:))
                        obj.calPointsState(iPoint) = obj.pointStateEnum.collected;
                    end
                    obj.shouldClearCal = true;  % mark that we need to clear calibration if controller is activated
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                    obj.isShowingPointManually = false;
                    if obj.isNonActiveShowingVideo
                        obj.setupNonActiveVideo();
                    end
                % validation point collected
                case 'val_collect_done'
                    obj.lastUpdate = {type,currentPoint,posNorm,callResult};
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('validation point collect: success');
                    end
                    % update point status
                    iPoint = find(obj.valPoints==currentPoint);
                    if ~isempty(iPoint) && all(posNorm==obj.valPoss(iPoint,:))
                        obj.valPointsState(iPoint) = obj.pointStateEnum.collected;
                    end
                    obj.shouldUpdateStatusText = obj.shouldUpdateStatusText || obj.isShowingPointManually;
                    obj.isShowingPointManually = false;
                    if obj.isNonActiveShowingVideo
                        obj.setupNonActiveVideo();
                    end
                % calibration point discarded
                case 'cal_discard'
                    obj.lastUpdate = {type,currentPoint,posNorm,callResult};
                    if bitget(obj.logTypes,2)
                        success = callResult.status==0;     % TOBII_RESEARCH_STATUS_OK
                        obj.log_to_cmd('calibration point discard: %s',ternary(success,'success','failed'));
                    end
                    % update point status
                    iPoint = find(obj.calPoints==currentPoint);
                    if ~isempty(iPoint) && all(posNorm==obj.calPoss(iPoint,:))
                        obj.calPointsState(iPoint) = obj.pointStateEnum.nothing;
                    end
                % validation point discarded
                case 'val_discard'
                    obj.lastUpdate = {type,currentPoint,posNorm,callResult};
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('validation point discard: success');
                    end
                    % update point status
                    iPoint = find(obj.valPoints==currentPoint);
                    if ~isempty(iPoint) && all(posNorm==obj.valPoss(iPoint,:))
                        obj.valPointsState(iPoint) = obj.pointStateEnum.nothing;
                    end
                % new calibration computed (may have failed) or loaded
                case 'cal_compute_and_apply'
                    obj.lastUpdate = {type,callResult};
                    if bitget(obj.logTypes,2)
                        success = callResult.status==0 && strcmpi(callResult.calibrationResult.status,'success');
                        obj.log_to_cmd('calibration compute and apply result received: %s',ternary(success,'success','failed'));
                    end
                % a calibration was loaded
                case 'cal_load'
                    % mark that we need to clear calibration if controller is activated
                    obj.shouldClearCal = true;
                % calibration was cleared: now at a blank slate
                case 'cal_cleared'
                    obj.lastUpdate = {type};
                    if bitget(obj.logTypes,2)
                        obj.log_to_cmd('calibration clear result received');
                    end
                    obj.shouldClearCal = false;
                % interface exited from calibration or validation screen
                case {'cal_finished','val_finished'}
                    % we're done according to operator, clean up
                    obj.setTittaPacing('',type(1:3));
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
                switch obj.controlState
                    case obj.stateEnum.cal_positioning
                        txt = sprintf('Positioning %d/%d',obj.onScreenTimeThresh, obj.onScreenTimeThreshCap);
                    case obj.stateEnum.cal_gazing
                        % draw video rect
                        txt = sprintf('Gaze training\nvideo size %d/%d',obj.videoSize,size(obj.videoSizes,1));
                    case obj.stateEnum.cal_calibrating
                        txt = sprintf('Calibrating %d/%d',obj.calPoint,length(obj.calPoints));
                    case obj.stateEnum.cal_done
                        txt = 'Calibration done';

                    case obj.stateEnum.val_validating
                        txt = sprintf('Validating %d/%d',obj.valPoint,length(obj.valPoints));
                    case obj.stateEnum.val_done
                        txt = 'Validation done';
                end
            end
            txt = sprintf('%s\nReward: %s',txt,ternary(obj.dispensingReward,'on','off'));
            obj.shouldUpdateStatusText = false;
        end

        function draw(obj,wpnts,tick,sFac,offset)
            % wpnts: two window pointers. first is for participant screen,
            % second for operator
            % sFac and offset are used to scale from participant screen to
            % operator screen, in case they have different resolutions
            if ~obj.isActive && ~obj.isNonActiveShowingVideo && ~obj.isShowingPointManually
                return;
            end
            if obj.drawState>0 && ~obj.isShowingPointManually
                drawCmd = 'draw';
                if obj.drawState==1
                    drawCmd = 'new';
                    if obj.controlState == obj.stateEnum.cal_positioning
                        obj.calDisplay.videoSize = obj.videoSizes(1,:);
                    end
                end
                pos = [nan nan];
                if ~obj.isActive && obj.isNonActiveShowingVideo
                    pos = obj.scrRes/2;
                elseif ismember(obj.controlState, [obj.stateEnum.cal_positioning obj.stateEnum.cal_gazing])
                    pos = obj.scrRes/2;
                elseif obj.controlState == obj.stateEnum.cal_calibrating
                    calPos = obj.calPoss(obj.calPoint,:).*obj.scrRes(:).';
                    pos = calPos;
                elseif obj.controlState == obj.stateEnum.val_validating
                    valPos = obj.valPoss(obj.valPoint,:).*obj.scrRes(:).';
                    pos = valPos;
                end
                % Don't call draw here if we've issued a command to collect
                % calibration data for a point and haven't gotten a status
                % update yet, then Titta is showing the point for us
                if obj.awaitingPointResult~=1 || obj.drawExtraFrame
                    obj.calDisplay.doDraw(wpnts(1),drawCmd,nan,pos,tick,obj.stage);
                end
                if ~isnan(pos(1))
                    obj.drawState = 2;
                end

                if obj.awaitingPointResult~=1 && obj.drawExtraFrame
                    obj.drawExtraFrame = false;
                end
            end

            % draw video rect for operator
            if (~obj.isActive && (obj.isNonActiveShowingVideo || obj.isShowingPointManually)) || ...
               ismember(obj.controlState, [obj.stateEnum.cal_gazing obj.stateEnum.cal_calibrating obj.stateEnum.val_validating])
                pos = obj.calDisplay.pos;
                sz = obj.calDisplay.videoSize;
                rect = CenterRectOnPointd([0 0 sz*sFac],pos(1)*sFac+offset(1),pos(2)*sFac+offset(2));
                Screen('FrameRect',wpnts(end),obj.videoRectColor,rect,4);
            end

            % draw gaze if wanted
            if obj.showGazeToOperator
                sz = [1/40 1/120]*obj.scrRes(2);
                for p=1:3
                    switch p
                        case 1
                            pos = obj.leftGaze;
                            clr = [255 0 0];
                        case 2
                            pos = obj.rightGaze;
                            clr = [0 0 255];
                        case 3
                            pos = obj.meanGaze;
                            clr = 0;
                    end
                rectH = CenterRectOnPointd([0 0        sz ], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(1)*sFac+offset(1), pos(2)*sFac+offset(2));
                Screen('FillRect',wpnts(end), clr, rectH);
                Screen('FillRect',wpnts(end), clr, rectV);
                end
            end
        end
    end

    methods (Static)
        function canDo = canControl(type)
            switch type
                case 'calibration'
                    canDo = true;
                case 'validation'
                    canDo = true;
                otherwise
                    error('NonHumanPrimateCalController: controller capability "%s" not understood',type)
            end
        end
    end
    
    methods (Access = private, Hidden)
        function setCleanState(obj)
            if bitget(obj.logTypes,1)
                obj.log_to_cmd('cleanup state');
            end
            obj.isActive            = false;
            obj.isNonActiveShowingVideo = false;
            obj.isShowingPointManually  = false;
            obj.dispensingReward        = false;
            obj.dispensingForcedReward  = false;
            obj.controlState        = obj.stateEnum.cal_positioning;
            obj.shouldRewindState   = false;
            obj.shouldClearCal      = false;
            obj.clearCalNow         = false;
            obj.clearValNow         = false;
            obj.activationCount.cal = 0;
            obj.activationCount.val = 0;
            obj.shouldUpdateStatusText = true;

            obj.stage               = '';
            obj.gazeOnScreen        = false;
            obj.leftGaze            = [nan nan].';
            obj.rightGaze           = [nan nan].';
            obj.meanGaze            = [nan nan].';
            obj.onScreenTimestamp   = nan;
            obj.offScreenTimestamp  = nan;
            obj.onVideoTimestamp    = nan;
            obj.latestTimestamp     = nan;

            obj.onScreenTimeThresh  = 1;
            obj.videoSize           = 1;

            obj.calPoint            = 1;
            obj.calPoints           = [];
            obj.calPoss             = [];
            obj.calPointsState      = [];

            obj.valPoint            = 1;
            obj.valPoints           = [];
            obj.valPoss             = [];
            obj.valPointsState      = [];

            obj.awaitingPointResult = 0;

            obj.drawState           = 1;
            obj.drawExtraFrame      = false;
            obj.backupPaceDuration  = struct('cal',[],'val',[]);
        end

        function updateGaze(obj)
            if isempty(obj.trackerFrequency)
                obj.trackerFrequency = obj.EThndl.frequency;
            end
            gaze = obj.EThndl.buffer.peekN('gaze',round(obj.gazeFetchDur/1000*obj.trackerFrequency));
            if isempty(gaze)
                obj.meanGaze = nan;
                return
            end

            obj.latestTimestamp = double(gaze.systemTimeStamp(end))/1000;   % us -> ms
            fValid = mean([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],2);
            if any(fValid>obj.minValidGazeFrac)
                switch obj.gazeAggregationMethod
                    case 1
                        % take mean of valid samples
                        obj.leftGaze = mean(gaze. left.gazePoint.onDisplayArea(:,gaze. left.gazePoint.valid),2,'omitnan').*obj.scrRes(:);
                        obj.rightGaze= mean(gaze.right.gazePoint.onDisplayArea(:,gaze.right.gazePoint.valid),2,'omitnan').*obj.scrRes(:);
                    case 2
                        % use last valid sample
                        qValid = all([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1);
                        iSamp = find(qValid,1,'last');
                        obj.leftGaze = gaze. left.gazePoint.onDisplayArea(:,iSamp).*obj.scrRes(:);
                        obj.rightGaze= gaze.right.gazePoint.onDisplayArea(:,iSamp).*obj.scrRes(:);
                end
                obj.meanGaze = mean([obj.leftGaze obj.rightGaze],2);

                obj.gazeOnScreen = obj.meanGaze(1) > 0 && obj.meanGaze(1)<obj.scrRes(1) && ...
                                   obj.meanGaze(2) > 0 && obj.meanGaze(2)<obj.scrRes(2);
                if obj.gazeOnScreen
                    obj.offScreenTimestamp = nan;
                    if isnan(obj.onScreenTimestamp)
                        iSamp = find(any([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1),1,'last');
                        obj.onScreenTimestamp = double(gaze.systemTimeStamp(iSamp))/1000;   % us -> ms
                    end
                end
            else
                obj.gazeOnScreen = false;
                obj.leftGaze = [nan nan].';
                obj.rightGaze= [nan nan].';
                obj.meanGaze = [nan nan].';
                obj.onScreenTimestamp = nan;
                if isnan(obj.offScreenTimestamp)
                    obj.offScreenTimestamp = double(gaze.systemTimeStamp(1))/1000;  % us -> ms
                end
            end
        end

        function reward(obj,on)
            on = ~~on;
            if (on && obj.dispensingReward) || (~on && ~obj.dispensingReward)
                % nothing to do, already in expected state
                return
            end
            if obj.dispensingForcedReward && ~on
                % ignore request to switch off reward, since its forced on
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

        function trainLookScreen(obj)
            onScreenTime = obj.latestTimestamp-obj.onScreenTimestamp;
            % looking long enough on the screen, provide reward
            if onScreenTime > obj.onScreenTimeThresh
                obj.reward(true);
            end
            % if looking much longer than current looking threshold,
            % possibly increase threshold
            if onScreenTime > obj.onScreenTimeThresh*2
                if rand()<=obj.onScreenTimeThreshIncRate
                    obj.onScreenTimeThresh = min(obj.onScreenTimeThresh*2,obj.onScreenTimeThreshCap);   % limit to onScreenTimeThreshCap
                    obj.shouldUpdateStatusText = true;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('on-screen looking time threshold increased to %d',obj.onScreenTimeThresh);
                    end
                end
            end
        end

        function trainLookVideo(obj)
            onScreenTime = obj.latestTimestamp-obj.onScreenTimestamp;
            if onScreenTime > obj.onScreenTimeThresh
                % check distance to center of video (which is always at
                % center of screen)
                dist = hypot(obj.meanGaze(1)-obj.scrRes(1)/2,obj.meanGaze(2)-obj.scrRes(2)/2);
                % if looking close enough to video, provide reward and
                % possibly decrease video size
                if dist < obj.videoSizes(obj.videoSize,2)*2
                    obj.reward(true);
                    if onScreenTime > obj.videoShrinkTime && rand()<=obj.videoShrinkRate
                        obj.videoSize = min(obj.videoSize+1,size(obj.videoSizes,1));
                        obj.calDisplay.videoSize = obj.videoSizes(obj.videoSize,:);
                        obj.shouldUpdateStatusText = true;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('video size decreased to %dx%d',obj.videoSizes(obj.videoSize,:));
                        end
                    end
                else
                    obj.reward(false);
                end
            end
        end

        function commands = calibrate(obj)
            commands = {};
            calPos = obj.calPoss(obj.calPoint,:).*obj.scrRes(:).';
            dist = hypot(obj.meanGaze(1)-calPos(1),obj.meanGaze(2)-calPos(2));
            if obj.shouldRewindState
                if obj.awaitingPointResult~=4
                    % clear calibration
                    commands = {{'cal','clear'}};
                    obj.calPoint = 1;
                    obj.drawState = 1;
                    obj.awaitingPointResult = 4;
                    obj.shouldUpdateStatusText = true;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('rewinding state: clearing the calibration');
                    end
                elseif obj.awaitingPointResult==4 && ~isempty(obj.lastUpdate) && strcmp(obj.lastUpdate{1},'cal_cleared')
                    obj.awaitingPointResult = 0;
                    if obj.reEntryStateCal<obj.stateEnum.cal_calibrating
                        obj.controlState = obj.stateEnum.cal_gazing;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('calibration cleared, continue state rewind');
                        end
                    else
                        obj.shouldRewindState = false;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('calibration cleared, restarting collection');
                        end
                        obj.calDisplay.videoSize = obj.calVideoSize;
                    end
                    obj.shouldUpdateStatusText = true;
                end
                obj.lastUpdate = {};
            elseif obj.awaitingPointResult>0
                % we're waiting for the result of an action. Those are all
                % blocking in the Python code, but not here. For identical
                % behavior (and easier logic), we put all the response
                % waiting logic here, short-circuiting the below logic that
                % depends on where the subject looks
                if isempty(obj.lastUpdate)
                    return;
                end
                if obj.awaitingPointResult==1 && strcmp(obj.lastUpdate{1},'cal_collect_done')
                    % check this is for the expected point
                    if obj.lastUpdate{2}==obj.calPoints(obj.calPoint) && all(obj.lastUpdate{3}==obj.calPoss(obj.calPoint,:))
                        % check result
                        if obj.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
                            % success, decide next action
                            if obj.calPoint<length(obj.calPoints) && ~(obj.calPoint==1 && obj.calAfterFirstCollected)
                                % calibrate next point
                                obj.calPoint = obj.calPoint+1;
                                obj.awaitingPointResult = 0;
                                obj.shouldUpdateStatusText = true;
                                obj.onVideoTimestamp = nan;
                                obj.drawState = 1;
                                if bitget(obj.logTypes,1)
                                    obj.log_to_cmd('successfully collected calibration point %d, continue with collection of point %d', obj.calPoints(obj.calPoint-1), obj.calPoints(obj.calPoint));
                                end
                            else
                                % all collected or first collected and calibration wanted after first -> attempt calibration
                                commands = {{'cal','compute_and_apply'}};
                                obj.awaitingPointResult = 3;
                                obj.shouldUpdateStatusText = true;
                                if bitget(obj.logTypes,1)
                                    if obj.calPoint==1 && obj.calAfterFirstCollected
                                        obj.log_to_cmd('first calibration point successfully collected, requesting computing and applying calibration before continuing collection of other points');
                                    else
                                        obj.log_to_cmd('all calibration points successfully collected, requesting computing and applying calibration');
                                    end
                                end
                            end
                        else
                            % failed collecting calibration point, discard
                            % (to be safe its really gone from state,
                            % overkill i think but doesn't hurt)
                            commands = {{'cal','discard_point', obj.calPoints(obj.calPoint), obj.calPoss(obj.calPoint,:)}};
                            obj.awaitingPointResult = 2;
                            obj.drawState = 1;  % Titta calibration logic tells drawer to clean up upon failed point. Reshow point here
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('failed to collect calibration point %d, requesting to discard it', obj.calPoints(obj.calPoint));
                            end
                        end
                    end
                    obj.lastUpdate = {};
                elseif obj.awaitingPointResult==2 && strcmp(obj.lastUpdate{1},'cal_discard')
                    % check this is for the expected point
                    if obj.lastUpdate{2}==obj.calPoints(obj.calPoint) && all(obj.lastUpdate{3}==obj.calPoss(obj.calPoint,:))
                        if obj.lastUpdate{4}.status==0     % TOBII_RESEARCH_STATUS_OK
                            obj.awaitingPointResult = 0;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('successfully discarded calibration point %d', obj.calPoints(obj.calPoint));
                            end
                        else
                            error('can''t discard point, something seriously wrong')
                        end
                    end
                    obj.lastUpdate = {};
                elseif obj.awaitingPointResult==3 && strcmp(obj.lastUpdate{1},'cal_compute_and_apply')
                    if obj.lastUpdate{2}.status==0 && strcmpi(obj.lastUpdate{2}.calibrationResult.status,'success')
                        % successful calibration
                        if obj.calPoint==1 && obj.calAfterFirstCollected
                            obj.calPoint = obj.calPoint+1;
                            obj.awaitingPointResult = 0;
                            obj.shouldUpdateStatusText = true;
                            obj.onVideoTimestamp = nan;
                            obj.drawState = 1;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('calibration successfully applied, continuing calibration. Continue with collection of point %d', obj.calPoints(obj.calPoint));
                            end
                        else
                            obj.awaitingPointResult = 0;
                            obj.reward(false);
                            obj.controlState = obj.stateEnum.cal_done;
                            obj.shouldUpdateStatusText = true;
                            commands = {{'cal','disable_controller'}};
                            obj.drawState = 0;
                            if obj.calShowVideoWhenDone
                                obj.setupNonActiveVideo();
                            end
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('calibration successfully applied, disabling controller');
                            end
                        end
                    else
                        % failed, start over
                        for p=length(obj.calPoints):-1:1    % reverse so we can set cal state back to first point and await discard of that first point, will arrive last
                            commands = [commands {{'cal','discard_point', obj.calPoints(p), obj.calPoss(p,:)}}]; %#ok<AGROW> 
                        end
                        obj.awaitingPointResult = 2;
                        obj.calPoint = 1;
                        obj.drawState = 1;
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
            elseif dist < obj.calOnTargetDistFac*obj.scrRes(2)
                obj.reward(true);
                if obj.onVideoTimestamp<0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = obj.latestTimestamp;
                end
                onDur = obj.latestTimestamp-obj.onVideoTimestamp;
                if onDur > obj.calOnTargetTime && obj.awaitingPointResult==0
                    % request calibration point collection
                    commands = {{'cal','collect_point', obj.calPoints(obj.calPoint), obj.calPoss(obj.calPoint,:)}};
                    obj.awaitingPointResult = 1;
                    obj.calPointsState(obj.calPoint) = obj.pointStateEnum.collecting;
                    obj.drawExtraFrame = true;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('request calibration of point %d @ (%.3f,%.3f)', obj.calPoints(obj.calPoint), obj.calPoss(obj.calPoint,:));
                    end
                end
            else
                if obj.onVideoTimestamp>0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = -obj.latestTimestamp;
                end
                offDur = obj.latestTimestamp--obj.onVideoTimestamp;
                if offDur > obj.maxOffScreenTime
                    obj.reward(false);
                    % request discarding data for this point if its being
                    % collected
                    if obj.calPointsState(obj.calPoint)==obj.pointStateEnum.collecting || obj.awaitingPointResult~=0
                        commands = {{'cal','discard_point', obj.calPoints(obj.calPoint), obj.calPoss(obj.calPoint,:)}};
                        obj.awaitingPointResult = 2;
                        obj.calPointsState(obj.calPoint) = obj.pointStateEnum.discarding;
                        if bitget(obj.logTypes,1)
                            obj.log_to_cmd('request discarding calibration point %d @ (%.3f,%.3f)',obj.calPoints(obj.calPoint), obj.calPoss(obj.calPoint,:));
                        end
                    end
                end
            end
        end


        function commands = validate(obj)
            commands = {};
            if obj.awaitingPointResult>0
                % we're waiting for the result of an action. Check if there
                % is a result and process. Unlike calibration, this does
                % not short-circuit the logic below, as we may wish to
                % abort collection of a validation point
                if obj.awaitingPointResult==1 && ~isempty(obj.lastUpdate) && strcmp(obj.lastUpdate{1},'val_collect_done')
                    % check this is for the expected point
                    if obj.lastUpdate{2}==obj.valPoints(obj.valPoint) && all(obj.lastUpdate{3}==obj.valPoss(obj.valPoint,:))
                        % validation points always succeed, decide next
                        % action
                        if obj.valPoint<length(obj.valPoints)
                            obj.valPoint = obj.valPoint+1;
                            obj.awaitingPointResult = 0;
                            obj.shouldUpdateStatusText = true;
                            obj.onVideoTimestamp = nan;
                            obj.drawState = 1;
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('successfully collected validation point %d, continue with collection of point %d', obj.valPoints(obj.valPoint-1), obj.valPoints(obj.valPoint));
                            end
                        else
                            % done validating
                            obj.awaitingPointResult = 0;
                            obj.reward(false);
                            obj.controlState = obj.stateEnum.val_done;
                            obj.shouldUpdateStatusText = true;
                            obj.onVideoTimestamp = nan;
                            commands = {{'val','disable_controller'}};
                            obj.drawState = 0;
                            if obj.valShowVideoWhenDone
                                obj.setupNonActiveVideo();
                            end
                            if bitget(obj.logTypes,1)
                                obj.log_to_cmd('validation finished, disabling controller');
                            end
                            return
                        end
                    end
                    obj.lastUpdate = {};
                elseif obj.awaitingPointResult==2 && ~isempty(obj.lastUpdate) && strcmp(obj.lastUpdate{1},'val_discard')
                    % check this is for the expected point
                    if obj.lastUpdate{2}==obj.valPoints(obj.valPoint) && all(obj.lastUpdate{3}==obj.valPoss(obj.valPoint,:))
                        obj.awaitingPointResult = 0;
                    end
                    obj.lastUpdate = {};
                elseif ~isempty(obj.lastUpdate)
                    % unexpected (perhaps stale, e.g. from before auto was switched on) update, discard
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('unexpected update from Titta during validation: %s, discarding',obj.lastUpdate{1});
                    end
                    obj.lastUpdate = {};
                end
            end

            valPos = obj.valPoss(obj.valPoint,:).*obj.scrRes(:).';
            distL  = hypot(obj. leftGaze(1)-valPos(1), obj. leftGaze(2)-valPos(2));
            distR  = hypot(obj.rightGaze(1)-valPos(1), obj.rightGaze(2)-valPos(2));
            distM  = hypot(obj. meanGaze(1)-valPos(1), obj. meanGaze(2)-valPos(2));
            minDist = min([distM, distL, distR]);
            if minDist<obj.valOnTargetDist
                if obj.onVideoTimestamp<0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = obj.latestTimestamp;
                end
                onDur = obj.latestTimestamp-obj.onVideoTimestamp;
                if onDur > obj.valOnTargetTime && obj.awaitingPointResult==0
                    obj.reward(true)
                    % request validation point collection
                    commands = {{'val','collect_point', obj.valPoints(obj.valPoint), obj.valPoss(obj.valPoint,:)}};
                    obj.awaitingPointResult = 1;
                    obj.valPointsState(obj.valPoint) = obj.pointStateEnum.collecting;
                    obj.drawExtraFrame = true;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('request collection of validation data for point %d @ (%.3f,%.3f)', obj.valPoints(obj.valPoint), obj.valPoss(obj.valPoint,:));
                    end
                end
            else
                obj.reward(false)
                % request discarding data for this point if its being
                % collected
                if obj.valPointsState(obj.valPoint)==obj.pointStateEnum.collecting || obj.awaitingPointResult~=0
                    commands = {{'val','discard_point', obj.valPoints(obj.valPoint), obj.valPoss(obj.valPoint,:)}};
                    obj.awaitingPointResult = 2;
                    obj.valPointsState(obj.valPoint) = obj.pointStateEnum.discarding;
                    if bitget(obj.logTypes,1)
                        obj.log_to_cmd('request discarding validation point %d @ (%.3f,%.3f)',obj.valPoints(obj.valPoint), obj.valPoss(obj.valPoint,:));
                    end
                end
            end
        end

        function setTittaPacing(obj,set,reset)
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

        function setupNonActiveVideo(obj)
            if strcmp(obj.stage,'cal')
                obj.calDisplay.videoSize = obj.calVideoSizeWhenDone;
            else
                obj.calDisplay.videoSize = obj.valVideoSizeWhenDone;
            end
            obj.drawState = 1;
            obj.isNonActiveShowingVideo = true;
            obj.onVideoTimestamp = nan;
        end

        function determineNonActiveReward(obj)
            % for during manual calibration points and when showing video
            % after a calibration or validation
            vidPos = obj.calDisplay.pos;
            distL  = hypot(obj. leftGaze(1)-vidPos(1), obj. leftGaze(2)-vidPos(2));
            distR  = hypot(obj.rightGaze(1)-vidPos(1), obj.rightGaze(2)-vidPos(2));
            distM  = hypot(obj. meanGaze(1)-vidPos(1), obj. meanGaze(2)-vidPos(2));
            minDist = min([distM, distL, distR]);

            if strcmp(obj.stage,'cal')
                distFac = obj.calWhenDoneRewardDistFac;
                dur     = obj.calWhenDoneRewardTime;
            else
                distFac = obj.valWhenDoneRewardDistFac;
                dur     = obj.valWhenDoneRewardTime;
            end
            sz = obj.calDisplay.videoSize;
            dist = sz(1)*distFac;

            if minDist < dist
                if obj.onVideoTimestamp<0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = obj.latestTimestamp;
                end
                onDur = obj.latestTimestamp-obj.onVideoTimestamp;
                if onDur > dur
                    obj.reward(true)
                end
            else
                obj.reward(false)
            end
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
    end
end

%% helpers
function out = ternary(cond, a, b)
out = subsref({b; a}, substruct('{}', {cond + 1}));
end