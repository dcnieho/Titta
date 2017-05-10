%% ExternalSignal
%
% Provides properties for the external signal data.
%
%   external_signal = ExternalSignal(value,...
%                   device_time_stamp,...
%                   system_time_stamp)
%
%%
classdef ExternalSignal
    properties (SetAccess = immutable)
        %% Value 
        % Gets the value of the external signal port on the eye tracker.
        %
        % external_signal.Value
        %
        Value
        %% DeviceTimeStamp
        % Gets the time stamp according to the eye tracker's internal clock.
        %
        % external_signal.DeviceTimeStamp
        %
        DeviceTimeStamp
        %% SystemTimeStamp
        % Gets the time stamp according to the computer's internal clock.
        %
        % external_signal.SystemTimeStamp
        %
        SystemTimeStamp
        %% ChangeType
        % Gets the type of value change.
        %
        % external_signal.ChangeType
        %
        ChangeType
    end
    
    methods
        function external_signal = ExternalSignal(value,...
                device_time_stamp,...
                system_time_stamp,...
                change_type)
            
            external_signal.Value = value;
            
            external_signal.DeviceTimeStamp = device_time_stamp;
            
            external_signal.SystemTimeStamp = system_time_stamp;
            
            external_signal.ChangeType = ExternalSignalChangeType(change_type);
        end
    end
    
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%