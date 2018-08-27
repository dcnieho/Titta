classdef TobiiBuffer < handle
    properties (GetAccess = private, SetAccess = immutable, Hidden = true, Transient = true)
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
%             dlls = which('tobii_research.dll','-ALL');
%             if Is64Bit
%                 qFind = ~cellfun(@isempty,strfind(dlls,'64'));
%             else
%                 qFind = ~cellfun(@isempty,strfind(dlls,'32'));
%             end
%             cellfun(@(x)rmpath(fileparts(x)),dlls);
%             dllDir = fileparts(dlls{qFind});
%             addpath(dllDir);

            this.mexClassWrapperFnc = this.checkMEXFnc(mexFnc);
            
            % call no-op to load the mex file
            this.cppmethodGlobal('touch');
        end
        
        function delete(this)
            if ~isempty(this.instanceHandle)
                this.mexClassWrapperFnc('delete', this.instanceHandle);
                this.mexClassWrapperFnc = [];
                this.instanceHandle     = [];
            end
        end
        
        function init(this,address)
            if isa(address,'string')
                address = char(address);    % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            this.instanceHandle = this.cppmethod('new',char(address));
        end
        
        function success = startSampleBuffering(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.cppmethod('startSampleBuffering',uint64(initialBufferSize));
            else
                success = this.cppmethod('startSampleBuffering');
            end
        end
        function enableTempSampleBuffer(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                this.cppmethod('enableTempSampleBuffer',uint64(initialBufferSize));
            else
                this.cppmethod('enableTempSampleBuffer');
            end
        end
        function disableTempSampleBuffer(this)
            this.cppmethod('disableTempSampleBuffer');
        end
        function clearSampleBuffer(this)
            this.cppmethod('clearSampleBuffer');
        end
        function stopSampleBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.cppmethod('stopSampleBuffering',logical(doDeleteBuffer));
            else
                this.cppmethod('stopSampleBuffering');
            end
        end
        function data = consumeSamples(this,firstN)
            % optional input indicating how many samples to read from the
            % beginning of buffer. Default: all
            if nargin>1
                data = this.cppmethod('consumeSamples',uint64(firstN));
            else
                data = this.cppmethod('consumeSamples');
            end
        end
        function data = peekSamples(this,lastN)
            % optional input indicating how many samples to read from the
            % end of buffer. Default: 1
            if nargin>1
                data = this.cppmethod('peekSamples',uint64(lastN));
            else
                data = this.cppmethod('peekSamples');
            end
        end
        
        function success = startEyeImageBuffering(this,initialBufferSize,asGif)
            % optional buffer size input, and input requesting gif-encoded
            % instead of raw images
            if nargin>2
                success = this.cppmethod('startEyeImageBuffering',uint64(initialBufferSize),logical(asGif));
            elseif nargin>1
                success = this.cppmethod('startEyeImageBuffering',uint64(initialBufferSize));
            else
                success = this.cppmethod('startEyeImageBuffering');
            end
        end
        function enableTempEyeImageBuffer(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                this.cppmethod('enableTempEyeImageBuffer',uint64(initialBufferSize));
            else
                this.cppmethod('enableTempEyeImageBuffer');
            end
        end
        function disableTempEyeImageBuffer(this)
            this.cppmethod('disableTempSampleBuffer');
        end
        function clearEyeImageBuffer(this)
            this.cppmethod('clearEyeImageBuffer');
        end
        function stopEyeImageBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.cppmethod('stopEyeImageBuffering',logical(doDeleteBuffer));
            else
                this.cppmethod('stopEyeImageBuffering');
            end
        end
        function data = consumeEyeImages(this,firstN)
            % optional input indicating how many eye images to read from the
            % beginning of buffer. Default: all
            if nargin>1
                data = this.cppmethod('consumeEyeImages',uint64(firstN));
            else
                data = this.cppmethod('consumeEyeImages');
            end
        end
        function data = peekEyeImages(this,lastN)
            % optional input indicating how many eye images to read from
            % the end of buffer. Default: 1
            if nargin>1
                data = this.cppmethod('peekEyeImages',uint64(lastN));
            else
                data = this.cppmethod('peekEyeImages');
            end
        end
        
        function success = startExtSignalBuffering(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.cppmethod('startExtSignalBuffering',uint64(initialBufferSize));
            else
                success = this.cppmethod('startExtSignalBuffering');
            end
        end
        function enableTempExtSignalBuffer(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                this.cppmethod('enableTempExtSignalBuffer',uint64(initialBufferSize));
            else
                this.cppmethod('enableTempExtSignalBuffer');
            end
        end
        function disableTempExtSignalBuffer(this)
            this.cppmethod('disableTempExtSignalBuffer');
        end
        function clearExtSignalBuffer(this)
            this.cppmethod('clearExtSignalBuffer');
        end
        function stopExtSignalBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.cppmethod('stopExtSignalBuffering',logical(doDeleteBuffer));
            else
                this.cppmethod('stopExtSignalBuffering');
            end
        end
        function data = consumeExtSignals(this,firstN)
            % optional input indicating how many external signals to read
            % from the beginning of buffer. Default: all
            if nargin>1
                data = this.cppmethod('consumeExtSignals',uint64(firstN));
            else
                data = this.cppmethod('consumeExtSignals');
            end
        end
        function data = peekExtSignals(this,lastN)
            % optional input indicating how many external signals to read
            % from the end of buffer. Default: 1
            if nargin>1
                data = this.cppmethod('peekExtSignals',uint64(lastN));
            else
                data = this.cppmethod('peekExtSignals');
            end
        end
        
        function success = startTimeSyncBuffering(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.cppmethod('startTimeSyncBuffering',uint64(initialBufferSize));
            else
                success = this.cppmethod('startTimeSyncBuffering');
            end
        end
        function enableTempTimeSyncBuffer(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                this.cppmethod('enableTempTimeSyncBuffer',uint64(initialBufferSize));
            else
                this.cppmethod('enableTempTimeSyncBuffer');
            end
        end
        function disableTempTimeSyncBuffer(this)
            this.cppmethod('disableTempTimeSyncBuffer');
        end
        function clearTimeSyncBuffer(this)
            this.cppmethod('clearTimeSyncBuffer');
        end
        function stopTimeSyncBuffering(this,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if nargin>1
                this.cppmethod('stopTimeSyncBuffering',logical(doDeleteBuffer));
            else
                this.cppmethod('stopTimeSyncBuffering');
            end
        end
        function data = consumeTimeSyncs(this,firstN)
            % optional input indicating how many time sync packets to read
            % from the beginning of buffer. Default: all
            if nargin>1
                data = this.cppmethod('consumeTimeSyncs',uint64(firstN));
            else
                data = this.cppmethod('consumeTimeSyncs');
            end
        end
        function data = peekTimeSyncs(this,lastN)
            % optional input indicating how many time sync packets to read
            % from the end of buffer. Default: 1
            if nargin>1
                data = this.cppmethod('peekTimeSyncs',uint64(lastN));
            else
                data = this.cppmethod('peekTimeSyncs');
            end
        end
        
        
        function success = startLogging(this,initialBufferSize)
            % optional buffer size input
            if nargin>1
                success = this.cppmethodGlobal('startLogging',uint64(initialBufferSize));
            else
                success = this.cppmethodGlobal('startLogging');
            end
        end
        function data = getLog(this)
            data = this.cppmethodGlobal('getLog');
        end
        function stopLogging(this)
            this.cppmethodGlobal('stopLogging');
        end
    end
end
