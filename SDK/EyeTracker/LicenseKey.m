%% LicenseKey
%
%
% Represents the eye tracker license key.
%
%   license_key = LicenseKey(key_string)
%
%%
classdef LicenseKey
    properties (SetAccess = immutable)
        %% KeyString
        % Gets the string that is the actual license key.
        %
        %   license_key.KeyString
        %
        KeyString
    end
    
    methods
        function license_key = LicenseKey(key_string)
            if nargin ~= 0
                if isnumeric(key_string)
                    key_string = {key_string};
                end
                if ischar(key_string) 
                    [n,m] = size(key_string);
                    if n>m
                        key_string = key_string';
                    end
                    key_string = {key_string};
                end
                [n,m] = size(key_string);
                license_key(n,m) = LicenseKey;
                for i=1:n
                    license_key(i).KeyString = uint8(key_string{i});
                end
            end
        end
    end
    
end

%% See Also
% <../EyeTracker/FailedLicense.html FailedLicense>

%% Version
% !version
%
% Copyright !year Tobii Pro
%