%% ScreenBasedCalibration
%
% Provides methods and properties for managing calibrations for
% screen based eye trackers.
%
%   calib = ScreenBasedCalibration(tracker)
%
%%
classdef ScreenBasedCalibration
    properties (Access = private)
        APIcall
        MexFileName
    end

    properties (SetAccess = protected)
        EyeTracker
    end

    methods
        function calib = ScreenBasedCalibration(new_tracker)

            if  ~isa(new_tracker,'EyeTracker')
                msgID = 'Calibration:WrongInput';
                msg = 'Input must be an object from EyeTracker class.';
                error(msgID,msg);
            end

            if  ismember(EyeTrackerCapabilities.CanDoHMDBasedCalibration,new_tracker.DeviceCapabilities)
                msgID = 'Calibration:WrongInput';
                msg = 'Eye tracker is not capable of perform a screen based calibration.';
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
        % Adds data to the temporary calibration buffer for one calibration
        % point. The argument used is the point the calibration user
        % is assumed to be looking at and is given in the Active
        % Display Area Coordinate System.
        %
        % Parameters: coordinates (x,y) of the calibration point.
        %
        %   calib.collect_data(coordinates)
        %
        function status = collect_data(calib,coordinates)
            result = calib.APIcall('ScreenBasedCalibrationCollectData',calib.EyeTracker.CoreEyeTracker,coordinates);
            status = CalibrationStatus(result);
        end

        %% Discard Data
        % Removes the data associated with a specific calibration point
        % from the temporary calibration buffer.
        %
        % Parameters: coordinates (x,y) of the calibration point.
        %
        %   calib.discard_data(coordinates)
        %
        %
        function discard_data(calib,coordinates)
            calib.APIcall('ScreenBasedCalibrationDiscardData',calib.EyeTracker.CoreEyeTracker,coordinates);
        end

        %% Compute and Apply Calibration
        % Uses the collected data and tries to compute calibration
        % Parameters. If the calculation is successful, the result is
        % applied to the eye tracker. If there is insufficient data to
        % compute a new calibration or if the collected data is not good
        % enough then calibration is failed and will not be applied.
        %
        % Returns: an instance of the class <ScreenBasedCalibration/CalibrationResult.html CalibrationResult>
        %
        %   calib.compute_and_apply()
        %
        function result = compute_and_apply(calib)
            [point,left,right,validity,status] = calib.APIcall('ScreenBasedCalibrationComputeAndApply',calib.EyeTracker.CoreEyeTracker);

            [target_points,~,ic] = unique(point,'rows','stable');

            status = CalibrationStatus(status);

            if status ~= CalibrationStatus.Success
                target_points = [];
            end

            if size(target_points, 1) > 0
                points(size(target_points,1)) = CalibrationPoint;
            else
                points = [];
            end

            for i=1:size(target_points,1)
                points(i) = CalibrationPoint(target_points(i,:),left(ic==i,:),right(ic==i,:),validity(ic==i,:));
            end

            result = CalibrationResult(points,status);

        end


    end
end

%% Code Example
% <include>SampleCode/CalibrationSample_publish.m</include>

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
