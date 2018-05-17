%% HMDEyeData
%
% Provides properties for the eye data when gotten from an HMD based device.
%
%   hmd_eye_data = HMDEyeData(gaze_direction_unit_vector,...
%                gaze_direction_validity,...
%                gaze_origin_position_in_hmd_coordinates,...
%                gaze_origin_validity,...
%                pupil_diameter,...
%                pupil_validity,...
%                pupil_position_position_in_tracking_area,...
%                pupil_position_validity)
%
%%
classdef HMDEyeData    
    properties (SetAccess = immutable)
        %% GazeDirection
        % Gets the <../Gaze/HMDGazeDirection.html HMDGazeDirection> data.
        %
        %   hmd_eye_data.GazeDirection
        %
        GazeDirection
        %% Pupil
        % Gets the <../Gaze/PupilData.html PupilData>.
        %
        %   hmd_eye_data.Pupil
        %
        Pupil
        %% GazeOrigin
        % Gets the <../Gaze/HMDGazeOrigin.html HMDGazeOrigin> data.
        %
        %   hmd_eye_data.GazeOrigin
        %
        GazeOrigin
        %% PupilPosition
        % Gets the <../Gaze/HMDPupilPosition.html HMDPupilPosition> data.
        %
        %   hmd_eye_data.PupilPosition
        %
        PupilPosition
    end
    
    methods
        function hmd_eye_data = HMDEyeData(gaze_direction_unit_vector,...
                gaze_direction_validity,...
                gaze_origin_position_in_hmd_coordinates,...
                gaze_origin_validity,...
                pupil_diameter,...
                pupil_validity,...
                pupil_position_position_in_tracking_area,...
                pupil_position_validity)
            
            hmd_eye_data.GazeDirection = HMDGazeDirection(gaze_direction_unit_vector,...
                gaze_direction_validity);
            
            hmd_eye_data.Pupil = PupilData(pupil_diameter,pupil_validity);
                     
            hmd_eye_data.GazeOrigin = HMDGazeOrigin(gaze_origin_position_in_hmd_coordinates,...
                gaze_origin_validity);   
            
            hmd_eye_data.PupilPosition = HMDPupilPosition(pupil_position_position_in_tracking_area,...
                pupil_position_validity);
            
        end
    end
    
end

%% See Also
% <../Gaze/HMDGazeDirection.html HMDGazeDirection>, <../Gaze/PupilData.html
% PupilData>, <../Gaze/HMDGazeOrigin.html HMDGazeOrigin>, <../Gaze/HMDPupilPosition.html HMDPupilPosition>

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