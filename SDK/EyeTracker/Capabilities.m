%% Capabilites
%
% Defines the capabilities.
%
%%
classdef Capabilities < uint64
   enumeration
      %% CanSetDisplayArea
      % Indicates that the device's display area can be set.
      %
      %     Capabilities.CanSetDisplayArea (1)
      %
      CanSetDisplayArea (1)
      %%

      %% HasExternalSignal
      % Indicates that the device can deliver an external signal stream. 
      %
      %     Capabilities.HasExternalSignal (2)
      %
      HasExternalSignal (2)
      %%

      %% HasEyeImages
      % Indicates that the device can deliver an eye image stream.
      %
      %     Capabilities.HasEyeImages (4)
      %
      HasEyeImages (4)
      %%
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%s