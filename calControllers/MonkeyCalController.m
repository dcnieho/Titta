classdef MonkeyCalController < handle
    properties (Access=private, Constant)
        stateEnum = struct('cal_positioning',0, 'cal_gazing',1, 'cal_calibrating',2);
    end
    properties (SetAccess=private)
        % state
        gazeOnScreen;                               % true if we have gaze for both eyes and the average position is on screen
        meanGaze;
        onScreenTimestamp;                          % time of start of episode of gaze on screen
        offScreenTimestamp;                         % time of start of episode of gaze off screen
        onVideoTimestamp;                           % time of start of episode of gaze on video (for calibration)
        latestTimestamp;                            % latest gaze timestamp

        onScreenTimeThresh;
        videoSize;
        calPoint;
    end
    properties
        % comms
        EThndl;
        calDisplay;
        rewardProvider = [];

        nSamples                    = 3;            % number of gaze sample to peek on each iteration
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

        calOnVideoTime              = 500;
        calOnVideoDistFac           = 1/3;          % max gaze distance to be considered close enough to a point to attempt calibration (factor of vertical size of screen)
        calPoints                   = [];           % ID of calibration points to run by the controller, in provided order
        calPoss                     = [];           % corresponding positions
    end
    properties (Access=private,Hidden=true)
        controlState;
    end
    
    
    methods
        function obj = MonkeyCalController(EThndl,calDisplay,rewardProvider)
            obj.setCleanState();
            obj.EThndl = EThndl;
            obj.calDisplay = calDisplay;
            if nargin>2
                obj.rewardProvider = rewardProvider;
            end
        end

        function commands = tick(obj)
            commands = {};
            offScreenTime = obj.latestTimestamp-obj.offScreenTimestamp;
            if offScreenTime > obj.maxOffScreenTime
                obj.reward(false);
            else
                if obj.onScreenTimeThresh < obj.onScreenTimeThreshCap
                    % training to position and look at screen
                    obj.trainLookScreen();
                elseif obj.videoSize < size(obj.videoSizes,1)
                    % training to look at video
                    obj.controlState = obj.stateEnum.cal_gazing;
                    obj.trainLookVideo();
                else
                    % calibrating
                    obj.controlState = obj.stateEnum.cal_calibrating;
                    obj.calibrate();
                end
            end
        end

        function receiveUpdate(obj,titta_instance,currentPoint,posNorm,posPix,stage,type,calState)
            type
            calState
            if strcmp(type,'cal_compute_and_apply')
                calState.calibrationResult
            end
            % TODO: interface through which at least the following can be
            % communicated to the controller:
            % - cal/val mode switch
            % - calibration point result
            % - calibration point discard result
            % - calibration compute result
        end

        function draw(obj,wpnt)
            switch obj.controlState
                case obj.stateEnum.cal_positioning
                    % nothing to draw
                case obj.stateEnum.cal_gazing
                    % draw video rect
                    rect = CenterRectOnPointd([0 0 obj.videoSizes(obj.videoSize,:)],obj.scrRes(1)/2,obj.scrRes(2)/2);
                    Screen('FrameRect',wpnt,0,rect,4);
                case obj.stateEnum.cal_calibrating
                    calPos = obj.calPoss(obj.calPoint,:).*obj.scrRes(:).';
                    rect = CenterRectOnPointd([0 0 obj.videoSizes(obj.videoSize,:)],calPos(1),calPos(2));
                    Screen('FrameRect',wpnt,0,rect,4);
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
                    error('MonkeyCalController: controller capability "%s" not understood',type)
            end
        end
    end
    
    methods (Access = private, Hidden)
        function setCleanState(obj)
            obj.controlState = obj.stateEnum.cal_positioning;

            obj.gazeOnScreen = false;
            obj.meanGaze = [nan nan];
            obj.onScreenTimestamp = nan;
            obj.offScreenTimestamp = nan;
            obj.onVideoTimestamp = nan;
            obj.latestTimestamp = nan;

            obj.onScreenTimeThresh = 1;
            obj.videoSize = 1;
            obj.calPoint = 1;
        end

        function updateGaze(obj)
            gaze = obj.EThndl.buffer.peekN('gaze',obj.nSamples);
            if isempty(gaze)
                return
            end
            obj.latestTimestamp = gaze.systemTimeStamp(end)/1000;   % us -> ms
            qValid = all([gaze.left.gazePoint.valid; gaze.right.gazePoint.valid],1);
            iSamp = find(qValid,1);
            if isempty(iSamp)
                obj.gazeOnScreen = false;
                obj.meanGaze = [nan nan];
                obj.onScreenTimestamp = nan;
                if isnan(obj.offScreenTimestamp)
                    obj.offScreenTimestamp = gaze.systemTimeStamp(1)/1000;  % us -> ms
                end
            else
                iSamp = find(qValid,1,'last');
                obj.meanGaze = mean([eyeData.left.gazePoint.onDisplayArea(:,iSamp) eyeData.right.gazePoint.onDisplayArea(:,iSamp)],2);
                obj.meanGaze = obj.meanGaze.*obj.scrRes(:);
                obj.gazeOnScreen = obj.meanGaze(1) > 0 && obj.meanGaze(1)<obj.scrRes(1) && ...
                                   obj.meanGaze(2) > 0 && obj.meanGaze(2)<obj.scrRes(2);
                if obj.gazeOnScreen
                    obj.offScreenTimestamp = nan;
                    if isnan(obj.onScreenTimestamp)
                        obj.onScreenTimestamp = gaze.systemTimeStamp(iSamp)/1000;   % us -> ms
                    end
                end
            end
        end

        function reward(obj,on)
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
                    if rand()<=obj.videoShrinkRate
                        obj.videoSize = min(obj.videoSize,size(obj.videoSizes,1));
                        obj.calDisplay.calSize = obj.videoSizes(obj.videoSize,:);
                    end
                else
                    obj.reward(false);
                end
            end
        end

        function calibrate(obj)
            calPos = obj.calPoss(obj.calPoint,:).*obj.scrRes(:).';
            dist = hypot(obj.meanGaze(1)-calPos(1),obj.meanGaze(2)-calPos(2));
            if dist < obj.calOnVideoDistFac*obj.scrRes(2)
                obj.reward(true);
                if obj.onVideoTimestamp<0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = obj.latestTimestamp;
                end
                onDur = obj.latestTimestamp-obj.onVideoTimestamp;
                if onDur > obj.calOnVideoTime
                    % TODO issue calibration, rest of logic
                end
            else
                if obj.onVideoTimestamp>0 || isnan(obj.onVideoTimestamp)
                    obj.onVideoTimestamp = -obj.latestTimestamp;
                end
                offDur = obj.latestTimestamp--obj.onVideoTimestamp;
                if offDur > obj.maxOffScreenTime
                    obj.reward(false);
                    % TODO: discard data for this point
                end
            end
        end
    end
end
