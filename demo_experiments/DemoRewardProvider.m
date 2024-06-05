classdef DemoRewardProvider < handle
    properties
        dummyMode = false;
        dutyCycle = inf;    % ms. If set to something other than inf, reward will be on for dutyCycle ms, then off for dutyCycle ms, etc for as long rewards are on. This requires frequently calling tick()
        verbose   = false;  % if true, prints state updates to command line
    end
    properties (SetAccess=private)
        on = false;
        dispensing = false;
    end
    properties (Access=private,Hidden=true)
        startT;
    end

    methods
        function obj = DemoRewardProvider(dummyMode)
            if nargin>0 && ~isempty(dummyMode)
                obj.dummyMode = ~~dummyMode;
            end
        end

        function delete(obj)
            % ensure we stop the reward before we destruct
            obj.stop();
        end

        function start(obj)
            if ~obj.dummyMode && ~obj.on
                obj.startT = GetSecs();
                obj.dispense(true);
                if obj.verbose
                    fprintf('DemoRewardProvider: start\n');
                end
            end
            obj.on = true;
        end

        function tick(obj)
            if ~obj.dummyMode && obj.on
                % pulsing: check if need to switch reward on or off
                iVal = floor((GetSecs-obj.startT)*1000/obj.dutyCycle)+1;
                if mod(iVal,2)==1 && ~obj.dispensing
                    obj.dispense(true);
                    if obj.verbose
                        fprintf('DemoRewardProvider: pulse on %.3f\n',GetSecs-obj.startT);
                    end
                elseif mod(iVal,2)==0 && obj.dispensing
                    obj.dispense(false);
                    if obj.verbose
                        fprintf('DemoRewardProvider: pulse off %.3f\n',GetSecs-obj.startT);
                    end
                end
            end
        end

        function stop(obj)
            if ~obj.dummyMode && obj.on
                obj.dispense(false);
                if obj.verbose
                    fprintf('DemoRewardProvider: stop\n');
                end
            end
            obj.on = false;
        end
    end

    methods (Access = private, Hidden)
        function dispense(obj,start)
            if start
                obj.dispensing = true;
            else
                obj.dispensing = false;
            end
        end
    end
end