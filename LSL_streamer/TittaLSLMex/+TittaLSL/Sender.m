classdef Sender < TittaLSL.detail.Base
    properties (Dependent, SetAccess=private)
        eyeTracker
        streamingGaze
        streamingEyeImage
        streamingExternalSignal
        streamingTimeSync
        streamingPositioning
    end
    
    methods
        %% wrapper functions
        function this = Sender(addressOrInstance)
            % only needed when you want to stream _from_ an eye tracker,
            % not when you want to receive remote streams.
            % addressOrInstance can be an address of a Tobii eye tracker to
            % connect to or a Titta or TittaMex instance that is connected
            % to the eye tracker you want to stream from
            if isa(addressOrInstance,'Titta')
                assert(~isempty(addressOrInstance.buffer),'Can''t get the connected eye tracker: you passed a Titta instance, but this instance was not yet initialized and is thus not connected to an eye tracker.')
                addressOrInstance = addressOrInstance.buffer.address;
            elseif isa(addressOrInstance,'TittaMex')
                addressOrInstance = addressOrInstance.address;
            end
            addressOrInstance = ensureStringIsChar(addressOrInstance);

            this.newInstance('Sender', addressOrInstance);
        end
        
        
        %% property getters
        function str = get.eyeTracker(this)
            et = this.getEyeTracker();
            str = sprintf('%s (%s) @ %.0f', et.model, et.serialNumber, et.frequency);
        end
        function state = get.streamingGaze(this)
            state = this.isStreaming('gaze');
        end
        function state = get.streamingEyeImage(this)
            state = this.isStreaming('eyeImage');
        end
        function state = get.streamingExternalSignal(this)
            state = this.isStreaming('externalSignal');
        end
        function state = get.streamingTimeSync(this)
            state = this.isStreaming('timeSync');
        end
        function state = get.streamingPositioning(this)
            state = this.isStreaming('positioning');
        end
        
        
        %% member functions
        function eyeTracker = getEyeTracker(this)
            eyeTracker = this.cppmethod('getEyeTracker');
        end
        function name = getStreamSourceID(this,stream)
            if nargin<2
                error('TittaLSL::Sender::getStreamSourceID: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            name = this.cppmethod('getStreamSourceID',ensureStringIsChar(stream));
        end
        function success = start(this,stream,asGif)
            % optional buffer size input, and optional input to request
            % gif-encoded instead of raw images
            if nargin<2
                error('TittaLSL::Sender::start: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            stream = ensureStringIsChar(stream);
            if nargin>2 && ~isempty(asGif)
                success = this.cppmethod('start',stream,logical(asGif));
            else
                success = this.cppmethod('start',stream);
            end
        end
        function setIncludeEyeOpennessInGaze(this,include)
            this.cppmethod('setIncludeEyeOpennessInGaze',include);
        end
        function status = isStreaming(this,stream)
            if nargin<2
                error('TittaLSL::Sender::isStreaming: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            status = this.cppmethod('isStreaming',ensureStringIsChar(stream));
        end
        function stop(this,stream)
            if nargin<2
                error('TittaLSL::Sender::stop: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            this.cppmethod('stop',ensureStringIsChar(stream));
        end
    end
end
