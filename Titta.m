classdef Titta < handle
    properties (Access = protected, Hidden = true)
        % dll and mex files
        tobii;
        eyetracker;
        buffers;
        
        % message buffer
        msgs                = simpleVec(cell(1,2),1024);   % initialize with space for 1024 messages
        
        % state
        isInitialized       = false;
        usingFTGLTextRenderer;
        keyState;
        shiftKey;
        mouseState;
        calibrateLeftEye    = true;
        calibrateRightEye   = true;
        
        % settings and external info
        settings;
        scrInfo;
    end
    
    properties (SetAccess=private)
        systemInfo;
        geom;
        calibrateHistory;
        recState;
    end
    
    % computed properties (so not actual properties)
    properties (Dependent, SetAccess = private)
        rawSDK;         % get naked Tobii SDK instance
        rawET;          % get naked Tobii SDK handle to eyetracker
        rawBuffers;     % get naked Tobiibuffer instance
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
        
        function out = get.rawBuffers(obj)
            out = obj.buffers;
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
                expected    = getStructFields(defaults);
                input       = getStructFields(settings);
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
            obj.settings.cal.bgColor        = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor   = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor  = color2RGBA(obj.settings.cal.fixFrontColor);
            obj.settings.setup.eyeColorsHex = cellfun(@(x) reshape(dec2hex(x).',1,[]),obj.settings.setup.eyeColors,'uni',false);
            obj.settings.setup.eyeColors    = cellfun(@color2RGBA                    ,obj.settings.setup.eyeColors,'uni',false);
            
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
            obj.buffers = TobiiBuffer();
            obj.buffers.startLogging();
            
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
            obj.buffers.init(obj.eyetracker.Address);
            
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
            
            % init recording state
            obj.recState.gaze           = false;
            obj.recState.timeSync       = false;
            obj.recState.externalSignal = false;
            obj.recState.eyeImage       = false;
            
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
            [osf,odf,ocm]           = Screen('BlendFunction', wpnt, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            
            % see what text renderer to use
            obj.usingFTGLTextRenderer = ~~exist('libptbdrawtext_ftgl64.dll','file') && Screen('Preference','TextRenderer')==1;    % check if we're on a Windows platform with the high quality text renderer present (was never supported for 32bit PTB, so check only for 64bit)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.text,'lineCentOff'),'Titta: PTB''s TextRenderer changed between calls to getDefaults and the SMIWrapper constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call SMIWrapper.getDefaults(), as it has differnt settings than the recommended TextRendered number 1')
            end
            
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            obj.shiftKey = KbName('shift');
            [~,~,obj.mouseState] = GetMouse();
            
            
            %%% 1. some preliminary setup, to make sure we are in known state
            if strcmp(obj.settings.calibrateEye,'both')
                calibClass = ScreenBasedCalibration(obj.eyetracker);
            else
                calibClass = ScreenBasedMonocularCalibration(obj.eyetracker);
            end
            try
                if bitand(flag,1)
                    calibClass.leave_calibration_mode();    % make sure we're not already in calibration mode (start afresh)
                end
            catch ME %#ok<NASGU>
                % no-op, ok if fails, simply means we're not already in
                % calibration mode
            end
            obj.StopRecordAll();
            if bitand(flag,1)
                calibClass.enter_calibration_mode();
            end
            
            %%% 2. enter the setup/calibration screens
            % The below is a big loop that will run possibly multiple
            % calibration until exiting because skipped or a calibration is
            % selected by user.
            % there are three start modes:
            % 0. skip head positioning, go straight to calibration
            % 1. start with simple head positioning interface
            % 2. start with advanced head positioning interface
            startScreen = obj.settings.setup.startScreen;
            kCal = 0;
            while true
                qGoToValidationViewer = false;
                kCal = kCal+1;
                out.attempt{kCal}.eye  = obj.settings.calibrateEye;
                if startScreen>0
                    %%% 2a: show head positioning screen
                    out.attempt{kCal}.setupStatus = obj.showHeadPositioning(wpnt,out,startScreen);
                    switch out.attempt{kCal}.setupStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            break;
                        case -3
                            % go to validation viewer screen
                            qGoToValidationViewer = true;
                        case -4
                            % full stop
                            error('Titta: run ended from calibration routine')
                        otherwise
                            error('Titta: status %d not implemented',out.attempt{kCal}.setupStatus);
                    end
                end
                
                %%% 2b: calibrate and validate
                if ~qGoToValidationViewer
                    [out.attempt{kCal}.calStatus,temp] = obj.DoCalAndVal(wpnt,kCal,calibClass);
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
                            % restart calibration
                            startScreen = 0;
                            continue;
                        case -2
                            % go to setup
                            startScreen = max(1,startScreen);
                            continue;
                        case -4
                            % full stop
                            error('Titta: run ended from calibration routine')
                        otherwise
                            error('Titta: status %d not implemented',out.attempt{kCal}.calStatus);
                    end
                end
                % TODO: somewhere here store info about calibration quality
                % (only mean accuracy I guess)
                
                %%% 2c: show calibration results
                % show validation result and ask to continue
                [out.attempt{kCal}.valReviewStatus,out.attempt{kCal}.calSelection] = obj.showCalValResult(wpnt,out.attempt,kCal);
                switch out.attempt{kCal}.valReviewStatus
                    case 1
                        % all good, we're done
                        % TODO: note which calibration was chosen
                        break;
                    case 2
                        % skip setup
                        break;
                    case -1
                        % restart calibration
                        startScreen = 0;
                        continue;
                    case -2
                        % go to setup
                        startScreen = max(1,startScreen);
                        continue;
                    case -4
                        % full stop
                        error('Titta: run ended from Tobii routine')
                    otherwise
                        error('Titta: status %d not implemented',out.attempt{kCal}.valReviewStatus);
                end
            end
            
            % clean up
            Screen('Flip',wpnt);
            Screen('BlendFunction', wpnt, osf,odf,ocm);
            if bitand(flag,2)
                calibClass.leave_calibration_mode();
            end
            % log to messages which calibration was selected
            if isfield(out,'attempt') && isfield(out.attempt{kCal},'calSelection')
                obj.sendMessage(sprintf('Selected calibration %d',out.attempt{kCal}.calSelection));
            end
            
            % store calibration info in calibration history, for later
            % retrieval if wanted
            if isempty(obj.calibrateHistory)
                obj.calibrateHistory{1} = out;
            else
                obj.calibrateHistory{end+1} = out;
            end
        end
        
        function result = startRecording(obj,stream)
            % For these, the first call subscribes to the stream and returns
            % either data (might be empty if no data has been received yet) or
            % any error that happened during the subscription.
            % TODO: support optional size of buffer input
            result = true;
            assert(nargin>1,'Titta: startRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            switch lower(stream)
                case 'gaze'
                    field       = 'gaze';
                    if ~obj.recState.gaze
                        result      = obj.buffers.start('sample');
                        streamLbl   = 'gaze data';
                    end
                case 'eyeimage'
                    if obj.hasCap(EyeTrackerCapabilities.HasEyeImages)
                        field   	= 'eyeImage';
                        if ~obj.recState.eyeImage
                            result      = obj.buffers.start('eyeImage');
                            streamLbl   = 'eye images';
                        end
                    else
                        error('Titta: recording of eye images is not supported by this eye-tracker')
                    end
                case 'externalsignal'
                    if obj.hasCap(EyeTrackerCapabilities.HasExternalSignal)
                        field       = 'externalSignal';
                        if ~obj.recState.externalSignal
                            result      = obj.buffers.start('extSignal');
                            streamLbl   = 'external signals';
                        end
                    else
                        error('Titta: recording of external signals is not supported by this eye-tracker')
                    end
                case 'timesync'
                    field       = 'timeSync';
                    if ~obj.recState.timeSync
                        result      = obj.buffers.start('timeSync');
                        streamLbl   = 'sync data';
                    end
                otherwise
                    error('Titta: signal "%s" not known\nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"',stream);
            end
            
            % check for errors
            if ~result
                error('Titta: Error starting recording %s',streamLbl);
            end
            % mark that we are recording
            obj.recState.(field) = true;
        end
        
        function data = consumeN(obj,stream,varargin)
            % optional input argument firstN: how many samples to consume
            % from start. Default: all
            data = obj.consumeOrPeek(stream,'consumeN',varargin{:});
        end
        
        function data = consumeTimeRange(obj,stream,varargin)
            % optional inputs startT and endT. Default: whole range
            data = obj.consumeOrPeek(stream,'consumeTimeRange',varargin{:});
        end
        
        function data = peekN(obj,stream,varargin)
            % optional input argument lastN: how many samples to peek from
            % end. Default: 1. To get all, ask for -1 samples
            data = obj.consumeOrPeek(stream,'peekN',varargin{:});
        end
        
        function data = peekTimeRange(obj,stream,varargin)
            % optional inputs startT and endT. Default: whole range
            data = obj.consumeOrPeek(stream,'peekTimeRange',varargin{:});
        end
        
        function clearBuffer(obj,stream)
            obj.clearImpl(stream,'clear');
        end
        
        function clearBufferTimeRange(obj,stream,varargin)
            % optional inputs startT and endT. Default: whole range
            obj.clearImpl(stream,'clearTimeRange',varargin{:});
        end
        
        function stopRecording(obj,stream,qClearBuffer)
            assert(nargin>1,'Titta: stopRecording: provide stream argument. \nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"');
            if nargin<3 || isempty(qClearBuffer)
                qClearBuffer = false;
            end
            field = '';
            switch lower(stream)
                case 'gaze'
                    if obj.recState.gaze
                        success = obj.buffers.stop('sample',qClearBuffer);
                        field   = 'gaze';
                    end
                case 'eyeimage'
                    if obj.recState.eyeImage
                        success = obj.buffers.stop('eyeImage',qClearBuffer);
                        field   = 'eyeImage';
                    end
                case 'externalsignal'
                    if obj.recState.externalSignal
                        success = obj.buffers.stop('extSignal',qClearBuffer);
                        field   = 'externalSignal';
                    end
                case 'timesync'
                    if obj.recState.timeSync
                        success = obj.buffers.stop('timeSync',qClearBuffer);
                        field   = 'timeSync';
                    end
                otherwise
                    error('Titta: stream "%s" not known\nSupported streams are: "gaze", "eyeImage", "externalSignal" and "timeSync"',stream);
            end
            
            % mark that we stopped recording
            if ~isempty(field) && success
                obj.recState.(field) = false;
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
            dat.TobiiLog    = obj.buffers.getLog(false);
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
            dat = obj.collectSessionData(); %#ok<NASGU>
            
            % save
            try
                save(filename,'-struct','dat');
            catch ME
                error('Titta: Error saving data:\n%s',ME.getReport('extended'))
            end
        end
        
        function out = deInit(obj)
            if ~isempty(obj.rawBuffers)
                % return and stop log
                out = obj.rawBuffers.getLog();
                obj.rawBuffers.stopLogging();
            end
            
            % mark as deinited
            obj.isInitialized = false;
        end
    end
    
    
    
    
    % helpers
    methods (Static)
        function settings = getDefaults(tracker)
            settings.tracker    = tracker;
            
            % default tracking settings per eye-tracker
            switch tracker
                case 'Tobii Pro Spectrum'
                    settings.freq                   = 600;
                    settings.trackingMode           = 'human';
                case 'IS4_Large_Peripheral'
                    settings.freq                   = 90;
                    settings.trackingMode           = 'Default';
                case 'X2-60_Compact'
                    settings.freq                   = 60;
                    settings.trackingMode           = 'Default';
            end
            
            % the rest here are good defaults for all
            settings.calibrateEye           = 'both';                           % 'both', also possible if supported by eye tracker: 'left' and 'right'
            settings.serialNumber           = '';
            settings.licenseFile            = '';
            settings.nTryConnect            = 1;                                % How many times to try to connect before giving up
            settings.connectRetryWait       = 4;                                % seconds
            settings.setup.startScreen      = 1;                                % 0. skip head positioning, go straight to calibration; 1. start with simple head positioning interface; 2. start with advanced head positioning interface
            settings.setup.simpleShowEyes   = true;
            settings.setup.viewingDist      = 65;
            settings.setup.eyeColors        = {[177 97 24],[37 88 122]};        % L, R eye
            % TODO: do we support zero points? and also for val?
            settings.cal.pointPos           = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
            settings.cal.autoPace           = 1;                                % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
            settings.cal.paceDuration       = 1.5;                              % minimum duration (s) that each point is shown
            settings.cal.qRandPoints        = true;
            settings.cal.bgColor            = 127;
            settings.cal.fixBackSize        = 20;
            settings.cal.fixFrontSize       = 5;
            settings.cal.fixBackColor       = 0;
            settings.cal.fixFrontColor      = 255;
            settings.cal.drawFunction       = [];
            settings.cal.doRecordEyeImages  = false;
            settings.cal.doRecordExtSignal  = false;
            settings.val.pointPos           = [[0.25 0.25]; [0.25 0.75]; [0.75 0.75]; [0.75 0.25]];
            settings.val.paceDuration       = 1.5;
            settings.val.collectDuration    = 0.5;
            settings.val.qRandPoints        = true;
            settings.text.font              = 'Consolas';
            settings.text.color             = 0;                                % only for messages on the screen, doesn't affect buttons
            settings.text.style             = 0;                                % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.text.wrapAt            = 62;
            settings.text.vSpacing          = 1;
            if ~exist('libptbdrawtext_ftgl64.dll','file') || Screen('Preference','TextRenderer')==0 % if old text renderer, we have different defaults and an extra settings
                settings.text.size          = 18;
                settings.text.lineCentOff   = 3;                                % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
            else
                settings.text.size          = 24;
            end
            settings.string.simplePositionInstruction = 'Position yourself such that the two circles overlap.\nDistance: %.0f cm';
            settings.debugMode              = false;                            % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
        end
        
        function time = getSystemTime()
            time = int64(round(GetSecs()*1000*1000));
        end
    end
    
    methods (Access = private, Hidden)
        function allowed = getAllowedOptions(obj)
            allowed = {...
                'calibrateEye',''
                'setup','startScreen'
                'setup','viewingDist'
                'setup','eyeColors'
                'setup','simpleShowEyes'
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
                'val','pointPos'
                'val','paceDuration'
                'val','collectDuration'
                'val','qRandPoints'
                'text','font'
                'text','color'
                'text','size'
                'text','style'
                'text','wrapAt'
                'text','vSpacing'
                'text','lineCentOff'
                'string','simplePositionInstruction'
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
        
        function status = showHeadPositioning(obj,wpnt,out,startScreen)
            % status output:
            %  1: continue (setup seems good) (space)
            %  2: skip calibration and continue with task (shift+s)
            % -3: go to validation screen (p) -- only if there are already
            %     completed calibrations
            % -4: Exit completely (control+escape)
            % (NB: no -1 for this function)
            
            % init
            status = 5+5*(startScreen==2);  % 5 if simple screen requested, 10 if advanced screen
            startT = obj.sendMessage('SETUP START');
            obj.startRecording('gaze');
            % see if we already have valid calibrations
            qHaveValidCalibrations = ~isempty(getValidCalibrations(out.attempt));
            
            while true
                if status==5
                    % simple setup screen. has two circles for positioning, a button to
                    % start calibration and a button to go to advanced view
                    status = obj.showHeadPositioningSimple  (wpnt,qHaveValidCalibrations);
                elseif status==10
                    % advanced interface, has head box and eye image
                    status = obj.showHeadPositioningAdvanced(wpnt,qHaveValidCalibrations);
                else
                    break;
                end
            end
            obj.stopRecording('gaze');
            endT = obj.sendMessage('SETUP END');
            obj.clearBufferTimeRange('gaze',startT,endT);
        end
        
        function status = showHeadPositioningSimple(obj,wpnt,qHaveValidCalibrations)
            % if user is at reference viewing distance and at center of
            % head box vertically and horizontally, two circles will
            % overlap
            
            % setup text
            Screen('TextFont',  wpnt, obj.settings.text.font);
            Screen('TextSize',  wpnt, obj.settings.text.size);
            Screen('TextStyle', wpnt, obj.settings.text.style);
            
            % setup ovals
            ovalVSz     = .15;
            refSz       = ovalVSz*obj.scrInfo.resolution(2);
            refClr      = [0 0 255];
            headClr     = [255 255 0];
            headFillClr = [headClr .3*255];
            % setup head position visualization
            distGain    = 1.5;
            eyeClr      = [255 255 255];
            eyeSzFac    = .25;
            eyeMarginFac= .25;

            % setup buttons
            buttonSz    = {[220 45] [320 45] [400 45]};
            buttonSz    = buttonSz(1:2+qHaveValidCalibrations);  % third button only when more than one calibration available
            buttonOff   = 80;
            yposBase    = round(obj.scrInfo.resolution(2)*.95);
            % place buttons for go to advanced interface, or calibrate
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            b = 1;
            advancedButRect         = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
            advancedButTextCache    = obj.getTextCache(wpnt,'advanced (<i>a<i>)'        ,advancedButRect);
            b=b+1;
            
            calibButRect            = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
            calibButTextCache       = obj.getTextCache(wpnt,'calibrate (<i>spacebar<i>)',   calibButRect);
            b=b+1;
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
                validateButTextCache    = obj.getTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution,4,1);
            
            % setup cursors
            cursors.rect    = {advancedButRect.' calibButRect.' validateButRect.'};
            cursors.cursor  = [2 2 2];      % Hand
            cursors.other   = 0;            % Arrow
            if ~obj.settings.debugMode      % for cleanup
                cursors.reset = -1;         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor  = cursorUpdater(cursors);
            
            % get tracking status and visualize
            eyeDist = nan;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while true
                % get latest data from eye-tracker
                eyeData = obj.buffers.peekN('sample',1);
                [lEye,rEye] = deal(nan(3,1));
                if ~isempty(eyeData.systemTimeStamp) && obj.calibrateLeftEye
                    lEye = eyeData. left.gazeOrigin.inUserCoords;
                end
                qHaveLeft   = obj.calibrateLeftEye  && ~isempty(eyeData.systemTimeStamp) && eyeData. left.gazeOrigin.valid;
                if ~isempty(eyeData.systemTimeStamp) && obj.calibrateRightEye
                    rEye = eyeData.right.gazeOrigin.inUserCoords;
                end
                qHaveRight  = obj.calibrateRightEye && ~isempty(eyeData.systemTimeStamp) && eyeData.right.gazeOrigin.valid;
                qHave       = [qHaveLeft qHaveRight];
                
                
                % get average eye distance. use distance from one eye if only one eye
                % available
                dists   = [lEye(3) rEye(3)]./10;
                avgDist = mean(dists(qHave));
                Xs      = [lEye(1) rEye(1)]./10;
                if isnan(eyeDist) && any(qHave)
                    % get distance between eyes
                    eyeDist = hypot(diff(Xs),diff(dists));
                end
                if any(qHave) && ~isnan(eyeDist)
                    % if we have only one eye, make fake second eye
                    % position so drawn head position doesn't jump so much.
                    if ~qHaveLeft
                        Xs(1) = Xs(2)-eyeDist;
                    elseif ~qHaveRight
                        Xs(2) = Xs(1)+eyeDist;
                    end
                end
                avgX    = mean(Xs(~isnan(Xs))); % on purpose isnan() instead of qHave, as we may have just repaired a missing Xs above
                Ys      = [lEye(2) rEye(2)]./10;
                avgY    = mean(Ys(qHave));
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
                    fac     = avgDist/obj.settings.setup.viewingDist;
                    headSz  = refSz - refSz*(fac-1)*distGain;
                    eyeSz   = eyeSzFac*headSz;
                    eyeMargin = eyeMarginFac*headSz*2;  %*2 because all sizes are radii
                    % move
                    headPos = pos.*obj.scrInfo.resolution;
                else
                    headPos = [];
                end
                
                % draw distance info
                DrawFormattedText(wpnt,sprintf(obj.settings.string.simplePositionInstruction,avgDist),'center',fixPos(1,2)-.03*obj.scrInfo.resolution(2),obj.settings.text.color,[],[],[],1.5);
                % draw ovals
                drawCircle(wpnt,refClr,obj.scrInfo.center,refSz,5);
                if ~isempty(headPos)
                    drawCircle(wpnt,headClr,headPos,headSz,5,headFillClr);
                    if obj.settings.setup.simpleShowEyes
                        % left eye
                        pos = headPos; pos(1) = pos(1)-eyeMargin;
                        if ~obj.calibrateLeftEye
                            base = [-eyeSz eyeSz eyeSz -eyeSz; -eyeSz/4 -eyeSz/4 eyeSz/4 eyeSz/4];
                            R    = [cosd(45) -sind(45); sind(45) cosd(45)];
                            Screen('FillPoly', wpnt, [255 0 0], bsxfun(@plus,R  *base,pos(:)).', 1);
                            Screen('FillPoly', wpnt, [255 0 0], bsxfun(@plus,R.'*base,pos(:)).', 1);
                        elseif qHaveLeft
                            drawCircle(wpnt,[],pos,eyeSz,0,eyeClr);
                        else
                            rect = CenterRectOnPointd([-eyeSz -eyeSz/5 eyeSz eyeSz/5],pos(1),pos(2));
                            Screen('FillRect', wpnt, eyeClr, rect);
                        end
                        % right eye
                        pos(1) = pos(1)+eyeMargin*2;
                        if ~obj.calibrateRightEye
                            base = [-eyeSz eyeSz eyeSz -eyeSz; -eyeSz/4 -eyeSz/4 eyeSz/4 eyeSz/4];
                            R    = [cosd(45) -sind(45); sind(45) cosd(45)];
                            Screen('FillPoly', wpnt, [255 0 0], bsxfun(@plus,R  *base,pos(:)).', 1);
                            Screen('FillPoly', wpnt, [255 0 0], bsxfun(@plus,R.'*base,pos(:)).', 1);
                        elseif qHaveRight
                            drawCircle(wpnt,[],pos,eyeSz,0,eyeClr);
                        else
                            rect = CenterRectOnPointd([-eyeSz -eyeSz/5 eyeSz eyeSz/5],pos(1),pos(2));
                            Screen('FillRect', wpnt, eyeClr, rect);
                        end
                    end
                end
                % draw buttons
                Screen('FillRect',wpnt,[ 37  97 163],advancedButRect);
                obj.drawCachedText(advancedButTextCache);
                Screen('FillRect',wpnt,[  0 120   0],calibButRect);
                obj.drawCachedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    obj.drawCachedText(validateButTextCache);
                end
                % draw fixation points
                obj.drawFixPoints(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                
                % get user response
                [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],[advancedButRect.' calibButRect.' validateButRect.']);
                    if qIn(1)
                        status = 10;
                        break;
                    elseif qIn(2)
                        status = 1;
                        break;
                    elseif qIn(3)
                        status = -3;
                        break;
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'a'))
                        status = 10;
                        break;
                    elseif any(strcmpi(keys,'space'))
                        status = 1;
                        break;
                    elseif any(strcmpi(keys,'p')) && qHaveValidCalibrations
                        status = -3;
                        break;
                    elseif any(strcmpi(keys,'escape')) && shiftIsDown
                        status = -4;
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
        end
        
        
        function status = showHeadPositioningAdvanced(obj,wpnt,qHaveValidCalibrations)
            qHasEyeIm = obj.hasCap(EyeTrackerCapabilities.HasExternalSignal);
            if qHasEyeIm
                eyeStartTime = obj.getSystemTime();
                obj.startRecording('eyeImage');
            end
            
            % setup text
            Screen('TextFont',  wpnt, obj.settings.text.font);
            Screen('TextSize',  wpnt, obj.settings.text.size);
            Screen('TextStyle', wpnt, obj.settings.text.style);
            % setup box
            trackBoxDepths  = double([obj.geom.trackBox.FrontLowerLeft(3) obj.geom.trackBox.BackLowerLeft(3)]./10);
            boxSize = double((obj.geom.trackBox.FrontUpperRight-obj.geom.trackBox.FrontLowerLeft)./10);
            boxSize = round(500.*boxSize(1:2)./boxSize(1));
            [boxCenter(1),boxCenter(2)] = RectCenter([0 0 boxSize]);
            % setup eye image
            if qHasEyeIm
                margin  = 80;
                texs    = [0 0];
                eyeIm   = [];
                count   = 0;
                while isempty(eyeIm) && count<20
                    eyeIm = obj.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward
                    WaitSecs('YieldSecs',0.15);
                    count = count+1;
                end
                if ~isempty(eyeIm)
                    [texs,szs]  = UploadImages(texs,[],wpnt,eyeIm);
                else
                    szs         = [496 175; 496 175].';     % init at size of Spectrum@600Hz, decent enough guess for now
                end
                eyeImRect   = [zeros(2) szs.'];
                maxEyeImRect= max(eyeImRect,[],1);
            else
                margin       = 0;
                maxEyeImRect = [0 0 0 0];
            end
            
            % setup buttons
            buttonSz    = {[200 45] [320 45] [400 45]};
            buttonSz    = buttonSz(1:2+qHaveValidCalibrations);  % third button only when more than one calibration available
            buttonOff   = 80;
            yposBase    = round(obj.scrInfo.resolution(2)*.95);
            
            % position eye image, head box and buttons
            % center headbox and eye image on screen
            offsetV         = (obj.scrInfo.resolution(2)-boxSize(2)-margin-RectHeight(maxEyeImRect))/2;
            offsetH         = (obj.scrInfo.resolution(1)-boxSize(1))/2;
            boxRect         = OffsetRect([0 0 boxSize],offsetH,offsetV);
            if qHasEyeIm
                eyeImageRect{1} = OffsetRect(eyeImRect(1,:),obj.scrInfo.center(1)-eyeImRect(1,3)-10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(1,:))/2);
                eyeImageRect{2} = OffsetRect(eyeImRect(2,:),obj.scrInfo.center(1)               +10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(2,:))/2);
            end
            % place buttons for back to simple interface, or calibrate
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            basicButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],obj.scrInfo.center(1),yposBase-buttonSz{1}(2));
            basicButTextCache   = obj.getTextCache(wpnt,'basic (<i>b<i>)'          , basicButRect);
            calibButRect        = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],obj.scrInfo.center(1),yposBase-buttonSz{2}(2));
            calibButTextCache   = obj.getTextCache(wpnt,'calibrate (<i>spacebar<i>)',calibButRect);
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],obj.scrInfo.center(1),yposBase-buttonSz{3}(2));
                validateButTextCache    = obj.getTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution,4,1);
            
            gain = 1.5;     % 1.5 is a gain to make differences larger
            sz   = 15;      % base size at reference distance
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
            col2 = [255 155 0]; % color for arrow when just visible, just before exceeding second threshold
            col3 = [255 0   0]; % color for arrow when extreme, exceeding second threshold
            xThresh = [2/3 .8];
            yThresh = [.7  .85];
            zThresh = [.7  .85];
            
            % setup cursors
            cursors.rect    = {basicButRect.' calibButRect.' validateButRect.'};
            cursors.cursor  = [2 2 2];      % Hand
            cursors.other   = 0;            % Arrow
            if ~obj.settings.debugMode      % for cleanup
                cursors.reset = -1;         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor          = cursorUpdater(cursors);
            
            
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            arrowColor  = zeros(3,6);
            relPos      =   nan(3,1);
            while true
                eyeData = obj.buffers.peekN('sample',1);
                [lEye,rEye]     = deal(nan(3,1));
                [lValid,rValid] = deal(false);
                if ~isempty(eyeData.systemTimeStamp) && obj.calibrateLeftEye
                    lValid  = eyeData. left.gazeOrigin.valid;
                    lEye = eyeData. left.gazeOrigin.inTrackBoxCoords;
                end
                if ~isempty(eyeData.systemTimeStamp) && obj.calibrateRightEye
                    rValid  = eyeData.right.gazeOrigin.valid;
                    rEye = eyeData.right.gazeOrigin.inTrackBoxCoords;
                end
                
                % if one eye missing, estimate where it would be if user
                % kept head yaw constant
                if ~lValid && rValid
                    lEye = rEye-relPos;
                elseif ~rValid
                    rEye = lEye+relPos;
                end
                
                % get average eye distance. use distance from one eye if only one eye
                % available
                distL   = lEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                distR   = rEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                dists   = [distL distR];
                avgDist = mean(dists(~isnan(dists)));
                
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
                
                if qHasEyeIm
                    % get eye image
                    eyeIm       = obj.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward
                    [texs,szs]  = UploadImages(texs,szs,wpnt,eyeIm);
                    
                    % update eye image locations (and possibly track box) if
                    % size of returned eye image changed
                    if (~any(isnan(szs(:,1))) && any(szs(:,1).'~=eyeImRect(1,3:4))) || (~any(isnan(szs(:,2))) && any(szs(:,2).'~=eyeImRect(2,3:4)))
                        if ~any(isnan(szs(:,1)))
                            eyeImRect(1,3:4) = szs(:,1).';
                        end
                        if ~any(isnan(szs(:,2)))
                            eyeImRect(2,3:4) = szs(:,2).';
                        end
                        if max(eyeImRect(:,4))>maxEyeImRect(4)
                            % just got a larger eye image, make room to
                            % accomodate it
                            maxEyeImRect    = max(eyeImRect,[],1);
                            offsetV         = (obj.scrInfo.resolution(2)-boxSize(2)-margin-RectHeight(maxEyeImRect))/2;
                            offsetH         = (obj.scrInfo.resolution(1)-boxSize(1))/2;
                            boxRect         = OffsetRect([0 0 boxSize],offsetH,offsetV);
                        end
                        eyeImageRect{1} = OffsetRect(eyeImRect(1,:),obj.scrInfo.center(1)-eyeImRect(1,3)-10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(1,:))/2);
                        eyeImageRect{2} = OffsetRect(eyeImRect(2,:),obj.scrInfo.center(1)               +10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(2,:))/2);
                    end
                end
                
                % do drawing
                % draw box
                Screen('FillRect',wpnt,80,boxRect);
                % draw distance
                if ~isnan(avgDist)
                    if obj.usingFTGLTextRenderer
                        Screen('TextSize', wpnt, 12);
                    else
                        Screen('TextSize', wpnt, 10);
                    end
                    Screen('DrawText',wpnt,sprintf('%.0f cm',avgDist) ,boxRect(3)-40,boxRect(4)-16,255);
                end
                % draw eyes in box
                Screen('TextSize',  wpnt, obj.settings.text.size);
                if lValid || rValid
                    posL     = [1-lEye(1) lEye(2)];  %1-X as 0 is right and 1 is left edge. needs to be reflected for screen drawing
                    posR     = [1-rEye(1) rEye(2)];
                    % determine size of eye. based on distance from viewing
                    % distance, calculate size change
                    facL = obj.settings.setup.viewingDist/distL;
                    facR = obj.settings.setup.viewingDist/distR;
                    style = Screen('TextStyle', wpnt, 1);
                    % left eye
                    if ~isnan(posL(1))
                        drawEye(wpnt,lValid,posL,obj.settings.setup.eyeColors{1},round(sz*facL*gain),'L',boxRect);
                    end
                    % right eye
                    if ~isnan(posR(1))
                        drawEye(wpnt,rValid,posR,obj.settings.setup.eyeColors{2},round(sz*facR*gain),'R',boxRect);
                    end
                    Screen('TextStyle', wpnt, style);
                    % update relative eye positions - used for drawing estimated
                    % position of missing eye. X and Y are relative position in
                    % headbox, Z is difference in measured eye depths
                    if lValid && rValid
                        relPos = rEye-lEye;
                    end
                end
                % draw arrows
                for p=find(qDrawArrow)
                    Screen('FillPoly', wpnt, arrowColor(:,p), bsxfun(@plus,arrowsLRUDNF{p},arrowPos{p}+boxRect(1:2)) ,0);
                end
                % draw eye images, if any
                if qHasEyeIm
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
                % draw buttons
                Screen('FillRect',wpnt,[37  97 163],basicButRect);
                obj.drawCachedText(basicButTextCache);
                Screen('FillRect',wpnt,[ 0 120   0],calibButRect);
                obj.drawCachedText(calibButTextCache);
                if qHaveValidCalibrations
                    Screen('FillRect',wpnt,[150 150   0],validateButRect);
                    obj.drawCachedText(validateButTextCache);
                end
                % draw fixation points
                obj.drawFixPoints(wpnt,fixPos);
                
                % drawing done, show
                Screen('Flip',wpnt);
                
                % get user response
                [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],[basicButRect.' calibButRect.' validateButRect.']);
                    if any(qIn)
                        if qIn(1)
                            status = 5;
                            break;
                        elseif qIn(2)
                            status = 1;
                            break;
                        elseif qIn(3)
                            status = -3;
                            break;
                        end
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'b'))
                        status = 5;
                        break;
                    elseif any(strcmpi(keys,'space'))
                        status = 1;
                        break;
                    elseif any(strcmpi(keys,'p')) && qHaveValidCalibrations
                        status = -3;
                        break;
                    elseif any(strcmpi(keys,'escape')) && shiftIsDown
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && shiftIsDown
                        % skip calibration
                        status = 2;
                        break;
                    end
                end
            end
            % clean up
            if qHasEyeIm
                obj.stopRecording('eyeImage');
                obj.clearBufferTimeRange('eyeImage',eyeStartTime);  % from start time onward
                if any(texs)
                    Screen('Close',texs(texs>0));
                end
            end
            HideCursor;
        end
        
        function [cache,txtbounds] = getTextCache(obj,wpnt,text,rect,varargin)
            inputs.sx           = 0;
            inputs.xalign       = 'center';
            inputs.sy           = 0;
            inputs.yalign       = 'center';
            inputs.xlayout      = 'left';
            inputs.baseColor    = 0;
            if ~isempty(rect)
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
                    inputs.sy = inputs.sy + obj.settings.text.lineCentOff;
                end
                [~,~,txtbounds,cache] = DrawFormattedText2GDI(wpnt,text,inputs.sx,inputs.xalign,inputs.sy,inputs.yalign,inputs.xlayout,0,[],inputs.vSpacing,[],[],true);
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
        
        function drawFixPoints(obj,wpnt,pos)
            % draws Thaler et al. 2012's ABC fixation point
            sz = [obj.settings.cal.fixBackSize obj.settings.cal.fixFrontSize];
            
            % draw
            for p=1:size(pos,1)
                rectH = CenterRectOnPointd([0 0        sz ], pos(p,1), pos(p,2));
                rectV = CenterRectOnPointd([0 0 fliplr(sz)], pos(p,1), pos(p,2));
                Screen('gluDisk', wpnt,obj.settings.cal. fixBackColor, pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.settings.cal.fixFrontColor, rectH);
                Screen('FillRect',wpnt,obj.settings.cal.fixFrontColor, rectV);
                Screen('gluDisk', wpnt,obj.settings.cal. fixBackColor, pos(p,1), pos(p,2), sz(2)/2);
            end
        end
        
        function [status,out] = DoCalAndVal(obj,wpnt,kCal,calibClass)
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % NB: this sets the background color, because fullscreen fillrect sets new clear color in PTB
            
            % do calibration
            calStartT = obj.sendMessage(sprintf('CALIBRATION START %d',kCal));
            obj.startRecording('gaze');
            if obj.settings.cal.doRecordEyeImages && obj.hasCap(EyeTrackerCapabilities.HasEyeImages)
                obj.startRecording('eyeImage');
            end
            if obj.settings.cal.doRecordExtSignal && obj.hasCap(EyeTrackerCapabilities.HasExternalSignal)
                obj.startRecording('externalSignal');
            end
            obj.startRecording('timeSync');
            % show display
            [status,out.cal,tick] = obj.DoCalPointDisplay(wpnt,calibClass,-1);
            obj.sendMessage(sprintf('CALIBRATION END %d',kCal));
            out.cal.data = obj.ConsumeAllData(calStartT);
            if status==1
                % compute calibration
                out.cal.result = fixupTobiiCalResult(calibClass.compute_and_apply(),obj.calibrateLeftEye,obj.calibrateRightEye);
            end
            
            % if valid calibration retrieve data, so user can select different ones
            if status==1
                if strcmp(out.cal.result.status(1:7),'Success') % 1:7 so e.g. SuccessLeftEye is also supported
                    out.cal.computedCal = obj.eyetracker.retrieve_calibration_data();
                else
                    % calibration failed, back to setup screen
                    status = -2;
                    DrawFormattedText(wpnt,'Calibration failed\nPress any key to continue','center','center',obj.settings.text.color);
                    Screen('Flip',wpnt);
                    obj.getNewMouseKeyPress();
                    keyCode = false;
                    while ~any(keyCode)
                        [~,~,~,keyCode] = obj.getNewMouseKeyPress();
                    end
                end
            end
            
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
                        obj.settings.cal.drawFunction(nan);
                    end
                    Screen('Flip',wpnt);
                end
                return;
            end
            
            % do validation
            valStartT = obj.sendMessage(sprintf('VALIDATION START %d',kCal));
            obj.ClearAllBuffers(calStartT);    % clean up data
            % show display
            [status,out.val] = obj.DoCalPointDisplay(wpnt,[],tick,out.cal.flips(end));
            obj.sendMessage(sprintf('VALIDATION END %d',kCal));
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
                    obj.settings.cal.drawFunction(nan);
                end
            end
            
            % clear flip
            Screen('Flip',wpnt);
        end
        
        function data = ConsumeAllData(obj,varargin)
            data.gaze           = obj.consumeTimeRange('gaze',varargin{:});
            data.eyeImages      = obj.consumeTimeRange('eyeImage',varargin{:});
            data.externalSignals= obj.consumeTimeRange('externalSignal',varargin{:});
            data.timeSync       = obj.consumeTimeRange('timeSync',varargin{:});
        end
        
        function data = consumeOrPeek(obj,stream,action,varargin)
            stream = getInternalStreamName(stream,action);
            data = obj.buffers.(action)(stream,varargin{:});
        end
        
        function clearImpl(obj,stream,action,varargin)
            stream = getInternalStreamName(stream,action);
            obj.buffers.(action)(stream,varargin{:});
        end
        
        function ClearAllBuffers(obj,varargin)
            obj.buffers.clearTimeRange('sample',varargin{:});
            obj.buffers.clearTimeRange('eyeImage',varargin{:});
            obj.buffers.clearTimeRange('extSignal',varargin{:});
            obj.buffers.clearTimeRange('timeSync',varargin{:});
        end
        
        function StopRecordAll(obj)
            obj.stopRecording('gaze');
            obj.stopRecording('eyeImage');
            obj.stopRecording('externalSignal');
            obj.stopRecording('timeSync');
        end
        
        function [status,out,tick] = DoCalPointDisplay(obj,wpnt,calibClass,tick,lastFlip)
            % status output:
            %  1: finished succesfully (you should query Tobii SDK whether
            %     they agree that calibration was succesful though)
            %  2: skip calibration and continue with task (shift+s)
            % -1: restart calibration (r)
            % -2: abort calibration and go back to setup (escape key)
            % -4: Exit completely (control+escape)
            qFirst = nargin<5;
            qCal   = ~isempty(calibClass);
            
            % setup
            if qCal
                points          = obj.settings.cal.pointPos;
                paceInterval    = ceil(obj.settings.cal.paceDuration   *Screen('NominalFrameRate',wpnt));
                out.status      = [];
                switch obj.settings.calibrateEye
                    case 'both'
                        extraInp = {};
                    case 'left'
                        extraInp = {SelectedEye.LEFT};
                    case 'right'
                        extraInp = {SelectedEye.RIGHT};
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
            points = [points bsxfun(@times,points,obj.scrInfo.resolution) [1:nPoint].' ones(nPoint,1)]; %#ok<NBRAK>
            if (qCal && obj.settings.cal.qRandPoints) || (~qCal && obj.settings.val.qRandPoints)
                points = points(randperm(nPoint),:);
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
            needManualAccept= @(cp) obj.settings.cal.autoPace==0 || (obj.settings.cal.autoPace==1 && qCal && cp==1);
            advancePoint    = true;
            pointOff        = 0;
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
                    qNewPoint = false;
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
                            status = -4;
                        else
                            status = -2;
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
                        collect_result = calibClass.collect_data(points(currentPoint,1:2),extraInp{:});
                        % if fails, retry immediately
                        if collect_result.value==CalibrationStatus.Failure
                            collect_result = calibClass.collect_data(points(currentPoint,1:2),extraInp{:});
                        end
                        out.status(currentPoint,1) = collect_result.value;
                        % if still fails, retry one more time at end of
                        % point sequence (if this is not already a retried
                        % point)
                        if collect_result.value==CalibrationStatus.Failure && points(currentPoint,6)
                            points = [points; points(currentPoint,:)]; %#ok<AGROW>
                            points(end,6) = 0;  % indicate this is a point that is being retried so we don't try forever
                        end
                        
                        % next point
                        advancePoint = true;
                    else
                        if isnan(tick0v)
                            tick0v = tick;
                        end
                        if tick>tick0v+collectInterval
                            dat = obj.peekN('gaze',nDataPoint);
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
            obj.sendMessage(sprintf('POINT OFF %d',currentPoint-pointOff),out.flips(end));
        end
        
        function qAllowAcceptKey = drawFixationPointDefault(obj,wpnt,~,pos,~)
            obj.drawFixPoints(wpnt,pos);
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
            for f={'acc','RMS2D','STD2D','trackRatio'}
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
            
            % 2. RMS
            out.RMS     = sqrt(mean(diff(out.offs,[],2).^2,2,'omitnan'));
            out.RMS2D   = hypot(out.RMS(1),out.RMS(2));
            
            % 3. STD
            out.STD     = std(out.offs,[],2,'omitnan');
            out.STD2D   = hypot(out.STD(1),out.STD(2));
            
            % 4. track ratio
            out.trackRatio  = sum(gazeData.gazePoint.valid)/length(gazeData.gazePoint.valid);
        end
        
        function out = ADCSToUCS(obj,data)
            % data is a 2xN matrix of normalized coordinates
            xVec = obj.geom.displayArea.top_right-obj.geom.displayArea.top_left;
            yVec = obj.geom.displayArea.bottom_right-obj.geom.displayArea.top_right;
            out  = bsxfun(@plus,obj.geom.displayArea.top_left,bsxfun(@times,data(1,:),xVec)+bsxfun(@times,data(2,:),yVec));
        end
        
        function [status,selection] = showCalValResult(obj,wpnt,cal,selection)
            % status output:
            %  1: calibration/validation accepted, continue (a)
            %  2: just continue with task (shift+s)
            % -1: restart calibration (escape key)
            % -2: go back to setup (s)
            % -4: exit completely (control+escape)
            %
            % additional buttons
            % c: chose other calibration (if have more than one valid)
            % g: show gaze (and fixation points)
            % t: toggle between seeing validation results and calibration
            %    result
            
            % find how many valid calibrations we have:
            iValid = getValidCalibrations(cal);
            if ~ismember(selection,iValid)
                % this happens if setup cancelled to go directly to this validation
                % viewer
                selection = iValid(end);
            end
            qHaveMultipleValidCals = ~isscalar(iValid);
            
            % set up box representing screen
            scale       = .8;
            boxRect     = CenterRectOnPoint([0 0 obj.scrInfo.resolution*scale],obj.scrInfo.center(1),obj.scrInfo.center(2));
            boxRect     = OffsetRect(boxRect,0,20);
            [brw,brh]   = RectSize(boxRect);
            
            % set up buttons
            % 1. below screen
            yPosMid     = boxRect(4)+(obj.scrInfo.resolution(2)-boxRect(4))/2;
            buttonSz    = [300 45; 300 45; 350 45];
            buttonSz    = buttonSz(1:2+qHaveMultipleValidCals,:);   % third button only when more than one calibration available
            buttonOff   = 80;
            totWidth    = sum(buttonSz(:,1))+(size(buttonSz,1)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonSz(:,1).']+[0 ones(1,size(buttonSz,1))]*buttonOff)-totWidth/2;
            recalButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz(1,2)],obj.scrInfo.center(1),yPosMid-buttonSz(1,2)/2);
            recalButTextCache   = obj.getTextCache(wpnt,'recalibrate (<i>esc<i>)'  ,    recalButRect);
            continueButRect     = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz(2,2)],obj.scrInfo.center(1),yPosMid-buttonSz(2,2)/2);
            continueButTextCache= obj.getTextCache(wpnt,'continue (<i>spacebar<i>)', continueButRect);
            if qHaveMultipleValidCals
                selectButRect       = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz(3,2)],obj.scrInfo.center(1),yPosMid-buttonSz(3,2)/2);
                selectButTextCache  = obj.getTextCache(wpnt,'select other cal (<i>c<i>)', selectButRect);
            else
                selectButRect = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            % 2. atop screen
            yPosMid             = boxRect(2)/2;
            buttonSz            = [200 45; 250 45];
            buttonOff           = 750;
            showGazeButClrs     = {[37  97 163],[11 122 244]};
            setupButRect        = OffsetRect([0 0 buttonSz(1,:)],obj.scrInfo.center(1)-buttonOff/2-buttonSz(1,1),yPosMid-buttonSz(1,2)/2);
            setupButTextCache   = obj.getTextCache(wpnt,'setup (<i>s<i>)'    ,   setupButRect);
            showGazeButRect     = OffsetRect([0 0 buttonSz(2,:)],obj.scrInfo.center(1)+buttonOff/2              ,yPosMid-buttonSz(2,2)/2);
            showGazeButTextCache= obj.getTextCache(wpnt,'show gaze (<i>g<i>)',showGazeButRect);
            % 3. left side
            yPosTop             = boxRect(2);
            buttonSz            = [boxRect(1) 45];
            toggleCVButClr      = [37  97 163];
            toggleCVButRect     = OffsetRect([0 0 buttonSz],0,yPosTop);
            toggleCVButTextCache= {obj.getTextCache(wpnt,'show cal (<i>t<i>)',toggleCVButRect), obj.getTextCache(wpnt,'show val (<i>t<i>)',toggleCVButRect)};
            
            
            % setup menu, if any
            if qHaveMultipleValidCals
                margin      = 10;
                pad         = 3;
                height      = 45;
                nElem       = length(iValid);
                totHeight   = nElem*(height+pad)-pad;
                width       = 700;
                % menu background
                menuBackRect= [-.5*width+obj.scrInfo.center(1)-margin -.5*totHeight+obj.scrInfo.center(2)-margin .5*width+obj.scrInfo.center(1)+margin .5*totHeight+obj.scrInfo.center(2)+margin];
                % menuRects
                menuRects = repmat([-.5*width+obj.scrInfo.center(1) -height/2+obj.scrInfo.center(2) .5*width+obj.scrInfo.center(1) height/2+obj.scrInfo.center(2)],length(iValid),1);
                menuRects = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                % text in each rect
                for c=length(iValid):-1:1
                    % acc field is [lx rx; ly ry]
                    [strl,strr,strsep] = deal('');
                    if obj.calibrateLeftEye
                        strl = sprintf('<color=%s>Left<color>: (%.2f°,%.2f°)',obj.settings.setup.eyeColorsHex{1},cal{iValid(c)}.val.acc(:,1));
                    end
                    if obj.calibrateRightEye
                        strr = sprintf('<color=%s>Right<color>: (%.2f°,%.2f°)',obj.settings.setup.eyeColorsHex{2},cal{iValid(c)}.val.acc(:,2));
                    end
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        strsep = ', ';
                    end
                    str = sprintf('(%d): %s%s%s',c,strl,strsep,strr);
                    menuTextCache(c) = obj.getTextCache(wpnt,str,menuRects(c,:));
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution,4,1);
            
            qDoneCalibSelection = false;
            qToggleSelectMenu   = true;
            qSelectMenuOpen     = true;     % gets set to false on first draw as toggle above is true (hack to make sure we're set up on first entrance of draw loop)
            qToggleGaze         = false;
            qShowGaze           = false;
            qUpdateCalDisplay   = true;
            qSelectedCalChanged = false;
            qShowCal            = false;
            fixPointRectSz      = 100;
            openInfoForPoint    = nan;
            pointToShowInfoFor  = nan;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            [mx,my] = obj.getNewMouseKeyPress();
            while ~qDoneCalibSelection
                % toggle gaze on or off if requested
                if qToggleGaze
                    if qShowGaze
                        % switch off
                        obj.stopRecording('gaze');
                        obj.clearBufferTimeRange('gaze',gazeStartT);
                    else
                        % switch on
                        gazeStartT = obj.getSystemTime();
                        obj.startRecording('gaze');
                    end
                    qShowGaze   = ~qShowGaze;
                    qToggleGaze = false;
                end
                
                % setup cursors
                if qToggleSelectMenu
                    qSelectMenuOpen     = ~qSelectMenuOpen;
                    qToggleSelectMenu   = false;
                    if qSelectMenuOpen
                        cursors.rect    = {menuRects.',continueButRect.',recalButRect.'};
                        cursors.cursor  = 2*ones(1,size(menuRects,1)+2);    % 2: Hand
                        % setup indicator which calibration is active
                        rect = menuRects(selection==iValid,:);
                        rect(3) = rect(1)+RectWidth(rect)*.07;
                        menuActiveCache = obj.getTextCache(wpnt,' <color=ff0000>-><color>',rect);
                    else
                        cursors.rect    = {continueButRect.',recalButRect.',selectButRect.',setupButRect.',showGazeButRect.',toggleCVButRect.'};
                        cursors.cursor  = [2 2 2 2 2 2];  % 2: Hand
                    end
                    cursors.other   = 0;    % 0: Arrow
                    cursors.qReset  = false;
                    % NB: don't reset cursor to invisible here as it will then flicker every
                    % time you click something. default behaviour is good here
                    cursor = cursorUpdater(cursors);
                end
                
                % setup fixation point positions for cal or val
                if qUpdateCalDisplay || qSelectedCalChanged
                    if qSelectedCalChanged
                        % load requested cal
                        DrawFormattedText(wpnt,'Loading calibration...','center','center',0);
                        Screen('Flip',wpnt);
                        obj.loadOtherCal(cal{selection});
                        qSelectedCalChanged = false;
                    end
                    % update info text
                    % acc field is [lx rx; ly ry]
                    % text only changes when calibration selection changes,
                    % but putting these lines in the above if makes logic
                    % more complicated. Now we regenerate the same text
                    % when switching between viewing calibration and
                    % validation output, thats an unimportant price to pay
                    % for simpler logic
                    [strl,strr,strsep] = deal('');
                    if obj.calibrateLeftEye
                        strl = sprintf('  <color=%s>Left eye<color>:   (%.2f°,%.2f°)  %.2f°  %.2f°  %3.0f%%',obj.settings.setup.eyeColorsHex{1},cal{selection}.val.acc(:, 1 ),cal{selection}.val.STD2D( 1 ),cal{selection}.val.RMS2D( 1 ),cal{selection}.val.trackRatio( 1 )*100);
                    end
                    if obj.calibrateRightEye
                        idx = 1+obj.calibrateLeftEye;
                        strr = sprintf(' <color=%s>Right eye<color>:   (%.2f°,%.2f°)  %.2f°  %.2f°  %3.0f%%',obj.settings.setup.eyeColorsHex{2},cal{selection}.val.acc(:,idx),cal{selection}.val.STD2D(idx),cal{selection}.val.RMS2D(idx),cal{selection}.val.trackRatio(idx)*100);
                    end
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        strsep = '\n';
                    end
                    valText = sprintf('<font=Consolas><size=%d><u>Validation<u>   accuracy (X,Y)   SD     RMS  track\n%s%s%s',obj.settings.text.size,strl,strsep,strr);
                    valInfoTopTextCache = obj.getTextCache(wpnt,valText,CenterRectOnPoint([0 0 10 10],obj.scrInfo.resolution(1)/2,boxRect(2)/2),'vSpacing',obj.settings.text.vSpacing,'xlayout','left');
                    
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
                            calValPos(p,:)  = cal{selection}.cal.result.gazeData(p).calPos.'.*[brw brh]+boxRect(1:2);
                        end
                    else
                        for p=1:nPoints
                            calValPos(p,:)  = cal{selection}.val.pointPos(p,2:3)./obj.scrInfo.resolution.*[brw brh]+boxRect(1:2);
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
                    calValLblCache      = obj.getTextCache(wpnt,sprintf('showing %s',lbl),[],'sx',boxRect(1),'sy',boxRect(2)-3,'xalign','left','yalign','bottom');
                end
                
                % setup overlay with data quality info for specific point
                if ~isnan(openInfoForPoint)
                    pointToShowInfoFor = openInfoForPoint;
                    openInfoForPoint   = nan;
                    % 1. prepare text
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        lE = cal{selection}.val.quality(pointToShowInfoFor).left;
                        rE = cal{selection}.val.quality(pointToShowInfoFor).right;
                        str = sprintf('Accuracy:     <color=%1$s>(%3$.2f°,%4$.2f°)<color>, <color=%2$s>(%8$.2f°,%9$.2f°)<color>\nPrecision SD:     <color=%1$s>%5$.2f°<color>          <color=%2$s>%10$.2f°<color>\nPrecision RMS:    <color=%1$s>%6$.2f°<color>          <color=%2$s>%11$.2f°<color>\nTrack ratio:      <color=%1$s>%7$3.0f%%<color>           <color=%2$s>%12$3.0f%%<color>',obj.settings.setup.eyeColorsHex{:},abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.trackRatio*100,abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.trackRatio*100);
                    elseif obj.calibrateLeftEye
                        lE = cal{selection}.val.quality(pointToShowInfoFor).left;
                        str = sprintf('Accuracy:     <color=%1$s>(%3$.2f°,%4$.2f°)<color>\nPrecision SD:     <color=%1$s>%5$.2f°<color>\nPrecision RMS:    <color=%1$s>%6$.2f°<color>\nTrack ratio:      <color=%1$s>%7$3.0f%%<color>',obj.settings.setup.eyeColorsHex{:},abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.trackRatio*100);
                    elseif obj.calibrateRightEye
                        rE = cal{selection}.val.quality(pointToShowInfoFor).right;
                        str = sprintf('Accuracy:     <color=%2$s>(%3$.2f°,%4$.2f°)<color>\nPrecision SD:     <color=%2$s>%5$.2f°<color>\nPrecision RMS:    <color=%2$s>%6$.2f°<color>\nTrack ratio:      <color=%2$s>%7$3.0f%%<color>',obj.settings.setup.eyeColorsHex{:},abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.trackRatio*100);
                    end
                    [pointTextCache,txtbounds] = obj.getTextCache(wpnt,str,[],'xlayout','left');
                    % get box around text
                    margin = 10;
                    infoBoxRect = GrowRect(txtbounds,margin,margin);
                    infoBoxRect = OffsetRect(infoBoxRect,-infoBoxRect(1),-infoBoxRect(2));  % make sure rect is [0 0 w h]
                end
                
                while true % draw loop
                    % draw validation screen image
                    % draw box
                    Screen('FillRect',wpnt,80,boxRect);
                    % draw calibration points
                    obj.drawFixPoints(wpnt,calValPos);
                    % draw captured data in characteristic tobii plot
                    for p=1:nPoints
                        if qShowCal
                            myCal = cal{selection}.cal.result;
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = strcmp(myCal.gazeData(p).left.validity,'ValidAndUsed');
                                lEpos= bsxfun(@plus,bsxfun(@times,myCal.gazeData(p). left.pos(:,qVal),[brw brh].'),boxRect(1:2).');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = strcmp(myCal.gazeData(p).right.validity,'ValidAndUsed');
                                rEpos= bsxfun(@plus,bsxfun(@times,myCal.gazeData(p).right.pos(:,qVal),[brw brh].'),boxRect(1:2).');
                            end
                        else
                            myVal = cal{selection}.val;
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = myVal.gazeData(p). left.gazePoint.valid;
                                lEpos= bsxfun(@plus,bsxfun(@times,myVal.gazeData(p). left.gazePoint.onDisplayArea(:,qVal),[brw brh].'),boxRect(1:2).');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = myVal.gazeData(p).right.gazePoint.valid;
                                rEpos= bsxfun(@plus,bsxfun(@times,myVal.gazeData(p).right.gazePoint.onDisplayArea(:,qVal),[brw brh].'),boxRect(1:2).');
                            end
                        end
                        if obj.calibrateLeftEye  && ~isempty(lEpos)
                            Screen('DrawLines',wpnt,reshape([repmat(bpos,1,size(lEpos,2)); lEpos],2,[]),1,obj.settings.setup.eyeColors{1},[],2);
                        end
                        if obj.calibrateRightEye && ~isempty(rEpos)
                            Screen('DrawLines',wpnt,reshape([repmat(bpos,1,size(rEpos,2)); rEpos],2,[]),1,obj.settings.setup.eyeColors{2},[],2);
                        end
                    end
                    
                    % setup text
                    Screen('TextFont',  wpnt, obj.settings.text.font);
                    Screen('TextSize',  wpnt, obj.settings.text.size);
                    Screen('TextStyle', wpnt, obj.settings.text.style);
                    % draw text with validation accuracy etc info
                    obj.drawCachedText(valInfoTopTextCache);
                    % draw text indicating whether calibration or
                    % validation is currently shown
                    obj.drawCachedText(calValLblCache);
                    % draw buttons
                    Screen('FillRect',wpnt,[150 0 0],recalButRect);
                    obj.drawCachedText(recalButTextCache);
                    Screen('FillRect',wpnt,[0 120 0],continueButRect);
                    obj.drawCachedText(continueButTextCache);
                    if qHaveMultipleValidCals
                        Screen('FillRect',wpnt,[150 150 0],selectButRect);
                        obj.drawCachedText(selectButTextCache);
                    end
                    Screen('FillRect',wpnt,[150 0 0],setupButRect);
                    obj.drawCachedText(setupButTextCache);
                    Screen('FillRect',wpnt,showGazeButClrs{qShowGaze+1},showGazeButRect);
                    obj.drawCachedText(showGazeButTextCache);
                    Screen('FillRect',wpnt,toggleCVButClr,toggleCVButRect);
                    obj.drawCachedText(toggleCVButTextCache{qShowCal+1});
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt,140,menuBackRect);
                        % menuRects
                        Screen('FillRect',wpnt,110,menuRects.');
                        % text in each rect
                        for c=1:length(iValid)
                            obj.drawCachedText(menuTextCache(c));
                        end
                        obj.drawCachedText(menuActiveCache);
                    end
                    % if hovering over validation point, show info
                    if ~isnan(pointToShowInfoFor)
                        rect = OffsetRect(infoBoxRect,mx,my);
                        Screen('FillRect',wpnt,110,rect);
                        obj.drawCachedText(pointTextCache,rect);
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        % draw fixation points
                        obj.drawFixPoints(wpnt,fixPos);
                        % draw gaze data
                        eyeData = obj.buffers.consumeN('sample');
                        if ~isempty(eyeData.systemTimeStamp)
                            lE = eyeData. left.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution.';
                            rE = eyeData.right.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution.';
                            if obj.calibrateLeftEye  && eyeData. left.gazePoint.valid(end)
                                Screen('gluDisk', wpnt,obj.settings.setup.eyeColors{1}, lE(1), lE(2), 10);
                            end
                            if obj.calibrateRightEye && eyeData.right.gazePoint.valid(end)
                                Screen('gluDisk', wpnt,obj.settings.setup.eyeColors{2}, rE(1), rE(2), 10);
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
                            qIn = inRect([mx my],[continueButRect.' recalButRect.' selectButRect.' setupButRect.' showGazeButRect.' toggleCVButRect.']);
                            if any(qIn)
                                if qIn(1)
                                    status = 1;
                                    qDoneCalibSelection = true;
                                elseif qIn(2)
                                    status = -1;
                                    qDoneCalibSelection = true;
                                elseif qIn(3)
                                    qToggleSelectMenu   = true;
                                elseif qIn(4)
                                    status = -2;
                                    qDoneCalibSelection = true;
                                elseif qIn(5)
                                    qToggleGaze         = true;
                                elseif qIn(6)
                                    qUpdateCalDisplay   = true;
                                    qShowCal            = ~qShowCal;
                                end
                                break;
                            end
                        end
                    elseif any(keyCode)
                        keys = KbName(keyCode);
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape'))
                                qToggleSelectMenu = true;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                idx                 = iValid(str2double(keys(1)));
                                qSelectedCalChanged = selection~=idx;
                                selection           = idx;
                                qToggleSelectMenu   = true;
                                break;
                            end
                        else
                            if any(strcmpi(keys,'space'))
                                status = 1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'escape')) && ~shiftIsDown
                                status = -1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'s')) && ~shiftIsDown
                                status = -2;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'c')) && qHaveMultipleValidCals
                                qToggleSelectMenu   = true;
                                break;
                            elseif any(strcmpi(keys,'g'))
                                qToggleGaze         = true;
                                break;
                            elseif any(strcmpi(keys,'t'))
                                qUpdateCalDisplay   = true;
                                qShowCal            = ~qShowCal;
                                break;
                            end
                        end
                        
                        % these two key combinations should always be available
                        if any(strcmpi(keys,'escape')) && shiftIsDown
                            status = -4;
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
            if status~=1
                selection = NaN;
            end
            if qShowGaze
                % if showing gaze, switch off gaze data stream
                obj.stopRecording('gaze');
                obj.clearBufferTimeRange('gaze',gazeStartT);
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
    end
