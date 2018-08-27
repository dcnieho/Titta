classdef simpleVec < handle
    properties (Access = protected, Hidden = true)
        dataStore;
        nElem = 0;
    end
    properties (Dependent, SetAccess = private)
        data;
        N;
    end
    methods
        function obj = simpleVec(dataType,reserveSize)
            % optionally call with example data and how much of that type
            % and size to reserve
            if nargin
                obj.realloc(reserveSize,dataType);
            end
        end
        
        function append(obj,val)
            nIn = size(val,1);
            if obj.nElem+nIn>length(obj.dataStore)
                % allocate more space
                if isempty(obj.dataStore)
                    % no elements yet, start with enough space for input, or at least 16
                    obj.realloc(max(2^nextpow2(nIn),16),val)
                else
                    % this at minumum double size or data store, or more if needed to fit all input
                    newNElem = 2^nextpow2(length(obj.dataStore)+nIn);
                    obj.realloc(newNElem,obj.dataStore(end,:));
                end
            end
            % put value
            obj.dataStore(obj.nElem+1:obj.nElem+nIn,:)  = val;
            obj.nElem                                   = obj.nElem+nIn;
        end
        
        function out = get.data(obj)
            out = obj.dataStore(1:obj.nElem,:);
        end
        
        function out = get.N(obj)
            out = obj.nElem;
        end
        
    end
    
    methods (Access = protected, Hidden = true)
        function realloc(obj,nElem,exampleElem)
            % alloc new space
            nCol = size(exampleElem,2);
            if isa(exampleElem,'cell')
                temp = cell(nElem,nCol);
            elseif isa(exampleElem,'struct')
                temp = repmat(exampleElem,nElem,nCol);
            else
                temp = zeros(nElem,nCol,'like',exampleElem);
            end
            % copy over old values
            if obj.nElem
                temp(1:obj.nElem,:) = obj.dataStore(1:obj.nElem,:);
            end
            % remove old
            obj.dataStore = temp;
        end
    end
end