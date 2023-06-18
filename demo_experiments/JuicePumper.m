% This controls the juice pump for the SMAKN LCUS-1 type USB relay module
% USB intelligent control switch USB switch
% Turn  on the relay switch, HEX: A0 01 01 A2 (DEC: 160 1 1 162)
% Turn off the relay switch, HEX: A0 01 00 A1 (DEC: 160 1 0 161)
classdef JuicePumper < handle
    properties
        port;
        baudrate = 9600;
        dummyMode = false;
    end
    properties (Access=private,Hidden=true)
        portHandle;
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
                fwrite(obj.portHandle, [160 1 1 162]);
            end
        end

        function stop(obj)
            if ~obj.dummyMode
                fwrite(obj.portHandle, [160 1 0 161]);
            end
        end
    end

    methods (Static=true)
        function ports = getPorts()
            ports = serialportlist();
        end
    end
end