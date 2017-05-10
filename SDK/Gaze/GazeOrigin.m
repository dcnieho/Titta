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
    properties (SetAccess = immutable)
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

            gaze_origin.Validity = Validity(validity);
            
            if gaze_origin.Validity == Validity.Valid
                gaze_origin.InUserCoordinateSystem = in_user_coordinate_system;
                gaze_origin.InTrackBoxCoordinateSystem = in_trackbox_coordinate_system;
            else
                gaze_origin.InUserCoordinateSystem = nan;
                gaze_origin.InTrackBoxCoordinateSystem = nan;
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
