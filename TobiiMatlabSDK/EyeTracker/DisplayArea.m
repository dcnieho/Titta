%% DisplayArea
%
% Represents the corners of the active display area in the user coordinate system, and its size.
%
% The structure sent as an argument when creating an instance of this class
% must contain the fields: bottom_left, top_left and top_right.
% Note that the properties BottomRight, Width and Height are derived from the remaining
% properties.
%
%   display_area = DisplayArea(display_struct)
%
%%
classdef DisplayArea
    properties (SetAccess = protected)
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
            if ~isfield(display_struct,'bottom_left') || ~isfield(display_struct,'top_left') || ~isfield(display_struct,'top_right')
                msgID = 'DisplayArea:WrongInput';
                msg = 'Input must be a struct with the fields bottom_left, top_left and top_right.';
                error(msgID,msg);
            end

            display_area.BottomLeft = display_struct.bottom_left;
            display_area.TopLeft = display_struct.top_left;
            display_area.TopRight = display_struct.top_right;

            display_area.BottomRight = display_struct.top_right - display_struct.top_left + display_struct.bottom_left;
            display_area.Width = norm(display_struct.top_left - display_struct.top_right);
            display_area.Height = norm(display_struct.top_left - display_struct.bottom_left);
        end

        function s = struct(obj)
            s = struct('bottom_left',obj.BottomLeft, ...
                       'top_left',obj.TopLeft, ...
                       'top_right',obj.TopRight, ...
                       'bottom_right',obj.BottomRight, ...
                       'width',obj.Width, ...
                       'height',obj.Height);
        end

        function tf = eq(obj1,obj2)
            tf = all(obj1.BottomLeft == obj2.BottomLeft) && all(obj1.TopLeft == obj2.TopLeft) && all(obj1.TopRight == obj2.TopRight);
        end

    end
end

%% See Also
% <../EyeTracker.html EyeTracker>

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