end



%%% helpers
function angle = AngleBetweenVectors(a,b)
angle = atan2(sqrt(sum(cross(a,b,1).^2,1)),dot(a,b,1))*180/pi;
end

function iValid = getValidCalibrations(cal)
iValid = find(cellfun(@(x) isfield(x,'calStatus') && x.calStatus==1 && strcmp(x.cal.result.status(1:7),'Success'),cal));
end

function result = fixupTobiiCalResult(calResult,hasLeft,hasRight)
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

function enumLbl = TobiiEnumToString(enum)
% turn off warning for converting object to struct
warnState = warning('query','MATLAB:structOnObject');
warning('off',warnState.identifier);

names = fieldnames(enum);
values= struct2cell(struct(enum(1)));
qRem = cellfun(@(x) strcmp(x,'value'),names);
names (qRem,:) = [];
values(qRem,:) = []; values = cat(1,values{:});
% store what the result status was
if isobject(enum(1).value)
    enumLbl = arrayfun(@(x) names{values==x.value.value},enum,'uni',false);
else
    enumLbl = arrayfun(@(x) names{values==x.value}      ,enum,'uni',false);
end
if isscalar(enumLbl)
    enumLbl = enumLbl{1};
end

% reset warning
warning(warnState.state,warnState.identifier);
end

