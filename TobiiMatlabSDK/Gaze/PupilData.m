%% PupilData
%
% Provides properties for the pupil data.
%
%   pupil_data = PupilData(diameter,validity)
%
%%
classdef PupilData
    properties (SetAccess = protected)
        %% Diameter
        % Gets the diameter of the pupil in millimeters.
        %
        %   pupil_data.Diameter
        %
        Diameter
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the pupil data
        %
        %   pupil_data.Validity
        %
        Validity
    end

    methods
        function pupil_data = PupilData(diameter,validity)
            if nargin > 0
                pupil_data.Validity = Validity(validity);
                pupil_data.Diameter = diameter;
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