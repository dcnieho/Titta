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
    properties (SetAccess = immutable)
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
            
            gaze_point.Validity = Validity(validity);
            
            if gaze_point.Validity == Validity.Valid
                gaze_point.OnDisplayArea = on_display_area;
                gaze_point.InUserCoordinateSystem = in_user_coordinate_system;
            else
                gaze_point.OnDisplayArea = nan;
                gaze_point.InUserCoordinateSystem = nan;
            end
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
