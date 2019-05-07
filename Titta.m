classdef Titta < handle
    properties (Access = protected, Hidden = true)
        % dll and mex files
        tobii;
        eyetracker;
        
        % message buffer
        msgs;
        
        % state
        isInitialized       = false;
        usingFTGLTextRenderer;
        keyState;
        shiftKey;
        mouseState;
        qFloatColorRange;
        calibrateLeftEye    = true;
        calibrateRightEye   = true;
        
        % settings and external info
        settings;
        scrInfo;
    end
    
    properties (SetAccess=protected)
        systemInfo;
        geom;
        calibrateHistory;
        buffer;
    end
    
    % computed properties (so not actual properties)
    properties (Dependent, SetAccess = private)
        rawSDK;         % get naked Tobii SDK instance
        rawET;          % get naked Tobii SDK handle to eyetracker
    end
    
    methods
        function obj = Titta(settingsOrETName)
            % deal with inputs
            if ischar(settingsOrETName)
                % only eye-tracker name provided, load defaults for this
                % tracker
                obj.setOptions(obj.getDefaults(settingsOrETName));
            else
                obj.setOptions(settingsOrETName);
            end
            
            obj.msgs = simpleVec(cell(1,2),1024);   % (re)initialize with space for 1024 messages
        end
        
        function delete(obj)
            obj.deInit();
        end
        
        function out = setDummyMode(obj)
            assert(nargout==1,'Titta: you must use the output argument of setDummyMode, like: TobiiHandle = TobiiHandle.setDummyMode(), or TobiiHandle = setDummyMode(TobiiHandle)')
            out = TittaDummyMode(obj);
        end
        
        function out = get.rawSDK(obj)
            out = obj.tobii;
        end
        
        function out = get.rawET(obj)
            out = obj.eyetracker;
        end
        
        function out = getOptions(obj)
            if ~obj.isInitialized
                % return all settings
                out = obj.settings;
            else
                % only the subset that can be changed "live"
                opts = obj.getAllowedOptions();
                for p=1:size(opts,1)
                    if isempty(opts{p,2})
                        out.(opts{p,1})             = obj.settings.(opts{p,1});
                    else
                        out.(opts{p,1}).(opts{p,2}) = obj.settings.(opts{p,1}).(opts{p,2});
                    end
                end
            end
        end
        
        function setOptions(obj,settings)
            if obj.isInitialized
                % only a subset of settings is allowed. Hardcode here, and
                % copy over if exist. Ignore all others silently
                allowed = obj.getAllowedOptions();
                for p=1:size(allowed,1)
                    if isfield(settings,allowed{p,1}) && (isempty(allowed{p,2}) || isfield(settings.(allowed{p,1}),allowed{p,2}))
                        if isempty(allowed{p,2})
                            obj.settings.(allowed{p,1})                 = settings.(allowed{p,1});
                        else
                            obj.settings.(allowed{p,1}).(allowed{p,2})  = settings.(allowed{p,1}).(allowed{p,2});
                        end
                    end
                end
            else
                defaults    = obj.getDefaults(settings.tracker);
                expected    = getStructFieldsString(defaults);
                input       = getStructFieldsString(settings);
                qMissing    = ~ismember(expected,input);
                qAdded      = ~ismember(input,expected);
                if any(qMissing)
                    params = sprintf('\n  settings.%s',expected{qMissing});
                    error('Titta: For the %s tracker, the following settings are expected, but were not provided by you:%s\nAdd these to your settings input.',settings.tracker,params);
                end
                if any(qAdded)
                    params = sprintf('\n  settings.%s',input{qAdded});
                    error('Titta: For the %s tracker, the following settings are not expected, but were provided by you:%s\nRemove these from your settings input.',settings.tracker,params);
                end
                obj.settings = settings;
            end
            % setup colors
            obj.settings.UI.val.eyeColors               = color2RGBA(obj.settings.UI.val.eyeColors);
            obj.settings.UI.val.onlineGaze.eyeColors    = color2RGBA(obj.settings.UI.val.onlineGaze.eyeColors);
            obj.settings.UI.val.avg.text.eyeColors      = color2RGBA(obj.settings.UI.val.avg.text.eyeColors);
            obj.settings.UI.val.hover.text.eyeColors    = color2RGBA(obj.settings.UI.val.hover.text.eyeColors);
            obj.settings.UI.val.menu.text.eyeColors     = color2RGBA(obj.settings.UI.val.menu.text.eyeColors);
            
            obj.settings.UI.setup.bgColor               = color2RGBA(obj.settings.UI.setup.bgColor);
            obj.settings.UI.setup.fixBackColor          = color2RGBA(obj.settings.UI.setup.fixBackColor);
            obj.settings.UI.setup.fixFrontColor         = color2RGBA(obj.settings.UI.setup.fixFrontColor);
            obj.settings.UI.setup.instruct.color        = color2RGBA(obj.settings.UI.setup.instruct.color);
            obj.settings.UI.cal.errMsg.color            = color2RGBA(obj.settings.UI.cal.errMsg.color);
            obj.settings.UI.val.bgColor                 = color2RGBA(obj.settings.UI.val.bgColor);
            obj.settings.UI.val.fixBackColor            = color2RGBA(obj.settings.UI.val.fixBackColor);
            obj.settings.UI.val.fixFrontColor           = color2RGBA(obj.settings.UI.val.fixFrontColor);
            obj.settings.UI.val.onlineGaze.fixBackColor = color2RGBA(obj.settings.UI.val.onlineGaze.fixBackColor);
            obj.settings.UI.val.onlineGaze.fixFrontColor= color2RGBA(obj.settings.UI.val.onlineGaze.fixFrontColor);
            obj.settings.UI.val.avg.text.color          = color2RGBA(obj.settings.UI.val.avg.text.color);
            obj.settings.UI.val.hover.bgColor           = color2RGBA(obj.settings.UI.val.hover.bgColor);
            obj.settings.UI.val.hover.text.color        = color2RGBA(obj.settings.UI.val.hover.text.color);
            obj.settings.UI.val.menu.bgColor            = color2RGBA(obj.settings.UI.val.menu.bgColor);
            obj.settings.UI.val.menu.itemColor          = color2RGBA(obj.settings.UI.val.menu.itemColor);
            obj.settings.UI.val.menu.itemColorActive    = color2RGBA(obj.settings.UI.val.menu.itemColorActive);
            obj.settings.UI.val.menu.text.color         = color2RGBA(obj.settings.UI.val.menu.text.color);
            obj.settings.cal.bgColor                    = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor               = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor              = color2RGBA(obj.settings.cal.fixFrontColor);
            
            obj.settings.UI.button.setup.eyeIm.buttonColor  = color2RGBA(obj.settings.UI.button.setup.eyeIm.buttonColor);
            obj.settings.UI.button.setup.eyeIm.textColor    = color2RGBA(obj.settings.UI.button.setup.eyeIm.textColor);
            obj.settings.UI.button.setup.cal.buttonColor    = color2RGBA(obj.settings.UI.button.setup.cal.buttonColor);
            obj.settings.UI.button.setup.cal.textColor      = color2RGBA(obj.settings.UI.button.setup.cal.textColor);
            obj.settings.UI.button.setup.prevcal.buttonColor= color2RGBA(obj.settings.UI.button.setup.prevcal.buttonColor);
            obj.settings.UI.button.setup.prevcal.textColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.textColor);
            obj.settings.UI.button.val.recal.buttonColor    = color2RGBA(obj.settings.UI.button.val.recal.buttonColor);
            obj.settings.UI.button.val.recal.textColor      = color2RGBA(obj.settings.UI.button.val.recal.textColor);
            obj.settings.UI.button.val.reval.buttonColor    = color2RGBA(obj.settings.UI.button.val.reval.buttonColor);
            obj.settings.UI.button.val.reval.textColor      = color2RGBA(obj.settings.UI.button.val.reval.textColor);
            obj.settings.UI.button.val.continue.buttonColor = color2RGBA(obj.settings.UI.button.val.continue.buttonColor);
            obj.settings.UI.button.val.continue.textColor   = color2RGBA(obj.settings.UI.button.val.continue.textColor);
            obj.settings.UI.button.val.selcal.buttonColor   = color2RGBA(obj.settings.UI.button.val.selcal.buttonColor);
            obj.settings.UI.button.val.selcal.textColor     = color2RGBA(obj.settings.UI.button.val.selcal.textColor);
            obj.settings.UI.button.val.setup.buttonColor    = color2RGBA(obj.settings.UI.button.val.setup.buttonColor);
            obj.settings.UI.button.val.setup.textColor      = color2RGBA(obj.settings.UI.button.val.setup.textColor);
            obj.settings.UI.button.val.toggGaze.buttonColor = color2RGBA(obj.settings.UI.button.val.toggGaze.buttonColor);
            obj.settings.UI.button.val.toggGaze.textColor   = color2RGBA(obj.settings.UI.button.val.toggGaze.textColor);
            obj.settings.UI.button.val.toggCal.buttonColor  = color2RGBA(obj.settings.UI.button.val.toggCal.buttonColor);
            obj.settings.UI.button.val.toggCal.textColor    = color2RGBA(obj.settings.UI.button.val.toggCal.textColor);
            
            % check requested eye calibration mode
            assert(ismember(obj.settings.calibrateEye,{'both','left','right'}),'Monocular/binocular recording setup ''%s'' not recognized. Supported modes are [''both'', ''left'', ''right'']',obj.settings.calibrateEye)
            if ismember(obj.settings.calibrateEye,{'left','right'}) && obj.isInitialized
                assert(obj.hasCap(EyeTrackerCapabilities.CanDoMonocularCalibration),'You requested recording from only the %s eye, but this %s does not support monocular calibrations. Set mode to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
            end
            switch obj.settings.calibrateEye
                case 'both'
                    obj.calibrateLeftEye  = true;
                    obj.calibrateRightEye = true;
                case 'left'
                    obj.calibrateLeftEye  = true;
                    obj.calibrateRightEye = false;
                case 'right'
                    obj.calibrateLeftEye  = false;
                    obj.calibrateRightEye = true;
            end
        end
        
        function out = init(obj)
            % Load in Tobii SDK
            obj.tobii = EyeTrackingOperations();
            
            % Load in our callback buffer mex
            obj.buffer = TobiiBuffer();
            obj.buffer.startLogging();
            
            % Connect to eyetracker
            iTry = 1;
            while true
                if iTry<obj.settings.nTryConnect
                    func = @warning;
                else
                    func = @error;
                end
                % see which eye trackers are available
                trackers = obj.tobii.find_all_eyetrackers();
                % find macthing eye-tracker, first by model
                if isempty(trackers) || ~any(strcmp({trackers.Model},obj.settings.tracker))
                    extra = '';
                    if iTry==obj.settings.nTryConnect
                        if ~isempty(trackers)
                            extra = sprintf('\nI did find the following:%s',sprintf('\n  %s',trackers.Model));
                        else
                            extra = sprintf('\nNo trackers connected.');
                        end
                    end
                    func('Titta: No trackers of model ''%s'' connected%s',obj.settings.tracker,extra);
                    WaitSecs(obj.settings.connectRetryWait);
                    iTry = iTry+1;
                    continue;
                end
                qModel = strcmp({trackers.Model},obj.settings.tracker);
                % if obligatory serial also given, check on that
                % a serial number preceeded by '*' denotes the serial number is
                % optional. That means that if only a single other tracker of
                % the same type is found, that one will be used.
                assert(sum(qModel)==1 || ~isempty(obj.settings.serialNumber),'Titta: If more than one connected eye-tracker is of the requested model, a serial number must be provided to allow connecting to the right one')
                if sum(qModel)>1 || (~isempty(obj.settings.serialNumber) && obj.settings.serialNumber(1)~='*')
                    % more than one tracker found or non-optional serial
                    serial = obj.settings.serialNumber;
                    if serial(1)=='*'
                        serial(1) = [];
                    end
                    qTracker = qModel & strcmp({trackers.SerialNumber},serial);
                    
                    if ~any(qTracker)
                        extra = '';
                        if iTry==obj.settings.nTryConnect
                            extra = sprintf('\nI did find trackers of model ''%s'' with the following serial numbers:%s',obj.settings.tracker,sprintf('\n  %s',trackers.SerialNumber));
                        end
                        func('Titta: No trackers of model ''%s'' with serial ''%s'' connected.%s',obj.settings.tracker,serial,extra);
                        WaitSecs(obj.settings.connectRetryWait);
                        iTry = iTry+1;
                        continue;
                    else
                        break;
                    end
                else
                    % the single tracker we found is fine, use it
                    qTracker = qModel;
                    break;
                end
            end
            % get our instance
            obj.eyetracker = trackers(qTracker);
            
            % provide callback buffer mex with eye tracker
            obj.buffer.init(obj.eyetracker.Address);
            
            % apply license(s) if needed
            if ~isempty(obj.settings.licenseFile)
                if ~iscell(obj.settings.licenseFile)
                    obj.settings.licenseFile = {obj.settings.licenseFile};
                end
                
                % load license files
                nLicenses   = length(obj.settings.licenseFile);
                licenses    = LicenseKey.empty(nLicenses,0);
                for l = 1:nLicenses
                    fid = fopen(obj.settings.licenseFile{l},'r');   % users should provide fully qualified paths or paths that are valid w.r.t. pwd
                    licenses(l) = LicenseKey(fread(fid));
                    fclose(fid);
                end
                
                % apply to selected eye tracker.
                % Should return empty if all the licenses were correctly applied.
                failed_licenses = obj.eyetracker.apply_licenses(licenses);
                assert(isempty(failed_licenses),'Titta: provided license(s) couldn''t be applied')
            end
            
            % set tracker to operate at requested tracking frequency
            try
                obj.eyetracker.set_gaze_output_frequency(obj.settings.freq);
            catch ME
                % provide nice error message
                allFs = obj.eyetracker.get_all_gaze_output_frequencies();
                allFs = ['[' sprintf('%d, ',allFs) ']']; allFs(end-2:end-1) = [];
                error('Titta: Error setting tracker sampling frequency to %d. Possible tracking frequencies for this %s are %s.\nRaw error info:\n%s',obj.settings.freq,obj.settings.tracker,allFs,ME.getReport('extended'))
            end
            
            % set eye tracking mode. NB: When using firmware older than
            % 1.7.6, the only support eye tracking mode is 'Default'
            if ~isempty(obj.settings.trackingMode)
                try
                    obj.eyetracker.set_eye_tracking_mode(obj.settings.trackingMode);
                catch ME
                    % add info about possible tracking modes.
                    allModes = obj.eyetracker.get_all_eye_tracking_modes();
                    allModes = ['[' sprintf('''%s'', ',allModes{:}) ']']; allModes(end-2:end-1) = [];
                    error('Titta: Error setting tracker mode to ''%s''. Possible tracking modes for this %s are %s. If a mode you expect is missing, check whether the eye tracker firmware is up to date.\nRaw error info:\n%s',obj.settings.trackingMode,obj.settings.tracker,allModes,ME.getReport('extended'))
                end
            end
            
            % if monocular tracking is requested, check that it is
            % supported
            if ismember(obj.settings.calibrateEye,{'left','right'})
                assert(obj.hasCap(EyeTrackerCapabilities.CanDoMonocularCalibration),'You requested recording from only the %s eye, but this %s does not support monocular calibrations. Set mode to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
            end
            
            % get info about the system
            fields = {'Name','SerialNumber','Model','FirmwareVersion','Address'};
            for f=1:length(fields)
                obj.systemInfo.(fields{f}) = obj.eyetracker.(fields{f});
            end
            obj.systemInfo.samplerate   = obj.eyetracker.get_gaze_output_frequency();
            assert(obj.systemInfo.samplerate==obj.settings.freq,'Titta: Tracker not running at requested sampling rate (%d Hz), but at %d Hz',obj.settings.freq,obj.systemInfo.samplerate);
            obj.systemInfo.trackingMode = obj.eyetracker.get_eye_tracking_mode();
            out.systemInfo              = obj.systemInfo;
            out.systemInfo.SDKversion   = obj.tobii.get_sdk_version();
            
            % get information about display geometry and trackbox
            warnState = warning('query','MATLAB:structOnObject');
            warning('off',warnState.identifier);    % turn off warning for converting object to struct
            obj.geom.displayArea    = structfun(@double,struct(obj.eyetracker.get_display_area()),'uni',false);
            obj.geom.trackBox       = structfun(@double,struct(obj.eyetracker.get_track_box())   ,'uni',false);
            warning(warnState.state,warnState.identifier);  % reset warning
            % extract some info for conversion between UCS and trackbox
            % coordinates
            obj.geom.UCS2TB.trackBoxDepths      = [obj.geom.trackBox.FrontUpperRight(3) obj.geom.trackBox.BackUpperRight(3)]./10;
            obj.geom.UCS2TB.trackBoxMinX        = obj.geom.trackBox.FrontUpperRight(1)/10;
            obj.geom.UCS2TB.trackBoxXSlope      = diff([obj.geom.trackBox.FrontUpperRight(1) obj.geom.trackBox.BackUpperRight(1)])/diff(obj.geom.UCS2TB.trackBoxDepths*10); % slope: grows wider by x cm if depth increases by y cm
            obj.geom.UCS2TB.trackBoxHalfWidth   = @(x) obj.geom.UCS2TB.trackBoxMinX+obj.geom.UCS2TB.trackBoxXSlope*(x-obj.geom.UCS2TB.trackBoxDepths(1));
            obj.geom.UCS2TB.trackBoxMinY        = obj.geom.trackBox.FrontUpperRight(2)/10;
            obj.geom.UCS2TB.trackBoxYSlope      = diff([obj.geom.trackBox.FrontUpperRight(2) obj.geom.trackBox.BackUpperRight(2)])/diff(obj.geom.UCS2TB.trackBoxDepths*10); % slope: grows taller by x cm if depth increases by y cm
            obj.geom.UCS2TB.trackBoxHalfHeight  = @(x) obj.geom.UCS2TB.trackBoxMinY+obj.geom.UCS2TB.trackBoxYSlope*(x-obj.geom.UCS2TB.trackBoxDepths(1));
            out.geom                = obj.geom;
            
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(obj,wpnt,flag)
            % this function does all setup, draws the interface, etc
            % flag is for if you want to calibrate the two eyes separately,
            % monocularly. When doing first eye, set flag to 1, when second
            % eye set flag to 2. Internally for Titta flag 1 has the
            % meaning "first calibration" and flag 2 "final calibration".
            % This is checked against with bitand, so when user didn't
            % specify we assume a single calibration will be done (which is
            % thus both first and final) and thus set flag to 3.
            if nargin<3 || isempty(flag)
                flag = 3;
            end
            
            % get info about screen
            obj.scrInfo.resolution  = Screen('Rect',wpnt); obj.scrInfo.resolution(1:2) = [];
            obj.scrInfo.center      = obj.scrInfo.resolution/2;
            obj.qFloatColorRange    = Screen('ColorRange',wpnt)==1;
            % get current PTB state so we can restore when returning
            % 1. alpha blending
            [osf,odf,ocm]           = Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            % 2. screen clear color so we can reset that too. There is only
            % one way to do that annoyingly:
            % 2.1. clear back buffer by flipping
            Screen('Flip',wpnt);
            % 2.2. read a pixel, this gets us the background color
            bgClr = double(reshape(Screen('GetImage',wpnt,[1 1 2 2],'backBuffer',obj.qFloatColorRange,4),1,4));
            % 3. text
            text.style  = Screen('TextStyle', wpnt);
            text.size   = Screen('TextSize' , wpnt);
            text.font   = Screen('TextFont' , wpnt);
            text.color  = Screen('TextColor', wpnt);
            
            % see what text renderer to use
            obj.usingFTGLTextRenderer = ~~exist('libptbdrawtext_ftgl64.dll','file') && Screen('Preference','TextRenderer')==1;    % check if we're on a Windows platform with the high quality text renderer present (was never supported for 32bit PTB, so check only for 64bit)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.UI.button.textVOff,'lineCentOff'),'Titta: PTB''s TextRenderer changed between calls to getDefaults and the Titta constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call Titta.getDefaults(), as it has different settings than the recommended TextRenderer number 1')
            end
            
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            obj.shiftKey = KbName('shift');
            [~,~,obj.mouseState] = GetMouse();
            
            
            %%% 1. some preliminary setup, to make sure we are in known state
            if bitand(flag,1)
                obj.buffer.leaveCalibrationMode(true);  % make sure we're not already in calibration mode (start afresh)
            end
            obj.StopRecordAll();
            if bitand(flag,1)
                qDoMonocular = ismember(obj.settings.calibrateEye,{'left','right'});
                if qDoMonocular
                    assert(obj.hasCap(EyeTrackerCapabilities.CanDoMonocularCalibration),'You requested calibrating only the %s eye, but this %s does not support monocular calibrations. Set settings.calibrateEye to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
                end
                obj.buffer.enterCalibrationMode(qDoMonocular);
            end
            % log eye that we are calibrating
            obj.sendMessage(sprintf('Setting up %s eye',obj.settings.calibrateEye));
            
            %%% 2. enter the setup/calibration screens
            % The below is a big loop that will run possibly multiple
            % calibration until exiting because skipped or a calibration is
            % selected by user.
            % there are three start modes:
            % 0. skip head positioning, go straight to calibration
            % 1. start with simple head positioning interface
            % 2. start with advanced head positioning interface
            startScreen = obj.settings.UI.startScreen;
            qDoCal      = true;
            kCal        = 0;
            activeCal   = nan;
            while true
                qGoToValidationViewer = false;
                kCal = kCal+1;
                out.attempt{kCal}.eye  = obj.settings.calibrateEye;
                if startScreen>0
                    %%% 2a: show head positioning screen
                    out.attempt{kCal}.setupStatus = obj.showHeadPositioning(wpnt,out);
                    switch out.attempt{kCal}.setupStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            break;
                        case -4
                            % go to validation viewer screen
                            qGoToValidationViewer = true;
                        case -5
                            % full stop
                            obj.buffer.leaveCalibrationMode();
                            error('Titta: run ended from calibration routine')
                        otherwise
                            error('Titta: status %d not implemented',out.attempt{kCal}.setupStatus);
                    end
                end
                
                %%% 2b: calibrate and validate
                if ~qGoToValidationViewer
                    [out.attempt{kCal}.calStatus,temp] = obj.DoCalAndVal(wpnt,kCal,qDoCal);
                    oldwarn = warning('off','catstruct:DuplicatesFound');   % field already exists but is empty, will be overwritten with the output from the function here
                    out.attempt{kCal} = catstruct(out.attempt{kCal},temp);
                    warning(oldwarn);
                    % if only validating, copy info of active calibration
                    if ~qDoCal
                        out.attempt{kCal}.cal = out.attempt{activeCal}.cal;
                        out.attempt{kCal}.calIsCopiedFrom = activeCal;
                        % reset
                        qDoCal    = true;
                        activeCal = nan;
                    end
                    % check returned action state
                    switch out.attempt{kCal}.calStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            break;
                        case -1
                            % restart calibration
                            startScreen = 0;
                            continue;
                        case -3
                            % go to setup
                            startScreen = 1;
                            continue;
                        case -5
                            % full stop
                            obj.buffer.leaveCalibrationMode();
                            error('Titta: run ended from calibration routine')
                        otherwise
                            error('Titta: status %d not implemented',out.attempt{kCal}.calStatus);
                    end
                    
                    % store information about last calibration as message
                    if out.attempt{kCal}.calStatus==1
                        % 1 get data to put in message, output per eye
                        % separately.
                        eyes    = fieldnames(out.attempt{kCal}.val.quality);
                        nPoint  = length(out.attempt{kCal}.val.quality);
                        msg     = cell(1,length(eyes));
                        for e=1:length(eyes)
                            dat = cell(7,nPoint+1);
                            for k=1:nPoint
                                val = out.attempt{kCal}.val.quality(k).(eyes{e});
                                dat(:,k) = {sprintf('%d @ (%.0f,%.0f)',k,out.attempt{kCal}.val.pointPos(k,2:3)),val.acc2D,val.acc(1),val.acc(2),val.STD2D,val.RMS2D,val.dataLoss*100};
                            end
                            % also get average
                            val = out.attempt{kCal}.val;
                            dat(:,end) = {'average',val.acc2D(e),val.acc(1,e),val.acc(2,e),val.STD2D(e),val.RMS2D(e),val.dataLoss(e)*100};
                            msg{e} = sprintf('%s eye:\n%s',eyes{e},sprintf('%s\t%.4f°\t%.4f°\t%.4f°\t%.4f°\t%.4f°\t%.1f%%\n',dat{:}));
                        end
                        msg = [msg{:}]; msg(end) = [];
                        obj.sendMessage(sprintf('VALIDATION %d Data Quality:\npoint\tacc2D\taccX\taccY\tSTD2D\tRMS2D\tdata loss\n%s',kCal,msg));
                    end
                end
                
                %%% 2c: show calibration results
                % show validation result and ask to continue
                [out.attempt{kCal}.valReviewStatus,out.attempt{kCal}.calSelection,activeCal] = obj.showCalValResult(wpnt,out.attempt,kCal);
                switch out.attempt{kCal}.valReviewStatus
                    case 1
                        % all good, we're done
                        break;
                    case 2
                        % skip setup
                        break;
                    case -1
                        % restart calibration
                        startScreen = 0;
                        continue;
                    case -2
                        % redo validation only
                        startScreen = 0;
                        qDoCal      = false;
                        continue;
                    case -3
                        % go to setup
                        startScreen = 1;
                        continue;
                    case -5
                        % full stop
                        obj.buffer.leaveCalibrationMode();
                        error('Titta: run ended from Tobii routine')
                    otherwise
                        error('Titta: status %d not implemented',out.attempt{kCal}.valReviewStatus);
                end
            end
            
            % clean up and reset PTB state
            Screen('FillRect',wpnt,bgClr);              % reset background color
            Screen('BlendFunction', wpnt, osf,odf,ocm); % reset blend function
            Screen('TextFont',wpnt,text.font,text.style);
            Screen('TextColor',wpnt,text.color);
            Screen('TextSize',wpnt,text.size);
            Screen('Flip',wpnt);                        % clear screen
            
            if bitand(flag,2)
                obj.buffer.leaveCalibrationMode();
            end
            % log to messages which calibration was selected
            if isfield(out,'attempt') && isfield(out.attempt{kCal},'calSelection')
                obj.sendMessage(sprintf('Selected calibration (%s) %d',obj.settings.calibrateEye,out.attempt{kCal}.calSelection));
            end
            
            % store calibration info in calibration history, for later
            % retrieval if wanted
            if isempty(obj.calibrateHistory)
                obj.calibrateHistory{1} = out;
            else
                obj.calibrateHistory{end+1} = out;
            end
        end
        
        function time = sendMessage(obj,str,time)
            % Tobii system timestamp is from same clock as PTB's clock. So
            % we're good. If an event has a known time (e.g. a screen
            % flip), provide it as an input argument to this function. This
            % known time input should be in seconds (as provided by PTB's
            % functions), and will be converted to microsec to match
            % Tobii's timestamps
            if nargin<3
                time = obj.getSystemTime();
            else
                time = int64(round(time*1000*1000));
            end
            obj.msgs.append({time,str});
            if obj.settings.debugMode
                fprintf('%d: %s\n',time,str);
            end
        end
        
        function msgs = getMessages(obj)
            msgs = obj.msgs.data;
        end
        
        function dat = collectSessionData(obj)
            obj.StopRecordAll();
            dat.cal         = obj.calibrateHistory;
            dat.msgs        = obj.getMessages();
            dat.systemInfo  = obj.systemInfo;
            dat.geom        = obj.geom;
            dat.settings    = obj.settings;
            if isa(dat.settings.cal.drawFunction,'function_handle')
                dat.settings.cal.drawFunction = func2str(dat.settings.cal.drawFunction);
            end
            dat.TobiiLog    = obj.buffer.getLog(false);
            dat.data        = obj.ConsumeAllData();
        end
        
        function saveData(obj, filename, doAppendVersion)
            % convenience function that gets data from all streams and
            % saves to mat file along with messages, calibration
            % information and system info
            
            % 1. get filename and path
            [path,file,ext] = fileparts(filename);
            assert(~isempty(path),'Titta: saveData: filename should contain a path')
            % eat .mat off filename, preserve any other extension user may
            % have provided
            if ~isempty(ext) && ~strcmpi(ext,'.mat')
                file = [file ext];
            end
            % add versioning info to file name, if wanted and if already
            % exists
            if nargin>=3 && doAppendVersion
                % see what files we have in data folder with the same name
                f = dir(path);
                f = f(~[f.isdir]);
                f = regexp({f.name},['^' regexptranslate('escape',file) '(_\d+)?\.mat$'],'tokens');
                % see if any. if so, see what number to append
                f = [f{:}];
                if ~isempty(f)
                    % files with this subject name exist
                    f=cellfun(@(x) sscanf(x,'_%d'),[f{:}],'uni',false);
                    f=sort([f{:}]);
                    if isempty(f)
                        file = [file '_1'];
                    else
                        file = [file '_' num2str(max(f)+1)];
                    end
                end
            end
            % now make sure file ends with .mat
            file = [file '.mat'];
            % construct full filename
            filename = fullfile(path,file);
            
            % 2. collect all data to save
            dat = obj.collectSessionData();
            
            % save
            try
                save(filename,'-struct','dat');
            catch ME
                error('Titta: Error saving data:\n%s',ME.getReport('extended'))
            end
        end
        
        function out = deInit(obj)
            if ~isempty(obj.buffer)
                % return log
                out = obj.buffer.getLog(true);
            end
            % deleting the buffer object stops all streams and clears its
            % buffers
            obj.buffer = [];
            
            % clear msgs
            obj.msgs = simpleVec(cell(1,2),1024);   % (re)initialize with space for 1024 messages
            
            % mark as deinited
            obj.isInitialized = false;
        end
    end
    
    
    
    
    % helpers
    methods (Static)
        function settings = getDefaults(tracker)
            assert(nargin>=1,'Titta: you must provide a tracker name when calling getDefaults')
            settings.tracker    = tracker;
            
            % default tracking settings per eye-tracker
            settings.trackingMode           = 'Default';    % if tracker doesn't support trackingMode, SDK will use "Default" it seems. so use that by Default here too
            switch tracker
                case 'Tobii Pro Spectrum'
                    settings.freq                   = 600;
                    settings.trackingMode           = 'human';
                case 'Tobii TX300'
                    settings.freq                   = 300;
                case 'IS4_Large_Peripheral'
                    settings.freq                   = 90;
                case 'X2-60_Compact'
                    settings.freq                   = 60;
                case 'Tobii Pro Nano'
                    settings.freq                   = 60;
            end
            
            if ~exist('libptbdrawtext_ftgl64.dll','file') || Screen('Preference','TextRenderer')==0 % if old text renderer, we have different defaults and an extra settings
                % seems text gets rendered a little larger with this one,
                % make sure we have good default sizes anyway
                textFac = 0.75;
            else
                textFac = 1;
            end
            
            % some default colors to be used below
            eyeColors           = {[255 127   0],[ 0  95 191]};
            toggleButColors     = {[ 37  97 163],[11 122 244]};     % for buttons that toggle (e.g. show eye movements, show online gaze)
            continueButtonColor = [0 120 0];                        % continue calibration, start recording
            backButtonColor     = [150 0 0];                        % redo cal, val, go back to set up
            optionButtonColor   = [150 150 0];                      % "sideways" actions: view previous calibrations, open menu and select different calibration
            
            % TODO: change button colors to something brighter with more
            % contrast with the background
            % TODO: common file format
            % TODO: teaching perspective of showing all the data quality
            % measures, write about that in the paper.
            
            % the rest here are good defaults for all
            settings.calibrateEye               = 'both';                       % 'both', also possible if supported by eye tracker: 'left' and 'right'
            settings.serialNumber               = '';
            settings.licenseFile                = '';
            settings.nTryConnect                = 1;                            % How many times to try to connect before giving up
            settings.connectRetryWait           = 4;                            % seconds
            settings.UI.startScreen             = 1;                            % 0. skip head positioning, go straight to calibration; 1. start with head positioning interface
            settings.UI.setup.showEyes          = true;
            settings.UI.setup.showPupils        = true;
            settings.UI.setup.viewingDist       = 65;
            settings.UI.setup.bgColor           = 127;
            settings.UI.setup.fixBackSize       = 20;
            settings.UI.setup.fixFrontSize      = 5;
            settings.UI.setup.fixBackColor      = 0;
            settings.UI.setup.fixFrontColor     = 255;
            settings.UI.setup.instruct.string   = 'Position yourself such that the two circles overlap.\nDistance: %.0f cm';
            settings.UI.setup.instruct.font     = 'Consolas';
            settings.UI.setup.instruct.size     = 24*textFac;
            settings.UI.setup.instruct.color    = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.setup.instruct.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.setup.instruct.vSpacing = 1.5;
            settings.UI.button.margins          = [30 14];
            if ~exist('libptbdrawtext_ftgl64.dll','file') || Screen('Preference','TextRenderer')==0 % if old text renderer, we have different defaults and an extra settings
                settings.UI.button.textVOff     = 3;                            % amount (pixels) to move single line text so that it is visually centered on requested coordinate
            end
            settings.UI.button.setup.text.font  = 'Consolas';
            settings.UI.button.setup.text.size  = 24*textFac;
            settings.UI.button.setup.text.style = 0;
            settings.UI.button.setup.eyeIm.accelerator  = 'e';
            settings.UI.button.setup.eyeIm.qShow        = true;
            settings.UI.button.setup.eyeIm.string       = {'eye images (<i>e<i>)','no eye images (<i>e<i>)'};
            settings.UI.button.setup.eyeIm.buttonColor  = toggleButColors;
            settings.UI.button.setup.eyeIm.textColor    = 0;
            settings.UI.button.setup.cal.accelerator    = 'space';
            settings.UI.button.setup.cal.qShow          = true;
            settings.UI.button.setup.cal.string         = 'calibrate (<i>spacebar<i>)';
            settings.UI.button.setup.cal.buttonColor    = continueButtonColor;
            settings.UI.button.setup.cal.textColor      = 0;
            settings.UI.button.setup.prevcal.accelerator= 'p';
            settings.UI.button.setup.prevcal.qShow      = true;
            settings.UI.button.setup.prevcal.string     = 'previous calibrations (<i>p<i>)';
            settings.UI.button.setup.prevcal.buttonColor= optionButtonColor;
            settings.UI.button.setup.prevcal.textColor  = 0;
            settings.UI.button.val.text.font    = 'Consolas';
            settings.UI.button.val.text.size    = 24*textFac;
            settings.UI.button.val.text.style   = 0;
            settings.UI.button.val.recal.accelerator    = 'escape';
            settings.UI.button.val.recal.qShow          = true;
            settings.UI.button.val.recal.string         = 'recalibrate (<i>esc<i>)';
            settings.UI.button.val.recal.buttonColor    = backButtonColor;
            settings.UI.button.val.recal.textColor      = 0;
            settings.UI.button.val.reval.accelerator    = 'v';
            settings.UI.button.val.reval.qShow          = true;
            settings.UI.button.val.reval.string         = 'revalidate (<i>v<i>)';
            settings.UI.button.val.reval.buttonColor    = backButtonColor;
            settings.UI.button.val.reval.textColor      = 0;
            settings.UI.button.val.continue.accelerator = 'space';
            settings.UI.button.val.continue.qShow       = true;
            settings.UI.button.val.continue.string      = 'continue (<i>spacebar<i>)';
            settings.UI.button.val.continue.buttonColor = continueButtonColor;
            settings.UI.button.val.continue.textColor   = 0;
            settings.UI.button.val.selcal.accelerator   = 'c';
            settings.UI.button.val.selcal.qShow         = true;
            settings.UI.button.val.selcal.string        = 'select other cal (<i>c<i>)';
            settings.UI.button.val.selcal.buttonColor   = optionButtonColor;
            settings.UI.button.val.selcal.textColor     = 0;
            settings.UI.button.val.setup.accelerator    = 's';
            settings.UI.button.val.setup.qShow          = true;
            settings.UI.button.val.setup.string         = 'setup (<i>s<i>)';
            settings.UI.button.val.setup.buttonColor    = backButtonColor;
            settings.UI.button.val.setup.textColor      = 0;
            settings.UI.button.val.toggGaze.accelerator = 'g';
            settings.UI.button.val.toggGaze.qShow       = true;
            settings.UI.button.val.toggGaze.string      = 'show gaze (<i>g<i>)';
            settings.UI.button.val.toggGaze.buttonColor = toggleButColors;
            settings.UI.button.val.toggGaze.textColor   = 0;
            settings.UI.button.val.toggCal.accelerator  = 't';
            settings.UI.button.val.toggCal.qShow        = false;
            settings.UI.button.val.toggCal.string       = {'show cal (<i>t<i>)','show val (<i>t<i>)'};
            settings.UI.button.val.toggCal.buttonColor  = toggleButColors{1};
            settings.UI.button.val.toggCal.textColor    = 0;
            settings.UI.cal.errMsg.string       = 'Calibration failed\nPress any key to continue';
            settings.UI.cal.errMsg.font         = 'Consolas';
            settings.UI.cal.errMsg.size         = 36*textFac;
            settings.UI.cal.errMsg.color        = [150 0 0];                    % only for messages on the screen, doesn't affect buttons
            settings.UI.cal.errMsg.style        = 1;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.cal.errMsg.wrapAt       = 62;
            settings.UI.val.eyeColors           = eyeColors;                    % colors for validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.bgColor             = 127;                          % background color for validation output screen
            settings.UI.val.fixBackSize         = 20;
            settings.UI.val.fixFrontSize        = 5;
            settings.UI.val.fixBackColor        = 0;
            settings.UI.val.fixFrontColor       = 255;
            settings.UI.val.onlineGaze.eyeColors    = eyeColors;                % colors for online gaze display on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.onlineGaze.fixBackSize  = 20;
            settings.UI.val.onlineGaze.fixFrontSize = 5;
            settings.UI.val.onlineGaze.fixBackColor = 0;
            settings.UI.val.onlineGaze.fixFrontColor= 255;
            settings.UI.val.avg.text.font       = 'Consolas';
            settings.UI.val.avg.text.size       = 24*textFac;
            settings.UI.val.avg.text.color      = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.val.avg.text.eyeColors  = eyeColors;                    % colors for "left" and "right" in data quality report on top of validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.avg.text.style      = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.avg.text.vSpacing   = 1;
            settings.UI.val.hover.bgColor       = 110;
            settings.UI.val.hover.text.font     = 'Consolas';
            settings.UI.val.hover.text.size     = 20*textFac;
            settings.UI.val.hover.text.color    = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.val.hover.text.eyeColors= eyeColors;                    % colors for "left" and "right" in per-point data quality report on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.hover.text.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.menu.bgColor        = 110;
            settings.UI.val.menu.itemColor      = 140;
            settings.UI.val.menu.itemColorActive= 180;
            settings.UI.val.menu.text.font      = 'Consolas';
            settings.UI.val.menu.text.size      = 24*textFac;
            settings.UI.val.menu.text.color     = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.val.menu.text.eyeColors = eyeColors;                    % colors for "left" and "right" in calibration selection menu on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.menu.text.style     = 0;
            settings.cal.pointPos               = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
            settings.cal.autoPace               = 1;                            % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
            settings.cal.paceDuration           = 1.5;                          % minimum duration (s) that each point is shown
            settings.cal.qRandPoints            = true;
            settings.cal.bgColor                = 127;
            settings.cal.fixBackSize            = 20;
            settings.cal.fixFrontSize           = 5;
            settings.cal.fixBackColor           = 0;
            settings.cal.fixFrontColor          = 255;
            settings.cal.drawFunction           = [];
            settings.cal.doRecordEyeImages      = false;
            settings.cal.doRecordExtSignal      = false;
            settings.val.pointPos               = [[0.25 0.25]; [0.25 0.75]; [0.75 0.75]; [0.75 0.25]];
            settings.val.paceDuration           = 1.5;
            settings.val.collectDuration        = 0.5;
            settings.val.qRandPoints            = true;
            settings.debugMode                  = false;                        % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
        end
        
        function time = getSystemTime()
            time = int64(round(GetSecs()*1000*1000));
        end
    end
    
    methods (Access = private, Hidden)
        function allowed = getAllowedOptions(obj)
            % NB: while some settings are nested a few levels deeper than
            % this, the two level info below has sufficient granularity
            allowed = {...
                'calibrateEye',''
                'UI','startScreen'
                'UI','setup'
                'UI','cal'
                'UI','val'
                'UI','button'
                'cal','pointPos'
                'cal','autoPace'
                'cal','paceDuration'
                'cal','qRandPoints'
                'cal','bgColor'
                'cal','fixBackSize'
                'cal','fixFrontSize'
                'cal','fixBackColor'
                'cal','fixFrontColor'
                'cal','drawFunction'
                'cal','doRecordEyeImages'
                'cal','doRecordExtSignal'
                'val','pointPos'
                'val','paceDuration'
                'val','collectDuration'
                'val','qRandPoints'
                };
            for p=size(allowed,1):-1:1
                if ~isfield(obj.settings,allowed{p,1}) || (~isempty(allowed{p,2}) && ~isfield(obj.settings.(allowed{p,1}),allowed{p,2}))
                    allowed(p,:) = [];
                end
            end
        end
        
        function out = hasCap(obj,cap)
            out = ismember(cap,obj.eyetracker.DeviceCapabilities);
        end
        
        function status = showHeadPositioning(obj,wpnt,out)            
            % status output:
            %  1: continue (setup seems good) (space)
            %  2: skip calibration and continue with task (shift+s)
            % -4: go to validation screen (p) -- only if there are already
            %     completed calibrations
            % -5: Exit completely (control+escape)
            % (NB: no -1 for this function)
            
            % logic: if user is at reference viewing distance and at center
            % of head box vertically and horizontally, two circles will
            % overlap indicating correct positioning
            
            startT                  = obj.sendMessage(sprintf('SETUP START %s',obj.settings.calibrateEye));
            obj.buffer.start('gaze');
            qHasEyeIm               = obj.buffer.hasStream('eyeImage');
            % see if we already have valid calibrations
            qHaveValidCalibrations  = ~isempty(getValidCalibrations(out.attempt));
            
            % setup text for buttons
            Screen('TextFont',  wpnt, obj.settings.UI.button.setup.text.font, obj.settings.UI.button.setup.text.style);
            Screen('TextSize',  wpnt, obj.settings.UI.button.setup.text.size);
            
            % setup ovals
            ovalVSz     = .15;
            refSz       = ovalVSz*obj.scrInfo.resolution(2);
            refClr      = [0 0 255];
            headClr     = [255 255 0];
            headFillClr = [headClr .3*255];
            % setup head position visualization
            distGain    = 1.5;
            dDistGain   = 8;
            eyeClr      = [255 255 255];
            eyeSzFac    = .25;
            eyeMarginFac= .25;
            pupilRefSz  = .50;
            pupilRefDiam= 5;    % mm
            pupilSzGain = 1.5;

            % setup buttons
            % which to show
            but(1)  = obj.settings.UI.button.setup.eyeIm;
            but(2)  = obj.settings.UI.button.setup.cal;
            but(3)  = obj.settings.UI.button.setup.prevcal;
            but(1).qShow = but(1).qShow && qHasEyeIm;
            but(3).qShow = but(3).qShow && qHaveValidCalibrations;
            % where and get text
            offScreen   = [-100 -90 -100 -90];
            [but.rect]  = deal(offScreen); % offscreen so mouse handler doesn't fuck up because of it
            for p=1:length(but)
                if but(p).qShow
                    [but(p).rect,but(p).cache] = obj.getButton(wpnt, but(p).string, but(p).textColor, obj.settings.UI.button.margins);
                end
            end
            % arrange them 
            butRectsBase= cat(1,but([but.qShow]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution(2)*.95);
                % place buttons for go to advanced interface, or calibrate
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                butRects          = num2cell(butRects,2);
                [but([but.qShow]).rect] = butRects{:};
                % now position text correctly
                for p=1:length(but)
                    if but(p).qShow
                        but(p).cache = obj.positionButtonText(but(p).cache, but(p).rect);
                    end
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution,4,1);
            
            % setup cursors
            butRects        = cat(1,but.rect).';
            cursors.rect    = num2cell(butRects,1);
            cursors.cursor  = repmat(2,size(cursors.rect)); % Hand
            cursors.other   = 0;                            % Arrow
            if ~obj.settings.debugMode                      % for cleanup
                cursors.reset = -1;                         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor  = cursorUpdater(cursors);
            
            % setup text for positioning message
            Screen('TextFont',  wpnt, obj.settings.UI.setup.instruct.font, obj.settings.UI.setup.instruct.style);
            Screen('TextSize',  wpnt, obj.settings.UI.setup.instruct.size);
            
            % get tracking status and visualize
            eyeDist             = 6.2;
            qEyeDistMeasured    = false;
            Rori                = [1 0; 0 1];
            dZ                  = 0;
            qToggleEyeImage     = false;
            qShowEyeImage       = false;
            texs                = [0 0];
            szs                 = [];
            eyeImageRect        = repmat({zeros(1,4)},1,2);
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            Screen('FillRect', wpnt, obj.getColorForWindow(obj.settings.UI.setup.bgColor)); % Set the background color
            headPostLastT       = 0;
            while true
                if qHasEyeIm
                    % toggle eye images on or off if requested
                    if qToggleEyeImage
                        if qShowEyeImage
                            % switch off
                            obj.buffer.stop('eyeImage');
                            obj.buffer.clearTimeRange('eyeImage',eyeStartTime);  % default third argument, clearing from startT until now
                        else
                            % switch on
                            eyeStartTime = obj.getSystemTime();
                            obj.buffer.start('eyeImage');
                        end
                        qShowEyeImage   = ~qShowEyeImage;
                        qToggleEyeImage = false;
                    end
                    
                    if qShowEyeImage
                        % get eye image
                        eyeIm       = obj.buffer.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward (default third argument: now)
                        [texs,szs]  = UploadImages(texs,szs,wpnt,eyeIm);
                        
                        % update eye image locations if size of returned eye image changed
                        if (~any(isnan(szs(:,1))) && any(szs(:,1).'~=diff(reshape(eyeImageRect{1},2,2)))) || (~any(isnan(szs(:,2))) && any(szs(:,2).'~=diff(reshape(eyeImageRect{1},2,2))))
                            margin = 20;
                            qShow = [but.qShow];
                            if ~any(qShow)
                                basePos = round(obj.scrInfo.resolution(2)*.95);
                            else
                                basePos = min(butRects(2,[but.qShow]));
                            end
                            eyeImageRect{1} = OffsetRect([0 0 szs(:,1).'],obj.scrInfo.center(1)-szs(1,1)-margin/2,basePos-margin-szs(2,1));
                            eyeImageRect{2} = OffsetRect([0 0 szs(:,2).'],obj.scrInfo.center(1)         +margin/2,basePos-margin-szs(2,2));
                        end
                    end
                end
                
                % get latest data from eye-tracker
                eyeData = obj.buffer.peekN('gaze',1);
                [lEye,rEye] = deal(nan(3,1));
                if ~isempty(eyeData.systemTimeStamp)
                    lEye = eyeData. left.gazeOrigin.inUserCoords;
                    lPup = eyeData. left.pupil.diameter;
                end
                qHaveLeft   = ~isempty(eyeData.systemTimeStamp) && eyeData. left.gazeOrigin.valid;
                if ~isempty(eyeData.systemTimeStamp)
                    rEye = eyeData.right.gazeOrigin.inUserCoords;
                    rPup = eyeData.right.pupil.diameter;
                end
                qHaveRight  = ~isempty(eyeData.systemTimeStamp) && eyeData.right.gazeOrigin.valid;
                qHave       = [qHaveLeft qHaveRight];
                
                % get average eye distance. use distance from one eye if only one eye
                % available
                dists   = [lEye(3) rEye(3)]./10;
                Xs      = [lEye(1) rEye(1)]./10;
                Ys      = [lEye(2) rEye(2)]./10;
                if all(qHave)
                    % get orientation of eyes in X-Y plane
                    dX          = diff(Xs);
                    dY          = diff(Ys);
                    dZ          = diff(dists);
                    orientation = atan2(dY,dX);
                    Rori = [cos(orientation) sin(orientation); -sin(orientation) cos(orientation)];
                    if ~qEyeDistMeasured
                        % get distance between eyes
                        eyeDist          = hypot(dX,diff(dists));
                        qEyeDistMeasured = true;
                    end
                end
                % if we have only one eye, make fake second eye
                % position so drawn head position doesn't jump so much.
                off   = Rori*[eyeDist; 0];
                if ~qHaveLeft
                    Xs(1)   = Xs(2)   -off(1);
                    Ys(1)   = Ys(2)   +off(2);
                    dists(1)= dists(2)-dZ;
                elseif ~qHaveRight
                    Xs(2)   = Xs(1)   +off(1);
                    Ys(2)   = Ys(1)   -off(2);
                    dists(2)= dists(1)+dZ;
                end
                % determine head position in user coordinate system
                avgX    = mean(Xs(~isnan(Xs))); % on purpose isnan() instead of qHave, as we may have just repaired a missing Xs and Ys above
                avgY    = mean(Ys(~isnan(Xs)));
                avgDist = mean(dists(~isnan(Xs)));
                % convert from UCS to trackBox coordinates
                tbWidth = obj.geom.UCS2TB.trackBoxHalfWidth (avgDist);
                avgX    = avgX/tbWidth /2+.5;
                tbHeight= obj.geom.UCS2TB.trackBoxHalfHeight(avgDist);
                avgY    = avgY/tbHeight/2+.5;
                
                % scale up size of oval. define size/rect at standard distance, have a
                % gain for how much to scale as distance changes
                if ~isnan(avgDist)
                    pos     = [avgX 1-avgY];  %1-Y to flip direction (positive UCS is upward, should be downward for drawing on screen)
                    % determine size of oval, based on distance from reference distance
                    fac     = avgDist/obj.settings.UI.setup.viewingDist;
                    headSz  = refSz - refSz*(fac-1)*distGain;
                    eyeSz   = eyeSzFac*headSz*((avgDist./dists-1)*dDistGain+1);
                    eyeMargin = eyeMarginFac*headSz*2;  %*2 because all sizes are radii
                    % move
                    headPos = pos.*obj.scrInfo.resolution;
                    headPostLastT = eyeData.systemTimeStamp;
                else
                    headPos = [];
                end
                
                % draw eye images, if any
                if qShowEyeImage
                    if texs(1)
                        Screen('DrawTexture', wpnt, texs(1),[],eyeImageRect{1});
                    else
                        Screen('FillRect', wpnt, 0, eyeImageRect{1});
                    end
                    if texs(2)
                        Screen('DrawTexture', wpnt, texs(2),[],eyeImageRect{2});
                    else
                        Screen('FillRect', wpnt, 0, eyeImageRect{2});
                    end
                end
                % for distance info and ovals: hide when eye image is shown
                % and data is missing. But only do so after 200 ms of data
                % missing, so that these elements don't flicker all the
                % time when unstable track
                qHideSetup = qShowEyeImage && isempty(headPos) && double(eyeData.systemTimeStamp-headPostLastT)/1000>200;
                % draw distance info
                if ~qHideSetup
                    DrawFormattedText(wpnt,sprintf(obj.settings.UI.setup.instruct.string,avgDist),'center',fixPos(1,2)-.03*obj.scrInfo.resolution(2),obj.settings.UI.setup.instruct.color,[],[],[],obj.settings.UI.setup.instruct.vSpacing);
                end
                % draw ovals
                % reference circle--don't draw if showing eye images and no
                % tracking data available
                if ~qHideSetup
                    drawCircle(wpnt,obj.getColorForWindow(refClr),obj.scrInfo.center,refSz,5);
                end
                % stylized head
                if ~isempty(headPos)
                    drawCircle(wpnt,obj.getColorForWindow(headClr),headPos,headSz,5,obj.getColorForWindow(headFillClr));
                    if obj.settings.UI.setup.showEyes
                        for p=1:2
                            % left eye
                            off = Rori*[eyeMargin; 0];
                            if p==1
                                pos = headPos-off.';
                                pup = lPup;
                            else
                                pos = headPos+off.';
                                pup = rPup;
                            end
                            if (p==1 && ~obj.calibrateLeftEye) || (p==2 && ~obj.calibrateRightEye)
                                % draw cross indicating not calibrated
                                base = eyeSz(p)*[-1 1 1 -1; -1/4 -1/4 1/4 1/4];
                                R    = [cosd(45) sind(45); -sind(45) cosd(45)];
                                Screen('FillPoly', wpnt, obj.getColorForWindow([255 0 0]), bsxfun(@plus,R  *Rori*base,pos(:)).', 1);
                                Screen('FillPoly', wpnt, obj.getColorForWindow([255 0 0]), bsxfun(@plus,R.'*Rori*base,pos(:)).', 1);
                            elseif (p==1 && qHaveLeft) || (p==2 && qHaveRight)
                                % draw eye with optional pupil
                                drawCircle(wpnt,[],pos,eyeSz(p),0,obj.getColorForWindow(eyeClr));
                                if obj.settings.UI.setup.showPupils
                                    pupSz = (1+(pup/pupilRefDiam-1)*pupilSzGain)*pupilRefSz*eyeSz(1);
                                    drawCircle(wpnt,[],pos,pupSz,0,obj.getColorForWindow([0 0 0]));
                                end
                            else
                                % draw line indicating closed/missing eye
                                base = eyeSz(p)*[-1 1 1 -1; -1/5 -1/5 1/5 1/5];
                                Screen('FillPoly', wpnt, obj.getColorForWindow(eyeClr), bsxfun(@plus,Rori*base,pos(:)).', 1);
                            end
                        end
                    end
                end
                
                % draw buttons
                obj.drawButton(wpnt,but(1),qShowEyeImage+1);
                obj.drawButton(wpnt,but(2));
                obj.drawButton(wpnt,but(3));
                
                % draw fixation points
                obj.drawFixPoints(wpnt,fixPos,obj.settings.UI.setup.fixBackSize,obj.settings.UI.setup.fixFrontSize,obj.settings.UI.setup.fixBackColor,obj.settings.UI.setup.fixFrontColor);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                
                % get user response
                [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],butRects);
                    if qIn(1)
                        qToggleEyeImage = true;
                    elseif qIn(2)
                        status = 1;
                        break;
                    elseif qIn(3)
                        status = -4;
                        break;
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,obj.settings.UI.button.setup.eyeIm.accelerator))
                        qToggleEyeImage = true;
                    elseif any(strcmpi(keys,obj.settings.UI.button.setup.cal.accelerator))
                        status = 1;
                        break;
                    elseif any(strcmpi(keys,obj.settings.UI.button.setup.prevcal.accelerator)) && qHaveValidCalibrations
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'escape')) && shiftIsDown
                        status = -5;
                        break;
                    elseif any(strcmpi(keys,'s')) && shiftIsDown
                        % skip calibration
                        status = 2;
                        break;
                    end
                end
            end
            % clean up
            HideCursor;
            obj.buffer.stop('gaze');
            obj.sendMessage(sprintf('SETUP END %s',obj.settings.calibrateEye));
            obj.buffer.clearTimeRange('gaze',startT);    % clear buffer from start time until now (now=default third argument)
            if qHasEyeIm
                obj.buffer.stop('eyeImage');
                obj.buffer.clearTimeRange('eyeImage',startT);    % clear buffer from start time until now (now=default third argument)
                if any(texs)
                    Screen('Close',texs(texs>0));
                end
            end
        end
        
        function [cache,txtbounds] = getTextCache(obj,wpnt,text,rect,varargin)
            inputs.sx           = 0;
            inputs.xalign       = 'center';
            inputs.sy           = 0;
            inputs.yalign       = 'center';
            inputs.xlayout      = 'left';
            inputs.baseColor    = obj.getColorForWindow(0);
            if nargin>3 && ~isempty(rect)
                [inputs.sx,inputs.sy] = RectCenterd(rect);
            end
            
            if obj.usingFTGLTextRenderer
                for p=1:2:length(varargin)
                    inputs.(varargin{p}) = varargin{p+1};
                end
                args = [fieldnames(inputs) struct2cell(inputs)].';
                [~,~,txtbounds,cache] = DrawFormattedText2(text,'win',wpnt,'cacheOnly',true,args{:});
            else
                inputs.vSpacing = [];
                fs=fieldnames(inputs);
                for p=1:length(fs)
                    qHasOpt = strcmp(varargin,fs{p});
                    if any(qHasOpt)
                        inputs.(fs{p}) = varargin{find(qHasOpt)+1};
                    end
                end
                if ~isempty(rect)
                    inputs.sy = inputs.sy + obj.settings.UI.button.textVOff;
                end
                [~,~,txtbounds,cache] = DrawFormattedText2GDI(wpnt,text,inputs.sx,inputs.xalign,inputs.sy,inputs.yalign,inputs.xlayout,inputs.baseColor,[],inputs.vSpacing,[],[],true);
            end
        end
        
        function [rect,cache] = getButton(obj, wpnt, string, color, buttonMargins)
            if ~iscell(string)
                string = {string};
            end
            assert(ismember(numel(string),[1 2]),'number of strings for button ''%s'' should be 1 or 2',string{1});
            if ~iscell(color)
                color = {color};
            end
            assert(ismember(numel(color),[1 2]),'number of textColors for button ''%s'' should be 1 or 2',string{1});
            if length(color)<length(string)
                color = [color color];
            elseif length(string)<length(color)
                string = [string string];
            end
            
            % get strings
            for p=length(string):-1:1
                [cache(p),rect(p,:)]    = obj.getTextCache(wpnt,sprintf('<color=%s>%s',clr2hex(color{p}),string{p}));
            end
            % get rect around largest
            rect = [0 0 max(rect(:,3)-rect(:,1)) max(rect(:,4)-rect(:,2))] + 2*[0 0 buttonMargins];
        end
        
        function cache = positionButtonText(obj, cache, rect)
            [sx,sy] = RectCenterd(rect);
            if obj.usingFTGLTextRenderer
                for p=1:length(cache)
                    [~,~,~,cache(p)] = DrawFormattedText2(cache(p),'cacheOnly',true,'sx',sx,'sy',sy,'xalign','center','yalign','center');
                end
            else
                % TODO offset the below somehow
                for p=1:length(cache)
                    cache.px
                    cache.py
                end
            end
        end
        
        function drawCachedText(obj,cache,rect)
            if obj.usingFTGLTextRenderer
                args = {};
                if nargin>2
                    args = {'sx','center','sy','center','xalign','center','yalign','center','winRect',rect};
                end
                DrawFormattedText2(cache,args{:});
            else
                if nargin>2
                    [cx,cy] = RectCenterd(rect);
                    cache.px = cache.px+cx;
                    cache.py = cache.py+cy;
                end
                DrawFormattedText2GDI(cache);
            end
        end
        
        function drawFixPoints(obj,wpnt,pos,fixBackSize,fixFrontSize,fixBackColor,fixFrontColor)
            % draws Thaler et al. 2012's ABC fixation point
            sz = [fixBackSize fixFrontSize];
            
            % draw
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj.getColorForWindow( fixBackColor), pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.getColorForWindow(fixFrontColor), rectH);
                Screen('FillRect',wpnt,obj.getColorForWindow(fixFrontColor), rectV);
                Screen('gluDisk', wpnt,obj.getColorForWindow( fixBackColor), pos(p,1), pos(p,2), sz(2)/2);
            end
        end
        
        function drawButton(obj,wpnt,but,idx)
            if ~but.qShow
                return;
            end
            if nargin<4
                idx = 1;
            end
            if iscell(but.buttonColor)
                clr = but.buttonColor{min(idx,end)};
            else
                clr = but.buttonColor;
            end
            Screen('FillRect',wpnt,obj.getColorForWindow(clr),but.rect);
            obj.drawCachedText(but.cache(min(idx,end)));
        end
        
        function [status,out] = DoCalAndVal(obj,wpnt,kCal,qDoCal)
            Screen('FillRect', wpnt, obj.getColorForWindow(obj.settings.cal.bgColor)); % NB: this sets the background color, because fullscreen fillrect sets new clear color in PTB
            
            % get data streams started
            if qDoCal
                calStartT = obj.sendMessage(sprintf('CALIBRATION START %s %d',obj.settings.calibrateEye,kCal));
            else
                valStartT = obj.sendMessage(sprintf( 'VALIDATION START %s %d',obj.settings.calibrateEye,kCal));
            end
            obj.buffer.start('gaze');
            if obj.settings.cal.doRecordEyeImages && obj.buffer.hasStream('eyeImage')
                obj.buffer.start('eyeImage');
            end
            if obj.settings.cal.doRecordExtSignal && obj.buffer.hasStream('externalSignal')
                obj.buffer.start('externalSignal');
            end
            obj.buffer.start('timeSync');
            
            % do calibration
            if qDoCal
                % show display
                [status,out.cal,tick] = obj.DoCalPointDisplay(wpnt,true,-1);
                obj.sendMessage(sprintf('CALIBRATION END %s %d',obj.settings.calibrateEye,kCal));
                out.cal.data = obj.ConsumeAllData(calStartT);
                if status==1
                    if ~isempty(obj.settings.cal.pointPos)
                        % if valid calibration retrieve data, so user can select different ones
                        if strcmpi(out.cal.result.status(1:7),'Success') % 1:7 so e.g. SuccessLeftEye is also supported
                            out.cal.computedCal = obj.eyetracker.retrieve_calibration_data();
                        else
                            % calibration failed, back to setup screen
                            status = -3;
                            Screen('TextFont', wpnt, obj.settings.UI.cal.errMsg.font, obj.settings.UI.cal.errMsg.style);
                            Screen('TextSize', wpnt, obj.settings.UI.cal.errMsg.size);
                            DrawFormattedText(wpnt,obj.settings.UI.cal.errMsg.string,'center','center',obj.getColorForWindow(obj.settings.UI.cal.errMsg.color));
                            Screen('Flip',wpnt);
                            obj.getNewMouseKeyPress();
                            keyCode = false;
                            while ~any(keyCode)
                                [~,~,~,keyCode] = obj.getNewMouseKeyPress();
                            end
                        end
                    else
                        % can't actually calibrate if user requested no
                        % calibration points, so just make these fields
                        % empty in that case.
                        out.cal.result = [];
                        out.cal.computedCal = [];
                    end
                end
                calLastFlip = {tick,out.cal.flips(end)};
                
                if status~=1
                    obj.StopRecordAll();
                    obj.ClearAllBuffers(calStartT);    % clean up data
                    if status~=-1
                        % -1 means restart calibration from start. if we do not
                        % clean up here, we e.g. get a nice animation of the
                        % point back to the center of the screen, or however
                        % the user wants to indicate change of point. Clean up
                        % in all other cases, or we would maintain drawstate
                        % accross setup screens and such.
                        % So, send cleanup message to user function (if any)
                        if isa(obj.settings.cal.drawFunction,'function_handle')
                            obj.settings.cal.drawFunction(nan,nan,nan,nan);
                        end
                        Screen('Flip',wpnt);
                    end
                    return;
                end
            else
                calLastFlip = {-1};
            end
            
            % do validation
            if qDoCal
                valStartT = obj.sendMessage(sprintf('VALIDATION START %s %d',obj.settings.calibrateEye,kCal));
                obj.ClearAllBuffers(calStartT);    % clean up data from calibration
            end
            % show display
            [status,out.val] = obj.DoCalPointDisplay(wpnt,false,calLastFlip{:});
            obj.sendMessage(sprintf('VALIDATION END %s %d',obj.settings.calibrateEye,kCal));
            out.val.allData = obj.ConsumeAllData(valStartT);
            obj.StopRecordAll();
            obj.ClearAllBuffers(valStartT);    % clean up data
            % compute accuracy etc
            if status==1
                out.val = obj.ProcessValData(out.val);
            end
            
            if status~=-1   % see comment above about why not when -1
                % cleanup message to user function (if any)
                if isa(obj.settings.cal.drawFunction,'function_handle')
                    obj.settings.cal.drawFunction(nan,nan,nan,nan);
                end
            end
            
            % clear flip
            Screen('Flip',wpnt);
        end
        
        function data = ConsumeAllData(obj,varargin)
            data.gaze           = obj.buffer.consumeTimeRange('gaze',varargin{:});
            data.eyeImages      = obj.buffer.consumeTimeRange('eyeImage',varargin{:});
            data.externalSignals= obj.buffer.consumeTimeRange('externalSignal',varargin{:});
            data.timeSync       = obj.buffer.consumeTimeRange('timeSync',varargin{:});
        end
        
        function ClearAllBuffers(obj,varargin)
            % clear all buffer, optionally only within specified time range
            obj.buffer.clearTimeRange('gaze',varargin{:});
            obj.buffer.clearTimeRange('eyeImage',varargin{:});
            obj.buffer.clearTimeRange('externalSignal',varargin{:});
            obj.buffer.clearTimeRange('timeSync',varargin{:});
        end
        
        function StopRecordAll(obj)
            obj.buffer.stop('gaze');
            obj.buffer.stop('eyeImage');
            obj.buffer.stop('externalSignal');
            obj.buffer.stop('timeSync');
        end
        
        function [status,out,tick] = DoCalPointDisplay(obj,wpnt,qCal,tick,lastFlip)
            % status output:
            %  1: finished succesfully (you should query Tobii SDK whether
            %     they agree that calibration was succesful though)
            %  2: skip calibration and continue with task (shift+s)
            % -1: restart calibration (r)
            % -3: abort calibration and go back to setup (escape key)
            % -5: Exit completely (control+escape)
            qFirst = nargin<5;
            
            % setup
            if qCal
                points          = obj.settings.cal.pointPos;
                paceInterval    = ceil(obj.settings.cal.paceDuration   *Screen('NominalFrameRate',wpnt));
                out.status      = {};
                extraInp        = {obj.settings.calibrateEye};
                if strcmp(obj.settings.calibrateEye,'both')
                    extraInp    = {};
                end
            else
                points          = obj.settings.val.pointPos;
                paceInterval    = ceil(obj.settings.val.paceDuration   *Screen('NominalFrameRate',wpnt));
                collectInterval = ceil(obj.settings.val.collectDuration*Screen('NominalFrameRate',wpnt));
                nDataPoint      = ceil(obj.settings.val.collectDuration*obj.eyetracker.get_gaze_output_frequency());
                tick0v          = nan;
                out.gazeData    = [];
            end
            nPoint = size(points,1);
            if nPoint>0
                points = [points bsxfun(@times,points,obj.scrInfo.resolution) [1:nPoint].' ones(nPoint,1)]; %#ok<NBRAK>
                if (qCal && obj.settings.cal.qRandPoints) || (~qCal && obj.settings.val.qRandPoints)
                    points = points(randperm(nPoint),:);
                end
            end
            if isempty(obj.settings.cal.drawFunction)
                drawFunction = @obj.drawFixationPointDefault;
            else
                drawFunction = obj.settings.cal.drawFunction;
            end
            
            % prepare output
            status = 1; % calibration went ok, unless otherwise stated
            
            % clear screen, anchor timing, get ready for displaying calibration points
            if qFirst
                out.flips = Screen('Flip',wpnt);
            else
                out.flips = lastFlip;
            end
            out.pointPos = [];
            
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            
            currentPoint    = 0;
            needManualAccept= @(cp) obj.settings.cal.autoPace==0 || (obj.settings.cal.autoPace==1 && tick==-1 && cp==1);
            advancePoint    = true;
            pointOff        = 0;
            nCollecting     = 0;
            while true
                tick        = tick+1;
                nextFlipT   = out.flips(end)+1/1000;
                if advancePoint
                    currentPoint = currentPoint+1;
                    % check any points left to do
                    if currentPoint>size(points,1)
                        pointOff = 1;
                        break;
                    end
                    out.pointPos(end+1,1:3) = points(currentPoint,[5 3 4]);
                    % check if manual acceptance needed for this point
                    waitForKeyAccept = needManualAccept(currentPoint);
                    haveAccepted     = ~waitForKeyAccept;   % if not needed, we already have it
                    
                    % get ready for next point
                    tick0p          = tick;
                    advancePoint    = false;
                    qNewPoint       = true;
                end
                
                % call drawer function
                qAllowAcceptKey     = drawFunction(wpnt,currentPoint,points(currentPoint,3:4),tick);
                
                out.flips(end+1)    = Screen('Flip',wpnt,nextFlipT);
                if qNewPoint
                    obj.sendMessage(sprintf('POINT ON %d (%.0f %.0f)',currentPoint,points(currentPoint,3:4)),out.flips(end));
                    nCollecting     = 0;
                    qNewPoint       = false;
                end
                
                % get user response
                [~,~,~,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                if any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'space')) && waitForKeyAccept && qAllowAcceptKey
                        % if in semi-automatic and first point, or if
                        % manual and any point, space bars triggers
                        % accepting calibration point
                        haveAccepted    = true;
                    elseif any(strcmpi(keys,'r'))
                        status = -1;
                        break;
                    elseif any(strcmpi(keys,'escape'))
                        % NB: no need to cancel calibration here,
                        % leaving calibration mode is done by caller
                        if shiftIsDown
                            status = -5;
                        else
                            status = -3;
                        end
                        break;
                    elseif any(strcmpi(keys,'s')) && shiftIsDown
                        % skip calibration
                        status = 2;
                        break;
                    end
                end
                
                % accept point
                if haveAccepted && tick>tick0p+paceInterval
                    if qCal
                        if ~nCollecting
                            % start collection
                            obj.buffer.calibrationCollectData(points(currentPoint,1:2),extraInp{:});
                            nCollecting = 1;
                        else
                            % check status
                            calStatus = obj.buffer.calibrationCollectionStatus();
                            switch calStatus
                                case 'collecting'
                                    % carry on
                                case 'success'
                                    % next point
                                    advancePoint = true;
                                case 'failure'
                                    if nCollecting==1
                                        % if failed first time, immediately try again
                                        obj.buffer.calibrationCollectData(points(currentPoint,1:2),extraInp{:});
                                        nCollecting = 2;
                                    else
                                        % if still fails, retry one more time at end of
                                        % point sequence (if this is not already a retried
                                        % point)
                                        if points(currentPoint,6)
                                            points = [points; points(currentPoint,:)]; %#ok<AGROW>
                                            points(end,6) = 0;  % indicate this is a point that is being retried so we don't try forever
                                        end
                                        % next point
                                        advancePoint = true;
                                    end
                                otherwise
                                    error('calibrationCollectionStatus returned status ''%s'', don''t know what to do with that',calStatus);
                            end
                            if advancePoint
                                out.status{currentPoint} = calStatus;
                            end
                        end
                    else
                        if isnan(tick0v)
                            tick0v = tick;
                        end
                        if tick>tick0v+collectInterval
                            dat = obj.buffer.peekN('gaze',nDataPoint);
                            if isempty(out.gazeData)
                                out.gazeData = dat;
                            else
                                out.gazeData(end+1,1) = dat;
                            end
                            tick0v = nan;
                            % next point
                            advancePoint = true;
                        end
                    end
                end
            end
            
            % calibration/validation finished
            currentPoint = currentPoint-pointOff;
            obj.sendMessage(sprintf('POINT OFF %d',currentPoint),out.flips(end));
            
            % get calibration result while keeping animation on the screen
            % alive for a smooth experience
            if qCal && size(points,1)>0
                % compute calibration
                obj.buffer.calibrationComputeAndApply();
                result  = [];
                flipT   = out.flips(end);
                while isempty(result)
                    tick    = tick+1;
                    drawFunction(wpnt,currentPoint,points(currentPoint,3:4),tick);
                    flipT   = Screen('Flip',wpnt,flipT+1/1000);
                    
                    result  = obj.buffer.calibrationRetrieveComputeAndApplyResult();
                end
                out.result = fixupTobiiCalResult(result,obj.calibrateLeftEye,obj.calibrateRightEye);
            end
        end
        
        function qAllowAcceptKey = drawFixationPointDefault(obj,wpnt,~,pos,~)
            obj.drawFixPoints(wpnt,pos,obj.settings.cal.fixBackSize,obj.settings.cal.fixFrontSize,obj.settings.cal.fixBackColor,obj.settings.cal.fixFrontColor);
            qAllowAcceptKey = true;
        end
        
        function val = ProcessValData(obj,val)
            % compute validation accuracy per point, noise levels, %
            % missing
            for p=length(val.gazeData):-1:1
                if obj.calibrateLeftEye
                    val.quality(p).left  = obj.getDataQuality(val.gazeData(p).left ,val.pointPos(p,2:3));
                end
                if obj.calibrateRightEye
                    val.quality(p).right = obj.getDataQuality(val.gazeData(p).right,val.pointPos(p,2:3));
                end
            end
            if obj.calibrateLeftEye
                lefts  = [val.quality.left];
            end
            if obj.calibrateRightEye
                rights = [val.quality.right];
            end
            [l,r] = deal([]);
            for f={'acc','acc2D','RMS2D','STD2D','dataLoss'}
                % NB: abs when averaging over eyes, we need average size of
                % error for accuracy and for other fields its all positive
                % anyway
                if obj.calibrateLeftEye
                    l = mean(abs([lefts.(f{1})]),2,'omitnan');
                end
                if obj.calibrateRightEye
                    r = mean(abs([rights.(f{1})]),2,'omitnan');
                end
                val.(f{1}) = [l r];
            end
        end
        
        function out = getDataQuality(obj,gazeData,valPointPos)
            % 1. accuracy
            pointOnScreenDA  = (valPointPos./obj.scrInfo.resolution).';
            pointOnScreenUCS = obj.ADCSToUCS(pointOnScreenDA);
            offOnScreenADCS  = bsxfun(@minus,gazeData.gazePoint.onDisplayArea,pointOnScreenDA);
            offOnScreenCm    = bsxfun(@times,offOnScreenADCS,[obj.geom.displayArea.width,obj.geom.displayArea.height].');
            offOnScreenDir   = atan2(offOnScreenCm(2,:),offOnScreenCm(1,:));
            
            vecToPoint  = bsxfun(@minus,pointOnScreenUCS,gazeData.gazeOrigin.inUserCoords);
            gazeVec     = gazeData.gazePoint.inUserCoords-gazeData.gazeOrigin.inUserCoords;
            angs2D      = AngleBetweenVectors(vecToPoint,gazeVec);
            out.offs    = bsxfun(@times,angs2D,[cos(offOnScreenDir); sin(offOnScreenDir)]);
            out.acc     = mean(out.offs,2,'omitnan');
            out.acc2D   = mean( angs2D ,2,'omitnan');
            
            % 2. RMS
            out.RMS     = sqrt(mean(diff(out.offs,[],2).^2,2,'omitnan'));
            out.RMS2D   = hypot(out.RMS(1),out.RMS(2));
            
            % 3. STD
            out.STD     = std(out.offs,[],2,'omitnan');
            out.STD2D   = hypot(out.STD(1),out.STD(2));
            
            % 4. data loss
            out.dataLoss  = 1-sum(gazeData.gazePoint.valid)/length(gazeData.gazePoint.valid);
        end
        
        function out = ADCSToUCS(obj,data)
            % data is a 2xN matrix of normalized coordinates
            xVec = obj.geom.displayArea.top_right-obj.geom.displayArea.top_left;
            yVec = obj.geom.displayArea.bottom_right-obj.geom.displayArea.top_right;
            out  = bsxfun(@plus,obj.geom.displayArea.top_left,bsxfun(@times,data(1,:),xVec)+bsxfun(@times,data(2,:),yVec));
        end
        
        function [status,selection,activeCal] = showCalValResult(obj,wpnt,cal,selection)
            % status output:
            %  1: calibration/validation accepted, continue (a)
            %  2: just continue with task (shift+s)
            % -1: restart calibration (escape key)
            % -2: redo validation only (v)
            % -3: go back to setup (s)
            % -5: exit completely (control+escape)
            %
            % additional buttons
            % c: chose other calibration (if have more than one valid)
            % g: show gaze (and fixation points)
            % t: toggle between seeing validation results and calibration
            %    result
            Screen('FillRect', wpnt, obj.getColorForWindow(obj.settings.UI.val.bgColor)); % NB: this sets the background color, because fullscreen fillrect sets new clear color in PTB
            
            % find how many valid calibrations we have:
            iValid = getValidCalibrations(cal);
            if ~isempty(iValid) && ~ismember(selection,iValid)  % exception, when we have no valid calibrations at all (happens when using zero-point calibration)
                % this happens if setup cancelled to go directly to this validation
                % viewer
                selection = iValid(end);
            end
            qHasCal                = ~isempty(cal{selection}.cal.result);
            qHaveMultipleValidCals = ~isempty(iValid) && ~isscalar(iValid);
            
            % setup text for buttons
            Screen('TextFont',  wpnt, obj.settings.UI.button.val.text.font, obj.settings.UI.button.val.text.style);
            Screen('TextSize',  wpnt, obj.settings.UI.button.val.text.size);
            
            % set up buttons
            % which to show
            but(1)  = obj.settings.UI.button.val.recal;
            but(2)  = obj.settings.UI.button.val.reval;
            but(3)  = obj.settings.UI.button.val.continue;
            but(4)  = obj.settings.UI.button.val.selcal;
            but(4).qShow = but(4).qShow && qHaveMultipleValidCals;
            but(5)  = obj.settings.UI.button.val.setup;
            but(6)  = obj.settings.UI.button.val.toggGaze;
            but(7)  = obj.settings.UI.button.val.toggCal;
            but(7).qShow = but(7).qShow && qHasCal;
            offScreen   = [-100 -90 -100 -90];
            [but.rect]  = deal(offScreen); % offscreen so mouse handler doesn't fuck up because of it
            % 1. below screen
            % size and get text
            for p=1:4
                if but(p).qShow
                    [but(p).rect,but(p).cache] = obj.getButton(wpnt, but(p).string, but(p).textColor, obj.settings.UI.button.margins);
                end
            end
            % position them
            butRectsBase= cat(1,but([but(1:4).qShow]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution(2)*.97);
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                butRects          = num2cell(butRects,2);
                [but([1:length(but)]<=4&[but.qShow]).rect] = butRects{:};
                % now position text correctly
                for p=1:4
                    if but(p).qShow
                        but(p).cache = obj.positionButtonText(but(p).cache, but(p).rect);
                    end
                end
            end
            
            % 2. atop screen
            % size and get text
            for p=5:6
                if but(p).qShow
                    [but(p).rect,but(p).cache] = obj.getButton(wpnt, but(p).string, but(p).textColor, obj.settings.UI.button.margins);
                end
            end
            % position them
            yPosTop             = .02*obj.scrInfo.resolution(2);
            buttonOff           = 900;
            if but(5).qShow
                but(5).rect     = OffsetRect(but(5).rect,obj.scrInfo.center(1)-buttonOff/2-but(5).rect(3),yPosTop);
                but(5).cache    = obj.positionButtonText(but(5).cache, but(5).rect);
            end
            if but(6).qShow
                but(6).rect     = OffsetRect(but(6).rect,obj.scrInfo.center(1)+buttonOff/2,yPosTop);
                but(6).cache    = obj.positionButtonText(but(6).cache, but(6).rect);
            end
            
            % 3. left side
            if but(7).qShow
                % size and get text
                [but(7).rect,but(7).cache] = obj.getButton(wpnt, but(7).string, but(7).textColor, obj.settings.UI.button.margins);
                % position them
                but(7).rect     = OffsetRect(but(7).rect,0,yPosTop);
                but(7).cache    = obj.positionButtonText(but(7).cache, but(7).rect);
            end
            
            
            % setup menu, if any
            if qHaveMultipleValidCals
                margin          = 10;
                pad             = 3;
                height          = 45;
                nElem           = length(iValid);
                totHeight       = nElem*(height+pad)-pad;
                width           = 900;
                % menu background
                menuBackRect    = [-.5*width+obj.scrInfo.center(1)-margin -.5*totHeight+obj.scrInfo.center(2)-margin .5*width+obj.scrInfo.center(1)+margin .5*totHeight+obj.scrInfo.center(2)+margin];
                % menuRects
                menuRects       = repmat([-.5*width+obj.scrInfo.center(1) -height/2+obj.scrInfo.center(2) .5*width+obj.scrInfo.center(1) height/2+obj.scrInfo.center(2)],length(iValid),1);
                menuRects       = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                % text in each rect
                for c=length(iValid):-1:1
                    % acc field is [lx rx; ly ry]
                    [strl,strr,strsep] = deal('');
                    if obj.calibrateLeftEye
                        strl = sprintf( '<color=%s>Left<color>: %.2f°, (%.2f°,%.2f°)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{1}),cal{iValid(c)}.val.acc2D( 1 ),cal{iValid(c)}.val.acc(:, 1 ));
                    end
                    if obj.calibrateRightEye
                        idx = 1+obj.calibrateLeftEye;
                        strr = sprintf('<color=%s>Right<color>: %.2f°, (%.2f°,%.2f°)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{2}),cal{iValid(c)}.val.acc2D(idx),cal{iValid(c)}.val.acc(:,idx));
                    end
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        strsep = ', ';
                    end
                    str = sprintf('(%d): %s%s%s',c,strl,strsep,strr);
                    Screen('TextFont',  wpnt, obj.settings.UI.val.menu.text.font, obj.settings.UI.val.menu.text.style);
                    Screen('TextSize',  wpnt, obj.settings.UI.val.menu.text.size);
                    menuTextCache(c) = obj.getTextCache(wpnt,str,menuRects(c,:),'baseColor',obj.settings.UI.val.menu.text.color);
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution,4,1);
            
            qDoneCalibSelection = false;
            qToggleSelectMenu   = true;
            qSelectMenuOpen     = true;     % gets set to false on first draw as toggle above is true (hack to make sure we're set up on first entrance of draw loop)
            qChangeMenuArrow    = false;
            qToggleGaze         = false;
            qShowGaze           = false;
            qUpdateCalDisplay   = true;
            qSelectedCalChanged = false;
            qShowCal            = false;
            fixPointRectSz      = 100;
            openInfoForPoint    = nan;
            pointToShowInfoFor  = nan;
            but7Pos             = but(7).rect;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            [mx,my] = obj.getNewMouseKeyPress();
            while ~qDoneCalibSelection
                % toggle gaze on or off if requested
                if qToggleGaze
                    if qShowGaze
                        % switch off
                        obj.buffer.stop('gaze');
                        obj.buffer.clearTimeRange('gaze',gazeStartT);
                    else
                        % switch on
                        gazeStartT = obj.getSystemTime();
                        obj.buffer.start('gaze');
                    end
                    qShowGaze   = ~qShowGaze;
                    qToggleGaze = false;
                end
                
                % setup fixation point positions for cal or val
                if qUpdateCalDisplay || qSelectedCalChanged
                    if qSelectedCalChanged
                        % load requested cal
                        DrawFormattedText(wpnt,'Loading calibration...','center','center',0);
                        Screen('Flip',wpnt);
                        obj.loadOtherCal(cal{selection});
                        qSelectedCalChanged = false;
                        qHasCal = ~isempty(cal{selection}.cal.result);
                        if ~qHasCal && qShowCal
                            qShowCal            = false;
                            % toggle selection menu to trigger updating of
                            % cursors, but make sure menu doesn't actually
                            % open by temporarily changing its state
                            qToggleSelectMenu   = true;
                            qSelectMenuOpen     = ~qSelectMenuOpen;
                        end
                        if ~qHasCal
                            but(7).qShow    = false;
                            but(7).rect     = offScreen;
                        elseif obj.settings.UI.button.val.toggCal.qShow
                            but(7).qShow    = true;
                            but(7).rect     = but7Pos;
                        end
                    end
                    % update info text
                    % acc field is [lx rx; ly ry]
                    % text only changes when calibration selection changes,
                    % but putting these lines in the above if makes logic
                    % more complicated. Now we regenerate the same text
                    % when switching between viewing calibration and
                    % validation output, thats an unimportant price to pay
                    % for simpler logic
                    Screen('TextFont', wpnt, obj.settings.UI.val.avg.text.font, obj.settings.UI.val.avg.text.style);
                    Screen('TextSize', wpnt, obj.settings.UI.val.avg.text.size);
                    [strl,strr,strsep] = deal('');
                    if obj.calibrateLeftEye
                        strl = sprintf(' <color=%s>Left eye<color>:  %.2f°, (%.2f°,%.2f°)   %.2f°   %.2f°  %3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{1}),cal{selection}.val.acc2D( 1 ),cal{selection}.val.acc(:, 1 ),cal{selection}.val.STD2D( 1 ),cal{selection}.val.RMS2D( 1 ),cal{selection}.val.dataLoss( 1 )*100);
                    end
                    if obj.calibrateRightEye
                        idx = 1+obj.calibrateLeftEye;
                        strr = sprintf('<color=%s>Right eye<color>:  %.2f°, (%.2f°,%.2f°)   %.2f°   %.2f°  %3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{2}),cal{selection}.val.acc2D(idx),cal{selection}.val.acc(:,idx),cal{selection}.val.STD2D(idx),cal{selection}.val.RMS2D(idx),cal{selection}.val.dataLoss(idx)*100);
                    end
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        strsep = '\n';
                    end
                    valText = sprintf('<u>Validation<u>    <i>offset 2D, (X,Y)      SD   RMS-S2S  loss<i>\n%s%s%s',strl,strsep,strr);
                    valInfoTopTextCache = obj.getTextCache(wpnt,valText,OffsetRect([-5 0 5 10],obj.scrInfo.resolution(1)/2,.02*obj.scrInfo.resolution(2)),'vSpacing',obj.settings.UI.val.avg.text.vSpacing,'yalign','top','xlayout','left','baseColor',obj.settings.UI.val.avg.text.color);
                    
                    % get info about where points were on screen
                    if qShowCal
                        lbl      = 'calibration';
                        nPoints  = length(cal{selection}.cal.result.gazeData);
                    else
                        lbl      = 'validation';
                        nPoints  = size(cal{selection}.val.pointPos,1);
                    end
                    calValPos   = zeros(nPoints,2);
                    if qShowCal
                        for p=1:nPoints
                            calValPos(p,:)  = cal{selection}.cal.result.gazeData(p).calPos.'.*obj.scrInfo.resolution;
                        end
                    else
                        for p=1:nPoints
                            calValPos(p,:)  = cal{selection}.val.pointPos(p,2:3);
                        end
                    end
                    % get rects around validation points
                    if qShowCal
                        calValRects         = [];
                    else
                        calValRects = zeros(size(cal{selection}.val.pointPos,1),4);
                        for p=1:size(cal{selection}.val.pointPos,1)
                            calValRects(p,:)= CenterRectOnPointd([0 0 fixPointRectSz fixPointRectSz],calValPos(p,1),calValPos(p,2));
                        end
                    end
                    qUpdateCalDisplay   = false;
                    pointToShowInfoFor  = nan;      % close info display, if any
                    if qHasCal && obj.settings.UI.button.val.toggCal.qShow
                        calValLblCache      = obj.getTextCache(wpnt,sprintf('showing %s',lbl),[],'sx',.02*obj.scrInfo.resolution(1),'sy',.97*obj.scrInfo.resolution(2),'xalign','left','yalign','bottom');
                    end
                end
                
                % setup cursors
                if qToggleSelectMenu
                    butRects            = cat(1,but.rect).';
                    currentMenuSel      = find(selection==iValid);
                    qSelectMenuOpen     = ~qSelectMenuOpen;
                    qChangeMenuArrow    = qSelectMenuOpen;  % if opening, also set arrow, so this should also be true
                    qToggleSelectMenu   = false;
                    if qSelectMenuOpen
                        cursors.rect    = [{menuRects.'} num2cell(butRects(:,1:3),1)];
                        cursors.cursor  = repmat(2,1,size(menuRects,1)+3);    % 2: Hand
                    else
                        cursors.rect    = num2cell(butRects,1);
                        cursors.cursor  = repmat(2,1,7);  % 2: Hand
                    end
                    cursors.other   = 0;    % 0: Arrow
                    cursors.qReset  = false;
                    % NB: don't reset cursor to invisible here as it will then flicker every
                    % time you click something. default behaviour is good here
                    cursor = cursorUpdater(cursors);
                end
                if qChangeMenuArrow
                    % setup arrow that can be moved with arrow keys
                    rect = menuRects(currentMenuSel,:);
                    rect(3) = rect(1)+RectWidth(rect)*.07;
                    menuActiveCache = obj.getTextCache(wpnt,' <color=ff0000>-><color>',rect);
                    qChangeMenuArrow = false;
                end
                
                % setup overlay with data quality info for specific point
                if ~isnan(openInfoForPoint)
                    pointToShowInfoFor = openInfoForPoint;
                    openInfoForPoint   = nan;
                    % 1. prepare text
                    Screen('TextFont', wpnt, obj.settings.UI.val.hover.text.font, obj.settings.UI.val.hover.text.style);
                    Screen('TextSize', wpnt, obj.settings.UI.val.hover.text.size);
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        lE = cal{selection}.val.quality(pointToShowInfoFor).left;
                        rE = cal{selection}.val.quality(pointToShowInfoFor).right;
                        str = sprintf('Offset:       <color=%1$s>%3$.2f°, (%4$.2f°,%5$.2f°)<color>, <color=%2$s>%9$.2f°, (%10$.2f°,%11$.2f°)<color>\nPrecision SD:        <color=%1$s>%6$.2f°<color>                 <color=%2$s>%12$.2f°<color>\nPrecision RMS:       <color=%1$s>%7$.2f°<color>                 <color=%2$s>%13$.2f°<color>\nData loss:            <color=%1$s>%8$3.0f%%<color>                  <color=%2$s>%14$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{1}),clr2hex(obj.settings.UI.val.hover.text.eyeColors{2}),lE.acc2D,abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.dataLoss*100,rE.acc2D,abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.dataLoss*100);
                    elseif obj.calibrateLeftEye
                        lE = cal{selection}.val.quality(pointToShowInfoFor).left;
                        str = sprintf('Offset:       <color=%1$s>%2$.2f°, (%3$.2f°,%4$.2f°)<color>\nPrecision SD:        <color=%1$s>%5$.2f°<color>\nPrecision RMS:       <color=%1$s>%6$.2f°<color>\nData loss:            <color=%1$s>%7$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{1}),lE.acc2D,abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.dataLoss*100);
                    elseif obj.calibrateRightEye
                        rE = cal{selection}.val.quality(pointToShowInfoFor).right;
                        str = sprintf('Offset:       <color=%1$s>%2$.2f°, (%3$.2f°,%4$.2f°)<color>\nPrecision SD:        <color=%1$s>%5$.2f°<color>\nPrecision RMS:       <color=%1$s>%6$.2f°<color>\nData loss:            <color=%1$s>%7$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{2}),rE.acc2D,abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.dataLoss*100);
                    end
                    [pointTextCache,txtbounds] = obj.getTextCache(wpnt,str,[],'xlayout','left','baseColor',obj.settings.UI.val.hover.text.color);
                    % get box around text
                    margin = 10;
                    infoBoxRect = GrowRect(txtbounds,margin,margin);
                    infoBoxRect = OffsetRect(infoBoxRect,-infoBoxRect(1),-infoBoxRect(2));  % make sure rect is [0 0 w h]
                end
                
                while true % draw loop
                    % draw validation screen image
                    % draw calibration points
                    obj.drawFixPoints(wpnt,calValPos,obj.settings.UI.val.fixBackSize,obj.settings.UI.val.fixFrontSize,obj.settings.UI.val.fixBackColor,obj.settings.UI.val.fixFrontColor);
                    % draw captured data in characteristic tobii plot
                    for p=1:nPoints
                        if qShowCal
                            myCal = cal{selection}.cal.result;
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = strcmp(myCal.gazeData(p).left.validity,'ValidAndUsed');
                                lEpos= bsxfun(@times,myCal.gazeData(p). left.pos(:,qVal),obj.scrInfo.resolution.');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = strcmp(myCal.gazeData(p).right.validity,'ValidAndUsed');
                                rEpos= bsxfun(@times,myCal.gazeData(p).right.pos(:,qVal),obj.scrInfo.resolution.');
                            end
                        else
                            myVal = cal{selection}.val;
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = myVal.gazeData(p). left.gazePoint.valid;
                                lEpos= bsxfun(@times,myVal.gazeData(p). left.gazePoint.onDisplayArea(:,qVal),obj.scrInfo.resolution.');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = myVal.gazeData(p).right.gazePoint.valid;
                                rEpos= bsxfun(@times,myVal.gazeData(p).right.gazePoint.onDisplayArea(:,qVal),obj.scrInfo.resolution.');
                            end
                        end
                        if obj.calibrateLeftEye  && ~isempty(lEpos)
                            Screen('DrawLines',wpnt,reshape([repmat(bpos,1,size(lEpos,2)); lEpos],2,[]),1,obj.getColorForWindow(obj.settings.UI.val.eyeColors{1}),[],2);
                        end
                        if obj.calibrateRightEye && ~isempty(rEpos)
                            Screen('DrawLines',wpnt,reshape([repmat(bpos,1,size(rEpos,2)); rEpos],2,[]),1,obj.getColorForWindow(obj.settings.UI.val.eyeColors{2}),[],2);
                        end
                    end
                    
                    % draw text with validation accuracy etc info
                    obj.drawCachedText(valInfoTopTextCache);
                    if qHasCal && obj.settings.UI.button.val.toggCal.qShow
                        % draw text indicating whether calibration or
                        % validation is currently shown
                        obj.drawCachedText(calValLblCache);
                    end
                    % draw buttons
                    obj.drawButton(wpnt,but(1));
                    obj.drawButton(wpnt,but(2));
                    obj.drawButton(wpnt,but(3));
                    obj.drawButton(wpnt,but(4));
                    obj.drawButton(wpnt,but(5));
                    obj.drawButton(wpnt,but(6),qShowGaze+1);
                    obj.drawButton(wpnt,but(7),qShowCal+1);
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt,obj.getColorForWindow(obj.settings.UI.val.menu.bgColor),menuBackRect);
                        % menuRects, inactive and currentlyactive
                        qActive = iValid==selection;
                        Screen('FillRect',wpnt,obj.getColorForWindow(obj.settings.UI.val.menu.itemColor      ),menuRects(~qActive,:).');
                        Screen('FillRect',wpnt,obj.getColorForWindow(obj.settings.UI.val.menu.itemColorActive),menuRects( qActive,:).');
                        % text in each rect
                        for c=1:length(iValid)
                            obj.drawCachedText(menuTextCache(c));
                        end
                        obj.drawCachedText(menuActiveCache);
                    end
                    % if hovering over validation point, show info
                    if ~isnan(pointToShowInfoFor)
                        rect = OffsetRect(infoBoxRect,mx,my);
                        % mak sure does not go offscreen
                        if rect(3)>obj.scrInfo.resolution(1)
                            rect = OffsetRect(rect,obj.scrInfo.resolution(1)-rect(3),0);
                        end
                        if rect(4)>obj.scrInfo.resolution(2)
                            rect = OffsetRect(rect,0,obj.scrInfo.resolution(2)-rect(4));
                        end
                        Screen('FillRect',wpnt,obj.getColorForWindow(obj.settings.UI.val.hover.bgColor),rect);
                        obj.drawCachedText(pointTextCache,rect);
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        % draw fixation points
                        obj.drawFixPoints(wpnt,fixPos,obj.settings.UI.val.onlineGaze.fixBackSize,obj.settings.UI.val.onlineGaze.fixFrontSize,obj.settings.UI.val.onlineGaze.fixBackColor,obj.settings.UI.val.onlineGaze.fixFrontColor);
                        % draw gaze data
                        eyeData = obj.buffer.consumeN('gaze');
                        if ~isempty(eyeData.systemTimeStamp)
                            lE = eyeData. left.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution.';
                            rE = eyeData.right.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution.';
                            if obj.calibrateLeftEye  && eyeData. left.gazePoint.valid(end)
                                Screen('gluDisk', wpnt,obj.getColorForWindow(obj.settings.UI.val.onlineGaze.eyeColors{1}), lE(1), lE(2), 10);
                            end
                            if obj.calibrateRightEye && eyeData.right.gazePoint.valid(end)
                                Screen('gluDisk', wpnt,obj.getColorForWindow(obj.settings.UI.val.onlineGaze.eyeColors{2}), rE(1), rE(2), 10);
                            end
                        end
                    end
                    % drawing done, show
                    Screen('Flip',wpnt);
                    
                    % get user response
                    [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if any(buttons)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectMenuOpen
                            iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn) && iIn<=length(iValid)
                                idx                 = iValid(iIn);
                                qSelectedCalChanged = selection~=idx;
                                selection           = idx;
                                qToggleSelectMenu   = true;
                                break;
                            else
                                qToggleSelectMenu   = true;
                                break;
                            end
                        end
                        if ~qSelectMenuOpen || qToggleSelectMenu     % if menu not open or menu closing because pressed outside the menu, check if pressed any of these menu buttons
                            qIn = inRect([mx my],butRects);
                            if any(qIn)
                                if qIn(1)
                                    status = -1;
                                    qDoneCalibSelection = true;
                                elseif qIn(2)
                                    status = -2;
                                    qDoneCalibSelection = true;
                                elseif qIn(3)
                                    status = 1;
                                    qDoneCalibSelection = true;
                                elseif qIn(4)
                                    qToggleSelectMenu   = true;
                                elseif qIn(5)
                                    status = -3;
                                    qDoneCalibSelection = true;
                                elseif qIn(6)
                                    qToggleGaze         = true;
                                elseif qIn(7)
                                    qUpdateCalDisplay   = true;
                                    qShowCal            = ~qShowCal;
                                end
                                break;
                            end
                        end
                    elseif any(keyCode)
                        keys = KbName(keyCode);
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape')) || any(strcmpi(keys,'c'))
                                qToggleSelectMenu = true;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                idx                 = iValid(str2double(keys(1)));
                                qSelectedCalChanged = selection~=idx;
                                selection           = idx;
                                qToggleSelectMenu   = true;
                                break;
                            elseif any(ismember(lower(keys),{'kp_enter','return','enter'})) % lowercase versions of possible return key names (also include numpad's enter)
                                idx                 = iValid(currentMenuSel);
                                qSelectedCalChanged = selection~=idx;
                                selection           = idx;
                                qToggleSelectMenu   = true;
                                break;
                            else
                                if ~iscell(keys), keys = {keys}; end
                                if any(cellfun(@(x) ~isempty(strfind(lower(x(1:min(2,end))),'up')),keys)) %#ok<STREMP>
                                    % up arrow key (test so round-about
                                    % because KbName could return both 'up'
                                    % and 'UpArrow', depending on platform
                                    % and mode)
                                    if currentMenuSel>1
                                        currentMenuSel   = currentMenuSel-1;
                                        qChangeMenuArrow = true;
                                        break;
                                    end
                                elseif any(cellfun(@(x) ~isempty(strfind(lower(x(1:min(4,end))),'down')),keys)) %#ok<STREMP>
                                    % down key
                                    if currentMenuSel<length(iValid)
                                        currentMenuSel   = currentMenuSel+1;
                                        qChangeMenuArrow = true;
                                        break;
                                    end
                                end
                            end
                        else
                            if any(strcmpi(keys,obj.settings.UI.button.val.continue.accelerator))
                                status = 1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.recal.accelerator)) && ~shiftIsDown
                                status = -1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.reval.accelerator))
                                status = -2;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.setup.accelerator)) && ~shiftIsDown
                                status = -3;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.selcal.accelerator)) && qHaveMultipleValidCals
                                qToggleSelectMenu   = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggGaze.accelerator))
                                qToggleGaze         = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggCal.accelerator)) && qHasCal
                                qUpdateCalDisplay   = true;
                                qShowCal            = ~qShowCal;
                                break;
                            end
                        end
                        
                        % these two key combinations should always be available
                        if any(strcmpi(keys,'escape')) && shiftIsDown
                            status = -5;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && shiftIsDown
                            % skip calibration
                            status = 2;
                            qDoneCalibSelection = true;
                            break;
                        end
                    end
                    % check if hovering over point for which we have info
                    if ~isempty(calValRects)
                        iIn = find(inRect([mx my],calValRects.'));
                        if ~isempty(iIn)
                            % see if new point
                            if pointToShowInfoFor~=iIn
                                openInfoForPoint = iIn;
                                break;
                            end
                        elseif ~isnan(pointToShowInfoFor)
                            % stop showing info
                            pointToShowInfoFor = nan;
                            break;
                        end
                    end
                end
            end
            % done, clean up
            cursor.reset();
            activeCal = selection;
            if status~=1
                selection = NaN;
            end
            if qShowGaze
                % if showing gaze, switch off gaze data stream
                obj.buffer.stop('gaze');
                obj.buffer.clearTimeRange('gaze',gazeStartT);
            end
            HideCursor;
        end
        
        function loadOtherCal(obj,cal)
            obj.eyetracker.apply_calibration_data(cal.cal.computedCal);
        end
        
        function [mx,my,mouse,key,shiftIsDown] = getNewMouseKeyPress(obj)
            % function that only returns key depress state changes in the
            % down direction, not keys that are held down or anything else
            % NB: before using this, make sure internal state is up to
            % date!
            [~,~,keyCode]   = KbCheck();
            [mx,my,buttons] = GetMouse();
            
            % get only fresh mouse and key presses (so change from state
            % "up" to state "down")
            key     = keyCode & ~obj.keyState;
            mouse   = buttons & ~obj.mouseState;
            
            % get if shift key is currently down
            shiftIsDown = ~~keyCode(obj.shiftKey);
            
            % store to state
            obj.keyState    = keyCode;
            obj.mouseState  = buttons;
        end
        
        function clr = getColorForWindow(obj,clr)
            if obj.qFloatColorRange
                clr = double(clr)/255;
            end
        end
    end
end



%%% helpers
function angle = AngleBetweenVectors(a,b)
angle = atan2(sqrt(sum(cross(a,b,1).^2,1)),dot(a,b,1))*180/pi;
end

function iValid = getValidCalibrations(cal)
iValid = find(cellfun(@(x) isfield(x,'calStatus') && x.calStatus==1 && ~isempty(x.cal.result) && strcmp(x.cal.result.status(1:7),'Success'),cal));
end

function result = fixupTobiiCalResult(calResult,hasLeft,hasRight)
result = calResult;
return
% status
result.status = TobiiEnumToString(calResult.Status);

% data points used for calibration
for p=length(calResult.CalibrationPoints):-1:1
    dat = calResult.CalibrationPoints(p);
    % calibration point position
    result.gazeData(p).calPos   = dat.PositionOnDisplayArea.';
    % gaze data for the point
    if hasLeft
        result.gazeData(p). left.validity = TobiiEnumToString(cat(2,dat. LeftEye.Validity));
        result.gazeData(p). left.pos      = cat(1,dat. LeftEye.PositionOnDisplayArea).';
    end
    if hasRight
        result.gazeData(p).right.validity = TobiiEnumToString(cat(2,dat.RightEye.Validity));
        result.gazeData(p).right.pos      = cat(1,dat.RightEye.PositionOnDisplayArea).';
    end
end
end

function hex = clr2hex(clr)
hex = reshape(dec2hex(clr(1:3),2).',1,[]);
end

function [texs,szs] = UploadImages(texs,szs,wpnt,image)
if isempty(image)
    return;
end
qHave = [false false];
if isempty(szs)
    szs   = nan(2,2);
end
for p=length(image.cameraID):-1:1
    % get which camera, 0 is right, 1 is left
    which = image.cameraID(p);
    if which==0
        which = 2;
    end
    % if we haven't uploaded an image for this camera yet, do
    % so now
    if ~qHave(which)
        [w,h] = deal(image.width(p),image.height(p));
        if iscell(image.image)
            im = image.image{p};
        else
            im = image.image(:,p);
        end
        im = reshape(im,w,h).';
        texs (which) = UploadImage(texs(which),wpnt,im);
        qHave(which) = true;
        szs(:,which) = [w h].';
    end
    if all(qHave)
        break;
    end
end
end

function tex = UploadImage(tex,wpnt,image)
if tex
    Screen('Close',tex);
end
% 8 to prevent mipmap generation, we don't need it
% fliplr to make eye image look like coming from a mirror
% instead of simply being from camera's perspective
tex = Screen('MakeTexture',wpnt,fliplr(image),[],8);
end

function drawCircle(wpnt,clr,center,sz,lineWidth,fillClr)
nStep = 200;
alpha = linspace(0,2*pi,nStep);
alpha = [alpha(1:end-1); alpha(2:end)]; alpha = alpha(:).';
xy    = sz.*[cos(alpha); sin(alpha)];
if nargin>=6
    Screen('FillPoly', wpnt, fillClr, xy.'+repmat(center(:).',size(alpha,2),1), 1);
end
if lineWidth && ~isempty(clr)
    Screen('DrawLines', wpnt, xy, lineWidth ,clr ,center,2);
end
end

function fieldString = getStructFieldsString(str)
fieldInfo = getStructFields(str);

% add dots
for c=size(fieldInfo,2):-1:2
    qHasField = ~cellfun(@isempty,fieldInfo(:,c));
    temp = repmat({''},size(fieldInfo,1),1);
    temp(qHasField) = {'.'};
    fieldInfo = [fieldInfo(:,1:c-1) temp fieldInfo(:,c:end)];
end

% concat per row
fieldInfo = num2cell(fieldInfo,2);
fieldString = cellfun(@(x) cat(2,x{:}),fieldInfo,'uni',false);
end

function fieldInfo = getStructFields(str)
qSubStruct  = structfun(@isstruct,str);
fieldInfo   = fieldnames(str);
if any(qSubStruct)
    idx         = find(qSubStruct);
    for p=length(idx):-1:1
        temp = getStructFields(str.(fieldInfo{idx(p),1}));
        if size(temp,2)+1>size(fieldInfo,2)
            extraCol = size(temp,2)+1-size(fieldInfo,2);
            fieldInfo = [fieldInfo repmat({''},size(fieldInfo,1),extraCol)]; %#ok<AGROW>
        end
        add = repmat(fieldInfo(idx(p),:),size(temp,1),1);
        add(:,(1:size(temp,2))+1) = temp;
        fieldInfo = [fieldInfo(1:idx(p)-1,:); add; fieldInfo(idx(p)+1:end,:)];
    end
end
end