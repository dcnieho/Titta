% TobiiMex is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

classdef TobiiMexDummyMode < TobiiMex
    properties (Access = protected, Hidden = true)
        isRecordingGaze = false;
    end
    
    methods
        % Use the name of your MEX file here
        function this = TobiiMexDummyMode(~)
            % construct default base class, none of its properties are
            % relevant when in dummy mode
            this = this@TobiiMex();
            
            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if 1
                thisInfo    = ?TobiiMexDummyMode;
                thisMethods = thisInfo.MethodList;
                superInfo   = ?TobiiMex;
                superMethods= superInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'TobiiMex'})) = [];
                thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TobiiMexDummyMode'})) = [];
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
                qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name}) & ~ismember({superMethods.Name},{'findAllEyeTrackers','startLogging','getLog','stopLogging'});
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
        function applyLicenses(~,~)
        end
        function clearLicenses(~)
        end
        
        %% calibration
        function enterCalibrationMode(~,~)
        end
        function leaveCalibrationMode(~,~)
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
            assert(nargin>1,'Titta::cpp::hasStream: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            supported   = checkValidStream(this,stream);
        end
        function success = start(this,stream,~,~)
            assert(nargin>1,'Titta::cpp::start: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            success = checkValidStream(this,stream);
            if strcmpi(stream,'gaze')
                this.isRecordingGaze = true;
            end
        end
        function status = isRecording(this,stream)
            assert(nargin>1,'Titta::cpp::isRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = checkValidStream(this,stream);
            status = false;
            if strcmpi(stream,'gaze')
                status = this.isRecordingGaze;
            end
        end
        function data = consumeN(this,stream,~,side)
            assert(nargin>1,'Titta::cpp::consumeN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = checkValidStream(this,stream);
            if nargin>3
                stream = checkValidBufferSide(this,side);
            end
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = consumeTimeRange(this,stream,~,~)
            assert(nargin>1,'Titta::cpp::consumeTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = checkValidStream(this,stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekN(this,stream,~,side)
            assert(nargin>1,'Titta::cpp::peekN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = checkValidStream(this,stream);
            if nargin>3
                stream = checkValidBufferSide(this,side);
            end
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekTimeRange(this,stream,~,~)
            assert(nargin>1,'Titta::cpp::peekTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = checkValidStream(this,stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function clear(this,stream)
            assert(nargin>1,'Titta::cpp::clear: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            checkValidStream(this,stream);
        end
        function clearTimeRange(this,stream,~,~)
            assert(nargin>1,'Titta::cpp::clearTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            checkValidStream(this,stream);
        end
        function success = stop(this,stream,~)
            assert(nargin>1,'Titta::cpp::stop: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
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
isValid = this.cppmethodGlobal('checkDataStream',ensureStringIsChar(stream));
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

[mx, my] = deal([]);
if isRecording
    [mx, my] = GetMouse();
end
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
ts = round(GetSecs*1000*1000);
gP = struct('onDisplayArea',[mx/rect(3); my/rect(4)],'inUserCoords',zeros(3,1),'valid',true);
pu = struct('diameter',0,'valid',false);
gO = struct('inUserCoords',zeros(3,1),'inTrackBoxCoords',zeros(3,1),'valid',false);
edat = struct('gazePoint',gP,'pupil',pu,'gazeOrigin',gO);
sample = struct('deviceTimeStamp',ts,'systemTimeStamp',ts,'left',edat,'right',edat);
end
