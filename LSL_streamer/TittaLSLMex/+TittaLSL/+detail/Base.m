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

    methods (Static = true, Access = private)
        function mexClassWrapperFnc = getMexFncImpl(SDKVersion, debugMode)
            % determine what mex file to call
            if debugMode
                mexFile = sprintf('TittaLSLMex_v%d_d',SDKVersion);
            else
                mexFile = sprintf('TittaLSLMex_v%d',SDKVersion);
            end
            if strcmp(computer,'PCWIN') || strcmp(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')) %#ok<STREMP>
                mexFncStr = sprintf('TittaLSL.detail.SDKv%d.%s',SDKVersion,mexFile);
            else
                mexFncStr = sprintf('TittaLSL.detail.%s',mexFile);
            end

            % 1. check if mex file is found on path
            if isempty(which(mexFncStr))
                error('TittaLSL:MEXFunctionNotFound','The MEX file "%s" was not found on path.',mexFncStr);
            end

            % construct function handle to Mex file
            mexClassWrapperFnc = str2func(mexFncStr);

            % call no-op to load the mex file, so we fail early when load fails
            mexClassWrapperFnc('touch');
        end
    end

    methods (Static = true, Access = protected)
        function mexClassWrapperFnc = getMexFnc(SDKVersion, debugMode)
            persistent mexClassWrapperFncCache;
            % version indicates the version of the Tobii SDK that the MEX
            % file should be built against, i.e., version==1 loads
            % TittaLSLMex_v1, for compatibility with older eye trackers,
            % version==2 loads TittaLSLMex_v2 which only works with Tobii
            % eye trackers from the last few years, but has the latest
            % features.
            guessVersion = nargin<1 || isempty(SDKVersion);
            if guessVersion
                SDKVersion = 1;
            end
            if isempty(mexClassWrapperFncCache)
                % debugmode is for developer of TittaLSLMex only, no use for end users
                if nargin<2 || isempty(debugMode)
                    debugMode = false;
                else
                    debugMode = ~~debugMode;
                end
                while true
                    mexClassWrapperFncCache = TittaLSL.detail.Base.getMexFncImpl(SDKVersion, debugMode);
                    if ~guessVersion
                        break
                    else
                        % check we got what we expected
                        loadedVersion = mexClassWrapperFncCache('GetTobiiSDKVersion');
                        loadedVersion = str2double(loadedVersion(1));
                        if loadedVersion ~= SDKVersion
                            % set right version and try again. Why this
                            % crazy logic? If a single tobii_research.dll
                            % is already loaded somewhere in the MATLAB
                            % process, that's the one we'll get, even if
                            % we're trying to load the mex file for a
                            % different version of the dll. So we have to
                            % load, check what we got, and adjust.
                            SDKVersion = loadedVersion;
                        else
                            break;
                        end
                    end
                end
            end

            % User requested a specific version of tobii_research.dll.
            % Check if the right version of tobii_research dll is loaded.
            % If not, abort
            if ~guessVersion
                loadedVersion = mexClassWrapperFncCache('GetTobiiSDKVersion');
                if str2double(loadedVersion(1)) ~= SDKVersion
                    error('The version of the loaded tobii_research.dll is %s, which does not match the requested major version %d. This can happen if you have previously loaded this different version, either with a call to TittaLSLMex, or to TittaMex. If you want to change the underlying tobii_research.dll version, you have to close and restart MATLAB, a "clear all" is not sufficient. Also, do not mix the dll versions used for multiple eye trackers, TittaMex and TittaLSLMex instances',loadedVersion,SDKVersion)
                end
            end

            % set output
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
        function this = Base(SDKVersion)
            this.mexClassWrapperFnc = TittaLSL.detail.Base.getMexFnc(SDKVersion);
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