function hsv = rgb2hsv(rgb)
% takes 0-255 rgb values, outputs 0-1 hsv values
% code from Octave
rgb = rgb/255;
s = min(rgb,[],2);
v = max(rgb,[],2);

% set hue to zero for undefined values (gray has no hue)
h = zeros(size(v));
notgray = (s ~= v);

% blue hue
idx = (v == rgb(:,3) & notgray);
if (any (idx))
    h(idx) = 2/3 + 1/6 * (rgb(idx,1) - rgb(idx,2)) ./ (v(idx) - s(idx));
end

% green hue
idx = (v == rgb(:,2) & notgray);
if (any (idx))
    h(idx) = 1/3 + 1/6 * (rgb(idx,3) - rgb(idx,1)) ./ (v(idx) - s(idx));
end

% red hue
idx = (v == rgb(:,1) & notgray);
if (any (idx))
    h(idx) =       1/6 * (rgb(idx,2) - rgb(idx,3)) ./ (v(idx) - s(idx));
end

% correct for negative red
idx = (h < 0);
h(idx) = 1+h(idx);

% set the saturation
s(~notgray) = 0;
s(notgray) = 1 - s(notgray) ./ v(notgray);

hsv = [h s v];
end


function rgb = hsv2rgb(hsv)
% takes 0-1 hsv values, outputs 0-255 rgb values
% code from Octave
% Prefill rgb map with v*(1-s)
rgb = repmat (hsv(:,3) .* (1 - hsv(:,2)), 1, 3);

