%% GazeOrigin
%
% Provides properties for the gaze origin.
%
%   gaze_origin = GazeOrigin(in_user_coordinate_system,...
%                   in_trackbox_coordinate_system,...
%                   validity)
%
%%
classdef GazeOrigin
    properties (SetAccess = protected)
        %% InUserCoordinateSystem
        % Gets the gaze origin position in 3D in the user coordinate system.
        %
        % gaze_origin.InUserCoordinateSystem
        %
        InUserCoordinateSystem
        %% InTrackBoxCoordinateSystem
        % Gets the gaze origin position in 3D in the track box coordinate
        % system.
        %
        % gaze_origin.InTrackBoxCoordinateSystem
        %
        InTrackBoxCoordinateSystem
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the gaze origin data.
        %
        % gaze_origin.Validity
        %
        Validity
    end

    methods
        function gaze_origin = GazeOrigin(in_user_coordinate_system,...
                in_trackbox_coordinate_system,...
                validity)
            if nargin > 0
                gaze_origin.Validity = Validity(validity);
                gaze_origin.InUserCoordinateSystem = in_user_coordinate_system;
                gaze_origin.InTrackBoxCoordinateSystem = in_trackbox_coordinate_system;
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