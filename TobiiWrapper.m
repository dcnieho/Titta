function fhndl = TobiiWrapper(tobiiSetup,scrInfo,textSetup)


% params
eyetracker  = [];
debugLevel  = false;

if isnumeric(scrInfo) % bgColor only
    thecolor = scrInfo;
    clear scrInfo;
    scrInfo.rect    = Screen('Rect',0); scrInfo.rect(1:2) = [];
    scrInfo.center  = scrInfo.rect/2;
    scrInfo.bgclr   = thecolor;
end


% setup function handles
fhndl.init              = @init;
fhndl.calibrate         = @calibrate;
fhndl.startRecording    = @startRecording;
fhndl.stopRecording     = @stopRecording;
fhndl.getData           = @getData;
fhndl.cleanUp           = @cleanUp;
        
    function out = init(input1)
        debugLevel = input1;
        
        % setup colors
        tobiiSetup.cal.fixBackColor = color2RGBA(tobiiSetup.cal.fixBackColor);
        tobiiSetup.cal.fixFrontColor= color2RGBA(tobiiSetup.cal.fixFrontColor);
        
        % get instance to Tobii wrapper
        Tobii = EyeTrackingOperations();
        
        % get eyeTracker
        eyetracker = Tobii.get_eyetracker(tobiiSetup.eyetrackerAddress);
        
        % apply license(s) if needed
        if ~isempty(tobiiSetup.licenseFile)
            if ~iscell(tobiiSetup.licenseFile)
                tobiiSetup.licenseFile = {tobiiSetup.licenseFile};
            end
            
            % load license files
            nLicenses   = length(tobiiSetup.licenseFile);
            licenses    = LicenseKey.empty(nLicenses,0);
            for l = 1:nLicenses
                fid = fopen(fullfile(cd,'licences',tobiiSetup.licenseFile{l}),'r');
                licenses(l) = LicenseKey(fread(fid));
                fclose(fid);
            end
            
            % apply to selected eye tracker.
            % Should return empty if all the licenses were correctly applied.
            failed_licenses = eyetracker.apply_licenses(licenses);
            assert(isempty(failed_licenses),'TobiiWrapper: provided license(s) couldn''t be applied')
        end
        
        % set requested tracking frequency
        eyetracker.set_gaze_output_frequency(tobiiSetup.freq);
        
        % get some system info
        out = [];
    end

    function out = calibrate(wpnt)
        % setup calibration
        % get where the calibration points are
        tobiiSetup.cal.calPointPosPix(:,1) = tobiiSetup.cal.calPointPos(:,1)*scrInfo.rect(1);
        tobiiSetup.cal.calPointPosPix(:,2) = tobiiSetup.cal.calPointPos(:,2)*scrInfo.rect(2);
        % and validation points
        tobiiSetup.cal.valPointPosPix(:,1) = tobiiSetup.cal.valPointPos(:,1)*scrInfo.rect(1);
        tobiiSetup.cal.valPointPosPix(:,2) = tobiiSetup.cal.valPointPos(:,2)*scrInfo.rect(2);
        
        % now run calibration until successful or exited
        kCal = 0;
        qDoSetup = tobiiSetup.cal.qStartWithHeadBox;
        while true
            kCal = kCal+1;
            if qDoSetup
                % show eye image (optional), headbox.
                status = doShowHeadBoxEye(wpnt,@startRecording,@getData,@stopRecording,eyetracker,scrInfo,textSetup,debugLevel);
                switch status
                    case 1
                        % all good, continue
                    case 2
                        % skip setup
                        break;
                    case -1
                        % doesn't make sense here, doesn't exist
                    case -2
                        % full stop
                        error('run ended from Tobii calibration routine')
                    otherwise
                        error('status %d not implemented',status);
                end
            end
            
            % calibrate
            [out.attempt{kCal}.calStatus,temp] = DoCal(wpnt,eyetracker,tobiiSetup.cal);
            warning('off','catstruct:DuplicatesFound')  % field already exists but is empty, will be overwritten with the output from the function here
            out.attempt{kCal} = catstruct(out.attempt{kCal},temp);
            % check returned action state
            switch out.attempt{kCal}.calStatus
                case 1
                    % all good, continue
                case 2
                    % skip setup
                    break;
                case -1
                    % retry calibration
                    qDoSetup = true;
                    continue;
                case -2
                    % full stop
                    error('run ended from Tobii calibration routine')
                otherwise
                    error('status %d not implemented',out.attempt{kCal}.calStatus);
            end
            
            % show calibration result and ask to continue
            [out.attempt{kCal}.calResultAccept,out.attempt{kCal}.calSelection] = showCalibrateImage(wpnt,out.attempt,kCal,tobiiSetup.cal,scrInfo,textSetup);
            switch out.attempt{kCal}.calResultAccept
                case 1
                    % all good, check correct calibration is loaded, and we're done
                    if out.attempt{kCal}.calSelection ~= kCal
                        eyetracker.apply_calibration_data(out.attempt{out.attempt{kCal}.calSelection}.cal.calData);
                    end
                case 2
                    % skip setup
                    break;
                case -1
                    % retry calibration
                    qDoSetup = true;
                    continue;
                case -2
                    % full stop
                    error('run ended from Tobii calibration routine')
                otherwise
                    error('status %d not implemented',out.attempt{kCal}.valResultAccept);
            end
            
            % validate
            [out.attempt{kCal}.calStatus,out.attempt{kCal}.val] = DoVal(wpnt,tobiiSetup.cal,@startRecording,@getData,@stopRecording);
            
            % get info about accuracy of calibration
            % TODO, just plot for now
            % show validation result and ask to continue
            [out.attempt{kCal}.valResultAccept,out.attempt{kCal}.calSelectionAfterVal] = showValidateImage(wpnt,out.attempt,kCal,tobiiSetup.cal,scrInfo,textSetup);
            switch out.attempt{kCal}.valResultAccept
                case 1
                    % all good, check correct calibration is leaded, and we're done
                    if out.attempt{kCal}.calSelectionAfterVal ~= kCal
                        eyetracker.apply_calibration_data(out.attempt{out.attempt{kCal}.calSelectionAfterVal}.cal.calData);
                    end
                    break;
                case 2
                    % skip setup
                    break;
                case -1
                    % retry calibration
                    qDoSetup = true;
                    continue;
                case -2
                    % full stop
                    error('run ended from SMI calibration routine')
                otherwise
                    error('status %d not implemented',out.attempt{kCal}.valResultAccept);
            end
        end
    end


    function startRecording()
        % For these, the first call subscribes to the stream and returns
        % either data (might be empty if no data has been received yet) or 
        % any error that happened during the subscription.
        % 1. info about synchronization between ET and system
        result = eyetracker.get_time_sync_data();
        if isa(result,'StreamError')
            err = sprintf('Error: %s\n',char(result.Error));
            err = [err sprintf('Source: %s\n',char(result.Source))];
            err = [err sprintf('SystemTimeStamp: %d\n',result.SystemTimeStamp)];
            err = [err sprintf('Message: %s\n',result.Message)];
            error('Tobii: Error starting recording sync data\n%s',err);
        end
        % 2. gaze data
        result = eyetracker.get_gaze_data();
        if isa(result,'StreamError')
            err = sprintf('Error: %s\n',char(result.Error));
            err = [err sprintf('Source: %s\n',char(result.Source))];
            err = [err sprintf('SystemTimeStamp: %d\n',result.SystemTimeStamp)];
            err = [err sprintf('Message: %s\n',result.Message)];
            error('Tobii: Error starting recording gaze data\n%s',err);
        end
        
        WaitSecs(.1); % give it some time to get started, never hurts
    end

    function [etData,syncData] = stopRecording(qClass)
        % return any data still in the buffers
        [etData,syncData] = getData(nargin>0 && qClass);
        % unsubscribe from streams
        eyetracker.stop_gaze_data();
        eyetracker.stop_time_sync_data();
    end

    function [etData,syncData] = getData(qClass)
        if nargin>0 && qClass
            mode = 'class';
        else
            mode = 'flat';
        end
        
        etData  = eyetracker.get_gaze_data(mode);
        syncData= eyetracker.get_time_sync_data(mode);
    end

    function [etData,syncData] = cleanUp()
        % returns any data still in the buffers
        [etData,syncData] = stopRecording();
    end

