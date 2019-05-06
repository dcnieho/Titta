%% GazePoint
%
% Provides properties for the gaze point.
%
%   gaze_point = GazePoint(on_display_area,...
%                   in_user_coordinate_system,...
%                   validity)
%
%%
classdef GazePoint
    properties (SetAccess = protected)
        %% OnDisplayArea
        % Gets the gaze point position in 2D on the active display area.
        %
        % gaze_point.OnDisplayArea
        %
        OnDisplayArea
        %% InUserCoordinateSystem
        % Gets the gaze point position in 3D in the user coordinate system.
        %
        % gaze_point.InUserCoordinateSystem
        %
        InUserCoordinateSystem
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the gaze point data.
        %
        % gaze_point.Validity
        %
        Validity
    end

    methods
        function gaze_point = GazePoint(on_display_area,...
                in_user_coordinate_system,...
                validity)
            if nargin > 0
                gaze_point.Validity = Validity(validity);
                gaze_point.OnDisplayArea = on_display_area;
                gaze_point.InUserCoordinateSystem = in_user_coordinate_system;
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
