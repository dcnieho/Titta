%% EyeImage
%
% Eye image occurence depends on the eye tracker model.
% Not all eye trackers support this feature.
%          
%%
classdef EyeImage
    properties (SetAccess = immutable)
        %% SystemTimeStamp
        % Gets the time stamp according to the computer's internal clock.
        %
        %   eye_image.SystemTimeStamp
        %
        SystemTimeStamp
        %% DeviceTimeStamp
        % Gets the time stamp according to the eye tracker's internal clock.
        %
        %   eye_image.DeviceTimeStamp
        %
        DeviceTimeStamp 
        %% Type
        % Gets the type of eye image.
        %
        %   eye_image.Type
        %
        Type
        %% CameraId
        % Gets the source/which camera that generated the image.
        %
        %   eye_image.CameraId
        %
        CameraId 
        %% Image
        % Gets the bitmap data sent by the eye tracker.
        %
        %   eye_image.Image
        %
        Image     
    end
    
    methods
        function eye_image = EyeImage(system_time_stamp,...
                device_time_stamp,...
                type,...
                camera_id,...
                bits_per_pixel,...
                padding_per_pixel,...
                width,...
                height,...
                image)
            
            eye_image.SystemTimeStamp = system_time_stamp;
            eye_image.DeviceTimeStamp = device_time_stamp;
            eye_image.Type = EyeImageType(type);
            eye_image.CameraId = camera_id;
            
            full_bits_per_pixel = (bits_per_pixel + padding_per_pixel);
            
            image = typecast(image,['uint',num2str(full_bits_per_pixel)]);
            
            image = image(1:width*height);
            
            eye_image.Image = reshape(image,[width,height])';
            
        end
    end
    
end

%% See Also
% <../EyeTracker.html EyeTracker> <../Eyetracker/EyeImageType.html EyeImageType>

%% Version
% !version
%
% Copyright !year Tobii Pro
%