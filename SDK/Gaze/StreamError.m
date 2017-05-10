%% StreamError
%
% Provides properties for the stream error.
%
%   StreamError = Stream_Error(error_struct)
%
%%
classdef StreamError    
    properties (SetAccess = immutable)
        %% Error
        % Gets the <../Gaze/StreamErrorType.html StreamErrorType>.
        %
        %   stream_error.Error
        %
        Error
        %% Source
        % Gets the <../Gaze/StreamErrorSource.html StreamErrorSource>.
        %
        %   stream_error.Source
        %
        Source
        %% Message
        % Gets the message.
        %
        %   stream_error.Message
        %
        Message
        %% SystemTimeStamp
        % Gets the time stamp according to the computer's internal clock.
        %
        %   stream_error.SystemTimeStamp
        %
        SystemTimeStamp
    end
    
    methods
        function stream_error = StreamError(error_struct)
       
            stream_error.Error = StreamErrorType(error_struct.error); %#ok<*MCNPN>
            
            stream_error.Source = StreamErrorSource(error_struct.source);
                        
            stream_error.Message = error_struct.message;
            
            stream_error.SystemTimeStamp = error_struct.system_time_stamp;
            
        end
    end
    
end

%% See Also
% <../Gaze/GazePoint.html GazePoint>, <../Gaze/PupilData.html PupilData>, <../Gaze/GazeOrigin.html GazeOrigin>

%% Version
% !version
%
% Copyright !year Tobii Pro
%
