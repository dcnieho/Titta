%% EyeImageType
%
% Defines the type of eye image.
%
%%
classdef EyeImageType < EnumClass
    properties (Constant = true)
        %% Full
        % Indicates that the eye tracker could not identify the eyes
        % and the image is the full image.
        %
        %     type.Full (0)
        %
        Full = 0;
        %%
        %% Cropped
        % Indicates that the image is cropped and shows the eyes.
        %
        %     type.Cropped (1)
        %
        Cropped = 1;
        %%
    end

    methods
        function out = EyeImageType(in)
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