%% LicenseKey
%
%
% Represents the eye tracker license key.
%
%   license_key = LicenseKey(key_string)
%
%%
classdef LicenseKey
    properties (SetAccess = protected)
        %% KeyString
        % Gets the string that is the actual license key.
        %
        %   license_key.KeyString
        %
        KeyString
    end

    methods
        function license_key = LicenseKey(key_string)
            if nargin > 0
                license_key.KeyString = uint8(key_string);
            end
        end
    end
end

%% See Also
% <../EyeTracker/FailedLicense.html FailedLicense>

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