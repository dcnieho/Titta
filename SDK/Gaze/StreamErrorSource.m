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
   end
end

%% Version
% !version
%
% Copyright !year Tobii Pro
%