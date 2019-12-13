% TobiiMex is part of Titta, a toolbox providing convenient access to
% eye tracking functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nyström, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

classdef TobiiMex < handle
    properties (GetAccess = private, SetAccess = private, Hidden = true, Transient = true)
        instanceHandle;         % integer handle to a class instance in MEX function
    end
    properties (GetAccess = protected, SetAccess = private, Hidden = false)
        % should be 'SetAccess = immutable', but Octave does not support it
        mexClassWrapperFnc;     % the MEX function owning the class instances
    end
    properties (Dependent, SetAccess=private)
        serialNumber
        model
        firmwareVersion
        runtimeVersion
        address
        capabilities
        supportedFrequencies
        supportedModes
    end
    properties (Dependent)
        deviceName
        frequency
        trackingMode
    end
    
    methods (Static = true)
        function mexFnc = checkMEXFnc(mexFnc)
            % Input function_handle or name, return valid handle or error
            isOctave = ismember(exist('OCTAVE_VERSION', 'builtin'), [102, 5]);
            
            if isOctave
                try
                    % accept string or function_handle
                    if ischar(mexFnc)
                        mexFnc = str2func(mexFnc);
                    end
                    mexFnc('touch')
                catch me
                    if isa(mexFnc,'function_handle')
                        mexFnc = func2str(mexFnc);
                    end
                    error('TobiiMex:invalidMEXFunction','Failed to load or call MEX file: "%s".',mexFnc)
                end
            else
                % accept string or function_handle
                if ischar(mexFnc)
                    mexFnc = str2func(mexFnc);
                end
                % validate MEX-file function handle
                % http://stackoverflow.com/a/19307825/2778484
                funInfo = functions(mexFnc);
                if exist(funInfo.file,'file') ~= 3  % status 3 is MEX-file
                    error('TobiiMex:invalidMEXFunction','Invalid MEX file: "%s".',funInfo.file);
                end
            end
        end
    end
    
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('TobiiMex:invalidHandle','No class handle. Did you call init yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
    end
    
    methods
        % Use the name of your MEX file here
        function this = TobiiMex(debugMode)
            % debugmode is for developer of TobiiMex only, no use for
            % end users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                mexFnc = 'TobiiMex_matlab_d';
            else
                mexFnc = 'TobiiMex_matlab';
            end
            
            % construct C++ class instance
            this.mexClassWrapperFnc = this.checkMEXFnc(mexFnc);
            
            % call no-op to load the mex file, so we fail early when load
            % fails
            this.cppmethodGlobal('touch');
        end
        
        %% Matlab interface
        function init(this,address)
            address = ensureStringIsChar(address);
            this.instanceHandle = this.cppmethodGlobal('new',address);
        end
        function delete(this)
            if ~isempty(this.mexClassWrapperFnc)
                this.stopLogging();
            end
            if ~isempty(this.instanceHandle)
                this.cppmethod('delete');
                this.instanceHandle = [];
            end
        end
        
        %% global SDK functions
        function SDKVersion = getSDKVersion(this)
            SDKVersion = this.cppmethodGlobal('getSDKVersion');
        end
        function systemTimestamp = getSystemTimestamp(this)
            systemTimestamp = this.cppmethodGlobal('getSystemTimestamp');
        end
        function eyeTrackerList = findAllEyeTrackers(this)
            eyeTrackerList = this.cppmethodGlobal('findAllEyeTrackers');
        end
        % logging
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
        
        %% eye-tracker specific getters and setters
        % getters
        function eyeTracker = getEyeTrackerInfo(this)
            eyeTracker = this.cppmethod('getEyeTrackerInfo');
        end
        function frequency = get.deviceName(this)
            frequency = this.cppmethod('getDeviceName');
        end
        function serialNumber = get.serialNumber(this)
            serialNumber = this.cppmethod('getSerialNumber');
        end
        function model = get.model(this)
            model = this.cppmethod('getModel');
        end
        function firmwareVersion = get.firmwareVersion(this)
            firmwareVersion = this.cppmethod('getFirmwareVersion');
        end
        function runtimeVersion = get.runtimeVersion(this)
            runtimeVersion = this.cppmethod('getRuntimeVersion');
        end
        function address = get.address(this)
            address = this.cppmethod('getAddress');
        end
        function capabilities = get.capabilities(this)
            capabilities = this.cppmethod('getCapabilities');
        end
        function supportedFrequencies = get.supportedFrequencies(this)
            supportedFrequencies = this.cppmethod('getSupportedFrequencies');
        end
        function supportedModes = get.supportedModes(this)
            supportedModes = this.cppmethod('getSupportedModes');
        end
        function frequency = get.frequency(this)
            frequency = this.cppmethod('getFrequency');
        end
        function trackingMode = get.trackingMode(this)
            trackingMode = this.cppmethod('getTrackingMode');
        end
        function trackBox = getTrackBox(this)
            trackBox = this.cppmethod('getTrackBox');
        end
        function displayArea = getDisplayArea(this)
            displayArea = this.cppmethod('getDisplayArea');
        end
        % setters
        function set.deviceName(this,deviceName)
            assert(nargin>1,'TobiiMex::setDisplayName: provide device name argument.');
            deviceName = ensureStringIsChar(deviceName);
            this.cppmethod('setDeviceName',deviceName);
        end
        function set.frequency(this,frequency)
            assert(nargin>1,'TobiiMex::setFrequency: provide frequency argument.');
            this.cppmethod('setFrequency',single(frequency));
        end
        function set.trackingMode(this,trackingMode)
            assert(nargin>1,'TobiiMex::setTrackingMode: provide tracking mode argument.');
            trackingMode = ensureStringIsChar(trackingMode);
            this.cppmethod('setTrackingMode',trackingMode);
        end
        % modifiers
        function applyLicenses(this,licenses)
            assert(nargin>1,'TobiiMex::applyLicenses: provide licenses argument.');
            if ~iscell(licenses)
                licenses = {licenses};
            end
            classes = cellfun(@class,licenses,'uni',false);
            assert(all(ismember(classes,{'char','uint8'})),'TobiiMex::applyLicenses: the provided licenses should have ''char'' or ''uint8'' type')
            % convert all to uint8 to make C++-side simpler (not sure if
            % absolutely safe to just use uint8 there in all cases)
            licenses = cellfun(@uint8,licenses,'uni',false);
            this.cppmethod('applyLicenses',licenses);
        end
        function clearLicenses(this)
            this.cppmethod('clearLicenses');
        end
        
        %% calibration
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
        
        %% data streams
        function supported = hasStream(this,stream)
            assert(nargin>1,'TobiiMex::hasStream: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            supported = this.cppmethod('hasStream',ensureStringIsChar(stream));
        end
        function success = start(this,stream,initialBufferSize,asGif)
            % optional buffer size input, and optional input to request
            % gif-encoded instead of raw images
            assert(nargin>1,'TobiiMex::start: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(asGif)
                success = this.cppmethod('start',stream,uint64(initialBufferSize),logical(asGif));
            elseif nargin>2 && ~isempty(initialBufferSize)
                success = this.cppmethod('start',stream,uint64(initialBufferSize));
            else
                success = this.cppmethod('start',stream);
            end
        end
        function status = isRecording(this,stream)
            assert(nargin>1,'TobiiMex::isRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            status = this.cppmethod('isRecording',ensureStringIsChar(stream));
        end
        function data = consumeN(this,stream,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: all
            % -  side: Which side of buffer to consume samples from.
            %          Default: start
            assert(nargin>1,'TobiiMex::consumeN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(side)
                data = this.cppmethod('consumeN',stream,uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>2 && ~isempty(NSamp)
                data = this.cppmethod('consumeN',stream,uint64(NSamp));
            else
                data = this.cppmethod('consumeN',stream);
            end
        end
        function data = consumeTimeRange(this,stream,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            assert(nargin>1,'TobiiMex::consumeTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT));
            else
                data = this.cppmethod('consumeTimeRange',stream);
            end
        end
        function data = peekN(this,stream,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: 1. To get all,
            %          ask for inf samples
            % -  side: Which side of buffer to consume samples from.
            %          Default: end
            assert(nargin>1,'TobiiMex::peekN: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(side)
                data = this.cppmethod('peekN',stream,uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>2 && ~isempty(NSamp)
                data = this.cppmethod('peekN',stream,uint64(NSamp));
            else
                data = this.cppmethod('peekN',stream);
            end
        end
        function data = peekTimeRange(this,stream,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            assert(nargin>1,'TobiiMex::peekTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('peekTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('peekTimeRange',stream,int64(startT));
            else
                data = this.cppmethod('peekTimeRange',stream);
            end
        end
        function clear(this,stream)
            assert(nargin>1,'TobiiMex::clear: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            this.cppmethod('clear',ensureStringIsChar(stream));
        end
        function clearTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole buffer
            assert(nargin>1,'TobiiMex::clearTimeRange: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            stream = ensureStringIsChar(stream);
            if nargin>3 && ~isempty(endT)
                this.cppmethod('clearTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                this.cppmethod('clearTimeRange',stream,int64(startT));
            else
                this.cppmethod('clearTimeRange',stream);
            end
        end
        function success = stop(this,stream,doClearBuffer)
            % optional boolean input indicating whether buffer should be
            % cleared out
            assert(nargin>1,'TobiiMex::stop: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal", "timeSync" and "positioning"');
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(doClearBuffer)
                success = this.cppmethod('stop',stream,logical(doClearBuffer));
            else
                success = this.cppmethod('stop',stream);
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
