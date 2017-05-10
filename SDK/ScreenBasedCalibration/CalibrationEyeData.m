%% CalibrationEyeData
%
% Represents the calibration sample data collected for one eye.
%
%%
classdef CalibrationEyeData
    properties
        %% PositionOnDisplayArea
        % Gets the eye sample position on the active display area.
        % 
        %   gaze.PositionOnDisplayArea
        %
        PositionOnDisplayArea
        %% Validity
        % Gets information about if the sample was used or not in 
        % the calibration. (<../Gaze/Validity.html Validity>)
        %
        %   gaze.Validity
        %
        Validity
    end
    
    methods
        function gaze = CalibrationEyeData(position,validity)

            gaze.PositionOnDisplayArea = position;
            gaze.Validity = CalibrationEyeValidity(validity);
        end
    end
    
end

%% See Also
% <../Gaze/Validity.html Validity>

%% Version
% !version
%
% Copyright !year Tobii Pro
%