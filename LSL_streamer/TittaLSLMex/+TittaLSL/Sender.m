% TittaLSL can be found at https://github.com/dcnieho/Titta. Check there
% for the latest version.
% When using TittaLSL, please cite the following paper:
% 
% Niehorster, D.C., Nyström, M. (2025). TittaLSL: A toolbox for creating
% networked eye-tracking experiments in Python and MATLAB with Tobii eye
% trackers. Behavior Research Methods. doi: 10.3758/s13428-025-02714-2
classdef Sender < TittaLSL.detail.Base
    properties (Dependent, SetAccess=private)
        eyeTracker
        eyeTrackerDescription

        hasGazeStream
        hasEyeOpennessStream
        hasExternalSignalStream
        hasTimeSyncStream
        hasPositioningStream

        streamingGaze
        streamingEyeOpenness
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

        function delete(this)
            this.destroy('gaze');
            this.destroy('eyeOpenness');
            this.destroy('externalSignal');
            this.destroy('timeSync');
            this.destroy('positioning');
        end
        
        
        %% property getters
        function et = get.eyeTracker(this)
            et = this.getEyeTracker();
        end
        function str = get.eyeTrackerDescription(this)
            et = this.getEyeTracker();
            str = sprintf('%s (%s) @ %.0f', et.model, et.serialNumber, et.frequency);
        end
        function state = get.hasGazeStream(this)
            state = this.hasStream('gaze');
        end
        function state = get.hasEyeOpennessStream(this)
            state = this.hasStream('eyeOpenness');
        end
        function state = get.hasExternalSignalStream(this)
            state = this.hasStream('externalSignal');
        end
        function state = get.hasTimeSyncStream(this)
            state = this.hasStream('timeSync');
        end
        function state = get.hasPositioningStream(this)
            state = this.hasStream('positioning');
        end
        function state = get.streamingGaze(this)
            state = this.isStreaming('gaze');
        end
        function state = get.streamingEyeOpenness(this)
            state = this.isStreaming('eyeOpenness');
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
        function success = create(this,stream,doStartSending)
            if nargin<2
                error('TittaLSL::Sender::create: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            if nargin>2 && ~isempty(doStartSending)
                success = this.cppmethod('create',ensureStringIsChar(stream),logical(doStartSending));
            else
                success = this.cppmethod('create',ensureStringIsChar(stream));
            end
        end
        function status = hasStream(this,stream)
            if nargin<2
                error('TittaLSL::Sender::hasStream: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            status = this.cppmethod('hasStream',ensureStringIsChar(stream));
        end
        function start(this,stream)
            if nargin<2
                error('TittaLSL::Sender::start: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            this.cppmethod('start',ensureStringIsChar(stream));
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
        function destroy(this,stream)
            if nargin<2
                error('TittaLSL::Sender::destroy: provide stream argument. \nSupported streams are: %s.',this.GetAllStreamsString());
            end
            this.cppmethod('destroy',ensureStringIsChar(stream));
        end
    end
end
