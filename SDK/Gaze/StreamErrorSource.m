%% Stream Error Source
%
% Defines the error's source occured during a stream.
%
%%
classdef StreamErrorSource < int32
   enumeration
      %% User
      % The error was reported by the user.
      %
      %     type.User (0)
      %
      User  (0)
      %%
      %% StreamPump
      % The error occured while streaming. 
      %
      %     type.StreamPump (1)
      %
      StreamPump (1)
      %%
      %% SubscriptionGazeData 
      % The error occured while subscribing to gaze data.
      %
      %     type.SubscriptionGazeData  (2)
      %
      SubscriptionGazeData (2)
      %%
      %% SubscriptionExternalSignal 
      % The error occured while subscribing to external signal.
      %
      %     type.SubscriptionExternalSignal  (3)
      %
      SubscriptionExternalSignal (3)
      %%
      %% SubscriptionTimeSynchronizationData
      % The error occured while subscribing to time synchronization data. 
      %
      %     type.SubscriptionTimeSynchronizationData  (4)
      %
      SubscriptionTimeSynchronizationData (4)
      %%
      %% SubscriptionEyeImage
      % The error occured while subscribing to eye image. 
      %
      %     type.SubscriptionEyeImage  (5)
      %
      SubscriptionEyeImage (5)
      %% SubscriptionNotification
      % The error occured while subscribing to notifications. 
      %
      %     type.SubscriptionNotification  (6)
      %
      SubscriptionNotification (6)
      %%
      %% SubscriptionHMDGazeData 
      % The error occured while subscribing to HMD gaze data.
      %
      %     type.SubscriptionHMDGazeData (7)
      %
      SubscriptionHMDGazeData (7)
      %%
   end
end

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