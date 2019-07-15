% TobiiBuffer is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

classdef TobiiBuffer < handle
    properties (GetAccess = private, SetAccess = private, Hidden = true, Transient = true)
        instanceHandle;         % integer handle to a class instance in MEX function
    end
    properties (GetAccess = protected, SetAccess = immutable, Hidden = false)
        mexClassWrapperFnc;     % the MEX function owning the class instances
    end
    
    methods (Static = true)
        function mexFnc = checkMEXFnc(mexFnc)
            % Input function_handle or name, return valid handle or error
            
            % accept string or function_handle
            if ischar(mexFnc)
                mexFnc = str2func(mexFnc);
            end
            
            % validate MEX-file function handle
            % http://stackoverflow.com/a/19307825/2778484
            funInfo = functions(mexFnc);
            if exist(funInfo.file,'file') ~= 3  % status 3 is MEX-file
                error('TobiiBuffer:invalidMEXFunction','Invalid MEX file: "%s".',funInfo.file);
            end
        end
    end
    
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('TobiiBuffer:invalidHandle','No class handle. Did you call init yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
    end
    
    methods
        % Use the name of your MEX file here
        function this = TobiiBuffer(debugMode)
            % debugmode is for developer of SMIbuffer only, no use for end
            % users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                mexFnc = 'TobiiBuffer_matlab_d';
            else
                mexFnc = 'TobiiBuffer_matlab';
            end
            
            % construct C++ class instance
            this.mexClassWrapperFnc = this.checkMEXFnc(mexFnc);
            
            % call no-op to load the mex file, so we fail early when load
            % fails
            this.cppmethodGlobal('touch');
        end
        
        function delete(this)
            if ~isempty(this.instanceHandle)
                this.cppmethod('delete');
                this.instanceHandle     = [];
            end
        end
        
        function init(this,address)
            address = ensureStringIsChar(address);
            this.instanceHandle = this.cppmethodGlobal('new',address);
        end
        
        function enterCalibrationMode(this,doMonocular)
            this.cppmethod('enterCalibrationMode',doMonocular);
        end
        function leaveCalibrationMode(this,force)
            if nargin<2
                force = false;
            end
            this.cppmethod('leaveCalibrationMode',force);
        end
        function calibrationCollectData(this,coordinates,eye)
            if nargin>2 && ~isempty(eye)
                this.cppmethod('calibrationCollectData',coordinates,ensureStringIsChar(eye));
            else
                this.cppmethod('calibrationCollectData',coordinates);
            end
        end
        function calibrationDiscardData(this,coordinates,eye)
            if nargin>2 && ~isempty(eye)
                this.cppmethod('calibrationDiscardData',coordinates,ensureStringIsChar(eye));
            else
                this.cppmethod('calibrationDiscardData',coordinates);
            end
        end
        function calibrationComputeAndApply(this)
            this.cppmethod('calibrationComputeAndApply');
        end
        function calibrationGetData(this)
            this.cppmethod('calibrationGetData');
        end
        function calibrationApplyData(this,cal)
            this.cppmethod('calibrationApplyData',cal);
        end
        function status = calibrationGetStatus(this)
            status = this.cppmethod('calibrationGetStatus');
        end
        function result = calibrationRetrieveResult(this)
            result = this.cppmethod('calibrationRetrieveResult');
        end
        
        function supported = hasStream(this,stream)
            assert(nargin>1,'Titta::buffer::hasStream: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            supported = this.cppmethod('hasStream',ensureStringIsChar(stream));
        end
        function success = start(this,stream,initialBufferSize,asGif)
            % optional buffer size input, and optional input to request
            % gif-encoded instead of raw images
            assert(nargin>1,'Titta::buffer::start: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(asGif)
                success = this.cppmethod('start',stream,uint64(initialBufferSize),logical(asGif));
            elseif nargin>2 && ~isempty(initialBufferSize)
                success = this.cppmethod('start',stream,uint64(initialBufferSize));
            else
                success = this.cppmethod('start',stream);
            end
        end
        function success = stop(this,stream,doClearBuffer)
            % optional boolean input indicating whether buffer should be
            % cleared out
            assert(nargin>1,'Titta::buffer::stop: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(doClearBuffer)
                success = this.cppmethod('stop',stream,logical(doClearBuffer));
            else
                success = this.cppmethod('stop',stream);
            end
        end
        function status = isRecording(this,stream)
            assert(nargin>1,'Titta::buffer::isRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            status = this.cppmethod('isBuffering',ensureStringIsChar(stream));
        end
        function clear(this,stream)
            assert(nargin>1,'Titta::buffer::clear: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            this.cppmethod('clear',ensureStringIsChar(stream));
        end
        function clearTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole buffer
            assert(nargin>1,'Titta::buffer::clearTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                this.cppmethod('clearTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                this.cppmethod('clearTimeRange',stream,int64(startT));
            else
                this.cppmethod('clearTimeRange',stream);
            end
        end
        function data = consumeN(this,stream,firstN)
            % optional input argument firstN: how many samples to consume
            % from start. Default: all
            assert(nargin>1,'Titta::buffer::consumeN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(firstN)
                data = this.cppmethod('consumeN',stream,uint64(firstN));
            else
                data = this.cppmethod('consumeN',stream);
            end
        end
        function data = consumeTimeRange(this,stream,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            assert(nargin>1,'Titta::buffer::consumeTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT));
            else
                data = this.cppmethod('consumeTimeRange',stream);
            end
        end
        function data = peekN(this,stream,lastN)
            % optional input argument lastN: how many samples to peek from
            % end. Default: 1. To get all, ask for -1 samples
            assert(nargin>1,'Titta::buffer::peekN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(lastN)
                data = this.cppmethod('peekN',stream,uint64(lastN));
            else
                data = this.cppmethod('peekN',stream);
            end
        end
        function data = peekTimeRange(this,stream,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            assert(nargin>1,'Titta::buffer::peekTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('peekTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('peekTimeRange',stream,int64(startT));
            else
                data = this.cppmethod('peekTimeRange',stream);
            end
        end
        
        
        function success = startLogging(this,initialBufferSize)
            % optional buffer size input
            if nargin>1 && ~isempty(initialBufferSize)
                success = this.cppmethodGlobal('startLogging',uint64(initialBufferSize));
            else
                success = this.cppmethodGlobal('startLogging');
            end
        end
        function data = getLog(this,clearLogBuffer)
            % optional clear buffer input
            if nargin>1 && ~isempty(clearLogBuffer)
                data = this.cppmethodGlobal('getLog',clearLogBuffer);
            else
                data = this.cppmethodGlobal('getLog');
            end
            data = [data{:}];
        end
        function stopLogging(this)
            this.cppmethodGlobal('stopLogging');
        end
    end
end


% helpers
function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
end
end
