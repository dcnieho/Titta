% shut up all warnings about accessing other class properties in a class's
% setter or getter
%#ok<*MCSUP>
classdef PTBButton < handle
    properties
        visible;
        rect;
        drawDropShadow = true;
    end
    
    properties (SetAccess=private)
        margins;
        
        normalState;
        hoverState;
        activeState;
    end
    
    properties (Access=private, Hidden=true)
        unfinishedSetup;
        wpnt;
        funs;
        textRect;           % base rect of text
        offset = [0 0];     % offset currently applied to it to position rect and text
        dropShadowClr;
    end
    
    methods
        function this = PTBButton(setup,visibleOverride,wpnt,funs,margins)
            this.visible        = setup.visible && visibleOverride;
            this.wpnt           = wpnt;
            this.funs           = funs; % textCacheGetter, textCacheDrawer, cacheOffSetter, colorGetter
            this.margins        = margins;
            
            this.normalState    = struct('fillColor',[],'edgeColor',[],'string','','textColor',[],'tCache',[]);
            this.hoverState     = this.normalState;
            this.activeState    = this.normalState;
            
            % check inputs
            fields = {'string','textColor','fillColor','edgeColor'};
            for f=fields
                if ~iscell(setup.(f{1}))
                    setup.(f{1}) = {setup.(f{1})};
                end
                assert(ismember(numel(setup.(f{1})),[1:3]),'number of %ss for button ''%s'' should be 1, 2 or 3',f{1},setup.string{1});
            end
            % make sure we have equal number of inputs. Process only string
            % and textColor, we expand further below after generating text
            % cache
            maxIn           = max(cellfun(@(x) length(setup.(x)),fields(1:2)));
            for f=fields(1:2)
                setup.(f{1})    = distributeInputs(setup.(f{1}),maxIn);
            end
            
            % get drawing cache for strings
            if this.visible
                this.setupButton(this.wpnt,setup);
            else
                this.unfinishedSetup.string     = setup.string;
                this.unfinishedSetup.textColor  = setup.textColor;
                this.unfinishedSetup.fillColor  = setup.fillColor;
                this.unfinishedSetup.edgeColor  = setup.edgeColor;
            end
            
            this.dropShadowClr = this.funs.colorGetter([0 0 0 127]);
        end
        
        function rect = get.rect(this)
            if ~this.visible
                rect = [-10000 -10000 -10000 -10000];   % something far offscreen and empty
            else
                rect = this.rect;
            end
        end
        
        function set.rect(this,val)
            this.rect = val;
            if ~isempty(this.normalState.tCache)
                fields = {'normalState', 'hoverState', 'activeState'};
                for f=1:length(fields)
                    this.(fields{f}).tCache = this.funs.cacheOffSetter(this.(fields{f}).tCache, this.rect, this.offset);
                end
            [this.offset(1),this.offset(2)] = RectCenterd(this.rect);
            end
        end
        
        function set.visible(this,val)
            this.visible = ~~val;
            if this.visible && isempty(this.normalState) && ~isempty(this.unfinishedSetup)
                % first time becomes visible, do setup
                this.setupButton(this.wpnt,this.unfinishedSetup);
            end
        end
        
        function draw(this,mousePos,qActive)
            if ~this.visible
                return;
            end
            if nargin<3 || isempty(qActive)
                qActive = false;
            end
            states = {'normalState','hoverState','activeState'};
            if qActive
                state = 3;
            elseif inRect(mousePos(:),this.rect(:))
                state = 2;
            else
                state = 1;
            end
            
            clr      = this.(states{state}).fillColor;
            eclr     = this.(states{state}).edgeColor;
            
            drawRect = this.rect;
            extraIn = {};
            if this.drawDropShadow
                % draw drop shadow
                dropOffset = 6;
                off = [cosd(45) sind(45)];
                shadowRect = OffsetRect(this.rect(:).',off(1)*dropOffset,off(2)*dropOffset);
                Screen('FillRect',this.wpnt,this.dropShadowClr,shadowRect);
                if state==3
                    % depressed, move button to be draw right on top of
                    % drop shadow
                    drawRect = OffsetRect(this.rect(:).',off(1)*dropOffset*.5,off(2)*dropOffset*.5);
                    extraIn = {drawRect};
                end
            end
            if state==2
                edgeWidth = 3;
            else
                edgeWidth = 2;
            end
            
            % draw background
            Screen('FillRect',this.wpnt,clr,drawRect);
            % draw edge
            Screen('FrameRect',this.wpnt,eclr,drawRect,edgeWidth);
            % draw text
            this.funs.textCacheDrawer(this.(states{state}).tCache,extraIn{:});
        end
    end
    
    methods (Access=private, Hidden=true)
        function setupButton(this,wpnt,setup)
            for p=length(setup.string):-1:1
                [setup.tCache{p},tRect(p,:)] = this.funs.textCacheGetter(wpnt,sprintf('<color=%s>%s',clr2hex(setup.textColor{p}),setup.string{p}));
            end
            % get rect around largest
            this.textRect   = [0 0 max(tRect(:,3)-tRect(:,1)) max(tRect(:,4)-tRect(:,2))];
            this.rect       = this.textRect + [-this.margins this.margins];
            
            % get colors
            fields = {'fillColor','edgeColor'}; % not textcolor, textCacheGetter takes it always as 8bit
            for f=fields
                for c=1:length(setup.(f{1}))
                    setup.(f{1}){c} = this.funs.colorGetter(setup.(f{1}){c});
                end
            end
            
            % now get final button setup
            fields = {'string','textColor','fillColor','edgeColor','tCache'};
            for f=fields
                setup.(f{1})    = distributeInputs(setup.(f{1}),3);
            end
            
            % put in the right place
            fields2 = {'normalState', 'hoverState', 'activeState'};
            for f2=1:length(fields2)
                for f1=fields
                    this.(fields2{f2}).(f1{1}) = setup.(f1{1}){f2};
                end
            end
        end
    end
end


%%% helpers
function hex = clr2hex(clr)
hex = reshape(dec2hex(clr(1:3),2).',1,[]);
end

function input = distributeInputs(input,nWanted)
nIn = length(input);
if nIn==nWanted
    return;
end
assert(nIn<nWanted,'Have more inputs than wanted, programmer error (not setup error)')
if nWanted==2
    input = input([1 1]);
elseif nWanted==3
    if nIn==1
        input = input([1 1 1]);
    else
        input = input([1 1 2]);
    end
end
end

function verts = getRoundedPoly(rect,radius)
% for if we want rounded edges. Screen('FramePoly') looks horrible with
% this as input however, due to lack of antialiasing it seems
[rw,rh] = deal(RectWidth(rect),RectHeight(rect));
nStep  = 15;
verts = zeros(nStep*4,2);
% top left
angs = linspace(-180,-90,nStep).';
verts(1:nStep,:) = [cosd(angs) sind(angs)]*radius+radius;
% top right
angs = linspace( -90,  0,nStep).';
verts(nStep+1:2*nStep,:) = bsxfun(@plus,[cosd(angs) sind(angs)]*radius,[rw-radius +radius]);
% bottom right
angs = linspace( 0,  90,nStep).';
verts(2*nStep+1:3*nStep,:) = bsxfun(@plus,[cosd(angs) sind(angs)]*radius,[rw-radius rh-radius]);
% bottom left
angs = linspace( 90, 180,nStep).';
verts(3*nStep+1:4*nStep,:) = bsxfun(@plus,[cosd(angs) sind(angs)]*radius,[radius rh-radius]);
end