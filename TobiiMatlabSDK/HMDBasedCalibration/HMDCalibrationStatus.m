%% HMDCalibrationStatus
%
% Defines the overall status of a calibration process.
%
%%
classdef HMDCalibrationStatus < EnumClass
    properties (Constant = true)
        %% Failure
        % Indicates that the calibration process failed.
        %
        %     HMDCalibrationStatus.Failure (0)
        %
        Failure = 0;
        %%
        %% Success
        % Indicates that the calibration process succeeded.
        %
        %     HMDCalibrationStatus.Success (1)
        %
        Success = 1;
        %%
    end

    methods
        function out = HMDCalibrationStatus(in)
            if nargin > 0
                out.value =  in;
            end
        end
    end
end

%% See Also
% <../HMDBasedCalibration/HMDCalibrationResult.html HMDCalibrationResult>

%% Version
% !version
%
% COPYRIGHT !year - PROPERTY OF TOBII AB
% Copyright !year TOBII AB - KARLSROVAGEN 2D, DANDERYD 182 53, SWEDEN - All Rights Reserved.
%
% Copyright NOTICE: All information contained herein is, and remains, the property of Tobii AB and its suppliers,
% if any. The intellectual and technical concepts contained herein are proprietary to Tobii AB and its suppliers and
% may be covered by U.S.and Foreign Patents, patent applications, and are protected by trade secret or copyright law.
% Dissemination of this information or reproduction of this material is strictly forbidden unless prior written
% permission is obtained from Tobii AB.
%

