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
            if isa(address,'string')
                address = char(address);    % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            this.instanceHandle = this.cppmethodGlobal('new',char(address));
        end
        
        function success = start(this,stream,initialBufferSize,asGif)
            % optional buffer size input, and input requesting gif-encoded
            % instead of raw images
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>3 && ~isempty(asGif)
                success = this.cppmethod('start',stream,uint64(initialBufferSize),logical(asGif));
            elseif nargin>2 && ~isempty(initialBufferSize)
                success = this.cppmethod('start',stream,uint64(initialBufferSize));
            else
                success = this.cppmethod('start',stream);
            end
        end
        function clear(this,stream)
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            this.cppmethod('clear',stream);
        end
        function clearTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole range
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>3 && ~isempty(endT)
                this.cppmethod('clearTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                this.cppmethod('clearTimeRange',stream,int64(startT));
            else
                this.cppmethod('clearTimeRange',stream);
            end
        end
        function success = stop(this,stream,doDeleteBuffer)
            % optional boolean input indicating whether buffer should be
            % deleted
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>2 && ~isempty(doDeleteBuffer)
                success = this.cppmethod('stop',stream,logical(doDeleteBuffer));
            else
                success = this.cppmethod('stop',stream);
            end
        end
        function data = consumeN(this,stream,firstN)
            % optional input indicating how many samples to read from the
            % beginning of buffer. Default: all
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>2 && ~isempty(firstN)
                data = this.cppmethod('consumeN',stream,uint64(firstN));
            else
                data = this.cppmethod('consumeN',stream);
            end
        end
        function data = consumeTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole range
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>3 && ~isempty(endT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT),int64(endT));
            elseif nargin>2 && ~isempty(startT)
                data = this.cppmethod('consumeTimeRange',stream,int64(startT));
            else
                data = this.cppmethod('consumeTimeRange',stream);
            end
        end
        function data = peekN(this,stream,lastN)
            % optional input indicating how many items to read from the
            % end of buffer. Default: 1
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
            if nargin>2 && ~isempty(lastN)
                data = this.cppmethod('peekN',stream,uint64(lastN));
            else
                data = this.cppmethod('peekN',stream);
            end
        end
        function data = peekTimeRange(this,stream,startT,endT)
            % optional start and end time inputs. Default: whole range
            if isa(stream,'string')
                stream = char(stream);      % seems matlab also has a string type, shows up if user accidentally uses double quotes, convert to char
            end
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
        end
        function stopLogging(this)
            this.cppmethodGlobal('stopLogging');
        end
    end
end
