%% EyeImage
%
% Eye image occurence depends on the eye tracker model.
% Not all eye trackers support this feature.
%
%%
classdef EyeImage
    properties (SetAccess = protected)
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

            if nargin > 0
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

end

%% See Also
% <../EyeTracker.html EyeTracker> <../Eyetracker/EyeImageType.html EyeImageType>

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