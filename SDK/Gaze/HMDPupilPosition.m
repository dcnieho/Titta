%% HMDPupilPosition
%
% Provides properties for the HMD pupil position.
%
%   hmd_pupil_position = HMDPupilPosition(position_in_tracking_area,...
%                   validity)
%
%%
classdef HMDPupilPosition
    properties (SetAccess = immutable)
        %% PositionInTrackingArea
        % Gets the (normalizes) 2D coordinates that describes the pupil's position in the HMD's tracking area.
        %
        % hmd_pupil_position.PositionInTrackingArea
        %
        PositionInTrackingArea
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the pupil position data.
        %
        % hmd_pupil_position.Validity
        %
        Validity
    end

    methods
        function hmd_pupil_position = HMDPupilPosition(position_in_tracking_area,...
                 validity)

            hmd_pupil_position.Validity = Validity(validity);

            hmd_pupil_position.PositionInTrackingArea = position_in_tracking_area;
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
