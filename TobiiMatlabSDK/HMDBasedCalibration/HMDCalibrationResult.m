%% HMDCalibrationResult
%
% Represents the result of the HMD based calibration.
%
%   result = HMDCalibrationResult(status)
%
%%
classdef HMDCalibrationResult
    properties (SetAccess = protected)
        %% Status
        % Gets the status of the calculation.
        %
        %   result.Status
        Status
    end

    methods
        function result = HMDCalibrationResult(status)
            if nargin > 0
                result.Status = HMDCalibrationStatus(status);
            end
        end
    end

end

%% See Also
% <../HMDBasedCalibration/HMDCalibrationStatus.html HMDCalibrationStatus>

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