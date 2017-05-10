%% EyeImageType
%
% Defines the type of eye image.
%
%%
classdef EyeImageType < int32
   enumeration
      %% Full
      % Indicates that the eye tracker could not identify the eyes
      % and the image is the full image.
      %
      %     type.Full (0)
      %
      Full (0)
      %%
      %% Cropped
      % Indicates that the image is cropped and shows the eyes.
      %
      %     type.Cropped (1)
      %
      Cropped (1)
      %%
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%