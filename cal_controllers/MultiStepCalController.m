classdef MultiStepCalController < handle
    properties (Constant)
        pointStateEnum = struct('nothing',0, 'showing',1, 'collecting',2, 'discarding',3, 'collected', 4);
    end
    properties (SetAccess=private)
        step                        = 1;            % state

        gazePos;
        gazeOnScreen;                               % true if we have gaze for both eyes and the average position is on screen
        onScreenTimestamp;                          % time of start of episode of gaze on screen
        offScreenTimestamp;                         % time of start of episode of gaze off screen
        onTargetTimestamp;                          % time of start of episode of gaze on video (for calibration)
        latestTimestamp;                            % latest gaze timestamp

        calPointsForStep;
        calPoints                   = [];           % ID of calibration points to run by the controller, in provided order
        calPoss                     = [];           % corresponding positions
        calMargins                  = [];           % maximum distance of current gaze from calibration points to be counted as on a given point, for each step. fractions of horizontal screen resolution
        calPointsState              = [];
    end
    properties
        % comms
        EThndl;
        calDisplay;
        rewardProvider;

        gazeFetchDur                = 100;          % duration of gaze samples to peek on each iteration (ms, e.g., last 100 ms of gaze)
        gazeAggregationMethod       = 1;            % 1: use mean of all samples during last gazeFetchDur ms, 2: use mean of last valid sample during last gazeFetchDur ms
        minValidGazeFrac            = .5;           % minimum fraction of gaze samples that should be valid. If not exceeded, gaze is counted as offscreen
        maxOffScreenTime            = 800;          % ms
        scrRes;

        calOnTargetTime             = 500;          % ms

        showRewardTargetWhenDone    = true;         % if true, shows a centered square on the screen after the calibration logic is finished and the controller disengages. Gaze on the square triggers rewards (for demo purposes)
        rewardTargetSize            = .2;           % fraction of horizontal screen resolution
        rewardTargetColor           = [255 0 0];

        showGazeToOperator          = true;         % if true, aggregated gaze as used by the controller is drawn as a crosshair on the operator screen
        logTypes                    = 0;            % bitmask: if 0, no logging. bit 1: print basic messages about what its up to. bit 2: print each command received in receiveUpdate(), bit 3: print messages about rewards (many!)
        logReceiver                 = 0;            % if 0: matlab command line. if 1: Titta
    end
    
    
    methods
        function obj = MultiStepCalController(EThndl,calDisplay,scrRes,rewardProvider)
            obj.setCleanState();
            obj.EThndl = EThndl;
            obj.calDisplay = calDisplay;
            if nargin>2 && ~isempty(scrRes)
                obj.scrRes = scrRes;
            end
            if nargin>3 && ~isempty(rewardProvider)
                obj.rewardProvider = rewardProvider;
            end
        end

        function setCalPoints(obj, calPoints, calPoss, margins)
            assert(~obj.isActive,'cannot set calibration points when already calibrating or calibrated')
            obj.calPoints       = calPoints;                % ID of calibration points to run by the controller, in provided order
            obj.calPoss         = calPoss;                  % corresponding positions
            obj.calMargins      = margins;                  % margins around the points for each step
            obj.calPointsState  = repmat(obj.pointStateEnum.nothing, size(obj.calPoss));
        end

        function commands = tick(obj)
            commands = {};
            
        end

        function receiveUpdate(obj,~,currentPoint,posNorm,~,~,event,callResult)
            % receiveUpdate(titta_instance,currentPoint,posNorm,posPix,stage,event,callResult)
            % we don't need all the input arguments, so we ignore some

            if bitget(obj.logTypes,2)
                obj.log_to_cmd('received event: %s',event);
            end
            
        end

        function txt = getStatusText(obj,force)
            % return '!!clear_status' if you want to remove the status text
            
        end

        function draw(obj,wpnts,tick,sFac,offset)
            % wpnts: two window pointers. first is for participant screen,
            % second for operator
            % sFac and offset are used to scale from participant screen to
            % operator screen, in case they have different resolutions. So
            % always use them
            
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
            
        end
    end
end