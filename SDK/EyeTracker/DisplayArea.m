%% DisplayArea
%
% Represents the corners in space of the active display area, and its size.
%
%   display_area = DisplayArea(display)            
%
%%
classdef DisplayArea
    properties (SetAccess = immutable)
        %% Bottom Left
        % Gets the bottom left corner of the active display area 
        % (Array with 3D coordinates).
        %
        %   display_area.BottomLeft 
        %
        BottomLeft 
        %% Bottom Right
        % Gets the bottom right corner of the active display area 
        % (Array with 3D coordinates).
        %
        %   display_area.BottomRight 
        %
        BottomRight
        %% Top Left 
        % Gets the top left corner of the active display area 
        % (Array with 3D coordinates).
        %
        %   display_area.TopLeft
        %
        TopLeft 
        %% Top Right 
        % Gets the top right corner of the active display area 
        % (Array with 3D coordinates).
        %
        %   display_area.TopRight
        %
        TopRight
        %% Height
        % Gets the height in millimeters of the active display area.
        %
        %   display_area.Height
        %
        Height
        %% Width
        % Gets the width in millimeters of the active display area
        %
        %   display_area.Width
        %
        Width
    end
    
    methods
        function display_area = DisplayArea(display_struct)
            
            display_area.BottomLeft = display_struct.bottom_left;
            display_area.BottomRight = display_struct.bottom_right;
            display_area.TopLeft = display_struct.top_left;
            display_area.TopRight = display_struct.top_right;
            display_area.Width = display_struct.width;
            display_area.Height = display_struct.height;
            
        end
    end
    
end

%% See Also
% <../EyeTracker.html EyeTracker>

%% Version
% !version
%
% Copyright !year Tobii Pro
%