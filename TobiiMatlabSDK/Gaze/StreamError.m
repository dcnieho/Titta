%% StreamError
%
% Provides properties for the stream error.
%
%   StreamError = Stream_Error(error_struct)
%
%%
classdef StreamError
    properties (SetAccess = protected)
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
            if nargin > 0
                stream_error.Error = StreamErrorType(error_struct.error); %#ok<*MCNPN>

                stream_error.Source = StreamErrorSource(error_struct.source);

                stream_error.Message = error_struct.message;

                stream_error.SystemTimeStamp = error_struct.system_time_stamp;
            end
        end
    end
end

%% See Also
% <../Gaze/GazePoint.html GazePoint>, <../Gaze/PupilData.html PupilData>, <../Gaze/GazeOrigin.html GazeOrigin>

%% Version
% !version
%
% COPYRIGHT !year - PROPERTY OF TOBII PRO AB
% Copyright !year TOBII PRO AB - KARLSROVAGEN 2D, DANDERYD 182 53, SWEDEN - All Rights Reserved.
%
% Copyright NOTICE: All information contained herein is, and remains, the property of Tobii Pro AB and its suppliers,
% if any. The intellectual and technical concepts contained herein are proprietary to Tobii Pro AB and its suppliers and
% may be covered by U.S.and Foreign Patents, patent applications, and are protected by trade secret or copyright law.
% Dissemination of this information or reproduction of this material is strictly forbidden unless prior written
% permission is obtained from Tobii Pro AB.
%