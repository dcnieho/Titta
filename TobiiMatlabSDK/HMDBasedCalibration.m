%% HMDBasedCalibration
%
% Provides methods and properties for managing calibrations
% for HMD based eye trackers.
%
%   calib = HMDBasedCalibration(tracker)
%
%%
classdef HMDBasedCalibration
    properties (Access = private)
        APIcall
        MexFileName
    end

    properties (SetAccess = protected)
        EyeTracker
    end

    methods
        function calib = HMDBasedCalibration(new_tracker)

            if  ~isa(new_tracker,'EyeTracker')
                msgID = 'Calibration:WrongInput';
                msg = 'Input must be an object from EyeTracker class.';
                error(msgID,msg);
            end

            if  ~ismember(Capabilities.CanDoHMDBasedCalibration,new_tracker.DeviceCapabilities)
                msgID = 'Calibration:WrongInput';
                msg = 'Eye tracker is not capable of perform a HMD based calibration.';
                error(msgID,msg);
            end

            calibration_folder = 'HMDBasedCalibration';
            if exist(calibration_folder,'dir') == 7 && exist('HMDCalibrationResult','class') == 0
                addpath(calibration_folder);
            end

            calib.EyeTracker = new_tracker;

            calib.MexFileName = new_tracker.MexFileName;

            calib.APIcall = str2func(calib.MexFileName);

        end

        %% Enter Calibration Mode
        % Enters the Calibration Mode and the Eye Tracker is made ready for
        % collecting data and calculating new calibrations.
        %
        %   calib.enter_calibration_mode()
        %
        function enter_calibration_mode(calib)
            calib.APIcall('EnterCalibrationMode',calib.EyeTracker.CoreEyeTracker);
        end

        %% Leave Calibration Mode
        % Leaves the Calibration Mode.
        %
        %   calib.leave_calibration_mode()
        %
        function leave_calibration_mode(calib)
            calib.APIcall('LeaveCalibrationMode',calib.EyeTracker.CoreEyeTracker);
        end

        %% Collect Data
        % Starts collecting data for a calibration point. The argument used is the
        % point the calibration user is assumed to be looking at and is given
        % in the HMD coordinate system.
        % Parameters: coordinates (x, y, x) of the calibration point.
        %
        %   calib.collect_data(coordinates)
        %
        function status = collect_data(calib,coordinates)
            result = calib.APIcall('HMDBasedCalibrationCollectData',calib.EyeTracker.CoreEyeTracker,double(coordinates));
            status = HMDCalibrationResult(result);
        end

        %% Compute and Apply Calibration
        % Uses the collected data and tries to compute calibration parameters.
        % If the calculation is successful, the result is applied to the eye tracker.
        % If there is insufficient data to compute a new calibration or if the collected data is
        % not good enough then calibration is failed and will not be applied.
        %
        % Returns: an instance of the class <HMDBasedCalibration/HMDCalibrationResult.html HMDCalibrationResult>
        %
        %   calib.compute_and_apply()
        %
        function result = compute_and_apply(calib)
            status = calib.APIcall('HMDBasedCalibrationComputeAndApply',calib.EyeTracker.CoreEyeTracker);
            result = HMDCalibrationResult(status);
        end


    end
end

%% Code Example
% <include>SampleCode/HMDCalibrationSample_publish.m</include>

%% See Also
% <EyeTracker.html Eyetracker>, <HMDBasedCalibration/HMDCalibrationResult.html HMDCalibrationResult>,
% <HMDBasedCalibration/HMDCalibrationStatus.html CalibrationStatus>

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
