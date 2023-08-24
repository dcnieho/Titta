classdef ImageCalibrationDisplay < handle
    properties (Access=private, Constant)
        calStateEnum = struct('undefined',0, 'showing',1, 'blinking',2);
    end
    properties (Access=private)
        calState;
        currentPoint;
        startT;
        blinkStartT;
        texs;
    end
    properties (SetAccess=private)
        images              = {};
        imageDurations      = [];
        imageScales         = [];
    end
    properties
        blinkInterval           = 0.3;
        blinkCount              = 2;
        restartAnimForEachPoint = true; % if true, each new point starts with first frame. if false, animation continues where it was, just moves position
        bgColor                 = 127;
    end
    properties (Access=private, Hidden = true)
        qFloatColorRange;
        cumDurations;
        qTexsLoaded;
    end
    
    
    methods
        function obj = ImageCalibrationDisplay()
            obj.setCleanState();
        end
        
        function setCleanState(obj)
            obj.calState        = obj.calStateEnum.undefined;
            obj.currentPoint    = nan(1,3);
            obj.startT          = [];
            if ~isempty(obj.texs)
                Screen('Close',[obj.texs.tex]);
                obj.texs = [];
            end
            obj.qTexsLoaded     = false;
        end
        
        function setImages(obj,wpnt,imageFiles,imageDurations,imageScales)
            % check input
            imageInfo = obj.interrogateImages(imageFiles);

            if isscalar(imageDurations)
                imageDurations = repmat(imageDurations,1,length(imageInfo));
            end
            assert(numel(imageDurations)==length(imageInfo),'either specify a single duration for all image files, or a duration per image file (or per image frame if files contain multiple frames, like animated gifs)')
            obj.imageDurations = imageDurations;
            obj.cumDurations   = cumsum([0 obj.imageDurations]);
            
            if nargin<4 || isempty(imageScales)
                imageScales = ones(1,length(imageInfo));
            elseif isscalar(imageScales)
                imageScales = repmat(imageScales,1,length(imageInfo));
            end
            assert(numel(imageScales)==length(imageInfo),'either specify a single scale for all image files, or a scale per image file (or per image frame if files contain multiple frames, like animated gifs)')
            obj.imageScales = imageScales;
            
            obj.images = imageInfo;
            
            % load images
            obj.loadImages();
            if ~isempty(wpnt)
                obj.uploadImages(wpnt);
            end
        end
        
        function qAllowAcceptKey = doDraw(obj,wpnt,drawCmd,currentPoint,pos,~,~)
            % last two inputs, tick (monotonously increasing integer) and
            % stage ("cal" or "val") are not used in this code
            
            % if called with drawCmd == 'fullCleanUp', this is a signal
            % that calibration/validation is done, and cleanup can occur if
            % wanted. If called with drawCmd == 'sequenceCleanUp' that
            % means there should be a gap in the drawing sequence (e.g. no
            % smooth animation between two positions). For this one we keep
            % image playback state unless asked to fully clean up.
            if ismember(drawCmd,{'fullCleanUp','sequenceCleanUp'})
                if strcmp(drawCmd,'fullCleanUp')
                    obj.setCleanState();
                end
                return;
            end
            
            % now that we have a wpnt, interrogate window
            if isempty(obj.qFloatColorRange)
                obj.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            end
            
            % delay-load images if needed
            if ~obj.qTexsLoaded
                obj.uploadImages(wpnt);
            end
            
            % check point changed
            curT = GetSecs;
            if strcmp(drawCmd,'new')
                obj.currentPoint    = [currentPoint pos];
                if isempty(obj.startT) || obj.restartAnimForEachPoint
                    obj.startT = curT;
                end
                obj.calState        = obj.calStateEnum.showing;
            elseif strcmp(drawCmd,'redo')
                % start blink, restart animation.
                obj.calState        = obj.calStateEnum.blinking;
                obj.blinkStartT     = curT;
            else % drawCmd == 'draw'
                % regular draw: check state transition
                if obj.calState==obj.calStateEnum.blinking && (curT-obj.blinkStartT)>obj.blinkInterval*obj.blinkCount*2
                    % blink finished
                    obj.calState    = obj.calStateEnum.showing;
                end
            end
            
            % determine current point position
            curPos = obj.currentPoint(2:3);
            
            % determine if we're ready to accept the user pressing the
            % accept calibration point button. User should not be able to
            % press it if point is not yet at the final position
            qAllowAcceptKey = obj.calState~=obj.calStateEnum.blinking;
            
            % draw
            if obj.calState~=obj.calStateEnum.blinking
                [~,~,whichIm] = histcounts(mod(curT-obj.startT,obj.cumDurations(end)),obj.cumDurations);
            else
                whichIm = 1;
            end
            Screen('FillRect',wpnt,obj.getColorForWindow(obj.bgColor)); % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
            if obj.calState~=obj.calStateEnum.blinking || mod((curT-obj.blinkStartT)/obj.blinkInterval/2,1)>.5
                rect = CenterRectOnPointd(obj.texs(whichIm).scrRect,curPos(1),curPos(2));
                Screen('DrawTexture',wpnt,obj.texs(whichIm).tex,[],rect);
            end
        end
    end
    
    methods (Access = private, Hidden, Static)
        function imageInfo = interrogateImages(imageFiles)
            imageInfo = cell2struct(cell(4,1,0),{'file','ext','frameIdx','info'});   % make empty struct
            for p=1:length(imageFiles)
                % get info about images
                [~,~,ext] = fileparts(imageFiles{p});
                if ext(1)=='.'
                    ext(1) = [];
                end
                if ismember(lower(ext),{'gif','jpg','png','tif','tiff'})
                    imInfo = imfinfo(imageFiles{p});
                    nImage = length(imInfo);    % gif and tiff may contain multiple images
                    for f=1:nImage
                        imageInfo(1,end+1) = struct('file',imageFiles{p},'ext',ext,'frameIdx',f,'info',[]); %#ok<AGROW>
                        if ismember(lower(ext),{'tif','tiff'})
                            imageInfo(1,end).info = imInfo;
                        elseif strcmpi(ext,'gif')
                            imageInfo(1,end).info = imInfo(f);
                        end
                    end
                else
                    error('Files other than gif, jpg, png and tif are not supported')
                end
            end
        end

        function imdata = loadImage(image)
            switch lower(image.ext)
                case {'jpg','png'}
                    assert(frame==1,'Reading more than one frame from jpg or png file is not supported')
                    [imdata,cmap,a] = imread(image.file);
                case {'gif'}
                    [imdata,cmap]   = imread(image.file,image.frameIdx);
                    % check if gif has a transparent color. If so,
                    % create alpha layer
                    % 1. get which color is transparent
                    tIdx            = nan;
                    if isfield(image.info,'TransparentColor')
                        tIdx        = image.info.TransparentColor;
                    end
                    % 2. create the alpha layer
                    if ~isnan(tIdx) && ~isempty(tIdx)
                        a = imdata ~= tIdx-1;   % indexed image is zero-based, tIdx is 1-based
                        a = cast(a,'like',imdata) * intmax(class(imdata));
                    else
                        a = [];
                    end
                case {'tif','tiff'}
                    [imdata,cmap,a] = imread(image.file,'Index',image.frameIdx,'Info',image.info);
            end

            % if indexed image, turn into RGB image
            if ~isempty(cmap)
                imdata = ind2rgb(imdata,cmap);
            end
            
            % convert to double with 0--1 range
            if isinteger(imdata)
                imdata = double(imdata)/double(intmax(class(imdata)));
            end
            
            % if single plane (grayscale, expand to three planes)
            if size(imdata,3)==1
                imdata = repmat(imdata,1,1,3);
            end
            
            % add alpha channel, if any.
            % ensure its of right type
            if isa(imdata,'double') && ~isa(a,'double')
                a = double(a)/double(intmax(class(a)));
            end
            % add
            imdata = cat(3,imdata,a);
        end

        function tex = uploadImage(imdata,wpnt,scrSize,qDontScaleUp)
            % get some info about image
            tex.size  = [size(imdata,1) size(imdata,2)];
            tex.ext   = fliplr(tex.size);   % size is [y x], for rects need [x y]

            % store image data
            if nargin>1 && ~isempty(wpnt)
                % upload as PTB texture
                if Screen('ColorRange',wpnt)==1
                    tex.tex = Screen('MakeTexture',wpnt,imdata,[],[],1);
                else
                    imdata  = uint8(round(imdata*255));
                    tex.tex = Screen('MakeTexture',wpnt,imdata);
                end
            else
                % simply pass back out
                tex.imdata = imdata;
            end

            if nargin>2 && ~isempty(scrSize)
                % find scale fac to make it fit on screen
                tex.scaleFac = min(scrSize./tex.ext);
                if nargin>3 && ~isempty(qDontScaleUp) && qDontScaleUp
                    % make sure image is not scaled up (scaleFac not higher
                    % than 1)
                    tex.scaleFac = min(1, tex.scaleFac);
                end
                tex.scrRect = CenterRect([0 0 tex.ext].*tex.scaleFac,[0 0 scrSize]);
            end
        end
    end
    
    methods (Access = private, Hidden)
        function loadImages(obj)
            for p=1:length(obj.images)
                obj.images(p).imdata = obj.loadImage(obj.images(p));
            end
        end

        function uploadImages(obj,wpnt)
            scrSize = Screen('Rect',wpnt);
            scrSize(1:2) = [];
            for p=1:length(obj.images)
                if ~isfield(obj.images(p),'imdata') || isempty(obj.images(p).imdata)
                    obj.images(p).imdata = obj.loadImage(obj.images(p));
                end
                tex = obj.uploadImage(obj.images(p).imdata,wpnt,scrSize,true);
                tex.scaleFac = min(obj.imageScales(p), tex.scaleFac);
                tex.scrRect = CenterRectOnPointd([0 0 tex.ext].*min(tex.scaleFac),0,0);
                if p==1
                    obj.texs = tex;
                else
                    obj.texs(p) = tex;
                end
            end
            obj.qTexsLoaded = true;
        end
        
        function clr = getColorForWindow(obj,clr)
            if obj.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end
