%% Calibration Eye Validity
%
% Defines the validity of calibration eye sample.
%
%%
classdef CalibrationEyeValidity < EnumClass
    properties (Constant = true)
        %% InvalidAndNotUsed
        % The eye tracking failed or the calibration eye data is invalid.
        %
        %   CalibrationEyeValidity.InvalidAndNotUsed (-1)
        %
        InvalidAndNotUsed = -1;
        %%
        %% ValidButNotUsed
        % Eye Tracking was successful, but the calibration eye data was
        % not used in calibration e.g. gaze was too far away.
        %
        %   CalibrationEyeValidity.ValidButNotUsed (0)
        %
        ValidButNotUsed = 0;
        %%
        %% ValidAndUsed
        % The calibration eye data was valid and used in calibration.
        %
        %   CalibrationEyeValidity.ValidAndUsed (1)
        %
        ValidAndUsed = 1;
        %%
    end

    methods
        function out = CalibrationEyeValidity(in)
            if nargin > 0
                out.value =  in;
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
