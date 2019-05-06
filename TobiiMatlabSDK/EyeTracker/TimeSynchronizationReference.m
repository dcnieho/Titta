%% TimeSynchronizationReference
%
% Provides data for the Time Synchronization Reference
%
%   time_sync_ref = TimeSynchronizationReference(SystemRequestTimeStamp,...
%                    DeviceTimeStamp,...
%                    SystemResponseTimeStamp)
%
%%
classdef TimeSynchronizationReference
    properties (SetAccess = protected)
        %% SystemRequestTimeStamp
        % Gets the time stamp when the computer sent the request to the eye tracker.
        %
        % time_sync_ref.SystemRequestTimeStamp
        %
        SystemRequestTimeStamp
        %% DeviceTimeStamp
        % Gets the time stamp when the eye tracker received the request,
        % according to the eye tracker's clock.
        %
        % time_sync_ref.DeviceTimeStamp
        %
        DeviceTimeStamp
        %% SystemResponseTimeStamp
        % Gets the time stamp when the computer received the response from
        % the eye tracker
        %
        % time_sync_ref.SystemResponseTimeStamp
        %
        SystemResponseTimeStamp
    end

    methods
        function time_sync_ref = TimeSynchronizationReference(system_request_time_stamp,...
                    device_time_stamp,...
                    system_response_time_stamp)
            if nargin > 0
                time_sync_ref.SystemRequestTimeStamp = system_request_time_stamp;

                time_sync_ref.DeviceTimeStamp = device_time_stamp;

                time_sync_ref.SystemResponseTimeStamp = system_response_time_stamp;
            end
        end
    end
end

%% See Also
% <../EyeTracker.html EyeTracker>

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