%% Stream Error Type
%
% Defines the error type occured during a stream.
%
%%
classdef StreamErrorType < int32
   enumeration
      %% ConnectionLost 
      % Indicates that the connection to the device was lost.
      %
      %     type.ConnectionLost (0)
      %
      ConnectionLost  (0)
      %%
      %% InsufficientLicense
      % Indicates that a feature locked by license is trying to be used.
      %
      %     type.InsufficientLicense (1)
      %
      InsufficientLicense (1)
      %%
      %% NotSupported 
      % Indicates that a feature not supported by the device is trying to
      % be used.
      %
      %     type.NotSupported  (2)
      %
      NotSupported (2)
      %%
      %% Internal 
      % Indicates that an internal error occured during a stream.
      %
      %     type.Internal  (3)
      %
      Internal (3)
      %%
      %% User 
      % Indicates that an error reported by the user occured during a stream.
      %
      %     type.User  (4)
      %
      User (4)
      %%
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%