%% CalibrationResult
%
% Represents the result of the calculated calibration.
%
%   result = CalibrationResult(points,status)
%
%%
classdef CalibrationResult
    properties (SetAccess = immutable)
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
            result.CalibrationPoints = points;
            result.Status = CalibrationStatus(status);
        end
    end

end

%% See Also
% <../ScreenBasedCalibration/CalibrationPoint.html CalibrationPoint>, <../ScreenBasedCalibration/CalibrationStatus.html CalibrationStatus>

%% Version
% !version
%
% Copyright !year Tobii Pro
%
