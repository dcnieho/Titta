%% EyeTracker
%
% Provides methods and properties to manage and get data
% from an eye tracker
%
%%
classdef EyeTracker
    properties (Access = private)
        APIcall
    end

    %% Protected Properties
    properties (SetAccess = protected)
        %% Name
        % Gets the name of the eye tracker.output_folder
        %
        %   eyetracker.Name
        %
        Name
    end
    %% Readonly Properties
    properties (SetAccess = protected)
        %% Serial Number
        % Gets the serial number of the eye tracker. All physical eye
        % trackers have a unique serial number.
        %
        %   eyetracker.SerialNumber
        %
        SerialNumber
        %% Model
        % 	Gets the model of the eye tracker.
        %
        %   eyetracker.Model
        %
        Model
        %% Firmware Version
        % Gets the firmware version of the eye tracker.
        %
        %   eyetracker.FirmwareVersion
        %
        FirmwareVersion
        %% Runtime Version
        % Gets the runtime version of the eye tracker.
        %
        %   eyetracker.RuntimeVersion
        %
        RuntimeVersion
        %% Address
        % Gets the address of the eye tracker device
        %
        %   eyetracker.Address
        %
        Address
        %% DeviceCapabilities
        % Gets the capabilities of the device.
        %
        %   eyetracker.DeviceCapabilities
        %
        DeviceCapabilities

    end
    properties (Access = {?ScreenBasedCalibration;?ScreenBasedMonocularCalibration;?HMDBasedCalibration})
        CoreEyeTracker
        MexFileName
    end

    methods
        function is_eq = eq(tracker1, tracker2)
            if isempty(tracker1) || isempty(tracker2) || any(size(tracker1)~=size(tracker2))
                is_eq = false;
            else
                is_eq = [tracker1.SerialNumber] ~= [tracker2.SerialNumber];
            end
        end

       function is_ne = ne(tracker1, tracker2)
            if isempty(tracker1) || isempty(tracker2) || any(size(tracker1)~=size(tracker2))
                is_ne = true;
            else
                is_ne = [tracker1.SerialNumber] == [tracker2.SerialNumber];
            end
       end

        function sorted = sort(trackers)
            if all(size(trackers) == [1, 1])
                sorted = trackers;
            else
                [~,idx]=sort({trackers.SerialNumber});
                sorted=trackers(idx);
            end
        end

        function diff = setdiff(trackers1, trackers2)

            diff_serials = setdiff({trackers1.SerialNumber},{trackers2.SerialNumber});
            diff(size(diff_serials,2), 1) = EyeTracker;
            j = 1;
            for i=1:size(trackers1,2)
               if any(ismember(diff_serials,trackers1(i).SerialNumber))
                   diff(j) = trackers1(i);
                   j = j+1;
               end
            end

        end

    end

    %% Methods
    methods
        function tracker = EyeTracker(new_tracker)
            if nargin > 0
                tracker.APIcall = str2func(new_tracker.mex_file_name);
                tracker.MexFileName = new_tracker.mex_file_name;

                tracker.Name = new_tracker.device_name;
                tracker.Address = new_tracker.address;
                tracker.SerialNumber = new_tracker.serial_number;
                tracker.Model = new_tracker.model;
                tracker.FirmwareVersion = new_tracker.firmware_version;
                tracker.RuntimeVersion = new_tracker.runtime_version;
                tracker.CoreEyeTracker = new_tracker.core_eyetracker;

                warning('off', 'all');
                cap = fieldnames(EyeTrackerCapabilities);
                tracker.DeviceCapabilities = [];
                for i=1:length(cap)

                    if ~strcmp(cap{i}, 'value') && bitand(new_tracker.device_capabilities, EyeTrackerCapabilities.(cap{i})) ~= 0
                        tracker.DeviceCapabilities = [tracker.DeviceCapabilities, EyeTrackerCapabilities.(cap{i})];
                    end
                end
                warning('on', 'all');
            end
        end

        %% Set Device Name
        % Changes the device name. This is not supported by all eye trackers.
        %
        % Parameters: string with new desired device name
        % Returns: instance of the class <EyeTracker.html EyeTracker> with the updated device name.
        %
        % <include>SampleCode/SetDeviceName_publish.m</include>
        %
        function tracker = set_device_name(tracker,name)
            tracker.APIcall('SetDeviceName',tracker.CoreEyeTracker,name);
            tracker.Name = name;
        end

        %% Get All Gaze Output Frequencies
        % Gets an array with the available gaze output frequencies.
        %
        % Returns: array of doubles with the available gaze output frequencies.
        %
        % <include>SampleCode/GetAllGazeOutputFrequencies_publish.m</include>
        %
        function gaze_output_frequencies = get_all_gaze_output_frequencies(tracker)
            gaze_output_frequencies = tracker.APIcall('GetAllGazeOutputFrequencies',tracker.CoreEyeTracker);
        end

        %% Get Gaze Output Frequency
        % Gets the current gaze output frequency.
        %
        % Returns: double with the current gaze output frequency.
        %
        % <include>SampleCode/GetGazeOutputFrequency_publish.m</include>
        %
        function gaze_output_frequency = get_gaze_output_frequency(tracker)
            gaze_output_frequency = tracker.APIcall('GetGazeOutputFrequency',tracker.CoreEyeTracker);
        end

        %% Set Gaze Output Frequency
        % Sets the current gaze output frequency
        %
        % Parameters: double with the desired gaze output frequency.
        %
        % <include>SampleCode/SetGazeOutputFrequency_publish.m</include>
        %
        function set_gaze_output_frequency(tracker,gaze_output_frequency)
            tracker.APIcall('SetGazeOutputFrequency',tracker.CoreEyeTracker,gaze_output_frequency);
        end

        %% Get All Eye Tracking Modes
        % Gets a cell array with the available eye tracking modes.
        %
        % Returns: cell of strings with the available eye tracking modes.
        %
        % <include>SampleCode/GetAllEyeTrackingModes_publish.m</include>
        %
        function modes = get_all_eye_tracking_modes(tracker)
            modes = tracker.APIcall('GetAllEyeTrackingModes',tracker.CoreEyeTracker);
        end

        %% Get Eye Tracking Mode
        % Gets the current eye tracking mode.
        %
        % Returns: string with the current eye tracking mode.
        %
        % <include>SampleCode/GetEyeTrackingMode_publish.m</include>
        %
        function mode = get_eye_tracking_mode(tracker)
            mode = tracker.APIcall('GetEyeTrackingMode',tracker.CoreEyeTracker);
        end

        %% Set Eye Tracking Mode
        % Sets the current eye tracking mode.
        %
        % Parameters: string with the desired eye tracking modes.
        %
        % <include>SampleCode/SetEyeTrackingMode_publish.m</include>
        %
        function set_eye_tracking_mode(tracker,mode)
            if iscell(mode)
                mode = mode{:};
            end
            tracker.APIcall('SetEyeTrackingMode',tracker.CoreEyeTracker,mode);
        end

        %% Retreive Calibration Data
        % Gets the calibration data, which is stored in the active
        % calibration buffer.
        % This data can be saved to a file for later use.
        %
        % Returns: array of uint8 containing the calibration data.
        %
        % <include>SampleCode/RetrieveCalibrationData_publish.m</include>
        %
        function data = retrieve_calibration_data(tracker)
            data = tracker.APIcall('RetrieveCalibrationData',tracker.CoreEyeTracker);
        end

        %% Apply Calibration Data
        % Sets the provided calibration, which means copying the data
        % from the calibration to into the active calibration buffer.
        %
        % Parameters: array of uint8 containing the calibration data.
        %
        % <include>SampleCode/ApplyCalibrationData_publish.m</include>
        %
        function apply_calibration_data(tracker,data)
            tracker.APIcall('ApplyCalibrationData',tracker.CoreEyeTracker,uint8(data));
        end

        %% Get Time Synchronization Data
        % Provides data for the time synchronization.
        % Only supports streaming from one eyetracker at a time.
        % If there is the need to use a different eyetracker,
        % use the method stop_time_sync_data first and start a new data
        % stream for the new eyetracker.
        % Returns a class with 3 different time stamps:
        %
        % SystemRequestTimeStamp: time stamp when the computer sent the
        %                           request to the eye tracker.
        %
        % DeviceTimeStamp: time stamp when the eye tracker received the
        %                    request, according to the eye trackers clock.
        %
        % SystemResponseTimeStamp: time stamp when the computer received
        %                            the response from the eye tracker.
        %
        % If no input is provided an array of TimeSynchronizationReference
        % instances will be returned. If an input 'flat' is provided the
        % function will return a struct with arrays of the collected data
        % for each individual property of the time synchronization data.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be returned.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <EyeTracker/TimeSynchronizationReference.html TimeSynchronizationReference>.
        %
        % <include>SampleCode/GetTimeSynchronizationData_publish.m</include>
        %
        function output = get_time_sync_data(tracker, mode)
            if nargin == 1
               mode = 'class';
            end

            time_sync_data = tracker.APIcall('GetTimeSynchronizationData',tracker.CoreEyeTracker);

            if isfield(time_sync_data, 'error')
               output = StreamError(time_sync_data);
               tracker.stop_time_sync_data();
               return
            end

            if strcmp(mode,'flat')
                output = time_sync_data;
                return
            end

            data_size = numel(time_sync_data.device_time_stamp);

            if data_size > 0
                output(data_size, 1) = TimeSynchronizationReference;
                for i=1:data_size
                    output(i) = TimeSynchronizationReference(...
                        time_sync_data.system_request_time_stamp(i),...
                        time_sync_data.device_time_stamp(i),...
                        time_sync_data.system_response_time_stamp(i));
                end
            else
                output = [];
            end

        end

        %% Stop Time Synchronization Data
        % Stops the current time synchronization stream.
        %
        % <include>SampleCode/GetTimeSynchronizationData_publish.m</include>
        %
        function stop_time_sync_data(tracker)
            tracker.APIcall('StopTimeSynchronizationData',tracker.CoreEyeTracker);
        end

        %% Get Gaze Data
        % Provides data for gaze.
        % Time synchronized gaze is not supported on all eye trackers,
        % other eye trackers need additional license to activate this
        % feature.
        % Only supports streaming from one eyetracker at a time.
        %
        % If there is the need to use a different eyetracker,
        % use the method stop_gaze_data first and start a new data
        % stream for the new eyetracker.
        %
        % It is possible to check the validity of the data received using
        % the validity field. Complementary, if some specific data field
        % is invalid then it will contain nan (Not a number) as its value.
        %
        % If no input is provided an array of GazeData instances will be
        % returned. If an input 'flat' is provided the function will return
        % a struct with arrays of the collected data for each individual
        % property of the gaze data.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be returned.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <Gaze/GazeData.html GazeData>.
        %
        % <include>SampleCode/GetGazeData_publish.m</include>
        %
        function output = get_gaze_data(tracker, mode)
            if nargin == 1
               mode = 'class';
            end

            gaze_data = tracker.APIcall('GetGazeData',tracker.CoreEyeTracker);

            if isfield(gaze_data, 'error')
               output = StreamError(gaze_data);
