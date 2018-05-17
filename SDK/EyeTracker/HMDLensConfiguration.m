%% HMDLensConfiguration
%
% Represents the lens configuration of the HMD device.
%
%   lens_config = HMDLensConfiguration(lens_config)
%
%%
classdef HMDLensConfiguration
    properties (SetAccess = immutable)
        %% Left
        % The point in HMD coordinate system that defines the position of the left lens (in millimeters).
        % (Array with 3D coordinates).
        %
        %   lens_configuration.Left
        %
        Left
        %% Right
        % The point in HMD coordinate system that defines the position of the right lens (in millimeters).
        % (Array with 3D coordinates).
        %
        %   lens_configuration.Right
        %
        Right
    end

    methods
        function lens_configuration = HMDLensConfiguration(left, right)
            lens_configuration.Left = single(left);
            lens_configuration.Right = single(right);
        end
    end
end

%% See Also
% <../EyeTracker.html EyeTracker>

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