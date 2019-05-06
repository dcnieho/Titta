%% CalibrationStatus
%
% Defines the overall status of a calibration process.
%
%%
classdef CalibrationStatus < EnumClass
    properties (Constant = true)
        %% Failure
        % Indicates that the calibration process failed.
        %
        %     CalibrationStatus.Failure (0)
        %
        Failure = 0;
        %%
        %% Success
        % Indicates that the calibration process succeeded for both eyes.
        %
        %     CalibrationStatus.Success (1)
        %
        Success = 1;
        %%
        %% SuccessLeftEye
        % Indicates that the calibration process succeeded for the left eye.
        %
        %     CalibrationStatus.SuccessLeftEye (2)
        %
        SuccessLeftEye = 2;
        %%
        %% SuccessRightEye
        % Indicates that the calibration process succeeded for the right eye.
        %
        %     CalibrationStatus.SuccessRightEye (3)
        %
        SuccessRightEye = 3;
        %%
    end

    methods
        function out = CalibrationStatus(in)
            if nargin > 0
                out.value =  in;
            end
        end
    end
end

%% See Also
% <../ScreenBasedCalibration/CalibrationResult.html CalibrationResult>

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
