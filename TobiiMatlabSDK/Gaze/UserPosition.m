%% User Positiom
%
% Provides properties for the user position.
%
%   user_position = UserPosition(position, validity)
%
%%
classdef UserPosition
    properties (SetAccess = protected)
        %% UserPosition
        % Gets the user position.
        %
        % user_position.Position
        %
        Position
        %% Validity
        % Gets the <../Gaze/Validity.html Validity> of the user_position.
        %
        % user_position.Validity
        %
        Validity
    end

    methods
        function user_position = UserPosition(position, validity)
            if nargin > 0
                user_position.Validity = Validity(validity);
                user_position.Position = position;
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