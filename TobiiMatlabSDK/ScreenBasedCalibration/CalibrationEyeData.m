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
            if nargin > 0
                gaze.PositionOnDisplayArea = position;
                gaze.Validity = CalibrationEyeValidity(validity);
            end
        end
    end
    
end

%% See Also
% <../Gaze/Validity.html Validity>

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