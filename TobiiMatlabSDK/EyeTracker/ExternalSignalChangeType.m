%% External Signal Change Type
%
% Defines the type of external signal.
%
%%
classdef ExternalSignalChangeType < EnumClass
    properties (Constant = true)
        %% ValueChanged
        % Indicates that the value sent to the eye tracker has changed.
        %
        %     type.ValueChanged  (0)
        %
        ValueChanged = 0;
        %%
        %% InitialValue
        % Indicates that the value is the initial value, and is received
        % when starting a subscription.
        %
        %     type.InitialValue (1)
        %
        InitialValue = 1;
        %%
        %% ConnectionRestored
        % Indicates that there has been a connection lost and now it is
        % restored and the value is the current value.
        %
        %     type.ConnectionRestored  (2)
        %
        ConnectionRestored = 2;
        %%
    end

    methods
        function out = ExternalSignalChangeType(in)
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