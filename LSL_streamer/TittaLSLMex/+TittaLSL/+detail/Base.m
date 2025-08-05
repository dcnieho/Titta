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
        function mexClassWrapperFnc = getMexFnc(SDKVersion, debugMode)
            persistent mexClassWrapperFncCache;
            % version indicates the version of the Tobii SDK that the
            % loaded MEX file should be built against, i.e., version==1
            % loads TittaLSLMex_v1, for compatibility with older eye
            % trackers, version==2 loads TittaLSLMex_v2 which only works
            % with Tobii eye trackers from the last few years, but has the
            % latest features.
            if nargin<1 || isempty(SDKVersion)
                SDKVersion = 2;
            end

            if isempty(mexClassWrapperFncCache)
                mexClassWrapperFncCache = cell(0,2);
            end

            qLoaded = [mexClassWrapperFncCache{:,1}]==SDKVersion;
            if ~any(qLoaded)
                % debugmode is for developer of TittaLSLMex only, no use for end users
                if nargin<2 || isempty(debugMode)
                    debugMode = false;
                else
                    debugMode = ~~debugMode;
                end
                % determine what mex file to call
                if debugMode
                    mexFncStr = sprintf('TittaLSL.detail.TittaLSLMex_v%d_d',SDKVersion);
                else
                    mexFncStr = sprintf('TittaLSL.detail.TittaLSLMex_v%d',SDKVersion);
                end
    
                % 1. check if mex file is found on path
                if isempty(which(mexFncStr))
                    error('TittaLSL:MEXFunctionNotFound','The MEX file "%s" was not found on path.',mexFncStr);
                end
    
                % construct function handle to Mex file
                mexClassWrapperFncCache{end+1,2} = str2func(mexFncStr);
                mexClassWrapperFncCache{end  ,1} = SDKVersion;

                mexClassWrapperFnc = mexClassWrapperFncCache{end,2};
            else
                mexClassWrapperFnc = mexClassWrapperFncCache{qLoaded,2};
            end

            % call no-op to load the mex file/check its loaded, so we fail
            % early when load has failed
            mexClassWrapperFnc('touch');
        end
    end

    methods (Static)
        % dll info
        function SDKVersion = GetTobiiSDKVersion(SDKVersion)
            if nargin<1
                SDKVersion = [];
            end
            fnc = TittaLSL.detail.Base.getMexFnc(SDKVersion);
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
        function this = Base(SDKVersion)
            this.mexClassWrapperFnc = TittaLSL.detail.Base.getMexFnc(SDKVersion);
        end

        % getters
        function SDKVersion = get.TobiiSDKVersion(this)
            SDKVersion = this.cppmethodGlobal('GetTobiiSDKVersion');
        end
        function LSLVersion = get.LSLVersion(this)
            LSLVersion = this.GetLSLVersion();
        end
    end
end