% red = hue-2/3 : green = hue : blue = hue-1/3
% Apply modulo 1 for red and blue to keep within range [0, 1]
hue = [mod(hsv(:,1) - 2/3, 1), hsv(:,1) , mod(hsv(:,1) - 1/3, 1)];

% factor s*v -> f
f = repmat(hsv(:,2) .* hsv(:,3), 1, 3);

% add s*v*hue-function to rgb map
rgb = rgb + ...
    f .* (6 * (hue < 1/6) .* hue ...
    + (hue >= 1/6 & hue < 1/2) ...
    + (hue >= 1/2 & hue < 2/3) .* (4 - 6 * hue));

rgb = round(rgb*255);
end
        
function drawEye(wpnt,valid,pos,clr,sz,lbl,boxRect)
if ~valid
    hsv = rgb2hsv(clr(1:3));
    clr = [hsv2rgb([hsv(:,1) hsv(:,2)/2 hsv(:,3)]) clr(4)];
end
pos = pos.*[diff(boxRect([1 3])) diff(boxRect([2 4]))]+boxRect(1:2);
Screen('gluDisk',wpnt,clr,pos(1),pos(2),sz)
if valid
    bbox = Screen('TextBounds',wpnt,lbl);
    pos  = round(pos-bbox(3:4)/2);
    Screen('DrawText',wpnt,lbl,pos(1),pos(2),255);
