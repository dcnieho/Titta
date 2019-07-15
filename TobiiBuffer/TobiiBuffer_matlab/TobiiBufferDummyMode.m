classdef TobiiBufferDummyMode < TobiiBuffer
    properties (Access = protected, Hidden = true)
        isRecordingGaze = false;
    end
    
    methods
        % Use the name of your MEX file here
        function this = TobiiBufferDummyMode(~)
            % construct default base class, none of its properties are
            % relevant when in dummy mode
            this = this@TobiiBuffer();
            
            % check we overwrite all public methods (for developer, to make
            % sure we override all accessible baseclass calls with no-ops)
            if 1
                thisInfo    = ?TobiiBufferDummyMode;
                thisMethods = thisInfo.MethodList;
                superInfo   = ?TobiiBuffer;
                superMethods= superInfo.MethodList;
                % for both, remove their constructors from list and limit
                % to only public methods
                superMethods(~strcmp({superMethods.Access},'public') | (~~[superMethods.Static]) | ismember({superMethods.Name},{'TobiiBuffer'})) = [];
                thisMethods (~strcmp( {thisMethods.Access},'public') | (~~ [thisMethods.Static]) | ismember( {thisMethods.Name},{'TobiiBufferDummyMode'})) = [];
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
                
                % 2. methods from superclas that are not overridden.
                qNotOverridden = ~ismember({superMethods.Name},{thisMethods.Name});
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
        
        function delete(~)
        end
        
        function init(~,~)
        end
        
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
            status = [];
        end
        function result = calibrationRetrieveResult(~)
            result = [];
        end
        
        function supported = hasStream(~,stream)
            assert(nargin>1,'Titta::buffer::hasStream: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            supported   = checkValidStream(ensureStringIsChar(stream));
        end
        function success = start(this,stream,~,~)
            assert(nargin>1,'Titta::buffer::start: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            success = checkValidStream(ensureStringIsChar(stream));
            if strcmpi(stream,'gaze')
                this.isRecordingGaze = true;
            end
        end
        function success = stop(this,stream,~)
            assert(nargin>1,'Titta::buffer::stop: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            success = checkValidStream(ensureStringIsChar(stream));
            if strcmpi(stream,'gaze')
                this.isRecordingGaze = false;
            end
        end
        function status = isRecording(this,stream)
            assert(nargin>1,'Titta::buffer::isRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            status = false;
            if strcmpi(stream,'gaze')
                status = this.isRecordingGaze;
            end
        end
        function clear(~,~)
            assert(nargin>1,'Titta::buffer::clear: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
        end
        function clearTimeRange(~,~,~,~)
        end
        function data = consumeN(this,stream,~)
            assert(nargin>1,'Titta::buffer::consumeN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = consumeTimeRange(this,stream,~,~)
            assert(nargin>1,'Titta::buffer::consumeTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekN(this,stream,~)
            assert(nargin>1,'Titta::buffer::peekN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        function data = peekTimeRange(this,stream,~,~)
            assert(nargin>1,'Titta::buffer::peekTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            data = [];
            if strcmpi(stream,'gaze')
                data = getMouseSample(this.isRecordingGaze);
            end
        end
        
        
        function success = startLogging(~,~)
            success = true;
        end
        function data = getLog(~,~)
            data = [];
        end
        function stopLogging(~)
        end
    end
end


% helpers
function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
end
end

function isValid = checkValidStream(stream)
isValid = ismember(stream,{'gaze','eyeImage', 'externalSignal','timeSync'});
end

function sample = getMouseSample(isRecording)
[mx, my] = deal([]);
if isRecording
    [mx, my] = GetMouse();
end
rect = Screen('Rect',0);
% put into fake SampleStruct
ts = round(GetSecs*1000*1000);
gP = struct('onDisplayArea',[mx/rect(3); my/rect(4)],'inUserCoords',zeros(3,1),'valid',true);
pu = struct('diameter',0,'valid',false);
gO = struct('inUserCoords',zeros(3,1),'inTrackBoxCoords',zeros(3,1),'valid',false);
edat = struct('gazePoint',gP,'pupil',pu,'gazeOrigin',gO);
sample = struct('deviceTimeStamp',ts,'systemTimeStamp',ts,'left',edat,'right',edat);
end