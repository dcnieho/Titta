%% HMDGazeDirection
%
% Provides properties for the HMD gaze direction.
%
%   hmd_gaze_direction = HMDGazeDirection(unit_vector,...
%                   validity)
%
%%
classdef HMDGazeDirection
    properties (SetAccess = protected)
        %% UnitVector
        % Gets the 3D unit vector that describes the gaze direction.
        %
        % hmd_gaze_direction.UnitVector
        %
        UnitVector
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the gaze direction data.
        %
        % hmd_gaze_direction.Validity
        %
        Validity
    end

    methods
        function hmd_gaze_direction = HMDGazeDirection(unit_vector,...
                 validity)
            if nargin > 0
                hmd_gaze_direction.Validity = Validity(validity);

                hmd_gaze_direction.UnitVector = unit_vector;
            end
        end
    end

end

%% See Also
% <../Gaze/Validity.html Validity>

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
