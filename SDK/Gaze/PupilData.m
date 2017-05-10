%% PupilData
%
% Provides properties for the pupil data.
%
%   pupil_data = PupilData(diameter,validity)
%
%%
classdef PupilData
    properties (SetAccess = immutable)
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
            
            pupil_data.Validity = Validity(validity);
            
            if pupil_data.Validity == Validity.Valid
                pupil_data.Diameter = diameter;
            else
                pupil_data.Diameter = nan;
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