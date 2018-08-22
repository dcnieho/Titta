classdef TobiiBuffer < cppclass
    methods
        % Use the name of your MEX file here
        function this = TobiiBuffer(address,debugMode)
            % debugmode is for developer of SMIbuffer only, no use for end
            % users
            if nargin<2 || isempty(debugMode)
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
            this@cppclass(mexFnc,address);
        end
        
        % delete is inherited
        
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
            % optional input indicating how many samples to read from the
            % beginning of buffer. Default: all
            if nargin>1
                data = this.cppmethod('consumeEyeImages',uint64(firstN));
            else
                data = this.cppmethod('consumeEyeImages');
            end
        end
        function data = peekEyeImages(this,lastN)
            % optional input indicating how many samples to read from the
            % end of buffer. Default: 1
            if nargin>1
                data = this.cppmethod('peekEyeImages',uint64(lastN));
            else
                data = this.cppmethod('peekEyeImages');
            end
        end
    end
end
