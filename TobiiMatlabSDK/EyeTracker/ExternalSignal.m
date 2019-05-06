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
    properties (SetAccess = protected)
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

            if nargin > 0
                external_signal.Value = value;

                external_signal.DeviceTimeStamp = device_time_stamp;

                external_signal.SystemTimeStamp = system_time_stamp;

                external_signal.ChangeType = ExternalSignalChangeType(change_type);
            end
        end
    end

end

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