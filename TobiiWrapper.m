classdef TobiiWrapper < handle
    properties (Access = protected, Hidden = true)
        % dll and mex files
        tobii;
        eyetracker;
        buffers;
        
        % message buffer
        msgs;
        
        % state
        isInitialized   = false;
        usingFTGLTextRenderer;
        keyState;
        shiftKey;
        mouseState;
        
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
    properties (Dependent)
        options;    % subset of settings that can actually be changed. contents differ based on state of class (once inited, much less can be set)
    end
    
    methods
        function obj = TobiiWrapper(settingsOrETName,scrInfo)
            % deal with inputs
            if ischar(settingsOrETName)
                % only eye-tracker name provided, load defaults for this
                % tracker
                obj.options = obj.getDefaults(settingsOrETName);
            else
                obj.options = settingsOrETName;
            end
            
            if nargin<2 || isempty(scrInfo)
                obj.scrInfo.resolution  = Screen('Rect',0); obj.scrInfo.resolution(1:2) = [];
                obj.scrInfo.center      = obj.scrInfo.resolution/2;
            else
                assert(isfield(scrInfo,'resolution') && isfield(scrInfo,'center'),'scrInfo should have a ''resolution'' and a ''center'' field')
                obj.scrInfo             = scrInfo;
            end
            
            % see what text renderer to use
            obj.usingFTGLTextRenderer = ~~exist('libptbdrawtext_ftgl64.dll','file');    % check if we're on a Windows platform with the high quality text renderer present (was never supported for 32bit PTB, so check only for 64bit)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.text,'lineCentOff'),'PTB''s TextRenderer changed between calls to getDefaults and the SMIWrapper constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call SMIWrapper.getDefaults(), as it has differnt settings than the recommended TextRendered number 1')
            end
            
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            obj.shiftKey = KbName('shift');
            [~,~,obj.mouseState] = GetMouse();
            
            % Load in Tobii SDK
            obj.tobii = EyeTrackingOperations();
            
            % prepare msg buffer
            obj.msgs = simpleVec(cell(1,2),1024);
        end
        
        function out = setDummyMode(obj)
            assert(nargout==1,'you must use the output argument of setDummyMode, like: TobiiHandle = TobiiHandle.setDummyMode(), or TobiiHandle = setDummyMode(TobiiHandle)')
            out = TobiiWrapperDummyMode(obj);
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
        
        function out = get.options(obj)
            if ~obj.isInitialized
                % return all settings
                out = obj.settings;
            else
                % only the subset that can be changed "live"
                opts = obj.getAllowedOptions();
                for p=1:size(opts,1)
                    out.(opts{p,1}).(opts{p,2}) = obj.settings.(opts{p,1}).(opts{p,2});
                end
            end
        end
        
        function set.options(obj,settings)
            if obj.isInitialized
                % only a subset of settings is allowed. Hardcode here, and
                % copy over if exist. Ignore all others silently
                allowed = obj.getAllowedOptions();
                for p=1:size(allowed,1)
                    if isfield(settings,allowed{p,1}) && isfield(settings.(allowed{p,1}),allowed{p,2})
                        obj.settings.(allowed{p,1}).(allowed{p,2}) = settings.(allowed{p,1}).(allowed{p,2});
                    end
                end
            else
                % just copy it over. If user didn't remove fields from
                % settings struct, we're good. If they did, they're an
                % idiot. If they added any, they'll be ignored, so no
                % problem.
                obj.settings = settings;
            end
            % setup colors
            obj.settings.cal.bgColor        = color2RGBA(obj.settings.cal.bgColor);
            obj.settings.cal.fixBackColor   = color2RGBA(obj.settings.cal.fixBackColor);
            obj.settings.cal.fixFrontColor  = color2RGBA(obj.settings.cal.fixFrontColor);
        end
        
        function out = init(obj)
            % Connect to eyetracker
            % see which eye trackers available
            trackers = obj.tobii.find_all_eyetrackers();
            % find macthing eye-tracker, first by model
            qModel = strcmp({trackers.Model},obj.settings.tracker);
            assert(any(qModel),'No trackers of model ''%s'' connected',obj.settings.tracker)
            % if obligatory serial also given, check on that
            assert(sum(qModel)==1 || ~isempty(obj.settings.serialNumber),'If more than one connected eye-tracker is of the requested model, a serial number must be provided to allow connecting to the right one')
            if sum(qModel)>1 || (~isempty(obj.settings.serialNumber) && obj.settings.serialNumber(1)~='*')
                serial = obj.settings.serialNumber;
                if serial(1)=='*'
                    serial(1) = [];
                end
                qTracker = qModel & strcmp({trackers.SerialNumber},serial);
                assert(any(qTracker),'No trackers of model ''%s'' with serial ''%s'' connected',obj.settings.tracker,serial)
            else
                qTracker = qModel;
            end
            % get our instance
            obj.eyetracker = trackers(qTracker);
            
            % Load in our callback buffer mex
            obj.buffers = TobiiBuffer(obj.eyetracker.Address);
            
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
                assert(isempty(failed_licenses),'TobiiWrapper: provided license(s) couldn''t be applied')
            end
            
            % set tracker to operate at requested tracking frequency
            obj.eyetracker.set_gaze_output_frequency(obj.settings.freq);
            
