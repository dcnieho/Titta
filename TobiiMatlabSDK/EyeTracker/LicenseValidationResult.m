%% LicenseValidationResult
%
%
%
%%
classdef LicenseValidationResult < EnumClass
    properties (Constant = true)
        %% Valid
        % Indicates a valid license.
        %
        %     LicenseValidationResult.Valid (0)
        %
        Valid = 0;
        %%

        %% Tampered
        % Indicates a tampered license.
        %
        %     LicenseValidationResult.Tampered (1)
        %
        Tampered = 1;
        %%

        %% Invalid Application Signature
        % Indicates a license with an invalid application signature.
        %
        %     LicenseValidationResult.InvalidApplicationSignature (2)
        %
        InvalidApplicationSignature = 2;
        %%

        %% Nonsigned Application
        % Indicates a license with a non signed application.
        %
        %     LicenseValidationResult.NonsignedApplication (3)
        %
        NonsignedApplication = 3;
        %%

        %% Expired
        % Indicates an expired license.
        %
        %     LicenseValidationResult.Expired (4)
        %
        Expired = 4;
        %%

        %% Premature
        % Indicates a premature license
        %
        %     LicenseValidationResult.Premature (5)
        %
        Premature = 5;
        %%

        %% Invalid Process Name
        % Indicates a license with an invalid process name.
        %
        %     LicenseValidationResult.InvalidProcessName (6)
        %
        InvalidProcessName = 6;
        %%

        %% Invalid Serial Number
        % Indicates a license with an invalid serial number.
        %
        %     LicenseValidationResult.InvalidSerialNumber (7)
        %
        InvalidSerialNumber = 7;
        %%

        %% Invalid Mode
        % Indicates a license with an invalid mode.
        %
        %     LicenseValidationResult.InvalidMode (8)
        %
        InvalidMode = 8;
        %%
    end

    methods
        function out = LicenseValidationResult(in)
            if nargin > 0
                out.value =  double(in);
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