%% UserPositionGuide
%
% Provides data for the UserPositionGuide.
%
%   user_position_guide = UserPositionGuide(
%                left_user_position,...
%                left_user_position_validity,...
%                right_user_position,...
%                right_user_position_validity)
%
%%
classdef UserPositionGuide
    properties (SetAccess = protected)
        %% LeftEye
        % Gets the user position guide (<../Gaze/UserPosition.html UserPosition>) for the left eye.
        %
        %   user_position_guide.LeftEye
        %
        LeftEye
        %% RightEye
        % Gets the user position guide (<../Gaze/UserPosition.html UserPosition>) for the right eye.
        %
        %   user_position_guide.RightEye
        %
        RightEye
    end

    methods
        function user_position_guide = UserPositionGuide(left_user_position,...
                left_user_position_validity,...
                right_userleft_user_position,...
                right_user_position_validity)

            if nargin > 0

                user_position_guide.LeftEye = UserPosition(left_user_position,...
                    left_user_position_validity);

                user_position_guide.RightEye = UserPosition(right_userleft_user_position,...
                    right_user_position_validity);
            end

        end
    end

end

%% See Also
% <../Gaze/UserPosition.html EyeData>

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