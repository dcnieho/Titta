%% CalibrationStatus
%
% Defines the overall status of a calibration process.
%
%%
classdef CalibrationStatus < int32
   enumeration
      %% Failure
      % Indicates that the calibration process failed.
      %
      %     CalibrationStatus.Failure (0)
      %
      Failure (0),
      %%
      %% Success
      % Indicates that the calibration process succeeded.
      %
      %     CalibrationStatus.Success (1)
      %
      Success (1),
      %%
   end
end

%% See Also
% <../ScreenBasedCalibration/CalibrationResult.html CalibrationResult>

%% Version
% !version
%
% Copyright !year Tobii Pro
%

