%% EyeTracker
%
% Provides methods and properties to manage and get data
% from an eye tracker
%
%%
classdef EyeTracker    
    properties (Access = private)
        APIcall
        MexFileName = 'tobiiresearch'
    end
    
    %% Protected Properties
    properties (SetAccess = protected)  
        %% Name
        % Gets the name of the eye tracker.
        %
        %   eyetracker.Name
        %
        Name
    end
    %% Readonly Properties
    properties (SetAccess = immutable)
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
    properties (Access = {?ScreenBasedCalibration})
        CoreEyeTracker
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
            
            diff = EyeTracker.empty(size(diff_serials,2),0);
            
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
            
            tracker.APIcall = str2func(['@',tracker.MexFileName]);
            
            tracker.Name = new_tracker.device_name;
            tracker.Address = new_tracker.address;
            tracker.SerialNumber = new_tracker.serial_number;
            tracker.Model = new_tracker.model;
            tracker.FirmwareVersion = new_tracker.firmware_version;
            tracker.CoreEyeTracker = new_tracker.core_eyetracker;
            
            cap = enumeration('Capabilities');
            tracker.DeviceCapabilities = [];
            for i=1:length(cap)
                if bitand(new_tracker.device_capabilities,cap(i)) ~= 0
                    tracker.DeviceCapabilities = [tracker.DeviceCapabilities,Capabilities(cap(i))];
                end
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
        % Provides data for the for time synchronization.
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
        % If an error occurs durring this stream the data returned will be 
        % of the class <Gaze/StreamError.html StreamError>.
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
                
            output = TimeSynchronizationReference.empty(size(time_sync_data.device_time_stamp,1),0);

            for i=1:size(time_sync_data.device_time_stamp,1)
                output(i) = TimeSynchronizationReference(...
                    time_sync_data.system_request_time_stamp(i),...
                    time_sync_data.device_time_stamp(i),...
                    time_sync_data.system_response_time_stamp(i));
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
        % If an error occurs durring this stream the data returned will be 
        % of the class <Gaze/StreamError.html StreamError>.
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
               tracker.stop_gaze_data();
               return
            end
            
            if strcmp(mode,'flat')
                output = gaze_data;
                return
            end
            
            output = GazeData.empty(size(gaze_data.device_time_stamp,1),0);
            for i=1:size(gaze_data.device_time_stamp,1)
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
            
        end
        
        %% Stop Gaze Data
        % Stops the current gaze data stream.
        %
        % <include>SampleCode/GetGazeData_publish.m</include>
        %
        function stop_gaze_data(tracker)
            tracker.APIcall('StopGazeData',tracker.CoreEyeTracker);
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
        % If an error occurs durring this stream the data returned will be 
        % of the class <Gaze/StreamError.html StreamError>.
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
            
            if ~any(tracker.DeviceCapabilities==Capabilities.HasExternalSignal)
                while ~isfield(external_signal_data, 'error')
                    pause(0.1);
                    external_signal_data = tracker.APIcall('GetExternalSignalData',tracker.CoreEyeTracker);
                end
            end
            
            if isfield(external_signal_data, 'error')
               output = StreamError(external_signal_data);
               tracker.stop_external_signal_data();
               return
            end
            
            if strcmp(mode,'flat')
                output = external_signal_data;
                return
            end
            
            output = ExternalSignal.empty(size(external_signal_data.device_time_stamp,1),0);
            for i=1:size(external_signal_data.device_time_stamp,1)
                output(i) = ExternalSignal(external_signal_data.value(i),...
                    external_signal_data.device_time_stamp(i),...
                    external_signal_data.system_time_stamp(i),...
                    external_signal_data.change_type(i));
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
        % If an error occurs durring this stream the data returned will be 
        % of the class <Gaze/StreamError.html StreamError>.
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

            if ~any(tracker.DeviceCapabilities==Capabilities.HasEyeImages)
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
            
            output = EyeImage.empty(size(eye_image.system_time_stamp,1),0);
            for i=1:size(eye_image.system_time_stamp,1)
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
                baseException = MException(msgID,msg);
                throw(baseException); 
            end
            
            number_of_licenses = length(licenses);
            
            input_licenses = cell(number_of_licenses,1);
            
            for i=1:number_of_licenses
                input_licenses(i) = {licenses(i).KeyString};
            end
    
            licenses_validation = tracker.APIcall('ApplyLicenses',tracker.CoreEyeTracker,input_licenses);
            
            number_of_failed_licenses = sum(licenses_validation~=0);
            
            failed_licenses = FailedLicense.empty(number_of_failed_licenses,0);
            failed_licenses_position = find(licenses_validation);
            for i=1:number_of_failed_licenses
                    failed_licenses(i) = FailedLicense(licenses(failed_licenses_position(i)),...
                    licenses_validation(failed_licenses_position(i)));
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
        % <include>SampleCode/GetDisplayArea_publish.m</include>
        %
        function display_area = get_display_area(tracker)
            display = tracker.APIcall('GetDisplayArea',tracker.CoreEyeTracker);
            display_area = DisplayArea(display);
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
    end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%