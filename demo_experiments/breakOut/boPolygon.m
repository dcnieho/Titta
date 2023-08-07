classdef boPolygon < handle
    properties (Access = private, Hidden=true)
        privateEdges;
        privateAABBmid;
        privateAABBhalfSize;
    end
    properties (SetAccess = private)
        vertices = [];
        
    end
    properties (SetAccess = private, Dependent)
        edges;
        AABBmid;
        AABBhalfSize;
    end
    
    methods
        function this = boPolygon(vertices)
            if nargin>=1 && ~isempty(vertices)  % when creating array, may be default constructed
                this.vertices   = vertices;
            end
        end
        
        function set.vertices(this,vertices)
            assert(size(vertices,2)==2,'Vertices should be a 2xN array')
            nVert = size(vertices,1);
            assert(nVert>=3,'At least three vertices should be provided')
            
            this.vertices       = vertices;
            this.privateEdges   = []; %#ok<MCSUP> % design is such that this will always be fine. cache can be regenerated when needed
        end
        
        function out = get.edges(this)
            if isempty(this.privateEdges)
                % create cache
                this.genCaches();
            end
            out = this.privateEdges;
        end
        
        function out = get.AABBmid(this)
            if isempty(this.privateAABBmid)
                % create cache
                this.genCaches();
            end
            out = this.privateAABBmid;
        end
        
        function out = get.AABBhalfSize(this)
            if isempty(this.privateAABBhalfSize)
                % create cache
                this.genCaches();
            end
            out = this.privateAABBhalfSize;
        end
        
        function translate(this,vec)
            this.vertices = bsxfun(@plus,this.vertices,vec(:).');
            % regen caches
            this.genCaches();
        end
    end
    
    methods (Access = private, Hidden = true)
        function genCaches(this)
            % generate edges
            nVert = size(this.vertices,1);
            % close off polygon
            this.privateEdges = struct('p1',{},'p2',{});
            this.privateEdges(nVert) = struct('p1',this.vertices(end,:),'p2',this.vertices(1,:));
            % other edges
            for p=nVert-1:-1:1
                this.privateEdges(p) = struct('p1',this.vertices(p,:),'p2',this.vertices(p+1,:));
            end
            
            % get AABB
            tl = min(this.vertices,[],1);
            rb = max(this.vertices,[],1);
            % get AABB mid
            this.privateAABBmid = mean([tl; rb],1);
            % get AABB halfSize
            this.privateAABBhalfSize = norm(this.privateAABBmid-tl);
        end
    end
end