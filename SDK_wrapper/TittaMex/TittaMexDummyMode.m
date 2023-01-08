% TittaMex is part of Titta, a toolbox providing convenient access to
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

classdef TittaMexDummyMode < TittaMex
    properties (Access = protected, Hidden = true)
        isRecordingGaze = false;
        isInCalMode     = false;
    end

    methods
        % Use the name of your MEX file here
        function this = TittaMexDummyMode(~)
            % construct default base class, none of its properties are
            % relevant when in dummy mode
            this = this@TittaMex();

            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if ~ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5])  % check if we're running on Octave
                thisInfo    = ?TittaMexDummyMode;
                thisMethods = thisInfo.MethodList;
                superInfo   = ?TittaMex;
                superMethods= superInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'TittaMex'})) = [];
                thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TittaMexDummyMode'})) = [];
                % for methods of this dummy mode class, also remove methods
                % defined by superclass. and for both remove all those from
                % handle class
                definingClass = [thisMethods.DefiningClass];
                thisMethods(~strcmp({definingClass.Name},thisInfo.Name)) = [];
                definingClass = [superMethods.DefiningClass];
                superMethods(~strcmp({definingClass.Name},superInfo.Name)) = [];

                % now check for problems:
                % 1. any methods we define here that are not in superclass?
                notInSuper = ~ismember({thisMethods.Name},{superMethods.Name});
                if any(notInSuper)
                    fprintf('methods that are in %s but not in %s:\n',thisInfo.Name,superInfo.Name);
                    fprintf('  %s\n',thisMethods(notInSuper).Name);
                end

                % 2. methods from superclass that are not overridden.
                % filter out those methods that we on purpose do not define
                % in this subclass, as the superclass methods work fine
                % (call static functions in the mex)
                qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name}) & ~ismember({superMethods.Name},{'findAllEyeTrackers','startLogging','getLog','stopLogging','getAllBufferSidesString','getAllStreamsString'});
                if any(qNotOverridden)
                    fprintf('methods from %s not overridden in %s:\n',superInfo.Name,thisInfo.Name);
                    fprintf('  %s\n',superMethods(qNotOverridden).Name);
                end

                % 3. right number of input arguments?
                qMatchingInput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(superMethod)
                        qMatchingInput(p) = (length(superMethod.InputNames) == length(thisMethods(p).InputNames)) || (length(superMethod.InputNames) < length(thisMethods(p).InputNames) && strcmp(superMethod.InputNames{end},'varargin'));
                    else
                        qMatchingInput(p) = true;
                    end
                end
                if any(~qMatchingInput)
                    fprintf('methods in %s with wrong number of input arguments (mismatching %s):\n',thisInfo.Name,superInfo.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingInput).Name);
                end

                % 4. right number of output arguments?
                qMatchingOutput = false(size(thisMethods));
                for p=1:length(thisMethods)
                    superMethod = superMethods(strcmp({superMethods.Name},thisMethods(p).Name));
                    if isscalar(superMethod)
                        qMatchingOutput(p) = length(superMethod.OutputNames) == length(thisMethods(p).OutputNames);
                    else
                        qMatchingOutput(p) = true;
                    end
                end
                if any(~qMatchingOutput)
                    fprintf('methods in %s with wrong number of output arguments (mismatching %s):\n',thisInfo.Name,superInfo.Name);
                    fprintf('  %s\n',thisMethods(~qMatchingOutput).Name);
                end
            end
        end

        %% Matlab interface
        function init(~,~)
        end
        function delete(~)
        end

        %% global SDK functions
        % no need to override any

        %% eye-tracker specific getters and setters
        % getters
        function eyeTracker = getEyeTrackerInfo(~)
            eyeTracker = [];
        end
        function trackBox = getTrackBox(~)
            trackBox = [];
        end
        function displayArea = getDisplayArea(~)
            displayArea = [];
        end
        % setters
        % properties only, so nothing to override
        % modifiers
        function applyResults = applyLicenses(~,~)
            applyResults = [];
        end
        function clearLicenses(~)
        end

        %% calibration
        function hasEnqueuedEnter = enterCalibrationMode(this,~)
            this.isInCalMode    = true;
            hasEnqueuedEnter    = true;
        end
        function isInCalibrationMode = isInCalibrationMode(this,~)
            isInCalibrationMode = this.isInCalMode;
        end
        function hasEnqueuedLeave = leaveCalibrationMode(this,~)
            this.isInCalMode    = true;
            hasEnqueuedLeave    = true;
        end
        function calibrationCollectData(~,~,~)
        end
        function calibrationDiscardData(~,~,~)
        end
        function calibrationComputeAndApply(~)
        end
        function calibrationGetData(~)
        end
        function calibrationApplyData(~,~)
        end
        function status = calibrationGetStatus(~)
            status = '';
        end
        function result = calibrationRetrieveResult(~)
            result = struct();
        end

        %% data streams
        function supported = hasStream(this,stream)
            if nargin<2
                error('TittaMex::hasStream: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            supported   = checkValidStream(this,stream);
        end
        function prevEyeOpennessState = setIncludeEyeOpennessInGaze(~,~)
            prevEyeOpennessState = false;
        end
        function success = start(this,stream,~,~)
            if nargin<2
                error('TittaMex::start: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            success = checkValidStream(this,stream);
            if strcmpi(stream,'gaze')
                this.isRecordingGaze = true;
            end
        end
        function status = isRecording(this,stream)
            if nargin<2
                error('TittaMex::isRecording: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            status = false;
            if strcmpi(stream,'gaze')
                status = this.isRecordingGaze;
            end
        end
        function data = consumeN(this,stream,~,side)
            if nargin<2
                error('TittaMex::consumeN: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            if nargin>3
                stream = checkValidBufferSide(this,side);
            end
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = consumeTimeRange(this,stream,~,~)
            if nargin<2
                error('TittaMex::consumeTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekN(this,stream,~,side)
            if nargin<2
                error('TittaMex::peekN: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            if nargin>3
                stream = checkValidBufferSide(this,side);
            end
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekTimeRange(this,stream,~,~)
            if nargin<2
                error('TittaMex::peekTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function clear(this,stream)
            if nargin<2
                error('TittaMex::clear: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
        end
        function clearTimeRange(this,stream,~,~)
            if nargin<2
                error('TittaMex::clearTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            checkValidStream(this,stream);
        end
        function success = stop(this,stream,~)
            if nargin<2
                error('TittaMex::stop: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            success = checkValidStream(this,stream);
            if strcmpi(stream,'gaze')
                this.isRecordingGaze = false;
            end
        end
    end
end


% helpers
function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
end
end

function isValid = checkValidStream(this,stream)
isValid = this.cppmethodGlobal('checkStream',ensureStringIsChar(stream));
end
function isValid = checkValidBufferSide(this,side)
isValid = this.cppmethodGlobal('checkBufferSide',ensureStringIsChar(side));
end

function sample = getMouseSample(isRecording)
% figure out mouse to screen mapping
persistent rects;
if isempty(rects)
    scrs    = Screen('Screens');
    for p=length(scrs):-1:1
        rects(p,:) = Screen('GlobalRect',scrs(p));
    end
    if ~isscalar(scrs)
        rects(1,:) = [];
    end
end

if isRecording
    [mx, my] = GetMouse();
    if size(rects,1)>1
        qRect = inRect([mx my].',rects.');
        rect = rects(qRect,:);

        % translate to local rect
        mx  = mx-rect(1);
        my  = my-rect(2);
        rect= OffsetRect(rect,-rect(1),-rect(2));
    else
        rect = rects;
    end
    % put into fake SampleStruct
    ts = int64(GetSecs*1000*1000);
    gP = struct('onDisplayArea',[mx/rect(3); my/rect(4)],'inUserCoords',zeros(3,1),'valid',true,'available',true);
    pu = struct('diameter',0,'valid',false,'available',true);   % also good for eye openness, has the same fields
    gO = struct('inUserCoords',zeros(3,1),'inTrackBoxCoords',zeros(3,1),'valid',false,'available',true);
    edat = struct('gazePoint',gP,'pupil',pu,'eyeOpenness',pu,'gazeOrigin',gO);
    sample = struct('deviceTimeStamp',ts,'systemTimeStamp',ts,'left',edat,'right',edat);
else
    % put into fake SampleStruct
    gP = struct('onDisplayArea',zeros(2,0),'inUserCoords',zeros(3,0),'valid',isRecording,'available',false);
    pu = struct('diameter',[],'valid',false,'available',false);  % also good for eye openness, has the same fields
    gO = struct('inUserCoords',zeros(3,0),'inTrackBoxCoords',zeros(3,0),'valid',false,'available',false);
    edat = struct('gazePoint',gP,'pupil',pu,'eyeOpenness',pu,'gazeOrigin',gO);
    sample = struct('deviceTimeStamp',[],'systemTimeStamp',[],'left',edat,'right',edat);
end
end
