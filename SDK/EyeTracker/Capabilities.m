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

      %% HasGazeData
      % Indicates that the device can deliver a gaze data stream. Standard for all screen based eye trackers.
      %
      %     Capabilities.HasGazeData (8)
      %
      HasGazeData (8)
      %%

      %% HasHMDGazeData
      % Indicates that the device can deliver a HMD gaze data stream.
      %
      %     Capabilities.HasHMDGazeData (16)
      %
      HasHMDGazeData (16)
      %%

      %% CanDoScreenBasedCalibration
      % Indicates that screen based calibration can be performed on the device.
      %
      %     Capabilities.CanDoScreenBasedCalibration (32)
      %
      CanDoScreenBasedCalibration (32)
      %%

      %% CanDoHMDBasedCalibration
      % Indicates that HMD based calibration can be performed on the device.
      %
      %     Capabilities.CanDoHMDBasedCalibration (64)
      %
      CanDoHMDBasedCalibration (64)
      %%

      %% HasHMDLensConfig
      % Indicates that it's possible to get and set the HMD lens configuration on the device.
      %
      %     Capabilities.HasHMDLensConfig (128)
      %
      HasHMDLensConfig (128)
      %%

      %% CanDoMonocularCalibration
      % Indicates that monocular calibration can be performed on the device.
      %
      %     Capabilities.CanDoMonocularCalibration (256)
      %
      CanDoMonocularCalibration (256)
      %%
   end
end

%% Version
% !version
%
% COPYRIGHT !year - PROPERTY OF TOBII AB
% Copyright !year TOBII AB - KARLSROVAGEN 2D, DANDERYD 182 53, SWEDEN - All Rights Reserved.
%
% Copyright NOTICE: All information contained herein is, and remains, the property of Tobii AB and its suppliers,
% if any. The intellectual and technical concepts contained herein are proprietary to Tobii AB and its suppliers and
% may be covered by U.S.and Foreign Patents, patent applications, and are protected by trade secret or copyright law.
% Dissemination of this information or reproduction of this material is strictly forbidden unless prior written
% permission is obtained from Tobii AB.
%