end




% helpers
function status = doShowHeadBoxEye(wpnt,startRecording,getData,stopRecording,eyetracker,scrInfo,textSetup,debugLevel)
% status output:
%  1: continue (setup seems good) (space)
%  2: skip calibration and continue with task (shift+s)
% -2: Exit completely (control+escape)
% (NB: no -1 for this function)

% setup text
Screen('TextFont',  wpnt, textSetup.font);
Screen('TextSize',  wpnt, textSetup.size);
Screen('TextStyle', wpnt, textSetup.style);
% setup box
REDmBox = [31 21]; % at 60 cm, doesn't matter as we need aspect ratio
boxSize = round(500.*REDmBox./REDmBox(1));
[boxCenter(1),boxCenter(2)] = RectCenter([0 0 boxSize]);
% position box
boxRect = CenterRectOnPoint([0 0 boxSize],scrInfo.center(1),scrInfo.center(2));
% setup arrows + their positions
aSize = 26;
arrow = [
    -0.52  -0.64
     0.52  -0.64
     0.52  -0.16
     1.00  -0.16
     0.00   0.64
    -1.00  -0.16
    -0.52  -0.16];
arrowsLRUDNF = {[-arrow(:,2) arrow(:,1)],[arrow(:,2) -arrow(:,1)],arrow,-arrow,arrow,-arrow};
arrowsLRUDNF{5}(1:2,1) = arrowsLRUDNF{5}(1:2,1)*.75;
arrowsLRUDNF{5}( : ,2) = arrowsLRUDNF{5}( : ,2)*.6;
arrowsLRUDNF{6}(1:2,1) = arrowsLRUDNF{6}(1:2,1)/.75;
arrowsLRUDNF{6}( : ,2) = arrowsLRUDNF{6}( : ,2)*.6;
arrowsLRUDNF = cellfun(@(x) round(x.*aSize),arrowsLRUDNF,'uni',false);
% positions relative to boxRect. add position to arrowsLRDUNF to get
% position of vertices in boxRect;
margin = 4;
arrowPos = cell(1,6);
arrowPos{1} = [boxSize(1)-margin-max(arrowsLRUDNF{1}(:,1)) boxCenter(2)];
arrowPos{2} = [           margin-min(arrowsLRUDNF{2}(:,1)) boxCenter(2)];
% down is special as need space underneath for near and far arrows
arrowPos{3} = [boxCenter(1)            margin-min(arrowsLRUDNF{3}(:,2))];
arrowPos{4} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{4}(:,2))-max(arrowsLRUDNF{5}(:,2))+min(arrowsLRUDNF{5}(:,2))];
arrowPos{5} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{5}(:,2))];
arrowPos{6} = [boxCenter(1) boxSize(2)-margin-max(arrowsLRUDNF{6}(:,2))];
% setup arrow colors and thresholds
col1 = [255 255 0]; % color for arrow when just visible, exceeding first threshold
col2 = [255 155 0]; % color for arrow when just visible, jhust before exceeding second threshold
col3 = [255 0   0]; % color for arrow when extreme, exceeding second threshold
xThresh = [2/3 .8];
yThresh = [.7  .85];
zThresh = [.7  .85];
% setup interface buttons, draw text once to get cache
yposBase    = round(scrInfo.rect(2)*.95);
buttonSz    = [250 45];
buttonOff   = 80;
baseRect    = OffsetRect([0 0 buttonSz],scrInfo.center(1),yposBase-buttonSz(2)); % left is now at screen center, bottom at right height
continueButRect     = OffsetRect(baseRect,-buttonOff/2-buttonSz(1),0);
[~,~,~,continueButTextCache] = DrawMonospacedText(wpnt,'continue (<i>space<i>)','center','center',0,[],[],[],OffsetRect(continueButRect,0,textSetup.lineCentOff));
eyeImageButRect     = OffsetRect(baseRect, buttonOff/2            ,0);
[~,~,~,eyeImageButTextCache] = DrawMonospacedText(wpnt,'eye image (<i>e<i>)'   ,'center','center',0,[],[],[],OffsetRect(eyeImageButRect,0,textSetup.lineCentOff));
Screen('FillRect', wpnt, scrInfo.bgclr); % clear what we've just drawn
eyeButClrs  = {[37  97 163],[11 122 244]};

