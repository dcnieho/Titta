%% ScreenBasedMonocularCalibration
%
% Provides methods and properties for managing monocular and bi-monocular calibrations for screen based eye trackers.
% This type of calibration is not supported by all eye trackers. Check the DeviceCapabilities of the eye tracker first!
%
%   calib = ScreenBasedMonocularCalibration(tracker)
%
%%
classdef ScreenBasedMonocularCalibration
    properties (Access = private)
        APIcall
        MexFileName
    end

    properties (SetAccess = protected)
        EyeTracker
    end

    methods
        function calib = ScreenBasedMonocularCalibration(new_tracker)

            if  ~isa(new_tracker,'EyeTracker')
                msgID = 'Calibration:WrongInput';
                msg = 'Input must be an object from EyeTracker class.';
                error(msgID, msg);
            end

            if  ~ismember(EyeTrackerCapabilities.CanDoScreenBasedCalibration,new_tracker.DeviceCapabilities) || ~ismember(EyeTrackerCapabilities.CanDoMonocularCalibration,new_tracker.DeviceCapabilities)
                msgID = 'Calibration:WrongInput';
                msg = 'Eye tracker is not capable of perform a screen based monocular calibration.';
                error(msgID,msg);
            end

            calibration_folder = 'ScreenBasedCalibration';
            if exist(calibration_folder,'dir') == 7 && exist('CalibrationResult','class') == 0
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
        % Collects data for a calibration point for the selected eye(s).
        % The point argument is the point on the display the user is assumed to be looking at and is given in
        % the active display area coordinate system.
        %
        % Parameters: coordinates (x,y) of the calibration point.
        % Parameters: eye_to_calibrate, an instance of the enum <EyeTracker/SelectedEye.html SelectedEye> selected eye to calibrate
        %
        % Returns: an instance of the class <ScreenBasedCalibration/CalibrationStatus.html CalibrationStatus>
        %
        %   calib.collect_data(coordinates,eye_to_calibrate)
        %
        function status = collect_data(calib,coordinates,eye_to_calibrate)
            result = calib.APIcall('ScreenBasedMonocularCalibrationCollectData',calib.EyeTracker.CoreEyeTracker,coordinates,int32(eye_to_calibrate));
            status = CalibrationStatus(result);
        end

        %% Discard Data
        % Removes the collected data for the specified eye(s) and calibration point.
        %
        % Parameters: coordinates (x,y) of the calibration point.
        % Parameters: eye_to_calibrate, an instance of the enum <EyeTracker/SelectedEye.html SelectedEye> selected eye to calibrate
        %
        %   calib.discard_data(coordinates,eye_to_calibrate)
        %
        %
        function discard_data(calib,coordinates,eye_to_calibrate)
            calib.APIcall('ScreenBasedMonocularCalibrationDiscardData',calib.EyeTracker.CoreEyeTracker,coordinates,int32(eye_to_calibrate));
        end

        %% Compute and Apply Calibration
        % Uses the collected data and tries to compute calibration parameters. If the calculation is successful,
        % the result is applied to the eye tracker. If there is insufficient data to compute a new calibration or
        % if the collected data is not good enough then the calibration fails and will not be applied.
        %
        % Returns: an instance of the class <ScreenBasedCalibration/CalibrationResult.html CalibrationResult>
        %
        %   calib.compute_and_apply()
        %
        function result = compute_and_apply(calib)
            [point,left,right,validity,status] = calib.APIcall('ScreenBasedMonocularCalibrationComputeAndApply',calib.EyeTracker.CoreEyeTracker);

            [target_points,~,ic] = unique(point,'rows','stable');

            status = CalibrationStatus(status);

            if status == CalibrationStatus.Failure
                target_points = [];
            end

            points(size(target_points,1)) = CalibrationPoint;

            for i=1:size(target_points,1)
                points(i) = CalibrationPoint(target_points(i,:),left(ic==i,:),right(ic==i,:),validity(ic==i,:));
            end

            result = CalibrationResult(points, status);

        end

    end
end

%% Code Example
% <include>SampleCode/MonocularCalibrationSample_publish.m</include>

%% See Also
% <EyeTracker.html Eyetracker>, <ScreenBasedCalibration/CalibrationEyeData.html...
% CalibrationEyeData>, <ScreenBasedCalibration/CalibrationEyeValidity.html...
% CalibrationEyeValidity>, <ScreenBasedCalibration/CalibrationPoint.html CalibrationPoint>,
% <ScreenBasedCalibration/CalibrationResult.html CalibrationResult>, <ScreenBasedCalibration/CalibrationStatus.html
% CalibrationStatus>

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
