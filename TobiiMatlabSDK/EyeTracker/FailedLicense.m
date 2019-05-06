%% FaliedLicense
%
% Represents a license that failed.
%
%   failed_license = FailedLicense(license_key,validation_result)
%
%%
classdef FailedLicense
    properties (SetAccess = protected)
        %% LicenseKey
        % Gets the license key.
        %
        %   failed_license.LicenseKey
        %
        LicenseKey
        %% ValidationResult
        % Gets the result of the license validation.
        %
        %   failed_license.ValidationResult
        %
        ValidationResult
    end

    methods
        function failed_license = FailedLicense(license_key,validation_result)
            if nargin > 0
                failed_license.LicenseKey = license_key;
                failed_license.ValidationResult = LicenseValidationResult(validation_result);
            end
        end
    end

end

%% See Also
% <../EyeTracker/LicenseKey.html LicenseKey>

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