% LSLMex is part of Titta, a toolbox providing convenient access to
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

classdef LSLMex < handle
    properties (GetAccess = private, SetAccess = private, Hidden = true, Transient = true)
        instanceHandle;         % integer handle to a class instance in MEX function
    end
    properties (GetAccess = protected, SetAccess = private, Hidden = false)
        mexClassWrapperFnc;     % the MEX function owning the class instances
    end
    properties (Dependent, SetAccess=private)
        TobiiSDKVersion
        LSLVersion
    end
    
    methods (Static = true, Access = protected)
        function mexFnc = checkMEXFnc(mexFnc)
            % Input function_handle or name, return valid handle or error
            if ischar(mexFnc)
                mexFnc = str2func(mexFnc);
            end
            % validate MEX-file function handle
            % http://stackoverflow.com/a/19307825/2778484
            funInfo = functions(mexFnc);
            if exist(funInfo.file,'file') ~= 3  % status 3 is MEX-file
                error('LSLMex:invalidMEXFunction','Invalid MEX file "%s" for function %s.',funInfo.file,funInfo.function);
            end
        end
    end
    
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('LSLMex:invalidHandle','No class handle. Did you call init yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
    end
    
    methods
        %% Matlab interface
        function this = LSLMex(debugMode)
            % debugmode is for developer of LSLMex only, no use for
            % end users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                mexFnc = 'LSLMex_d';
            else
                mexFnc = 'LSLMex_';
            end
            
            % construct C++ class instance
            this.mexClassWrapperFnc = this.checkMEXFnc(mexFnc);
            
            % call no-op to load the mex file, so we fail early when load
            % fails
            this.cppmethodGlobal('touch');
            this.instanceHandle = this.cppmethodGlobal('new');
        end
        
        function delete(this)
            if ~isempty(this.mexClassWrapperFnc)
            end
            if ~isempty(this.instanceHandle)
                this.cppmethod('delete');
                this.instanceHandle = [];
            end
        end
        
        %% global/static SDK functions (not static here, still need an instance of the MEX file)
        function SDKVersion = get.TobiiSDKVersion(this)
            SDKVersion = this.cppmethodGlobal('getTobiiSDKVersion');
        end
        function LSLVersion = get.LSLVersion(this)
            LSLVersion = this.cppmethodGlobal('getLSLVersion');
        end
        function streamInfos = getRemoteStreams(this, streamType)
            if nargin>1
                streamInfos = this.cppmethodGlobal('getRemoteStreams',ensureStringIsChar(streamType));
            else
                streamInfos = this.cppmethodGlobal('getRemoteStreams');
            end
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

        %% outlets
        function connect(this,addressOrInstance)
            % only needed when you want to stream _from_ an eye tracker,
            % not when you want to receive remote streams.
            % addressOrInstance can be an address of a Tobii eye tracker to
            % connect to or a Titta or TittaMex instance that is connected
            % to the eye tracker you want to stream from
            if isa(str,'Titta')
                assert(~isempty(addressOrInstance.buffer),'Can''t get the connected eye tracker: you passed a Titta instance, but this instance was not yet initialized and is thus not connected to an eye tracker.')
                address = addressOrInstance.buffer.address;
            elseif isa(addressOrInstance,'TittaMex')
                address = addressOrInstance.address;
            end
            address = ensureStringIsChar(address);
            this.instanceHandle = this.cppmethodGlobal('new',address);
        end
        function success = startOutlet(this,stream,asGif)
            % optional buffer size input, and optional input to request
            % gif-encoded instead of raw images
            if nargin<2
                error('LSLMex::startOutlet: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(asGif)
                success = this.cppmethod('startOutlet',stream,logical(asGif));
            else
                success = this.cppmethod('startOutlet',stream);
            end
        end
        function setIncludeEyeOpennessInGaze(this,include)
            this.cppmethod('setIncludeEyeOpennessInGaze',include);
        end
        function status = isStreaming(this,stream)
            if nargin<2
                error('LSLMex::isStreaming: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            status = this.cppmethod('isStreaming',ensureStringIsChar(stream));
        end
        function stopOutlet(this,stream)
            if nargin<2
                error('LSLMex::stopOutlet: provide stream argument. \nSupported streams are: %s.',this.getAllStreamsString());
            end
            this.cppmethod('stopOutlet',ensureStringIsChar(stream));
        end
        
        %% inlets
        function id = createInlet(this,streamSourceID,initialBufferSize,doStartListening)
            % optional buffer size input, and optional input to request
            % immediately starting listening on the inlet (so you do not
            % have to call startListening(id) yourself)
            if nargin<2
                error('LSLMex::createInlet: must provide an LSL stream source identifier string.');
            end
            streamSourceID = ensureStringIsChar(streamSourceID);
            if nargin>3 && ~isempty(doStartListening)
                id = this.cppmethod('startOutlet',streamSourceID,uint64(initialBufferSize),logical(doStartListening));
            elseif nargin>2 && ~isempty(initialBufferSize)
                id = this.cppmethod('startOutlet',streamSourceID,uint64(initialBufferSize));
            else
                id = this.cppmethod('startOutlet',streamSourceID);
            end
        end

        function streamInfo = getInletInfo(this,id)
            if nargin<2
                error('LSLMex::getInletInfo: must provide an inlet id.');
            end
            streamInfo = this.cppmethod('getInletInfo',uint32(id));
        end
        function stream = getInletType(this,id)
            if nargin<2
                error('LSLMex::getInletType: must provide an inlet id.');
            end
            stream = this.cppmethod('getInletType',uint32(id));
        end

        function startListening(this,id)
            if nargin<2
                error('LSLMex::startListening: must provide an inlet id.');
            end
            this.cppmethod('startListening',uint32(id));
        end
        function status = isListening(this,id)
            if nargin<2
                error('LSLMex::isListening: must provide an inlet id.');
            end
            status = this.cppmethod('isListening',uint32(id));
        end
        
        function data = consumeN(this,id,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: all
            % -  side: Which side of buffer to consume samples from.
            %          Values: 'start' or 'end'
            %          Default: 'start'
            if nargin<2
                error('LSLMex::consumeN: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>3 && ~isempty(side)
                data = this.cppmethod('consumeN',id,uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>2 && ~isempty(NSamp)
                data = this.cppmethod('consumeN',id,uint64(NSamp));
            else
                data = this.cppmethod('consumeN',id);
            end
        end
        function data = consumeTimeRange(this,id,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            if nargin<2
                error('LSLMex::consumeTimeRange: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('consumeTimeRange',id,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('consumeTimeRange',id,int64(startT));
            else
                data = this.cppmethod('consumeTimeRange',id);
            end
        end
        function data = peekN(this,id,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: 1. To get all,
            %          ask for inf samples
            % -  side: Which side of buffer to consume samples from.
            %          Values: 'start' or 'end'
            %          Default: 'end'
            if nargin<2
                error('LSLMex::peekN: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>3 && ~isempty(side)
                data = this.cppmethod('peekN',id,uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>2 && ~isempty(NSamp)
                data = this.cppmethod('peekN',id,uint64(NSamp));
            else
                data = this.cppmethod('peekN',id);
            end
        end
        function data = peekTimeRange(this,id,startT,endT)
            % optional inputs startT and endT. Default: whole buffer
            if nargin<2
                error('LSLMex::peekTimeRange: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('peekTimeRange',id,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('peekTimeRange',id,int64(startT));
            else
                data = this.cppmethod('peekTimeRange',id);
            end
        end

        function clear(this,id)
            if nargin<2
                error('LSLMex::clear: must provide an inlet id.');
            end
            this.cppmethod('clear',uint32(id));
        end
        function clearTimeRange(this,id,startT,endT)
            % optional start and end time inputs. Default: whole buffer
            if nargin<2
                error('LSLMex::clearTimeRange: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>3 && ~isempty(endT)
                this.cppmethod('clearTimeRange',id,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                this.cppmethod('clearTimeRange',id,int64(startT));
            else
                this.cppmethod('clearTimeRange',id);
            end
        end

        function stopListening(this,id,doClearBuffer)
            % optional boolean input indicating whether buffer should be
            % cleared out
            if nargin<2
                error('LSLMex::stopListening: must provide an inlet id.');
            end
            id = uint32(id);
            if nargin>2 && ~isempty(doClearBuffer)
                this.cppmethod('stopListening',id,logical(doClearBuffer));
            else
                this.cppmethod('stopListening',id);
            end
        end
        function deleteListener(this,id)
            if nargin<2
                error('LSLMex::deleteListener: must provide an inlet id.');
            end
            this.cppmethod('deleteListener',uint32(id));
        end
    end
end


% helpers
function str = ensureStringIsChar(str)
if isa(str,'string')
    str = char(str);        % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
end
end
