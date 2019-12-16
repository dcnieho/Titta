% Titta is a toolbox providing convenient access to eye tracking
% functionality using Tobii eye trackers 
%
% Titta can be found at https://github.com/dcnieho/Titta. Check there for
% the latest version.
% When using Titta, please cite the following paper:
% Niehorster, D.C., Andersson, R. & Nystr�m, M., (in prep). Titta: A
% toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
% trackers.

classdef Titta < handle
    properties (Access = protected, Hidden = true)
        % message buffer
        msgs;
        
        % state
        isInitialized       = false;
        usingFTGLTextRenderer;
        keyState;
        mouseState;
        qFloatColorRange;
        calibrateLeftEye    = true;
        calibrateRightEye   = true;
        wpnts;
        
        % settings and external info
        settings;
        scrInfo;
    end
    
    properties (SetAccess=protected)
        geom;
        calibrateHistory;
        buffer;
    end
    
    properties (Dependent, SetAccess=private)
        systemInfo  % struct with all the below properties in it, for easy copying
        
        deviceName
        serialNumber
        model
        firmwareVersion
        runtimeVersion
        address
        capabilities
        supportedFrequencies
        supportedModes
    end
    properties (Dependent)
        frequency
        trackingMode
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
        
        function out = getOptions(obj)
            out = obj.settings;
            if ~obj.isInitialized
                % no-op, return all settings
            else
                % return only the subset that can be changed "live"
                remOpts = obj.getDisAllowedOptions();
                for p=1:numel(remOpts)
                    out = rmfield(out,remOpts{p});
                end
            end
        end
        
        function setOptions(obj,settings)
            % special handling of changes to frequency and tracking mode
            if isfield(settings,'freq') && isfield(obj.settings,'freq') && settings.freq ~= obj.settings.freq
                obj.frequency = settings.freq;
            end
            if isfield(settings,'trackingMode') && isfield(obj.settings,'trackingMode') && ~strcmp(settings.trackingMode,obj.settings.trackingMode)
                obj.trackingMode = settings.trackingMode;
            end
            if obj.isInitialized
                % only a subset of settings is allowed. Overwrite those
                % that are not allowed to be changed so that we are certain
                % they do exist in the input and have not been tampered
                % with
                cantTouch = obj.getDisAllowedOptions();
                for p=1:numel(cantTouch)
                    settings.(cantTouch{p}) = obj.settings.(cantTouch{p});
                end
                
                obj.settings = settings;
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
            obj.settings.UI.setup.refCircleClr          = color2RGBA(obj.settings.UI.setup.refCircleClr);
            obj.settings.UI.setup.headCircleEdgeClr     = color2RGBA(obj.settings.UI.setup.headCircleEdgeClr);
            obj.settings.UI.setup.headCircleFillClr     = color2RGBA(obj.settings.UI.setup.headCircleFillClr);
            obj.settings.UI.setup.eyeClr                = color2RGBA(obj.settings.UI.setup.eyeClr);
            obj.settings.UI.setup.pupilClr              = color2RGBA(obj.settings.UI.setup.pupilClr);
            obj.settings.UI.setup.crossClr              = color2RGBA(obj.settings.UI.setup.crossClr);
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
            obj.settings.UI.val.waitMsg.color           = color2RGBA(obj.settings.UI.val.waitMsg.color);
            obj.settings.UI.val.hover.bgColor           = color2RGBA(obj.settings.UI.val.hover.bgColor);
            obj.settings.UI.val.hover.text.color        = color2RGBA(obj.settings.UI.val.hover.text.color);
            obj.settings.UI.val.menu.bgColor            = color2RGBA(obj.settings.UI.val.menu.bgColor);
            obj.settings.UI.val.menu.itemColor          = color2RGBA(obj.settings.UI.val.menu.itemColor);
            obj.settings.UI.val.menu.itemColorActive    = color2RGBA(obj.settings.UI.val.menu.itemColorActive);
            obj.settings.UI.val.menu.text.color         = color2RGBA(obj.settings.UI.val.menu.text.color);
            obj.settings.cal.bgColor                    = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor               = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor              = color2RGBA(obj.settings.cal.fixFrontColor);
            
            obj.settings.UI.button.setup.eyeIm.fillColor    = color2RGBA(obj.settings.UI.button.setup.eyeIm.fillColor);
            obj.settings.UI.button.setup.eyeIm.edgeColor    = color2RGBA(obj.settings.UI.button.setup.eyeIm.edgeColor);
            obj.settings.UI.button.setup.eyeIm.textColor    = color2RGBA(obj.settings.UI.button.setup.eyeIm.textColor);
            obj.settings.UI.button.setup.cal.fillColor      = color2RGBA(obj.settings.UI.button.setup.cal.fillColor);
            obj.settings.UI.button.setup.cal.edgeColor      = color2RGBA(obj.settings.UI.button.setup.cal.edgeColor);
            obj.settings.UI.button.setup.cal.textColor      = color2RGBA(obj.settings.UI.button.setup.cal.textColor);
            obj.settings.UI.button.setup.prevcal.fillColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.fillColor);
            obj.settings.UI.button.setup.prevcal.edgeColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.edgeColor);
            obj.settings.UI.button.setup.prevcal.textColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.textColor);
            obj.settings.UI.button.val.recal.fillColor      = color2RGBA(obj.settings.UI.button.val.recal.fillColor);
            obj.settings.UI.button.val.recal.edgeColor      = color2RGBA(obj.settings.UI.button.val.recal.edgeColor);
            obj.settings.UI.button.val.recal.textColor      = color2RGBA(obj.settings.UI.button.val.recal.textColor);
            obj.settings.UI.button.val.reval.fillColor      = color2RGBA(obj.settings.UI.button.val.reval.fillColor);
            obj.settings.UI.button.val.reval.edgeColor      = color2RGBA(obj.settings.UI.button.val.reval.edgeColor);
            obj.settings.UI.button.val.reval.textColor      = color2RGBA(obj.settings.UI.button.val.reval.textColor);
            obj.settings.UI.button.val.continue.fillColor   = color2RGBA(obj.settings.UI.button.val.continue.fillColor);
            obj.settings.UI.button.val.continue.edgeColor   = color2RGBA(obj.settings.UI.button.val.continue.edgeColor);
            obj.settings.UI.button.val.continue.textColor   = color2RGBA(obj.settings.UI.button.val.continue.textColor);
            obj.settings.UI.button.val.selcal.fillColor     = color2RGBA(obj.settings.UI.button.val.selcal.fillColor);
            obj.settings.UI.button.val.selcal.edgeColor     = color2RGBA(obj.settings.UI.button.val.selcal.edgeColor);
            obj.settings.UI.button.val.selcal.textColor     = color2RGBA(obj.settings.UI.button.val.selcal.textColor);
            obj.settings.UI.button.val.setup.fillColor      = color2RGBA(obj.settings.UI.button.val.setup.fillColor);
            obj.settings.UI.button.val.setup.edgeColor      = color2RGBA(obj.settings.UI.button.val.setup.edgeColor);
            obj.settings.UI.button.val.setup.textColor      = color2RGBA(obj.settings.UI.button.val.setup.textColor);
            obj.settings.UI.button.val.toggGaze.fillColor   = color2RGBA(obj.settings.UI.button.val.toggGaze.fillColor);
            obj.settings.UI.button.val.toggGaze.edgeColor   = color2RGBA(obj.settings.UI.button.val.toggGaze.edgeColor);
            obj.settings.UI.button.val.toggGaze.textColor   = color2RGBA(obj.settings.UI.button.val.toggGaze.textColor);
            obj.settings.UI.button.val.toggCal.fillColor    = color2RGBA(obj.settings.UI.button.val.toggCal.fillColor);
            obj.settings.UI.button.val.toggCal.edgeColor    = color2RGBA(obj.settings.UI.button.val.toggCal.edgeColor);
            obj.settings.UI.button.val.toggCal.textColor    = color2RGBA(obj.settings.UI.button.val.toggCal.textColor);
            
            % check requested eye calibration mode
            assert(ismember(obj.settings.calibrateEye,{'both','left','right'}),'Monocular/binocular recording setup ''%s'' not recognized. Supported modes are [''both'', ''left'', ''right'']',obj.settings.calibrateEye)
            if ismember(obj.settings.calibrateEye,{'left','right'}) && obj.isInitialized
                assert(obj.hasCap('CanDoMonocularCalibration'),'You requested recording from only the %s eye, but this %s does not support monocular calibrations. Set mode to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
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
        
        % getters
        function systemInfo = get.systemInfo(obj)
            systemInfo = [];
            if ~isempty(obj.buffer)
                systemInfo              = obj.buffer.getEyeTrackerInfo();
                systemInfo.SDKVersion   = obj.buffer.SDKVersion;    % SDK version consumed by MEX file
            end
        end
        function deviceName = get.deviceName(obj)
            deviceName = [];
            if ~isempty(obj.buffer)
                deviceName = obj.buffer.deviceName;
            end
        end
        function serialNumber = get.serialNumber(obj)
            serialNumber = [];
            if ~isempty(obj.buffer)
                serialNumber = obj.buffer.serialNumber;
            end
        end
        function model = get.model(obj)
            model = [];
            if ~isempty(obj.buffer)
                model = obj.buffer.model;
            end
        end
        function firmwareVersion = get.firmwareVersion(obj)
            firmwareVersion = [];
            if ~isempty(obj.buffer)
                firmwareVersion = obj.buffer.firmwareVersion;
            end
        end
        function runtimeVersion = get.runtimeVersion(obj)
            runtimeVersion = [];
            if ~isempty(obj.buffer)
                runtimeVersion = obj.buffer.runtimeVersion;
            end
        end
        function address = get.address(obj)
            address = [];
            if ~isempty(obj.buffer)
                address = obj.buffer.address;
            end
        end
        function capabilities = get.capabilities(obj)
            capabilities = [];
            if ~isempty(obj.buffer)
                capabilities = obj.buffer.capabilities;
            end
        end
        function supportedFrequencies = get.supportedFrequencies(obj)
            supportedFrequencies = [];
            if ~isempty(obj.buffer)
                supportedFrequencies = obj.buffer.supportedFrequencies;
            end
        end
        function supportedModes = get.supportedModes(obj)
            supportedModes = [];
            if ~isempty(obj.buffer)
                supportedModes = obj.buffer.supportedModes;
            end
        end
        function frequency = get.frequency(obj)
            frequency = [];
            if ~isempty(obj.buffer)
                frequency = obj.buffer.frequency;
            end
        end
        function trackingMode = get.trackingMode(obj)
            trackingMode = [];
            if ~isempty(obj.buffer)
                trackingMode = obj.buffer.trackingMode;
            end
        end
        % setters
        function set.frequency(obj,frequency)
            assert(nargin>1,'Titta::set.frequency: provide frequency argument.');
            if ~isempty(obj.buffer)
                obj.buffer.frequency = frequency;
                % if successful (would have thrown on previous line if
                % not), update frequency stored in settings as well
                obj.settings.freq = obj.buffer.frequency;
            end
        end
        function set.trackingMode(obj,trackingMode)
            assert(nargin>1,'Titta::set.trackingMode: provide tracking mode argument.');
            if ~isempty(obj.buffer)
                obj.buffer.trackingMode = trackingMode;
                % if successful (would have thrown on previous line if
                % not), update tracking mode stored in settings as well
                obj.settings.trackingMode = obj.buffer.trackingMode;
            end
        end
        
        function out = init(obj)
            % Load in our callback buffer mex
            obj.buffer = TobiiMex();
            obj.buffer.startLogging();
            
            % Connect to eyetracker
            iTry = 1;
            if exist('WaitSecs','file')==3
                wfunc = @(x) WaitSecs('YieldSecs',x);
            else
                wfunc = @pause;
            end
            while true
                if iTry<obj.settings.nTryReConnect+1
                    func = @warning;
                else
                    func = @error;
                end
                % see which eye trackers are available
                trackers = obj.buffer.findAllEyeTrackers();
                % find macthing eye-tracker, first by model
                if isempty(trackers) || ~any(strcmp({trackers.model},obj.settings.tracker))
                    extra = '';
                    if iTry==obj.settings.nTryReConnect+1
                        if ~isempty(trackers)
                            extra = sprintf('\nI did find the following:%s',sprintf('\n  %s',trackers.model));
                        else
                            extra = sprintf('\nNo eye trackers connected.');
                        end
                    end
                    func('Titta: No eye trackers of model ''%s'' connected%s',obj.settings.tracker,extra);
                    wfunc(obj.settings.connectRetryWait(min(iTry,end)));
                    iTry = iTry+1;
                    continue;
                end
                qModel = strcmp({trackers.model},obj.settings.tracker);
                % If obligatory serial also given, check on that.
                % A serial number preceeded by '*' denotes the serial
                % number is optional. That means that if only a single
                % other tracker of the same type is found, that one will be
                % used.
                assert(sum(qModel)==1 || ~isempty(obj.settings.serialNumber),'Titta: If more than one connected eye tracker is of the requested model, a serial number must be provided to allow connecting to the right one')
                if sum(qModel)>1 || (~isempty(obj.settings.serialNumber) && obj.settings.serialNumber(1)~='*')
                    % more than one tracker found or non-optional serial
                    serial = obj.settings.serialNumber;
                    if serial(1)=='*'
                        serial(1) = [];
                    end
                    qTracker = qModel & strcmp({trackers.serialNumber},serial);
                    
                    if ~any(qTracker)
                        extra = '';
                        if iTry==obj.settings.nTryReConnect+1
                            extra = sprintf('\nI did find eye trackers of model ''%s'' with the following serial numbers:%s',obj.settings.tracker,sprintf('\n  %s',trackers.serialNumber));
                        end
                        func('Titta: No eye trackers of model ''%s'' with serial ''%s'' connected.%s',obj.settings.tracker,serial,extra);
                        wfunc(obj.settings.connectRetryWait(min(iTry,end)));
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
            theTracker = trackers(qTracker);
            
            % provide callback buffer mex with eye tracker
            obj.buffer.init(theTracker.address);
            
            % apply license(s) if needed
            if ~isempty(obj.settings.licenseFile)
                if ~iscell(obj.settings.licenseFile)
                    obj.settings.licenseFile = {obj.settings.licenseFile};
                end
                
                % load license files
                nLicenses   = length(obj.settings.licenseFile);
                licenses    = cell(1,nLicenses);
                for l = 1:nLicenses
                    fid = fopen(obj.settings.licenseFile{l},'r');   % users should provide fully qualified paths or paths that are valid w.r.t. pwd
                    licenses{l} = fread(fid,inf,'*uint8');
                    fclose(fid);
                end
                
                % apply to selected eye tracker.
                applyResults = obj.buffer.applyLicenses(licenses);
                qFailed = ~strcmp(applyResults,'TOBII_RESEARCH_LICENSE_VALIDATION_RESULT_OK');
                if any(qFailed)
                    info = cell(sum(2,qFailed));
                    info(1,:) = applyResults(qFailed);
                    info(2,:) = obj.settings.licenseFile(qFailed);
                    info = sprintf('  %s (%s)\n',info{:}); info(end) = [];
                    error('Titta: the following provided license(s) couldn''t be applied:\n%s',info);
                end
                
                % applying license may have changed eye tracker's
                % capabilities or other info. get a fresh copy
                theTracker = obj.buffer.getEyeTrackerInfo();
            end
            
            % set tracker to operate at requested tracking frequency
            try
                obj.buffer.frequency = obj.settings.freq;
            catch ME
                % provide nice error message
                allFs = ['[' sprintf('%d, ',theTracker.supportedFrequencies) ']']; allFs(end-2:end-1) = [];
                error('Titta: Error setting tracker sampling frequency to %d. Possible tracking frequencies for this %s are %s.\nRaw error info:\n%s',obj.settings.freq,obj.settings.tracker,allFs,ME.getReport('extended'))
            end
            
            % set eye tracking mode.
            if ~isempty(obj.settings.trackingMode)
                try
                    obj.buffer.trackingMode = obj.settings.trackingMode;
                catch ME
                    % add info about possible tracking modes.
                    allModes = ['[' sprintf('''%s'', ',theTracker.supportedModes{:}) ']']; allModes(end-2:end-1) = [];
                    error('Titta: Error setting tracker mode to ''%s''. Possible tracking modes for this %s are %s. If a mode you expect is missing, check whether the eye tracker firmware is up to date.\nRaw error info:\n%s',obj.settings.trackingMode,obj.settings.tracker,allModes,ME.getReport('extended'))
                end
            end
            
            % if monocular tracking is requested, check that it is
            % supported
            if ismember(obj.settings.calibrateEye,{'left','right'})
                assert(obj.hasCap('CanDoMonocularCalibration'),'You requested recording from only the %s eye, but this %s does not support monocular calibrations. Set mode to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
            end
            
            % get info about the system
            assert(obj.systemInfo.frequency==obj.settings.freq,'Titta: Tracker not running at requested sampling rate (%d Hz), but at %d Hz',obj.settings.freq,obj.systemInfo.frequency);
            out.systemInfo                  = obj.systemInfo;
            
            % get information about display geometry and trackbox
            obj.geom.displayArea    = obj.buffer.getDisplayArea();
            try
                obj.geom.trackBox       = obj.buffer.getTrackBox();
                % get width and height of trackbox at middle depth
                obj.geom.trackBox.halfWidth   = mean([obj.geom.trackBox.frontUpperRight(1) obj.geom.trackBox.backUpperRight(1)])/10;
                obj.geom.trackBox.halfHeight  = mean([obj.geom.trackBox.frontUpperRight(2) obj.geom.trackBox.backUpperRight(2)])/10;
            catch
                % tracker does not support trackbox
                obj.geom.trackBox.halfWidth     = [];
                obj.geom.trackBox.halfHeight    = [];
            end
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
            obj.wpnts = wpnt;
            for w=length(wpnt):-1:1
                obj.scrInfo.resolution{w}  = Screen('Rect',wpnt(w)); obj.scrInfo.resolution{w}(1:2) = [];
                obj.scrInfo.center{w}      = obj.scrInfo.resolution{w}/2;
                obj.qFloatColorRange(w)    = Screen('ColorRange',wpnt(w))==1;
                % get current PTB state so we can restore when returning
                % 1. alpha blending
                [osf{w},odf{w},ocm{w}]     = Screen('BlendFunction', wpnt(w), GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                % 2. screen clear color so we can reset that too. There is only
                % one way to do that annoyingly:
                % 2.1. clear back buffer by flipping
                Screen('Flip',wpnt(w));
                % 2.2. read a pixel, this gets us the background color
                bgClr{w} = double(reshape(Screen('GetImage',wpnt(w),[1 1 2 2],'backBuffer',obj.qFloatColorRange(w),4),1,4));
                % 3. text
                text.style(w)  = Screen('TextStyle', wpnt(w));
                text.size(w)   = Screen('TextSize' , wpnt(w));
                text.font{w}   = Screen('TextFont' , wpnt(w));
                text.color{w}  = Screen('TextColor', wpnt(w));
            end
            
            % see what text renderer to use
            isWin = streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<*STREMP>
            obj.usingFTGLTextRenderer = (~isWin || ~~exist('libptbdrawtext_ftgl64.dll','file')) && Screen('Preference','TextRenderer')==1;    % check if we're not on Windows, or if on Windows that we the high quality text renderer is used (was never supported for 32bit PTB, so check only for 64bit)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.UI.button,'textVOff'),'Titta: PTB''s TextRenderer changed between calls to getDefaults and the Titta constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call Titta.getDefaults(), as it has different settings than the recommended TextRenderer number 1')
            end
            
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            [~,~,obj.mouseState] = GetMouse();
            
            
            %%% 1. some preliminary setup, to make sure we are in known state
            if bitand(flag,1)
                obj.buffer.leaveCalibrationMode(true);  % make sure we're not already in calibration mode (start afresh)
            end
            obj.StopRecordAll();
            
            %%% 2. enter the setup/calibration screens
            % The below is a big loop that will run possibly multiple
            % calibration until exiting because skipped or a calibration is
            % selected by user.
            % there are three start modes:
            % 0. skip head positioning, go straight to calibration
            % 1. start with head positioning interface
            startScreen         = obj.settings.UI.startScreen;
            kCal                = 0;
            out                 = struct('selectedCal', nan, 'wasSkipped', false);
            qNewCal             = true;
            qHasEnteredCalMode  = false;
            while true
                qGoToValidationViewer = false;
                if qNewCal
                    if ~kCal
                        kCal = 1;
                    else
                        kCal = length(out.attempt)+1;
                    end
                    qNewCal = false;
                end
                out.attempt{kCal}.eye  = obj.settings.calibrateEye;
                if startScreen>0
                    %%% 2a: show head positioning screen
                    out.attempt{kCal}.setupStatus = obj.showHeadPositioning(wpnt,out);
                    switch out.attempt{kCal}.setupStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            out.wasSkipped = true;
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
                    % enter calibration mode if we should and if we haven't
                    % yet. Only do this now, so previous calibration
                    % survives a "skip calibration" during the setup screen
                    if bitand(flag,1) && ~qHasEnteredCalMode
                        qDoMonocular = ismember(obj.settings.calibrateEye,{'left','right'});
                        if qDoMonocular
                            assert(obj.hasCap('CanDoMonocularCalibration'),'You requested calibrating only the %s eye, but this %s does not support monocular calibrations. Set settings.calibrateEye to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
                        end
                        obj.buffer.enterCalibrationMode(qDoMonocular);
                        qHasEnteredCalMode = true;
                    end
                    out.attempt{kCal} = obj.DoCalAndVal(wpnt,kCal,out.attempt{kCal});
                    % check returned action state
                    switch out.attempt{kCal}.status
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            out.wasSkipped = true;
                            break;
                        case -1
                            % restart calibration
                            startScreen = 0;
                            qNewCal     = ~(isfield(out.attempt{kCal},'cal') && out.attempt{kCal}.cal.status==1);   % new calibration unless we have a successful calibration already, then we're restarting a validation
                            continue;
                        case -3
                            % go to setup
                            startScreen = 1;
                            qNewCal     = true;
                            continue;
                        case -5
                            % full stop
                            obj.buffer.leaveCalibrationMode();
                            error('Titta: run ended from calibration routine')
                        otherwise
                            error('Titta: status %d not implemented',out.attempt{kCal}.status);
                    end
                    
                    % store information about last calibration as message
                    if out.attempt{kCal}.val{end}.status==1
                        message = obj.getValidationQualityMessage(out.attempt{kCal},kCal);
                        obj.sendMessage(message);
                    end
                end
                
                %%% 2c: show calibration results
                % show validation result and ask to continue
                [out.attempt,kCal] = obj.showCalValResult(wpnt,out.attempt,kCal);
                switch out.attempt{kCal}.valReviewStatus
                    case 1
                        % all good, we're done
                        out.selectedCal = kCal;
                        break;
                    case 2
                        % skip setup
                        out.wasSkipped = true;
                        break;
                    case -1
                        % restart calibration
                        startScreen = 0;
                        qNewCal     = true;
                        continue;
                    case -2
                        % redo validation only
                        startScreen = 0;
                        % NB: not a new cal, we're adding a validation to
                        % the current cal
                        continue;
                    case -3
                        % go to setup
                        startScreen = 1;
                        qNewCal     = true;
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
            for w=length(wpnt):-1:1
                Screen('FillRect',      wpnt(w),bgClr{w});                  % reset background color
                Screen('BlendFunction', wpnt(w),osf{w},odf{w},ocm{w});      % reset blend function
                Screen('TextFont',      wpnt(w),text.font{w},text.style(w));
                Screen('TextColor',     wpnt(w),text.color{w});
                Screen('TextSize',      wpnt(w),text.size(w));
                Screen('Flip',          wpnt(w));                           % clear screen
            end
            
            if bitand(flag,2) || (out.wasSkipped && qHasEnteredCalMode)
                obj.buffer.leaveCalibrationMode();
            end
            % log to messages which calibration was selected
            if ~isnan(out.selectedCal)
                obj.sendMessage(sprintf('CALIBRATION (%s) SELECTED no. %d',getEyeLbl(obj.settings.calibrateEye),out.selectedCal));
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
            % functions), and will be converted to microseconds to match
            % Tobii's timestamps
            if nargin<3
                time = obj.getTimeAsSystemTime();
            else
                time = obj.getTimeAsSystemTime(time);
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
            dat.calibration = obj.calibrateHistory;
            dat.messages    = obj.getMessages();
            dat.systemInfo  = obj.systemInfo;
            dat.geometry    = obj.geom;
            dat.settings    = obj.settings;
            if isa(dat.settings.cal.drawFunction,'function_handle')
                dat.settings.cal.drawFunction = func2str(dat.settings.cal.drawFunction);
            end
            if isa(dat.settings.cal.pointNotifyFunction,'function_handle')
                dat.settings.cal.pointNotifyFunction = func2str(dat.settings.cal.pointNotifyFunction);
            end
            if isa(dat.settings.val.pointNotifyFunction,'function_handle')
                dat.settings.val.pointNotifyFunction = func2str(dat.settings.val.pointNotifyFunction);
            end
            if isa(dat.settings.UI.setup.instruct.strFun,'function_handle')
                dat.settings.UI.setup.instruct.strFun = func2str(dat.settings.UI.setup.instruct.strFun);
            end
            if isa(dat.settings.UI.setup.instruct.strFunO,'function_handle')
                dat.settings.UI.setup.instruct.strFunO = func2str(dat.settings.UI.setup.instruct.strFunO);
            end
            dat.TobiiLog    = obj.buffer.getLog(false);
            dat.data        = obj.ConsumeAllData();
        end
        
        function saveData(obj, filename, doAppendVersion)
            % convenience function that gets data from all streams and
            % saves to mat file along with messages, calibration
            % information and system info
            
            % 1. get filename and path
            if nargin<3
                doAppendVersion = false;
            end
            filename = Titta.getFileName(filename, doAppendVersion);
            
            % 2. collect all data to save
            dat = obj.collectSessionData();
            
            % save
            try
                save(filename,'-struct','dat');
            catch ME
                error('Titta: saveData: Error saving data:\n%s',ME.getReport('extended'))
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
            
            % clear msgs and other fields
            obj.msgs = simpleVec(cell(1,2),1024);   % (re)initialize with space for 1024 messages
            obj.calibrateHistory = [];
            obj.geom = [];
            
            % mark as deinited
            obj.isInitialized = false;
        end
    end
    
    
    
    
    % helpers
    methods (Static, Hidden)
        function notAllowed = getDisAllowedOptions()
            % blacklist of options that cannot be set once Titta.init() has
            % run
            notAllowed = {...
                'tracker'
                'serialNumber'
                'licenseFile'
                'nTryReConnect'
                'connectRetryWait'
                'debugMode'
                };
        end
    end
    methods (Static)
        function settings = getDefaults(tracker)
            assert(nargin>=1,'Titta: you must provide a tracker name when calling getDefaults')
            settings.tracker    = tracker;
            
            % default tracking settings per eye-tracker
            settings.trackingMode           = 'Default';    % for all trackers except Spectrum, default tracking mode is "Default". So use that as a default
            switch tracker
                case 'Tobii Pro Spectrum'
                    settings.freq                   = 600;
                    settings.trackingMode           = 'human';
                case 'Tobii TX300'
                    settings.freq                   = 300;
                case 'Tobii T60 XL'
                    settings.freq                   = 60;
                    
                case 'Tobii Pro Nano'
                    settings.freq                   = 60;
                case {'Tobii Pro X3-120','Tobii Pro X3-120 EPU'}
                    settings.freq                   = 120;
                case 'X2-60_Compact'
                    settings.freq                   = 60;
                case 'X2-30_Compact'
                    settings.freq                   = 40;   % reports 40Hz instead of actual 30Hz rate...
                case 'Tobii X60'
                    settings.freq                   = 60;
                case 'Tobii X120'
                    settings.freq                   = 120;
                case 'Tobii T60'
                    settings.freq                   = 60;
                case 'Tobii T120'
                    settings.freq                   = 120;
                    
                case 'IS4_Large_Peripheral'
                    settings.freq                   = 90;
            end
            
            % check have PTB, adjust text setting if needed
            textFac                     = 1;
            qUsingOldWindowsPTBRenderer = false;
            if ~~exist('PsychtoolboxVersion','file')
                if IsWin && (~exist('libptbdrawtext_ftgl64.dll','file') || Screen('Preference','TextRenderer')==0)
                    % seems text gets rendered a little larger with the old
                    % text renderer, make sure we have good default sizes
                    % anyway
                    qUsingOldWindowsPTBRenderer = true;
                    textFac                     = 0.75;
                end
            end
            
            % some default colors to be used below
            eyeColors           = {[255 127   0],[  0  95 191]};
            toggleButClr.fill   = {[199 221 255],[219 233 255],[ 17 108 248]};  % for buttons that toggle (e.g. show eye movements, show online gaze)
            toggleButClr.edge   = {[  0   0   0],[  5  75 181],[219 233 255]};
            toggleButClr.text   = {[  5  75 181],[  5  75 181],[219 233 255]};
            continueButClr.fill = {[ 84 185  72],[ 91 194  78],[ 92 201  79]};  % continue calibration, start recording
            continueButClr.edge = {[  0   0   0],[237 255 235],[237 255 235]};
            continueButClr.text = {[214 255 209],[237 255 235],[237 255 235]};
            backButClr.fill     = {[255 209 207],[255 231 229],[255  60  48]};  % redo cal, val, go back to set up
            backButClr.edge     = {[  0   0   0],[238  62  52],[255 231 229]};
            backButClr.text     = {[238  62  52],[238  62  52],[255 231 229]};
            optionButClr.fill   = {[255 225 199],[255 236 219],[255 147  56]};  % "sideways" actions: view previous calibrations, open menu and select different calibration
            optionButClr.edge   = {[  0   0   0],[255 116   0],[255 236 219]};
            optionButClr.text   = {[255 116   0],[255 116   0],[255 236 219]};
            
            % TODO: common file format
            
            % the rest here are good defaults for all
            settings.calibrateEye               = 'both';                       % 'both', also possible if supported by eye tracker: 'left' and 'right'
            settings.serialNumber               = '';
            settings.licenseFile                = '';                           % should be single string or cell array of strings, with each string being the path to a license file to apply
            settings.nTryReConnect              = 3;                            % How many times to retry connecting before giving up? Something larger than zero is good as it may take more time than the first call to find_all_eyetrackers for network eye trackers to be found
            settings.connectRetryWait           = [1 2];                        % seconds
            settings.UI.startScreen             = 1;                            % 0. skip head positioning, go straight to calibration; 1. start with head positioning interface
            settings.UI.setup.showEyes          = true;
            settings.UI.setup.showPupils        = true;
            settings.UI.setup.showYaw           = true;                         % show yaw of head?
            settings.UI.setup.showYawToOperator = true;                         % show yaw of head on operator screen?
            settings.UI.setup.referencePos      = [];                           % [x y z] in cm. if empty, default: ideal head positioning determined through eye tracker's positioning stream. If values given, refernce position circle is positioned referencePos(1) cm horizontally and referencePos(2) cm vertically from the center of the screen (assuming screen dimensions were correctly set in Tobii Eye Tracker Manager)
            settings.UI.setup.bgColor           = 127;
            settings.UI.setup.refCircleClr      = [0 0 255];
            settings.UI.setup.headCircleEdgeClr = [255 255 0];
            settings.UI.setup.headCircleFillClr = [255 255 0 .3*255];
            settings.UI.setup.eyeClr            = 255;
            settings.UI.setup.pupilClr          = 0;
            settings.UI.setup.crossClr          = [255 0 0];
            settings.UI.setup.fixBackSize       = 20;
            settings.UI.setup.fixFrontSize      = 5;
            settings.UI.setup.fixBackColor      = 0;
            settings.UI.setup.fixFrontColor     = 255;
            % functions for drawing instruction and positioning information
            % on user and operator screen. Note that rx, ry and rz are
            % NaN (unknown) if reference position is not set by user
            settings.UI.setup.instruct.strFun   = @(x,y,z,rx,ry,rz) sprintf('Position yourself such that the two circles overlap.\nDistance: %.0f cm',z);
            settings.UI.setup.instruct.strFunO  = @(x,y,z,rx,ry,rz) sprintf('Position:\nX: %1$.1f cm, should be: %4$.1f cm\nY: %2$.1f cm, should be: %5$.1f cm\nDistance: %3$.1f cm, should be: %6$.1f cm',x,y,z,rx,ry,rz);
            settings.UI.setup.instruct.font     = 'Segoe UI';
            settings.UI.setup.instruct.size     = 24*textFac;
            settings.UI.setup.instruct.color    = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.setup.instruct.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.setup.instruct.vSpacing = 1.5;
            if streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32'))   % on Windows
                settings.UI.cursor.normal           = 0;                        % arrow
                settings.UI.cursor.clickable        = 2;                        % hand
            elseif IsLinux
                settings.UI.cursor.normal           = 2;                        % arrow
                settings.UI.cursor.clickable        = 58;                       % hand
            end
            settings.UI.button.margins          = [14 16];
            if qUsingOldWindowsPTBRenderer  % old text PTB renderer on Windows
                settings.UI.button.textVOff     = 3;                            % amount (pixels) to move single line text so that it is visually centered on requested coordinate
            end
            settings.UI.button.setup.text.font          = 'Segoe UI';
            settings.UI.button.setup.text.size          = 24*textFac;
            settings.UI.button.setup.text.style         = 0;
            settings.UI.button.setup.eyeIm.accelerator  = 'e';
            settings.UI.button.setup.eyeIm.visible      = true;
            settings.UI.button.setup.eyeIm.string       = 'eye images (<i>e<i>)';
            settings.UI.button.setup.eyeIm.fillColor    = toggleButClr.fill;
            settings.UI.button.setup.eyeIm.edgeColor    = toggleButClr.edge;
            settings.UI.button.setup.eyeIm.textColor    = toggleButClr.text;
            settings.UI.button.setup.cal.accelerator    = 'space';
            settings.UI.button.setup.cal.visible        = true;
            settings.UI.button.setup.cal.string         = 'calibrate (<i>spacebar<i>)';
            settings.UI.button.setup.cal.fillColor      = continueButClr.fill;
            settings.UI.button.setup.cal.edgeColor      = continueButClr.edge;
            settings.UI.button.setup.cal.textColor      = continueButClr.text;
            settings.UI.button.setup.prevcal.accelerator= 'p';
            settings.UI.button.setup.prevcal.visible    = true;
            settings.UI.button.setup.prevcal.string     = 'previous calibrations (<i>p<i>)';
            settings.UI.button.setup.prevcal.fillColor  = optionButClr.fill;
            settings.UI.button.setup.prevcal.edgeColor  = optionButClr.edge;
            settings.UI.button.setup.prevcal.textColor  = optionButClr.text;
            settings.UI.button.val.text.font            = 'Segoe UI';
            settings.UI.button.val.text.size            = 24*textFac;
            settings.UI.button.val.text.style           = 0;
            settings.UI.button.val.recal.accelerator    = 'escape';
            settings.UI.button.val.recal.visible        = true;
            settings.UI.button.val.recal.string         = 'recalibrate (<i>esc<i>)';
            settings.UI.button.val.recal.fillColor      = backButClr.fill;
            settings.UI.button.val.recal.edgeColor      = backButClr.edge;
            settings.UI.button.val.recal.textColor      = backButClr.text;
            settings.UI.button.val.reval.accelerator    = 'v';
            settings.UI.button.val.reval.visible        = true;
            settings.UI.button.val.reval.string         = 'revalidate (<i>v<i>)';
            settings.UI.button.val.reval.fillColor      = backButClr.fill;
            settings.UI.button.val.reval.edgeColor      = backButClr.edge;
            settings.UI.button.val.reval.textColor      = backButClr.text;
            settings.UI.button.val.continue.accelerator = 'space';
            settings.UI.button.val.continue.visible     = true;
            settings.UI.button.val.continue.string      = 'continue (<i>spacebar<i>)';
            settings.UI.button.val.continue.fillColor   = continueButClr.fill;
            settings.UI.button.val.continue.edgeColor   = continueButClr.edge;
            settings.UI.button.val.continue.textColor   = continueButClr.text;
            settings.UI.button.val.selcal.accelerator   = 'c';
            settings.UI.button.val.selcal.visible       = true;
            settings.UI.button.val.selcal.string        = 'select other cal (<i>c<i>)';
            settings.UI.button.val.selcal.fillColor     = optionButClr.fill;
            settings.UI.button.val.selcal.edgeColor     = optionButClr.edge;
            settings.UI.button.val.selcal.textColor     = optionButClr.text;
            settings.UI.button.val.setup.accelerator    = 's';
            settings.UI.button.val.setup.visible        = true;
            settings.UI.button.val.setup.string         = 'setup (<i>s<i>)';
            settings.UI.button.val.setup.fillColor      = backButClr.fill;
            settings.UI.button.val.setup.edgeColor      = backButClr.edge;
            settings.UI.button.val.setup.textColor      = backButClr.text;
            settings.UI.button.val.toggGaze.accelerator = 'g';
            settings.UI.button.val.toggGaze.visible     = true;
            settings.UI.button.val.toggGaze.string      = 'show gaze (<i>g<i>)';
            settings.UI.button.val.toggGaze.fillColor   = toggleButClr.fill;
            settings.UI.button.val.toggGaze.edgeColor   = toggleButClr.edge;
            settings.UI.button.val.toggGaze.textColor   = toggleButClr.text;
            settings.UI.button.val.toggCal.accelerator  = 't';
            settings.UI.button.val.toggCal.visible      = false;
            settings.UI.button.val.toggCal.string       = 'show cal (<i>t<i>)';
            settings.UI.button.val.toggCal.fillColor    = toggleButClr.fill;
            settings.UI.button.val.toggCal.edgeColor    = toggleButClr.edge;
            settings.UI.button.val.toggCal.textColor    = toggleButClr.text;
            settings.UI.cal.errMsg.string       = 'Calibration failed\nPress any key to continue';
            settings.UI.cal.errMsg.font         = 'Segoe UI';
            settings.UI.cal.errMsg.size         = 36*textFac;
            settings.UI.cal.errMsg.color        = [150 0 0];
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
            settings.UI.val.avg.text.color      = 0;
            settings.UI.val.avg.text.eyeColors  = eyeColors;                    % colors for "left" and "right" in data quality report on top of validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.avg.text.style      = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.avg.text.vSpacing   = 1;
            settings.UI.val.waitMsg.string      = 'Please wait...';
            settings.UI.val.waitMsg.font        = 'Segoe UI';
            settings.UI.val.waitMsg.size        = 28*textFac;
            settings.UI.val.waitMsg.color       = 0;
            settings.UI.val.waitMsg.style       = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.hover.bgColor       = 110;
            settings.UI.val.hover.text.font     = 'Consolas';
            settings.UI.val.hover.text.size     = 20*textFac;
            settings.UI.val.hover.text.color    = 0;
            settings.UI.val.hover.text.eyeColors= eyeColors;                    % colors for "left" and "right" in per-point data quality report on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.hover.text.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.menu.bgColor        = 110;
            settings.UI.val.menu.itemColor      = 140;
            settings.UI.val.menu.itemColorActive= 180;
            settings.UI.val.menu.text.font      = 'Segoe UI';
            settings.UI.val.menu.text.size      = 24*textFac;
            settings.UI.val.menu.text.color     = 0;
            settings.UI.val.menu.text.eyeColors = eyeColors;                    % colors for "left" and "right" in calibration selection menu on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.menu.text.style     = 0;
            settings.cal.pointPos               = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
            settings.cal.autoPace               = 1;                            % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
            settings.cal.paceDuration           = 0.8;                          % minimum duration (s) that each point is shown
            settings.cal.doRandomPointOrder     = true;
            settings.cal.bgColor                = 127;
            settings.cal.fixBackSize            = 20;
            settings.cal.fixFrontSize           = 5;
            settings.cal.fixBackColor           = 0;
            settings.cal.fixFrontColor          = 255;
            settings.cal.drawFunction           = [];
            settings.cal.doRecordEyeImages      = false;
            settings.cal.doRecordExtSignal      = false;
            settings.cal.pointNotifyFunction    = [];                           % function that is called upon each calibration point completing
            settings.val.pointPos               = [[0.5 .2]; [.2 .5];[.8 .5]; [.5 .8]];
            settings.val.paceDuration           = 0.8;
            settings.val.collectDuration        = 0.5;
            settings.val.doRandomPointOrder     = true;
            settings.val.pointNotifyFunction    = [];                           % function that is called upon each validation point completing (note that validation doesn't check fixation, purely based on time)
            settings.debugMode                  = false;                        % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
        end
        
        function time = getTimeAsSystemTime(PTBtime)
            % maps either inputted PTB time (e.g. from GetSecs, audio or
            % video timestamps, PsychHID timestamps, etc) or current
            % GetSecs if no input argument was provided to Tobii system
            % time. PTB time is in seconds, and may be using a different
            % clock than Tobii time. Tobii time is in microseconds.
            if IsLinux
                % on Linux, Tobii Pro SDK on Linux and mono clock on PTB
                % internally both use CLOCK_MONOTONIC, whereas the clock
                % used for PTB's GetSecs, Flip timestamps, etc, uses
                % CLOCK_REALTIME. GetSecs('AllClocks') enables getting time
                % in both clocks, so we can calculate the offset between
                % the two clocks and remap PTB time to
                % CLOCK_MONOTONIC/Tobii Pro SDK system time. The AllClocks
                % subfunction of GetSecs allows to remap with better
                % (usually much better) accuracy than 20 microseconds. We
                % detemine the offset anew every time this function is
                % called, as REALTIME_CLOCK/PTB time may be affected by NTP
                % adjustments, and the two clocks may thus drift.
                [PTBgs,~,~,PTBmono] = GetSecs('AllClocks');
                if nargin<1
                    PTBtime = PTBmono;                  % not PTB time specified, just get CLOCK_MONOTONIC timestamp
                else
                    PTBtime = PTBtime-PTBgs+PTBmono;    % PTBgs-PTBmono is offset required to remap from PTB time to CLOCK_MONOTONIC/Tobii Pro SDK system time
                end
            else
                if nargin<1
                    PTBtime = GetSecs();
                end
            end
            time = int64(PTBtime*1000*1000);
        end
        
        function message = getValidationQualityMessage(cal,kCal)
            if isfield(cal,'attempt')
                % find selected calibration, make sure we output quality
                % info for that
                if nargin<2 || isempty(kCal)
                    assert(isfield(cal,'selectedCal'),'The user did not select a calibration')
                    kCal    = cal.selectedCal;
                end
                cal     = cal.attempt{kCal};
            end
            % find last valid validation
            iVal    = find(cellfun(@(x) x.status, cal.val)==1,1,'last');
            val     = cal.val{iVal};
            % get data to put in message, output per eye separately.
            eyes    = fieldnames(val.quality);
            nPoint  = length(val.quality);
            msg     = cell(1,length(eyes));
            for e=1:length(eyes)
                dat = cell(7,nPoint+1);
                for k=1:nPoint
                    valq = val.quality(k).(eyes{e});
                    dat(:,k) = {sprintf('%d @ (%.0f,%.0f)',k,val.pointPos(k,2:3)),valq.acc2D,valq.acc(1),valq.acc(2),valq.STD2D,valq.RMS2D,valq.dataLoss*100};
                end
                % also get average
                dat(:,end) = {'average',val.acc2D(e),val.acc(1,e),val.acc(2,e),val.STD2D(e),val.RMS2D(e),val.dataLoss(e)*100};
                msg{e} = sprintf('%s eye:\n%s',eyes{e},sprintf('%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.1f\n',dat{:}));
            end
            msg = [msg{:}]; msg(end) = [];
            message = sprintf('CALIBRATION %1$d Data Quality (computed from validation %2$d):\npoint\tacc2D (%4$c)\taccX (%4$c)\taccY (%4$c)\tSTD2D (%4$c)\tRMS2D (%4$c)\tdata loss (%%)\n%3$s',kCal,iVal,msg,char(176));
        end
        
        function filename = getFileName(filename, doAppendVersion)
            % 1. get filename and path
            [path,file,ext] = fileparts(filename);
            assert(~isempty(path),'Titta: getFileName: filename should contain a path')
            % eat .mat off filename, preserve any other extension user may
            % have provided
            if ~isempty(ext) && ~strcmpi(ext,'.mat')
                file = [file ext];
            end
            % add versioning info to file name, if wanted and if already
            % exists
            if nargin>=2 && doAppendVersion
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
        end
    end
    
    methods (Access = private, Hidden)
        function out = hasCap(obj,cap)
            out = ismember(cap,obj.systemInfo.capabilities);
        end
        
        function status = showHeadPositioning(obj,wpnt,out)            
            % status output:
            %  1: continue (setup seems good) (space)
            %  2: skip calibration and continue with task (shift+s)
            % -4: go to validation screen (p) -- only if there are already
            %     completed calibrations
            % -5: Exit completely (control+escape)
            % (NB: no -1 for this function)
            
            % logic: if user is at reference viewing distance and at
            % desired position in head box vertically and horizontally, two
            % circles will overlap indicating correct positioning
            % further logic: this display is like a mirror, making it
            % directly intuitive how the head is oriented w.r.t. the eye
            % tracker. Only information missing is pitch, as that cannot be
            % known from only the 3D positions of the two eyes.
            
            startT                  = obj.sendMessage(sprintf('START SETUP (%s)',getEyeLbl(obj.settings.calibrateEye)));
            obj.buffer.start('gaze');
            obj.buffer.start('positioning');
            qHasEyeIm               = obj.buffer.hasStream('eyeImage');
            % see if we already have valid calibrations
            qHaveValidCalibrations  = ~isempty(getValidCalibrations(out.attempt));
            qHaveOperatorScreen     = ~isscalar(wpnt);
            
            % setup text for buttons
            for w=1:length(wpnt)
                Screen('TextFont',  wpnt(w), obj.settings.UI.button.setup.text.font, obj.settings.UI.button.setup.text.style);
                Screen('TextSize',  wpnt(w), obj.settings.UI.button.setup.text.size);
            end
            
            % setup ovals
            ovalVSz     = .15;
            refSz       = ovalVSz*obj.scrInfo.resolution{1}(2);
            refClr      = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(1));
            bgClr       = obj.getColorForWindow(obj.settings.UI.setup.bgColor,wpnt(1));
            % setup head position visualization
            head                    = ETHead(wpnt(1),obj.geom.trackBox.halfWidth,obj.geom.trackBox.halfHeight);
            head.refSz              = refSz;
            head.rectWH             = obj.scrInfo.resolution{1};
            head.headCircleFillClr  = obj.settings.UI.setup.headCircleFillClr;
            head.headCircleEdgeClr  = obj.settings.UI.setup.headCircleEdgeClr;
            head.showYaw            = obj.settings.UI.setup.showYaw;
            head.showEyes           = obj.settings.UI.setup.showEyes;
            head.eyeClr             = obj.settings.UI.setup.eyeClr;
            head.showPupils         = obj.settings.UI.setup.showPupils;
            head.pupilClr           = obj.settings.UI.setup.pupilClr;
            head.crossClr           = obj.settings.UI.setup.crossClr;
            head.crossEye           = (~obj.calibrateLeftEye)*1+(~obj.calibrateRightEye)*2; % will be 0, 1 or 2 (as we must calibrate at least one eye)
            if qHaveOperatorScreen
                headO                   = ETHead(wpnt(2),obj.geom.trackBox.halfWidth,obj.geom.trackBox.halfHeight);
                headO.refSz             = head.refSz;
                headO.rectWH            = head.rectWH;
                headO.headCircleFillClr = head.headCircleFillClr;
                headO.headCircleEdgeClr = head.headCircleEdgeClr;
                headO.showYaw           = obj.settings.UI.setup.showYawToOperator;
                headO.showEyes          = head.showEyes;
                headO.eyeClr            = head.eyeClr;
                headO.showPupils        = head.showPupils;
                headO.pupilClr          = head.pupilClr;
                headO.crossClr          = head.crossClr;
                headO.crossEye          = head.crossEye;
                refClrO                 = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(2));
                bgClrO                  = obj.getColorForWindow(obj.settings.UI.setup.bgColor,wpnt(2));
            end
            
            % get reference position
            if isempty(obj.settings.UI.setup.referencePos)
                obj.settings.UI.setup.referencePos = [NaN NaN NaN];
            end
            % position reference circle on screen
            refPosO = obj.scrInfo.resolution{1}/2;
            allPosOff = [0 0];
            if ~isnan(obj.settings.UI.setup.referencePos(1)) && any(obj.settings.UI.setup.referencePos(1:2)~=0)
                scrWidth  = obj.geom.displayArea.width/10;
                scrHeight = obj.geom.displayArea.height/10;
                pixPerCm  = mean(obj.scrInfo.resolution{1}./[scrWidth scrHeight])*[1 -1];   % flip Y because positive UCS is upward, should be downward for drawing on screen
                allPosOff = obj.settings.UI.setup.referencePos(1:2).*pixPerCm;
            end
            refPosP = refPosO+allPosOff;
            
            head.referencePos   = obj.settings.UI.setup.referencePos;
            head.allPosOff      = allPosOff;
            if qHaveOperatorScreen
                headO.referencePos  = head.referencePos;
                % NB: no offset on screen for head on operator screen, so
                % don't use allPosOff
            end

            % setup buttons
            funs    = struct('textCacheGetter',@obj.getTextCache, 'textCacheDrawer', @obj.drawCachedText, 'cacheOffSetter', @obj.positionButtonText, 'colorGetter', @(clr) obj.getColorForWindow(clr,wpnt(end)));
            but(1)  = PTBButton(obj.settings.UI.button.setup.eyeIm  ,       qHasEyeIm       , wpnt(end), funs, obj.settings.UI.button.margins);
            but(2)  = PTBButton(obj.settings.UI.button.setup.cal    ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(3)  = PTBButton(obj.settings.UI.button.setup.prevcal, qHaveValidCalibrations, wpnt(end), funs, obj.settings.UI.button.margins);
            % arrange them
            butRectsBase= cat(1,but([but.visible]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution{end}(2)*.95);
                % place buttons for go to advanced interface, or calibrate
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution{w}(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                butRects          = num2cell(butRects,2);
                [but([but.visible]).rect] = butRects{:};
            end
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution{w},4,1);
            
            % setup cursors
            butRects        = cat(1,but.rect).';
            % for cursor, need to correct rect position based on global
            % rect of window
            rect     = Screen('GlobalRect',wpnt(end));
            butRects = bsxfun(@plus,butRects,rect([1 2 1 2]).');
            cursors.rect    = num2cell(butRects,1);
            cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,size(cursors.rect));  % clickable items
            cursors.other   = obj.settings.UI.cursor.normal;                                % default
            if ~obj.settings.debugMode                                                      % for cleanup
                cursors.reset = -1;                                                         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor  = cursorUpdater(cursors);
            
            % setup text for positioning message
            Screen('TextFont',  wpnt(1), obj.settings.UI.setup.instruct.font, obj.settings.UI.setup.instruct.style);
            Screen('TextSize',  wpnt(1), obj.settings.UI.setup.instruct.size);
            
            % get tracking status and visualize
            qToggleEyeImage     = qHaveOperatorScreen;  % eye images default off if single screen, default on if have operator screen
            qShowEyeImage       = false;
            texs                = [0 0];
            szs                 = [];
            eyeImageRect        = repmat({zeros(1,4)},1,2);
            circVerts           = genCircle(200);
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            headPosLastT       = 0;
            while true
                Screen('FillRect', wpnt(1), bgClr);
                if qHaveOperatorScreen
                    Screen('FillRect', wpnt(2), bgClrO);
                end
                if qHasEyeIm
                    % toggle eye images on or off if requested
                    if qToggleEyeImage
                        if qShowEyeImage
                            % switch off
                            obj.buffer.stop('eyeImage');
                            obj.buffer.clearTimeRange('eyeImage',eyeStartTime);  % default third argument, clearing from startT until now
                        else
                            % switch on
                            eyeStartTime = obj.getTimeAsSystemTime();
                            obj.buffer.start('eyeImage');
                        end
                        qShowEyeImage   = ~qShowEyeImage;
                        qToggleEyeImage = false;
                    end
                    
                    if qShowEyeImage
                        % get eye image
                        eyeIm       = obj.buffer.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward (default third argument: now)
                        [texs,szs]  = UploadImages(texs,szs,wpnt(end),eyeIm);
                        
                        % update eye image locations if size of returned eye image changed
                        if (~any(isnan(szs(:,1))) && any(szs(:,1).'~=diff(reshape(eyeImageRect{1},2,2)))) || (~any(isnan(szs(:,2))) && any(szs(:,2).'~=diff(reshape(eyeImageRect{1},2,2))))
                            margin = 20;
                            visible = [but.visible];
                            if ~any(visible)
                                basePos = round(obj.scrInfo.resolution{1}(2)*.95);
                            else
                                basePos = min(butRects(2,[but.visible]));
                            end
                            eyeImageRect{1} = OffsetRect([0 0 szs(:,1).'],obj.scrInfo.center{end}(1)-szs(1,1)-margin/2,basePos-margin-szs(2,1));
                            eyeImageRect{2} = OffsetRect([0 0 szs(:,2).'],obj.scrInfo.center{end}(1)         +margin/2,basePos-margin-szs(2,2));
                        end
                    end
                end
                
                % get latest data from eye-tracker
                eyeData     = obj.buffer.peekN('gaze',1);
                posGuide    = obj.buffer.peekN('positioning',1);
                if isempty(eyeData.systemTimeStamp)
                    head.update([],[],[],[], [],[],[],[]);
                    if qHaveOperatorScreen
                        headO.update([],[],[],[], [],[],[],[]);
                    end
                else
                    head.update(...
                        eyeData. left.gazeOrigin.valid, eyeData. left.gazeOrigin.inUserCoords, posGuide. left.user_position, eyeData. left.pupil.diameter,...
                        eyeData.right.gazeOrigin.valid, eyeData.right.gazeOrigin.inUserCoords, posGuide.right.user_position, eyeData.right.pupil.diameter);
                    if qHaveOperatorScreen
                        headO.update(...
                            eyeData. left.gazeOrigin.valid, eyeData. left.gazeOrigin.inUserCoords, posGuide. left.user_position, eyeData. left.pupil.diameter,...
                            eyeData.right.gazeOrigin.valid, eyeData.right.gazeOrigin.inUserCoords, posGuide.right.user_position, eyeData.right.pupil.diameter);
                    end
                end
                
                if ~isnan(head.avgDist)
                    headPosLastT = eyeData.systemTimeStamp;
                end
                
                % draw eye images, if any
                if qShowEyeImage
                    if texs(1)
                        Screen('DrawTexture', wpnt(end), texs(1),[],eyeImageRect{1});
                    else
                        Screen('FillRect', wpnt(end), 0, eyeImageRect{1});
                    end
                    if texs(2)
                        Screen('DrawTexture', wpnt(end), texs(2),[],eyeImageRect{2});
                    else
                        Screen('FillRect', wpnt(end), 0, eyeImageRect{2});
                    end
                end
                % for distance info and ovals: hide when eye image is shown
                % and data is missing. But only do so after 200 ms of data
                % missing, so that these elements don't flicker all the
                % time when unstable track
                qHideSetup = qShowEyeImage && isempty(head.headPos) && ~isempty(eyeData.systemTimeStamp) && double(eyeData.systemTimeStamp-headPosLastT)/1000>200;
                % draw distance info
                if ~qHideSetup
                    str = obj.settings.UI.setup.instruct.strFun(head.avgX,head.avgY,head.avgDist,obj.settings.UI.setup.referencePos(1),obj.settings.UI.setup.referencePos(2),obj.settings.UI.setup.referencePos(3));
                    DrawFormattedText(wpnt(1),str,'center',fixPos(1,2),obj.settings.UI.setup.instruct.color,[],[],[],obj.settings.UI.setup.instruct.vSpacing);
                end
                if qHaveOperatorScreen
                    str = obj.settings.UI.setup.instruct.strFunO(head.avgX,head.avgY,head.avgDist,obj.settings.UI.setup.referencePos(1),obj.settings.UI.setup.referencePos(2),obj.settings.UI.setup.referencePos(3));
                    DrawFormattedText(wpnt(2),str,'center',fixPos(1,2),obj.settings.UI.setup.instruct.color,[],[],[],obj.settings.UI.setup.instruct.vSpacing);
                end
                % draw reference and head indicators
                % reference circle--don't draw if showing eye images and no
                % tracking data available
                if ~qHideSetup
                    drawOrientedPoly(wpnt(1),circVerts,1,[0 0],[0 1; 1 0],refSz,refPosP,[],refClr ,5);
                end
                if qHaveOperatorScreen
                    % no vertical/horizontal offset on operator screen
                    drawOrientedPoly(wpnt(2),circVerts,1,[0 0],[0 1; 1 0],refSz,refPosO,[],refClrO,5);
                end
                % stylized head
                head.draw();
                if qHaveOperatorScreen
                    headO.draw();
                end
                
                % draw buttons
                [mousePos(1), mousePos(2)] = GetMouse();
                [mousePos(1), mousePos(2)] = RemapMouse(wpnt(end), 'AllViews', mousePos(1), mousePos(2));
                but(1).draw(mousePos,qShowEyeImage);
                but(2).draw(mousePos);
                but(3).draw(mousePos);
                
                % draw fixation points
                obj.drawFixPoints(wpnt(1),fixPos,obj.settings.UI.setup.fixBackSize,obj.settings.UI.setup.fixFrontSize,obj.settings.UI.setup.fixBackColor,obj.settings.UI.setup.fixFrontColor);
                
                % drawing done, show
                Screen('Flip',wpnt(1),[],0,0,1);
                
                
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
                    elseif any(strcmpi(keys,'d')) && shiftIsDown
                        % take screenshot
                        takeScreenshot(wpnt(1));
                    elseif any(strcmpi(keys,'o')) && shiftIsDown && qHaveOperatorScreen
                        % take screenshot of operator screen
                        takeScreenshot(wpnt(2));
                    end
                end
            end
            % clean up
            HideCursor;
            obj.buffer.stop('positioning');
            obj.buffer.stop('gaze');
            obj.sendMessage(sprintf('STOP SETUP (%s)',getEyeLbl(obj.settings.calibrateEye)));
            obj.buffer.clearTimeRange('gaze',startT);       % clear buffer from start time until now (now=default third argument)
            obj.buffer.clear('positioning');                % this one is not meant to be kept around (useless as it doesn't have time stamps). So just clear completely.
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
            inputs.baseColor    = 0;
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
                if nargin>3 && ~isempty(rect)
                    inputs.sy = inputs.sy + obj.settings.UI.button.textVOff;
                end
                [~,~,txtbounds,cache] = DrawFormattedText2GDI(wpnt,text,inputs.sx,inputs.xalign,inputs.sy,inputs.yalign,inputs.xlayout,inputs.baseColor,[],inputs.vSpacing,[],[],true);
            end
        end
        
        function cache = positionButtonText(obj, cache, rect, previousOff)
            [sx,sy] = RectCenterd(rect);
            if obj.usingFTGLTextRenderer
                for p=1:length(cache)
                    [~,~,~,cache(p)] = DrawFormattedText2(cache(p),'cacheOnly',true,'sx',sx,'sy',sy,'xalign','center','yalign','center');
                end
            else
                % offset the text to sx,sy (assumes it was centered on 0,0,
                % which is ok for current code)
                for p=1:length(cache)
                    cache.px = cache.px-previousOff(1)+sx;
                    cache.py = cache.py-previousOff(2)+sy;
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
                Screen('gluDisk', wpnt,obj.getColorForWindow( fixBackColor,wpnt), pos(p,1), pos(p,2), sz(1)/2);
                Screen('FillRect',wpnt,obj.getColorForWindow(fixFrontColor,wpnt), rectH);
                Screen('FillRect',wpnt,obj.getColorForWindow(fixFrontColor,wpnt), rectV);
                Screen('gluDisk', wpnt,obj.getColorForWindow( fixBackColor,wpnt), pos(p,1), pos(p,2), sz(2)/2);
            end
        end
        
        function out = DoCalAndVal(obj,wpnt,kCal,out)
            % determine if calibrating or revalidating
            qDoCal = ~isfield(out,'cal');
            
            % get data streams started
            eyeLbl = getEyeLbl(obj.settings.calibrateEye);
            if qDoCal
                calStartT   = obj.sendMessage(sprintf('START CALIBRATION (%s), calibration no. %d',eyeLbl,kCal));
                iVal        = 1;
            else
                if isfield(out,'val')
                    iVal = length(out.val)+1;
                else
                    iVal = 1;
                end
                valStartT = obj.sendMessage(sprintf('START VALIDATION (%s), calibration no. %d, validation no. %d',eyeLbl,kCal,iVal));
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
                [out.cal,tick] = obj.DoCalPointDisplay(wpnt,true,-1,[],kCal==1);
                obj.sendMessage(sprintf('STOP CALIBRATION (%s), calibration no. %d',eyeLbl,kCal));
                out.cal.data = obj.ConsumeAllData(calStartT);
                if out.cal.status==1
                    if ~isempty(obj.settings.cal.pointPos)
                        % if valid calibration retrieve data, so user can select different ones
                        if ~strcmpi(out.cal.result.status(1:7),'Success') % 1:7 so e.g. SuccessLeftEye is also supported
                            % calibration failed, back to setup screen
                            out.cal.status = -3;
                            obj.sendMessage(sprintf('CALIBRATION FAILED (%s), calibration no. %d',eyeLbl,kCal));
                            Screen('TextFont', wpnt(end), obj.settings.UI.cal.errMsg.font, obj.settings.UI.cal.errMsg.style);
                            Screen('TextSize', wpnt(end), obj.settings.UI.cal.errMsg.size);
                            for w=wpnt
                                Screen('FillRect', w, obj.getColorForWindow(obj.settings.cal.bgColor,w));
                            end
                            DrawFormattedText(wpnt(end),obj.settings.UI.cal.errMsg.string,'center','center',obj.getColorForWindow(obj.settings.UI.cal.errMsg.color,wpnt(end)));
                            Screen('Flip',wpnt(1),[],0,0,1);
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
                if isfield(out.cal,'flips')
                    calLastFlip = {tick,out.cal.flips(end)};
                else
                    calLastFlip = {-1};
                end
                
                if out.cal.status~=1
                    obj.StopRecordAll();
                    obj.ClearAllBuffers(calStartT);    % clean up data
                    if out.cal.status~=-1
                        % -1 means restart calibration from start. if we do not
                        % clean up here, we e.g. get a nice animation of the
                        % point back to the center of the screen, or however
                        % the user wants to indicate change of point. Clean up
                        % in all other cases, or we would maintain drawstate
                        % accross setup screens and such.
                        % So, send cleanup message to user function (if any)
                        if isa(obj.settings.cal.drawFunction,'function_handle')
                            obj.settings.cal.drawFunction(wpnt(1),'cleanUp',nan,nan,nan,nan);
                        end
                        for w=wpnt
                            Screen('FillRect', w, obj.getColorForWindow(obj.settings.cal.bgColor,w));
                        end
                        Screen('Flip',wpnt(1),[],0,0,1);
                    end
                    out.status = out.cal.status;
                    return;
                end
            else
                calLastFlip = {-1};
            end
            
            % do validation
            if qDoCal
                % if we just did a cal, add message that now we're entering
                % validation mode
                valStartT = obj.sendMessage(sprintf('START VALIDATION (%s), calibration no. %d, validation no. %d',eyeLbl,kCal,iVal));
                obj.ClearAllBuffers(calStartT);    % clean up data from calibration
            end
            % show display
            out.val{iVal} = obj.DoCalPointDisplay(wpnt,false,calLastFlip{:});
            obj.sendMessage(sprintf('STOP VALIDATION (%s), calibration no. %d, validation no. %d',eyeLbl,kCal,iVal));
            out.val{iVal}.allData = obj.ConsumeAllData(valStartT);
            obj.StopRecordAll();
            obj.ClearAllBuffers(valStartT);    % clean up data
            % compute accuracy etc
            if out.val{iVal}.status==1
                out.val{iVal} = obj.ProcessValData(out.val{iVal});
            end
            
            if out.val{iVal}.status~=-1   % see comment above about why not when -1
                % cleanup message to user function (if any)
                if isa(obj.settings.cal.drawFunction,'function_handle')
                    obj.settings.cal.drawFunction(wpnt(1),'cleanUp',nan,nan,nan,nan);
                end
            end
            out.status = out.val{iVal}.status;
            
            % clear flip
            for w=wpnt
                Screen('FillRect', w, obj.getColorForWindow(obj.settings.cal.bgColor,w));
            end
            Screen('Flip',wpnt(1),[],0,0,1);
        end
        
        function data = ConsumeAllData(obj,varargin)
            data.gaze           = obj.buffer.consumeTimeRange('gaze',varargin{:});
            data.eyeImages      = obj.buffer.consumeTimeRange('eyeImage',varargin{:});
            data.externalSignals= obj.buffer.consumeTimeRange('externalSignal',varargin{:});
            data.timeSync       = obj.buffer.consumeTimeRange('timeSync',varargin{:});
            % NB: positioning stream is not consumed as it will be useless
            % for later analysis (it doesn't have timestamps, and is meant
            % for visualization only).
        end
        
        function ClearAllBuffers(obj,varargin)
            % clear all buffer, optionally only within specified time range
            obj.buffer.clearTimeRange('gaze',varargin{:});
            obj.buffer.clearTimeRange('eyeImage',varargin{:});
            obj.buffer.clearTimeRange('externalSignal',varargin{:});
            obj.buffer.clearTimeRange('timeSync',varargin{:});
            if nargin<2
                % positioning stream doesn't have timestamps, and clear can
                % thus only be called on it without a time range
                obj.buffer.clear('positioning');
            end
        end
        
        function StopRecordAll(obj)
            obj.buffer.stop('gaze');
            obj.buffer.stop('eyeImage');
            obj.buffer.stop('externalSignal');
            obj.buffer.stop('timeSync');
            obj.buffer.stop('positioning');
        end
        
        function [out,tick] = DoCalPointDisplay(obj,wpnt,qCal,tick,lastFlip,qIsFirstCalAttempt)
            % status output (in out.status):
            %  1: finished succesfully (you should out.result.status though
            %     to verify that the eye tracker agrees that the
            %     calibration was successful)
            %  2: skip calibration and continue with task (shift+s)
            % -1: restart calibration/validation (r)
            % -3: abort calibration/validation and go back to setup (escape
            %     key)
            % -5: Exit completely (shift+escape)
            if nargin<6 || isempty(qIsFirstCalAttempt)
                qIsFirstCalAttempt = false;
            end
            qHaveOperatorScreen = ~isscalar(wpnt);
            qShowEyeImage       = qHaveOperatorScreen && obj.buffer.hasStream('eyeImage');
            
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            
            % prep colors
            for w=length(wpnt):-1:1
                bgClr{w} = obj.getColorForWindow(obj.settings.cal.bgColor,wpnt(w));
            end
            
            % timing is done in ticks (display refreshes) instead of time.
            % If multiple screens, get lowest fs as that will determine
            % tick rate
            for w=length(wpnt):-1:1
                fs(w) = Screen('NominalFrameRate',wpnt(w));
            end
            
            % start recording eye images if not already started
            eyeStartTime    = [];
            texs            = [0 0];
            szs             = [];
            eyeImageRect    = repmat({zeros(1,4)},1,2);
            if qShowEyeImage
                if ~obj.settings.cal.doRecordEyeImages
                    eyeStartTime    = obj.getTimeAsSystemTime();
                    obj.buffer.start('eyeImage');
                end
            end
            
            % setup
            if qCal
                points              = obj.settings.cal.pointPos;
                paceIntervalTicks   = ceil(obj.settings.cal.paceDuration   *min(fs));
                out.pointStatus     = {};
                extraInp            = {};
                if ~strcmp(obj.settings.calibrateEye,'both')
                    extraInp            = {obj.settings.calibrateEye};
                end
                stage               = 'cal';
            else
                points              = obj.settings.val.pointPos;
                paceIntervalTicks   = ceil(obj.settings.val.paceDuration   *min(fs));
                collectInterval     = ceil(obj.settings.val.collectDuration*min(fs));
                nDataPoint          = ceil(obj.settings.val.collectDuration*obj.settings.freq);
                tick0v              = nan;
                out.gazeData        = [];
                stage               = 'val';
            end
            nPoint = size(points,1);
            if nPoint==0
                out.status = 1;
                return;
            end
            if qHaveOperatorScreen
                oPoints = bsxfun(@times,points,obj.scrInfo.resolution{2});
                drawOperatorScreenFun = @(idx,eS,t,s,eI) obj.drawOperatorScreen(wpnt(2),oPoints,idx,eS,t,s,eI);
            end
            
            points = [points bsxfun(@times,points,obj.scrInfo.resolution{1}) [1:nPoint].' ones(nPoint,1)]; %#ok<NBRAK>
            if (qCal && obj.settings.cal.doRandomPointOrder) || (~qCal && obj.settings.val.doRandomPointOrder)
                points = points(randperm(nPoint),:);
            end
            if isa(obj.settings.cal.drawFunction,'function_handle')
                drawFunction = obj.settings.cal.drawFunction;
            else
                drawFunction = @obj.drawFixationPointDefault;
            end
            
            % if calibrating, make sure we start with a clean slate:
            % discard data from all points, if any.
            % Specifically, Tobii eye trackers have a FIFO buffer of
            % samples per calibration coordinate. This buffer may be longer
            % than the amount of samples collected during a single
            % calibration attempt, meaning that two consecutive
            % calibrations may not be fully independent from each other.
            % This appears to be unwanted in almost all cases, so here we
            % clear the buffers for each calibration coordinate before we
            % start collecting data for them.
            % NB: already at clean state if first calibration (for this
            % eye) after mode entered, because entering calibration mode
            % clears all buffers, so can skip
            if qCal && ~qIsFirstCalAttempt
                for p=1:size(points,1)
                    % queue up all the discard actions quickly
                    obj.buffer.calibrationDiscardData(points(p,1:2),extraInp{:});
                end
                % now we expect size(points,1) completed DiscardData
                % reports as well
                nReply = 0;
                while true
                    computeResult  = obj.buffer.calibrationRetrieveResult();
                    nReply  = nReply + (~isempty(computeResult) && strcmp(computeResult.workItem.action,'DiscardData'));
                    if nReply==size(points,1)
                        break;
                    end
                    WaitSecs('YieldSecs',0.001);    % don't sping too hard
                end
            end
            
            % anchor timing, get ready for displaying calibration points
            if nargin<5 || isempty(lastFlip)    % first in sequence
                flipT   = GetSecs();
            else
                flipT   = lastFlip;
            end
            qStartOfSequence = tick==-1;        % are we at the start of a calibrate/validate sequence?
            
            % prepare output
            out.status = 1; % calibration went ok, unless otherwise stated
            
            % clear screen, anchor timing, get ready for displaying calibration points
            out.flips    = flipT;
            out.pointPos = [];
            
            currentPoint    = 0;
            needManualAccept= @(cp) obj.settings.cal.autoPace==0 || (obj.settings.cal.autoPace==1 && qStartOfSequence && cp==1);
            advancePoint    = true;
            pointOff        = 0;
            nCollecting     = 0;
            tick0p          = nan;
            while true
                tick        = tick+1;
                nextFlipT   = out.flips(end)+1/1000;
                if advancePoint
                    % notify current point collected, if user defined a
                    % function for that
                    if currentPoint
                        if qCal
                            fun = obj.settings.cal.pointNotifyFunction;
                            extra = {out.pointStatus{currentPoint}}; %#ok<CCAT1>
                        else
                            fun = obj.settings.val.pointNotifyFunction;
                            extra = {};
                        end
                        if isa(fun,'function_handle')
                            fun(obj,currentPoint,points(currentPoint,1:2),points(currentPoint,3:4),stage,extra{:});
                        end
                    end
                    
                    % move to display next point
                    currentPoint = currentPoint+1;
                    % check any points left to do
                    if currentPoint>size(points,1)
                        pointOff = 1;
                        break;
                    end
                    out.pointPos(end+1,1:3) = points(currentPoint,[5 3 4]);
                    % check if manual acceptance needed for this point
                    haveAccepted = ~needManualAccept(currentPoint);     % if not needed, we already have it
                    
                    % get ready for next point
                    qWaitForAllowAccept = true;
                    advancePoint    = false;
                    qNewPoint       = true;
                    tick0p          = nan;
                    drawCmd         = 'new';
                end
                
                % call drawer function
                for w=1:length(wpnt)
                    Screen('FillRect', wpnt(w), bgClr{w});   % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
                end
                if qHaveOperatorScreen
                    [texs,szs,eyeImageRect] = drawOperatorScreenFun(points(currentPoint,5),eyeStartTime,texs,szs,eyeImageRect);
                end
                qAllowAccept        = drawFunction(wpnt(1),drawCmd,currentPoint,points(currentPoint,3:4),tick,stage);
                drawCmd             = 'draw';   % clear any command other than 'draw'
                if qWaitForAllowAccept && qAllowAccept
                    tick0p              = tick;
                    qWaitForAllowAccept = false;
                end
                
                out.flips(end+1)    = Screen('Flip',wpnt(1),nextFlipT,0,0,1);
                if qNewPoint
                    obj.sendMessage(sprintf('POINT ON %d (%.0f %.0f)',currentPoint,points(currentPoint,3:4)),out.flips(end));
                    nCollecting     = 0;
                    qNewPoint       = false;
                end
                
                % get user response
                [~,~,~,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                if any(keyCode)
                    keys = KbName(keyCode);
                    if any(strcmpi(keys,'space')) && qAllowAccept
                        % if in semi-automatic mode and first point, or if
                        % manual and any point, space bars triggers
                        % accepting calibration point
                        haveAccepted    = true;
                    elseif any(strcmpi(keys,'r'))
                        out.status = -1;
                        break;
                    elseif any(strcmpi(keys,'escape'))
                        % NB: no need to cancel calibration here,
                        % leaving calibration mode is done by caller
                        if shiftIsDown
                            out.status = -5;
                        else
                            out.status = -3;
                        end
                        break;
                    elseif any(strcmpi(keys,'backspace')) && (~haveAccepted || tick<=tick0p+paceIntervalTicks)
                        % motify user requested to redo the current
                        % calibration/validation point, if not too late
                        % because already accepted the point started data
                        % collection for it)
                        drawCmd             = 'redo';
                        % wait again for at least paceInterval ticks before
                        % will start data collection
                        tick0p              = nan;
                        qWaitForAllowAccept = true;
                    elseif any(strcmpi(keys,'s')) && shiftIsDown
                        % skip calibration
                        out.status = 2;
                        break;
                    elseif any(strcmpi(keys,'d')) && shiftIsDown
                        % take screenshot of participant screen
                        takeScreenshot(wpnt(1));
                    elseif any(strcmpi(keys,'o')) && shiftIsDown && qHaveOperatorScreen
                        % take screenshot of operator screen
                        takeScreenshot(wpnt(2));
                    end
                end
                
                % accept point
                if haveAccepted && tick>tick0p+paceIntervalTicks
                    if qCal
                        if ~nCollecting
                            % start collection
                            obj.buffer.calibrationCollectData(points(currentPoint,1:2),extraInp{:});
                            nCollecting = 1;
                        else
                            % check status
                            computeResult  = obj.buffer.calibrationRetrieveResult();
                            if ~isempty(computeResult)
                                if strcmp(computeResult.workItem.action,'CollectData') && computeResult.status==0     % TOBII_RESEARCH_STATUS_OK
                                    % success, next point
                                    advancePoint = true;
                                else
                                    % failed
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
                                end
                            end
                            if advancePoint
                                out.pointStatus{currentPoint} = computeResult;
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
            lastPoint = currentPoint-pointOff;
            obj.sendMessage(sprintf('POINT OFF %d',lastPoint),out.flips(end));
            
            % get calibration result while keeping animation on the screen
            % alive for a smooth experience
            if qCal && out.status==1
                % compute calibration
                obj.buffer.calibrationComputeAndApply();
                computeResult   = [];
                calData         = [];
                flipT           = out.flips(end);
                while true
                    tick    = tick+1;
                    for w=1:length(wpnt)
                        Screen('FillRect', wpnt(w), bgClr{w});
                    end
                    if qHaveOperatorScreen
                        [texs,szs,eyeImageRect] = drawOperatorScreenFun([],eyeStartTime,texs,szs,eyeImageRect);
                    end
                    drawFunction(wpnt(1),'draw',lastPoint,points(lastPoint,3:4),tick,stage);
                    flipT   = Screen('Flip',wpnt(1),flipT+1/1000,0,0,1);
                    
                    % first get computeAndApply result, then get
                    if isempty(computeResult)
                        computeResult = obj.buffer.calibrationRetrieveResult();
                        if ~isempty(computeResult)
                            if ~strcmp(computeResult.workItem.action,'Compute')
                                % not what we were waiting for, skip
                                computeResult = [];
                            elseif ~strcmpi(computeResult.calibrationResult.status(1:7),'Success') % 1:7 so e.g. SuccessLeftEye is also supported
                                % calibration unsuccessful, we bail now
                                break;
                            else
                                % issue command to get calibration data
                                obj.buffer.calibrationGetData();
                            end
                        end
                    else
                        calData = obj.buffer.calibrationRetrieveResult();
                        if ~isempty(calData)
                            if ~strcmp(calData.workItem.action,'GetCalibrationData')
                                % not what we were waiting for, skip
                                calData = [];
                            else
                                % done
                                break;
                            end
                        end
                    end
                end
                out.result = fixupTobiiCalResult(computeResult.calibrationResult,obj.calibrateLeftEye,obj.calibrateRightEye);
                if ~isempty(calData)
                    out.computedCal = calData.calibrationData;
                end
            end
            
            if qShowEyeImage && ~obj.settings.cal.doRecordEyeImages
                obj.buffer.stop('eyeImage');
                obj.buffer.clearTimeRange('eyeImage',eyeStartTime);     % clear buffer from start time until now (now=default third argument)
                if any(texs)
                    Screen('Close',texs(texs>0));
                end
            end
        end
        
        function [texs,szs,eyeImageRect] = drawOperatorScreen(obj,wpnt,pos,highlight,eyeStartTime,texs,szs,eyeImageRect)
            % draw eye image
            if nargin>4
                % get eye image
                eyeIm       = obj.buffer.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward (default third argument: now)
                [texs,szs]  = UploadImages(texs,szs,wpnt,eyeIm);
                
                % update eye image locations if size of returned eye image changed
                if (~any(isnan(szs(:,1))) && any(szs(:,1).'~=diff(reshape(eyeImageRect{1},2,2)))) || (~any(isnan(szs(:,2))) && any(szs(:,2).'~=diff(reshape(eyeImageRect{1},2,2))))
                    margin = 20;
                    eyeImageRect{1} = OffsetRect([0 0 szs(:,1).'],obj.scrInfo.center{2}(1)-szs(1,1)-margin/2,obj.scrInfo.center{2}(2)-szs(2,1)/2);
                    eyeImageRect{2} = OffsetRect([0 0 szs(:,2).'],obj.scrInfo.center{2}(1)         +margin/2,obj.scrInfo.center{2}(2)-szs(2,2)/2);
                end
                if texs(1)
                    Screen('DrawTexture', wpnt(end), texs(1),[],eyeImageRect{1});
                end
                if texs(2)
                    Screen('DrawTexture', wpnt(end), texs(2),[],eyeImageRect{2});
                end
            else
                [texs,szs,eyeImageRect] = deal([]);
            end
            % draw indicator which point is being shown
            if ~isempty(highlight)
                Screen('gluDisk', wpnt,obj.getColorForWindow([255 0 0],wpnt), pos(highlight,1), pos(highlight,2), obj.settings.cal.fixBackSize*1.5/2);
            end
            % draw all points
            obj.drawFixationPointDefault(wpnt,[],[],pos);
            % draw live data
            clrs = {[],[]};
            if obj.calibrateLeftEye
                clrs{1} = obj.getColorForWindow(obj.settings.UI.val.eyeColors{1},wpnt);
            end
            if obj.calibrateRightEye
                clrs{2} = obj.getColorForWindow(obj.settings.UI.val.eyeColors{2},wpnt);
            end
            drawLiveData(wpnt,obj.buffer,500,obj.settings.freq,clrs{:},4,obj.scrInfo.resolution{2});
        end
        
        function qAllowAcceptKey = drawFixationPointDefault(obj,wpnt,~,~,pos,~,~)
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
            pointOnScreenDA  = (valPointPos./obj.scrInfo.resolution{1}).';
            pointOnScreenUCS = obj.ADCSToUCS(pointOnScreenDA);
            offOnScreenADCS  = bsxfun(@minus,gazeData.gazePoint.onDisplayArea,pointOnScreenDA);
            offOnScreenCm    = bsxfun(@times,offOnScreenADCS,[obj.geom.displayArea.width,obj.geom.displayArea.height].');
            offOnScreenDir   = atan2(offOnScreenCm(2,:),offOnScreenCm(1,:));
            
            vecToPoint  = bsxfun(@minus,pointOnScreenUCS,gazeData.gazeOrigin.inUserCoords);
            gazeVec     = gazeData.gazePoint.inUserCoords-gazeData.gazeOrigin.inUserCoords;
            angs2D      = AngleBetweenVectors(vecToPoint,gazeVec);
            out.offs    = bsxfun(@times,angs2D,[cos(offOnScreenDir); sin(offOnScreenDir)]);
            out.acc     = mean(abs(out.offs),2,'omitnan');
            out.acc2D   = mean(    angs2D   ,2,'omitnan');
            
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
            xVec = obj.geom.displayArea.topRight-obj.geom.displayArea.topLeft;
            yVec = obj.geom.displayArea.bottomRight-obj.geom.displayArea.topRight;
            out  = bsxfun(@plus,obj.geom.displayArea.topLeft,bsxfun(@times,data(1,:),xVec)+bsxfun(@times,data(2,:),yVec));
        end
        
        function [cal,selection] = showCalValResult(obj,wpnt,cal,selection)
            % status output:
            %  1: calibration/validation accepted, continue (a)
            %  2: just continue with task (shift+s)
            % -1: restart calibration (escape key)
            % -2: redo validation only (v)
            % -3: go back to setup (s)
            % -5: exit completely (shift+escape)
            %
            % additional buttons
            % c: chose other calibration (if have more than one valid)
            % g: show gaze (and fixation points)
            % t: toggle between seeing validation results and calibration
            %    result
            % shift-d: take screenshot of participant screen
            % shift-o: take screenshot of operator screen
            qHaveOperatorScreen     = ~isscalar(wpnt);
            
            % for cursor interaction, need to correct rect position
            % based on global rect of window
            gRectOff                = Screen('GlobalRect',wpnt(end));
            gRectOff                = gRectOff([1 2 1 2]);
            
            % find how many valid calibrations we have:
            iValid = getValidCalibrations(cal);
            if ~isempty(iValid) && ~ismember(selection,iValid)  % exception, when we have no valid calibrations at all (happens when using zero-point calibration)
                % this happens if setup cancelled to go directly to this validation
                % viewer
                selection = iValid(end);
            end
            qHasCal                 = ~isempty(cal{selection}.cal.result);
            qHaveMultipleValidCals  = ~isempty(iValid) && ~isscalar(iValid);
            iVal                    = find(cellfun(@(x) x.status, cal{selection}.val)==1,1,'last');
            
            % setup text for buttons
            Screen('TextFont',  wpnt(end), obj.settings.UI.button.val.text.font, obj.settings.UI.button.val.text.style);
            Screen('TextSize',  wpnt(end), obj.settings.UI.button.val.text.size);
            
            % set up buttons
            funs    = struct('textCacheGetter',@obj.getTextCache, 'textCacheDrawer', @obj.drawCachedText, 'cacheOffSetter', @obj.positionButtonText, 'colorGetter', @(clr) obj.getColorForWindow(clr,wpnt(end)));
            but(1)  = PTBButton(obj.settings.UI.button.val.recal   ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(2)  = PTBButton(obj.settings.UI.button.val.reval   ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(3)  = PTBButton(obj.settings.UI.button.val.continue,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(4)  = PTBButton(obj.settings.UI.button.val.selcal  , qHaveMultipleValidCals, wpnt(end), funs, obj.settings.UI.button.margins);
            but(5)  = PTBButton(obj.settings.UI.button.val.setup   ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(6)  = PTBButton(obj.settings.UI.button.val.toggGaze,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(7)  = PTBButton(obj.settings.UI.button.val.toggCal ,        qHasCal        , wpnt(end), funs, obj.settings.UI.button.margins);
            % 1. below screen
            % position them
            butRectsBase= cat(1,but([but(1:4).visible]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution{1}(2)*.97);
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution{1}(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                butRects          = num2cell(butRects,2);
                [but((1:length(but))<=4&[but.visible]).rect] = butRects{:};
            end
            
            % 2. atop screen
            % position them
            yPosTop             = .02*obj.scrInfo.resolution{1}(2);
            buttonOff           = 900;
            if but(5).visible
                but(5).rect     = OffsetRect(but(5).rect,obj.scrInfo.center{1}(1)-buttonOff/2-but(5).rect(3),yPosTop);
            end
            if but(6).visible
                but(6).rect     = OffsetRect(but(6).rect,obj.scrInfo.center{1}(1)+buttonOff/2,yPosTop);
            end
            
            % 3. left side
            if but(7).visible
                % position it
                but(7).rect     = OffsetRect(but(7).rect,0,yPosTop);
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
                menuBackRect    = [-.5*width+obj.scrInfo.center{1}(1)-margin -.5*totHeight+obj.scrInfo.center{1}(2)-margin .5*width+obj.scrInfo.center{1}(1)+margin .5*totHeight+obj.scrInfo.center{1}(2)+margin];
                menuBackRectGlobal  = menuBackRect+gRectOff;
                % menuRects
                menuRects       = repmat([-.5*width+obj.scrInfo.center{1}(1) -height/2+obj.scrInfo.center{1}(2) .5*width+obj.scrInfo.center{1}(1) height/2+obj.scrInfo.center{1}(2)],length(iValid),1);
                menuRects       = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                menuRectsGlobal = bsxfun(@plus,menuRects,gRectOff);
                % text in each rect
                for c=length(iValid):-1:1
                    % find the active/last valid validation for this
                    % calibration
                    aVal = find(cellfun(@(x) x.status, cal{iValid(c)}.val)==1,1,'last');
                    % acc field is [lx rx; ly ry]
                    [strl,strr,strsep] = deal('');
                    if obj.calibrateLeftEye
                        strl = sprintf( '<color=%1$s>Left<color>: %2$.2f%5$c, (%3$.2f%5$c,%4$.2f%5$c)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{1}),cal{iValid(c)}.val{aVal}.acc2D( 1 ),cal{iValid(c)}.val{aVal}.acc(1, 1 ),cal{iValid(c)}.val{aVal}.acc(2, 1 ),char(176));
                    end
                    if obj.calibrateRightEye
                        idx = 1+obj.calibrateLeftEye;
                        strr = sprintf('<color=%1$s>Right<color>: %2$.2f%5$c, (%3$.2f%5$c,%4$.2f%5$c)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{2}),cal{iValid(c)}.val{aVal}.acc2D(idx),cal{iValid(c)}.val{aVal}.acc(1,idx),cal{iValid(c)}.val{aVal}.acc(2,idx),char(176));
                    end
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        strsep = ', ';
                    end
                    str = sprintf('(%d): %s%s%s',c,strl,strsep,strr);
                    Screen('TextFont',  wpnt(end), obj.settings.UI.val.menu.text.font, obj.settings.UI.val.menu.text.style);
                    Screen('TextSize',  wpnt(end), obj.settings.UI.val.menu.text.size);
                    menuTextCache(c) = obj.getTextCache(wpnt(end),str,menuRects(c,:),'baseColor',obj.settings.UI.val.menu.text.color);
                end
            end
            
            % setup message for participant if we have an operator screen
            if qHaveOperatorScreen && ~isempty(obj.settings.UI.val.waitMsg.string)
                Screen('TextFont',  wpnt(end), obj.settings.UI.val.waitMsg.font, obj.settings.UI.val.waitMsg.style);
                Screen('TextSize',  wpnt(end), obj.settings.UI.val.waitMsg.size);
                waitTextCache = obj.getTextCache(wpnt(1),obj.settings.UI.val.waitMsg.string,[0 0 obj.scrInfo.resolution{1}],'baseColor',obj.settings.UI.val.waitMsg.color);
            end
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution{1},4,1);
            
            % prep colors
            bgClr               = obj.getColorForWindow(obj.settings.UI.val.bgColor,wpnt(1));
            eyeClrs             = cellfun(@(x) obj.getColorForWindow(x,wpnt(end)),obj.settings.UI.val.eyeColors,'uni',false);
            menuBgClr           = obj.getColorForWindow(obj.settings.UI.val.menu.bgColor,wpnt(end));
            menuItemClr         = obj.getColorForWindow(obj.settings.UI.val.menu.itemColor      ,wpnt(end));
            menuItemClrActive   = obj.getColorForWindow(obj.settings.UI.val.menu.itemColorActive,wpnt(end));
            hoverBgClr          = obj.getColorForWindow(obj.settings.UI.val.hover.bgColor,wpnt(end));
            for w=length(wpnt):-1:1
                onlineGazeClr(:,w) = cellfun(@(x) obj.getColorForWindow(x,wpnt(w)),obj.settings.UI.val.onlineGaze.eyeColors,'uni',false);
            end
            if qHaveOperatorScreen
                bgClrO      = obj.getColorForWindow(obj.settings.UI.val.bgColor,wpnt(2));
            end
            
            qDoneCalibSelection = false;
            qToggleSelectMenu   = true;
            qSelectMenuOpen     = true;     % gets set to false on first draw as toggle above is true (hack to make sure we're set up on first entrance of draw loop)
            qChangeMenuArrow    = false;
            qToggleGaze         = false;
            qShowGazeToAll      = false;
            qShowGaze           = false;
            qUpdateCalDisplay   = true;
            qSelectedCalChanged = false;
            qAwaitingCalChange  = false;
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
                        obj.buffer.stop('gaze');
                        obj.buffer.clearTimeRange('gaze',gazeStartT);
                    else
                        % switch on
                        gazeStartT = obj.getTimeAsSystemTime();
                        obj.buffer.start('gaze');
                    end
                    qShowGaze   = ~qShowGaze;
                    qToggleGaze = false;
                end
                
                % setup fixation point positions for cal or val
                if qUpdateCalDisplay || qSelectedCalChanged || qAwaitingCalChange
                    qUpdateNow = false;
                    if qSelectedCalChanged
                        % load requested cal
                        obj.loadOtherCal(cal{newSelection});
                        qSelectedCalChanged = false;
                        qAwaitingCalChange = true;
                    else
                        qUpdateNow = true;
                    end
                    if qAwaitingCalChange || qUpdateNow
                        if qAwaitingCalChange
                            result = obj.buffer.calibrationRetrieveResult();
                        end
                        if qUpdateNow || (~isempty(result) && strcmp(result.workItem.action,'ApplyCalibrationData'))
                            if ~qUpdateNow && result.status~=0      % TOBII_RESEARCH_STATUS_OK
                                error('%s',result.statusString)
                            end
                            if qAwaitingCalChange
                                % calibration change has come through, make
                                % needed updates
                                selection = newSelection;
                                qAwaitingCalChange = false;
                                qHasCal = ~isempty(cal{selection}.cal.result);
                                iVal    = find(cellfun(@(x) x.status, cal{selection}.val)==1,1,'last');
                                if ~qHasCal && qShowCal
                                    qShowCal            = false;
                                    % toggle selection menu to trigger updating of
                                    % cursors, but make sure menu doesn't actually
                                    % open by temporarily changing its state
                                    qToggleSelectMenu   = true;
                                    qSelectMenuOpen     = ~qSelectMenuOpen;
                                end
                                if ~qHasCal
                                    but(7).visible    = false;
                                elseif obj.settings.UI.button.val.toggCal.visible
                                    but(7).visible    = true;
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
                            Screen('TextFont', wpnt(end), obj.settings.UI.val.avg.text.font, obj.settings.UI.val.avg.text.style);
                            Screen('TextSize', wpnt(end), obj.settings.UI.val.avg.text.size);
                            [strl,strr,strsep] = deal('');
                            if obj.calibrateLeftEye
                                strl = sprintf(' <color=%1$s>Left eye<color>:  %2$.2f%8$c, (%3$.2f%8$c,%4$.2f%8$c)   %5$.2f%8$c   %6$.2f%8$c  %7$3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{1}),cal{selection}.val{iVal}.acc2D( 1 ),cal{selection}.val{iVal}.acc(1, 1 ),cal{selection}.val{iVal}.acc(2, 1 ),cal{selection}.val{iVal}.STD2D( 1 ),cal{selection}.val{iVal}.RMS2D( 1 ),cal{selection}.val{iVal}.dataLoss( 1 )*100,char(176));
                            end
                            if obj.calibrateRightEye
                                idx = 1+obj.calibrateLeftEye;
                                strr = sprintf('<color=%1$s>Right eye<color>:  %2$.2f%8$c, (%3$.2f%8$c,%4$.2f%8$c)   %5$.2f%8$c   %6$.2f%8$c  %7$3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{2}),cal{selection}.val{iVal}.acc2D(idx),cal{selection}.val{iVal}.acc(1,idx),cal{selection}.val{iVal}.acc(2,idx),cal{selection}.val{iVal}.STD2D(idx),cal{selection}.val{iVal}.RMS2D(idx),cal{selection}.val{iVal}.dataLoss(idx)*100,char(176));
                            end
                            if obj.calibrateLeftEye && obj.calibrateRightEye
                                strsep = '\n';
                            end
                            valText = sprintf('<u>Validation<u>    <i>offset 2D, (X,Y)      SD    RMS-S2S  loss<i>\n%s%s%s',strl,strsep,strr);
                            valInfoTopTextCache = obj.getTextCache(wpnt(end),valText,OffsetRect([-5 0 5 10],obj.scrInfo.resolution{1}(1)/2,.02*obj.scrInfo.resolution{1}(2)),'vSpacing',obj.settings.UI.val.avg.text.vSpacing,'yalign','top','xlayout','left','baseColor',obj.settings.UI.val.avg.text.color);
                            
                            % get info about where points were on screen
                            if qShowCal
                                nPoints  = length(cal{selection}.cal.result.points);
                            else
                                nPoints  = size(cal{selection}.val{iVal}.pointPos,1);
                            end
                            calValPos   = zeros(nPoints,2);
                            if qShowCal
                                for p=1:nPoints
                                    calValPos(p,:)  = cal{selection}.cal.result.points(p).position.'.*obj.scrInfo.resolution{1};
                                end
                            else
                                for p=1:nPoints
                                    calValPos(p,:)  = cal{selection}.val{iVal}.pointPos(p,2:3);
                                end
                            end
                            % get rects around validation points
                            if qShowCal
                                calValRects         = [];
                                calValRectsGlobal   = [];
                            else
                                calValRects = zeros(size(cal{selection}.val{iVal}.pointPos,1),4);
                                for p=1:size(cal{selection}.val{iVal}.pointPos,1)
                                    calValRects(p,:)= CenterRectOnPointd([0 0 fixPointRectSz fixPointRectSz],calValPos(p,1),calValPos(p,2));
                                end
                                calValRectsGlobal = bsxfun(@plus,calValRects,gRectOff);
                            end
                            qUpdateCalDisplay   = false;
                            pointToShowInfoFor  = nan;      % close info display, if any
                        end
                    end
                end
                
                % setup cursors
                if qToggleSelectMenu
                    butRects            = cat(1,but.rect);
                    butRectsGlobal      = bsxfun(@plus,butRects,gRectOff);
                    currentMenuSel      = find(selection==iValid);
                    qSelectMenuOpen     = ~qSelectMenuOpen;
                    qChangeMenuArrow    = qSelectMenuOpen;  % if opening, also set arrow, so this should also be true
                    qToggleSelectMenu   = false;
                    if qSelectMenuOpen
                        cursors.rect    = [num2cell(menuRectsGlobal.',1) num2cell(butRectsGlobal(1:3,:).',1)];
                        cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,size(menuRectsGlobal,1)+3); % clickable items
                    else
                        cursors.rect    = num2cell(butRectsGlobal.',1);
                        cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,length(cursors.rect));      % clickable items
                    end
                    
                    cursors.other   = obj.settings.UI.cursor.normal;                                % default
                    cursors.qReset  = false;
                    % NB: don't reset cursor to invisible here as it will then flicker every
                    % time you click something. default behaviour is good here
                    cursor = cursorUpdater(cursors);
                end
                if qChangeMenuArrow
                    % setup arrow that can be moved with arrow keys
                    rect = menuRects(currentMenuSel,:);
                    rect(3) = rect(1)+RectWidth(rect)*.07;
                    menuActiveCache = obj.getTextCache(wpnt(end),' <color=ff0000>-><color>',rect);
                    qChangeMenuArrow = false;
                end
                
                % setup overlay with data quality info for specific point
                if ~isnan(openInfoForPoint)
                    pointToShowInfoFor = openInfoForPoint;
                    openInfoForPoint   = nan;
                    % 1. prepare text
                    Screen('TextFont', wpnt(end), obj.settings.UI.val.hover.text.font, obj.settings.UI.val.hover.text.style);
                    Screen('TextSize', wpnt(end), obj.settings.UI.val.hover.text.size);
                    if obj.calibrateLeftEye && obj.calibrateRightEye
                        lE = cal{selection}.val{iVal}.quality(pointToShowInfoFor).left;
                        rE = cal{selection}.val{iVal}.quality(pointToShowInfoFor).right;
                        str = sprintf('Offset:       <color=%1$s>%3$.2f%15$c, (%4$.2f%15$c,%5$.2f%15$c)<color>, <color=%2$s>%9$.2f%15$c, (%10$.2f%15$c,%11$.2f%15$c)<color>\nPrecision SD:        <color=%1$s>%6$.2f%15$c<color>                 <color=%2$s>%12$.2f%15$c<color>\nPrecision RMS:       <color=%1$s>%7$.2f%15$c<color>                 <color=%2$s>%13$.2f%15$c<color>\nData loss:            <color=%1$s>%8$3.0f%%<color>                  <color=%2$s>%14$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{1}),clr2hex(obj.settings.UI.val.hover.text.eyeColors{2}),lE.acc2D,abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.dataLoss*100,rE.acc2D,abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.dataLoss*100,char(176));
                    elseif obj.calibrateLeftEye
                        lE = cal{selection}.val{iVal}.quality(pointToShowInfoFor).left;
                        str = sprintf('Offset:       <color=%1$s>%2$.2f%8$c, (%3$.2f%8$c,%4$.2f%8$c)<color>\nPrecision SD:        <color=%1$s>%5$.2f%8$c<color>\nPrecision RMS:       <color=%1$s>%6$.2f%8$c<color>\nData loss:            <color=%1$s>%7$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{1}),lE.acc2D,abs(lE.acc(1)),abs(lE.acc(2)),lE.STD2D,lE.RMS2D,lE.dataLoss*100,char(176));
                    elseif obj.calibrateRightEye
                        rE = cal{selection}.val{iVal}.quality(pointToShowInfoFor).right;
                        str = sprintf('Offset:       <color=%1$s>%2$.2f%8$c, (%3$.2f%8$c,%4$.2f%8$c)<color>\nPrecision SD:        <color=%1$s>%5$.2f%8$c<color>\nPrecision RMS:       <color=%1$s>%6$.2f%8$c<color>\nData loss:            <color=%1$s>%7$3.0f%%<color>',clr2hex(obj.settings.UI.val.hover.text.eyeColors{2}),rE.acc2D,abs(rE.acc(1)),abs(rE.acc(2)),rE.STD2D,rE.RMS2D,rE.dataLoss*100,char(176));
                    end
                    [pointTextCache,txtbounds] = obj.getTextCache(wpnt(end),str,[],'xlayout','left','baseColor',obj.settings.UI.val.hover.text.color);
                    % get box around text
                    margin = 10;
                    infoBoxRect = GrowRect(txtbounds,margin,margin);
                    infoBoxRect = OffsetRect(infoBoxRect,-infoBoxRect(1),-infoBoxRect(2));  % make sure rect is [0 0 w h]
                end
                
                while true % draw loop
                    Screen('FillRect', wpnt(1), bgClr);
                    if qHaveOperatorScreen
                        Screen('FillRect', wpnt(2), bgClrO);
                    end
                    % draw validation screen image
                    % draw calibration/validation points
                    obj.drawFixPoints(wpnt(end),calValPos,obj.settings.UI.val.fixBackSize,obj.settings.UI.val.fixFrontSize,obj.settings.UI.val.fixBackColor,obj.settings.UI.val.fixFrontColor);
                    % draw captured data in characteristic tobii plot
                    for p=1:nPoints
                        if qShowCal
                            myCal = cal{selection}.cal.result;
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = strcmp(myCal.points(p).samples. left.validity,'validAndUsed');
                                lEpos= bsxfun(@times,myCal.points(p).samples. left.position(:,qVal),obj.scrInfo.resolution{1}.');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = strcmp(myCal.points(p).samples.right.validity,'validAndUsed');
                                rEpos= bsxfun(@times,myCal.points(p).samples.right.position(:,qVal),obj.scrInfo.resolution{1}.');
                            end
                        else
                            myVal = cal{selection}.val{iVal};
                            bpos = calValPos(p,:).';
                            % left eye
                            if obj.calibrateLeftEye
                                qVal = myVal.gazeData(p). left.gazePoint.valid;
                                lEpos= bsxfun(@times,myVal.gazeData(p). left.gazePoint.onDisplayArea(:,qVal),obj.scrInfo.resolution{1}.');
                            end
                            % right eye
                            if obj.calibrateRightEye
                                qVal = myVal.gazeData(p).right.gazePoint.valid;
                                rEpos= bsxfun(@times,myVal.gazeData(p).right.gazePoint.onDisplayArea(:,qVal),obj.scrInfo.resolution{1}.');
                            end
                        end
                        if obj.calibrateLeftEye  && ~isempty(lEpos)
                            Screen('DrawLines',wpnt(end),reshape([repmat(bpos,1,size(lEpos,2)); lEpos],2,[]),1,eyeClrs{1},[],2);
                        end
                        if obj.calibrateRightEye && ~isempty(rEpos)
                            Screen('DrawLines',wpnt(end),reshape([repmat(bpos,1,size(rEpos,2)); rEpos],2,[]),1,eyeClrs{2},[],2);
                        end
                    end
                    
                    % draw text with validation accuracy etc info
                    obj.drawCachedText(valInfoTopTextCache);
                    % draw buttons
                    [mousePos(1), mousePos(2)] = GetMouse();
                    [mousePos(1), mousePos(2)] = RemapMouse(wpnt(end), 'AllViews', mousePos(1), mousePos(2));
                    but(1).draw(mousePos);
                    but(2).draw(mousePos);
                    but(3).draw(mousePos);
                    but(4).draw(mousePos,qSelectMenuOpen);
                    but(5).draw(mousePos);
                    but(6).draw(mousePos,qShowGaze);
                    but(7).draw(mousePos,qShowCal);
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt(end),menuBgClr,menuBackRect);
                        % menuRects, inactive and currently active
                        qActive = iValid==selection;
                        Screen('FillRect',wpnt(end),menuItemClr,menuRects(~qActive,:).');
                        Screen('FillRect',wpnt(end),menuItemClrActive,menuRects( qActive,:).');
                        % text in each rect
                        for c=1:length(iValid)
                            obj.drawCachedText(menuTextCache(c));
                        end
                        obj.drawCachedText(menuActiveCache);
                    end
                    % if hovering over validation point, show info
                    if ~isnan(pointToShowInfoFor)
                        rect = OffsetRect(infoBoxRect,mx-gRectOff(1),my-gRectOff(2));
                        % mak sure does not go offscreen
                        if rect(3)>obj.scrInfo.resolution{1}(1)
                            rect = OffsetRect(rect,obj.scrInfo.resolution{1}(1)-rect(3),0);
                        end
                        if rect(4)>obj.scrInfo.resolution{1}(2)
                            rect = OffsetRect(rect,0,obj.scrInfo.resolution{1}(2)-rect(4));
                        end
                        Screen('FillRect',wpnt(end),hoverBgClr,rect);
                        obj.drawCachedText(pointTextCache,rect);
                    end
                    % if have operator screen, show message to wait to
                    % participant
                    if qHaveOperatorScreen && ~qShowGaze && ~isempty(obj.settings.UI.val.waitMsg.string)
                        obj.drawCachedText(waitTextCache);
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        % draw fixation points
                        obj.drawFixPoints(wpnt(1),fixPos,obj.settings.UI.val.onlineGaze.fixBackSize,obj.settings.UI.val.onlineGaze.fixFrontSize,obj.settings.UI.val.onlineGaze.fixBackColor,obj.settings.UI.val.onlineGaze.fixFrontColor);
                        % draw gaze data
                        eyeData = obj.buffer.peekN('gaze');
                        if ~isempty(eyeData.systemTimeStamp)
                            lE = eyeData. left.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            rE = eyeData.right.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            if obj.calibrateLeftEye  && eyeData. left.gazePoint.valid(end)
                                Screen('gluDisk', wpnt(end),onlineGazeClr{1,end}, lE(1), lE(2), 10);
                                if qHaveOperatorScreen && qShowGazeToAll
                                    Screen('gluDisk', wpnt(1),onlineGazeClr{1,1}, lE(1), lE(2), 10);
                                end
                            end
                            if obj.calibrateRightEye && eyeData.right.gazePoint.valid(end)
                                Screen('gluDisk', wpnt(end),onlineGazeClr{2,end}, rE(1), rE(2), 10);
                                if qHaveOperatorScreen && qShowGazeToAll
                                    Screen('gluDisk', wpnt(1),onlineGazeClr{2,1}, rE(1), rE(2), 10);
                                end
                            end
                        end
                    end
                    % drawing done, show
                    Screen('Flip',wpnt(1),[],0,0,1);
                    if qAwaitingCalChange
                        % break out of draw loop
                        break;
                    end
                    
                    % get user response
                    [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress();
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if any(buttons)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectMenuOpen
                            iIn = find(inRect([mx my],[menuRectsGlobal.' menuBackRectGlobal.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn) && iIn<=length(iValid)
                                newSelection        = iValid(iIn);
                                qSelectedCalChanged = selection~=newSelection;
                                qToggleSelectMenu   = true;
                                break;
                            else
                                qToggleSelectMenu   = true;
                                break;
                            end
                        end
                        if ~qSelectMenuOpen || qToggleSelectMenu     % if menu not open or menu closing because pressed outside the menu, check if pressed any of these menu buttons
                            qIn = inRect([mx my],butRectsGlobal.');
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
                                    qShowGazeToAll      = shiftIsDown;
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
                                newSelection        = iValid(str2double(keys(1)));
                                qSelectedCalChanged = selection~=newSelection;
                                qToggleSelectMenu   = true;
                                break;
                            elseif any(ismember(lower(keys),{'kp_enter','return','enter'})) % lowercase versions of possible return key names (also include numpad's enter)
                                newSelection        = iValid(currentMenuSel);
                                qSelectedCalChanged = selection~=newSelection;
                                qToggleSelectMenu   = true;
                                break;
                            else
                                if ~iscell(keys), keys = {keys}; end
                                if any(cellfun(@(x) ~isempty(strfind(lower(x(1:min(2,end))),'up')),keys)) 
                                    % up arrow key (test so round-about
                                    % because KbName could return both 'up'
                                    % and 'UpArrow', depending on platform
                                    % and mode)
                                    if currentMenuSel>1
                                        currentMenuSel   = currentMenuSel-1;
                                        qChangeMenuArrow = true;
                                        break;
                                    end
                                elseif any(cellfun(@(x) ~isempty(strfind(lower(x(1:min(4,end))),'down')),keys)) 
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
                                qShowGazeToAll      = shiftIsDown;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggCal.accelerator)) && qHasCal
                                qUpdateCalDisplay   = true;
                                qShowCal            = ~qShowCal;
                                break;
                            end
                        end
                        
                        % these key combinations should always be available
                        if any(strcmpi(keys,'escape')) && shiftIsDown
                            status = -5;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && shiftIsDown
                            % skip calibration
                            status = 2;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'d')) && shiftIsDown
                            % take screenshot
                            takeScreenshot(wpnt(1));
                        elseif any(strcmpi(keys,'o')) && shiftIsDown && qHaveOperatorScreen
                            % take screenshot of operator screen
                            takeScreenshot(wpnt(2));
                        end
                    end
                    % check if hovering over point for which we have info
                    if ~isempty(calValRects)
                        iIn = find(inRect([mx my],calValRectsGlobal.'));
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
            cal{selection}.valReviewStatus = status;
            if qShowGaze
                % if showing gaze, switch off gaze data stream
                obj.buffer.stop('gaze');
                obj.buffer.clearTimeRange('gaze',gazeStartT);
            end
            HideCursor;
        end
        
        function loadOtherCal(obj,cal)
            obj.buffer.calibrationApplyData(cal.cal.computedCal);
        end
        
        function [mx,my,mouse,key,shiftIsDown] = getNewMouseKeyPress(obj)
            % function that only returns key depress state changes in the
            % down direction, not keys that are held down or anything else
            % NB: before using this, make sure internal state is up to
            % date!
            [~,~,keyCode]   = KbCheck();
            [mx,my,buttons] = GetMouse();
            [mx,my]         = RemapMouse(obj.wpnts(end), 'AllViews', mx, my);
            
            % get only fresh mouse and key presses (so change from state
            % "up" to state "down")
            key     = keyCode & ~obj.keyState;
            mouse   = buttons & ~obj.mouseState;
            
            % get if shift key is currently down
            if any(keyCode)
                shiftIsDown = any(ismember(lower(KbName(keyCode)),{'shift','leftshift','rightshift'}));
            else
                shiftIsDown = false;
            end
            
            % store to state
            obj.keyState    = keyCode;
            obj.mouseState  = buttons;
        end
        
        function clr = getColorForWindow(obj,clr,wpnt)
            if obj.qFloatColorRange(obj.wpnts==wpnt)
                clr = double(clr)/255;
            end
        end
    end
end



%%% helpers
function eyeLbl = getEyeLbl(eye)
eyeLbl = sprintf('%s eye',eye);
if strcmp(eye,'both')
    eyeLbl = [eyeLbl 's'];
end
end
function angle = AngleBetweenVectors(a,b)
angle = atan2(sqrt(sum(cross(a,b,1).^2,1)),dot(a,b,1))*180/pi;
end

function iValid = getValidCalibrations(cal)
iValid = find(cellfun(@(x) isfield(x,'cal') && isfield(x.cal,'status') && x.cal.status==1 && ~isempty(x.cal.result) && strcmpi(x.cal.result.status(1:7),'success') && any(cellfun(@(y) y.status, x.val)==1),cal));
end

function result = fixupTobiiCalResult(calResult,hasLeft,hasRight)
result = calResult;
if hasLeft&&hasRight
    % we want data for both eyes, so we're done
    return
end

% only have one of the eyes, remove data for the other eye
for p=1:length(result.points)
    if ~hasLeft
        result.points(p).samples = rmfield(result.points(p).samples,'left');
    end
    if ~hasRight
        result.points(p).samples = rmfield(result.points(p).samples,'right');
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

function verts = genCircle(nStep)
alpha = linspace(0,2*pi,nStep);
verts = [cos(alpha); sin(alpha)];
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

function takeScreenshot(wpnt,dir)
if nargin<2 || isempty(dir)
    dir = cd;
end

fname   = fullfile(dir,[datestr(now,'yyyy-mm-dd HH.MM.SS.FFF') '.png']);
scrShot = Screen('GetImage',wpnt);
imwrite(scrShot,fname);
end
