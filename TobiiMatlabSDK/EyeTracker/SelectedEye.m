%% SelectedEye
%
% Defines the selected eye.
%
%%
classdef SelectedEye < EnumClass
    properties (Constant = true)
        %% LEFT
        % Left Eye
        %
        %     selected_eye.LEFT (0)
        %
        LEFT = 0;
        %%
        %% RIGHT
        % Right Eye
        %
        %     selected_eye.RIGHT (1)
        %
        RIGHT = 1;
        %%
        %% BOTH
        % Both Eyes
        %
        %     selected_eye.BOTH (2)
        %
        BOTH = 2;
        %%
    end

    methods
        function out = SelectedEye(in)
            if nargin > 0
                out.value =  in;
            end
        end
    end
end

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