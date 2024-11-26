% online filter for eye-movement (x,y) data
% Pontus Olsson - Real-time and Offline Filters for Eye Tracking
% XR-EE-RT 2007:011
% http://kth.diva-portal.org/smash/get/diva2:573446/FULLTEXT01.pdf

classdef OlssonFilter < handle
    % public properties: settings
    properties 
        timeWindow;
        distT;
        Tfast;      % time constant for fast phase movement
        Tslow;      % time constant for slow phase movement
        TresetTime; % time during which T exponential resets from Tfast to Tslow
    end
    
    % internals
    properties (Access = private, Hidden = true)
        x;
        y;
        t;
        tLastStep;
        interval;
        buffer;
        Tacc;       % acceleration of exponential reset curve
    end
       
    methods % public
        %% Constructor
        function obj = OlssonFilter()
            obj.setDefaults();
            obj.recalculateResetAcc();
            obj.reset();
        end
        
        %% Destructor
        function delete(~)
            % no-op
        end

        %% methods
        function reset(obj)
            obj.x          = NaN;
            obj.y          = NaN;
            obj.t          = 0;
            obj.tLastStep  = -inf;
            obj.interval   = 0;
            obj.buffer     = [];
        end
        
        function [fx,fy] = addSample(obj,ts,x,y)
            % ts: timestamp in ms
            %  x: horizontal x position
            %  y: horizontal y position
            
            if isnan(obj.x) && isnan(obj.y) && obj.t == 0
                obj.x = x;
                obj.y = y;
                obj.t = obj.Tslow;
            end

            % if nan input, just return last value
            % TODO: optionally, if obj last value is too old (look at
            % latest sample in buffer compared to incoming timestamp),
            % stop showing data
            if isnan(x) || isnan(y)
                fx = obj.x;
                fy = obj.y;
                return;
            end

            % add incoming data to buffer
            obj.buffer = [ts x y; obj.buffer];
            
            % run through available data and divide up into time windows
            dt = ts-obj.buffer(:,1);
            % throw out data older than we're interested in
            qOld = dt > 2*obj.timeWindow;
            obj.buffer(qOld,:) = [];
            dt(qOld) = [];

            % split up buffer into two time windows
            qdt = dt>obj.timeWindow;
            avgXB = mean(obj.buffer( qdt,2));
            avgYB = mean(obj.buffer( qdt,3));
            avgXA = mean(obj.buffer(~qdt,2));
            avgYA = mean(obj.buffer(~qdt,3));
            
            % if we swap to Tfast, we exponentially return to Tslow. We do
            % obj over a period of TresetTime ms. Compute current T here
            if ts-obj.tLastStep<=obj.TresetTime
                obj.t = min(obj.Tfast+.5*obj.Tacc.*(ts-obj.tLastStep).^2, obj.Tslow);
            else
                obj.t = obj.Tslow;
            end
            % check for fast movement, reset T to Tfast if there is
            if ~isnan(avgXA) && ~isnan(avgXB)
                dist = hypot(avgXB-avgXA,avgYB-avgYA);
                if dist > obj.distT
                    obj.t          = obj.Tfast;
                    obj.tLastStep  = ts;
                end
            end
            
            % if we don't know the sampling interval yet, determine it
            % from the data
            % check if we have enough data to start the filter. We do that
            % by checking if we just threw out a sample because its too
            % old, that means the buffer is fully filled. (actually its
            % ready one sample earlier, but thats hard to detect)
            validFilter = any(qOld);
            if validFilter && ~obj.interval && size(obj.buffer,1)>1
                obj.interval    = -mean(diff(obj.buffer(:,1)));     % minus as newest sample is on top, not bottom
            end

            % smooth based on new incoming sample
            if obj.interval
                alpha = obj.t / obj.interval;
                obj.x = (x + alpha * obj.x) / (1.0 + alpha);
                obj.y = (y + alpha * obj.y) / (1.0 + alpha);
            else
                % return average of data we have seen so far, best we can
                % do until we have seen enough data to really go at it
                obj.x = mean(obj.buffer(:,2),'omitnan');
                obj.y = mean(obj.buffer(:,3),'omitnan');
            end
            
            % return
            fx = obj.x;
            fy = obj.y;
            return;
        end
        
        function set.Tfast(obj, Tfast)
            assert(isempty(obj.Tslow) || Tfast<obj.Tslow,'Tfast should be smaller than Tslow')
            obj.Tfast   = Tfast;
            obj.recalculateResetAcc();
        end
        function set.Tslow(obj, Tslow)
            assert(isempty(obj.Tfast) || obj.Tfast<Tslow,'Tfast should be smaller than Tslow')
            obj.Tslow   = Tslow;
            obj.recalculateResetAcc();
        end
        function set.TresetTime(obj, TresetTime)
            obj.TresetTime  = TresetTime;
            obj.recalculateResetAcc();
        end
    end
    
    methods (Access = private, Hidden = true)
        function setDefaults(obj)
            obj.timeWindow  = 50;
            obj.distT       = 25;
            obj.Tfast       = .5;
            obj.Tslow       = 300;
            obj.TresetTime  = 100;   % 100 ms to exponentially go from Tfast to Tslow
        end
        
        function recalculateResetAcc(obj)
            if ~isempty(obj.Tfast) && ~isempty(obj.Tslow) && ~isempty(obj.TresetTime)
                obj.Tacc    = 2*(obj.Tslow-obj.Tfast)/100^2;
            end
        end
    end
end