%                tracker.stop_gaze_data();
               return
            end

            if strcmp(mode,'flat')
                output = gaze_data;
                return
            end

            data_size = size(gaze_data.device_time_stamp,1);

            if data_size > 0
                output(data_size, 1) = GazeData;
                for i=1:data_size
                    output(i) = GazeData(gaze_data.device_time_stamp(i),...
                        gaze_data.system_time_stamp(i),...
                        gaze_data.left_gaze_point_on_display_area(i,:),...
                        gaze_data.left_gaze_point_in_user_coordinate_system(i,:),...
                        gaze_data.left_gaze_point_validity(i),...
                        gaze_data.left_pupil_diameter(i),...
                        gaze_data.left_pupil_validity(i),...
                        gaze_data.left_gaze_origin_in_user_coordinate_system(i,:),...
                        gaze_data.left_gaze_origin_in_trackbox_coordinate_system(i,:),...
                        gaze_data.left_gaze_origin_validity(i),...
                        gaze_data.right_gaze_point_on_display_area(i,:),...
                        gaze_data.right_gaze_point_in_user_coordinate_system(i,:),...
                        gaze_data.right_gaze_point_validity(i),...
                        gaze_data.right_pupil_diameter(i),...
                        gaze_data.right_pupil_validity(i),...
                        gaze_data.right_gaze_origin_in_user_coordinate_system(i,:),...
                        gaze_data.right_gaze_origin_in_trackbox_coordinate_system(i,:),...
                        gaze_data.right_gaze_origin_validity(i));
                end
            else
                output = [];
            end
        end

        %% Stop Gaze Data
        % Stops the current gaze data stream.
        %
        % <include>SampleCode/GetGazeData_publish.m</include>
        %
        function stop_gaze_data(tracker)
            tracker.APIcall('StopGazeData',tracker.CoreEyeTracker);
        end


        %% Get User Position Guide
        % Provides data for user position guide.
        % Only supports streaming from one eyetracker at a time.
        %
        % If there is the need to use a different eyetracker,
        % use the method stop_user_position_guide first and start a new data
        % stream for the new eyetracker.
        %
        % It is possible to check the validity of the data received using
        % the validity field. Complementary, if some specific data field
        % is invalid then it will contain nan (Not a number) as its value.
        %
        % If data is available an instance of UserPositionGuide will be returned,
        % otherwise the output will be empty.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be returned.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <Gaze/UserPositionGuide.html UserPositionGuide>.
        %
        % <include>SampleCode/GetUserPositionGuide_publish.m</include>
        %
        function output = get_user_position_guide(tracker)
            user_position_guide = tracker.APIcall('GetUserPositionGuide',tracker.CoreEyeTracker);

            if isfield(user_position_guide, 'error')
               output = StreamError(user_position_guide);
               tracker.stop_user_position_guide();
               return
            end

            if isempty(user_position_guide.left_user_position)
                output = [];
            else
                output = UserPositionGuide(user_position_guide.left_user_position,...
                    user_position_guide.left_user_position_validity,...
                    user_position_guide.right_user_position,...
                    user_position_guide.right_user_position_validity);
            end
        end

        %% Stop User Position
        % Stops the current user position guide stream.
        %
        % <include>SampleCode/GetUserPositionGuide_publish.m</include>
        %
        function stop_user_position_guide(tracker)
            tracker.APIcall('StopUserPositionGuide',tracker.CoreEyeTracker);
        end

        %% Get HMD Gaze Data
        % Provides data for HMD gaze.
        % Only supports streaming from one eyetracker at a time.
        %
        % If there is the need to use a different eyetracker,
        % use the method stop_hmd_gaze_data first and start a new data
        % stream for the new eyetracker.
        %
        % It is possible to check the validity of the data received using
        % the validity field. Complementary, if some specific data field
        % is invalid then it will contain nan (Not a number) as its value.
        %
        % If no input is provided an array of HMDGazeData instances will be
        % returned. If an input 'flat' is provided the function will return
        % a struct with arrays of the collected data for each individual
        % property of the gaze data.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be returned.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <Gaze/HMDGazeData.html HMDGazeData>.
        %
        % <include>SampleCode/GetHMDGazeData_publish.m</include>
        %
        function output = get_hmd_gaze_data(tracker, mode)
            if nargin == 1
               mode = 'class';
            end

            hmd_gaze_data = tracker.APIcall('GetHMDGazeData',tracker.CoreEyeTracker);

            if isfield(hmd_gaze_data, 'error')
               output = StreamError(hmd_gaze_data);
               tracker.stop_hmd_gaze_data();
               return
            end

            if strcmp(mode,'flat')
                output = hmd_gaze_data;
                return
            end

            data_size = size(hmd_gaze_data.device_time_stamp,1);

            if data_size > 0
                output(data_size, 1) = HMDGazeData;
                for i=1:data_size
                    output(i) = HMDGazeData(hmd_gaze_data.device_time_stamp(i),...
                        hmd_gaze_data.system_time_stamp(i),...
                        hmd_gaze_data.left_gaze_direction_unit_vector(i,:),...
                        hmd_gaze_data.left_gaze_direction_validity(i),...
                        hmd_gaze_data.left_gaze_origin_position_in_hmd_coordinates(i,:),...
                        hmd_gaze_data.left_gaze_origin_validity(i),...
                        hmd_gaze_data.left_pupil_diameter(i),...
                        hmd_gaze_data.left_pupil_validity(i),...
                        hmd_gaze_data.left_pupil_position_in_tracking_area(i,:),...
                        hmd_gaze_data.left_pupil_position_validity(i),...
                        hmd_gaze_data.right_gaze_direction_unit_vector(i,:),...
                        hmd_gaze_data.right_gaze_direction_validity(i),...
                        hmd_gaze_data.right_gaze_origin_position_in_hmd_coordinates(i,:),...
                        hmd_gaze_data.right_gaze_origin_validity(i),...
                        hmd_gaze_data.right_pupil_diameter(i),...
                        hmd_gaze_data.right_pupil_validity(i),...
                        hmd_gaze_data.right_pupil_position_in_tracking_area(i,:),...
                        hmd_gaze_data.right_pupil_position_validity(i));
                end
            else
                output = [];
            end

        end

        %% Stop HMD Gaze Data
        % Stops the current HMD gaze data stream.
        %
        % <include>SampleCode/GetHMDGazeData_publish.m</include>
        %
        function stop_hmd_gaze_data(tracker)
            tracker.APIcall('StopHMDGazeData',tracker.CoreEyeTracker);
        end

        %% Get External Signal Data
        % Provides data for the ExternalSignal
        % New data is delivered when the value of the external signal port on the eye tracker
        % device changes, otherwise an empty array will be returned.
        % Not all eye trackers have output trigger port.
        % The output feature could be used to synchronize the eye tracker
        % data with other devices data. The output data contains time
        % reference that matches the time reference on the time
        % synchronized gaze data.
        %
        % If no input is provided an array of ExternalSignal instances will be
        % returned. If an input 'flat' is provided the function will return
        % a struct with arrays of the collected data for each individual
        % property of the external signal data.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be return.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <EyeTracker/ExternalSignal.html ExternalSignal>.
        %
        % <include>SampleCode/GetExternalSignalData_publish.m</include>
        %
        function output = get_external_signal_data(tracker, mode)
            if nargin == 1
               mode = 'class';
            end

            external_signal_data = tracker.APIcall('GetExternalSignalData',tracker.CoreEyeTracker);

            if ~any(tracker.DeviceCapabilities==EyeTrackerCapabilities.HasExternalSignal)
                while ~isfield(external_signal_data, 'error')
                    pause(0.1);
                    external_signal_data = tracker.APIcall('GetExternalSignalData',tracker.CoreEyeTracker);
                end
            end

            if isfield(external_signal_data, 'error')
                output = StreamError(external_signal_data);
                return
            end

            if strcmp(mode,'flat')
                output = external_signal_data;
                return
            end

            data_size = size(external_signal_data.device_time_stamp,1);

            if data_size > 0
                output(data_size, 1) = ExternalSignal;
                for i=1:data_size
                    output(i) = ExternalSignal(external_signal_data.value(i),...
                        external_signal_data.device_time_stamp(i),...
                        external_signal_data.system_time_stamp(i),...
                        external_signal_data.change_type(i));
                end
            else
                output = [];
            end
        end

        %% Stop External Signal Data
        % Stops the current external_signal data stream.
        %
        % <include>SampleCode/GetExternalSignalData_publish.m</include>
        %
        function stop_external_signal_data(tracker)
            tracker.APIcall('StopExternalSignalData',tracker.CoreEyeTracker);
        end

        %% Get Eye Image
        % Provides data for the eye_image
        % Only supports streaming from one eyetracker at a time.
        % If there is the need to use a different eyetracker,
        % use the method stop_eye_image first and start a new data
        % stream for the new eyetracker.
        % Not all eye tracker models support this feature.
        %
        % If no one is listening to gaze data, the eye tracker will only
        % deliver full images, otherwise either cropped or full images will
        % be delivered depending on whether or not the eye tracker has
        % detected eyes.
        %
        % If no input is provided an array of EyeImage instances will be
        % returned. If an input 'flat' is provided the function will return
        % a struct with arrays of the collected data for each individual
        % property of the eye image data.
        %
        % If an error occurs during this stream the data returned will be
        % of the class <Gaze/StreamError.html StreamError>.
        %
        % For every call of this method an array of the collected data will be returned.
        % This means that on the first call, if no error has occurred, an empty array will be return.
        % Note that the returned data will not be the data collected since the first call of this method,
        % only the data collected in between calls will be returned.
        %
        % Returns: array with instances of class <EyeTracker/EyeImage.html EyeImage>.
        %
        % <include>SampleCode/GetEyeImage_publish.m</include>
        %
        function output = get_eye_image(tracker,mode)
            if nargin == 1
               mode = 'class';
            end

            eye_image = tracker.APIcall('GetEyeImage',tracker.CoreEyeTracker);

            if ~any(tracker.DeviceCapabilities==EyeTrackerCapabilities.HasEyeImages)
                while ~isfield(eye_image, 'error')
                    pause(0.1);
                    eye_image = tracker.APIcall('GetEyeImage',tracker.CoreEyeTracker);
                end
            end

            if isfield(eye_image, 'error')
               output = StreamError(eye_image);
               tracker.stop_eye_image();
               return
            end

            if strcmp(mode,'flat')
                output = eye_image;
                return
            end

            data_size = size(eye_image.device_time_stamp,1);

            if data_size > 0
                output(data_size, 1) = EyeImage;
                for i=1:data_size
                    output(i) = EyeImage(eye_image.system_time_stamp(i),...
                        eye_image.device_time_stamp(i),...
                        eye_image.type(i),...
                        eye_image.camera_id(i),...
                        eye_image.bits_per_pixel(i),...
                        eye_image.padding_per_pixel(i),...
                        eye_image.width(i),...
                        eye_image.height(i),...
                        eye_image.image(:,i));
                end
            else
                output = [];
            end
        end

        %% Stop Eye Image
        % Stops the current eye image stream.
        %
        % <include>SampleCode/GetEyeImage_publish.m</include>
        %
        function stop_eye_image(tracker)
            tracker.APIcall('StopEyeImage',tracker.CoreEyeTracker);
        end

        %% Apply Licenses
        % Sets a key ring of licenses for unlocking features of the
        % eye tracker. Returns a cell array with the failed licenses. If
        % all licenses were succesfully applied the cell array returned will
        % be empty.
        %
        % Parameters: array or single instance of class <EyeTracker/LicenseKey.html LicenseKey>.
        % Returns: array with instances of class <EyeTracker/FailedLicense.html FailedLicense>.
        %
        % <include>SampleCode/ApplyLicenses_publish.m</include>
        %
        function failed_licenses = apply_licenses(tracker,licenses)

            if ~isa(licenses,'LicenseKey')
                msgID = 'TOBII:WrongInput';
                msg = 'Input must be an object from LicenseKey class.';
                error(msgID,msg);
            end

            number_of_licenses = length(licenses);

            input_licenses = cell(number_of_licenses,1);

            for i=1:number_of_licenses
                input_licenses(i) = {licenses(i).KeyString};
            end

            licenses_validation = tracker.APIcall('ApplyLicenses',tracker.CoreEyeTracker,input_licenses);

            number_of_failed_licenses = sum(licenses_validation~=0);

            if number_of_failed_licenses > 0
                failed_licenses(number_of_failed_licenses) = FailedLicense;
                failed_licenses_position = find(licenses_validation);
                for i=1:number_of_failed_licenses
                        failed_licenses(i) = FailedLicense(licenses(failed_licenses_position(i)),...
                        licenses_validation(failed_licenses_position(i)));
                end
            else
                failed_licenses = [];
            end
        end

        %% Clear Applied Licenses
        % Clears any previously applied licenses
        %
        % <include>SampleCode/ClearAppliedLicenses_publish.m</include>
        %
        function clear_applied_licenses(tracker)
            tracker.APIcall('ClearAppliedLicenses',tracker.CoreEyeTracker);
        end

        %% Get Display Area
        % Gets the size and corners of the display area..
        %
        % Returns: instance of class <EyeTracker/DisplayArea.html DisplayArea>.
        %
        % <include>SampleCode/GetAndSetDisplayArea_publish.m</include>
        %
        function display_area = get_display_area(tracker)
            display = tracker.APIcall('GetDisplayArea',tracker.CoreEyeTracker);
            display_area = DisplayArea(display);
        end

        %% Set Display Area
        % Sets the display area of the eye tracker. It is strongly recommended to use Eye Tracker Manager to calculate
        % the display area coordinates as the origin of the User Coordinate System differs between eye tracker models.
        %
        % Parameters: The eye tracker's desired display area as an instance of class <EyeTracker/DisplayArea.html DisplayArea>.
        %
        % <include>SampleCode/GetAndSetDisplayArea_publish.m</include>
        %
        function set_display_area(tracker, display_area)
            if ~isa(display_area,'DisplayArea')
                msgID = 'SetDisplayArea:WrongInput';
                msg = 'Input must be an object from DisplayArea class.';
                error(msgID,msg);
            end
            tracker.APIcall('SetDisplayArea',tracker.CoreEyeTracker, struct(display_area));
        end

        %% Get Track Box
        % Gets the track box of the eye tracker.
        %
        % Returns: instance of class <EyeTracker/TrackBox.html TrackBox>.
        %
        % <include>SampleCode/GetTrackBox_publish.m</include>
        %
        function track_box = get_track_box(tracker)
            coordinates = tracker.APIcall('GetTrackBox',tracker.CoreEyeTracker);
            track_box = TrackBox(coordinates(1,:),...
                coordinates(2,:),coordinates(3,:),...
                coordinates(4,:),coordinates(5,:),...
                coordinates(6,:),coordinates(7,:),...
                coordinates(8,:));
        end

        %% Enable Notifications
        % Enables the notifications for the eyetracker.
        %
        % <include>SampleCode/EnableNotifications_publish.m</include>
        %
        function enable_notifications(tracker)
            tracker.APIcall('EnableNotifications',tracker.CoreEyeTracker);
        end

        %% Disable Notifications
        % Disables the notifications for the eyetracker.
        %
        % <include>SampleCode/EnableNotifications_publish.m</include>
        %
        function disable_notifications(tracker)
            tracker.APIcall('DisableNotifications',tracker.CoreEyeTracker);
        end

        %% Get HMD Lens Configuration
        % Gets the current lens configuration of the HMD based eye tracker.
        % The lens configuration describes how the lenses of the HMD device are positioned.
        %
        % <include>SampleCode/GetLensConfiguration_publish.m</include>
        %
        function lens_config = get_hmd_lens_configuration(tracker)
            lens = tracker.APIcall('GetHMDLensConfiguration',tracker.CoreEyeTracker);
            lens_config = HMDLensConfiguration(lens.left', lens.right');
        end

        %% Set HMD Lens Configuration
        % Sets the lens configuration of the HMD based eye tracker.
        % The lens configuration describes how the lenses of the HMD device are positioned.
        %
        % <include>SampleCode/SetLensConfiguration_publish.m</include>
        %
        function set_hmd_lens_configuration(tracker, lens_config)
            if ~isa(lens_config,'HMDLensConfiguration')
                msgID = 'SetHMDLensConfiguration:WrongInput';
                msg = 'Input must be an object from HMDLensConfiguration class.';
                error(msgID,msg);
            end
            tracker.APIcall('SetHMDLensConfiguration',tracker.CoreEyeTracker, lens_config.Left, lens_config.Right);
        end

    end
end

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