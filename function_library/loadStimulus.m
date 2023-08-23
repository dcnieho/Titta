function texs = loadStimulus(stimFile,wpnt,scrSize,qDontScaleUp)
%#ok<*AGROW> 

% get info about images
[~,file,ext] = fileparts(stimFile);
if ext(1)=='.'
    ext(1) = [];
end
stimName = [file '.' ext];
if ismember(lower(ext),{'gif','jpg','png','tif','tiff'})
    imInfo = imfinfo(stimFile);
    nImage = length(imInfo);    % gif and tiff may contain multiple images
else
    nImage = 1;
end

i=1;
for q=1:nImage
    switch lower(ext)
        case {'gif','jpg','png','tif','tiff'}
            texs(1,i).fInfo = dir(stimFile);
            texs(1,i).fInfo.fname = file;
            texs(1,i).fInfo.ext   = ext;
            texs(i).iInfo   = imInfo(q);
            switch lower(ext)
                case {'jpg','png'}
                    [imdata,cmap,a] = imread(stimFile);
                case {'gif'}
                    [imdata,cmap]   = imread(stimFile,q);
                    % check if gif has a transparent color. If so,
                    % create alpha layer
                    % 1. get which color is transparent
                    tIdx            = nan;
                    if isfield(texs(i).iInfo,'TransparentColor')
                        tIdx        = texs(i).iInfo.TransparentColor;
                    end
                    % 2. create the alpha layer
                    if ~isnan(tIdx) && ~isempty(tIdx)
                        a = imdata ~= tIdx-1;   % indexed image is zero-based, tIdx is 1-based
                        a = cast(a,'like',imdata) * intmax(class(imdata));
                    else
                        a = [];
                    end
                case {'tif','tiff'}
                    [imdata,cmap,a] = imread(stimFile,'Index',q,'Info',imInfo);
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

        otherwise
            error('extension of file ''%s'' not recognized/supported. Not an image file?',stimName)
    end
    
    % get some info about image
    texs(i).size  = [size(imdata,1) size(imdata,2)];
    texs(i).ext   = fliplr(texs(i).size);   % size is [y x], for rects need [x y]
    
    % store image data
    if nargin>1 && ~isempty(wpnt)
        % upload as PTB texture
        if Screen('ColorRange',wpnt)==1
            texs(i).tex = Screen('MakeTexture',wpnt,imdata,[],[],1);
        else
            imdata      = uint8(round(imdata*255));
            texs(i).tex = Screen('MakeTexture',wpnt,imdata);
        end
    else
        % simply pass back out
        texs(i).imdata = imdata;
    end
    
    if nargin>2 && ~isempty(scrSize)
        % find scale fac to make it fit on screen
        texs(i).scaleFac = min(scrSize./texs(i).ext);
        if nargin>3 && ~isempty(qDontScaleUp) && qDontScaleUp
            % make sure image is not scaled up (scaleFac not higher
            % than 1)
            texs(i).scaleFac = min(1, texs(i).scaleFac);
        end
        texs(i).scrRect = CenterRect([0 0 texs(i).ext].*texs(i).scaleFac,[0 0 scrSize]);
    end
    
    i=i+1;
end
