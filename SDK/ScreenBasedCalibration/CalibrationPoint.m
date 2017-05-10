%% CalibrationPoint
%
% Represents the Calibration Point and its collected calibration samples.
%
%   calib_point = CalibrationPoint(point,left,right,validity)
%
%%
classdef CalibrationPoint
    properties (SetAccess = immutable)
        %% PositionOnDisplayArea
        % Gets the position of the calibration point on the Active Display Area.
        %
        %   calib_point.PositionOnDisplayArea
        %
        PositionOnDisplayArea
        %% LeftEye
        % Gets the calibration sample data(<../ScreenBasedCalibration/CalibrationEyeData.html CalibrationEyeData>) for the left eye.
        %
        %   calib_point.LeftEye
        %
        LeftEye
        %% Right Eye
        % Gets the calibration sample data(<../ScreenBasedCalibration/CalibrationEyeData.html CalibrationEyeData>) for the right eye.
        %
        %   calib_point.RigthEye
        %
        RightEye
    end
    
    methods
        function calib_point = CalibrationPoint(point,left,right,validity)
            
            calib_point.PositionOnDisplayArea = point;
            
            calib_point.LeftEye = CalibrationEyeData.empty(size(left,1),0);
            calib_point.RightEye = CalibrationEyeData.empty(size(left,1),0);
            for i=1:size(left,1)
                 calib_point.LeftEye(i) = CalibrationEyeData(left(i,:),validity(i,1));
                 calib_point.RightEye(i) = CalibrationEyeData(right(i,:),validity(i,2));
            end
        end
    end
    
end

%% See Also
% <../ScreenBasedCalibration/CalibrationEyeData.html CalibrationEyeData>

%% Version
% !version
%
% Copyright !year Tobii Pro
%