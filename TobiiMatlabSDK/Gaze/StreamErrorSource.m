%% Stream Error Source
%
% Defines the error's source occured during a stream.
%
%%
classdef StreamErrorSource < EnumClass
    properties (Constant = true)
        %% User
        % The error was reported by the user.
        %
        %     type.User (0)
        %
        User = 0;
        %%
        %% StreamPump
        % The error occured while streaming.
        %
        %     type.StreamPump (1)
        %
        StreamPump = 1;
        %%
        %% SubscriptionGazeData
        % The error occured while subscribing to gaze data.
        %
        %     type.SubscriptionGazeData  (2)
        %
        SubscriptionGazeData = 2;
        %%
        %% SubscriptionExternalSignal
        % The error occured while subscribing to external signal.
        %
        %     type.SubscriptionExternalSignal  (3)
        %
        SubscriptionExternalSignal = 3;
        %%
        %% SubscriptionTimeSynchronizationData
        % The error occured while subscribing to time synchronization data.
        %
        %     type.SubscriptionTimeSynchronizationData  (4)
        %
        SubscriptionTimeSynchronizationData = 4;
        %%
        %% SubscriptionEyeImage
        % The error occured while subscribing to eye image.
        %
        %     type.SubscriptionEyeImage  (5)
        %
        SubscriptionEyeImage = 5;
        %% SubscriptionNotification
        % The error occured while subscribing to notifications.
        %
        %     type.SubscriptionNotification  (6)
        %
        SubscriptionNotification = 6;
        %%
        %% SubscriptionHMDGazeData
        % The error occured while subscribing to HMD gaze data.
        %
        %     type.SubscriptionHMDGazeData (7)
        %
        SubscriptionHMDGazeData = 7;
        %%
        %% SubscriptionUserPositionGuide
        % The error occured while subscribing to user position guide.
        %
        %     type.SubscriptionUserPositionGuide (8)
        %
        SubscriptionUserPositionGuide = 8;
        %%
    end

    methods
        function out = StreamErrorSource(in)
            if nargin > 0
                out.value =  in;
            end
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