% setup cursors
cursors.rect    = {continueButRect.' eyeImageButRect.'};
cursors.cursor  = [2 2];    % Hand
cursors.other   = 0;        % Arrow
if debugLevel<2  % for cleanup
    cursors.reset = -1; % hide cursor (else will reset to cursor.other by default, so we're good with that default
end
cursor          = cursorUpdater(cursors);

% subscribe to gaze data so we can get position in head box
startRecording();
hasEyeImage     = any(eyetracker.DeviceCapabilities==Capabilities.HasEyeImages);    % TODO: array or bittwiddle?
trackBox        = eyetracker.get_track_box();
trackBoxDepths  = double([trackBox.FrontLowerLeft(3) trackBox.BackLowerLeft(3)]./10);


% get tracking status and visualize, showing eye image as well if wanted
qShowEyeImage       = false;
qRecalculateRects   = false;
qFirstTimeEyeImage  = true;
tex             = 0;
arrowColor      = zeros(3,6);
eyeKeyDown      = false;
eyeClickDown    = false;
relPos          = zeros(3);
% for overlays in eye image. disable them all initially
toggleKeys      = KbName({'e'});
while true
    % get tracking status info (position in headbox)
    eyeData = getData(true);
    if isempty(eyeData)
        [lEye,rEye] = deal(nan(1,3));
    else
        % check if we have valid data, if not, go back to previous sample
        lEye = double(eyeData(end).LeftEye .GazeOrigin.InTrackBoxCoordinateSystem);
        rEye = double(eyeData(end).RightEye.GazeOrigin.InTrackBoxCoordinateSystem);
        if isnan(lEye)
            lEye = nan(1,3);
        end
        if isnan(rEye)
            rEye = nan(1,3);
        end
    end
    
    % get average eye distance. use distance from one eye if only one eye
    % available
    distL   = lEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
    distR   = rEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
    dists   = [distL distR];
    avgDist = mean(dists(~isnan(dists)));
    % if missing, estimate where eye would be in depth if user kept head yaw
    % constant
    if isnan(distL)
        distL = distR-relPos(3);
    elseif isnan(distR)
        distR = distL+relPos(3);
    end
    
    % see which arrows to draw
    qDrawArrow = false(1,6);
    xMid = -(     [lEye(1) rEye(1)] *2-1);
    yMid = -(     [lEye(2) rEye(2)] *2-1);
    zMid =   mean([lEye(3) rEye(3)])*2-1;
    if any(abs(xMid)>xThresh(1))
        [~,i] = max(abs(xMid));
        idx = 1 + (xMid(i)<0);  % if too far on the left, arrow should point to the right, etc below
        qDrawArrow(idx) = true;
        arrowColor(:,idx) = getArrowColor(xMid(i),xThresh,col1,col2,col3);
    end
    if any(abs(yMid)>yThresh(1))
        [~,i] = max(abs(yMid));
        idx = 3 + (yMid(i)<0);
        qDrawArrow(idx) = true;
        arrowColor(:,idx) = getArrowColor(yMid(i),yThresh,col1,col2,col3);
    end
    if abs(zMid)>zThresh(1)
        idx = 5 + (zMid>0);
        qDrawArrow(idx) = true;
        arrowColor(:,idx) = getArrowColor(zMid,zThresh,col1,col2,col3);
    end
    if qShowEyeImage
        % get eye image
        [ret,eyeImage] = eyetracker.getEyeImage(pImageDataS);
        if ret==1
            % clean up old one, if any
            if tex
                Screen('Close',tex);
            end
            tex = Screen('MakeTexture',wpnt,eyeImage,[],8);   % 8 to prevent mipmap generation, we don't need it
            if qRecalculateRects && qFirstTimeEyeImage
                % only calculate when first time to show image
                eyeImageRect= [0 0 size(eyeImage,2) size(eyeImage,1)];
            end
        end
    elseif tex
        Screen('Close',tex);
        tex = 0;
    end
    if qRecalculateRects && (~qShowEyeImage || (qShowEyeImage&&tex))
        if qShowEyeImage
            % now visible
            % center whole box+eye image on screen
            margin      = 80;
            sidespace   = round((scrInfo.rect(2)-RectHeight(boxRect)-margin-RectHeight(eyeImageRect))/2);
            % put boxrect such that it is sidespace pixels away from top of
            % screen
            boxRect     = OffsetRect(boxRect,0,sidespace-boxRect(2));
            if qFirstTimeEyeImage
                % only calculate all this once, it'll be the same the next
                % time we show the eye image.
                % move such that top-left of imRect is at right place
                eyeImageRect    = OffsetRect(eyeImageRect,scrInfo.center(1)-eyeImageRect(3)/2,sidespace+RectHeight(boxRect)+margin);
                qFirstTimeEyeImage = false;
            end
            % update cursors
            cursors.rect    = [cursors.rect {contourButRect.' pupilButRect.' reflexButRect.'}];
            cursors.cursor  = [2 2 2 2 2];
            cursor          = cursorUpdater(cursors);
        else
            % now hidden
            boxRect     = CenterRectOnPoint([0 0 boxSize],scrInfo.center(1),scrInfo.center(2));
            % update cursors: remove buttons for overlays in the eye image
            cursors.rect    = cursors.rect(1:2);
            cursors.cursor  = [2 2];
            cursor          = cursorUpdater(cursors);
        end
        qRecalculateRects = false;
    end
    
    % do drawing
    % draw box
    Screen('FillRect',wpnt,80,boxRect);
    % draw distance
    if ~isnan(avgDist)
        Screen('TextSize',  wpnt, 10);
        Screen('DrawText',wpnt,sprintf('%.0f cm',avgDist) ,boxRect(3)-40,boxRect(4)-16,255);
    end
    % draw eyes in box
    Screen('TextSize',  wpnt, textSetup.size);
    % scale up size of oval. define size/rect at standard distance (60cm),
    % have a gain for how much to scale as distance changes
    if ~isempty(eyeData) && (eyeData(end).LeftEye.GazeOrigin.Validity || eyeData(end).RightEye.GazeOrigin.Validity)
        posL = [1-lEye(1) lEye(2)];  %1-X as +1 is left and 0 is right. needs to be reflected for screen drawing
        posR = [1-rEye(1) rEye(2)];
        % determine size of eye. based on distance to standard distance of
        % 60cm, calculate size change
        fac  = 60/avgDist;
        facL = 60/distL;
        facR = 60/distR;
        gain = 1.5;  % 1.5 is a gain to make differences larger
        sz   = 15;
        % left eye
        style = Screen('TextStyle',  wpnt, 1);
        drawEye(wpnt,eyeData(end).LeftEye .GazeOrigin.Validity,posL,posR, relPos*fac,[255 120 120],[220 186 186],round(sz*facL*gain),'L',boxRect);
        % right eye
        drawEye(wpnt,eyeData(end).RightEye.GazeOrigin.Validity,posR,posL,-relPos*fac,[120 255 120],[186 220 186],round(sz*facR*gain),'R',boxRect);
        Screen('TextStyle',  wpnt, style);
        % update relative eye positions - used for drawing estimated
        % position of missing eye. X and Y are relative position in
        % headbox, Z is difference in measured eye depths
        if eyeData(end).LeftEye.GazeOrigin.Validity&&eyeData(end).RightEye.GazeOrigin.Validity
            relPos = [(posR-posL)/fac min(max(distR-distL,-8),8)];   % keep a distance normalized to eye-tracker distance of 60 cm, so we can scale eye distance with subject's distance from tracker correctly
        end
        % draw center
        if 0 && pTrackingStatus.total.validity
            pos = [pTrackingStatus.total.relativePositionX -pTrackingStatus.total.relativePositionY]/2+.5;
            pos = pos.*[diff(boxRect([1 3])) diff(boxRect([2 4]))]+boxRect(1:2);
            Screen('gluDisk',wpnt,[0 0 255],pos(1),pos(2),10)
        end
    end
    % draw arrows
    for p=find(qDrawArrow)
        Screen('FillPoly', wpnt, arrowColor(:,p), bsxfun(@plus,arrowsLRUDNF{p},arrowPos{p}+boxRect(1:2)) ,0);
    end
    % draw eye image, if any
    if tex
        Screen('DrawTexture', wpnt, tex,[],eyeImageRect);
    end
    % draw buttons
    Screen('FillRect',wpnt,[0 120   0],continueButRect);
    DrawMonospacedText(continueButTextCache);
    if hasEyeImage
        Screen('FillRect',wpnt,eyeButClrs{logical(tex)+1},eyeImageButRect);
        DrawMonospacedText(eyeImageButTextCache);
    end
    % drawing done, show
    Screen('Flip',wpnt);

    % check for keypresses or button clicks
    [mx,my,buttons] = GetMouse;
    [~,~,keyCode] = KbCheck;
    % update cursor look if needed
    cursor.update(mx,my);
    if any(buttons)
        % don't care which button for now. determine if clicked on either
        % of the buttons
        qIn = inRect([mx my],[continueButRect.' eyeImageButRect.']);
        if any(qIn)
            if qIn(1)
                status = 1;
                break;
            elseif ~eyeClickDown
                if qIn(2) && hasEyeImage
                    % show/hide eye image: reposition screen elements
                    qShowEyeImage       = ~qShowEyeImage;
                    qRecalculateRects   = true;     % can only do this when we know how large the image is
                end
                eyeClickDown = any(qIn);
            end
        end
    elseif any(keyCode)
        keys = KbName(keyCode);
        if any(strcmpi(keys,'space'))
            status = 1;
            break;
        elseif any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
            status = -2;
            break;
        elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
            % skip calibration
            status = 2;
            break;
        end
        if ~eyeKeyDown
            if any(strcmpi(keys,'e')) && hasEyeImage
                % show/hide eye image: reposition screen elements
                qShowEyeImage       = ~qShowEyeImage;
                qRecalculateRects   = true;     % can only do this when we know how large the image is
            end
        end
    end
    eyeKeyDown   = any(keyCode(toggleKeys));        % maintain button state so only one press counted until after key up
    eyeClickDown = eyeClickDown && any(buttons);    % maintain button state so only one press counted until after mouse up
end
% clean up
if tex
    Screen('Close',tex);
end
HideCursor;
stopRecording();
end

function arrowColor = getArrowColor(posRating,thresh,col1,col2,col3)
if abs(posRating)>thresh(2)
    arrowColor = col3;
else
    arrowColor = col1+(abs(posRating)-thresh(1))./diff(thresh)*(col2-col1);
end
end

function drawEye(wpnt,validity,pos,posOther,relPos,clr1,clr2,sz,lbl,boxRect)
% TODO: if eye leaves trackbox, fade it out from alpha=1 when fully inside
% (edge of disk) to alpha is zero when eye coordinate (center of disk) is
% out of box
if validity
    clr = clr1;
else
    clr = clr2;
    if any(relPos)
        pos = posOther-relPos(1:2);
    else
        return
    end
end
pos = pos.*[diff(boxRect([1 3])) diff(boxRect([2 4]))]+boxRect(1:2);
Screen('gluDisk',wpnt,clr,pos(1),pos(2),sz)
if validity
    bbox = Screen('TextBounds',wpnt,lbl);
    pos  = round(pos-bbox(3:4)/2);
    Screen('DrawText',wpnt,lbl,pos(1),pos(2),0);
end
end

function [status,out] = DoCal(wpnt,eyetracker,calSetup)
% calibrate
calibClass = ScreenBasedCalibration(eyetracker);
calibClass.enter_calibration_mode();
% show display
[status,out.cal] = DoCalPointDisplay(wpnt,calibClass,calSetup);
if status~=1
    calibClass.leave_calibration_mode();
    return;
end
out.cal.result = calibClass.compute_and_apply();
calibClass.leave_calibration_mode();

% if valid calibration retrieve data, so user can select different ones
if out.cal.result.Status
    out.cal.calData = eyetracker.retrieve_calibration_data();
end

% clear screen
Screen('Flip',wpnt);
end

function [status,out] = DoCalPointDisplay(wpnt,calibClass,calSetup)
% status output:
%  1: finished succesfully (you should query SMI software whether they think
%     calibration was succesful though)
%  2: skip calibration and continue with task (shift+s)
% -1: This calibration aborted/restart (escape key)
% -2: Exit completely (control+escape)

% setup output
out.flips = [];
out.point = [];
out.pointPos = [];

status = 1; % calibration went ok, unless otherwise noted below
nPoint = size(calSetup.calPointPosPix,1);
points = [calSetup.calPointPosPix [1:nPoint].' ones(nPoint,1)];
if calSetup.qCalRandPoints
    points = points(randperm(nPoint),:);
end
while ~isempty(points)
    % wait till keys released
    keyDown = 1;
    while keyDown
        WaitSecs('YieldSecs', 0.002);
        keyDown = KbCheck;
    end
    
    % draw point
    drawfixpoints(wpnt,points(1,1:2),{'thaler'},{[calSetup.fixBackSize calSetup.fixFrontSize]},{{calSetup.fixBackColor calSetup.fixFrontColor}},0);
    
    out.point(end+1)        = points(1,3);
    out.flips(end+1)        = Screen('Flip',wpnt);
    out.pointPos(end+1,:)   = points(1,1:2);
    % check for keys
    qBreak = false;
    while true
        [keyPressed,~,keyCode] = KbCheck();
        if keyPressed
            keys = KbName(keyCode);
            if any(strcmpi(keys,'space'))
                % minimum gaze duration of 1.5 s, wait if we're not that
                % far yet
                WaitSecs('UntilTime', out.flips(end)+1.5);
                collect_result = calibClass.collect_data(calSetup.calPointPos(points(1,3),:));
                if collect_result
                    % good point, remove
                    points(1,:) = [];
                else
                    % not good, potentially redo
                    temp = points(1,:);
                    points(1,:) = [];
                    if temp(4)
                        points = [points; temp];
                        points(end,end) = 0;    % if set to 0, wont be redone again even if fails again
                    end
                end
                break;
            elseif any(strcmpi(keys,'escape'))
                if any(strcmpi(keys,'shift'))
                    status = -2;
                else
                    status = -1;
                end
                qBreak = true;
                break;
            elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                % skip calibration
                status = 2;
                qBreak = true;
                break;
            end
        end
        
        WaitSecs('YieldSecs',.05);  % don't spin too fast
    end
    if qBreak
        break;
    end
end
end

function [status,selection] = showCalibrateImage(wpnt,cal,kCal,calSetup,scrInfo,textSetup)
% status output:
%  1: calibration/validation accepted, continue (a)
%  2: just continue with task (shift+s)
% -1: restart calibration (escape key)
% -2: Exit completely (control+escape)

% check if current calibration is valid
qCalValid = cal{kCal}.cal.result.Status;
% find how many valid calibrations we have:
selection = kCal;
iValid = find(cellfun(@(x) isfield(x,'cal')&&isfield(x.cal,'result')&&x.cal.result.Status,cal));
qShowSelect = numel(iValid)>2 || (~isempty(iValid) && ~qCalValid);

qDoneCalibSelection = false;
qSelectMenuOpen     = false;
scale = .8;
while ~qDoneCalibSelection
    % draw validation screen image
    % draw box
    boxRect     = CenterRectOnPoint([0 0 scrInfo.rect*scale],scrInfo.center(1),scrInfo.center(2));
    [brw,brh]   = RectSize(boxRect);
    Screen('FillRect',wpnt,80,boxRect);
    % draw calibration points
    myCal = cal{selection}.cal.result.CalibrationPoints;
    for p=1:length(myCal)
        pos = myCal(p).PositionOnDisplayArea.*[brw brh]+boxRect(1:2);
        drawfixpoints(wpnt,pos,{'thaler'},{[calSetup.fixBackSize calSetup.fixFrontSize]*scale},{{calSetup.fixBackColor calSetup.fixFrontColor}},0);
    end
    % draw captured data in characteristic tobii plot
    for p=1:length(myCal)
        bpos = double(myCal(p).PositionOnDisplayArea).*[brw brh]+boxRect(1:2);
        % left eye
        qVal = cat(1,myCal(p).LeftEye.Validity)==1;
        if any(qVal)
            lEpos= bsxfun(@plus,bsxfun(@times,double(cat(1,myCal(p).LeftEye(qVal).PositionOnDisplayArea)),[brw brh]),boxRect(1:2));
            for l=1:size(lEpos,1)
                Screen('DrawLines',wpnt,[bpos.' lEpos(l,:).'],1,[255 0 0],[],2);
            end
        end
        % right eye
        qVal = cat(1,myCal(p).RightEye.Validity)==1;
        if any(qVal)
            rEpos= bsxfun(@plus,bsxfun(@times,double(cat(1,myCal(p).RightEye(qVal).PositionOnDisplayArea)),[brw brh]),boxRect(1:2));
            for l=1:size(rEpos,1)
                Screen('DrawLines',wpnt,[bpos.' rEpos(l,:).'],1,[0 255 0],[],2);
            end
        end
    end
    % setup text
    Screen('TextFont',  wpnt, textSetup.font);
    Screen('TextSize',  wpnt, textSetup.size);
    Screen('TextStyle', wpnt, textSetup.style);
    if ~qCalValid
        DrawFormattedText(wpnt,'Calibration invalid','center',scrInfo.rect(2)*.06,[255 0 0]);
    end
    % place buttons
    yposBase    = round(scrInfo.rect(2)*.96);
    buttonSz    = {[300 45] [300 45] [350 45]};
    buttonSz    = buttonSz(1:2+qShowSelect);  % third button only when more than one calibration available
    buttonOff   = 80;
    buttonWidths= cellfun(@(x) x(1),buttonSz);
    totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
    buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
    continueRect= OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],scrInfo.center(1),yposBase-buttonSz{1}(2));
    recalRect   = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],scrInfo.center(1),yposBase-buttonSz{2}(2));
    if qShowSelect
        selectRect  = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],scrInfo.center(1),yposBase-buttonSz{3}(2));
    else
        selectRect = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
    end
    % draw buttons
    if qCalValid
        Screen('FillRect',wpnt,[0 120 0],continueRect);
        DrawMonospacedText(wpnt,'continue (<i>space<i>)'    ,'center','center',0,[],[],[],OffsetRect(continueRect,0,textSetup.lineCentOff));
    end
    Screen('FillRect',wpnt,[150 0 0],recalRect);
    DrawMonospacedText(wpnt,'recalibrate (<i>esc<i>)'       ,'center','center',0,[],[],[],OffsetRect(recalRect   ,0,textSetup.lineCentOff));
    if qShowSelect
        Screen('FillRect',wpnt,[150 150 0],selectRect);
        DrawMonospacedText(wpnt,'select other cal (<i>c<i>)','center','center',0,[],[],[],OffsetRect(selectRect  ,0,textSetup.lineCentOff));
    end
    % if selection menu open, draw on top
    if qSelectMenuOpen
        margin      = 10;
        pad         = 3;
        height      = 45;
        nElem       = length(iValid);
        totHeight   = nElem*(height+pad)-pad;
        width       = 80;
        % menu background
        menuBackRect= [-.5*width+scrInfo.center(1)-margin -.5*totHeight+scrInfo.center(2)-margin .5*width+scrInfo.center(1)+margin .5*totHeight+scrInfo.center(2)+margin];
        Screen('FillRect',wpnt,140,menuBackRect);
        % menuRects
        menuRects = repmat([-.5*width+scrInfo.center(1) -height/2+scrInfo.center(2) .5*width+scrInfo.center(1) height/2+scrInfo.center(2)],length(iValid),1);
        menuRects = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]);
        Screen('FillRect',wpnt,110,menuRects.');
        % text in each rect
        for c=1:length(iValid)
            str = sprintf('(%d)',c);
            DrawMonospacedText(wpnt,str,'center','center',0,[],[],[],OffsetRect(menuRects(c,:),0,textSetup.lineCentOff));
        end
    end
    % drawing done, show
    Screen('Flip',wpnt);
    % setup cursors
    if qSelectMenuOpen
        cursors.rect    = {menuRects.',continueRect.',recalRect.'};
        cursors.cursor  = 2*ones(1,size(menuRects,1)+2);    % 2: Hand
        % if no continue rect, don't have its area clickable either
        if ~qCalValid
            cursors.rect{2} = [-100 -90 -100 -90].';
        end
    else
        cursors.rect    = {continueRect.',recalRect.',selectRect.'};
        cursors.cursor  = [2 2 2];  % 2: Hand
        % if no continue rect, don't have its area clickable either
        if ~qCalValid
            cursors.rect{1} = [-100 -90 -100 -90].';
        end
    end
    cursors.other   = 0;    % 0: Arrow
    cursors.qReset  = false;
    % NB: don't reset cursor to invisible here as it will then flicker every
    % time you click something. default behaviour is good here
    
    % get user response
    cursor = cursorUpdater(cursors);
    while true
        [keyPressed,~,keyCode]  = KbCheck();
        [mx,my,buttons]         = GetMouse;
        cursor.update(mx,my);
        if any(buttons)
            % don't care which button for now. determine if clicked on either
            % of the buttons
            qBreak = false;
            if qSelectMenuOpen
                iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                if ~isempty(iIn) && iIn<=length(iValid)
                    selection = iValid(iIn);
                    qCalValid = true;
                    qSelectMenuOpen = false;
                    qBreak = true;
                else
                    qSelectMenuOpen = false;
                    qBreak = true;
                end
            end
            if ~qSelectMenuOpen     % if just pressed outside the menu, check if pressed any of these menu buttons
                qIn = inRect([mx my],[continueRect.' recalRect.' selectRect.']);
                if any(qIn)
                    if qIn(1) && qCalValid
                        status = 1;
                        qDoneCalibSelection = true;
                    elseif qIn(2)
                        status = -1;
                        qDoneCalibSelection = true;
                    elseif qIn(3)
                        qSelectMenuOpen     = true;
                    end
                    qBreak = true;
                end
            end
            if qBreak
                break;
            end
        elseif keyPressed
            keys = KbName(keyCode);
            if qSelectMenuOpen
                if any(strcmpi(keys,'escape'))
                    qSelectMenuOpen = false;
                    break;
                elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance
                    idx = str2double(keys(1));
                    selection = iValid(idx);
                    qCalValid = true;
                    qSelectMenuOpen = false;
                    break;
                end
            else
                if any(strcmpi(keys,'space')) && qCalValid
                    status = 1;
                    qDoneCalibSelection = true;
                    break;
                elseif any(strcmpi(keys,'escape')) && ~any(strcmpi(keys,'shift'))
                    status = -1;
                    qDoneCalibSelection = true;
                    break;
                elseif any(strcmpi(keys,'c')) && qShowSelect
                    qSelectMenuOpen = true;
                    break;
                end
            end
            
            % these two key combinations should always be available
            if any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
                status = -2;
                qDoneCalibSelection = true;
                break;
            elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                % skip calibration
                iView.abortCalibration();
                status = 2;
                qDoneCalibSelection = true;
                break;
            end
        end
        
        WaitSecs('YieldSecs',.01);  % don't spin too fast
    end
    cursor.reset();
end
if status~=1
    selection = NaN;
end
HideCursor;
end

function [status,out] = DoVal(wpnt,calSetup,startRecording,getData,stopRecording)
% validate
startRecording();
% show display
[status,out] = DoValPointDisplay(wpnt,calSetup);
if status~=1
    return;
end
% get data
[out.samples,out.syncData] = getData(true);
stopRecording();

% clear screen
Screen('Flip',wpnt);
end

function [status,out] = DoValPointDisplay(wpnt,calSetup)
% status output:
%  1: finished succesfully (you should query SMI software whether they think
%     calibration was succesful though)
%  2: skip calibration and continue with task (shift+s)
% -1: This calibration aborted/restart (escape key)
% -2: Exit completely (control+escape)

% setup output
out.flips = [];
out.point = [];
out.pointPos = [];

status = 1; % calibration went ok, unless otherwise noted below
nPoint = size(calSetup.valPointPosPix,1);
points = [calSetup.valPointPosPix [1:nPoint].' ones(nPoint,1)];
if calSetup.qCalRandPoints
    points = points(randperm(nPoint),:);
end
while ~isempty(points)
    % wait till keys released
    keyDown = 1;
    while keyDown
        WaitSecs('YieldSecs', 0.002);
        keyDown = KbCheck;
    end
    
    % draw point
    drawfixpoints(wpnt,points(1,1:2),{'thaler'},{[calSetup.fixBackSize calSetup.fixFrontSize]},{{calSetup.fixBackColor calSetup.fixFrontColor}},0);
    
    out.point(end+1)        = points(1,3);
    out.flips(end+1)        = Screen('Flip',wpnt);
    out.pointPos(end+1,:)   = points(1,1:2);
    % check for keys
    qBreak = false;
    while true
        [keyPressed,~,keyCode] = KbCheck();
        if keyPressed
            keys = KbName(keyCode);
            if any(strcmpi(keys,'space'))
                % minimum gaze duration of 1.5 s, wait if we're not that
                % far yet
                WaitSecs('UntilTime', out.flips(end)+1.5);
                % remove for "to display" list, continue to next point
                points(1,:) = [];
                break;
            elseif any(strcmpi(keys,'escape'))
                if any(strcmpi(keys,'shift'))
                    status = -2;
                else
                    status = -1;
                end
                qBreak = true;
                break;
            elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                % skip calibration
                status = 2;
                qBreak = true;
                break;
            end
        end
        
        WaitSecs('YieldSecs',.05);  % don't spin too fast
    end
    if qBreak
        break;
    end
end
end

function [status,selection] = showValidateImage(wpnt,cal,kCal,calSetup,scrInfo,textSetup)
% status output:
%  1: calibration/validation accepted, continue (a)
%  2: just continue with task (shift+s)
% -1: restart calibration (escape key)
% -2: Exit completely (control+escape)

% find how many valid calibrations we have:
selection = kCal;
iValid = find(cellfun(@(x) isfield(x,'cal')&&isfield(x.cal,'result')&&x.cal.result.Status,cal));

qDoneCalibSelection = false;
qSelectMenuOpen     = false;
scale = .8;
while ~qDoneCalibSelection
    % draw validation screen image
    % draw box
    boxRect     = CenterRectOnPoint([0 0 scrInfo.rect*scale],scrInfo.center(1),scrInfo.center(2));
    [brw,brh]   = RectSize(boxRect);
    Screen('FillRect',wpnt,80,boxRect);
    % draw calibration points
    if isfield(cal{selection},'val')
        myVal = cal{selection}.val;
        for p=1:size(myVal.pointPos,1)
            pos = myVal.pointPos(p,:)*scale+boxRect(1:2);
            drawfixpoints(wpnt,pos,{'thaler'},{[calSetup.fixBackSize calSetup.fixFrontSize]*scale},{{calSetup.fixBackColor calSetup.fixFrontColor}},0);
        end
        % draw captured data
        for p=1:length(myVal)
            % left eye
            lE = cat(1,myVal.samples.LeftEye); lE = cat(1,lE.GazePoint);
            qVal = cat(1,lE.Validity)==1;
            lEpos= bsxfun(@plus,bsxfun(@times,cat(1,double(cat(1,lE(qVal).OnDisplayArea))),[brw brh]),boxRect(1:2));
            Screen('DrawDots',wpnt,lEpos.',2,[255 0 0],[],2);
            % right eye
            rE = cat(1,myVal.samples.RightEye); rE = cat(1,rE.GazePoint);
            qVal = cat(1,rE.Validity)==1;
            rEpos= bsxfun(@plus,bsxfun(@times,cat(1,double(cat(1,rE(qVal).OnDisplayArea))),[brw brh]),boxRect(1:2));
            Screen('DrawDots',wpnt,rEpos.',2,[0 255 0],[],2);
        end
    else
        DrawFormattedText(wpnt,'No validation done for this calibration','center','center',0);
    end
    % setup text
    Screen('TextFont',  wpnt, textSetup.font);
    Screen('TextSize',  wpnt, textSetup.size);
    Screen('TextStyle', wpnt, textSetup.style);
    % draw text with validation accuracy info
%     valText = sprintf('<size=20>Accuracy  <color=ff0000>Left<color>: <size=18><font=Georgia><i>X<i><font><size> = %.2f°, <size=18><font=Georgia><i>Y<i><font><size> = %.2f°\nAccuracy <color=00ff00>Right<color>: <size=18><font=Georgia><i>X<i><font><size> = %.2f°, <size=18><font=Georgia><i>Y<i><font><size> = %.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY,cal{selection}.validateAccuracy.deviationRX,cal{selection}.validateAccuracy.deviationRY);
%     DrawMonospacedText(wpnt,valText,'center',100,255,[],textSetup.vSpacing);
    % place buttons
    yposBase    = round(scrInfo.rect(2)*.95);
    buttonSz    = {[200 45] [300 45] [350 45]};
    buttonSz    = buttonSz(1:2+~isscalar(iValid));  % third button only when more than one calibration available
    buttonOff   = 80;
    buttonWidths= cellfun(@(x) x(1),buttonSz);
    totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
    buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
    acceptRect  = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],scrInfo.center(1),yposBase-buttonSz{1}(2));
    recalRect   = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],scrInfo.center(1),yposBase-buttonSz{2}(2));
    if ~isscalar(iValid)
        selectRect  = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],scrInfo.center(1),yposBase-buttonSz{3}(2));
    else
        selectRect = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
    end
    % draw buttons
    Screen('FillRect',wpnt,[0 120 0],acceptRect);
    DrawMonospacedText(wpnt,'accept (<i>a<i>)'       ,'center','center',0,[],[],[],OffsetRect(acceptRect,0,textSetup.lineCentOff));
    Screen('FillRect',wpnt,[150 0 0],recalRect);
    DrawMonospacedText(wpnt,'recalibrate (<i>esc<i>)','center','center',0,[],[],[],OffsetRect(recalRect ,0,textSetup.lineCentOff));
    if ~isscalar(iValid)
        Screen('FillRect',wpnt,[150 150 0],selectRect);
        DrawMonospacedText(wpnt,'select other cal (<i>c<i>)','center','center',0,[],[],[],OffsetRect(selectRect ,0,textSetup.lineCentOff));
    end
    % if selection menu open, draw on top
    if qSelectMenuOpen
        margin      = 10;
        pad         = 3;
        height      = 45;
        nElem       = length(iValid);
        totHeight   = nElem*(height+pad)-pad;
        width       = 80;
        % menu background
        menuBackRect= [-.5*width+scrInfo.center(1)-margin -.5*totHeight+scrInfo.center(2)-margin .5*width+scrInfo.center(1)+margin .5*totHeight+scrInfo.center(2)+margin];
        Screen('FillRect',wpnt,140,menuBackRect);
        % menuRects
        menuRects = repmat([-.5*width+scrInfo.center(1) -height/2+scrInfo.center(2) .5*width+scrInfo.center(1) height/2+scrInfo.center(2)],length(iValid),1);
        menuRects = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]);
        Screen('FillRect',wpnt,110,menuRects.');
        % text in each rect
        for c=1:length(iValid)
            str = sprintf('(%d)',c);
            DrawMonospacedText(wpnt,str,'center','center',0,[],[],[],OffsetRect(menuRects(c,:),0,textSetup.lineCentOff));
        end
    end
    % drawing done, show
    Screen('Flip',wpnt);
    % setup cursors
    if qSelectMenuOpen
        cursors.rect    = {menuRects.',acceptRect.',recalRect.'};
        cursors.cursor  = 2*ones(1,size(menuRects,1)+2);    % 2: Hand
    else
        cursors.rect    = {acceptRect.',recalRect.',selectRect.'};
        cursors.cursor  = [2 2 2];  % 2: Hand
    end
    cursors.other   = 0;    % 0: Arrow
    cursors.qReset  = false;
    % NB: don't reset cursor to invisible here as it will then flicker every
    % time you click something. default behaviour is good here
    
    % get user response
    cursor = cursorUpdater(cursors);
    while true
        [keyPressed,~,keyCode]  = KbCheck();
        [mx,my,buttons]         = GetMouse;
        cursor.update(mx,my);
        if any(buttons)
            % don't care which button for now. determine if clicked on either
            % of the buttons
            qBreak = false;
            if qSelectMenuOpen
                iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                if ~isempty(iIn) && iIn<=length(iValid)
                    selection = iValid(iIn);
                    qSelectMenuOpen = false;
                    qBreak = true;
                else
                    qSelectMenuOpen = false;
                    qBreak = true;
                end
            end
            if ~qSelectMenuOpen     % if just pressed outside the menu, check if pressed any of these menu buttons
                qIn = inRect([mx my],[acceptRect.' recalRect.' selectRect.']);
                if any(qIn)
                    if qIn(1)
                        status = 1;
                        qDoneCalibSelection = true;
                    elseif qIn(2)
                        status = -1;
                        qDoneCalibSelection = true;
                    elseif qIn(3)
                        qSelectMenuOpen     = true;
                    end
                    qBreak = true;
                end
            end
            if qBreak
                break;
            end
        elseif keyPressed
            keys = KbName(keyCode);
            if qSelectMenuOpen
                if any(strcmpi(keys,'escape'))
                    qSelectMenuOpen = false;
                    break;
                elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance
                    idx = str2double(keys(1));
                    selection = iValid(idx);
                    qSelectMenuOpen = false;
                    break;
                end
            else
                if any(strcmpi(keys,'a'))
                    status = 1;
                    qDoneCalibSelection = true;
                    break;
                elseif any(strcmpi(keys,'escape')) && ~any(strcmpi(keys,'shift'))
                    status = -1;
                    qDoneCalibSelection = true;
                    break;
                elseif any(strcmpi(keys,'c')) && ~isscalar(iValid)
                    qSelectMenuOpen = true;
                    break;
                end
            end
            
            % these two key combinations should always be available
            if any(strcmpi(keys,'escape')) && any(strcmpi(keys,'shift'))
                status = -2;
                qDoneCalibSelection = true;
                break;
            elseif any(strcmpi(keys,'s')) && any(strcmpi(keys,'shift'))
                % skip calibration
                iView.abortCalibration();
                status = 2;
                qDoneCalibSelection = true;
                break;
            end
        end
        
        WaitSecs('YieldSecs',.01);  % don't spin too fast
    end
    % done, clean up
    cursor.reset();
end
if status~=1
    selection = NaN;
end
HideCursor;
end
