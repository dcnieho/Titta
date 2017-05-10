%% FaliedLicense
%
% Represents a license that failed.
%
%   failed_license = FailedLicense(license_key,validation_result)   
%
%%
classdef FailedLicense 
    properties (SetAccess = immutable)
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
            
            failed_license.LicenseKey = license_key;
            
            failed_license.ValidationResult = LicenseValidationResult(validation_result);
        end
    end
    
end

%% See Also
% <../EyeTracker/LicenseKey.html LicenseKey>

%% Version
% !version
%
% Copyright !year Tobii Pro
%