classdef Receiver < TittaLSL.detail.Base
    properties (Dependent, SetAccess=private)
        stream
        isRecording
    end

    methods (Static)
        function streamInfos = GetStreams(streamType)
            fnc = TittaLSL.detail.Base.getMexFnc();
            if nargin>1
                streamInfos = fnc('GetStreams',ensureStringIsChar(streamType));
            else
                streamInfos = fnc('GetStreams');
            end
        end
    end
    
    methods
        %% wrapper functions
        function this = Receiver(streamSourceID,initialBufferSize,doStartRecording)
            % optional buffer size input, and optional input to request
            % immediately starting listening on the inlet (so you do not
            % have to call startListening(id) yourself)
            if nargin<1
                error('TittaLSL::Receiver::constructor: must provide an LSL stream source identifier string.');
            end
            streamSourceID = ensureStringIsChar(streamSourceID);
            if nargin>2 && ~isempty(doStartRecording)
                this.newInstance('Receiver', streamSourceID,uint64(initialBufferSize),logical(doStartRecording));
            elseif nargin>1 && ~isempty(initialBufferSize)
                this.newInstance('Receiver', streamSourceID,uint64(initialBufferSize));
            else
                this.newInstance('Receiver', streamSourceID);
            end
        end
        
        
        %% property getters
        function stream = get.stream(this)
            stream = this.cppmethod('getType');
        end
        function status = get.isRecording(this)
            status = this.cppmethod('isRecording');
        end
        
        
        %% member functions
        function streamInfo = getInfo(this)
            streamInfo = this.cppmethod('getInfo');
        end

        function start(this)
            this.cppmethod('start');
        end
        
        function data = consumeN(this,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: all
            % -  side: Which side of buffer to consume samples from.
            %          Values: 'start' or 'end'
            %          Default: 'start'
            if nargin>2 && ~isempty(side)
                data = this.cppmethod('consumeN',uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>1 && ~isempty(NSamp)
                data = this.cppmethod('consumeN',uint64(NSamp));
            else
                data = this.cppmethod('consumeN');
            end
        end
        function data = consumeTimeRange(this,startT,endT,timeIsLocalTime)
            % optional inputs startT and endT. Default: whole buffer
            if nargin>3 && ~isempty(timeIsLocalTime)
                data = this.cppmethod('consumeTimeRange',int64(startT),int64(endT),logical(timeIsLocalTime));
            elseif nargin>2 && ~isempty(endT)
                data = this.cppmethod('consumeTimeRange',int64(startT),int64(endT));
            elseif nargin>1 && ~isempty(startT)
                data = this.cppmethod('consumeTimeRange',int64(startT));
            else
                data = this.cppmethod('consumeTimeRange');
            end
        end
        function data = peekN(this,NSamp,side)
            % optional input arguments:
            % - NSamp: how many samples to consume. Default: 1. To get all,
            %          ask for inf samples
            % -  side: Which side of buffer to consume samples from.
            %          Values: 'start' or 'end'
            %          Default: 'end'
            if nargin>2 && ~isempty(side)
                data = this.cppmethod('peekN',uint64(NSamp),ensureStringIsChar(side));
            elseif nargin>1 && ~isempty(NSamp)
                data = this.cppmethod('peekN',uint64(NSamp));
            else
                data = this.cppmethod('peekN');
            end
        end
        function data = peekTimeRange(this,startT,endT,timeIsLocalTime)
            % optional inputs startT and endT. Default: whole buffer
            if nargin>3 && ~isempty(timeIsLocalTime)
                data = this.cppmethod('peekTimeRange',int64(startT),int64(endT),logical(timeIsLocalTime));
            elseif nargin>2 && ~isempty(endT)
                data = this.cppmethod('peekTimeRange',int64(startT),int64(endT));
            elseif nargin>1 && ~isempty(startT)
                data = this.cppmethod('peekTimeRange',int64(startT));
            else
                data = this.cppmethod('peekTimeRange');
            end
        end

        function clear(this)
            this.cppmethod('clear');
        end
        function clearTimeRange(this,startT,endT,timeIsLocalTime)
            % optional start and end time inputs. Default: whole buffer
            if nargin>3 && ~isempty(timeIsLocalTime)
                this.cppmethod('clearTimeRange',int64(startT),int64(endT),logical(timeIsLocalTime));
            elseif nargin>2 && ~isempty(endT)
                this.cppmethod('clearTimeRange',int64(startT),int64(endT));
            elseif nargin>1 && ~isempty(startT)
                this.cppmethod('clearTimeRange',int64(startT));
            else
                this.cppmethod('clearTimeRange');
            end
        end

        function stop(this,doClearBuffer)
            % optional boolean input indicating whether buffer should be
            % cleared out
            if nargin>1 && ~isempty(doClearBuffer)
                this.cppmethod('stop',logical(doClearBuffer));
            else
                this.cppmethod('stop');
            end
        end
    end
end
