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
    properties (SetAccess = immutable)
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
            
            time_sync_ref.SystemRequestTimeStamp = system_request_time_stamp;
            
            time_sync_ref.DeviceTimeStamp = device_time_stamp;
            
            time_sync_ref.SystemResponseTimeStamp = system_response_time_stamp;
            
        end
    end
end    
%% See Also
% <../EyeTracker.html EyeTracker>

%% Version
% !version
%
% Copyright !year Tobii Pro
%