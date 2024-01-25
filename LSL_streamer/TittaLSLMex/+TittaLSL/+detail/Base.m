classdef (Abstract) Base < handle
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
                error('TittaLSLMex:invalidMEXFunction','Invalid MEX file "%s" for function %s.',funInfo.file,funInfo.function);
            end
        end
    end
    
    % methods dealing with the instance
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('TittaLSLMex:invalidHandle','No class handle. Did you call init yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
        
        function newInstance(this, varargin)
            this.instanceHandle = this.cppmethodGlobal('new',varargin{:});
        end
    end
    
    methods (Hidden)
        function delete(this)
            if ~isempty(this.instanceHandle)
                this.cppmethod('delete');
                this.instanceHandle = [];
            end
        end
    end
    
    methods
        function this = Base(debugMode)
            % debugmode is for developer of TittaLSLMex only, no use for
            % end users
            if nargin<1 || isempty(debugMode)
                debugMode = false;
            else
                debugMode = ~~debugMode;
            end
            % determine what mex file to call
            if debugMode
                mexFnc = 'TittaLSLMex_d';
            else
                mexFnc = 'TittaLSLMex';
            end
            
            % construct C++ class instance
            this.mexClassWrapperFnc = this.checkMEXFnc(mexFnc);
            
            % call no-op to load the mex file, so we fail early when load
            % fails
            this.cppmethodGlobal('touch');
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
    end
end
