%% CalibrationResult
%
% Represents the result of the calculated calibration.
%
%   result = CalibrationResult(points,status)
%
%%
classdef CalibrationResult
    properties (SetAccess = protected)
        %% CalibrationPoints
        % Gets the list of calibration points and theirs collected
        % calibration samples.
        %
        %   result.CalibrationsPoints
        CalibrationPoints
        %% Status
        % Gets the status of the calculation.
        %
        %   result.Status
        Status
    end

    methods
        function result = CalibrationResult(points,status)
            if nargin > 0
                result.CalibrationPoints = points;
                result.Status = CalibrationStatus(status);
            end
        end
    end

end

%% See Also
% <../ScreenBasedCalibration/CalibrationPoint.html CalibrationPoint>, <../ScreenBasedCalibration/CalibrationStatus.html CalibrationStatus>

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