%             % get info about the system
%             [~,obj.systemInfo]          = obj.iView.getSystemInfo();
%             if obj.caps.serialNumber
%                 [~,obj.systemInfo.Serial]   = obj.iView.getSerialNumber();
%             end
%             out.systemInfo              = obj.systemInfo;
            out = [];
            
            % get information about display geometry
            obj.geom = structfun(@double,struct(obj.eyetracker.get_display_area()),'uni',false);
            
            % setup track mode
            % TODO: human or primate, if supported
            
            % init recording state
            obj.recState.gaze   = false;
            obj.recState.sync   = false;
            obj.recState.extSig = false;
            obj.recState.eyeIm  = false;
            
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(obj,wpnt)
            % this function does all setup, draws the interface, etc
            
            %%% 1. some preliminary setup, to make sure we are in known state
            calibClass = ScreenBasedCalibration(obj.eyetracker);
            try
                calibClass.leave_calibration_mode();    % make sure we're not already in calibration mode (start afresh)
            catch ME %#ok<NASGU>
                % no-op, ok if fails, simply means we're not already in
                % calibration mode
            end
            obj.stopRecording();
            
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
                if startScreen>0
                    %%% 2a: show head positioning screen
                    if kCal==1
                        status = obj.showHeadPositioning(wpnt, [],startScreen);
                    else
                        status = obj.showHeadPositioning(wpnt,out,startScreen);
                    end
                    switch status
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
                            error('run ended from Tobii calibration routine')
                        otherwise
                            error('status %d not implemented',status);
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
                            error('run ended from Tobii calibration routine')
                        otherwise
                            error('status %d not implemented',out.attempt{kCal}.calStatus);
                    end
                end
                
                %%% 2c: show calibration results
                % show validation result and ask to continue
                [out.attempt{kCal}.valResultAccept,out.attempt{kCal}.calSelection] = obj.showCalValResult(wpnt,out.attempt,kCal);
                switch out.attempt{kCal}.valResultAccept
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
                        % go to setup
                        startScreen = max(1,startScreen);
                        continue;
                    case -4
                        % full stop
                        error('run ended from Tobii calibration routine')
                    otherwise
                        error('status %d not implemented',out.attempt{kCal}.valResultAccept);
                end
            end
            
            % clean up
            Screen('Flip',wpnt);
            
            % store calibration info in calibration history, for later
            % retrieval if wanted
            if isempty(obj.calibrateHistory)
                obj.calibrateHistory{1} = out;
            else
                obj.calibrateHistory{end+1} = out;
            end
        end
        
        function startRecording(obj)
            % 1. gaze data
            obj.startRecordingSpecificStream('gaze');
            
            % 2. info about synchronization between ET and system
            if obj.settings.doRecord.syncData
                obj.startRecordingSpecificStream('sync');
            end
            % 3. external signal
            if obj.settings.doRecord.externalSignal
                obj.startRecordingSpecificStream('externalSignal');
            end
            
            % 4. eye images
            if obj.settings.doRecord.eyeImages
                obj.startRecordingSpecificStream('eyeImages');
            end
            
            WaitSecs(.05); % give it some time to get started. not needed according to doc, but never hurts
        end
        
        function startRecordingSpecificStream(obj,stream)
            % For these, the first call subscribes to the stream and returns
            % either data (might be empty if no data has been received yet) or
            % any error that happened during the subscription.
            switch lower(stream)
                case 'gaze'
                    if ~obj.recState.gaze
                        result      = obj.buffers.startSampleBuffering();
                        streamLbl   = 'gaze data';
                        field       = 'gaze';
                    end
                case 'sync'
                    if ~obj.recState.sync
                        result      = obj.eyetracker.get_time_sync_data('flat');
                        streamLbl   = 'sync data';
                        field       = 'sync';
                    end
                case 'externalsignal'
                    if hasCap(obj,Capabilities.HasExternalSignal)
                        if ~obj.recState.extSig
                            result      = obj.eyetracker.get_external_signal_data('flat');
                            streamLbl   = 'external signals';
                            field       = 'extSig';
                        end
                    else
                        error('recording of external signals is not supported by this eye-tracker')
                    end
                case 'eyeimages'
                    if hasCap(obj,Capabilities.HasEyeImages)
                        if ~obj.recState.eyeIm
                            result      = obj.buffers.startEyeImageBuffering();
                            streamLbl   = 'eye images';
                            field   	= 'eyeIm';
                        end
                    else
                        error('recording of eye images is not supported by this eye-tracker')
                    end
                otherwise
                    error('signal ''%s'' not known',stream);
            end
            
            % check for errors
            if islogical(result)
                if ~result
                    error('Tobii: Error starting recording %s',streamLbl);
                end
            else
                obj.processError(result,sprintf('Tobii: Error starting recording %s',streamLbl));
            end
            % mark that we are recording
            obj.recState.(field) = true;
        end
        
        function startBuffer(obj,size)
            if nargin<2
                size = [];
            end
            ret = obj.buffers.startSampleBuffering(size);
            obj.processError(ret,'SMI: Error starting sample buffer');
        end
        
        function data = consumeData(obj,N)
            data = obj.buffers.consume(N);
        end
        
        function data = peekData(obj,N)
            % returns empty when sample not gotten successfully
            data = obj.buffers.peekSamples(N);
        end
        
        function stopRecording(obj)
            % 1. gaze data
            obj.stopRecordingSpecificStream('gaze');
            % 2. info about synchronization between ET and system
            obj.stopRecordingSpecificStream('sync');
            % 3. external signal
            obj.stopRecordingSpecificStream('externalSignal');
            % 4. eye images
            obj.stopRecordingSpecificStream('eyeImages');
        end
        
        function stopRecordingSpecificStream(obj,stream)
            field = '';
            switch lower(stream)
                case 'gaze'
                    if obj.recState.gaze
                        obj.buffers.stopSampleBuffering(false);
                        field = 'gaze';
                    end
                case 'sync'
                    if obj.recState.sync
                        obj.eyetracker.stop_time_sync_data();
                        field = 'sync';
                    end
                case 'externalsignal'
                    if obj.recState.extSig
                        obj.eyetracker.stop_external_signal_data();
                        field = 'extSig';
                    end
                case 'eyeimages'
                    if obj.recState.eyeIm
                        obj.buffers.stopEyeImageBuffering(false);
                        field = 'eyeIm';
                    end
                otherwise
                    error('signal ''%s'' not known',stream);
            end
            
            % mark that we stopped recording
            if ~isempty(field)
                obj.recState.(field) = false;
            end
        end
        
        function [etData,syncData,extData,eyeImage] = getData(obj)
            etData  = obj.getSpecificData('gaze');
            syncData= obj.getSpecificData('sync');
            extData = obj.getSpecificData('externalSignal');
            eyeImage= obj.getSpecificData('eyeImages');
        end
        
        function [data] = getSpecificData(obj,stream)
            data = [];
            switch lower(stream)
                case 'gaze'
                    if obj.recState.gaze
                        data = obj.eyetracker.get_gaze_data('flat');
                    end
                case 'sync'
                    if obj.recState.sync
                        data = obj.eyetracker.get_time_sync_data('flat');
                    end
                case 'externalsignal'
                    if obj.recState.extSig
                        data = obj.eyetracker.get_external_signal_data('flat');
                    end
                case 'eyeimages'
                    if obj.recState.eyeIm
                        data = obj.buffers.consumeEyeImages();
                    end
                otherwise
                    error('signal ''%s'' not known',stream);
            end
        end
        
        function sendMessage(obj,str,time)
            % Tobii system timestamp is same clock as PTB's clock. So we're
            % good. If an event has a known time (e.g. a screen flip),
            % provide it as an input argument to this function.
            if nargin<3
                time = GetSecs();
            end
            time = int64(round(time*1000*1000));
            obj.msgs.append({time,str});
            if obj.settings.debugMode
                fprintf('%d: %s\n',time,str);
            end
        end
        
        function recordEyeImages(obj,filename, format, duration)
            % NB: does NOT work on NG eye-trackers (RED250mobile, RED-n)
            % if using two computer setup, save location is on remote
            % computer, if not a full path is given, it is relative to
            % iView install directory on that computer. If single computer
            % setup, relative paths are relative to the current working
            % directory when this function is called
            % duration is in ms. If provided, images for the recording
            % duration are buffered and written to disk afterwards, so no
            % images will be lost. If empty, images are recorded directly
            % to disk (and lost if disk can't keep up).
            
            % get filename and path
            [path,file,~] = fileparts(filename);
            if isempty(regexp(path,'^\w:', 'once')) && ~obj.isTwoComputerSetup()
                % single computer setup and no drive letter in provided
                % path. Interpret path as relative to cd
                path = fullfile(cd,path);
            end
            
            % check format
            if ischar(format)
                format = find(strcmpi(format,{'jpg','bmp','xvid','huffyuv','alpary','xmp4'}));
                assert(~isempty(format),'if format provided as string, should be one of ''jpg'',''bmp'',''xvid'',''huffyuv'',''alpary'',''xmp4''');
                format = format-1;
            end
            assert(isnumeric(format) && format>=0 && format<=5,'format should be between 0 and 5 (inclusive)')
            
            % send command
            if isempty(duration)
                obj.rawET.sendCommand(sprintf('ET_EVB %d "%s" "%s"\n',format,file,path));
            else
                obj.rawET.sendCommand(sprintf('ET_EVB %d "%s" "%s" %d\n',format,file,path,duration));
            end
        end
        
        function stopRecordEyeImages(obj)
            % if no duration specified when calling recordEyeImages, call
            % this function to stop eye image recording
            obj.rawET.sendCommand('ET_EVE\n');
        end
        
        function saveData(obj,filename, user, description, doAppendVersion)
            % 1. get filename and path
            [path,file,ext] = fileparts(filename);
            assert(~isempty(path),'saveData: filename should contain a path')
            % eat .idf off filename, preserve any other extension user may
            % have provided
            if ~isempty(ext) && ~strcmpi(ext,'.idf')
                file = [file ext];
            end
            % add versioning info to file name, if wanted and if already
            % exists
            if nargin>=5 && doAppendVersion
                % see what files we have in data folder with the same name
                f = FileFromFolder(path,'ssilent','idf');
                f = regexp({f.fname},['^' regexptranslate('escape',file) '(_\d+)?$'],'tokens');
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
            % now make sure file ends with .idf
            file = [file '.idf'];
            % set defaults
            if nargin<3 || isempty(user)
                user = file;
            end
            if nargin<4 || isempty(description)
                description = '';
            end
            
            % construct full filename
            filename = fullfile(path,file);
            ret = obj.iView.saveData(filename, description, user, 0);
            obj.processError(ret,'SMI: Error saving data');
        end
        
        function out = deInit(obj,qQuit)
            obj.iView.disconnect();
            % also, read log, return contents as output and delete
            fid = fopen(obj.settings.logFileName, 'r');
            if fid~=-1
                out = fread(fid, inf, '*char').';
                fclose(fid);
            else
                out = '';
            end
            % somehow, matlab maintains a handle to the log file, even after
            % fclose all and unloading the SMI library. Somehow a dangling
            % handle from smi, would be my guess (note that calling iV_Quit did
            % not fix it).
            % delete(smiSetup.logFileName);
            if nargin>1 && qQuit
                obj.iView.quit();
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
            % settings (only provided if supported):
            % - trackEye:               'EYE_LEFT', 'EYE_RIGHT', or
            %                           'EYE_BOTH'
            % - trackMode:              'MONOCULAR', 'BINOCULAR',
            %                           'SMARTBINOCULAR', or
            %                           'SMARTTRACKING'
            % - doAverageEyes           true/false. TODO: check if only for
            %                           RED-m and newer?
            % - freq:                   eye-tracker dependant. Only for NG
            %                           trackers can it actually be set 
            % - cal.nPoint:             0, 1, 2, 5, 9 or 13 calibration
            %                           points are possible
            switch tracker
                case 'Tobii Pro Spectrum'
                    settings.freq                   = 1200;
                    settings.cal.pointPos           = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
                    settings.val.pointPos           = [[0.25 0.25]; [0.25 0.75]; [0.75 0.75]; [0.75 0.25]];
            end
            
            % the rest here are good defaults for all
            settings.serialNumber           = '';
            settings.licenseFile            = '';
            settings.setup.startScreen      = 1;                                % 0. skip head positioning, go straight to calibration; 1. start with simple head positioning interface; 2. start with advanced head positioning interface
            settings.cal.autoPace           = 1;                                % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
            settings.cal.paceDuration       = 1.5;                              % minimum duration (s) that each point is shown
            settings.cal.qRandPoints        = true;
            settings.cal.bgColor            = 127;
            settings.cal.fixBackSize        = 20;
            settings.cal.fixFrontSize       = 5;
            settings.cal.fixBackColor       = 0;
            settings.cal.fixFrontColor      = 255;
            settings.cal.drawFunction       = [];
            settings.val.paceDuration       = 1.5;
            settings.val.collectDuration    = 0.5;
            settings.val.qRandPoints        = true;
            settings.doRecord.syncData      = true;
            settings.doRecord.externalSignal= false;
            settings.doRecord.eyeImages     = false;
            settings.setup.viewingDist      = 65;
            settings.text.font              = 'Consolas';
            settings.text.style             = 0;                                % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.text.wrapAt            = 62;
            settings.text.vSpacing          = 1;
            if ~exist('libptbdrawtext_ftgl64.dll','file') % if old text renderer, we have different defaults and an extra settings
                settings.text.size          = 20;
                settings.text.lineCentOff   = 3;                                % amount (pixels) to move single line text down so that it is visually centered on requested coordinate
            else
                settings.text.size          = 24;
            end
            settings.string.simplePositionInstruction = 'Position yourself such that the two circles overlap.\nDistance: %.0f cm';
            settings.debugMode          = false;                            % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
        end
        
        function processError(returnValue,errorString)
            % for Tobii, deal with return values of type StreamError
            if isa(returnValue,'StreamError')
                error('%s (error %s, source %s, timestamp %d, message: %s)\n',errorString,char(returnValue.Error),char(returnValue.Source),returnValue.SystemTimeStamp,returnValue.Message);
            end
        end
    end
    
    methods (Access = private, Hidden)
        function allowed = getAllowedOptions(obj)
            allowed = {...
                'cal','autoPace'
                'cal','nPoint'
                'cal','bgColor'
                'cal','fixBackSize'
                'cal','fixFrontSize'
                'cal','fixBackColor'
                'cal','fixFrontColor'
                'cal','drawFunction'
                'text','font'
                'text','size'
                'text','style'
                'text','wrapAt'
                'text','vSpacing'
                'text','lineCentOff'
                'string','simplePositionInstruction'
                };
            for p=size(allowed,1):-1:1
                if ~isfield(obj.settings,allowed{p,1}) || ~isfield(obj.settings.(allowed{p,1}),allowed{p,2})
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
            obj.startRecordingSpecificStream('gaze');
            obj.sendMessage('SETUP START'); % so user can know to ignore this data (we can't afford emptying the buffer at end, user may have data in it from before)
            % see if we already have valid calibrations
            qHaveValidCalibrations = false;
            if ~isempty(out)
                if isfield(out,'attempt')
                    qHaveValidCalibrations = ~isempty(obj.getValidCalibrations(out.attempt));
                end
            end
            
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
            obj.stopRecordingSpecificStream('gaze');
            obj.sendMessage('SETUP END')
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
            ovalVSz = .15;
            refSz   = ovalVSz*obj.scrInfo.resolution(2);
            refClr  = [0 0 255];
            headClr = [255 255 0];
            % setup head position visualization
            distGain= 1.5;

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
            advancedButTextCache    = obj.getButtonTextCache(wpnt,'advanced (<i>a<i>)'        ,advancedButRect);
            b=b+1;
            
            calibButRect            = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
            calibButTextCache       = obj.getButtonTextCache(wpnt,'calibrate (<i>spacebar<i>)',   calibButRect);
            b=b+1;
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(b) 0 buttonRectsX(b+1)-buttonOff buttonSz{b}(2)],obj.scrInfo.center(1),yposBase-buttonSz{b}(2));
                validateButTextCache    = obj.getButtonTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            % setup cursors
            cursors.rect    = {advancedButRect.' calibButRect.' validateButRect.'};
            cursors.cursor  = [2 2 2];      % Hand
            cursors.other   = 0;            % Arrow
            if ~obj.settings.debugMode      % for cleanup
                cursors.reset = -1;         % hide cursor (else will reset to cursor.other by default, so we're good with that default
            end
            cursor          = cursorUpdater(cursors);
            
            % get tracking status and visualize
            trackBox        = obj.eyetracker.get_track_box();
            trackBoxDepths  = double([trackBox.FrontLowerLeft(3) trackBox.BackLowerLeft(3)]./10);
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while true
                % get latest data from eye-tracker
                eyeData = obj.buffers.peekSamples(1);
                if isempty(eyeData)
                    [lEye,rEye] = deal(nan(3,1));
                else
                    lEye = eyeData. left.gazeOrigin.inTrackBoxCoords;
                    rEye = eyeData.right.gazeOrigin.inTrackBoxCoords;
                end
                
                % get average eye distance. use distance from one eye if only one eye
                % available
                distL   = lEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                distR   = rEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                dists   = [distL distR];
                avgDist = mean(dists(~isnan(dists)));
                Xs      = [lEye(1) rEye(1)];    % normalized is good here
                avgX    = mean(Xs(~isnan(Xs)));
                Ys      = [lEye(2) rEye(2)];
                avgY    = mean(Ys(~isnan(Ys)));
                
                % scale up size of oval. define size/rect at standard distance, have a
                % gain for how much to scale as distance changes
                if ~isnan(distL) || ~isnan(distR)
                    pos     = [1-avgX avgY];  %1-X as 0 is right and 1 is left edge. needs to be reflected for screen drawing
                    % determine size of oval, based on distance from reference distance
                    fac     = avgDist/obj.settings.setup.viewingDist;
                    headSz  = refSz - refSz*(fac-1)*distGain;
                    % move
                    headPos = pos.*obj.scrInfo.resolution;
                else
                    headPos = [];
                end
                
                % draw distance info
                DrawFormattedText(wpnt,sprintf(obj.settings.string.simplePositionInstruction,avgDist),'center',fixPos(1,2)-.03*obj.scrInfo.resolution(2),255,[],[],[],1.5);
                % draw ovals
                obj.drawCircle(wpnt,refClr,obj.scrInfo.center,refSz,5);
                if ~isempty(headPos)
                    obj.drawCircle(wpnt,headClr,headPos,headSz,5);
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
                [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
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
                    elseif any(strcmpi(keys,'escape')) && haveShift
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
            end
            % clean up
            HideCursor;
        end
        
        
        function status = showHeadPositioningAdvanced(obj,wpnt,qHaveValidCalibrations)
            obj.startRecordingSpecificStream('eyeImages');
            
            % setup text
            Screen('TextFont',  wpnt, obj.settings.text.font);
            Screen('TextSize',  wpnt, obj.settings.text.size);
            Screen('TextStyle', wpnt, obj.settings.text.style);
            % setup box
            trackBox= obj.eyetracker.get_track_box();
            trackBoxDepths  = double([trackBox.FrontLowerLeft(3) trackBox.BackLowerLeft(3)]./10);
            boxSize = double((trackBox.FrontUpperRight-trackBox.FrontLowerLeft)./10);
            boxSize = round(500.*boxSize(1:2)./boxSize(1));
            [boxCenter(1),boxCenter(2)] = RectCenter([0 0 boxSize]);
            % setup eye image
            margin  = 80;
            texs    = [0 0];
            eyeIm   = [];
            while isempty(eyeIm)
                eyeIm = obj.getSpecificData('eyeImages');
                WaitSecs('YieldSecs',0.2);
            end
            [texs,szs]  = obj.UploadImages(texs,[],wpnt,eyeIm);
            eyeImRect   = [zeros(2) szs.'];
            maxEyeImRect= max(eyeImRect,[],1);
            
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
            eyeImageRect{1} = OffsetRect(eyeImRect(1,:),obj.scrInfo.center(1)-eyeImRect(1,3)-10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(1,:))/2);
            eyeImageRect{2} = OffsetRect(eyeImRect(2,:),obj.scrInfo.center(1)               +10,boxRect(4)+margin+RectHeight(maxEyeImRect-eyeImRect(2,:))/2);
            % place buttons for back to simple interface, or calibrate
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            basicButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],obj.scrInfo.center(1),yposBase-buttonSz{1}(2));
            basicButTextCache   = obj.getButtonTextCache(wpnt,'basic (<i>b<i>)'          , basicButRect);
            calibButRect        = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],obj.scrInfo.center(1),yposBase-buttonSz{2}(2));
            calibButTextCache   = obj.getButtonTextCache(wpnt,'calibrate (<i>spacebar<i>)',calibButRect);
            if qHaveValidCalibrations
                validateButRect         = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],obj.scrInfo.center(1),yposBase-buttonSz{3}(2));
                validateButTextCache    = obj.getButtonTextCache(wpnt,'previous calibrations (<i>p<i>)',validateButRect);
            else
                validateButRect         = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            
            Screen('FillRect', wpnt, obj.settings.cal.bgColor); % clear what we've just drawn
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
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
            relPos      = zeros(3);
            while true
                eyeData = obj.buffers.peekSamples(1);
                if isempty(eyeData)
                    [lEye,rEye] = deal(nan(3,1));
                else
                    lEye = eyeData. left.gazeOrigin.inTrackBoxCoords;
                    rEye = eyeData.right.gazeOrigin.inTrackBoxCoords;
                end
                
                % get average eye distance. use distance from one eye if only one eye
                % available
                distL   = lEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                distR   = rEye(3)*diff(trackBoxDepths)+trackBoxDepths(1);
                dists   = [distL distR];
                avgDist = mean(dists(~isnan(dists)));
                % if missing, estimate where eye would be in depth if user
                % kept head yaw constant
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
                    arrowColor(:,idx) = obj.getArrowColor(xMid(i),xThresh,col1,col2,col3);
                end
                if any(abs(yMid)>yThresh(1))
                    [~,i] = max(abs(yMid));
                    idx = 3 + (yMid(i)<0);
                    qDrawArrow(idx) = true;
                    arrowColor(:,idx) = obj.getArrowColor(yMid(i),yThresh,col1,col2,col3);
                end
                if abs(zMid)>zThresh(1)
                    idx = 5 + (zMid>0);
                    qDrawArrow(idx) = true;
                    arrowColor(:,idx) = obj.getArrowColor(zMid,zThresh,col1,col2,col3);
                end
                % get eye image
                eyeIm       = obj.getSpecificData('eyeImages');
                [texs,szs]  = obj.UploadImages(texs,szs,wpnt,eyeIm);
                
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
                
                % do drawing
                % draw box
                Screen('FillRect',wpnt,80,boxRect);
                % draw distance
                if ~isnan(avgDist)
                    Screen('TextSize', wpnt, 12);
                    Screen('DrawText',wpnt,sprintf('%.0f cm',avgDist) ,boxRect(3)-40,boxRect(4)-16,255);
                end
                % draw eyes in box
                Screen('TextSize',  wpnt, obj.settings.text.size);
                if ~isnan(distL) || ~isnan(distR)
                    posL     = [1-lEye(1) lEye(2)];  %1-X as 0 is right and 1 is left edge. needs to be reflected for screen drawing
                    posR     = [1-rEye(1) rEye(2)];
                    % determine size of eye. based on distance from viewing
                    % distance, calculate size change
                    fac  = obj.settings.setup.viewingDist/avgDist;
                    facL = obj.settings.setup.viewingDist/distL;
                    facR = obj.settings.setup.viewingDist/distR;
                    % left eye
                    style = Screen('TextStyle', wpnt, 1);
                    obj.drawEye(wpnt,~isnan(distL),posL,posR, relPos*fac,[255 120 120],[220 186 186],round(sz*facL*gain),'L',boxRect);
                    % right eye
                    obj.drawEye(wpnt,~isnan(distR),posR,posL,-relPos*fac,[120 255 120],[186 220 186],round(sz*facR*gain),'R',boxRect);
                    Screen('TextStyle', wpnt, style);
                    % update relative eye positions - used for drawing estimated
                    % position of missing eye. X and Y are relative position in
                    % headbox, Z is difference in measured eye depths
                    if ~isnan(distL) && ~isnan(distR)
                        relPos = [(posR-posL)/fac distR-distL];   % keep a distance normalized to viewing distance, so we can scale eye distance with subject's distance from tracker correctly
                    end
                end
                % draw arrows
                for p=find(qDrawArrow)
                    Screen('FillPoly', wpnt, arrowColor(:,p), bsxfun(@plus,arrowsLRUDNF{p},arrowPos{p}+boxRect(1:2)) ,0);
                end
                % draw eye images, if any
                if texs(1)
                    Screen('DrawTexture', wpnt, texs(1),[],eyeImageRect{1});
                end
                if texs(2)
                    Screen('DrawTexture', wpnt, texs(2),[],eyeImageRect{2});
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
                [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
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
                    elseif any(strcmpi(keys,'escape')) && haveShift
                        status = -4;
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
            end
            % clean up
            obj.stopRecordingSpecificStream('eyeImages');
            if texs
                Screen('Close',texs);
            end
            HideCursor;
        end
        
        function [texs,szs] = UploadImages(obj,texs,szs,wpnt,image)
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
                    texs(which) = obj.UploadImage(texs(which),wpnt,im);
                    qHave(which) = true;
                    szs(:,which) = [w h].';
                end
                if all(qHave)
                    break;
                end
            end
        end
        function tex = UploadImage(~,tex,wpnt,image)
            if tex
                Screen('Close',tex);
            end
            % 8 to prevent mipmap generation, we don't need it
            % fliplr to make eye image look like coming from a mirror
            % instead of simply being from camera's perspective
            tex = Screen('MakeTexture',wpnt,fliplr(image),[],8);
        end
        
        function drawCircle(~,wpnt,refClr,center,refSz,lineWidth)
            nStep = 200;
            alpha = linspace(0,2*pi,nStep);
            alpha = [alpha(1:end-1); alpha(2:end)]; alpha = alpha(:).';
            xy = refSz.*[cos(alpha); sin(alpha)];
            Screen('DrawLines', wpnt, xy, lineWidth ,refClr ,center,2);
        end
        
        function cache = getButtonTextCache(obj,wpnt,lbl,rect)
            if obj.usingFTGLTextRenderer
                [sx,sy] = RectCenterd(rect);
                [~,~,~,cache] = DrawFormattedText2(lbl,'win',wpnt,'sx',sx,'xalign','center','sy',sy,'yalign','center','baseColor',0,'cacheOnly',true);
            else
                [~,~,~,cache] = DrawMonospacedText(wpnt,lbl,'center','center',0,[],[],[],OffsetRect(rect,0,obj.settings.text.lineCentOff),true);
            end
        end
        
        function drawCachedText(obj,cache)
            if obj.usingFTGLTextRenderer
                DrawFormattedText2(cache);
            else
                DrawMonospacedText(cache);
            end
        end
        
        function arrowColor = getArrowColor(~,posRating,thresh,col1,col2,col3)
            if abs(posRating)>thresh(2)
                arrowColor = col3;
            else
                arrowColor = col1+(abs(posRating)-thresh(1))./diff(thresh)*(col2-col1);
            end
        end
        
        function drawEye(~,wpnt,validity,pos,posOther,relPos,clr1,clr2,sz,lbl,boxRect)
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
            calibClass.enter_calibration_mode();
            obj.startRecording();
            obj.sendMessage(sprintf('CALIBRATION START %d',kCal));
            % show display
            [status,out.cal,tick] = obj.DoCalPointDisplay(wpnt,calibClass,-1);
            obj.sendMessage(sprintf('CALIBRATION END %d',kCal));
            % compute calibration
            result = calibClass.compute_and_apply();
            calibClass.leave_calibration_mode();
            
            % if valid calibration retrieve data, so user can select different ones
            if result.Status==CalibrationStatus.Success
                out.cal.calData = obj.eyetracker.retrieve_calibration_data();
            end
            
            if status~=1
                obj.stopRecording();
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
                end
                return;
            end
            
            % do validation
            obj.sendMessage(sprintf('VALIDATION START %d',kCal));
            % show display
            [status,out.val] = obj.DoCalPointDisplay(wpnt,[],tick,out.cal.flips(end));
            obj.sendMessage(sprintf('VALIDATION END %d',kCal));
            obj.stopRecording();
            % compute accuracy etc
            if status==1
                out.val = ProcessValData(obj,out.val);
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
        
        function [status,out,tick] = DoCalPointDisplay(obj,wpnt,calibClass,tick,lastFlip)
            % status output:
            %  1: finished succesfully (you should query SMI software whether they think
            %     calibration was succesful though)
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
            else
                points          = obj.settings.val.pointPos;
                paceInterval    = ceil(obj.settings.val.paceDuration   *Screen('NominalFrameRate',wpnt));
                collectInterval = ceil(obj.settings.val.collectDuration*Screen('NominalFrameRate',wpnt));
                nDataPoint      = ceil(obj.settings.val.collectDuration*obj.eyetracker.get_gaze_output_frequency());
                tick0v          = nan;
                out.gazeData    = [];
            end
            nPoint = size(points,1);
            points = [points bsxfun(@times,points,obj.scrInfo.resolution) [1:nPoint].' ones(nPoint,1)];
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
            
            while true
                tick        = tick+1;
                nextFlipT   = out.flips(end)+1/1000;
                if advancePoint
                    currentPoint = currentPoint+1;
                    % check any points left to do
                    if currentPoint>size(points,1)
                        break;
                    end
                    out.pointPos(end+1,1:3) = [points(currentPoint,[5 3 4])];
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
                    obj.sendMessage(sprintf('POINT ON %d (%d %d)',currentPoint,points(currentPoint,3:4)),out.flips(end));
                    qNewPoint = false;
                end
                
                % get user response
                [~,~,~,keyCode,haveShift] = obj.getNewMouseKeyPress();
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
                        obj.iView.abortCalibration();
                        if any(strcmpi(keys,'shift'))
                            status = -4;
                        else
                            status = -2;
                        end
                        break;
                    elseif any(strcmpi(keys,'s')) && haveShift
                        % skip calibration
                        obj.iView.abortCalibration();
                        status = 2;
                        break;
                    end
                end
                
                % accept point
                if haveAccepted && tick>tick0p+paceInterval
                    if qCal
                        collect_result = calibClass.collect_data(points(currentPoint,1:2));
                        % if fails, retry immediately
                        if collect_result.value==CalibrationStatus.Failure
                            collect_result = calibClass.collect_data(points(currentPoint,1:2));
                        end
                        out.status(currentPoint,1) = collect_result.value;
                        % if still fails, retry one more times at end of
                        % point sequence (if this is not alrea a retried
                        % point)
                        if collect_result.value==CalibrationStatus.Failure && points(currentPoint,6)
                            points = [points; points(currentPoint,:)];
                            points(end,6) = 0;  % indicate this is a point that is being retried so we don't try forever
                        end
                        
                        % next point
                        advancePoint = true;
                    else
                        if isnan(tick0v)
                            tick0v = tick;
                        end
                        if tick>tick0v+collectInterval
                            dat = obj.buffers.peekSamples(nDataPoint);
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
            if ~qFirst
                out.flips(end+1) = Screen('Flip',wpnt);    % clear
                obj.sendMessage(sprintf('POINT OFF %d',currentPoint),out.flips(end));
            end
        end
        
        function qAllowAcceptKey = drawFixationPointDefault(obj,wpnt,~,pos,~)
            obj.drawFixPoints(wpnt,pos);
            qAllowAcceptKey = true;
        end
        
        function val = ProcessValData(obj,val)
            % compute validation accuracy per point, noise levels, %
            % missing
            for p=length(val.gazeData):-1:1
                val.result(p).left  = obj.getDataQuality(val.gazeData(p).left ,val.pointPos(p,2:3));
                val.result(p).right = obj.getDataQuality(val.gazeData(p).right,val.pointPos(p,2:3));
            end
            lefts  = [val.result.left];
            rights = [val.result.right];
            for f={'acc','RMS2D','STD2D','trackRatio'}
                % NB: abs when averaging over eyes, we need average size of
                % error for accuracy and for other fields its all positive
                % anyway
                val.(f{1}) = [nanmean(abs([lefts.(f{1})]),2) nanmean(abs([rights.(f{1})]),2)];
            end
        end
        
        function out = getDataQuality(obj,gazeData,valPointPos)
            % 1. accuracy
            pointOnScreenDA  = (valPointPos./obj.scrInfo.resolution).';
            pointOnScreenUCS = obj.ADCSToUCS(pointOnScreenDA);
            offOnScreenADCS  = bsxfun(@minus,gazeData.gazePoint.onDisplayArea,pointOnScreenDA);
            offOnScreenCm    = bsxfun(@times,offOnScreenADCS,[obj.geom.width,obj.geom.height].');
            offOnScreenDir   = atan2(offOnScreenCm(2,:),offOnScreenCm(1,:));
            
            vecToPoint  = bsxfun(@minus,pointOnScreenUCS,gazeData.gazeOrigin.inUserCoords);
            gazeVec     = gazeData.gazePoint.inUserCoords-gazeData.gazeOrigin.inUserCoords;
            angs2D      = obj.AngleBetweenVectors(vecToPoint,gazeVec);
            out.offs    = bsxfun(@times,angs2D,[cos(offOnScreenDir); sin(offOnScreenDir)]);
            out.acc     = nanmean(out.offs,2);
            
            % 2. RMS
            out.RMS     = sqrt(nanmean(diff(out.offs,[],2).^2,2));
            out.RMS2D   = hypot(out.RMS(1),out.RMS(2));
            
            % 3. STD
            out.STD     = nanstd(out.offs,[],2);
            out.STD2D   = hypot(out.STD(1),out.STD(2));
            
            % 4. track ratio
            out.trackRatio  = sum(gazeData.gazePoint.validity==1)/length(gazeData.gazePoint.validity);
        end
        
        function out = ADCSToUCS(obj,data)
            % data is a 2xN matrix of normalized coordinates
            xVec = obj.geom.top_right-obj.geom.top_left;
            yVec = obj.geom.bottom_right-obj.geom.top_right;
            out  = bsxfun(@plus,obj.geom.top_left,bsxfun(@times,data(1,:),xVec)+bsxfun(@times,data(2,:),yVec));
        end
        
        function out = DataTobiiToScreen(obj,data,res)
            % data is a 2xN matrix of normalized coordinates
            if nargin<3
                res = obj.scrInfo.resolution;
            end
            out = bsxfun(@times,data,res(:));
        end
        
        function angle = AngleBetweenVectors(~,a,b)
            angle = atan2(sqrt(sum(cross(a,b,1).^2,1)),dot(a,b,1))*180/pi;
        end
        
        function [status,selection] = showCalValResult(obj,wpnt,cal,kCal)
            % status output:
            %  1: calibration/validation accepted, continue (a)
            %  2: just continue with task (shift+s)
            % -1: restart calibration (escape key)
            % -2: go back to setup (s)
            % -4: Exit completely (control+escape)
            %
            % additional buttons
            % c: chose other calibration (if have more than one valid)
            % g: show gaze (and fixation points)
            
            % find how many valid calibrations we have:
            selection = kCal;
            iValid = obj.getValidCalibrations(cal);
            if ~ismember(selection,iValid)
                % this happens if setup cancelled to go directly to this validation
                % viewer
                selection = iValid(end);
            end
            qHaveMultipleValidCals = ~isscalar(iValid);
            % detect if average eyes
            qAveragedEyes = cal{selection}.validateAccuracy.deviationLX==cal{selection}.validateAccuracy.deviationRX && cal{selection}.validateAccuracy.deviationLY==cal{selection}.validateAccuracy.deviationRY;
            
            % setup buttons
            % 1. below screen
            yposBase    = round(obj.scrInfo.resolution(2)*.95);
            buttonSz    = {[300 45] [300 45] [350 45]};
            buttonSz    = buttonSz(1:2+qHaveMultipleValidCals);  % third button only when more than one calibration available
            buttonOff   = 80;
            buttonWidths= cellfun(@(x) x(1),buttonSz);
            totWidth    = sum(buttonWidths)+(length(buttonSz)-1)*buttonOff;
            buttonRectsX= cumsum([0 buttonWidths]+[0 ones(1,length(buttonWidths))]*buttonOff)-totWidth/2;
            recalButRect        = OffsetRect([buttonRectsX(1) 0 buttonRectsX(2)-buttonOff buttonSz{1}(2)],obj.scrInfo.center(1),yposBase-buttonSz{2}(2));
            recalButTextCache   = obj.getButtonTextCache(wpnt,'recalibrate (<i>esc<i>)'  ,    recalButRect);
            continueButRect     = OffsetRect([buttonRectsX(2) 0 buttonRectsX(3)-buttonOff buttonSz{2}(2)],obj.scrInfo.center(1),yposBase-buttonSz{1}(2));
            continueButTextCache= obj.getButtonTextCache(wpnt,'continue (<i>spacebar<i>)', continueButRect);
            if qHaveMultipleValidCals
                selectButRect       = OffsetRect([buttonRectsX(3) 0 buttonRectsX(4)-buttonOff buttonSz{3}(2)],obj.scrInfo.center(1),yposBase-buttonSz{3}(2));
                selectButTextCache  = obj.getButtonTextCache(wpnt,'select other cal (<i>c<i>)', selectButRect);
            else
                selectButRect = [-100 -90 -100 -90]; % offscreen so mouse handler doesn't fuck up because of it
            end
            % 2. atop screen
            topMargin           = 50;
            buttonSz            = {[200 45] [250 45]};
            buttonOff           = 550;
            showGazeButClrs     = {[37  97 163],[11 122 244]};
            setupButRect        = OffsetRect([0 0 buttonSz{1}],obj.scrInfo.center(1)-buttonOff/2-buttonSz{1}(1),topMargin+buttonSz{1}(2));
            setupButTextCache   = obj.getButtonTextCache(wpnt,'setup (<i>s<i>)'    ,   setupButRect);
            showGazeButRect     = OffsetRect([0 0 buttonSz{2}],obj.scrInfo.center(1)+buttonOff/2               ,topMargin+buttonSz{1}(2));
            showGazeButTextCache= obj.getButtonTextCache(wpnt,'show gaze (<i>g<i>)',showGazeButRect);
            
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
                menuRects = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]);
                % text in each rect
                for c=1:length(iValid)
                    str = sprintf('(%d): <color=ff0000>Left<color>: (%.2f°,%.2f°), <color=00ff00>Right<color>: (%.2f°,%.2f°)',c,cal{iValid(c)}.validateAccuracy.deviationLX,cal{iValid(c)}.validateAccuracy.deviationLY,cal{iValid(c)}.validateAccuracy.deviationRX,cal{iValid(c)}.validateAccuracy.deviationRY);
                    menuTextCache(c) = obj.getButtonTextCache(wpnt,str,menuRects(c,:)); %#ok<AGROW>
                end
            end
            
            % setup fixation points in the corners of the screen
            fixPos = [.1 .1; .1 .9; .9 .9; .9 .1] .* repmat(obj.scrInfo.resolution(1:2),4,1);
            
            qDoneCalibSelection = false;
            qSelectMenuOpen     = false;
            qShowGaze           = false;
            tex                 = 0;
            pSampleS            = SMIStructEnum.Sample;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            while ~qDoneCalibSelection
                % draw validation screen image
                if tex~=0
                    Screen('Close',tex);
                end
                tex   = Screen('MakeTexture',wpnt,cal{selection}.validateImage,[],8);   % 8 to prevent mipmap generation, we don't need it
                
                % setup cursors
                if qSelectMenuOpen
                    cursors.rect    = {menuRects.',continueButRect.',recalButRect.'};
                    cursors.cursor  = 2*ones(1,size(menuRects,1)+2);    % 2: Hand
                else
                    cursors.rect    = {continueButRect.',recalButRect.',selectButRect.',setupButRect.',showGazeButRect.'};
                    cursors.cursor  = [2 2 2 2 2];  % 2: Hand
                end
                cursors.other   = 0;    % 0: Arrow
                cursors.qReset  = false;
                % NB: don't reset cursor to invisible here as it will then flicker every
                % time you click something. default behaviour is good here
                cursor = cursorUpdater(cursors);
                
                while true % draw loop
                    Screen('DrawTexture', wpnt, tex);   % its a fullscreen image, so just draw
                    % setup text
                    Screen('TextFont',  wpnt, obj.settings.text.font);
                    Screen('TextSize',  wpnt, obj.settings.text.size);
                    Screen('TextStyle', wpnt, obj.settings.text.style);
                    % draw text with validation accuracy info
                    valText = sprintf('<font=Consolas><size=20>accuracy   X       Y\n   <color=ff0000>Left<color>: % 2.2f°  % 2.2f°\n  <color=00ff00>Right<color>: % 2.2f°  % 2.2f°',cal{selection}.validateAccuracy.deviationLX,cal{selection}.validateAccuracy.deviationLY,cal{selection}.validateAccuracy.deviationRX,cal{selection}.validateAccuracy.deviationRY);
                    if obj.usingFTGLTextRenderer
                        DrawFormattedText2(valText,'win',wpnt,'sx','center','xalign','center','sy',100,'baseColor',255,'vSpacing',obj.settings.text.vSpacing);
                    else
                        DrawMonospacedText(wpnt,valText,'center',100,255,[],obj.settings.text.vSpacing);
                    end
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
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        [ret,pSample] = obj.iView.getSample(pSampleS);
                        if ret==1
                            % draw
                            if ~(pSample.leftEye .gazeX==0 && pSample.leftEye .gazeY==0)
                                Screen('gluDisk', wpnt,[255 0 0], pSample. leftEye.gazeX, pSample. leftEye.gazeY, 10);
                            end
                            if ~(pSample.rightEye.gazeX==0 && pSample.rightEye.gazeY==0)
                                Screen('gluDisk', wpnt,[0 255 0], pSample.rightEye.gazeX, pSample.rightEye.gazeY, 10);
                            end
                        end
                        % draw fixation points
                        obj.drawFixPoints(wpnt,fixPos);
                    end
                    % drawing done, show
                    Screen('Flip',wpnt);
                    
                    % get user response
                    [mx,my,buttons,keyCode,haveShift] = obj.getNewMouseKeyPress();
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if any(buttons)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectMenuOpen
                            iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn) && iIn<=length(iValid)
                                selection = iValid(iIn);
                                obj.loadOtherCal(selection);
                                qSelectMenuOpen = false;
                                break;
                            else
                                qSelectMenuOpen = false;
                                break;
                            end
                        end
                        if ~qSelectMenuOpen     % if pressed outside the menu, check if pressed any of these menu buttons
                            qIn = inRect([mx my],[continueButRect.' recalButRect.' selectButRect.' setupButRect.' showGazeButRect.']);
                            if any(qIn)
                                if qIn(1)
                                    status = 1;
                                    qDoneCalibSelection = true;
                                elseif qIn(2)
                                    status = -1;
                                    qDoneCalibSelection = true;
                                elseif qIn(3)
                                    qSelectMenuOpen     = true;
                                elseif qIn(4)
                                    status = -2;
                                    qDoneCalibSelection = true;
                                elseif qIn(5)
                                    qShowGaze           = ~qShowGaze;
                                end
                                break;
                            end
                        end
                    elseif any(keyCode)
                        keys = KbName(keyCode);
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape'))
                                qSelectMenuOpen = false;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                idx = str2double(keys(1));
                                selection = iValid(idx);
                                obj.loadOtherCal(selection);
                                qSelectMenuOpen = false;
                                break;
                            end
                        else
                            if any(strcmpi(keys,'space'))
                                status = 1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'escape')) && ~haveShift
                                status = -1;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'s')) && ~haveShift
                                status = -2;
                                qDoneCalibSelection = true;
                                break;
                            elseif any(strcmpi(keys,'c')) && qHaveMultipleValidCals
                                qSelectMenuOpen     = ~qSelectMenuOpen;
                                break;
                            elseif any(strcmpi(keys,'g'))
                                qShowGaze           = ~qShowGaze;
                                break;
                            end
                        end
                        
                        % these two key combinations should always be available
                        if any(strcmpi(keys,'escape')) && haveShift
                            status = -4;
                            qDoneCalibSelection = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && haveShift
                            % skip calibration
                            obj.iView.abortCalibration();
                            status = 2;
                            qDoneCalibSelection = true;
                            break;
                        end
                    end
                end
            end
            % done, clean up
            cursor.reset();
            Screen('Close',tex);
            if status~=1
                selection = NaN;
            end
            HideCursor;
        end
        
        function loadOtherCal(obj,which)
            obj.iView.loadCalibration(num2str(which));
            % check correct one is loaded -- well, apparently below function returns
            % last calibration's accuracy, not loaded calibration. So we can't check
            % this way..... I have verified that loading works on the RED-m.
            % [~,validateAccuracy] = obj.iView.getAccuracy([], 0);
            % assert(isequal(validateAccuracy,out.attempt{selection}.validateAccuracy),'failed to load selected calibration');
        end
        
        function iValid = getValidCalibrations(~,cal)
            iValid = find(cellfun(@(x) isfield(x,'calStatusSMI') && strcmp(x.calStatusSMI,'calibrationValid'),cal));
        end
        
        function out = isTwoComputerSetup(obj)
            out = length(obj.settings.connectInfo)==4 && ~strcmp(obj.settings.connectInfo{1},obj.settings.connectInfo{3});
        end
        
        function [mx,my,mouse,key,haveShift] = getNewMouseKeyPress(obj)
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
            haveShift = ~~keyCode(obj.shiftKey);
            
            % store to state
            obj.keyState    = keyCode;
            obj.mouseState  = buttons;
        end
    end
end