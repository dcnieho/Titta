%% External Signal Change Type 
%
% Defines the type of external signal.
%
%%
classdef ExternalSignalChangeType < int32
   enumeration
      %% ValueChanged 
      % Indicates that the value sent to the eye tracker has changed.
      %
      %     type.ValueChanged  (0)
      %
      ValueChanged  (0)
      %%
      %% InitialValue
      % Indicates that the value is the initial value, and is received 
      % when starting a subscription.
      %
      %     type.InitialValue (1)
      %
      InitialValue (1)
      %%
      %% ConnectionRestored 
      % Indicates that there has been a connection lost and now it is 
      % restored and the value is the current value.
      %
      %     type.ConnectionRestored  (2)
      %
      ConnectionRestored (2)
      %%
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%