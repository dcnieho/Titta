classdef simpleVec < handle
    properties (Access = protected, Hidden = true)
        dataStore;
        nElem = 0;
    end
    properties (Dependent, SetAccess = private)
        data;
        N;
        capacity;
    end
    properties (SetAccess = private)
        axis;
    end
    methods
        function obj = simpleVec(dataExample,reserveSize,axis)
            % optionally call with example data (to get type and shape) and
            % how much of that type and size to reserve
            % further optionally provide axis long which to append data.
            % default is 1 (vertical/1st dimension of a matlab array)
            if nargin<3||isempty(axis)
                obj.axis = 1;
            else
                obj.axis = axis;
            end
            if nargin<2||isempty(reserveSize)
                reserveSize = 1;
            end
            % reserve data if we have an example from which we can
            % determine shape
            if nargin
                obj.realloc(reserveSize,dataExample);
            end
        end
        
        function append(obj,val)
            % can append one or more values along obj.axis direction at
            % once
            
            % get number of elements to append
            nIn = size(val,obj.axis);
            
            % allocate more space if needed
            if obj.nElem+nIn>size(obj.dataStore,obj.axis)
                obj.realloc(nIn,val);
            end
            
            % append input
            idxs                    = repmat({':'},1,ndims(obj.dataStore));
            idxs{obj.axis}          = obj.nElem+[1:nIn]; %#ok<NBRAK>
            obj.dataStore(idxs{:})  = val;
            obj.nElem               = obj.nElem+nIn;
        end
        
        function update(obj,idx,val)
            % to update a value, retrieve it first using .data(), then put
            % it back in (overwriting) using .update()
            assert(idx<=obj.nElem,'simpleVec::update: provided index out of bounds (too large, max is %d)',obj.nElem);
            idxs            = repmat({':'},1,ndims(obj.dataStore));
            idxs{obj.axis}  = idx;
            obj.dataStore(idxs{:}) = val;
        end
        
        function out = get.data(obj)
            idxs            = repmat({':'},1,ndims(obj.dataStore));
            idxs{obj.axis}  = 1:obj.nElem;
            out             = obj.dataStore(idxs{:});
        end
        
        function out = get.N(obj)
            out = obj.nElem;
        end
        
        function out = get.capacity(obj)
            out = size(obj.dataStore,obj.axis);
        end
    end
    
    methods (Access = protected, Hidden = true)
        function realloc(obj,nIn,exampleElem)
            % first see how many to alloc
            if isempty(obj.dataStore)
                % no elements yet, start with at least double the space of
                % input as we assume more will be appended
                [sz{1:ndims(exampleElem)}]  = size(exampleElem);
                sz{obj.axis}                = 2^(nextpow2(nIn)+1);
                exampleElem                 = exampleElem(1);
            else
                % this at minimum doubles the size of the data store, or
                % more if needed to fit all input
                [sz{1:ndims(obj.dataStore)}]= size(obj.dataStore);
                sz{obj.axis}                = 2^nextpow2(obj.nElem+nIn);
                exampleElem                 = obj.dataStore(1);     % ignore example elem. we want to ensure we keep the same datatype as datastore currently has, and avoid other trouble I haven't thought of
            end
            
            % alloc new space
            if isnumeric(exampleElem) || islogical(exampleElem)
                temp = zeros(sz{:},'like',exampleElem);
            elseif isa(exampleElem,'cell')
                temp = cell(sz{:});
            else    % e.g. struct or object
                temp = repmat(exampleElem,sz{:});
            end
            
            % copy over old values, if any
            if obj.nElem
                idx             = repmat({':'},size(sz));
                idx{obj.axis}   = [1:obj.nElem]; %#ok<NBRAK>
                temp(idx{:})    = obj.dataStore(idx{:});
            end
            
            % assign new memory/remove old
            obj.dataStore = temp;
        end
    end
end