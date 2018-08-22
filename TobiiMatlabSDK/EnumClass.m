%% Capabilites
%
% Defines the capabilities.
%
%%
classdef EnumClass
    properties (Access = public)
        value
    end

    methods
        function out = EnumClass(in)
            if nargin > 0
                out.value = uint32(in);
            end
        end

        function is_eq = eq(obj1, obj2)
            if isempty(obj1) || isempty(obj2)
                is_eq = false;
            elseif not(isnumeric(obj1)) && not(isnumeric(obj2))
                is_eq = obj1.value == obj2.value;
            elseif isnumeric(obj2)
                is_eq = obj1.value == obj2;
            elseif isnumeric(obj1)
                is_eq = obj1 == obj2.value;
            end
        end

        function is_eq = ne(obj1, obj2)
            is_eq = not(obj1 == obj2);
        end
    end
end
