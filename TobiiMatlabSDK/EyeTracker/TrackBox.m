%% TrackBox
%
% Represents the eight corners in user coordinate system that 
% together forms the track box.
%
%        track_box = TrackBox(back_lower_left,...
%                back_lower_right,...
%                back_upper_left,...
%                back_upper_right,...
%                front_lower_left,...
%                front_lower_right,...
%                front_upper_left,...
%                front_upper_right)           
%
%%
classdef TrackBox
    properties (SetAccess = protected)
        %% Back Lower Left 
        % Gets the back lower left corner of the track box.
        % (Array with 3D coordinates).
        %   track_box.BackLowerLeft 
        %
        BackLowerLeft 
        %% Back Lower Right
        % Gets the back lower right corner of the track box. 
        % (Array with 3D coordinates).
        %
        %   track_box.BackLowerRight 
        %
        BackLowerRight 
        %% Back Upper Left
        % Gets the back upper left corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.BackUpperLeft 
        %
        BackUpperLeft 
        %% Back Upper Right
        % Gets the back upper right corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.BackUpperRight  
        %
        BackUpperRight 
        %% Front Lower Left
        % Gets the front lower left corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.FrontLowerLeft  
        %
        FrontLowerLeft
        %% Front Lower Right
        % Gets the front lower right corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.FrontLowerRight  
        %
        FrontLowerRight
        %% Front Upper Left
        % Gets the front upper left corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.FrontUpperLeft
        %
        FrontUpperLeft
        %% Front Upper Right
        % Gets the front upper right corner of the track box.
        % (Array with 3D coordinates).
        %
        %   track_box.FrontUpperRight
        %
        FrontUpperRight
    end
    methods
        function track_box = TrackBox(back_lower_left,...
                back_lower_right,...
                back_upper_left,...
                back_upper_right,...
                front_lower_left,...
                front_lower_right,...
                front_upper_left,...
                front_upper_right)
            
            track_box.BackLowerLeft = back_lower_left;
            track_box.BackLowerRight = back_lower_right;
            track_box.BackUpperLeft = back_upper_left;
            track_box.BackUpperRight = back_upper_right;
            track_box.FrontLowerLeft = front_lower_left;
            track_box.FrontLowerRight = front_lower_right;
            track_box.FrontUpperLeft = front_upper_left;
            track_box.FrontUpperRight = front_upper_right;
            
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
