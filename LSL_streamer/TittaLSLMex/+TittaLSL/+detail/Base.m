classdef (Abstract) Base < handle
    properties (GetAccess = private, SetAccess = private, Hidden = true, Transient = true)
        type;
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
        function mexClassWrapperFnc = getMexFnc(debugMode)
            persistent mexClassWrapperFncCache;
            if isempty(mexClassWrapperFncCache)
                % debugmode is for developer of TittaLSLMex only, no use for end users
                if nargin<1 || isempty(debugMode)
                    debugMode = false;
                else
                    debugMode = ~~debugMode;
                end
                % determine what mex file to call
                if debugMode
                    mexFncStr = 'TittaLSL.detail.TittaLSLMex_d';
                else
                    mexFncStr = 'TittaLSL.detail.TittaLSLMex';
                end
    
                % 1. check if mex file is found on path
                if isempty(which(mexFncStr))
                    error('TittaLSL:MEXFunctionNotFound','The MEX file "%s" was not found on path.',mexFncStr);
                end
    
                % construct function handle to Mex file
                mexClassWrapperFncCache = str2func(mexFncStr);

                % call no-op to load the mex file, so we fail early when load fails
                mexClassWrapperFncCache('touch');
            end
            
            mexClassWrapperFnc = mexClassWrapperFncCache;
        end
    end

    methods (Static)
        % dll info
        function SDKVersion = GetTobiiSDKVersion()
            fnc = TittaLSL.detail.Base.getMexFnc();
            SDKVersion = fnc('GetTobiiSDKVersion');
        end
        function LSLVersion = GetLSLVersion()
            fnc = TittaLSL.detail.Base.getMexFnc();
            LSLVersion = fnc('GetLSLVersion');
        end

        % stream info
        function streams = GetAllStreamsString(quoteChar,snakeCase)
            fnc = TittaLSL.detail.Base.getMexFnc();
            if nargin>2
                streams = fnc('GetAllStreamsString',ensureStringIsChar(quoteChar),logical(snakeCase));
            elseif nargin>1
                streams = fnc('GetAllStreamsString',ensureStringIsChar(quoteChar));
            else
                streams = fnc('GetAllStreamsString');
            end
        end
    end
    
    % methods dealing with the instance
    methods (Access = protected, Sealed = true)
        function varargout = cppmethod(this, methodName, varargin)
            if isempty(this.instanceHandle)
                error('TittaLSLMex:invalidHandle','No class handle. Did you call newInstance() yet?');
            end
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, this.instanceHandle, varargin{:});
        end
        
        function varargout = cppmethodGlobal(this, methodName, varargin)
            [varargout{1:nargout}] = this.mexClassWrapperFnc(methodName, varargin{:});
        end
        
        function newInstance(this, varargin)
            this.type           = varargin{1};
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
        function this = Base()
            this.mexClassWrapperFnc = TittaLSL.detail.Base.getMexFnc();
        end

        % getters
        function SDKVersion = get.TobiiSDKVersion(this)
            SDKVersion = this.GetTobiiSDKVersion();
        end
        function LSLVersion = get.LSLVersion(this)
            LSLVersion = this.GetLSLVersion();
        end
    end
end
