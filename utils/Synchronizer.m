classdef Synchronizer < handle
    properties (Access = protected, Hidden = true)
        remoteTimes = zeros(0,1);
        localRequestTimes = zeros(0,1);
        localResponseTimes = zeros(0,1);
    end

    properties (SetAccess=protected)
        intercept = 0;
        slope = 1;

        localFun;
        remoteFun;

        lastSyncT = 0;
    end

    properties
        nSampForFit = 15;
        nSampPerSync = 30;

        % exponential backoff params for automatic sync
        initialDelay = 5;       % ms
        maxDelay     = 15000;   % ms
        currentDelay = 0;       % ms
    end

    methods
        function this = Synchronizer(localFun, remoteFun)
            this.localFun = localFun;
            this.remoteFun= remoteFun;
        end

        function remoteT = localTimeToRemote(this, localT)
            remoteT = -(this.intercept-localT)/this.slope;
        end

        function localT = remoteTimeToLocal(this, remoteT)
            localT = this.intercept + this.slope * remoteT;
        end

        function doSync(this)
            % get new sync info
            [this.remoteTimes(end+1,1), this.localRequestTimes(end+1,1), this.localResponseTimes(end+1,1)] = ...
                getSync(this.localFun, this.remoteFun, this.nSampPerSync);

            % update line fit to determine conversion function
            % Akin to Cristian's algorithm, we estimate local time corresponding to remote time
            % by taking average of request and response timestamps (i.e., we assume equal
            % transmission delays in both directions). If that is not true, max sync error is
            % (response-request)/2
            if isscalar(this.remoteTimes)
                this.intercept = (this.localResponseTimes+this.localRequestTimes)/2 - this.remoteTimes;
                this.slope = 1.;
            else
                % collect (up to) last N remote and system times and fit a line
                systemTimes     = (this.localResponseTimes(max(1,end-this.nSampForFit):end)+this.localRequestTimes(max(1,end-this.nSampForFit):end))/2;
                lastRemotetimes = this.remoteTimes(max(1,end-this.nSampForFit):end);
                fit = [ones(length(lastRemotetimes),1) lastRemotetimes]\systemTimes;
                this.intercept = fit(1);
                this.slope = fit(2);
            end

            % record time of sync and update delay (exponential back-off)
            if this.currentDelay == 0
                this.currentDelay = this.initialDelay;
            elseif this.localFun() > this.lastSyncT+this.currentDelay*1000
                this.currentDelay = this.currentDelay*2;
            end
            if this.currentDelay > this.maxDelay
                this.currentDelay = this.maxDelay;
            end
            this.lastSyncT = this.localFun();
        end

        function doSyncIfNeeded(this)
            if this.localFun() > this.lastSyncT+this.currentDelay*1000
                this.doSync()
            end
        end

        function out = getSyncHistory(this)
            out = [this.remoteTimes, this.localRequestTimes, this.localResponseTimes];
        end
    end
end

%% helpers
function [remoteTime, localRequestTime, localResponseTime] = getSync(localFun, remoteFun, nSampPerSync)
remoteTime = 0;
localRequestTime = 0;
localResponseTime = 1e9;
% acquire nSampPerSync syncs, keep and return the one with lowest RTT
for i=1:nSampPerSync
    localReqT = localFun();
    remoteT = remoteFun();
    localRespT = localFun();

    % if has lower RTT, use this one
    if (localRespT - localReqT < localResponseTime - localRequestTime)
        localRequestTime    = localReqT;
        remoteTime          = remoteT;
        localResponseTime   = localRespT;
    end
end
end