% This controls the juice pump for the SMAKN LCUS-1 type USB relay module
% USB intelligent control switch USB switch
% Turn  on the relay switch, HEX: A0 01 01 A2 (DEC: 160 1 1 162)
% Turn off the relay switch, HEX: A0 01 00 A1 (DEC: 160 1 0 161)
classdef JuicePumper < handle
    properties
        port;
        baudrate = 9600;
        dummyMode = false;
        dutyCycle = inf;    % ms. If set to something other than inf, juice will be pulsed with the pump being on for dutyCycle ms, then off for dutyCycle ms, etc for as long rewards are on. This requires frequently calling tick()
    end
    properties (SetAccess=private)
        on = false;
        dispensing = false;
    end
    properties (Access=private,Hidden=true)
        portHandle;
        startT;
    end

    methods
        function obj = JuicePumper(port,baudrate,dummyMode)
            obj.port = port;
            if nargin>1 && ~isempty(baudrate)
                obj.baudrate = baudrate;
            end
            if nargin>2 && ~isempty(dummyMode)
                obj.dummyMode = ~~dummyMode;
            end

            if ~obj.dummyMode
                obj.portHandle = serialport(obj.port,obj.baudrate);
                fopen(obj.portHandle);
            end
        end

        function delete(obj)
            if ~isempty(obj.portHandle)
                % ensure we stop the juice before we destruct
                obj.stop();
                delete(obj.portHandle)
            end
        end

        function start(obj)
            if ~obj.dummyMode
                obj.startT = GetSecs();
                obj.dispense(true);
                fprintf('start\n');
            end
            obj.on = true;
        end

        function tick(obj)
            if ~obj.dummyMode && obj.on
                % pulsing: check if need to switch pump on or off
                iVal = floor((GetSecs-obj.startT)*1000/obj.dutyCycle)+1;
                if mod(iVal,2)==1 && ~obj.dispensing
                    obj.dispense(true);
                    fprintf('pulse on %.3f\n',GetSecs-obj.startT);
                elseif mod(iVal,2)==0 && obj.dispensing
                    obj.dispense(false);
                    fprintf('pulse off %.3f\n',GetSecs-obj.startT);
                end
            end
        end

        function stop(obj)
            if ~obj.dummyMode
                obj.dispense(false);
                fprintf('stop\n');
            end
            obj.on = false;
        end
    end

    methods (Static=true)
        function ports = getPorts()
            ports = serialportlist();
        end
    end

    methods (Access = private, Hidden)
        function dispense(obj,start)
            if start
                fwrite(obj.portHandle, [160 1 1 162]);
                obj.dispensing = true;
            else
                fwrite(obj.portHandle, [160 1 0 161]);
                obj.dispensing = false;
            end
        end
    end
end