end
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

function arrowColor = getArrowColor(posRating,thresh,col1,col2,col3)
if abs(posRating)>thresh(2)
    arrowColor = col3;
else
    arrowColor = col1+(abs(posRating)-thresh(1))./diff(thresh)*(col2-col1);
end
end

function fieldString = getStructFields(defaults)
values                  = struct2cell(defaults);
qSubStruct              = cellfun(@isstruct,values);
fieldInfo               = fieldnames(defaults);
fieldInfoSub            = fieldInfo(qSubStruct);
fieldInfo(qSubStruct)   = [];
fieldInfo               = [fieldInfo repmat({''},size(fieldInfo))];
for p=1:length(fieldInfoSub)
    fields      = fieldnames(defaults.(fieldInfoSub{p}));
    fieldInfo   = [fieldInfo; [repmat(fieldInfoSub(p),size(fields)) fields]]; %#ok<AGROW>
end
% turn into string
fieldString = fieldInfo(:,1);
for i=1:size(fieldInfo,1)
    if ~isempty(fieldInfo{i,2})
        fieldString{i} = [fieldString{i} '.' fieldInfo{i,2}];
    end
end
end

function stream = getInternalStreamName(stream,action)
fields = {'gaze','eyeImage','externalSignal','timeSync'};
q = strcmpi(stream,fields);
assert(any(q),'Titta: %sData: stream ''%s'' not known',action,stream);

get     = {'sample','eyeImage','extSignal','timeSync'};
stream  = get{q};
end