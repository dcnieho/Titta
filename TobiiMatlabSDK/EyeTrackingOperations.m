%% EyeTrackingOperations
%
% Provides static methods for searching for eye trackers as well as
% connecting directly to a specific eye tracker. The eye tracker object(s)
% returned can then be used to manipulate the eye trackers and read eye
% tracker data. This is the entry point for the SDK users.
%
%%
classdef EyeTrackingOperations

    properties (Access = private)
        BITNESS = '';
        APIcall
        MexFileName = 'tobiiresearch';
    end

    methods
        %%
        %   Tobii = EyeTrackingOperations()
        function Tobii = EyeTrackingOperations(mex_folder)
            if nargin == 0
                mex_folder = '';
            end

            isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

            [platform, maxArraySize]=computer;

            is64bitComputer = (isOctave && ~isempty(strfind(platform, 'x86_64'))) || (~isOctave && maxArraySize > 2^31);

            if is64bitComputer
                Tobii.BITNESS = '64';
            else
                Tobii.BITNESS = '32';
            end

            if isOctave
                if ispc
                    arch = 'win';
                elseif ismac
                    arch = 'mac';
                elseif isunix
                    arch = 'linux';
                end
                library_path = fullfile('lib',Tobii.BITNESS,arch);
            else
                library_path = fullfile('lib',Tobii.BITNESS);
            end

            folders_to_add = {'Gaze';'EyeTracker';library_path;mex_folder};

            for i=1:length(folders_to_add)
                add_folder_to_path(folders_to_add{i})
            end

            % (3) - found mex file
            if exist(Tobii.MexFileName, 'file') ~= 3
                msgID = 'EyeTrackingOperations:mex_file';
                msg = sprintf('Could not find the mex file: %s', Tobii.MexFileName);
                error(msgID, msg);
            end

            Tobii.APIcall = str2func(Tobii.MexFileName);

        end
        %% Get System Time Stamp
        % Retrieves the time stamp from the system clock in microseconds.
        %
        % Returns: int64 time stamp in microseconds
        %
        % <include>SampleCode/GetSystemTimeStamp_publish.m</include>
        %
        function time_stamp_us = get_system_time_stamp(Tobii)
            time_stamp_us = Tobii.APIcall('GetSystemTimeStamp');
        end
        %% Get SDK Version
        % Retrieves the current version of the SDK.
        %
        % Returns: string with version of the sdk
        %
        % <include>SampleCode/GetSDKVersion_publish.m</include>
        %
        function version = get_sdk_version(Tobii)
            version = Tobii.APIcall('GetSDKVersion');
        end

        %% Find All Eye Trackers
        % Finds eye trackers connected to the computer or the network.
        % Please note that subsequent calls to find_all_eyetrackers() may
        % return the eye trackers in a different order.
        %
        % Returns: array with instances of the class <Eyetracker.html EyeTracker>
        %
        % <include>SampleCode/FindAllEyeTrackers_publish.m</include>
        %
        function retval = find_all_eyetrackers(Tobii)
            eyetrackers = Tobii.APIcall('FindAllEyeTrackers');

            number_of_eyetrackers = size(eyetrackers,1);

            if number_of_eyetrackers > 0
                retval(size(eyetrackers,1), 1) = EyeTracker;
                for i=1:size(eyetrackers,1)
                    eyetrackers(i).mex_file_name = Tobii.MexFileName;
                    retval(i) = EyeTracker(eyetrackers(i));
                end
            else
                retval = [];
            end
        end
        %% GetEyeTracker
        % Gets an eye tracker object that has the specified adress.
        %
        % Parameters: string with address of the desired eye tracker.
        % Returns: instance of the class <Eyetracker.html EyeTracker>
        %
        % <include>SampleCode/GetEyeTracker_publish.m</include>
        %
        function retval = get_eyetracker(Tobii,address)
            eyetracker = Tobii.APIcall('EyeTrackerGet',address);
            if size(eyetracker,1) == 1
                eyetracker.mex_file_name = Tobii.MexFileName;
                retval = EyeTracker(eyetracker);
            end
        end

        %%
        function delete(Tobii)
            clear(Tobii.MexFileName);
        end
    end

end

%% See Also
% <EyeTracker.html EyeTracker>

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