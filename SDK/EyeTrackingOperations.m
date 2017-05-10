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
        BITNESS = ''
         APIcall
        MexFileName = 'tobiiresearch'
    end
    
    methods
        %%
        %   Tobii = EyeTrackingOperations()
        function Tobii = EyeTrackingOperations
            [~,maxArraySize]=computer;
            is64bitComputer=maxArraySize> 2^31;
            if is64bitComputer
                Tobii.BITNESS = '64';
            else
                Tobii.BITNESS = '32';
            end
            
            mex_folder = [pwd,'/../../../Stage/MatlabRelease',Tobii.BITNESS];
            
            folders_to_add = {'Gaze';'EyeTracker';fullfile('lib',Tobii.BITNESS);mex_folder};
            
            for i=1:length(folders_to_add)
                add_folder_to_path(folders_to_add{i})
            end
            
            % (3) - found mex file
            if exist(Tobii.MexFileName,'file') ~= 3
                msgID = 'EyeTrackingOperations:mex_file';
                msg = sprintf('Could not find the mex file: %s', Tobii.MexFileName);
                baseException = MException(msgID,msg);
                throw(baseException);
            end  

            Tobii.APIcall = str2func(['@',Tobii.MexFileName]);
            
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
            retval = EyeTracker.empty(size(eyetrackers,1),0);
            for i=1:size(eyetrackers,1)
                retval(i) = EyeTracker(eyetrackers(i));
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
                retval = EyeTracker(eyetracker);
            end
        end        
        
        %%
        function delete(Tobii)
            clear(Tobii.MexFileName);
        end
    end
    
end

function add_folder_to_path(folder)
    if ispc
        NotinPath = isempty(strfind(lower(path),lower(folder)));
    else
        NotinPath = isempty(strfind(path,folder));
    end

    if exist(folder,'dir') == 7 && NotinPath
        addpath(folder);
    end
end

%% See Also
% <EyeTracker.html EyeTracker>


%% Version
%
% !version
%
% Copyright !year Tobii Pro
%