%% Calibration Eye Validity
%
% Defines the validity of calibration eye sample.
%
%%
classdef CalibrationEyeValidity < int32
   enumeration
      %% InvalidAndNotUsed
      % The eye tracking failed or the calibration eye data is invalid.
      %
      %   CalibrationEyeValidity.InvalidAndNotUsed (-1)  
      %
      InvalidAndNotUsed (-1),
      %%
      %% ValidButNotUsed
      % Eye Tracking was successful, but the calibration eye data was 
      % not used in calibration e.g. gaze was too far away.
      %
      %   CalibrationEyeValidity.ValidButNotUsed (0) 
      %
      ValidButNotUsed (0),
      %%
      %% ValidAndUsed
      % The calibration eye data was valid and used in calibration.
      %
      %   CalibrationEyeValidity.ValidAndUsed (1)
      %
      ValidAndUsed (1)
      %%
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%
