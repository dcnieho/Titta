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

classdef TittaMex < handle
    properties (GetAccess = private, SetAccess = private, Hidden = true, Transient = true)
        instanceHandle;         % integer handle to a class instance in MEX function
    end
    properties (GetAccess = protected, SetAccess = private, Hidden = false)
        mexClassWrapperFnc;     % the MEX function owning the class instances
    end
    properties (Dependent, SetAccess=private)
        SDKVersion
        systemTimestamp
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
    
    methods (Static = true, Access = protected)
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
                    error('TittaMex:invalidMEXFunction','Failed to load or call MEX file: "%s".',mexFnc)
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
                    error('TittaMex:invalidMEXFunction','Invalid MEX file "%s" for function %s.',funInfo.file,funInfo.function);
                end
            end
        end
    end
    
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('TittaMex:invalidHandle','No class handle. Did you call init yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
    end
    
    methods
        % Use the name of your MEX file here
        function this = TittaMex(debugMode)
            % debugmode is for developer of TittaMex only, no use for
            % end users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                mexFnc = 'TittaMex_d';
            else
                mexFnc = 'TittaMex_';
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
        function SDKVersion = get.SDKVersion(this)
            SDKVersion = this.cppmethodGlobal('getSDKVersion');
        end
        function systemTimestamp = get.systemTimestamp(this)
            systemTimestamp = this.cppmethodGlobal('getSystemTimestamp');
        end
        function eyeTrackerList = findAllEyeTrackers(this)
            eyeTrackerList = this.cppmethodGlobal('findAllEyeTrackers');
        end
        function eyeTracker = getEyeTrackerFromAddress(this,address)
            eyeTracker = this.cppmethodGlobal('getEyeTrackerFromAddress',ensureStringIsChar(address));
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
        % stream info
        function streams = getAllStreamsString(this,quoteChar,snakeCase)
            if nargin>2
                streams = this.cppmethodGlobal('getAllStreamsString',ensureStringIsChar(quoteChar),logical(snakeCase));
            elseif nargin>1
                streams = this.cppmethodGlobal('getAllStreamsString',ensureStringIsChar(quoteChar));
            else
                streams = this.cppmethodGlobal('getAllStreamsString');
            end
        end
        function bufferSides = getAllBufferSidesString(this,quoteChar)
            if nargin>1
                bufferSides = this.cppmethodGlobal('getAllBufferSidesString',ensureStringIsChar(quoteChar));
            else
                bufferSides = this.cppmethodGlobal('getAllBufferSidesString');
            end
        end
        
        %% eye-tracker specific getters and setters
        % getters
        function eyeTracker = getEyeTrackerInfo(this)
            eyeTracker = struct();
            if ~isempty(this.instanceHandle)
                eyeTracker = this.cppmethod('getEyeTrackerInfo');
            end
        end
        function deviceName = get.deviceName(this)
            deviceName = '';
            if ~isempty(this.instanceHandle)
                deviceName = this.cppmethod('getDeviceName');
            end
        end
        function serialNumber = get.serialNumber(this)
            serialNumber = '';
            if ~isempty(this.instanceHandle)
                serialNumber = this.cppmethod('getSerialNumber');
            end
        end
        function model = get.model(this)
            model = '';
            if ~isempty(this.instanceHandle)
                model = this.cppmethod('getModel');
            end
        end
        function firmwareVersion = get.firmwareVersion(this)
            firmwareVersion = '';
            if ~isempty(this.instanceHandle)
                firmwareVersion = this.cppmethod('getFirmwareVersion');
            end
        end
        function runtimeVersion = get.runtimeVersion(this)
            runtimeVersion = '';
            if ~isempty(this.instanceHandle)
                runtimeVersion = this.cppmethod('getRuntimeVersion');
            end
        end
        function address = get.address(this)
            address = '';
            if ~isempty(this.instanceHandle)
                address = this.cppmethod('getAddress');
            end
        end
        function capabilities = get.capabilities(this)
            capabilities = {};
            if ~isempty(this.instanceHandle)
                capabilities = this.cppmethod('getCapabilities');
            end
        end
        function supportedFrequencies = get.supportedFrequencies(this)
            supportedFrequencies = [];
            if ~isempty(this.instanceHandle)
                supportedFrequencies = this.cppmethod('getSupportedFrequencies');
            end
        end
        function supportedModes = get.supportedModes(this)
            supportedModes = {};
            if ~isempty(this.instanceHandle)
                supportedModes = this.cppmethod('getSupportedModes');
            end
        end
        function frequency = get.frequency(this)
            frequency = [];
            if ~isempty(this.instanceHandle)
                frequency = this.cppmethod('getFrequency');
            end
        end
        function trackingMode = get.trackingMode(this)
            trackingMode = '';
            if ~isempty(this.instanceHandle)
                trackingMode = this.cppmethod('getTrackingMode');
            end
        end
        function trackBox = getTrackBox(this)
            trackBox = this.cppmethod('getTrackBox');
        end
        function displayArea = getDisplayArea(this)
            displayArea = this.cppmethod('getDisplayArea');
        end
        % setters
        function set.deviceName(this,deviceName)
            if ~isempty(this.instanceHandle)
                assert(nargin>1,'TittaMex::setDisplayName: provide device name argument.');
                deviceName = ensureStringIsChar(deviceName);
                this.cppmethod('setDeviceName',deviceName);
            end
        end
        function set.frequency(this,frequency)
            if ~isempty(this.instanceHandle)
                assert(nargin>1,'TittaMex::setFrequency: provide frequency argument.');
                this.cppmethod('setFrequency',double(frequency));
            end
        end
        function set.trackingMode(this,trackingMode)
            if ~isempty(this.instanceHandle)
                assert(nargin>1,'TittaMex::setTrackingMode: provide tracking mode argument.');
                trackingMode = ensureStringIsChar(trackingMode);
                this.cppmethod('setTrackingMode',trackingMode);
            end
        end
        % modifiers
        function applyResults = applyLicenses(this,licenses)
            assert(nargin>1,'TittaMex::applyLicenses: provide licenses argument.');
            if ~iscell(licenses)
                licenses = {licenses};
            end
            classes = cellfun(@class,licenses,'uni',false);
            assert(all(ismember(classes,{'char','uint8'})),'TittaMex::applyLicenses: the provided licenses should have ''char'' or ''uint8'' type')
            % convert all to uint8 to make C++-side simpler (not sure if
            % absolutely safe to just use uint8 there in all cases)
            licenses = cellfun(@uint8,licenses,'uni',false);
            applyResults = this.cppmethod('applyLicenses',licenses);
        end
        function clearLicenses(this)
            this.cppmethod('clearLicenses');
        end
        
        %% calibration
        function hasEnqueuedEnter = enterCalibrationMode(this,doMonocular)
            hasEnqueuedEnter = this.cppmethod('enterCalibrationMode',doMonocular);
        end
        function isInCalibrationMode = isInCalibrationMode(this,throwErrorIfNot)
            if nargin>1 && ~isempty(throwErrorIfNot)
                isInCalibrationMode = this.cppmethod('isInCalibrationMode',throwErrorIfNot);
            else
                isInCalibrationMode = this.cppmethod('isInCalibrationMode');
            end
        end
        function hasEnqueuedLeave = leaveCalibrationMode(this,force)
            if nargin>1 && ~isempty(force)
                hasEnqueuedLeave = this.cppmethod('leaveCalibrationMode',force);
            else
                hasEnqueuedLeave = this.cppmethod('leaveCalibrationMode');
            end
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
        function calibrationApplyData(this,calibrationData)
            this.cppmethod('calibrationApplyData',calibrationData);
        end
        function status = calibrationGetStatus(this)
            status = this.cppmethod('calibrationGetStatus');
        end
        function result = calibrationRetrieveResult(this)
            result = this.cppmethod('calibrationRetrieveResult');
        end
        
        %% data streams
        function supported = hasStream(this,stream)
            if nargin<2
                error('TittaMex::hasStream: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            supported = this.cppmethod('hasStream',ensureStringIsChar(stream));
        end
        function prevEyeOpennessState = setIncludeEyeOpennessInGaze(this,include)
            prevEyeOpennessState = this.cppmethod('setIncludeEyeOpennessInGaze',include);
        end
        function success = start(this,stream,initialBufferSize,asGif)
            % optional buffer size input, and optional input to request
            % gif-encoded instead of raw images
            if nargin<2
                error('TittaMex::start: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            if nargin<2
                error('TittaMex::isRecording: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            status = this.cppmethod('isRecording',ensureStringIsChar(stream));
        end
        function data = consumeN(this,stream,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: all
            % -  side: Which side of buffer to consume samples from.
            %          Values: 'start' or 'end'
            %          Default: 'start'
            if nargin<2
                error('TittaMex::consumeN: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            if nargin<2
                error('TittaMex::consumeTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            %          Values: 'start' or 'end'
            %          Default: 'end'
            if nargin<2
                error('TittaMex::peekN: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            if nargin<2
                error('TittaMex::peekTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            if nargin<2
                error('TittaMex::clear: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            this.cppmethod('clear',ensureStringIsChar(stream));
        end
        function clearTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole buffer
            if nargin<2
                error('TittaMex::clearTimeRange: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
            if nargin<2
                error('TittaMex::stop: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
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
