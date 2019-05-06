%% EyeData
%
% Provides properties for the eye data.
%
%   eye_data = EyeData(gaze_point_on_display_area,...
%                gaze_point_in_user_coordinate_system,...
%                gaze_point_validity,...
%                pupil_diameter,...
%                pupil_validity,...
%                origin_in_user_coordinate_system,...
%                gaze_origin_in_trackbox_coordinate_system,...
%                gaze_origin_validity)
%
%%
classdef EyeData
    properties (SetAccess = protected)
        %% GazePoint
        % Gets the <../Gaze/GazePoint.html GazePoint> data.
        %
        %   eye_data.GazePoint
        %
        GazePoint
        %% Pupil
        % Gets the <../Gaze/PupilData.html PupilData>.
        %
        %   eye_data.Pupil
        %
        Pupil
        %% GazeOrigin
        % Gets the <../Gaze/GazeOrigin.html GazeOrigin> data.
        %
        %   eye_data.GazeOrigin
        %
        GazeOrigin
    end

    methods
        function eye_data = EyeData(gaze_point_on_display_area,...
                gaze_point_in_user_coordinate_system,...
                gaze_point_validity,...
                pupil_diameter,...
                pupil_validity,...
                origin_in_user_coordinate_system,...
                gaze_origin_in_trackbox_coordinate_system,...
                gaze_origin_validity)

            if nargin > 0
                eye_data.GazePoint = GazePoint(gaze_point_on_display_area,...
                    gaze_point_in_user_coordinate_system,...
                    gaze_point_validity);

                eye_data.Pupil = PupilData(pupil_diameter,pupil_validity);

                eye_data.GazeOrigin = GazeOrigin(origin_in_user_coordinate_system,...
                    gaze_origin_in_trackbox_coordinate_system,...
                    gaze_origin_validity);
            end

        end
    end

end

%% See Also
% <../Gaze/GazePoint.html GazePoint>, <../Gaze/PupilData.html PupilData>, <../Gaze/GazeOrigin.html GazeOrigin>

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