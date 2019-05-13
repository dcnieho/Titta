classdef PTBButton < handle
    properties
        visible;
        rect;
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
        textRect;   % base rect of text
        textOffset = [0 0]; % offset currently applied to it to position text
    end
    
    methods
        function this = PTBButton(setup,visibleOverride,wpnt,funs,margins)
            this.visible        = setup.visible && visibleOverride;
            this.wpnt           = wpnt;
            this.funs           = funs; % textCacheGetter, textCacheDrawer, cacheOffSetter, colorGetter
            this.margins        = margins;
            
            this.normalState    = struct('buttonColor',[],'string','','textColor',[],'tCache',[]);
            this.hoverState     = this.normalState;
            this.activeState    = this.normalState;
            
            % check inputs
            fields = {'string','textColor','buttonColor'};
            for f=fields(1:3)
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
                this.unfinishedSetup.buttonColor= setup.buttonColor;
            end
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
            if ~isempty(this.normalState.tCache)                                                %#ok<MCSUP>
                fields = {'normalState', 'hoverState', 'activeState'};
                for f=1:length(fields)
                    this.(fields{f}).tCache = this.funs.cacheOffSetter(this.(fields{f}).tCache, this.rect, this.textOffset); %#ok<MCSUP>
                end
                [this.textOffset(1),this.textOffset(2)] = RectCenterd(this.rect);               %#ok<MCSUP>
            end
        end
        
        function set.visible(this,val)
            this.visible = ~~val;
            if this.visible && isempty(this.normalState) && ~isempty(this.unfinishedSetup)      %#ok<MCSUP>
                % first time becomes visible, do setup
                this.setupButton(this.wpnt,this.unfinishedSetup);                               %#ok<MCSUP>
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
            
            clr      = this.(states{state}).buttonColor;
            lColHigh = this.(states{state}).lineColorHigh;
            lColLow1 = this.(states{state}).lineColorLow1;
            lColLow2 = this.(states{state}).lineColorLow2;
            
            % draw background
            Screen('FillRect',this.wpnt,this.funs.colorGetter(clr),this.rect);
            % draw edges
            width = 1;
            if state==3
                % button is depressed
                xy = [this.rect([1 3 3 3]) this.rect([1 1 1 3])+[1  1  1 -1]*width this.rect([1 1 1 3]);  this.rect([4 4 4 2]) this.rect([4 2 2 2])+[-1  1  1 1]*width this.rect([4 2 2 2])];
            else
                % button is up
                xy = [this.rect([1 1 1 3]) this.rect([1 3 3 3]) this.rect([1 3 3 3])+[1 -1 -1 -1]*width;  this.rect([4 2 2 2]) this.rect([4 4 4 2]) this.rect([4 4 4 2])+[-1 -1 -1 1]*width];
            end
            colors = [repmat(this.funs.colorGetter(lColHigh),4,1); repmat(this.funs.colorGetter(lColLow1),4,1); repmat(this.funs.colorGetter(lColLow2),4,1)].';
            Screen('DrawLines',this.wpnt,xy,width,colors);
            % draw text
            this.funs.textCacheDrawer(this.(states{state}).tCache);
        end
    end
    
    methods (Access=private, Hidden=true)
        function setupButton(this,wpnt,setup)
            for p=length(setup.string):-1:1
                [setup.tCache{p},tRect(p,:)] = this.funs.textCacheGetter(wpnt,sprintf('<color=%s>%s',clr2hex(setup.textColor{p}),setup.string{p}));
            end
            % get rect around largest
            this.textRect   = [0 0 max(tRect(:,3)-tRect(:,1)) max(tRect(:,4)-tRect(:,2))];
            this.rect       = this.textRect + 2*[0 0 this.margins];
            
            % now get final button setup
            fields = {'string','textColor','buttonColor','tCache'};
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
            
            % per state, make button colors
            this.setupButtonColors();
        end
        
        function setupButtonColors(this)
            fields = {'normalState', 'hoverState', 'activeState'};
            for f=1:length(fields)
                colHSL = rgb2hsl(this.(fields{f}).buttonColor);
                % make highlight color, and two lowlight colors
                this.(fields{f}).lineColorHigh = hsl2rgb([colHSL(1:2) (colHSL(3)+1)/2]);
                this.(fields{f}).lineColorLow1 = hsl2rgb([colHSL(1:2)  colHSL(3)*1/3 ]);
                this.(fields{f}).lineColorLow2 = hsl2rgb([colHSL(1:2)  colHSL(3)*2/3 ]);
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