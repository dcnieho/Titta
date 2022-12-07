% Titta is a toolbox providing convenient access to eye tracking
% functionality using Tobii eye trackers 
%
%    Titta can be found at https://github.com/dcnieho/Titta. Check there
%    for the latest version.
%    When using Titta, please cite the following paper:
%
%    Niehorster, D.C., Andersson, R. & Nystrom, M., (2020). Titta: A
%    toolbox for creating Psychtoolbox and Psychopy experiments with Tobii
%    eye trackers. Behavior Research Methods.
%    doi: https://doi.org/10.3758/s13428-020-01358-8
%
%    For detailed documentation, refer to <a href="https://github.com/dcnieho/Titta/blob/master/readme.md">the readme on GitHub</a>.
%
%    For help on the constructor method, type:
%      <a href="matlab: help Titta.Titta">help Titta.Titta</a>
%
%    For static methods:
%      <a href="matlab: help Titta.getDefaults">help Titta.getDefaults</a>
%      <a href="matlab: help Titta.getFileName">help Titta.getFileName</a>
%      <a href="matlab: help Titta.getTimeAsSystemTime">help Titta.getTimeAsSystemTime</a>
%      <a href="matlab: help Titta.getValidationQualityMessage">help Titta.getValidationQualityMessage</a>
%
%    For methods:
%      <a href="matlab: help Titta.setDummyMode">help Titta.setDummyMode</a>
%      <a href="matlab: help Titta.getOptions">help Titta.getOptions</a>
%      <a href="matlab: help Titta.setOptions">help Titta.setOptions</a>
%      <a href="matlab: help Titta.init">help Titta.init</a>
%      <a href="matlab: help Titta.calibrate">help Titta.calibrate</a>
%      <a href="matlab: help Titta.calibrateManual">help Titta.calibrateManual</a>
%      <a href="matlab: help Titta.sendMessage">help Titta.sendMessage</a>
%      <a href="matlab: help Titta.getMessages">help Titta.getMessages</a>
%      <a href="matlab: help Titta.collectSessionData">help Titta.collectSessionData</a>
%      <a href="matlab: help Titta.saveData">help Titta.saveData</a>
%      <a href="matlab: help Titta.deInit">help Titta.deInit</a>
%    
%    For properties:
%      <a href="matlab: help Titta.geom">help Titta.geom</a>
%      <a href="matlab: help Titta.calibrateHistory">help Titta.calibrateHistory</a>
%      <a href="matlab: help Titta.buffer">help Titta.buffer</a>
%      <a href="matlab: help Titta.deviceName">help Titta.deviceName</a>
%      <a href="matlab: help Titta.serialNumber">help Titta.serialNumber</a>
%      <a href="matlab: help Titta.model">help Titta.model</a>
%      <a href="matlab: help Titta.firmwareVersion">help Titta.firmwareVersion</a>
%      <a href="matlab: help Titta.runtimeVersion">help Titta.runtimeVersion</a>
%      <a href="matlab: help Titta.address">help Titta.address</a>
%      <a href="matlab: help Titta.capabilities">help Titta.capabilities</a>
%      <a href="matlab: help Titta.frequency">help Titta.frequency</a>
%      <a href="matlab: help Titta.trackingMode">help Titta.trackingMode</a>
%      <a href="matlab: help Titta.supportedFrequencies">help Titta.supportedFrequencies</a>
%      <a href="matlab: help Titta.supportedModes">help Titta.supportedModes</a>
%      <a href="matlab: help Titta.systemInfo">help Titta.systemInfo</a>

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
        eyeImageCanvasSize  = [];
        
        % settings and external info
        settings;
        scrInfo;
    end
    
    properties (SetAccess=protected)
        % Information about eye tracking setup's geometry
        %
        %    Titta.geom is a struct with information about the setup
        %    geometry known to the eye tracker, such as screen width and
        %    height, and the screen's location in the eye tracker's user
        %    coordinate system. Filled when Titta.init() is called.
        geom;
        
        % Information about all performed calibration attempts
        %
        %    Titta.calibrateHistory is a cell array with information about
        %    all calibration attempts during the current session.
        calibrateHistory;
        
        % Handle to TittaMex instance for interaction with eye tracker
        %
        %    Titta.buffer is a handle to TittaMex instance for interaction
        %    with the eye tracker's data streams, or for directly
        %    interacting with the eye tracker through the Tobii Pro SDK.
        %    Note that this is at your own risk. Titta should have minimal
        %    assumptions about eye-tracker state, but I cannot guarantee
        %    that direct interaction with the eye tracker does not
        %    interfere with later use of Titta in the same session.
        %    Initialized when Titta.init() is called.
        buffer;
    end
    
    properties (Dependent, SetAccess=private)
        % Get connected eye tracker's device name
        deviceName
        % Get connected eye tracker's serial number
        serialNumber
        % Get connected eye tracker's model name
        model
        % Get connected eye tracker's firmware version
        firmwareVersion
        % Get connected eye tracker's runtime version
        runtimeVersion
        % Get connected eye tracker's address
        address
        % Get connected eye tracker's exposed capabilities
        capabilities
        % Get connected eye tracker's supported sampling frequencies
        supportedFrequencies
        % Get connected eye tracker's supported tracking modes
        supportedModes
        
        % Get information about connected eye tracker
        %
        %    Titta.systemInfo is a struct that contains information about
        %    the device name, serial number, model name, firmware version,
        %    runtime version, address, sampling frequency, tracking mode,
        %    capabilities, supported sampling frequencies, and supported
        %    tracking modes of the connected eye tracker.
        systemInfo
    end
    properties (Dependent)
        % Get or set connected eye tracker's sampling frequency
        frequency
        % Get or set connected eye tracker's tracking mode
        trackingMode
    end
    
    methods
        function obj = Titta(settingsOrETName)
            % Construct Titta instance
            %
            %    EThndl = Titta(TRACKERMODEL) constructs a Titta instance
            %    with the default settings for the given TRACKERMODEL eye
            %    tracker.
            %
            %    EThndl = Titta(SETTINGS) constructs a Titta instance
            %    with the settings specified in SETTINGS.
            
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
            % Enable dummy mode
            %
            %    Turn the current Titta instance into a dummy mode class.
            %    EThndl = Titta.setDummyMode() returns a handle to a
            %    TittaDummyMode instance.
            
            assert(nargout==1,'Titta: you must use the output argument of setDummyMode, like: TobiiHandle = TobiiHandle.setDummyMode(), or TobiiHandle = setDummyMode(TobiiHandle)')
            out = TittaDummyMode(obj);
        end
        
        function out = getOptions(obj)
            % Get active settings
            % 
            %    SETTINGS = Titta.getOptions() returns the currently active
            %    settings. Only those settings that can be changed in the
            %    current state are returned (which is a subset of all
            %    settings once Titta.init() has been called)
            % 
            %    See also TITTA.SETOPTIONS
            
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
            % Change active settings
            % 
            %    Titta.setOptions(SETTINGS) changes the active settings to
            %    those specified in SETTINGS. First use getOptions() to get
            %    an up-to-date settings struct, then edit the wanted
            %    settings and use this function to apply themm.
            % 
            %    See also TITTA.GETOPTIONS
            
            % special handling of changes to frequency and tracking mode:
            % setting them on the Titta object has them changed on the eye
            % tracker
            if isfield(settings,'freq') && isfield(obj.settings,'freq') && settings.freq ~= obj.settings.freq
                obj.frequency = settings.freq;
            end
            if isfield(settings,'trackingMode') && isfield(obj.settings,'trackingMode') && ~strcmp(settings.trackingMode,obj.settings.trackingMode)
                obj.trackingMode = settings.trackingMode;
            end
            
            % handle other settings
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
            
            % check requested eye calibration mode
            obj.changeAndCheckCalibEyeMode();

            % calibration point setup
            assert(isempty(settings.cal.pointPosTrackerSpace       ) || isequal(size(settings.cal.pointPosTrackerSpace       ),size(settings.cal.pointPos))       ,'settings.cal.pointPosTrackerSpace should either be empty or the same size as settings.cal.pointPos')
            if ~isempty(settings.cal.pointPosTrackerSpace)
                assert(~isequal(obj.settings.cal.pointPosTrackerSpace,obj.settings.cal.pointPos),'if settings.cal.pointPosTrackerSpace is set, it should not contain the same values as settings.cal.pointPos')
                assert(~isempty(settings.val.pointPosTrackerSpace),'If the position of calibration points is specified using settings.cal.pointPosTrackerSpace, the position of validation points in tracker space should also be specified using settings.val.pointPosTrackerSpace')
                assert(~isequal(obj.settings.val.pointPosTrackerSpace,obj.settings.val.pointPos),'if settings.val.pointPosTrackerSpace is set, it should not contain the same values as settings.val.pointPos')
            else
                assert( isempty(settings.val.pointPosTrackerSpace),'settings.val.pointPosTrackerSpace should not be specified if settings.cal.pointPosTrackerSpace is empty')
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
            obj.settings.UI.setup.eyeClrPosMissing      = color2RGBA(obj.settings.UI.setup.eyeClrPosMissing);
            obj.settings.UI.setup.eyeBorderClr          = color2RGBA(obj.settings.UI.setup.eyeBorderClr);
            obj.settings.UI.setup.eyeLidClr             = color2RGBA(obj.settings.UI.setup.eyeLidClr);
            obj.settings.UI.setup.pupilClr              = color2RGBA(obj.settings.UI.setup.pupilClr);
            obj.settings.UI.setup.crossClr              = color2RGBA(obj.settings.UI.setup.crossClr);
            obj.settings.UI.setup.fixBackColor          = color2RGBA(obj.settings.UI.setup.fixBackColor);
            obj.settings.UI.setup.fixFrontColor         = color2RGBA(obj.settings.UI.setup.fixFrontColor);
            obj.settings.UI.setup.instruct.color        = color2RGBA(obj.settings.UI.setup.instruct.color);
            obj.settings.UI.setup.menu.bgColor          = color2RGBA(obj.settings.UI.setup.menu.bgColor);
            obj.settings.UI.setup.menu.itemColor        = color2RGBA(obj.settings.UI.setup.menu.itemColor);
            obj.settings.UI.setup.menu.itemColorActive  = color2RGBA(obj.settings.UI.setup.menu.itemColorActive);
            obj.settings.UI.setup.menu.text.color       = color2RGBA(obj.settings.UI.setup.menu.text.color);
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
            
            obj.settings.UI.button.setup.toggEyeIm.fillColor= color2RGBA(obj.settings.UI.button.setup.toggEyeIm.fillColor);
            obj.settings.UI.button.setup.toggEyeIm.edgeColor= color2RGBA(obj.settings.UI.button.setup.toggEyeIm.edgeColor);
            obj.settings.UI.button.setup.toggEyeIm.textColor= color2RGBA(obj.settings.UI.button.setup.toggEyeIm.textColor);
            obj.settings.UI.button.setup.cal.fillColor      = color2RGBA(obj.settings.UI.button.setup.cal.fillColor);
            obj.settings.UI.button.setup.cal.edgeColor      = color2RGBA(obj.settings.UI.button.setup.cal.edgeColor);
            obj.settings.UI.button.setup.cal.textColor      = color2RGBA(obj.settings.UI.button.setup.cal.textColor);
            obj.settings.UI.button.setup.prevcal.fillColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.fillColor);
            obj.settings.UI.button.setup.prevcal.edgeColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.edgeColor);
            obj.settings.UI.button.setup.prevcal.textColor  = color2RGBA(obj.settings.UI.button.setup.prevcal.textColor);
            obj.settings.UI.button.setup.changeeye.fillColor= color2RGBA(obj.settings.UI.button.setup.changeeye.fillColor);
            obj.settings.UI.button.setup.changeeye.edgeColor= color2RGBA(obj.settings.UI.button.setup.changeeye.edgeColor);
            obj.settings.UI.button.setup.changeeye.textColor= color2RGBA(obj.settings.UI.button.setup.changeeye.textColor);
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
            obj.settings.UI.button.val.toggPlot.fillColor   = color2RGBA(obj.settings.UI.button.val.toggPlot.fillColor);
            obj.settings.UI.button.val.toggPlot.edgeColor   = color2RGBA(obj.settings.UI.button.val.toggPlot.edgeColor);
            obj.settings.UI.button.val.toggPlot.textColor   = color2RGBA(obj.settings.UI.button.val.toggPlot.textColor);
            
            obj.settings.UI.plot.bgColor                    = color2RGBA(obj.settings.UI.plot.bgColor);
            obj.settings.UI.plot.eyeColors                  = color2RGBA(obj.settings.UI.plot.eyeColors);
            obj.settings.UI.plot.dotPosLine.color           = color2RGBA(obj.settings.UI.plot.dotPosLine.color);
            obj.settings.UI.plot.ax.bgColor                 = color2RGBA(obj.settings.UI.plot.ax.bgColor);
            obj.settings.UI.plot.ax.lineColor               = color2RGBA(obj.settings.UI.plot.ax.lineColor);
            obj.settings.UI.plot.ax.highlightColor          = color2RGBA(obj.settings.UI.plot.ax.highlightColor);
            obj.settings.UI.plot.ax.axisLbl.color           = color2RGBA(obj.settings.UI.plot.ax.axisLbl.color);
            obj.settings.UI.plot.ax.tickLbl.color           = color2RGBA(obj.settings.UI.plot.ax.tickLbl.color);
            obj.settings.UI.plot.ax.valLbl.color            = color2RGBA(obj.settings.UI.plot.ax.valLbl.color);
            obj.settings.UI.plot.but.exit.fillColor         = color2RGBA(obj.settings.UI.plot.but.exit.fillColor);
            obj.settings.UI.plot.but.exit.edgeColor         = color2RGBA(obj.settings.UI.plot.but.exit.edgeColor);
            obj.settings.UI.plot.but.exit.textColor         = color2RGBA(obj.settings.UI.plot.but.exit.textColor);
            obj.settings.UI.plot.but.valSel.fillColor       = color2RGBA(obj.settings.UI.plot.but.valSel.fillColor);
            obj.settings.UI.plot.but.valSel.edgeColor       = color2RGBA(obj.settings.UI.plot.but.valSel.edgeColor);
            obj.settings.UI.plot.but.valSel.textColor       = color2RGBA(obj.settings.UI.plot.but.valSel.textColor);
            
            obj.settings.UI.mancal.instruct.color               = color2RGBA(obj.settings.UI.mancal.instruct.color);
            obj.settings.UI.button.mancal.changeeye.fillColor   = color2RGBA(obj.settings.UI.button.mancal.changeeye.fillColor);
            obj.settings.UI.button.mancal.changeeye.edgeColor   = color2RGBA(obj.settings.UI.button.mancal.changeeye.edgeColor);
            obj.settings.UI.button.mancal.changeeye.textColor   = color2RGBA(obj.settings.UI.button.mancal.changeeye.textColor);
            obj.settings.UI.button.mancal.toggEyeIm.fillColor   = color2RGBA(obj.settings.UI.button.mancal.toggEyeIm.fillColor);
            obj.settings.UI.button.mancal.toggEyeIm.edgeColor   = color2RGBA(obj.settings.UI.button.mancal.toggEyeIm.edgeColor);
            obj.settings.UI.button.mancal.toggEyeIm.textColor   = color2RGBA(obj.settings.UI.button.mancal.toggEyeIm.textColor);
            obj.settings.UI.button.mancal.calval.fillColor      = color2RGBA(obj.settings.UI.button.mancal.calval.fillColor);
            obj.settings.UI.button.mancal.calval.edgeColor      = color2RGBA(obj.settings.UI.button.mancal.calval.edgeColor);
            obj.settings.UI.button.mancal.calval.textColor      = color2RGBA(obj.settings.UI.button.mancal.calval.textColor);
            obj.settings.UI.button.mancal.continue.fillColor    = color2RGBA(obj.settings.UI.button.mancal.continue.fillColor);
            obj.settings.UI.button.mancal.continue.edgeColor    = color2RGBA(obj.settings.UI.button.mancal.continue.edgeColor);
            obj.settings.UI.button.mancal.continue.textColor    = color2RGBA(obj.settings.UI.button.mancal.continue.textColor);
            obj.settings.UI.button.mancal.snapshot.fillColor    = color2RGBA(obj.settings.UI.button.mancal.snapshot.fillColor);
            obj.settings.UI.button.mancal.snapshot.edgeColor    = color2RGBA(obj.settings.UI.button.mancal.snapshot.edgeColor);
            obj.settings.UI.button.mancal.snapshot.textColor    = color2RGBA(obj.settings.UI.button.mancal.snapshot.textColor);
            obj.settings.UI.button.mancal.toggHead.fillColor    = color2RGBA(obj.settings.UI.button.mancal.toggHead.fillColor);
            obj.settings.UI.button.mancal.toggHead.edgeColor    = color2RGBA(obj.settings.UI.button.mancal.toggHead.edgeColor);
            obj.settings.UI.button.mancal.toggHead.textColor    = color2RGBA(obj.settings.UI.button.mancal.toggHead.textColor);
            obj.settings.UI.button.mancal.toggGaze.fillColor    = color2RGBA(obj.settings.UI.button.mancal.toggGaze.fillColor);
            obj.settings.UI.button.mancal.toggGaze.edgeColor    = color2RGBA(obj.settings.UI.button.mancal.toggGaze.edgeColor);
            obj.settings.UI.button.mancal.toggGaze.textColor    = color2RGBA(obj.settings.UI.button.mancal.toggGaze.textColor);
            obj.settings.UI.mancal.menu.bgColor                 = color2RGBA(obj.settings.UI.mancal.menu.bgColor);
            obj.settings.UI.mancal.menu.itemColor               = color2RGBA(obj.settings.UI.mancal.menu.itemColor);
            obj.settings.UI.mancal.menu.itemColorActive         = color2RGBA(obj.settings.UI.mancal.menu.itemColorActive);
            obj.settings.UI.mancal.menu.text.color              = color2RGBA(obj.settings.UI.mancal.menu.text.color);
            obj.settings.UI.mancal.menu.text.eyeColors          = color2RGBA(obj.settings.UI.mancal.menu.text.eyeColors);
            obj.settings.UI.mancal.avg.text.color               = color2RGBA(obj.settings.UI.mancal.avg.text.color);
            obj.settings.UI.mancal.avg.text.eyeColors           = color2RGBA(obj.settings.UI.mancal.avg.text.eyeColors);
            obj.settings.UI.mancal.hover.bgColor                = color2RGBA(obj.settings.UI.mancal.hover.bgColor);
            obj.settings.UI.mancal.hover.text.color             = color2RGBA(obj.settings.UI.mancal.hover.text.color);
            obj.settings.UI.mancal.hover.text.eyeColors         = color2RGBA(obj.settings.UI.mancal.hover.text.eyeColors);
            obj.settings.UI.mancal.onlineGaze.eyeColors         = color2RGBA(obj.settings.UI.mancal.onlineGaze.eyeColors);
            obj.settings.UI.mancal.eyeColors                    = color2RGBA(obj.settings.UI.mancal.eyeColors);
            obj.settings.UI.mancal.bgColor                      = color2RGBA(obj.settings.UI.mancal.bgColor);
            obj.settings.UI.mancal.fixBackColor                 = color2RGBA(obj.settings.UI.mancal.fixBackColor);
            obj.settings.UI.mancal.fixFrontColor                = color2RGBA(obj.settings.UI.mancal.fixFrontColor);
            obj.settings.UI.mancal.fixPoint.text.color          = color2RGBA(obj.settings.UI.mancal.fixPoint.text.color);
            obj.settings.mancal.bgColor                         = color2RGBA(obj.settings.mancal.bgColor);
            obj.settings.mancal.fixBackColor                    = color2RGBA(obj.settings.mancal.fixBackColor);
            obj.settings.mancal.fixFrontColor                   = color2RGBA(obj.settings.mancal.fixFrontColor);
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
            % Initialize Titta instance
            %
            %    Titta.init() uses the currently active settings to 
            %    connects to the indicated Tobii eye tracker and
            %    initializes it.
            % 
            %    See also TITTA.TITTA, TITTA.GETOPTIONS, TITTA.SETOPTIONS
            
            % Load in our callback buffer mex
            obj.buffer = TittaMex();
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
            
            % set tracker specific internal paramters
            switch obj.settings.tracker
                case 'Tobii Pro Fusion'
                    obj.eyeImageCanvasSize = [600 300];    % width x height
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
            obj.changeAndCheckCalibEyeMode();
            
            % get info about the system
            assert(obj.systemInfo.frequency==obj.settings.freq,'Titta: Tracker not running at requested sampling rate (%d Hz), but at %d Hz',obj.settings.freq,obj.systemInfo.frequency);
            out.systemInfo                  = obj.systemInfo;
            
            % get information about display geometry and trackbox
            obj.geom.displayArea    = obj.buffer.getDisplayArea();
            try
                obj.geom.trackBox       = obj.buffer.getTrackBox();
                % get width and height of trackbox at middle depth
                obj.geom.trackBox.halfWidth     = mean([obj.geom.trackBox.frontUpperRight(1) obj.geom.trackBox.backUpperRight(1)])/10;
                obj.geom.trackBox.halfHeight    = mean([obj.geom.trackBox.frontUpperRight(2) obj.geom.trackBox.backUpperRight(2)])/10;
            catch
                % tracker does not support trackbox
                obj.geom.trackBox.halfWidth     = [];
                obj.geom.trackBox.halfHeight    = [];
            end
            out.geom                = obj.geom;
            
            % mark as inited
            obj.isInitialized = true;
        end
        
        function out = calibrate(obj,wpnt,flag,previousCalibs)
            % Do participant setup and calibration
            %
            %    CALIBRATIONATTEMPT = Titta.calibrate(WPNT) displays the
            %    participant setup and calibration interface on the
            %    PsychToolbox window specified by WPNT.
            %
            %    WPNT can also be an array of two window pointers.
            %    In this case, the first window pointer is taken to refer
            %    to the participant screen, and the second to an operator
            %    screen. A minimal interface is then presented on the
            %    participant screen, while full information is shown on the
            %    operator screen, including a live view of gaze data and
            %    eye images (if available) during calibration and
            %    validation.
            %
            %    CALIBRATIONATTEMPT is a struct containing information
            %    about the calibration/validation run.
            %
            %    CALIBRATIONATTEMPT = Titta.calibrate(WPNT,FLAG) provides
            %    control over whether the call causes the eye tracker's
            %    calibration mode to be entered or left. The available
            %    flags are:
            %      1 - enter calibration mode when starting calibration
            %      2 - exit calibration mode when calibration finished
            %      3 - (default) both enter and exit calibration mode
            %
            %    FLAG is used for bimonocular calibrations, when
            %    Titta.calibrate() is called twice in a row, first to
            %    calibrate the first eye (use FLAG=1 to enter calibration
            %    mode here but not exit), and then a second time to
            %    calibrate the other eye (use FLAG=2 to exit calibration
            %    mode when done).
            %
            %    CALIBRATIONATTEMPT = Titta.calibrate(WPNT,FLAG,PREVIOUSCALIBS)
            %    allows to prepopulate the interface with previous
            %    calibration(s). The previously selected calibration is
            %    made active and it can then be revalidated and used, or
            %    replaced. PREVIOUSCALIBS is expected to be a
            %    CALIBRATIONATTEMPT output from a previous run of
            %    Titta.calibrate. Note that the PREVIOUSCALIBS
            %    functionality should be used together with bimonocular
            %    calibration _only_ when the calibration of the first eye
            %    is not replaced (validating it is ok, and recommended).
            %    This because prepopulating calibrations for the second eye
            %    will load this previous calibration, and thus undo any new
            %    calibration for the first eye.
            %
            %    INTERFACE
            %    During anywhere on the participant setup and calibration
            %    screens, the following key combinations are available:
            %      shift-escape - hard exit from the calibration mode. By
            %                     default (see
            %                     settings.UI.hardExitClosesPTB), this
            %                     causes en error to be thrown and script
            %                     execution to stop if that error is not
            %                     caught.
            %      shift-s      - skip calibration. If still at setup
            %                     screen for the first time, the last
            %                     calibration (perhaps of a previous
            %                     session) remains active. To clear any
            %                     calibration, first enter the calibration
            %                     screen and immediately then skip with
            %                     this key combination.
            %      shift-d      - take screenshot of the participant
            %                     display, which will be stored to the
            %                     current active directory (cd).
            %      shift-o      - when in dual-screen mode, take a
            %                     screenshot of the operator display, which
            %                     will be stored to the current active
            %                     directory (cd).
            %      shift-g      - when in dual screen mode, by default the
            %                     show gaze button on the validation result
            %                     screen only shows real-time gaze position
            %                     on the operator's screen. If the shift
            %                     key is held down while clicking the
            %                     button with the mouse, or when pressing
            %                     the functionality's hotkey (g by
            %                     default, see documentation of validation
            %                     results screen interface below),
            %                     real-time gaze will also be shown on the
            %                     participant's screen.
            %
            %    In addition to these, the three different screens that
            %    make up this procedure each have their own keys available.
            %    Some of these are hardcoded, others can be changed through
            %    Titta's settings. In the latter case, their default value
            %    is listed here, and the settings name is indicated in
            %    abbreviated form (e.g. `setup.toggEyeIm` refers to the
            %    setting `settings.UI.button.setup.toggEyeIm.accelerator`,
            %    gotten from Titta.getDefaults() or Titta.getOptions()).
            %    For the setup and validation result displays, these keys
            %    have a clickable button in the interface associated with
            %    them. Most of these buttons are visible by default, but
            %    some are not. You can change button visibility by
            %    changing, e.g.,
            %    `settings.UI.button.setup.toggEyeIm.visible`. Invisible
            %    buttons can still be activated or deactivated by means of
            %    the configured keys.
            %
            %    Setup display:
            %      spacebar  - start a calibration (setup.cal)
            %      e         - toggle eye images, if available
            %                  (setup.toggEyeIm)
            %      p         - return to validation result display,
            %                  available if there are any previous
            %                  calibrations (setup.prevcal)
            %      c         - open menu to change which eye will be
            %                  calibrated (both, left, right). The menu can
            %                  be keyboard-controlled: each of the items in
            %                  the menu are preceded by the number to press
            %                  to activate that option. Available only if
            %                  the eye tracker supports monocular
            %                  calibration (setup.changeeye)
            %   
            %    Calibration and validation display:
            %      escape    - return to setup screen.
            %      r         - restart calibration sequence from the
            %                  beginning
            %      backspace - redo the current calibration/validation
            %                  point. When using the
            %                  AnimatedCalibrationDisplay class
            %                  (settings.cal.drawFunction), this causes the
            %                  currently displayed point to blink.
            %      spacebar  - accept current calibration/validation point.
            %                  Whether it is needed to press spacebar to
            %                  collect data for a point depends on the
            %                  settings.cal.autoPace setting.
            %   
            %    Validation result display:
            %      spacebar  - select currently displayed calibration and
            %                  exit the interface/continue experiment
            %                  (val.continue)
            %      escape    - start a new calibration (val.recal)
            %      v         - revalidate the current calibration
            %                  (val.reval)
            %      s         - return to the setup screen (val.setup)
            %      c         - bring up a menu from which other
            %                  calibrations performed in the same session
            %                  can be selected (val.selcal)
            %      g         - toggle whether online gaze position is
            %                  visualized on the screen. When in dual
            %                  screen mode, gaze will only be visualized to
            %                  the operator. Press shift-g (or hold down
            %                  shift while pressing the interface button
            %                  with the mouse) to also show the online
            %                  gaze position on the participant screen
            %                  (val.toggGaze)
            %      p         - bring up plot of gaze and pupil data
            %                  collected during validation (val.toggPlot)
            %      t         - toggle between whether gaze data collected
            %                  during validation or during calibration is
            %                  shown in the interface (val.toggCal)
            %      x         - toggle between whether gaze data and
            %                  calibrations are shown in screen space or
            %                  tracker space (these are the same unless
            %                  settings.cal.pointPosTrackerSpace is
            %                  specified) are shown in the interface
            %                  (val.toggSpace)
            %
            %    See also TITTA.CALIBRATEMANUAL, TITTA.GETOPTIONS,
            %    TITTA.GETDEFAULTS
            
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
            if nargin<4 || isempty(previousCalibs)
                previousCalibs = [];
            end
            
            % get info about screen
            screenState = obj.getScreenInfo(wpnt);
            
            % init key, mouse state
            [~,~,obj.keyState] = KbCheck();
            [~,~,obj.mouseState] = GetMouse();
            
            % make sure we get eye openness data if available
            qHasEyeOpenness = obj.buffer.hasStream('eyeOpenness');
            if qHasEyeOpenness
                prevEyeOpennessState = obj.buffer.setIncludeEyeOpennessInGaze(true);
            end
            
            %%% 1. some preliminary setup, to make sure we are in known state
            if bitand(flag,1)
                obj.buffer.leaveCalibrationMode(true);  % make sure we're not already in calibration mode (start afresh)
            end
            obj.StopRecordAll();
            
            %%% 2. enter the setup/calibration screens
            % The below is a big loop that will run possibly multiple
            % calibration until exiting because skipped or a calibration is
            % selected by user.
            % there are two start modes:
            % 0. skip head positioning, go straight to calibration
            % 1. start with head positioning interface
            startScreen             = obj.settings.UI.startScreen;
            qHasEnteredCalMode      = false;
            qGoToValidationViewer   = false;
            if ~isempty(previousCalibs)
                % prepopulate with previous calibrations passed by user
                out                 = previousCalibs;
                % preload the one previously selected by user
                kCal                = out.selectedCal;      % index into list of calibration attempts
                if bitand(flag,1) && ~qHasEnteredCalMode
                    % else, assume calibration mode has already been
                    % entered. If that is not the case, its user error when
                    % the loadOtherCal() below fails.
                    obj.doEnterCalibrationMode();
                    qHasEnteredCalMode = true;
                end
                obj.loadOtherCal(out.attempt{kCal},kCal,[],true);
                currentSelection    = kCal;                 % keeps track of calibration that is currently applied
                % NB: qNewCal should also in this case be true, as the
                % setup screen shown first is the start of a potential new
                % calibration, if users skip to previously loaded
                % calibrations, they cancel this potential new calibration
                % like normal. Also, without this, when loading a previous
                % calibration (this code branch) and then pressing
                % continue/calibrate on the setup screen, a new validation
                % is added for the loaded calibration, not a new
                % calibration started.
                if startScreen==0
                    % when user wants to skip the setup screen, bring them
                    % straight to the validation result screen when loading
                    % a previous calibration.
                    qGoToValidationViewer = true;
                end
            else
                kCal                = 0;                    % index into list of calibration attempts
                currentSelection    = nan;                  % keeps track of calibration that is currently applied
            end
            qNewCal             = true;
            out.type            = 'standard';
            out.selectedCal     = nan;
            out.wasSkipped      = false;
            while true
                if qNewCal
                    if ~kCal
                        kCal = 1;
                    else
                        kCal = length(out.attempt)+1;
                    end
                    out.attempt{kCal}.timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                    out.attempt{kCal}.device    = obj.settings.tracker;
                end
                if startScreen==1
                    %%% 2a: show head positioning screen
                    [out.attempt{kCal}.setupStatus,qCalReset] = obj.showHeadPositioning(wpnt,out);
                    if qCalReset
                        currentSelection = nan;
                    end
                    switch out.attempt{kCal}.setupStatus
                        case 1
                            % all good, continue
                        case 2
                            % skip setup
                            out.wasSkipped = true;
                            out.selectedCal = currentSelection; % though skipped, we may have a previous succesful calibration applied at this stage already, log that
                            break;
                        case -4
                            % go to validation viewer screen
                            qGoToValidationViewer = true;
                        case -5
                            % full stop
                            obj.buffer.leaveCalibrationMode();
                            if obj.settings.UI.hardExitClosesPTB
                                sca
                                ListenChar(0); Priority(0);
                            end
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
                        obj.doEnterCalibrationMode();
                        qHasEnteredCalMode = true;
                    end
                    out.attempt{kCal} = obj.DoCalAndVal(wpnt,kCal,out.attempt{kCal});
                    % check returned action state
                    switch out.attempt{kCal}.status
                        case 1
                            % all good, continue
                            currentSelection = kCal;
                        case 2
                            % skip setup
                            out.wasSkipped  = true;
                            out.selectedCal = currentSelection; % though skipped, we may have a previous succesful calibration applied at this stage already, log that
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
                            if obj.settings.UI.hardExitClosesPTB
                                sca
                                ListenChar(0); Priority(0);
                            end
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
                qGoToValidationViewer = false;
                [out.attempt,kCal] = obj.showCalValResult(wpnt,out.attempt,currentSelection);
                currentSelection = kCal;
                switch out.attempt{kCal}.valReviewStatus
                    case 1
                        % all good, we're done
                        out.selectedCal = kCal;
                        break;
                    case 2
                        % skip setup
                        out.wasSkipped = true;
                        out.selectedCal = kCal; % even though skipped, if done so at this stage, we still have a calibration applied, so log that
                        break;
                    case {-1,-2}
                        % -1: redo calibration+validation
                        % -2: redo validation only, so add a validation to
                        %     the current calibration
                        startScreen = 0;
                        % indicate if redo cal or redo val
                        qNewCal     = out.attempt{kCal}.valReviewStatus==-1;    % true if redo calibration, false if only redo validation
                        continue;
                    case -3
                        % go to setup
                        startScreen = 1;
                        qNewCal     = true;
                        continue;
                    case -5
                        % full stop
                        obj.buffer.leaveCalibrationMode();
                        if obj.settings.UI.hardExitClosesPTB
                            sca
                            ListenChar(0); Priority(0);
                        end
                        error('Titta: run ended from calibration routine')
                    otherwise
                        error('Titta: status %d not implemented',out.attempt{kCal}.valReviewStatus);
                end
            end
            
            % clean up and reset PTB state
            obj.resetScreen(wpnt,screenState);
            if qHasEyeOpenness
                obj.buffer.setIncludeEyeOpennessInGaze(prevEyeOpennessState);
            end
            
            % if we want to exit calibration mode because:
            % 1. user requests it (flag bit 2 is set)
            % 2. user didn't request it, but we entered calibration mode
            %    and operator skipped calibration,
            % then issue a leave here now and wait for it to complete
            if obj.buffer.isInCalibrationMode() && (bitand(flag,2) || (out.wasSkipped && qHasEnteredCalMode))
                obj.doLeaveCalibrationMode();
            end
            
            % log whole process in calibrateHistory and log to messages
            % which calibration was selected
            obj.logCalib(out);
        end
        
        function out = calibrateManual(obj,wpnt,previousCalibs)
            % Do participant setup and calibration for non-compliant subjects
            %
            %    CALIBRATION = Titta.calibrate(WPNT) displays the
            %    participant and operator screens of the participant setup
            %    and calibration interface on the PsychToolbox windows
            %    specified by WPNT, an array of two window pointers. The
            %    first window pointer is taken to refer to the participant
            %    screen, and the second to an operator screen. 
            %
            %    CALIBRATION is a struct containing information about the
            %    calibration/validation run.
            %
            %    CALIBRATION = Titta.calibrate(WPNT,PREVIOUSCALIBS) allows
            %    to prepopulate the interface with previous calibration(s).
            %    The previously selected calibration is made active and it
            %    can then be revalidated and used, or replaced.
            %    PREVIOUSCALIBS is expected to be a CALIBRATION output from
            %    a previous run of Titta.calibrateManual.
            %
            %    INTERFACE
            %    The interface can be fully controlled by key combinations.
            %    Some key combinations are hardcoded, others can be changed through
            %    Titta's settings. In the latter case, their default value
            %    is listed here, and the settings name is indicated in
            %    abbreviated form (e.g. `toggEyeIm` refers to the setting
            %    `settings.UI.button.mancal.toggEyeIm.accelerator`, gotten
            %    from Titta.getDefaults() or Titta.getOptions()). Some of
            %    these keys have a clickable button in the interface
            %    associated with them. Most of these buttons are visible by
            %    default, but some are not. You can change button
            %    visibility by changing, e.g.,
            %    `settings.UI.button.mancal.toggEyeIm.visible`. Invisible
            %    buttons can still be activated or deactivated by means of
            %    the configured keys.
            % 
            %    The following hardcoded key combinations are available:
            %      shift-escape - hard exit from the calibration mode. By
            %                     default (see
            %                     settings.UI.hardExitClosesPTB), this
            %                     causes en error to be thrown and script
            %                     execution to stop if that error is not
            %                     caught.
            %      shift-s      - skip calibration. The currently active
            %                     calibration (as shown in the interface at
            %                     the time of skipping) will remain active.
            %      shift-d      - take screenshot of the participant
            %                     display, which will be stored to the
            %                     current active directory (cd).
            %      shift-o      - take a screenshot of the operator
            %                     display, which will be stored to the
            %                     current active directory (cd).
            %
            %    Calibration or validation data (depending on current mode)
            %    for a specific point is collected by either clicking on a
            %    fixation target on the operator screen, or by pressing the
            %    fixation target's corresponding number key on the
            %    keyboard. Already collected data is discarded by holding
            %    down the shift key while clicking the target or pressing
            %    its corresponding key. If a calibration/validation point
            %    collection or discarding is currently ongoing, clicking a
            %    fixation target or pressing its corresponding key enqueues
            %    this action, which will cause it to execute directly when
            %    the previous action is finished. E.g., rapidly pressing 3,
            %    1, 5 while in calibration mode will cause calibration data
            %    to be acquired for points 3, 1 and 5 in one sequence.
            %
            %    The following configurable key combinations are available:
            %      e         - toggle eye images, if available
            %                  (toggEyeIm)
            %      m         - change between calibration and validation
            %                  modes (calval)
            %      c         - open menu to change which eye will be
            %                  calibrated (both, left, right). The menu can
            %                  be keyboard-controlled: each of the items in
            %                  the menu are preceded by the number to press
            %                  to activate that option. Available only if
            %                  the eye tracker supports monocular
            %                  calibration (changeeye)
            %      spacebar  - select currently active calibration and
            %                  exit the interface/continue experiment
            %                  (continue)
            %      s         - opens a menu that allows the current
            %                  calibration state to be snapshotted, and any
            %                  existing snapshots to be loaded. The menu can
            %                  be keyboard-controlled: each of the items in
            %                  the menu are preceded by the key to press
            %                  to activate that option (snapshot)
            %      g         - toggle whether online gaze position is
            %                  visualized on the screen. Gaze will only be
            %                  visualized to the operator. Press shift-g
            %                  (or hold down shift while pressing the
            %                  interface button with the mouse) to also
            %                  show the online gaze position on the
            %                  participant screen (toggGaze)
            %      h         - toggle whether online head position
            %                  visualization is shown on the screen. It
            %                  will only be shown to the operator. Press
            %                  shift-h (or hold down shift while pressing
            %                  the interface button with the mouse) to also
            %                  show the head position visualization on the
            %                  participant screen (toggHead)
            %
            %    See also TITTA.CALIBRATE, TITTA.GETOPTIONS,
            %    TITTA.GETDEFAULTS
            
            % this function does all setup, draws the interface, etc
            assert(numel(wpnt)==2,'Titta.calibrateManual: need a two screen setup for this mode')
            if nargin<3 || isempty(previousCalibs)
                previousCalibs = [];
            end
            
            % get info about screen
            screenState = obj.getScreenInfo(wpnt);
            
            % some preliminary setup, to make sure we are in known state
            % NB: in contrast to calibrate() above, this function always
            % wipes calibration state upon entry
            obj.buffer.leaveCalibrationMode(true);  % make sure we're not already in calibration mode (start afresh)
            obj.doEnterCalibrationMode();
            obj.StopRecordAll();
            
            % setup the setup/calibration screens
            if ~isempty(previousCalibs)
                % prepopulating and loading is done inside doManualCalib,
                % here only copy over the previous calibrations passed by
                % user
                out                 = previousCalibs;
                % preload the one previously selected by user
                currentSelection    = previousCalibs.selectedCal;
            else
                currentSelection    = [nan nan];
            end
            out.type            = 'manual';
            out.selectedCal     = [nan nan];
            out.wasSkipped      = false;
            
            % run the setup/calibration process
            out = obj.doManualCalib(wpnt,out,currentSelection);
            switch out.status
                case 1
                    % all good, we're done
                case 2
                    % skip setup
                    out.wasSkipped  = true;
                    % NB: even though skipped, if done so at this stage, we
                    % may still have a calibration applied, so that is
                    % still logged in the output of doManualCalib()
                case -5
                    % full stop
                    obj.buffer.leaveCalibrationMode();
                    if obj.settings.UI.hardExitClosesPTB
                        sca
                        ListenChar(0); Priority(0);
                    end
                    error('Titta: run ended from manual calibration routine')
                otherwise
                    error('Titta: status %d not implemented',out.status);
            end
            
            % clean up and reset PTB state
            obj.resetScreen(wpnt,screenState);
            
            % leave calibration mode: issue a leave here now and wait for
            % it to complete
            if obj.buffer.isInCalibrationMode()
                obj.doLeaveCalibrationMode();
            end
            
            % log whole process in calibrateHistory and log to messages
            % which calibration was selected
            obj.logCalib(out);
            
            % also log information about data quality from validation, if
            % any
            if isfield(out.attempt{out.selectedCal(1)},'val')
                message = obj.getValidationQualityMessage(out);
                if ~isempty(message)
                    obj.sendMessage(message);
                else
                    obj.sendMessage('not validated');
                end
            end
        end
        
        function time = sendMessage(obj,str,time)
            % Store timestamped message
            %
            %    TIME = Titta.sendMessage(MESSAGE) stores the message
            %    MESSAGE with the current system timestamp.
            %
            %    TIME is the timestamp (in microseconds) indicating the eye
            %    tracker's system time at which the timestamp was stored.
            %
            %    TIME = Titta.sendMessage(MESSAGE,TIMESTMP) stores MESSAGE
            %    with the provided TIMESTAMP.
            %
            %    TIMESTAMP should be provided in seconds (will be stored as
            %    microseconds). Candidate times are the timestamps provided
            %    by PsychToolbox, such as the timestamp returned by
            %    Screen('Flip') or keyboard functions such as KbEventGet.
            %    These directly correspond to the eye tracker's system time
            %    on Windows, and are transparently remapped to system time
            %    on Linux with less than 20 microsecond error.
            %
            %    See also TITTA.GETMESSAGES, TITTA.GETTIMEASSYSTEMTIME
            
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
            % Returns all the stored timestamped messages
            %
            %    MSGS = Titta.getMessages() returns all the timestamped
            %    messages stored during the current session in a Nx2 cell
            %    array containing N timestamps (microseconds, first column)
            %    and the associated N messages (second column).
            %
            %    See also TITTA.SENDMESSAGE
            
            msgs = obj.msgs.data;
        end
        
        function dat = collectSessionData(obj)
            % Collects all data one may want to store to file, neatly organized
            % 
            %    DATA = Titta.collectSessionData() returns a struct with
            %    all information and data collected during the current
            %    session. Contains information about all calibration
            %    attemps; all timestamped messages; eye-tracker system
            %    information; setup geometry and settings that are in
            %    effect; and log messages generated by the eye tracker; and
            %    any data in the buffers of any of the eye-tracker's data
            %    streams.
            %
            %    See also TITTA.SAVEDATA, TITTA.GETFILENAME
            
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
            if isa(dat.settings.UI.mancal.instruct.strFun,'function_handle')
                dat.settings.UI.mancal.instruct.strFun = func2str(dat.settings.UI.mancal.instruct.strFun);
            end
            dat.TobiiLog            = obj.buffer.getLog(false);
            dat.data                = obj.ConsumeAllData();
        end
        
        function filename = saveData(obj, filename, doAppendVersion)
            % Save all session data to mat-file
            %
            %    FILENAME = Titta.saveData(FILENAME) saves the data
            %    returned by Titta.collectSessionData() directly to a
            %    mat-file with the specified FILENAME. Overwrites existing
            %    FILENAME file.
            %
            %    FILENAME = Titta.saveData(FILENAME, DOAPPENDVERSION)
            %    allows to automatically append a version number (_1, _2,
            %    etc) to the specified FILENAME if the destination file
            %    already exists. Default: false. Returns the FILENAME at
            %    which the file was saved.
            %
            %    See also TITTA.COLLECTSESSIONDATA, TITTA.GETFILENAME
            
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
            % Closes connection to the eye tracker and cleans up
            %
            %    LOG = Titta.deInit() return a struct of log messages
            %    generated by the eye tracker during the current session,
            %    if any.
            
            if ~isempty(obj.buffer)
                % return log
                out = obj.buffer.getLog(true);
            end
            % deleting the buffer object stops all streams and clears its
            % buffers
            obj.buffer = [];
            
            % clear msgs and other fields
            obj.msgs = simpleVec(cell(1,2),1024);   % reinitialize with space for 1024 messages
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
            % Get the default settings for a given eye tracker
            %
            %    SETTINGS = Titta.getDefaults(TRACKER) return a struct of
            %    containing the default SETTINGS for the specified TRACKER.
            %
            %    See also the TITTA.TITTA constructor
            
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
                    
                case 'Tobii Pro Fusion'
                    settings.freq                   = 120;
                case 'Tobii Pro Nano'
                    settings.freq                   = 60;
                case 'Tobii Pro Spark'
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
            
            % platform specific fonts
            if IsWin
                sansFont = 'Segoe UI';
                monoFont = 'Consolas';
            else
                sansFont = 'Liberation Sans';
                monoFont = 'Liberation Mono';
            end
            
            % the rest here are good defaults for all
            settings.calibrateEye               = 'both';                       % 'both', also possible if supported by eye tracker: 'left' and 'right'
            settings.serialNumber               = '';
            settings.licenseFile                = '';                           % should be single string or cell array of strings, with each string being the path to a license file to apply
            settings.nTryReConnect              = 3;                            % How many times to retry connecting before giving up? Something larger than zero is good as it may take more time than the first call to find_all_eyetrackers for network eye trackers to be found
            settings.connectRetryWait           = [1 2];                        % seconds
            settings.UI.startScreen             = 1;                            % 1. start with head positioning interface; 0. skip head positioning, go straight to calibration (if not loading previous calibrations), or validation result screen (if loading previous calibrations when calling Titta.calibrate()
            settings.UI.hardExitClosesPTB       = true;                         % if true, when user presses shift-escape to exit calibration interface, PTB window is closed, and ListenChars state fixed up
            settings.UI.setup.showEyes          = true;
            settings.UI.setup.showEyeLids       = true;
            settings.UI.setup.showPupils        = true;
            settings.UI.setup.showYaw           = true;                         % show yaw of head?
            settings.UI.setup.showYawToOperator = true;                         % show yaw of head on operator screen?
            settings.UI.setup.referencePos      = [];                           % [x y z] in cm. if empty, default: ideal head positioning determined through eye tracker's positioning stream. If values given, refernce position circle is positioned referencePos(1) cm horizontally and referencePos(2) cm vertically from the center of the screen (assuming screen dimensions were correctly set in Tobii Eye Tracker Manager)
            settings.UI.setup.bgColor           = 127;
            settings.UI.setup.refCircleClr      = [0 0 255];
            settings.UI.setup.headCircleEdgeClr = [255 255 0];
            settings.UI.setup.headCircleFillClr = [255 255 0 .3*255];
            settings.UI.setup.headCircleEdgeWidth= 5;
            settings.UI.setup.eyeClr            = 255;
            settings.UI.setup.eyeClrPosMissing  = [255 166 166];
            settings.UI.setup.eyeBorderClr      = 0;
            settings.UI.setup.eyeBorderWidth    = 1;
            settings.UI.setup.eyeLidClr         = [210 210 0];
            settings.UI.setup.pupilClr          = 0;
            settings.UI.setup.crossClr          = [255 0 0];
            settings.UI.setup.fixBackSize       = 20;
            settings.UI.setup.fixFrontSize      = 5;
            settings.UI.setup.fixBackColor      = 0;
            settings.UI.setup.fixFrontColor     = 255;
            settings.UI.setup.showHeadToSubject = true;                         % if false, the reference circle and head display are not shown on the participant monitor when showing setup display
            settings.UI.setup.showInstructionToSubject = true;                  % if false, the instruction text is not shown on the participant monitor when showing setup display
            settings.UI.setup.showFixPointsToSubject   = true;                  % if false, the fixation points in the corners of the screen are not shown on the participant monitor when showing setup display
            % functions for drawing instruction and positioning information
            % on user and operator screen. Note that rx, ry and rz are
            % NaN (unknown) if reference position is not set by user
            settings.UI.setup.instruct.strFun   = @(x,y,z,rx,ry,rz) sprintf('Position yourself such that the two circles overlap.\nDistance: %.0f cm',z);
            settings.UI.setup.instruct.strFunO  = @(x,y,z,rx,ry,rz) sprintf('Position:\nX: %.1f cm, should be: %.1f cm\nY: %.1f cm, should be: %.1f cm\nDistance: %.1f cm, should be: %.1f cm',x,rx,y,ry,z,rz);
            settings.UI.setup.instruct.font     = sansFont;
            settings.UI.setup.instruct.size     = 24*textFac;
            settings.UI.setup.instruct.color    = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.setup.instruct.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.setup.instruct.vSpacing = 1.5;
            settings.UI.setup.menu.bgColor          = 110;
            settings.UI.setup.menu.itemColor        = 140;
            settings.UI.setup.menu.itemColorActive  = 180;
            settings.UI.setup.menu.text.font        = sansFont;
            settings.UI.setup.menu.text.size        = 24*textFac;
            settings.UI.setup.menu.text.color       = 0;
            settings.UI.setup.menu.text.style       = 0;
            if streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32'))   % on Windows
                settings.UI.cursor.normal           = 0;                        % arrow
                settings.UI.cursor.clickable        = 2;                        % hand
                settings.UI.cursor.sizetopleft      = 10;
                settings.UI.cursor.sizetopright     = 9;
                settings.UI.cursor.sizebottomleft   = 9;
                settings.UI.cursor.sizebottomright  = 10;
                settings.UI.cursor.sizetop          = 4;
                settings.UI.cursor.sizebottom       = 4;
                settings.UI.cursor.sizeleft         = 5;
                settings.UI.cursor.sizeright        = 5;
            elseif IsLinux
                settings.UI.cursor.normal           = 2;                        % arrow
                settings.UI.cursor.clickable        = 58;                       % hand
                settings.UI.cursor.sizetopleft      = 134;
                settings.UI.cursor.sizetopright     = 136;
                settings.UI.cursor.sizebottomleft   = 12;
                settings.UI.cursor.sizebottomright  = 14;
                settings.UI.cursor.sizetop          = 138;
                settings.UI.cursor.sizebottom       = 16;
                settings.UI.cursor.sizeleft         = 70;
                settings.UI.cursor.sizeright        = 96;
            end
            settings.UI.button.margins          = [14 16];
            if qUsingOldWindowsPTBRenderer  % old text PTB renderer on Windows
                settings.UI.button.textVOff     = 3;                            % amount (pixels) to move single line text so that it is visually centered on requested coordinate
            end
            settings.UI.button.setup.text.font              = sansFont;
            settings.UI.button.setup.text.size              = 24*textFac;
            settings.UI.button.setup.text.style             = 0;
            settings.UI.button.setup.toggEyeIm.accelerator  = 'e';
            settings.UI.button.setup.toggEyeIm.visible      = true;
            settings.UI.button.setup.toggEyeIm.string       = 'eye images (<i>e<i>)';
            settings.UI.button.setup.toggEyeIm.fillColor    = toggleButClr.fill;
            settings.UI.button.setup.toggEyeIm.edgeColor    = toggleButClr.edge;
            settings.UI.button.setup.toggEyeIm.textColor    = toggleButClr.text;
            settings.UI.button.setup.cal.accelerator        = 'space';
            settings.UI.button.setup.cal.visible            = true;
            settings.UI.button.setup.cal.string             = 'calibrate (<i>spacebar<i>)';
            settings.UI.button.setup.cal.fillColor          = continueButClr.fill;
            settings.UI.button.setup.cal.edgeColor          = continueButClr.edge;
            settings.UI.button.setup.cal.textColor          = continueButClr.text;
            settings.UI.button.setup.prevcal.accelerator    = 'p';
            settings.UI.button.setup.prevcal.visible        = true;
            settings.UI.button.setup.prevcal.string         = 'previous calibrations (<i>p<i>)';
            settings.UI.button.setup.prevcal.fillColor      = optionButClr.fill;
            settings.UI.button.setup.prevcal.edgeColor      = optionButClr.edge;
            settings.UI.button.setup.prevcal.textColor      = optionButClr.text;
            settings.UI.button.setup.changeeye.accelerator  = 'c';
            settings.UI.button.setup.changeeye.visible      = false;
            settings.UI.button.setup.changeeye.string       = 'change eye (<i>c<i>)';
            settings.UI.button.setup.changeeye.fillColor    = optionButClr.fill;
            settings.UI.button.setup.changeeye.edgeColor    = optionButClr.edge;
            settings.UI.button.setup.changeeye.textColor    = optionButClr.text;
            settings.UI.button.val.text.font            = sansFont;
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
            settings.UI.button.val.toggSpace.accelerator= 'x';
            settings.UI.button.val.toggSpace.visible    = true;
            settings.UI.button.val.toggSpace.string     = 'tracker space (<i>x<i>)';
            settings.UI.button.val.toggSpace.fillColor  = toggleButClr.fill;
            settings.UI.button.val.toggSpace.edgeColor  = toggleButClr.edge;
            settings.UI.button.val.toggSpace.textColor  = toggleButClr.text;
            settings.UI.button.val.toggPlot.accelerator = 'p';
            settings.UI.button.val.toggPlot.visible     = true;
            settings.UI.button.val.toggPlot.string      = 'show plot (<i>p<i>)';
            settings.UI.button.val.toggPlot.fillColor   = toggleButClr.fill;
            settings.UI.button.val.toggPlot.edgeColor   = toggleButClr.edge;
            settings.UI.button.val.toggPlot.textColor   = toggleButClr.text;
            settings.UI.plot.bgColor                = 180;
            settings.UI.plot.eyeColors              = eyeColors;                    % colors for data lines in plot screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.plot.lineWidth              = 2;
            settings.UI.plot.scrMargins             = [.01 .02 .09 .06];            % fraction of screen used as blank margin ([left right top bottom])
            settings.UI.plot.panelPad               = .02;                          % fraction of screen
            settings.UI.plot.dotPosLine.color       = 0;
            settings.UI.plot.dotPosLine.width       = 3;
            settings.UI.plot.ax.bgColor             = 255;
            settings.UI.plot.ax.lineColor           = 0;
            settings.UI.plot.ax.lineWidth           = 1;
            settings.UI.plot.ax.tickLength          = .01;                          % fraction of screen height
            settings.UI.plot.ax.highlightColor      = [255 0 0 50];
            settings.UI.plot.ax.axisLbls.x          = 'time (s)';
            if IsOctave && IsWin
                degChar = char([194 176]);
            else
                degChar = char(176);
            end
            settings.UI.plot.ax.axisLbls.offset     = {sprintf('horizontal offset (%s)',degChar),sprintf('vertical offset (%s)',degChar),'pupil size (mm)','eye opennness (mm)'};
            settings.UI.plot.ax.axisLbls.full       = {'horizontal\ngaze position (px)','vertical\ngaze position (px)','pupil size (mm)','eye opennness (mm)'};
            settings.UI.plot.ax.axisLbl.font        = sansFont;
            settings.UI.plot.ax.axisLbl.size        = 22*textFac;
            settings.UI.plot.ax.axisLbl.color       = 0;
            settings.UI.plot.ax.axisLbl.style       = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.plot.ax.axisLbl.pad         = 10;
            settings.UI.plot.ax.tickLbl.font        = sansFont;
            settings.UI.plot.ax.tickLbl.size        = 18*textFac;
            settings.UI.plot.ax.tickLbl.color       = 0;
            settings.UI.plot.ax.tickLbl.style       = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.plot.ax.tickLbl.pad         = 7;
            settings.UI.plot.ax.valLbl.font         = sansFont;
            settings.UI.plot.ax.valLbl.size         = 22*textFac;
            settings.UI.plot.ax.valLbl.color        = 0;
            settings.UI.plot.ax.valLbl.style        = 1;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.plot.ax.valLbl.pad          = 5;
            settings.UI.plot.but.exit.accelerator   = 'escape';
            settings.UI.plot.but.exit.visible       = true;
            settings.UI.plot.but.exit.string        = 'return (<i>esc<i>)';
            settings.UI.plot.but.exit.fillColor     = optionButClr.fill;
            settings.UI.plot.but.exit.edgeColor     = optionButClr.edge;
            settings.UI.plot.but.exit.textColor     = optionButClr.text;
            settings.UI.plot.but.valSel.accelerator = 'c';
            settings.UI.plot.but.valSel.visible     = true;
            settings.UI.plot.but.valSel.string      = 'show context (<i>c<i>)';
            settings.UI.plot.but.valSel.fillColor   = toggleButClr.fill;
            settings.UI.plot.but.valSel.edgeColor   = toggleButClr.edge;
            settings.UI.plot.but.valSel.textColor   = toggleButClr.text;
            settings.UI.cal.errMsg.string           = 'Calibration failed\nPress any key to continue';
            settings.UI.cal.errMsg.font             = sansFont;
            settings.UI.cal.errMsg.size             = 36*textFac;
            settings.UI.cal.errMsg.color            = [150 0 0];
            settings.UI.cal.errMsg.style            = 1;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.cal.errMsg.wrapAt           = 62;
            settings.UI.val.eyeColors               = eyeColors;                    % colors for validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.bgColor                 = 127;                          % background color for validation output screen
            settings.UI.val.fixBackSize             = 20;
            settings.UI.val.fixFrontSize            = 5;
            settings.UI.val.fixBackColor            = 0;
            settings.UI.val.fixFrontColor           = 255;
            settings.UI.val.onlineGaze.eyeColors    = eyeColors;                % colors for online gaze display on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.onlineGaze.fixBackSize  = 20;
            settings.UI.val.onlineGaze.fixFrontSize = 5;
            settings.UI.val.onlineGaze.fixBackColor = 0;
            settings.UI.val.onlineGaze.fixFrontColor= 255;
            settings.UI.val.avg.text.font       = monoFont;
            settings.UI.val.avg.text.size       = 24*textFac;
            settings.UI.val.avg.text.color      = 0;
            settings.UI.val.avg.text.eyeColors  = eyeColors;                    % colors for "left" and "right" in data quality report on top of validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.avg.text.style      = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.avg.text.vSpacing   = 1;
            settings.UI.val.waitMsg.string      = 'Please wait...';
            settings.UI.val.waitMsg.font        = sansFont;
            settings.UI.val.waitMsg.size        = 28*textFac;
            settings.UI.val.waitMsg.color       = 0;
            settings.UI.val.waitMsg.style       = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.hover.bgColor       = 110;
            settings.UI.val.hover.text.font     = monoFont;
            settings.UI.val.hover.text.size     = 20*textFac;
            settings.UI.val.hover.text.color    = 0;
            settings.UI.val.hover.text.eyeColors= eyeColors;                    % colors for "left" and "right" in per-point data quality report on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.hover.text.style    = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.val.menu.bgColor        = 110;
            settings.UI.val.menu.itemColor      = 140;
            settings.UI.val.menu.itemColorActive= 180;
            settings.UI.val.menu.text.font      = sansFont;
            settings.UI.val.menu.text.size      = 24*textFac;
            settings.UI.val.menu.text.color     = 0;
            settings.UI.val.menu.text.eyeColors = eyeColors;                    % colors for "left" and "right" in calibration selection menu on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.val.menu.text.style     = 0;
            settings.cal.pointPos               = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
            settings.cal.pointPosTrackerSpace   = [];                           % if not empty, send these coordinates to the Tobii calibration routines, instead of those in settings.cal.pointPos. Useful if, e.g., you want to mirror the coordinates because participants view the screen through a mirror. If not empty, set settings.val.pointPosTrackerSpace as well
            settings.cal.autoPace               = 2;                            % 0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted
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
            settings.val.pointPosTrackerSpace   = [];                           % required if settings.cal.pointPosTrackerSpace is not empty. If not empty, these coordinates reflect where the validation point is in the calibrated eye tracker space
            settings.val.paceDuration           = 0.8;
            settings.val.collectDuration        = 0.5;
            settings.val.doRandomPointOrder     = true;
            settings.val.pointNotifyFunction    = [];                           % function that is called upon each validation point completing (note that validation doesn't check fixation, purely based on time)
            
            settings.UI.mancal.instruct.strFun  = @(x,y,z,rx,ry,rz) sprintf('X: %.1f cm, target: %.1f cm\nY: %.1f cm, target: %.1f cm\nDistance: %.1f cm, target: %.1f cm',x,rx,y,ry,z,rz);
            settings.UI.mancal.instruct.font    = sansFont;
            settings.UI.mancal.instruct.size    = 32*textFac;
            settings.UI.mancal.instruct.color   = 0;                            % only for messages on the screen, doesn't affect buttons
            settings.UI.mancal.instruct.style   = 0;                            % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.mancal.instruct.vSpacing= 1;
            settings.UI.button.mancal.text.font             = sansFont;
            settings.UI.button.mancal.text.size             = 24*textFac;
            settings.UI.button.mancal.text.style            = 0;
            settings.UI.button.mancal.changeeye.accelerator = 'c';
            settings.UI.button.mancal.changeeye.visible     = false;
            settings.UI.button.mancal.changeeye.string      = 'change eye (<i>c<i>)';
            settings.UI.button.mancal.changeeye.fillColor   = optionButClr.fill;
            settings.UI.button.mancal.changeeye.edgeColor   = optionButClr.edge;
            settings.UI.button.mancal.changeeye.textColor   = optionButClr.text;
            settings.UI.button.mancal.toggEyeIm.accelerator = 'e';
            settings.UI.button.mancal.toggEyeIm.visible     = true;
            settings.UI.button.mancal.toggEyeIm.string      = 'eye images (<i>e<i>)';
            settings.UI.button.mancal.toggEyeIm.fillColor   = toggleButClr.fill;
            settings.UI.button.mancal.toggEyeIm.edgeColor   = toggleButClr.edge;
            settings.UI.button.mancal.toggEyeIm.textColor   = toggleButClr.text;
            settings.UI.button.mancal.calval.accelerator    = 'm';
            settings.UI.button.mancal.calval.visible        = true;
            settings.UI.button.mancal.calval.string         = 'change mode (<i>m<i>)';
            settings.UI.button.mancal.calval.fillColor      = optionButClr.fill;
            settings.UI.button.mancal.calval.edgeColor      = optionButClr.edge;
            settings.UI.button.mancal.calval.textColor      = optionButClr.text;
            settings.UI.button.mancal.continue.accelerator  = 'space';
            settings.UI.button.mancal.continue.visible      = true;
            settings.UI.button.mancal.continue.string       = 'continue (<i>space<i>)';
            settings.UI.button.mancal.continue.fillColor    = continueButClr.fill;
            settings.UI.button.mancal.continue.edgeColor    = continueButClr.edge;
            settings.UI.button.mancal.continue.textColor    = continueButClr.text;
            settings.UI.button.mancal.snapshot.accelerator  = 's';
            settings.UI.button.mancal.snapshot.visible      = true;
            settings.UI.button.mancal.snapshot.string       = 'snapshot (<i>s<i>)';
            settings.UI.button.mancal.snapshot.fillColor    = optionButClr.fill;
            settings.UI.button.mancal.snapshot.edgeColor    = optionButClr.edge;
            settings.UI.button.mancal.snapshot.textColor    = optionButClr.text;
            settings.UI.button.mancal.toggHead.accelerator  = 'h';
            settings.UI.button.mancal.toggHead.visible      = true;
            settings.UI.button.mancal.toggHead.string       = 'show head (<i>h<i>)';
            settings.UI.button.mancal.toggHead.fillColor    = toggleButClr.fill;
            settings.UI.button.mancal.toggHead.edgeColor    = toggleButClr.edge;
            settings.UI.button.mancal.toggHead.textColor    = toggleButClr.text;
            settings.UI.button.mancal.toggGaze.accelerator  = 'g';
            settings.UI.button.mancal.toggGaze.visible      = true;
            settings.UI.button.mancal.toggGaze.string       = 'show gaze (<i>g<i>)';
            settings.UI.button.mancal.toggGaze.fillColor    = toggleButClr.fill;
            settings.UI.button.mancal.toggGaze.edgeColor    = toggleButClr.edge;
            settings.UI.button.mancal.toggGaze.textColor    = toggleButClr.text;
            settings.UI.mancal.menu.bgColor         = 110;
            settings.UI.mancal.menu.itemColor       = 140;
            settings.UI.mancal.menu.itemColorActive = 180;
            settings.UI.mancal.menu.text.font       = sansFont;
            settings.UI.mancal.menu.text.size       = 24*textFac;
            settings.UI.mancal.menu.text.color      = 0;
            settings.UI.mancal.menu.text.eyeColors  = eyeColors;                % colors for "left" and "right" in calibration selection menu on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.mancal.menu.text.style      = 0;
            settings.UI.mancal.calState.text.font   = sansFont;
            settings.UI.mancal.calState.text.size   = 20*textFac;
            settings.UI.mancal.calState.text.style  = 0;
            settings.UI.mancal.avg.text.font        = monoFont;
            settings.UI.mancal.avg.text.size        = 24*textFac;
            settings.UI.mancal.avg.text.color       = 0;
            settings.UI.mancal.avg.text.eyeColors   = eyeColors;                % colors for "left" and "right" in data quality report on top of validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.mancal.avg.text.style       = 0;                        % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.mancal.avg.text.vSpacing    = 1;
            settings.UI.mancal.hover.bgColor        = 110;
            settings.UI.mancal.hover.text.font      = monoFont;
            settings.UI.mancal.hover.text.size      = 20*textFac;
            settings.UI.mancal.hover.text.color     = 0;
            settings.UI.mancal.hover.text.eyeColors = eyeColors;                % colors for "left" and "right" in per-point data quality report on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.mancal.hover.text.style     = 0;                        % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.UI.mancal.onlineGaze.eyeColors = eyeColors;                % colors for online gaze display on validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            
            settings.UI.mancal.showHead             = false;                    % show head display when interface opens? If false, can stil be opened with button
            settings.UI.mancal.headScale            = .5;
            settings.UI.mancal.headPos              = [];                       % if empty, centered
            settings.UI.mancal.eyeColors            = eyeColors;                % colors for validation output screen. L, R eye. The functions utils/rgb2hsl.m and utils/hsl2rgb.m may be helpful to adjust luminance of your chosen colors if needed for visibility
            settings.UI.mancal.bgColor              = 127;                      % background color for operator screen
            settings.UI.mancal.fixBackSize          = 20;
            settings.UI.mancal.fixFrontSize         = 5;
            settings.UI.mancal.fixBackColor         = 0;
            settings.UI.mancal.fixFrontColor        = 255;
            settings.UI.mancal.fixPoint.text.font   = monoFont;
            settings.UI.mancal.fixPoint.text.size   = 12*textFac;
            settings.UI.mancal.fixPoint.text.color  = 255;
            settings.UI.mancal.fixPoint.text.style  = 0;                        % can OR together, 0=normal,1=bold,2=italic,4=underline,8=outline,32=condense,64=extend.
            settings.mancal.bgColor                 = 127;                      % background color for calibration screen (can be overridden by settings.mancal.drawFunction())
            settings.mancal.fixBackSize             = 20;
            settings.mancal.fixFrontSize            = 5;
            settings.mancal.fixBackColor            = 0;
            settings.mancal.fixFrontColor           = 255;
            settings.mancal.drawFunction            = [];
            settings.mancal.doRecordEyeImages       = false;
            settings.mancal.doRecordExtSignal       = false;
            settings.mancal.cal.pointPos            = [[0.1 0.1]; [0.1 0.9]; [0.5 0.5]; [0.9 0.1]; [0.9 0.9]];
            settings.mancal.cal.paceDuration        = 0.8;                      % minimum duration (s) that each point is shown
            settings.mancal.cal.pointNotifyFunction = [];                       % function that is called upon each calibration point completing
            settings.mancal.val.pointPos            = [[0.5 .2]; [.2 .5];[.8 .5]; [.5 .8]];
            settings.mancal.val.paceDuration        = 0.8;                      % minimum duration (s) that each point is shown
            settings.mancal.val.collectDuration     = 0.5;
            settings.mancal.val.pointNotifyFunction = [];                       % function that is called upon each validation point completing (note that validation doesn't check fixation, purely based on time)
            
            settings.debugMode                  = false;                        % for use with PTB's PsychDebugWindowConfiguration. e.g. does not hide cursor
        end
        
        function systemTime = getTimeAsSystemTime(PTBtime)
            % Get the default settings for a given eye tracker
            %
            %    SYSTEMTIME = Titta.getTimeAsSystemTime() provides the
            %    current Tobii SYSTEMTIME. This time is based on the
            %    current time provided by GetSecs().
            %
            %    SYSTEMTIME = Titta.getTimeAsSystemTime(PTBTIME) maps the
            %    provided PTBTIME to Tobii SYSTEMTIME.
            % 
            %    PTBTIME is PsychtoolBox time (e.g. from GetSecs, audio or
            %    video timestamps, PsychHID timestamps, etc). PTB time is
            %    in seconds.
            %
            %    SYSTEMTIME is Tobii system time in microseconds. It may be
            %    using a different computer clock than PTB time. In that
            %    case, this function not only converts from seconds to
            %    microseconds, but also remaps the time between the clocks.
            %
            %    See also TITTA.SENDMESSAGE
            
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
                    PTBtime = PTBmono;                  % no PTB time specified, just get CLOCK_MONOTONIC timestamp
                else
                    PTBtime = PTBtime-PTBgs+PTBmono;    % PTBgs-PTBmono is offset required to remap from PTB time to CLOCK_MONOTONIC/Tobii Pro SDK system time
                end
            else
                if nargin<1
                    PTBtime = GetSecs();
                end
            end
            systemTime = int64(PTBtime*1000*1000);
        end
        
        function message = getValidationQualityMessage(cal,selectedCal)
            % Get a formatted message about data quality during validation
            %
            %    MESSAGE = Titta.getValidationQualityMessage(CAL) formats
            %    the calibration information CAL into a text MESSAGE
            %    informing about achieved data quality.
            %
            %    If CAL is a struct with an array of calibration attemps,
            %    information about the CAL.selectedCal is output. If CAL is
            %    a specific calibration attempt, the message is formatted
            %    for this calibration. CAL may also be the data quality
            %    information for a specific validation session.
            % 
            %    MESSAGE = Titta.getValidationQualityMessage(CAL,SELECTEDCAL)
            %    formats the calibration information for specific
            %    calibration SELECTEDCAL in the calibration attempt array
            %    CAL.
            %
            %    See also TITTA.CALIBRATE TITTA.CALIBRATEMANUAL
            
            message = '';
            if isfield(cal,'quality')
                % direct validation quality struct passed in, process
                % directly
                val = cal;
                str = 'Data Quality (computed from validation)';
            else
                if isfield(cal,'attempt')
                    % find selected calibration, make sure we output quality
                    % info for that
                    if nargin<2 || isempty(selectedCal)
                        assert(isfield(cal,'selectedCal'),'The user did not select a calibration')
                        selectedCal    = cal.selectedCal;
                    end
                    cal     = cal.attempt{selectedCal(1)};
                end
                if isscalar(selectedCal)
                    % find last valid validation
                    iVal    = find(cellfun(@(x) x.status, cal.val)==1,1,'last');
                    val     = cal.val{iVal};
                    str     = sprintf('%d Data Quality (computed from validation %d)',selectedCal,iVal);
                else
                    % get val belonging to this cal
                    whichCals = cellfun(@(x) x.whichCal, cal.val);
                    idx     = find(whichCals==selectedCal(2),1,'last');
                    if isempty(idx)
                        return;
                    end
                    val     = cal.val{idx}.allPoints;
                    str     = sprintf('%d Data Quality (computed from validation %d)',selectedCal(1),idx);
                end
            end
            % get data to put in message, output per eye separately.
            if isfield(val,'quality')
                eyes    = fieldnames(val.quality);
                nPoint  = length(val.quality);
                msg     = cell(1,length(eyes));
                for e=1:length(eyes)
                    dat = cell(7,nPoint+1);
                    for k=1:nPoint
                        valq = val.quality(k).(eyes{e});
                        dat(:,k) = {sprintf('%d @ (%.0f,%.0f)',k,val.pointPos(k,2:3)),valq.acc1D,valq.acc2D(1),valq.acc2D(2),valq.STD1D,valq.RMS1D,valq.dataLoss*100};
                    end
                    % also get average
                    dat(:,end) = {'   average   ',val.acc1D(e),val.acc2D(1,e),val.acc2D(2,e),val.STD1D(e),val.RMS1D(e),val.dataLoss(e)*100};
                    msg{e} = sprintf('%s eye:\n%s',eyes{e},sprintf('%s\t%.4f\t%.4f\t%.4f\t%.4f\t%.4f\t%.1f\n',dat{:}));
                end
                msg = [msg{:}]; msg(end) = [];
                if IsOctave % NB: also for Linux so that output on command line renders correctly. Not needed for all other cases where its text for PTB graphics
                    degChar = char([194 176]);
                else
                    degChar = char(176);
                end
                message = sprintf('CALIBRATION %s:\npoint\tacc (%s)\taccX (%s)\taccY (%s)\tSTD (%s)\tRMS (%s)\tdata loss (%%)\n%s',str,degChar,degChar,degChar,degChar,degChar,msg);
            else
                message = sprintf('CALIBRATION %s: no validation was performed',str);
            end
        end
        
        function filename = getFileName(filename, doAppendVersion)
            % Get the filename for saving data
            %
            %    FILENAME = Titta.getFileName(FILENAME) checks the provided
            %    FILENAME.
            %
            %    FILENAME = Titta.getFileName(FILENAME, DOAPPENDVERSION)
            %    allows to automatically append a version number (_1, _2,
            %    etc) to the specified FILENAME if the destination file
            %    already exists. Default: false.
            %
            %    See also TITTA.SAVEDATA
            
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
        
        function changeAndCheckCalibEyeMode(obj,mode)
            if nargin<2 || isempty(mode)
                mode = obj.settings.calibrateEye;
            end
            % check requested eye calibration mode
            assert(ismember(mode,{'both','left','right'}),'Monocular/binocular recording setup ''%s'' not recognized. Supported modes are [''both'', ''left'', ''right'']',mode)
            if ismember(mode,{'left','right'}) && obj.isInitialized
                assert(obj.hasCap('CanDoMonocularCalibration'),'You requested recording from only the %s eye, but this %s does not support monocular calibrations. Set mode to ''both''',mode,obj.settings.tracker);
            end
            
            % finally, update selected mode
            obj.settings.calibrateEye = mode;
            % and set which eyes are calibrated
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
        
        function state = getScreenInfo(obj,wpnt)
            obj.wpnts = wpnt;
            for w=length(wpnt):-1:1
                obj.scrInfo.resolution{w}  = Screen('Rect',wpnt(w)); obj.scrInfo.resolution{w}(1:2) = [];
                obj.scrInfo.center{w}      = obj.scrInfo.resolution{w}/2;
                obj.qFloatColorRange(w)    = Screen('ColorRange',wpnt(w))==1;
                % get current PTB state so we can restore when returning
                % 1. alpha blending (switch it on in the process)
                [state.osf{w},state.odf{w},state.ocm{w}] = Screen('BlendFunction', wpnt(w), GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                % 2. screen clear color so we can reset that too. There is only
                % one way to do that annoyingly:
                % 2.1. clear back buffer by flipping
                Screen('Flip',wpnt(w));
                % 2.2. read a pixel, this gets us the background color
                state.bgClr{w} = double(reshape(Screen('GetImage',wpnt(w),[1 1 2 2],'backBuffer',obj.qFloatColorRange(w),4),1,4));
                % 3. text
                state.text.style(w)  = Screen('TextStyle', wpnt(w));
                state.text.size(w)   = Screen('TextSize' , wpnt(w));
                state.text.font{w}   = Screen('TextFont' , wpnt(w));
                state.text.color{w}  = Screen('TextColor', wpnt(w));
            end
            % if we have multiple screens, figure out scaling factor, in
            % case operator screen is smaller than experiment screen
            if length(obj.wpnts)==2
                obj.scrInfo.sFac    = min(obj.scrInfo.resolution{end}./obj.scrInfo.resolution{1});
                obj.scrInfo.offset  = (obj.scrInfo.resolution{end}-obj.scrInfo.resolution{1}*obj.scrInfo.sFac)/2;
            else
                obj.scrInfo.sFac    = 1;
                obj.scrInfo.offset  = [0 0];
            end
            
            % see what text renderer to use
            isWin = streq(computer,'PCWIN') || streq(computer,'PCWIN64') || ~isempty(strfind(computer, 'mingw32')); %#ok<*STREMP>
            obj.usingFTGLTextRenderer = (~isWin || ~~exist('libptbdrawtext_ftgl64.dll','file')) && Screen('Preference','TextRenderer')==1;    % check if we're not on Windows, or if on Windows that the high quality text renderer is used (was never supported for 32bit PTB, so check only for 64bit dll)
            if ~obj.usingFTGLTextRenderer
                assert(isfield(obj.settings.UI.button,'textVOff'),'Titta: PTB''s TextRenderer changed between calls to getDefaults and the Titta constructor. If you force the legacy text renderer by calling ''''Screen(''Preference'', ''TextRenderer'',0)'''' (not recommended) make sure you do so before you call Titta.getDefaults(), as it has different settings than the recommended TextRenderer number 1')
            end
        end
        
        function resetScreen(~,wpnt,state)
            for w=length(wpnt):-1:1
                Screen('FillRect',      wpnt(w),state.bgClr{w});                            % reset background color
                Screen('BlendFunction', wpnt(w),state.osf{w},state.odf{w},state.ocm{w});    % reset blend function
                Screen('TextFont',      wpnt(w),state.text.font{w},state.text.style(w));
                Screen('TextColor',     wpnt(w),state.text.color{w});
                Screen('TextSize',      wpnt(w),state.text.size(w));
                Screen('Flip',          wpnt(w));                                           % clear screen
            end
        end
        
        function [status,qCalReset] = showHeadPositioning(obj,wpnt,out)            
            % status output:
            %  1: continue (setup seems good) (space)
            %  2: skip calibration and continue with task (shift+s)
            % -4: go to validation screen (p) -- only if there are already
            %     completed calibrations
            % -5: Exit completely (shift+escape)
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
            qHaveValidValidations   = isfield(out,'attempt') && ~isempty(getCalsWithValidValidations(out.attempt));
            qHaveOperatorScreen     = ~isscalar(wpnt);
            qCanDoMonocularCalib    = obj.hasCap('CanDoMonocularCalibration');
            
            % setup text for buttons
            for w=1:length(wpnt)
                Screen('TextFont',  wpnt(w), obj.settings.UI.button.setup.text.font, obj.settings.UI.button.setup.text.style);
                Screen('TextSize',  wpnt(w), obj.settings.UI.button.setup.text.size);
            end
            
            % setup head displays
            ovalVSz     = .15;
            fac         = 1;
            refSz       = ovalVSz*obj.scrInfo.resolution{1}(2)*fac;
            refClrP     = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(1));
            bgClrP      = obj.getColorForWindow(obj.settings.UI.setup.bgColor,wpnt(1));
            [headP,refPosP] = setupHead(obj,wpnt(1),refSz,obj.scrInfo.resolution{1},fac,obj.settings.UI.setup.showYaw,true);
            if qHaveOperatorScreen
                refClrO     = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(2));
                bgClrO      = obj.getColorForWindow(obj.settings.UI.setup.bgColor,wpnt(2));
                [headO,refPosO] = setupHead(obj,wpnt(2),refSz,obj.scrInfo.resolution{2},fac,obj.settings.UI.setup.showYawToOperator,false);
            end
            

            % setup buttons
            funs    = struct('textCacheGetter',@obj.getTextCache, 'textCacheDrawer', @obj.drawCachedText, 'cacheOffSetter', @obj.positionButtonText, 'colorGetter', @(clr) obj.getColorForWindow(clr,wpnt(end)));
            but(1)  = PTBButton(obj.settings.UI.button.setup.changeeye, qCanDoMonocularCalib  , wpnt(end), funs, obj.settings.UI.button.margins);
            but(2)  = PTBButton(obj.settings.UI.button.setup.toggEyeIm,       qHasEyeIm       , wpnt(end), funs, obj.settings.UI.button.margins);
            but(3)  = PTBButton(obj.settings.UI.button.setup.cal      ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(4)  = PTBButton(obj.settings.UI.button.setup.prevcal  , qHaveValidValidations , wpnt(end), funs, obj.settings.UI.button.margins);
            
            % arrange them
            butRectsBase= cat(1,but([but.visible]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution{end}(2)*.95);
                % place buttons for go to advanced interface, or calibrate
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution{end}(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                idx = find([but.visible]);
                for b=1:length(idx)
                    but(idx(b)).rect = butRects(b,:);
                end
            end
            butRects = cat(1,but.rect).';
            
            % setup fixation points in the corners of the screen
            fixPos = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution{1},4,1);
            
            % setup menu, if any
            currentMenuItem = 0;
            qCalReset       = false;
            if qCanDoMonocularCalib
                margin          = 10;
                pad             = 3;
                height          = 45;
                nElem           = 3;
                totHeight       = nElem*(height+pad)-pad;
                width           = 300;
                % menu background
                menuBackRect    = [-.5*width+obj.scrInfo.center{end}(1)-margin -.5*totHeight+obj.scrInfo.center{end}(2)-margin .5*width+obj.scrInfo.center{end}(1)+margin .5*totHeight+obj.scrInfo.center{end}(2)+margin];
                % menuRects
                menuRects       = repmat([-.5*width+obj.scrInfo.center{end}(1) -height/2+obj.scrInfo.center{end}(2) .5*width+obj.scrInfo.center{end}(1) height/2+obj.scrInfo.center{end}(2)],nElem,1);
                menuRects       = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                % text in each rect
                Screen('TextFont',  wpnt(end), obj.settings.UI.setup.menu.text.font, obj.settings.UI.setup.menu.text.style);
                Screen('TextSize',  wpnt(end), obj.settings.UI.setup.menu.text.size);
                menuTextCache(1)= obj.getTextCache(wpnt(end), '(1) both eyes',menuRects(1,:),'baseColor',obj.settings.UI.val.menu.text.color);
                menuTextCache(2)= obj.getTextCache(wpnt(end), '(2) left eye' ,menuRects(2,:),'baseColor',obj.settings.UI.val.menu.text.color);
                menuTextCache(3)= obj.getTextCache(wpnt(end),'(3) right eye' ,menuRects(3,:),'baseColor',obj.settings.UI.val.menu.text.color);
                
                % get current state
                currentMenuItem = find(ismember({'both','left','right'},obj.settings.calibrateEye));
            end
            
            % setup text for positioning message
            for w=1:length(wpnt)
                Screen('TextFont',  wpnt(w), obj.settings.UI.setup.instruct.font, obj.settings.UI.setup.instruct.style);
                Screen('TextSize',  wpnt(w), obj.settings.UI.setup.instruct.size);
            end
            
            % setup colors
            menuBgClr           = obj.getColorForWindow(obj.settings.UI.setup.menu.bgColor,wpnt(end));
            menuItemClr         = obj.getColorForWindow(obj.settings.UI.setup.menu.itemColor      ,wpnt(end));
            menuItemClrActive   = obj.getColorForWindow(obj.settings.UI.setup.menu.itemColorActive,wpnt(end));
            
            % get tracking status and visualize
            qToggleSelectMenu   = true;
            qSelectMenuOpen     = true;     % gets set to false on first draw as toggle above is true (hack to make sure we're set up on first entrance of draw loop)
            qChangeMenuArrow    = false;
            qSelectedEyeChanged = false;
            qToggleEyeImage     = qHaveOperatorScreen;  % eye images default off if single screen, default on if have operator screen
            qShowEyeImage       = false;
            texs                = zeros(1,4);
            szs                 = zeros(2,4);
            poss                = zeros(2,4);
            eyeImageRectLocal   = zeros(4,4);
            eyeImageRect        = zeros(4,4);
            canvasPoss          = zeros(4,2);
            circVerts           = genCircle(200);
            % setup canvas positions if needed
            eyeImageMargin      = 20;
            qDrawEyeValidity    = false;
            if ~isempty(obj.eyeImageCanvasSize)
                visible = [but.visible];
                if ~any(visible)
                    basePos = round(obj.scrInfo.resolution{end}(2)*.95);
                else
                    basePos = min(butRects(2,[but.visible]));
                end
                canvasPoss(:,1) = OffsetRect([0 0 obj.eyeImageCanvasSize],obj.scrInfo.center{end}(1)-obj.eyeImageCanvasSize(1)-eyeImageMargin/2,basePos-eyeImageMargin-obj.eyeImageCanvasSize(2)).';
                canvasPoss(:,2) = OffsetRect([0 0 obj.eyeImageCanvasSize],obj.scrInfo.center{end}(1)                          +eyeImageMargin/2,basePos-eyeImageMargin-obj.eyeImageCanvasSize(2)).';
                % NB: we have a canvas only for eye trackers 
                qDrawEyeValidity= true;
            end
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            obj.getNewMouseKeyPress();
            headPosLastT        = 0;
            [mx,my]             = deal(0,0);
            while true
                Screen('FillRect', wpnt(1), bgClrP);
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
                        [texs,szs,poss,eyeImageRectLocal]  = ...
                            UploadImages(eyeIm,texs,szs,poss,eyeImageRectLocal,wpnt(end),obj.eyeImageCanvasSize);
                        
                        % if we don't have a canvas to draw eye images on,
                        % update eye image locations if size of returned
                        % eye image changed. NB: For Titta to function
                        % properly, any eye tracker that provides multiple
                        % images per camera (e.g. Tobii Pro Fusion), a
                        % canvas needs to be set up in the init() function
                        % if an eye tracker only provides a single image
                        % per camera, these are then found at indices 1 and
                        % 3
                        if isempty(obj.eyeImageCanvasSize) && (any(szs(:,1).'~=diff(reshape(eyeImageRect(:,1),2,2))) || any(szs(:,3).'~=diff(reshape(eyeImageRect(:,3),2,2))))
                            visible = [but.visible];
                            if ~any(visible)
                                basePos = round(obj.scrInfo.resolution{end}(2)*.95);
                            else
                                basePos = min(butRects(2,[but.visible]));
                            end
                            eyeImageRect(:,1) = OffsetRect([0 0 szs(:,1).'],obj.scrInfo.center{end}(1)-szs(1,1)-eyeImageMargin/2,basePos-eyeImageMargin-szs(2,1)).';
                            eyeImageRect(:,3) = OffsetRect([0 0 szs(:,3).'],obj.scrInfo.center{end}(1)         +eyeImageMargin/2,basePos-eyeImageMargin-szs(2,3)).';
                        elseif ~isempty(obj.eyeImageCanvasSize)
                            % turn canvas-local eye image locations into
                            % screen locations
                            for p=1:size(eyeImageRectLocal,2)
                                camIdx = abs(ceil(p/2)-3);  % [1 2] -> 1 -> 2, [3 4] -> 2 -> 1: flip 1<->2 at end because cam 1 is right camera, cam 2 left camera
                                eyeImageRect(:,p) = eyeImageRectLocal(:,p)+canvasPoss([1 2 1 2],camIdx);
                            end
                        end
                    end
                end
                
                % update calibration mode
                if qSelectedEyeChanged
                    switch currentMenuSel
                        case 1
                            mode = 'both';
                        case 2
                            mode = 'left';
                        case 3
                            mode = 'right';
                    end
                    obj.changeAndCheckCalibEyeMode(mode);
                    obj.sendMessage(sprintf('CHANGE SETUP to %s',getEyeLbl(obj.settings.calibrateEye)));
                    % exit and reenter calibration mode, if needed
                    if obj.doLeaveCalibrationMode()     % returns false if we weren't in calibration mode to begin with
                        obj.doEnterCalibrationMode();
                        qCalReset = true;               % reentering calibration mode clears whatever was already loaded
                    end
                    % update states of this screen
                    currentMenuItem = currentMenuSel;
                    headP.crossEye  = (~obj.calibrateLeftEye)*1+(~obj.calibrateRightEye)*2; % will be 0, 1 or 2 (as we must calibrate at least one eye)
                    headO.crossEye  = headP.crossEye;
                    qSelectedEyeChanged = false;
                end
                
                % setup cursors
                if qToggleSelectMenu
                    qSelectMenuOpen     = ~qSelectMenuOpen;
                    qChangeMenuArrow    = qSelectMenuOpen;  % if opening, also set arrow, so this should also be true
                    qToggleSelectMenu   = false;
                    currentMenuSel      = currentMenuItem;
                    if qSelectMenuOpen
                        cursors.rect    = menuRects.';
                        cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,size(menuRects,1));     % clickable items
                    else
                        cursors.rect    = butRects;
                        cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,length(cursors.rect));  % clickable items
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
                
                % get latest data from eye-tracker
                eyeData     = obj.buffer.peekN('gaze',1);
                posGuide    = obj.buffer.peekN('positioning',1);
                headP.update(...
                    eyeData. left.gazeOrigin.valid, eyeData. left.gazeOrigin.inUserCoords, posGuide. left.user_position, eyeData. left.pupil.valid, eyeData. left.pupil.diameter, eyeData. left.eyeOpenness.valid, eyeData. left.eyeOpenness.diameter,...
                    eyeData.right.gazeOrigin.valid, eyeData.right.gazeOrigin.inUserCoords, posGuide.right.user_position, eyeData.right.pupil.valid, eyeData.right.pupil.diameter, eyeData.right.eyeOpenness.valid, eyeData.right.eyeOpenness.diameter);
                if qHaveOperatorScreen
                    headO.update(...
                        eyeData. left.gazeOrigin.valid, eyeData. left.gazeOrigin.inUserCoords, posGuide. left.user_position, eyeData. left.pupil.valid, eyeData. left.pupil.diameter, eyeData. left.eyeOpenness.valid, eyeData. left.eyeOpenness.diameter,...
                        eyeData.right.gazeOrigin.valid, eyeData.right.gazeOrigin.inUserCoords, posGuide.right.user_position, eyeData.right.pupil.valid, eyeData.right.pupil.diameter, eyeData.right.eyeOpenness.valid, eyeData.right.eyeOpenness.diameter);
                end
                
                if ~isnan(headP.avgDist)
                    headPosLastT = eyeData.systemTimeStamp;
                end
                
                % draw eye images, if any
                if qShowEyeImage
                    qTex = ~~texs;
                    if any(qTex)
                        if qDrawEyeValidity
                            validityRects   = GrowRect(eyeImageRect.',3,3).';
                            if ~isempty(eyeData.systemTimeStamp)
                                qValid          = [eyeData.left.gazeOrigin.valid(end) eyeData.right.gazeOrigin.valid(end)];
                            else
                                qValid          = [false false];
                            end
                            qValid          = qValid([2 1 2 1]); % first and third are right eye, second and fourth left eye
                            clrs            = zeros(3,4);
                            clrs(:,qValid)  = repmat([0 120 0].',1,sum( qValid));
                            clrs(:,~qValid) = repmat([150 0 0].',1,sum(~qValid));
                            Screen('FillRect', wpnt(end), clrs(:,qTex), validityRects(:,qTex));
                        end
                        Screen('DrawTextures', wpnt(end), texs(qTex),[],eyeImageRect(:,qTex));
                    end
                end
                % for distance info and ovals: hide when eye image is shown
                % and data is missing. But only do so after 200 ms of data
                % missing, so that these elements don't flicker all the
                % time when unstable track
                qHideSetup = qShowEyeImage && isempty(headP.headPos) && ~isempty(eyeData.systemTimeStamp) && double(eyeData.systemTimeStamp-headPosLastT)/1000>200;
                % draw distance info
                if obj.settings.UI.setup.showInstructionToSubject && ~qHideSetup
                    str = obj.settings.UI.setup.instruct.strFun(headP.avgX,headP.avgY,headP.avgDist,obj.settings.UI.setup.referencePos(1),obj.settings.UI.setup.referencePos(2),obj.settings.UI.setup.referencePos(3));
                    if ~isempty(str)
                        DrawFormattedText(wpnt(1),str,'center',.05*obj.scrInfo.resolution{1}(2),obj.settings.UI.setup.instruct.color,[],[],[],obj.settings.UI.setup.instruct.vSpacing);
                    end
                end
                if qHaveOperatorScreen
                    str = obj.settings.UI.setup.instruct.strFunO(headP.avgX,headP.avgY,headP.avgDist,obj.settings.UI.setup.referencePos(1),obj.settings.UI.setup.referencePos(2),obj.settings.UI.setup.referencePos(3));
                    if ~isempty(str)
                        DrawFormattedText(wpnt(2),str,'center',.05*obj.scrInfo.resolution{2}(2),obj.settings.UI.setup.instruct.color,[],[],[],obj.settings.UI.setup.instruct.vSpacing);
                    end
                end
                % draw reference and head indicators
                % reference circle--don't draw if showing eye images and no
                % tracking data available (so head not drawn)
                if obj.settings.UI.setup.showHeadToSubject && ~qHideSetup
                    drawOrientedPoly(wpnt(1),circVerts,1,[0 0],[0 1; 1 0],refSz,refPosP,[],refClrP ,5);
                end
                if qHaveOperatorScreen
                    % no vertical/horizontal offset on operator screen
                    drawOrientedPoly(wpnt(2),circVerts,1,[0 0],[0 1; 1 0],refSz,refPosO,[],refClrO,5);
                end
                % stylized head
                if obj.settings.UI.setup.showHeadToSubject
                    headP.draw();
                end
                if qHaveOperatorScreen
                    headO.draw();
                end
                
                % draw buttons
                but(1).draw([mx my],qSelectMenuOpen);
                but(2).draw([mx my],qShowEyeImage);
                but(3).draw([mx my]);
                but(4).draw([mx my]);
                
                % draw fixation points
                if obj.settings.UI.setup.showFixPointsToSubject
                    obj.drawFixPoints(wpnt(1),fixPos,obj.settings.UI.setup.fixBackSize,obj.settings.UI.setup.fixFrontSize,obj.settings.UI.setup.fixBackColor,obj.settings.UI.setup.fixFrontColor);
                end
                
                % if selection menu open, draw on top
                if qSelectMenuOpen
                    % menu background
                    Screen('FillRect',wpnt(end),menuBgClr,menuBackRect);
                    % menuRects, inactive and currently active
                    qActive = [1:3]==currentMenuItem; %#ok<NBRAK>
                    Screen('FillRect',wpnt(end),menuItemClr,menuRects(~qActive,:).');
                    Screen('FillRect',wpnt(end),menuItemClrActive,menuRects( qActive,:).');
                    % text in each rect
                    for c=1:3
                        obj.drawCachedText(menuTextCache(c));
                    end
                    obj.drawCachedText(menuActiveCache);
                end
                
                % drawing done, show
                Screen('Flip',wpnt(1),[]);
                if qHaveOperatorScreen
                    Screen('Flip',wpnt(2),[],[],2);
                end
                
                
                % get user response
                [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress(wpnt(end));
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    if qSelectMenuOpen
                        iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                        if ~isempty(iIn) && iIn<=3
                            currentMenuSel      = iIn;
                            qSelectedEyeChanged = currentMenuItem~=currentMenuSel;
                            qToggleSelectMenu   = true;
                        else
                            qToggleSelectMenu   = true;
                        end
                    end
                    if ~qSelectMenuOpen || qToggleSelectMenu     % if menu not open or menu closing because pressed outside the menu, check if pressed any of these menu buttons
                        qIn = inRect([mx my],butRects);
                        if qIn(1) && qCanDoMonocularCalib
                            qToggleSelectMenu = true;
                        elseif qIn(2) && qHasEyeIm
                            qToggleEyeImage = true;
                        elseif qIn(3)
                            status = 1;
                            break;
                        elseif qIn(4) && qHaveValidValidations
                            status = -4;
                            break;
                        end
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    
                    % these key combinations should always be available,
                    % and override anything the user has set
                    if any(strcmpi(keys,'escape')) && shiftIsDown
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

                    % user-defined accelerators
                    if qSelectMenuOpen
                        if any(strcmpi(keys,'escape')) || any(strcmpi(keys,obj.settings.UI.button.setup.changeeye.accelerator))
                            qToggleSelectMenu = true;
                        elseif ismember(keys(1),{'1','2','3'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                            currentMenuSel      = str2double(keys(1));
                            qSelectedEyeChanged = currentMenuItem~=currentMenuSel;
                            qToggleSelectMenu   = true;
                        elseif any(ismember(lower(keys),{'kp_enter','return','enter'})) % lowercase versions of possible return key names (also include numpad's enter)
                            qSelectedEyeChanged = currentMenuItem~=currentMenuSel;
                            qToggleSelectMenu   = true;
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
                                end
                            elseif any(cellfun(@(x) ~isempty(strfind(lower(x(1:min(4,end))),'down')),keys))
                                % down key
                                if currentMenuSel<3
                                    currentMenuSel   = currentMenuSel+1;
                                    qChangeMenuArrow = true;
                                end
                            end
                        end
                    else
                        if any(strcmpi(keys,obj.settings.UI.button.setup.changeeye.accelerator)) && qCanDoMonocularCalib
                            qToggleSelectMenu = true;
                        elseif any(strcmpi(keys,obj.settings.UI.button.setup.toggEyeIm.accelerator)) && qHasEyeIm
                            qToggleEyeImage = true;
                        elseif any(strcmpi(keys,obj.settings.UI.button.setup.cal.accelerator))
                            status = 1;
                            break;
                        elseif any(strcmpi(keys,obj.settings.UI.button.setup.prevcal.accelerator)) && qHaveValidValidations
                            status = -4;
                            break;
                        end
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
                text = double(text);     % this seems to solve encoding issues with, e.g., degrees symbol. Doesn't work with DrawFormattedText2GDI below though, so just fix it for the vast majority of users sadly...
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
        
        function [cache,txtbounds] = repositionTextCache(obj,cache,offset)
            if obj.usingFTGLTextRenderer
                [~,~,txtbounds,cache] = DrawFormattedText2(cache,'cacheOnly',true,'sx',offset(1),'sy',offset(2));
            else
                % offset the text to sx,sy (assumes it was centered on 0,0,
                % which is ok for current code)
                cache.px    = cache.px+sx;
                cache.py    = cache.py+sy;
                cache.bbox  = OffsetRect(cache.bbox,off(1),off(2));
                txtbounds   = cache.bbox;
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
                    cache.px    = cache.px-previousOff(1)+sx;
                    cache.py    = cache.py-previousOff(2)+sy;
                    cache.bbox  = OffsetRect(cache.bbox,-previousOff(1)+sx,-previousOff(2)+sy);
                end
            end
        end
        
        function drawCachedText(obj,cache,rect)
            if obj.usingFTGLTextRenderer
                args = {};
                if nargin>2
                    args = {'sx','center','sy','center','xalign','center','yalign','center','winRect',rect};
                end
                for p=1:length(cache)
                    DrawFormattedText2(cache(p),args{:});
                end
            else
                for p=1:length(cache)
                    if nargin>2
                        [cx,cy] = RectCenterd(rect);
                        cache(p).px = cache(p).px+cx;
                        cache(p).py = cache(p).py+cy;
                    end
                    DrawFormattedText2GDI(cache(p));
                end
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
            out.eye  = obj.settings.calibrateEye;
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
                out.cal.data        = obj.ConsumeAllData(calStartT);
                out.cal.timestamp   = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
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
                            Screen('Flip',wpnt(1),[]);
                            if length(wpnt)>1
                                Screen('Flip',wpnt(2),[],[],2);
                            end
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
                        Screen('Flip',wpnt(1),[]);
                        if length(wpnt)>1
                            Screen('Flip',wpnt(2),[],[],2);
                        end
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
            out.val{iVal}.allData   = obj.ConsumeAllData(valStartT);
            out.val{iVal}.timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
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
            Screen('Flip',wpnt(1),[]);
            if length(wpnt)>1
                Screen('Flip',wpnt(2),[],[],2);
            end
        end
        
        function data = ConsumeAllData(obj,varargin)
            data.gaze           = obj.buffer.consumeTimeRange('gaze',varargin{:});
            data.eyeImages      = obj.buffer.consumeTimeRange('eyeImage',varargin{:});
            data.externalSignals= obj.buffer.consumeTimeRange('externalSignal',varargin{:});
            data.timeSync       = obj.buffer.consumeTimeRange('timeSync',varargin{:});
            data.notifications  = obj.buffer.consumeTimeRange('notification',varargin{:});
            % NB: positioning stream is not consumed as it will be useless
            % for later analysis (it doesn't have timestamps, and is meant
            % for visualization only). It is cleared however, consistent
            % with effect of the above
            if nargin<2
                % positioning stream doesn't have timestamps, and clear can
                % thus only be called on it without a time range
                obj.buffer.clear('positioning');
            end
        end
        function ClearAllBuffers(obj,varargin)
            % clear all buffer, optionally only within specified time range
            obj.buffer.clearTimeRange('gaze',varargin{:});
            obj.buffer.clearTimeRange('eyeImage',varargin{:});
            obj.buffer.clearTimeRange('externalSignal',varargin{:});
            obj.buffer.clearTimeRange('timeSync',varargin{:});
            obj.buffer.clearTimeRange('notification',varargin{:});
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
            % NB: do not notification stream, that is supposed to run for
            % whole time class is initialized
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
            fs = min(fs);
            
            % start recording eye images if not already started
            eyeStartTime        = [];
            texs                = zeros(1,4);
            szs                 = zeros(2,4);
            poss                = zeros(2,4);
            eyeImageRectLocal   = zeros(4,4);
            eyeImageRect        = zeros(4,4);
            if qShowEyeImage
                if ~obj.settings.cal.doRecordEyeImages
                    eyeStartTime    = obj.getTimeAsSystemTime();
                    obj.buffer.start('eyeImage');
                end
            end
            
            % setup
            if qCal
                points              = obj.settings.cal.pointPos;
                if ~isempty(obj.settings.cal.pointPosTrackerSpace)
                    pointsSDK = obj.settings.cal.pointPosTrackerSpace;
                else
                    pointsSDK = points;
                end
                paceIntervalTicks   = ceil(obj.settings.cal.paceDuration   *fs);
                out.pointStatus     = {};
                extraInp            = {};
                if ~strcmp(obj.settings.calibrateEye,'both')
                    extraInp        = {obj.settings.calibrateEye};
                end
                stage               = 'cal';
            else
                points              = obj.settings.val.pointPos;
                if ~isempty(obj.settings.val.pointPosTrackerSpace)
                    pointsSDK = obj.settings.val.pointPosTrackerSpace;
                else
                    pointsSDK = points;
                end
                paceIntervalTicks   = ceil(obj.settings.val.paceDuration   *fs);
                collectInterval     = ceil(obj.settings.val.collectDuration*fs);
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
                oPoints = bsxfun(@plus,bsxfun(@times,points,obj.scrInfo.resolution{1})*obj.scrInfo.sFac,obj.scrInfo.offset);
                drawOperatorScreenFun = @(idx,eS,t,s,ps,eI,eIL) obj.drawOperatorScreen(wpnt(2),oPoints,idx,eS,t,s,ps,eI,eIL);
            end
            
            points = [points pointsSDK bsxfun(@times,points,obj.scrInfo.resolution{1}) [1:nPoint].' ones(nPoint,1)]; %#ok<NBRAK>
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
                    obj.buffer.calibrationDiscardData(points(p,3:4),extraInp{:});
                end
                % now we expect size(points,1) completed DiscardData
                % reports as well
                nReply = 0;
                while true
                    callResult  = obj.buffer.calibrationRetrieveResult();
                    nReply  = nReply + (~isempty(callResult) && strcmp(callResult.workItem.action,'DiscardData'));
                    if nReply==size(points,1)
                        break;
                    end
                    WaitSecs('YieldSecs',0.001);    % don't spin too hard
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
            out.pointTs  = [];
            
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
                            fun(obj,currentPoint,points(currentPoint,1:2),points(currentPoint,5:6),stage,extra{:});
                        end
                    end
                    
                    % move to display next point
                    currentPoint = currentPoint+1;
                    % check any points left to do
                    if currentPoint>size(points,1)
                        pointOff = 1;
                        break;
                    end
                    out.pointPos(end+1,1:5) =  points(currentPoint,[7 5 6 3 4]);    % that is: [ID pos_screen_pix_x pos_screen_pix_y pos_tracker_norm_x pos_tracker_norm_y]
                    if ~isempty(out.pointTs)
                        % log end of previous point
                        out.pointTs(end,3) = out.flips(end);
                    end
                    out.pointTs (end+1,1:3) = [points(currentPoint, 7) nan nan];
                    % check if manual acceptance needed for this point
                    haveAccepted = ~needManualAccept(currentPoint);     % if not needed, we already have it
                    
                    % get ready for next point
                    qWaitForAllowAccept = true;
                    qLoggedAccept       = false;
                    advancePoint        = false;
                    qNewPoint           = true;
                    tick0p              = nan;
                    drawCmd             = 'new';
                end
                
                % call drawer function
                for w=1:length(wpnt)
                    Screen('FillRect', wpnt(w), bgClr{w});   % needed when multi-flipping participant and operator screen, doesn't hurt when not needed
                end
                if qHaveOperatorScreen
                    [texs,szs,poss,eyeImageRect,eyeImageRectLocal] = ...
                        drawOperatorScreenFun(points(currentPoint,7),eyeStartTime,texs,szs,poss,eyeImageRect,eyeImageRectLocal);
                end
                qAllowAccept        = drawFunction(wpnt(1),drawCmd,currentPoint,points(currentPoint,5:6),tick,stage);
                drawCmd             = 'draw';   % clear any command other than 'draw'
                if qWaitForAllowAccept && qAllowAccept
                    tick0p              = tick;
                    qWaitForAllowAccept = false;
                end
                
                out.flips(end+1)    = Screen('Flip',wpnt(1),nextFlipT);
                if qHaveOperatorScreen
                    Screen('Flip',wpnt(2),[],[],2);
                end
                if qNewPoint
                    obj.sendMessage(sprintf('POINT ON %d (%.0f %.0f)',currentPoint,points(currentPoint,5:6)),out.flips(end));
                    nCollecting     = 0;
                    qNewPoint       = false;
                end
                if ~qLoggedAccept && ~qWaitForAllowAccept
                    obj.sendMessage(sprintf('POINT READY %d (%.0f %.0f)',currentPoint,points(currentPoint,5:6)),out.flips(end));
                    qLoggedAccept = true;
                    % log when point is in place according to drawer
                    % function
                    out.pointTs(end,2) = out.flips(end);
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
                        obj.sendMessage(sprintf('POINT MANUALACCEPT %d (%.0f %.0f)',currentPoint,points(currentPoint,5:6)));
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
                        qLoggedAccept       = false;
                        obj.sendMessage(sprintf('POINT REDO %d (%.0f %.0f)',currentPoint,points(currentPoint,5:6)));
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
                            obj.buffer.calibrationCollectData(points(currentPoint,3:4),extraInp{:});
                            nCollecting = 1;
                            obj.sendMessage(sprintf('POINT COLLECTING %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
                        else
                            % check status
                            callResult  = obj.buffer.calibrationRetrieveResult();
                            if ~isempty(callResult)
                                if strcmp(callResult.workItem.action,'CollectData') && callResult.status==0     % TOBII_RESEARCH_STATUS_OK
                                    % success, next point
                                    advancePoint = true;
                                    obj.sendMessage(sprintf('POINT COLLECTED %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
                                else
                                    % failed
                                    obj.sendMessage(sprintf('POINT FAILED %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
                                    if nCollecting==1
                                        % if failed first time, immediately try again
                                        obj.buffer.calibrationCollectData(points(currentPoint,3:4),extraInp{:});
                                        nCollecting = 2;
                                        obj.sendMessage(sprintf('POINT COLLECTING %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
                                    else
                                        % if still fails, retry one more time at end of
                                        % point sequence (if this is not already a retried
                                        % point)
                                        if points(currentPoint,8)
                                            points = [points; points(currentPoint,:)]; %#ok<AGROW>
                                            points(end,8) = 0;  % indicate this is a point that is being retried so we don't try forever
                                        end
                                        % next point
                                        advancePoint = true;
                                    end
                                end
                            end
                            if advancePoint
                                out.pointStatus{currentPoint} = callResult;
                            end
                        end
                    else
                        if isnan(tick0v)
                            tick0v = tick;
                            obj.sendMessage(sprintf('POINT COLLECTING %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
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
                            obj.sendMessage(sprintf('POINT COLLECTED %d (%.0f %.0f, in tracker space: %.3f %.3f)',currentPoint,points(currentPoint,[5:6 3:4])));
                        end
                    end
                end
            end
            
            % calibration/validation finished
            lastPoint = currentPoint-pointOff;
            
            % get calibration result while keeping animation on the screen
            % alive for a smooth experience
            if qCal && out.status==1
                % compute calibration
                obj.buffer.calibrationComputeAndApply();
                computeResult   = [];
                calData         = [];
                flipT           = out.flips(end);
                qLogPointOff    = true;
                while true
                    tick    = tick+1;
                    for w=1:length(wpnt)
                        Screen('FillRect', wpnt(w), bgClr{w});
                    end
                    if qHaveOperatorScreen
                        [texs,szs,poss,eyeImageRect,eyeImageRectLocal] = ...
                            drawOperatorScreenFun([],eyeStartTime,texs,szs,poss,eyeImageRect,eyeImageRectLocal);
                    end
                    drawFunction(wpnt(1),'draw',lastPoint,points(lastPoint,5:6),tick,stage);
                    flipT   = Screen('Flip',wpnt(1),flipT+1/1000);
                    if qHaveOperatorScreen
                        Screen('Flip',wpnt(2),[],[],2);
                    end
                    if qLogPointOff
                        obj.sendMessage(sprintf('POINT OFF %d',lastPoint),flipT);
                        out.pointTs(end,3) = flipT;
                        qLogPointOff = false;
                    end
                    
                    % first get computeAndApply result, then get
                    % calibration data
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
            else
                % clear screen
                for w=1:length(wpnt)
                    Screen('FillRect', wpnt(w), bgClr{w});
                end
                flipT   = Screen('Flip',wpnt(1),flipT+1/1000);
                if qHaveOperatorScreen
                    Screen('Flip',wpnt(2),[],[],2);
                end
                obj.sendMessage(sprintf('POINT OFF %d',lastPoint),flipT);
                out.pointTs(end,3) = flipT;
            end
            
            if qShowEyeImage && ~obj.settings.cal.doRecordEyeImages
                obj.buffer.stop('eyeImage');
                obj.buffer.clearTimeRange('eyeImage',eyeStartTime);     % clear buffer from start time until now (now=default third argument)
                if any(texs)
                    Screen('Close',texs(texs>0));
                end
            end
        end
        
        function [texs,szs,poss,eyeImageRect,eyeImageRectLocal] = drawOperatorScreen(obj,wpnt,pos,highlight,eyeStartTime,texs,szs,poss,eyeImageRect,eyeImageRectLocal)
            % get live gaze data
            dataWindowDur   = 500;  % ms
            nDataPoint      = ceil(dataWindowDur/1000*obj.settings.freq);
            gazeData        = obj.buffer.peekN('gaze',nDataPoint);
            % draw eye image
            if nargin>5
                % get eye image
                if ~obj.settings.cal.doRecordEyeImages
                    eyeIm       = obj.buffer.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward (default third argument: now)
                else
                    eyeIm       = obj.buffer.peekN('eyeImage',4);    % peek (up to) last four from end, keep them in buffer
                end
                [texs,szs,poss,eyeImageRectLocal]  = ...
                            UploadImages(eyeIm,texs,szs,poss,eyeImageRectLocal,wpnt,obj.eyeImageCanvasSize);
                
                % position eye images
                eyeImageMargin = 20;
                if isempty(obj.eyeImageCanvasSize) && (any(szs(:,1).'~=diff(reshape(eyeImageRect(:,1),2,2))) || any(szs(:,3).'~=diff(reshape(eyeImageRect(:,3),2,2))))
                    % if we don't have a canvas to draw eye images on, update eye image locations if size of returned eye image changed
                    eyeImageRect(:,1) = OffsetRect([0 0 szs(:,1).'],obj.scrInfo.center{2}(1)-szs(1,1)-eyeImageMargin/2,obj.scrInfo.center{2}(2)-szs(2,1)/2);
                    eyeImageRect(:,3) = OffsetRect([0 0 szs(:,3).'],obj.scrInfo.center{2}(1)         +eyeImageMargin/2,obj.scrInfo.center{2}(2)-szs(2,3)/2);
                    qDrawEyeValidity = false;
                elseif ~isempty(obj.eyeImageCanvasSize)
                    % turn canvas-local eye image locations into screen locations
                    for p=1:size(eyeImageRectLocal,2)
                        camIdx = abs(ceil(p/2)-3);  % [1 2] -> 1 -> 2, [3 4] -> 2 -> 1: flip 1<->2 at end because cam 1 is right camera, cam 2 left camera
                        
                        if camIdx==1
                            canvasPossUL = [obj.scrInfo.center{2}(1)-obj.eyeImageCanvasSize(1)-eyeImageMargin/2, obj.scrInfo.center{2}(2)-obj.eyeImageCanvasSize(2)/2].';
                        else
                            canvasPossUL = [obj.scrInfo.center{2}(1)+eyeImageMargin/2                          , obj.scrInfo.center{2}(2)-obj.eyeImageCanvasSize(2)/2].';
                        end
                        
                        eyeImageRect(:,p) = eyeImageRectLocal(:,p)+canvasPossUL([1 2 1 2]);
                    end
                    qDrawEyeValidity = true;
                end
                % draw eye images
                qTex = ~~texs;
                    if any(qTex)
                        if qDrawEyeValidity
                            validityRects   = GrowRect(eyeImageRect.',3,3).';
                            if ~isempty(gazeData.systemTimeStamp)
                                qValid          = [gazeData.left.gazeOrigin.valid(end) gazeData.right.gazeOrigin.valid(end)];
                            else
                                qValid          = [false false];
                            end
                            qValid          = qValid([2 1 2 1]); % first and third are right eye, second and fourth left eye
                            clrs            = zeros(3,4);
                            clrs(:,qValid)  = repmat([0 120 0].',1,sum( qValid));
                            clrs(:,~qValid) = repmat([150 0 0].',1,sum(~qValid));
                            Screen('FillRect', wpnt(end), clrs(:,qTex), validityRects(:,qTex));
                        end
                        Screen('DrawTextures', wpnt(end), texs(qTex),[],eyeImageRect(:,qTex));
                    end
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
            drawLiveData(wpnt,gazeData,dataWindowDur,clrs{:},4,obj.scrInfo.resolution{1},obj.scrInfo.sFac,obj.scrInfo.offset);    % yes, that is resolution of screen 1 on purpose, sFac and offset transform it to screen 2
        end
        
        function qAllowAcceptKey = drawFixationPointDefault(obj,wpnt,~,~,pos,~,~)
            if ~isnan(pos)
                obj.drawFixPoints(wpnt,pos,obj.settings.cal.fixBackSize,obj.settings.cal.fixFrontSize,obj.settings.cal.fixBackColor,obj.settings.cal.fixFrontColor);
                qAllowAcceptKey = true;
            end
        end
        
        function val = ProcessValData(obj,val)
            % remove unneeded data
            if ~obj.calibrateLeftEye
                val.gazeData    = rmfield(val.gazeData    ,'left');
                val.allData.gaze= rmfield(val.allData.gaze,'left');
            end
            if ~obj.calibrateRightEye
                val.gazeData    = rmfield(val.gazeData    ,'right');
                val.allData.gaze= rmfield(val.allData.gaze,'right');
            end
            if isempty(val.gazeData)
                % no validation performed, nothing to do here, return
                return
            end
            
            % compute validation accuracy per point, noise levels, %
            % missing
            for p=length(val.gazeData):-1:1
                if obj.calibrateLeftEye
                    val.quality(p).left  = obj.getDataQuality(val.gazeData(p).left ,val.pointPos(p,4:5));
                end
                if obj.calibrateRightEye
                    val.quality(p).right = obj.getDataQuality(val.gazeData(p).right,val.pointPos(p,4:5));
                end
            end
            if obj.calibrateLeftEye
                lefts  = [val.quality.left];
            end
            if obj.calibrateRightEye
                rights = [val.quality.right];
            end
            [l,r] = deal([]);
            for f={'acc2D','acc1D','RMS1D','STD1D','dataLoss'}
                % NB: abs when averaging over eyes, we need average size of
                % error for accuracy and for other fields its all positive
                % anyway
                if obj.calibrateLeftEye
                    l = mynanmean(abs([lefts.(f{1})]),2);
                end
                if obj.calibrateRightEye
                    r = mynanmean(abs([rights.(f{1})]),2);
                end
                val.(f{1}) = [l r];
            end
        end
        
        function out = getDataQuality(obj,gazeData,valPointPos)
            % do data prep, and get offsets from validation target
            [angs1D,offOnScreenDir,qInvalid] = obj.getOffsetFromPoint(gazeData,valPointPos);
            
            % 1. accuracy
            out.offs    = bsxfun(@times,angs1D,[cos(offOnScreenDir); sin(offOnScreenDir)]);
            out.acc2D   = mynanmean(abs(out.offs),2);
            out.acc1D   = mynanmean(    angs1D   ,2);
            
            % 2. RMS
            out.RMS2D   = sqrt(mynanmean(diff(out.offs,[],2).^2,2));
            out.RMS1D   = hypot(out.RMS2D(1),out.RMS2D(2));
            
            % 3. STD
            out.STD2D   = mynanstd(out.offs,[],2);
            out.STD1D   = hypot(out.STD2D(1),out.STD2D(2));
            
            % 4. data loss
            out.dataLoss  = sum(qInvalid)/length(qInvalid);
        end
        
        function [angs1D,offOnScreenDir,qInvalid] = getOffsetFromPoint(obj,gazeData,pointOnScreenDA)
            % prep: ensure invalid data is nan. This is not fully
            % guaranteed by the Pro SDK
            qInvalid = ~gazeData.gazeOrigin.valid;
            gazeData.gazeOrigin.inUserCoords(:,qInvalid) = nan;
            qInvalid = ~gazeData.gazePoint.valid;
            gazeData.gazePoint.onDisplayArea(:,qInvalid) = nan;
            gazeData.gazePoint.inUserCoords (:,qInvalid) = nan;
            
            pointOnScreenUCS = obj.ADCSToUCS(pointOnScreenDA.');
            offOnScreenADCS  = bsxfun(@minus,gazeData.gazePoint.onDisplayArea,pointOnScreenDA.');
            offOnScreenCm    = bsxfun(@times,offOnScreenADCS,[obj.geom.displayArea.width,obj.geom.displayArea.height].');
            offOnScreenDir   = atan2(offOnScreenCm(2,:),offOnScreenCm(1,:));
            
            vecToPoint  = bsxfun(@minus,pointOnScreenUCS,gazeData.gazeOrigin.inUserCoords);
            gazeVec     = gazeData.gazePoint.inUserCoords-gazeData.gazeOrigin.inUserCoords;
            angs1D      = AngleBetweenVectors(vecToPoint,gazeVec);
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
            
            % find how many valid calibrations we have:
            iValidCals = getCalsWithValidValidations(cal);
            if ~isempty(iValidCals) && ~ismember(selection,iValidCals)  % exception, when we have no valid calibrations at all (happens when using zero-point calibration)
                % this happens if setup cancelled to go directly to this
                % validation viewer
                % select and load last successful calibration
                selection = iValidCals(end);
                obj.loadOtherCal(cal{selection},selection,true,true);
            end
            qHasCal                 = ~isempty(cal{selection}.cal.result);
            qHaveMultipleValidCals  = ~isempty(iValidCals) && ~isscalar(iValidCals);
            iVal                    = find(cellfun(@(x) x.status, cal{selection}.val)==1,1,'last');
            qHasValData             = isfield(cal{selection}.val{iVal},'pointPos');
            qHaveTrackerSpacePos    = ~isempty(obj.settings.cal.pointPosTrackerSpace);
            
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
            but(7)  = PTBButton(obj.settings.UI.button.val.toggSpace, qHaveTrackerSpacePos , wpnt(end), funs, obj.settings.UI.button.margins);
            but(8)  = PTBButton(obj.settings.UI.button.val.toggCal ,        qHasCal        , wpnt(end), funs, obj.settings.UI.button.margins);
            but(9)  = PTBButton(obj.settings.UI.button.val.toggPlot,      qHasValData      , wpnt(end), funs, obj.settings.UI.button.margins);
            % 1. below screen
            % position them
            butRectsBase= cat(1,but([but(1:4).visible]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution{end}(2)*.97);
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution{end}(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                idx = find((1:length(but))<=4&[but.visible]);
                for b=1:length(idx)
                    but(idx(b)).rect = butRects(b,:);
                end
            end
            
            % 2. atop screen
            % position them
            yPosTop             = .02*obj.scrInfo.resolution{end}(2);
            buttonOff           = 900;
            if but(5).visible
                but(5).rect     = OffsetRect(but(5).rect,obj.scrInfo.center{end}(1)-buttonOff/2-but(5).rect(3),yPosTop);
            end
            if but(6).visible
                but(6).rect     = OffsetRect(but(6).rect,obj.scrInfo.center{end}(1)+buttonOff/2,yPosTop);
            end
            
            % 3. left side
            prevPos = nan;
            for b=7:9
                if but(b).visible
                    % position it
                    if isnan(prevPos)
                        prevPos = OffsetRect(but(b).rect,-but(b).rect(1)+5,yPosTop);
                    else
                        yPos    = prevPos(4)-but(b).rect(2)+15;
                        prevPos = OffsetRect(but(b).rect,-but(b).rect(1)+5,yPos);
                    end
                    but(b).rect = prevPos;
                end
            end
            
            % check shiftable button accelerators do not conflict with
            % built in ones
            assert(~qHaveOperatorScreen || ~ismember(obj.settings.UI.button.val.toggGaze.accelerator,{'escape','s','d','o'}),'settings.UI.button.val.toggGaze.accelerator cannot be one of ''escape'', ''s'', ''d'', or ''o'', that would conflict with built-in accelerators')
            
            
            % setup menu, if any
            if IsOctave && IsWin
                degChar = char([194 176]);
            else
                degChar = char(176);
            end
            if qHaveMultipleValidCals
                margin          = 10;
                pad             = 3;
                height          = 45;
                nElem           = length(iValidCals);
                totHeight       = nElem*(height+pad)-pad;
                width           = 900;
                % menu background
                menuBackRect    = [-.5*width+obj.scrInfo.center{end}(1)-margin -.5*totHeight+obj.scrInfo.center{end}(2)-margin .5*width+obj.scrInfo.center{end}(1)+margin .5*totHeight+obj.scrInfo.center{end}(2)+margin];
                % menuRects
                menuRects       = repmat([-.5*width+obj.scrInfo.center{end}(1) -height/2+obj.scrInfo.center{end}(2) .5*width+obj.scrInfo.center{end}(1) height/2+obj.scrInfo.center{end}(2)],nElem,1);
                menuRects       = menuRects+bsxfun(@times,[height*([0:nElem-1]+.5)+[0:nElem-1]*pad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                % text in each rect
                Screen('TextFont',  wpnt(end), obj.settings.UI.val.menu.text.font, obj.settings.UI.val.menu.text.style);
                Screen('TextSize',  wpnt(end), obj.settings.UI.val.menu.text.size);
                for c=nElem:-1:1
                    % find the active/last valid validation for this
                    % calibration
                    aVal = find(cellfun(@(x) x.status, cal{iValidCals(c)}.val)==1,1,'last');
                    if isfield(cal{iValidCals(c)}.val{aVal},'acc1D')
                        % acc field is [lx rx; ly ry]
                        [strl,strr,strsep] = deal('');
                        if ismember(cal{iValidCals(c)}.eye,{'both','left'})
                            strl = sprintf( '<color=%s>Left<color>: %.2f%s, (%.2f%s,%.2f%s)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{1}),cal{iValidCals(c)}.val{aVal}.acc1D( 1 ),degChar,cal{iValidCals(c)}.val{aVal}.acc2D(1, 1 ),degChar,cal{iValidCals(c)}.val{aVal}.acc2D(2, 1 ),degChar);
                        end
                        if ismember(cal{iValidCals(c)}.eye,{'both','right'})
                            idx = 1+strcmp(cal{iValidCals(c)}.eye,'both');
                            strr = sprintf('<color=%s>Right<color>: %.2f%s, (%.2f%s,%.2f%s)',clr2hex(obj.settings.UI.val.menu.text.eyeColors{2}),cal{iValidCals(c)}.val{aVal}.acc1D(idx),degChar,cal{iValidCals(c)}.val{aVal}.acc2D(1,idx),degChar,cal{iValidCals(c)}.val{aVal}.acc2D(2,idx),degChar);
                        end
                        if strcmp(cal{iValidCals(c)}.eye,'both')
                            strsep = ', ';
                        end
                        str = sprintf('(%d): %s%s%s',c,strl,strsep,strr);
                    else
                        str = sprintf('(%d): no validation was performed',c);
                    end
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
            fixPos  = ([-1 -1; -1 1; 1 1; 1 -1]*.9/2+.5) .* repmat(obj.scrInfo.resolution{1},4,1);
            fixPosO = bsxfun(@plus,fixPos*obj.scrInfo.sFac,obj.scrInfo.offset);
            
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
            qShowInTrackerSpace = false;
            fixPointRectSz      = 80*obj.scrInfo.sFac;
            openInfoForPoint    = nan;
            qShowPlotOverlay    = false;
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            [mx,my] = obj.getNewMouseKeyPress(wpnt(end));
            while ~qDoneCalibSelection
                % draw plot overlay instead of interface if wanted
                if qShowPlotOverlay
                    st = obj.drawValidationDataPlots(wpnt,cal,selection,iVal);
                    qShowPlotOverlay = false;
                    if ~~st
                        status = st;
                        break;
                    end
                end
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
                        obj.loadOtherCal(cal{newSelection},newSelection,true,true);
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
                                error('Titta: error loading calibration: %s',result.statusString)
                            end
                            if qAwaitingCalChange
                                % calibration change has come through, make
                                % needed updates
                                selection           = newSelection;
                                qAwaitingCalChange  = false;
                                qHasCal             = ~isempty(cal{selection}.cal.result);
                                iVal                = find(cellfun(@(x) x.status, cal{selection}.val)==1,1,'last');
                                qHasValData         = isfield(cal{selection}.val{iVal},'pointPos');
                                if ~qHasCal && qShowCal
                                    qShowCal            = false;
                                    % toggle selection menu to trigger updating of
                                    % cursors, but make sure menu doesn't actually
                                    % open by temporarily changing its state
                                    qToggleSelectMenu   = true;
                                    qSelectMenuOpen     = ~qSelectMenuOpen;
                                end
                                if ~qHaveTrackerSpacePos
                                    but(7).visible    = false;
                                elseif obj.settings.UI.button.val.toggSpace.visible
                                    but(7).visible    = true;
                                end
                                if ~qHasCal
                                    but(8).visible    = false;
                                elseif obj.settings.UI.button.val.toggCal.visible
                                    but(8).visible    = true;
                                end
                                if ~qHasValData
                                    but(9).visible    = false;
                                elseif obj.settings.UI.button.val.toggPlot.visible
                                    but(9).visible    = true;
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
                            if isfield(cal{selection}.val{iVal},'acc1D')
                                if ismember(cal{selection}.eye,{'both','left'})
                                    strl = sprintf(' <color=%s>Left eye<color>:  %.2f%s, (%.2f%s,%.2f%s)   %.2f%s   %.2f%s  %3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{1}),cal{selection}.val{iVal}.acc1D( 1 ),degChar,cal{selection}.val{iVal}.acc2D(1, 1 ),degChar,cal{selection}.val{iVal}.acc2D(2, 1 ),degChar,cal{selection}.val{iVal}.STD1D( 1 ),degChar,cal{selection}.val{iVal}.RMS1D( 1 ),degChar,cal{selection}.val{iVal}.dataLoss( 1 )*100);
                                end
                                if ismember(cal{selection}.eye,{'both','right'})
                                    idx = 1+strcmp(cal{selection}.eye,'both');
                                    strr = sprintf('<color=%s>Right eye<color>:  %.2f%s, (%.2f%s,%.2f%s)   %.2f%s   %.2f%s  %3.0f%%',clr2hex(obj.settings.UI.val.avg.text.eyeColors{2}),cal{selection}.val{iVal}.acc1D(idx),degChar,cal{selection}.val{iVal}.acc2D(1,idx),degChar,cal{selection}.val{iVal}.acc2D(2,idx),degChar,cal{selection}.val{iVal}.STD1D(idx),degChar,cal{selection}.val{iVal}.RMS1D(idx),degChar,cal{selection}.val{iVal}.dataLoss(idx)*100);
                                end
                                if strcmp(cal{selection}.eye,'both')
                                    strsep = '\n';
                                end
                                valText = sprintf('<u>Validation<u>    <i>offset 2D, (X,Y)      SD    RMS-S2S  loss<i>\n%s%s%s',strl,strsep,strr);
                            else
                                valText = sprintf('no validation was performed');
                                qShowCal = true;
                            end
                            valInfoTopTextCache = obj.getTextCache(wpnt(end),valText,OffsetRect([-5 0 5 10],obj.scrInfo.resolution{end}(1)/2,.02*obj.scrInfo.resolution{end}(2)),'vSpacing',obj.settings.UI.val.avg.text.vSpacing,'yalign','top','xlayout','left','baseColor',obj.settings.UI.val.avg.text.color);
                            
                            % get info about where points were on screen
                            if qShowCal
                                pointPosTemp    = cal{selection}.cal.pointPos;
                                tobiiPoints     = cat(2,cal{selection}.cal.result.points.position).'; % these are in some order different from presentation, we need to reorder pointPos to match
                                pointPos        = zeros(size(tobiiPoints,1),5);
                                for p=1:size(tobiiPoints,1)
                                    [~,i] = min(hypot(pointPosTemp(:,4)-tobiiPoints(p,1),pointPosTemp(:,5)-tobiiPoints(p,2)));
                                    pointPos(p,:) = pointPosTemp(i,:);
                                end
                            else
                                pointPos = cal{selection}.val{iVal}.pointPos;
                            end
                            % pointPos now contains: [ID pos_screen_pix_x pos_screen_pix_y pos_tracker_norm_x pos_tracker_norm_y]
                            % convert all to norm to work with
                            pointPos    = [pointPos(:,1) bsxfun(@rdivide,pointPos(:,2:3),obj.scrInfo.resolution{1}) pointPos(:,4:5)];
                            nPoints     = size(pointPos,1);
                            if qShowInTrackerSpace
                                pointPosPix = bsxfun(@times,pointPos(:,4:5),obj.scrInfo.resolution{1});
                            else
                                pointPosPix = bsxfun(@times,pointPos(:,2:3),obj.scrInfo.resolution{1});
                            end
                            calValPos   = bsxfun(@plus,pointPosPix*obj.scrInfo.sFac,obj.scrInfo.offset);
                            
                            if qHaveTrackerSpacePos || (~qShowCal && qHasValData)
                                % get rects around validation points
                                calValRects = zeros(nPoints,4);
                                for p=1:nPoints
                                    calValRects(p,:)= CenterRectOnPointd([0 0 fixPointRectSz fixPointRectSz],calValPos(p,1),calValPos(p,2));
                                end

                                % update info displays
                                infoBoxRects        = nan(  nPoints,4);
                                infoShowRects       = nan(  nPoints,4);
                                qStickyShowPointInfo= false(nPoints,1);
                                pointTextCache      = cell( nPoints,1);
                            else
                                calValRects   = [];
                                infoShowRects = [];
                            end
                            
                            qUpdateCalDisplay   = false;
                        end
                    end
                end
                
                % setup cursors
                if qToggleSelectMenu
                    butRects            = cat(1,but.rect);
                    currentMenuSel      = find(selection==iValidCals);
                    qSelectMenuOpen     = ~qSelectMenuOpen;
                    qChangeMenuArrow    = qSelectMenuOpen;  % if opening, also set arrow, so this should also be true
                    qToggleSelectMenu   = false;
                    if qSelectMenuOpen
                        cursors.rect    = [menuRects.' butRects(1:3,:).'];
                        cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,size(menuRects,1)+3); % clickable items
                    else
                        cursors.rect    = butRects.';
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
                    ip                  = openInfoForPoint;
                    infoShowRects(ip,:) = -999;
                    openInfoForPoint    = nan;
                    % 1. prepare text
                    Screen('TextFont', wpnt(end), obj.settings.UI.val.hover.text.font, obj.settings.UI.val.hover.text.style);
                    Screen('TextSize', wpnt(end), obj.settings.UI.val.hover.text.size);
                    if qShowCal
                        str = sprintf('Position shown to participant: %.0f,%.0f px (norm: %.3f,%.3f)\nPosition in tracker space: %.3f,%.3f',pointPos(ip,2:3).*obj.scrInfo.resolution{1},pointPos(ip,2:3),pointPos(ip,4:5));
                    else
                        if strcmp(cal{selection}.eye,'both')
                            lE = cal{selection}.val{iVal}.quality(ip).left;
                            rE = cal{selection}.val{iVal}.quality(ip).right;
                            c1 = clr2hex(obj.settings.UI.val.hover.text.eyeColors{1});
                            c2 = clr2hex(obj.settings.UI.val.hover.text.eyeColors{2});
                            str = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>, <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>                 <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>                 <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>                  <color=%s>%3.0f%%<color>',c1,lE.acc1D,degChar,abs(lE.acc2D(1)),degChar,abs(lE.acc2D(2)),degChar, c2,rE.acc1D,degChar,abs(rE.acc2D(1)),degChar,abs(rE.acc2D(2)),degChar, c1,lE.STD1D,degChar, c2,rE.STD1D,degChar, c1,lE.RMS1D,degChar, c2,rE.RMS1D,degChar, c1,lE.dataLoss*100, c2,rE.dataLoss*100);
                        elseif strcmp(cal{selection}.eye,'left')
                            lE = cal{selection}.val{iVal}.quality(ip).left;
                            c = clr2hex(obj.settings.UI.val.hover.text.eyeColors{1});
                            str = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>',c,lE.acc1D,degChar,abs(lE.acc2D(1)),degChar,abs(lE.acc2D(2)),degChar, c,lE.STD1D,degChar, c,lE.RMS1D,degChar, c,lE.dataLoss*100);
                        elseif strcmp(cal{selection}.eye,'right')
                            rE = cal{selection}.val{iVal}.quality(ip).right;
                            c = clr2hex(obj.settings.UI.val.hover.text.eyeColors{2});
                            str = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>',c,rE.acc1D,degChar,abs(rE.acc2D(1)),degChar,abs(rE.acc2D(2)),degChar, c,rE.STD1D,degChar, c,rE.RMS1D,degChar, c,rE.dataLoss*100);
                        end
                        if qHaveTrackerSpacePos
                            str = [sprintf('Position shown to participant: %.0f,%.0f px (norm: %.3f,%.3f)\nPosition in tracker space: %.3f,%.3f\n',pointPos(ip,2:3).*obj.scrInfo.resolution{1},pointPos(ip,2:3),pointPos(ip,4:5)) str]; %#ok<AGROW> 
                        end
                    end
                    [pointTextCache{ip},txtbounds] = obj.getTextCache(wpnt(end),str,[],'xlayout','left','baseColor',obj.settings.UI.val.hover.text.color);
                    % get box around text
                    margin = 10;
                    infoBoxRects(ip,:) = GrowRect(txtbounds,margin,margin);
                    infoBoxRects(ip,:) = OffsetRect(infoBoxRects(ip,:),-infoBoxRects(ip,1),-infoBoxRects(ip,2));    % make sure rect is [0 0 w h]
                end
                
                while true % draw loop
                    Screen('FillRect', wpnt(1), bgClr);
                    if qHaveOperatorScreen
                        Screen('FillRect', wpnt(2), bgClrO);
                    end
                    % draw validation screen image
                    % draw calibration/validation points
                    obj.drawFixPoints(wpnt(end),calValPos,obj.settings.UI.val.fixBackSize*obj.scrInfo.sFac,obj.settings.UI.val.fixFrontSize*obj.scrInfo.sFac,obj.settings.UI.val.fixBackColor,obj.settings.UI.val.fixFrontColor);
                    % draw captured data in characteristic tobii plot
                    for p=1:nPoints
                        if qShowCal
                            myCal = cal{selection}.cal.result;
                            bpos = calValPos(p,:).';
                            % left eye
                            if ismember(cal{selection}.eye,{'both','left'})
                                qVal = strcmp(myCal.points(p).samples.left.validity,'validAndUsed');
                                lEpos= myCal.points(p).samples.left.position(:,qVal);
                            end
                            % right eye
                            if ismember(cal{selection}.eye,{'both','right'})
                                qVal = strcmp(myCal.points(p).samples.right.validity,'validAndUsed');
                                rEpos= myCal.points(p).samples.right.position(:,qVal);
                            end
                        else
                            myVal = cal{selection}.val{iVal};
                            bpos = calValPos(p,:).';
                            % left eye
                            if ismember(cal{selection}.eye,{'both','left'})
                                qVal = myVal.gazeData(p). left.gazePoint.valid;
                                lEpos= myVal.gazeData(p). left.gazePoint.onDisplayArea(:,qVal);
                            end
                            % right eye
                            if ismember(cal{selection}.eye,{'both','right'})
                                qVal = myVal.gazeData(p).right.gazePoint.valid;
                                rEpos= myVal.gazeData(p).right.gazePoint.onDisplayArea(:,qVal);
                            end
                        end
                        if ismember(cal{selection}.eye,{'both','left'})  && ~isempty(lEpos)
                            if qHaveTrackerSpacePos && ~qShowInTrackerSpace
                                % make data relative to point in screen space
                                lEpos = bsxfun(@plus,bsxfun(@minus,lEpos,pointPos(p,4:5).'),pointPos(p,2:3).');
                            end
                            lEpos = bsxfun(@plus,bsxfun(@times,lEpos,obj.scrInfo.resolution{1}.')*obj.scrInfo.sFac,obj.scrInfo.offset.');
                            Screen('DrawLines',wpnt(end),reshape([repmat(bpos,1,size(lEpos,2)); lEpos],2,[]),1,eyeClrs{1},[],2);
                        end
                        if ismember(cal{selection}.eye,{'both','right'}) && ~isempty(rEpos)
                            if qHaveTrackerSpacePos && ~qShowInTrackerSpace
                                % make data relative to point in screen space
                                rEpos = bsxfun(@plus,bsxfun(@minus,rEpos,pointPos(p,4:5).'),pointPos(p,2:3).');
                            end
                            rEpos = bsxfun(@plus,bsxfun(@times,rEpos,obj.scrInfo.resolution{1}.')*obj.scrInfo.sFac,obj.scrInfo.offset.');
                            Screen('DrawLines',wpnt(end),reshape([repmat(bpos,1,size(rEpos,2)); rEpos],2,[]),1,eyeClrs{2},[],2);
                        end
                    end
                    
                    % draw text with validation accuracy etc info
                    obj.drawCachedText(valInfoTopTextCache);
                    % draw buttons
                    mousePos = [mx my];
                    but(1).draw(mousePos);
                    but(2).draw(mousePos);
                    but(3).draw(mousePos);
                    but(4).draw(mousePos,qSelectMenuOpen);
                    but(5).draw(mousePos);
                    but(6).draw(mousePos,qShowGaze);
                    but(7).draw(mousePos,qShowInTrackerSpace);
                    but(8).draw(mousePos,qShowCal);
                    but(9).draw(mousePos);
                    % if selection menu open, draw on top
                    if qSelectMenuOpen
                        % menu background
                        Screen('FillRect',wpnt(end),menuBgClr,menuBackRect);
                        % menuRects, inactive and currently active
                        qActive = iValidCals==selection;
                        Screen('FillRect',wpnt(end),menuItemClr      ,menuRects(~qActive,:).');
                        Screen('FillRect',wpnt(end),menuItemClrActive,menuRects( qActive,:).');
                        % text in each rect
                        for c=1:length(iValidCals)
                            obj.drawCachedText(menuTextCache(c));
                        end
                        obj.drawCachedText(menuActiveCache);
                    end
                    % show info for validation point, if wanted
                    if ~isempty(infoShowRects) && any(~isnan(infoShowRects(:,1)))
                        for ip = 1:size(infoShowRects,1)
                            if ~isnan(infoShowRects(ip,1)) && ~qStickyShowPointInfo(ip) && ismember(ip,find(inRect([mx my],calValRects.')))
                                infoShowRects(ip,:) = OffsetRect(infoBoxRects(ip,:),mx,my);
                                % make sure does not go offscreen
                                if infoShowRects(ip,3)>obj.scrInfo.resolution{end}(1)
                                    infoShowRects(ip,:) = OffsetRect(infoShowRects(ip,:),obj.scrInfo.resolution{end}(1)-infoShowRects(ip,3),0);
                                end
                                if infoShowRects(ip,4)>obj.scrInfo.resolution{end}(2)
                                    infoShowRects(ip,:) = OffsetRect(infoShowRects(ip,:),0,obj.scrInfo.resolution{end}(2)-infoShowRects(ip,4));
                                end
                            end
                            Screen('FillRect',wpnt(end),hoverBgClr,infoShowRects(ip,:));
                            obj.drawCachedText(pointTextCache{ip},infoShowRects(ip,:));
                        end
                    end
                    % if have operator screen, show message to wait to
                    % participant (if any)
                    if qHaveOperatorScreen && ~qShowGaze && ~isempty(obj.settings.UI.val.waitMsg.string)
                        obj.drawCachedText(waitTextCache);
                    end
                    % if showing gaze, draw
                    if qShowGaze
                        % draw fixation points on operator screen and on
                        % participant screen
                        if qHaveOperatorScreen
                            obj.drawFixPoints(wpnt(end),fixPosO,obj.settings.UI.val.onlineGaze.fixBackSize*obj.scrInfo.sFac,obj.settings.UI.val.onlineGaze.fixFrontSize*obj.scrInfo.sFac,obj.settings.UI.val.onlineGaze.fixBackColor,obj.settings.UI.val.onlineGaze.fixFrontColor);
                        end
                        obj.drawFixPoints(wpnt(1),fixPos,obj.settings.UI.val.onlineGaze.fixBackSize,obj.settings.UI.val.onlineGaze.fixFrontSize,obj.settings.UI.val.onlineGaze.fixBackColor,obj.settings.UI.val.onlineGaze.fixFrontColor);
                        % draw gaze data
                        eyeData = obj.buffer.peekN('gaze');
                        if ~isempty(eyeData.systemTimeStamp)
                            lE = eyeData. left.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            rE = eyeData.right.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            if ismember(cal{selection}.eye,{'both','left'})  && eyeData. left.gazePoint.valid(end)
                                Screen('gluDisk', wpnt(end),onlineGazeClr{1,end}, lE(1)*obj.scrInfo.sFac+obj.scrInfo.offset(1), lE(2)*obj.scrInfo.sFac+obj.scrInfo.offset(2), 10);
                                if qHaveOperatorScreen && qShowGazeToAll
                                    Screen('gluDisk', wpnt(1),onlineGazeClr{1,1}, lE(1), lE(2), 10);
                                end
                            end
                            if ismember(cal{selection}.eye,{'both','right'}) && eyeData.right.gazePoint.valid(end)
                                Screen('gluDisk', wpnt(end),onlineGazeClr{2,end}, rE(1)*obj.scrInfo.sFac+obj.scrInfo.offset(1), rE(2)*obj.scrInfo.sFac+obj.scrInfo.offset(2), 10);
                                if qHaveOperatorScreen && qShowGazeToAll
                                    Screen('gluDisk', wpnt(1),onlineGazeClr{2,1}, rE(1), rE(2), 10);
                                end
                            end
                        end
                    end
                    % drawing done, show
                    Screen('Flip',wpnt(1),[]);
                    if qHaveOperatorScreen
                        Screen('Flip',wpnt(2),[],[],2);
                    end
                    if qAwaitingCalChange
                        % break out of draw loop
                        break;
                    end
                    
                    % get user response
                    [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress(wpnt(end));
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if any(buttons)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectMenuOpen
                            iIn = find(inRect([mx my],[menuRects.' menuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn) && iIn<=length(iValidCals)
                                newSelection        = iValidCals(iIn);
                                qSelectedCalChanged = selection~=newSelection;
                                qToggleSelectMenu   = true;
                                break;
                            else
                                qToggleSelectMenu   = true;
                                break;
                            end
                        end
                        if ~qSelectMenuOpen || qToggleSelectMenu     % if menu not open or menu closing because pressed outside the menu, check if pressed any of these menu buttons
                            qIn = inRect([mx my],butRects.');
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
                                    qShowInTrackerSpace = ~qShowInTrackerSpace;
                                elseif qIn(8)
                                    qUpdateCalDisplay   = true;
                                    qShowCal            = ~qShowCal;
                                elseif qIn(9)
                                    qShowPlotOverlay    = true;
                                end
                                qStickyShowPointInfo(:) = false;
                                break;
                            end
                        end
                    elseif any(keyCode)
                        keys = KbName(keyCode);
                        
                        % these key combinations should always be
                        % available, and override anything the user has set
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
                            qStickyShowPointInfo(:) = false;
                        elseif any(strcmpi(keys,'o')) && shiftIsDown && qHaveOperatorScreen
                            % take screenshot of operator screen
                            takeScreenshot(wpnt(2));
                            qStickyShowPointInfo(:) = false;
                        end

                        % user-defined accelerators
                        if qSelectMenuOpen
                            if any(strcmpi(keys,'escape')) || any(strcmpi(keys,obj.settings.UI.button.val.selcal.accelerator))
                                qToggleSelectMenu = true;
                                break;
                            elseif ismember(keys(1),{'1','2','3','4','5','6','7','8','9'})  % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                requested           = str2double(keys(1));
                                if requested<=length(iValidCals)
                                    newSelection        = iValidCals(requested);
                                    qSelectedCalChanged = selection~=newSelection;
                                    qToggleSelectMenu   = true;
                                end
                                break;
                            elseif any(ismember(lower(keys),{'kp_enter','return','enter'})) % lowercase versions of possible return key names (also include numpad's enter)
                                newSelection        = iValidCals(currentMenuSel);
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
                                    if currentMenuSel<length(iValidCals)
                                        currentMenuSel   = currentMenuSel+1;
                                        qChangeMenuArrow = true;
                                        break;
                                    end
                                end
                            end
                        else
                            if any(strcmpi(keys,obj.settings.UI.button.val.continue.accelerator)) && ~shiftIsDown
                                status = 1;
                                qDoneCalibSelection = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.recal.accelerator)) && ~shiftIsDown
                                status = -1;
                                qDoneCalibSelection = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.reval.accelerator)) && ~shiftIsDown
                                status = -2;
                                qDoneCalibSelection = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.setup.accelerator)) && ~shiftIsDown
                                status = -3;
                                qDoneCalibSelection = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.selcal.accelerator)) && ~shiftIsDown && qHaveMultipleValidCals
                                qToggleSelectMenu   = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggGaze.accelerator))
                                qToggleGaze         = true;
                                qShowGazeToAll      = shiftIsDown;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggSpace.accelerator)) && ~shiftIsDown
                                qUpdateCalDisplay   = true;
                                qShowInTrackerSpace = ~qShowInTrackerSpace;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggCal.accelerator)) && ~shiftIsDown && qHasCal
                                qUpdateCalDisplay   = true;
                                qShowCal            = ~qShowCal;
                                qStickyShowPointInfo(:) = false;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.val.toggPlot.accelerator)) && ~shiftIsDown && qHasValData
                                qShowPlotOverlay    = true;
                                qStickyShowPointInfo(:) = false;
                                break;
                            end
                        end
                    end
                    % check if hovering over point for which we have info
                    if ~isempty(calValRects)
                        iIn = find(inRect([mx my],calValRects.'));
                        if ~isempty(iIn) && ~qSelectMenuOpen
                            % see if new point
                            if isnan(infoShowRects(iIn,1))
                                openInfoForPoint = iIn;
                                break;
                            end
                            if any(buttons)
                                qStickyShowPointInfo(iIn) = true;
                            end
                        else
                            if any(buttons)
                                qStickyShowPointInfo(:) = false;
                            end
                            q = ~isnan(infoShowRects(:,1)) & ~qStickyShowPointInfo;
                            if any(q)
                                % stop showing info
                                infoShowRects(q,:) = nan;
                                break;
                            end
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
        
        function out = doManualCalib(obj,wpnt,out,currentSelection)
            % init key, mouse state
            [~,~,obj.keyState]      = KbCheck();
            [~,~,obj.mouseState]    = GetMouse();
            
            % get eye tracker capabilities
            qHasEyeIm               = obj.buffer.hasStream('eyeImage');
            qHasEyeOpenness         = obj.buffer.hasStream('eyeOpenness');
            qCanDoMonocularCalib    = obj.hasCap('CanDoMonocularCalibration');
            
            % timing is done in ticks (display refreshes) instead of time.
            % If multiple screens, get lowest fs as that will determine
            % tick rate
            for w=length(wpnt):-1:1
                fs(w) = Screen('NominalFrameRate',wpnt(w));
            end
            fs = min(fs);
            
            startT                  = obj.sendMessage('START MANUAL CALIBRATION ROUTINE');
            if qHasEyeOpenness
                prevEyeOpennessState    = obj.buffer.setIncludeEyeOpennessInGaze(true);
            end
            obj.buffer.start('gaze');
            obj.buffer.start('positioning');
            if obj.settings.mancal.doRecordEyeImages && qHasEyeIm
                obj.buffer.start('eyeImage');
            end
            if obj.settings.mancal.doRecordExtSignal && obj.buffer.hasStream('externalSignal')
                obj.buffer.start('externalSignal');
            end
            obj.buffer.start('timeSync');
            
            % setup live data visualization
            dataWindowLength    = 500; % ms
            nDataPointLiveView  = ceil(dataWindowLength/1000*obj.settings.freq);
            
            % setup head position visualization
            ovalVSz     = .15;
            facO        = obj.settings.UI.mancal.headScale;
            refSzP      = ovalVSz*obj.scrInfo.resolution{1}(2);
            refSzO      = ovalVSz*obj.scrInfo.resolution{2}(2)*facO;
            [headP,refPosP] = setupHead(obj,wpnt(1),refSzP,obj.scrInfo.resolution{1}, 1  ,obj.settings.UI.setup.showYaw,true);
            [headO,refPosO] = setupHead(obj,wpnt(2),refSzO,obj.scrInfo.resolution{2},facO,obj.settings.UI.setup.showYawToOperator,false);
            % setup head position screen (centered, can be dragged to move)
            if isempty(obj.settings.UI.mancal.headPos)
                headORect       = CenterRectOnPoint([0 0 obj.scrInfo.resolution{2}*facO],obj.scrInfo.center{end}(1),obj.scrInfo.center{end}(2));
            else
                headORect       = OffsetRect([0 0 obj.scrInfo.resolution{2}*facO],obj.settings.UI.mancal.headPos(1),obj.settings.UI.mancal.headPos(2));
            end
            headO.allPosOff = headORect(1:2);
            refPosO         = refPosO+headORect(1:2);
            
            % setup text for buttons
            Screen('TextFont',  wpnt(end), obj.settings.UI.button.mancal.text.font, obj.settings.UI.button.mancal.text.style);
            Screen('TextSize',  wpnt(end), obj.settings.UI.button.mancal.text.size);
            
            % set up buttons
            funs    = struct('textCacheGetter',@obj.getTextCache, 'textCacheDrawer', @obj.drawCachedText, 'cacheOffSetter', @obj.positionButtonText, 'colorGetter', @(clr) obj.getColorForWindow(clr,wpnt(end)));
            but(1)  = PTBButton(obj.settings.UI.button.mancal.changeeye, qCanDoMonocularCalib  , wpnt(end), funs, obj.settings.UI.button.margins);
            but(2)  = PTBButton(obj.settings.UI.button.mancal.toggEyeIm,       qHasEyeIm       , wpnt(end), funs, obj.settings.UI.button.margins);
            but(3)  = PTBButton(obj.settings.UI.button.mancal.calval   ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(4)  = PTBButton(obj.settings.UI.button.mancal.continue ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(5)  = PTBButton(obj.settings.UI.button.mancal.snapshot ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(6)  = PTBButton(obj.settings.UI.button.mancal.toggHead ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            but(7)  = PTBButton(obj.settings.UI.button.mancal.toggGaze ,         true          , wpnt(end), funs, obj.settings.UI.button.margins);
            % 1. below screen
            % position them
            butRectsBase= cat(1,but([but(1:5).visible]).rect);
            if ~isempty(butRectsBase)
                buttonOff   = 80;
                yposBase    = round(obj.scrInfo.resolution{end}(2)*.97);
                buttonWidths= butRectsBase(:,3)-butRectsBase(:,1);
                totWidth    = sum(buttonWidths)+(length(buttonWidths)-1)*buttonOff;
                xpos        = [zeros(size(buttonWidths)).'; buttonWidths.']+[0 ones(1,length(buttonWidths)-1); zeros(1,length(buttonWidths))]*buttonOff;
                xpos        = cumsum(xpos(:))-totWidth/2+obj.scrInfo.resolution{end}(1)/2;
                butRects(:,[1 3]) = [xpos(1:2:end) xpos(2:2:end)];
                butRects(:,2)     = yposBase-butRectsBase(:,4)+butRectsBase(:,2);
                butRects(:,4)     = yposBase;
                idx = find((1:length(but))<=5&[but.visible]);
                for b=1:length(idx)
                    but(idx(b)).rect = butRects(b,:);
                end
            end
            
            % 2. atop screen
            % position them
            yPosTop             = .02*obj.scrInfo.resolution{end}(2);
            buttonOff           = 900;
            if but(6).visible
                but(6).rect     = OffsetRect(but(6).rect,obj.scrInfo.center{end}(1)-buttonOff/2-but(6).rect(3),yPosTop);
            end
            if but(7).visible
                but(7).rect     = OffsetRect(but(7).rect,obj.scrInfo.center{end}(1)+buttonOff/2               ,yPosTop);
            end
            % get all butRects, needed below in script
            butRects        = cat(1,but.rect).';
            
            % check shiftable button accelerators do not conflict with
            % built in ones
            assert(~ismember(obj.settings.UI.button.mancal.toggHead.accelerator,{'escape','s','d','o'}),'settings.UI.button.mancal.toggHead.accelerator cannot be one of ''escape'', ''s'', ''d'', or ''o'', that would conflict with built-in accelerators')
            assert(~ismember(obj.settings.UI.button.mancal.toggGaze.accelerator,{'escape','s','d','o'}),'settings.UI.button.mancal.toggGaze.accelerator cannot be one of ''escape'', ''s'', ''d'', or ''o'', that would conflict with built-in accelerators')
            
            % setup menu, if any
            menuMargin      = 10;
            menuPad         = 3;
            menuElemHeight  = 45;
            if qCanDoMonocularCalib
                nElem               = 3;
                totHeight           = nElem*(menuElemHeight+menuPad)-menuPad;
                width               = 300;
                % menu background
                eyeMenuBackRect     = [-.5*width+obj.scrInfo.center{end}(1)-menuMargin -.5*totHeight+obj.scrInfo.center{end}(2)-menuMargin .5*width+obj.scrInfo.center{end}(1)+menuMargin .5*totHeight+obj.scrInfo.center{end}(2)+menuMargin];
                % menuRects
                eyeMenuRects        = repmat([-.5*width+obj.scrInfo.center{end}(1) -menuElemHeight/2+obj.scrInfo.center{end}(2) .5*width+obj.scrInfo.center{end}(1) menuElemHeight/2+obj.scrInfo.center{end}(2)],nElem,1);
                eyeMenuRects        = eyeMenuRects+bsxfun(@times,[menuElemHeight*([0:nElem-1]+.5)+[0:nElem-1]*menuPad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                % text in each rect
                Screen('TextFont', wpnt(end), obj.settings.UI.mancal.menu.text.font, obj.settings.UI.mancal.menu.text.style);
                Screen('TextSize', wpnt(end), obj.settings.UI.mancal.menu.text.size);
                eyeMenuTextCache(1) = obj.getTextCache(wpnt(end), '(1) both eyes',eyeMenuRects(1,:),'baseColor',obj.settings.UI.mancal.menu.text.color);
                eyeMenuTextCache(2) = obj.getTextCache(wpnt(end), '(2) left eye' ,eyeMenuRects(2,:),'baseColor',obj.settings.UI.mancal.menu.text.color);
                eyeMenuTextCache(3) = obj.getTextCache(wpnt(end),'(3) right eye' ,eyeMenuRects(3,:),'baseColor',obj.settings.UI.mancal.menu.text.color);
                
                % get current state
                currentEyeMenuItem  = find(ismember({'both','left','right'},obj.settings.calibrateEye));
            end
            
            % prep fixation targets
            cPoints             = obj.settings.mancal.cal.pointPos;
            vPoints             = obj.settings.mancal.val.pointPos;
            % for each point: [x_norm y_norm x_pix y_pix ID_number prev_status status];
            % cal status: 0: not collected; -1: failed; 1: collected;
            % 2: displaying; 3: collecting; 4: enqueued; 5: discarding
            cPointsP            = [cPoints bsxfun(@times,cPoints,obj.scrInfo.resolution{1}) [1:size(cPoints,1)].' zeros(size(cPoints,1),2)]; %#ok<NBRAK>
            % val status: 0: not collected; 1: collected; 2: displaying;
            % 3: collecting; 3: enqueued
            vPointsP            = [vPoints bsxfun(@times,vPoints,obj.scrInfo.resolution{1}) [1:size(vPoints,1)].' zeros(size(vPoints,1),2)]; %#ok<NBRAK>
            cPointsO            = bsxfun(@plus,cPointsP(:,3:4)*obj.scrInfo.sFac,obj.scrInfo.offset);
            vPointsO            = bsxfun(@plus,vPointsP(:,3:4)*obj.scrInfo.sFac,obj.scrInfo.offset);
            % make text caches for numbering points
            off = obj.settings.UI.mancal.fixBackSize*obj.scrInfo.sFac*1.7/2*[1 1]*sqrt(2)/2;
            Screen('TextFont', wpnt(end), obj.settings.UI.mancal.fixPoint.text.font, obj.settings.UI.mancal.fixPoint.text.style);
            Screen('TextSize', wpnt(end), max(round(obj.settings.UI.mancal.fixPoint.text.size*obj.scrInfo.sFac),4));
            for p=size(cPointsO,1):-1:1
                r = [cPointsO(p,:) cPointsO(p,:)]+[off off];
                cPointTextCache(p) = obj.getTextCache(wpnt(end), num2str(p),r,'baseColor',obj.settings.UI.mancal.fixPoint.text.color,'xalign','left','yalign','top');
            end
            for p=size(vPointsO,1):-1:1
                r = [vPointsO(p,:) vPointsO(p,:)]+[off off];
                vPointTextCache(p) = obj.getTextCache(wpnt(end), num2str(p),r,'baseColor',obj.settings.UI.mancal.fixPoint.text.color,'xalign','left','yalign','top');
            end
            
            % prep point drawer and data collection logic
            if isa(obj.settings.mancal.drawFunction,'function_handle')
                drawFunction    = obj.settings.mancal.drawFunction;
            else
                drawFunction    = @obj.drawFixationPointDefault;
            end
            collectInterval     = ceil(obj.settings.mancal.val.collectDuration*fs);
            nDataPoint          = ceil(obj.settings.mancal.val.collectDuration*obj.settings.freq);
            
            % prep colors
            bgClrP              = obj.getColorForWindow(obj.settings.UI.mancal.bgColor,wpnt(1));
            bgClrO              = obj.getColorForWindow(obj.settings.UI.mancal.bgColor,wpnt(2));
            eyeClrs             = cellfun(@(x) obj.getColorForWindow(x,wpnt(end)),obj.settings.UI.mancal.eyeColors,'uni',false);
            menuBgClr           = obj.getColorForWindow(obj.settings.UI.mancal.menu.bgColor,wpnt(end));
            menuItemClr         = obj.getColorForWindow(obj.settings.UI.mancal.menu.itemColor      ,wpnt(end));
            menuItemClrActive   = obj.getColorForWindow(obj.settings.UI.mancal.menu.itemColorActive,wpnt(end));
            hoverBgClr          = obj.getColorForWindow(obj.settings.UI.mancal.hover.bgColor,wpnt(end));
            refClrP             = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(1));
            refClrO             = obj.getColorForWindow(obj.settings.UI.setup.refCircleClr,wpnt(2));
            headBgClrO          = obj.getColorForWindow(obj.settings.UI.mancal.hover.bgColor,wpnt(2));
            for w=length(wpnt):-1:1
                onlineGazeClr(:,w) = cellfun(@(x) obj.getColorForWindow(x,wpnt(w)),obj.settings.UI.mancal.onlineGaze.eyeColors,'uni',false);
            end
            
            
            % outer loop, in which less frequent actions are done
            % 1. head display
            qShowHead               = obj.settings.UI.mancal.showHead;
            qShowHeadToAll          = false;
            circVerts               = genCircle(200);
            qDraggingHead           = false;
            dragPos                 = [];
            headResizingGrip        = nan;  % denotes which corner/edge is being dragged for resize action, nan if none currently active
            headOriRect             = [];
            % 2. calibration/validation state
            qToggleStage            = true;
            if ~all(isnan(currentSelection))
                % have a previous loaded calibration, start in validation
                % mode
                stage                   = 'cal';    % will be set to 'val' below because qToggleStage is true
                kCal                    = currentSelection(1);
                awaitingCalChangeType   = 'load';
                calLoadSource           = 'previousCal';
            else
                stage                   = 'val';    % will be set to 'cal' below because qToggleStage is true
                kCal                    = 0;
                awaitingCalChangeType   = '';           % 'compute' or 'load'
                calLoadSource           = '';
            end
            % 3. selection menus
            qToggleSelectEyeMenu    = false;
            qSelectEyeMenuOpen      = false;
            qToggleSelectSnapMenu   = false;
            qSelectSnapMenuOpen     = false;
            qChangeMenuArrow        = false;
            currentMenuRects        = [];
            currentMenuSel          = 0;
            % 4. eye selection
            qSelectedEyeChanged     = false;
            extraInp                = {};
            if ~strcmp(obj.settings.calibrateEye,'both')
                extraInp            = {obj.settings.calibrateEye};
            end
            % 5. eye images
            qToggleEyeImage         = true;     % eye images default on
            qShowEyeImage           = false;
            eyeImageMargin          = 20;
            eyeTexs                 = zeros(1,4);
            eyeSzs                  = zeros(2,4);
            eyePoss                 = zeros(2,4);
            eyeImageRectLocal       = zeros(4,4);
            eyeImageRect            = zeros(4,4);
            eyeCanvasPoss           = zeros(4,2);
            
            % 6. online gaze
            qShowGaze               = false;
            qShowGazeToAll          = false;
            % 7. point selection by mouse and info about validated points
            fixPointRectSzSel       = obj.settings.UI.mancal.fixBackSize*obj.scrInfo.sFac*1.5;
            fixPointRectSzHover     = 80*obj.scrInfo.sFac;
            openInfoForPoint        = nan;
            pointToShowInfoFor      = nan;
            qUpdatePointHover       = false;
            % 8. snapshot saving and loading
            qSaveSnapShot           = false;
            snapshots               = cell(0,3);    % each row is a snapshot, indices indicating 1: which attempt, 2: which cal, 3: cal history
            % 9. applied calibration status
            qNewCal                 = kCal==0;
            qClearState             = false;
            pointList               = [];
            discardList             = [];
            calibrationStatus       = 0+(kCal~=0);  % 0: not calibrated; -1: failed; 1: calibrated; 2: calibrating; 3: loading. initial state: 0 if new run, 1 if loaded previous
            usedCalibrationPoints   = [];
            pointStateLastCal       = [];
            qUpdateCalStatusText    = true;
            qUpdateLineDisplay      = true;
            % 10. cursor drawer state
            qUpdateCursors          = true;
            
            % setup canvas positions if needed
            qDrawEyeValidity    = false;
            if ~isempty(obj.eyeImageCanvasSize)
                visible = [but.visible];
                if ~any(visible)
                    basePos = round(obj.scrInfo.resolution{end}(2)*.95);
                else
                    basePos = min(butRects(2,[but(1:5).visible]));
                end
                eyeCanvasPoss(:,1) = OffsetRect([0 0 obj.eyeImageCanvasSize],obj.scrInfo.center{end}(1)-obj.eyeImageCanvasSize(1)-eyeImageMargin/2,basePos-eyeImageMargin-obj.eyeImageCanvasSize(2)).';
                eyeCanvasPoss(:,2) = OffsetRect([0 0 obj.eyeImageCanvasSize],obj.scrInfo.center{end}(1)                          +eyeImageMargin/2,basePos-eyeImageMargin-obj.eyeImageCanvasSize(2)).';
                % NB: we have a canvas only for eye trackers 
                qDrawEyeValidity= true;
            end
            
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            [mx,my]                 = obj.getNewMouseKeyPress(wpnt(end));
            
            qDoneWithManualCalib    = false;
            tick                    = 0;
            tick0p                  = nan;
            out.flips               = GetSecs();    % anchor timing
            frameMsg                = '';
            whichPoint              = nan;
            whichPointDiscard       = nan;
            qCancelPointCollect     = false;
            qRegenSnapShotMenuListing = false;
            if IsOctave && IsWin
                degChar = char([194 176]);
            else
                degChar = char(176);
            end
            while ~qDoneWithManualCalib
                % start new calibration, if wanted (e.g. eye changed, last
                % calibration point discarded). New cal also started when a
                % snapshot is loaded, but this is done elsewhere
                if qNewCal
                    if ~kCal
                        kCal = 1;
                    else
                        kCal = length(out.attempt)+1;
                    end
                    out.attempt{kCal}.timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                    out.attempt{kCal}.device    = obj.settings.tracker;
                    out.attempt{kCal}.eye       = obj.settings.calibrateEye;
                    calAction                   = 0;
                    valAction                   = 0;
                    qNewCal                     = false;
                end
                
                % clear point, calibration statuses, etc
                if qClearState
                    cPointsP(:,end-[1 0])       = 0;
                    vPointsP(:,end-[1 0])       = 0;
                    pointsP (:,end-[1 0])       = 0; %#ok<AGROW>
                    calibrationStatus           = 0;
                    usedCalibrationPoints       = [];
                    qUpdateLineDisplay          = true;
                    qUpdateCalStatusText        = true;
                    qClearState                 = false;
                end
                
                % toggle stage
                if qToggleStage
                    switch stage
                        case 'val'  % currently 'val', becomes 'cal'
                            % copy over status of val points to storage
                            if exist('pointsP','var')
                                vPointsP(:,end-[1 0]) = pointsP(:,end-[1 0]);
                            end
                            % change to cal
                            stage           = 'cal';
                            pointsP         = cPointsP;
                            pointsO         = cPointsO;
                            pointTextCache  = cPointTextCache;
                            paceIntervalTicks   = ceil(obj.settings.mancal.cal.paceDuration*fs);
                            obj.sendMessage(sprintf('ENTER CALIBRATION MODE (%s), calibration no. %d',getEyeLbl(obj.settings.calibrateEye),kCal));
                        case 'cal'  % currently 'cal', becomes 'val'
                            % copy over status of cal points to storage
                            if exist('pointsP','var')
                                cPointsP(:,end-[1 0]) = pointsP(:,end-[1 0]);
                            end
                            % change to val
                            stage           = 'val';
                            pointsP         = vPointsP;
                            pointsO         = vPointsO;
                            pointTextCache  = vPointTextCache;
                            paceIntervalTicks   = ceil(obj.settings.mancal.val.paceDuration*fs);
                            obj.sendMessage(sprintf('ENTER VALIDATION MODE (%s), calibration no. %d',getEyeLbl(obj.settings.calibrateEye),kCal));
                    end
                    % get point rects on operator screen
                    calValRectsSel  = zeros(4,size(pointsO,1));
                    calValRectsHover= zeros(4,size(pointsO,1));
                    for p=1:size(pointsO,1)
                        calValRectsSel(:,p)     = CenterRectOnPointd([0 0 fixPointRectSzSel   fixPointRectSzSel  ],pointsO(p,1),pointsO(p,2));
                        calValRectsHover(:,p)   = CenterRectOnPointd([0 0 fixPointRectSzHover fixPointRectSzHover],pointsO(p,1),pointsO(p,2));
                    end
                    qUpdateCursors      = true;
                    qToggleStage        = false;
                    qUpdateLineDisplay  = true;
                    qUpdatePointHover   = true;
                    qUpdateCalStatusText= true;
                end
                
                % setup menu, if any
                if qToggleSelectSnapMenu
                    qSelectSnapMenuOpen = ~qSelectSnapMenuOpen;
                    if qSelectSnapMenuOpen
                        qRegenSnapShotMenuListing = true;
                    end
                    qToggleSelectSnapMenu   = false;
                    qUpdateCursors          = true;
                elseif qToggleSelectEyeMenu
                    qSelectEyeMenuOpen  = ~qSelectEyeMenuOpen;
                    if qSelectEyeMenuOpen
                        currentMenuBackRect = eyeMenuBackRect;
                        currentMenuRects    = eyeMenuRects;
                        currentMenuTextCache= eyeMenuTextCache;
                        currentMenuSel      = currentEyeMenuItem;
                        menuActiveItem      = currentEyeMenuItem==[1:3]; %#ok<NBRAK>
                        qChangeMenuArrow    = true;
                    end
                    qToggleSelectEyeMenu= false;
                    qUpdateCursors      = true;
                end
                
                if qSaveSnapShot
                    % find last successful cal, thats the one that is
                    % active
                    toSave                      = [kCal getLastManualCal(out.attempt{kCal})];
                    % check if this snapshot already exists
                    if isempty(snapshots) || ~any(all([cat(1,snapshots{:,1})==toSave(1) cat(1,snapshots{:,2})==toSave(2)],2))
                        % collect cal actions that contributed to current
                        % state
                        cals = collectCalsForSave(out,toSave,cPointsP);
                        snapshots = [snapshots; num2cell(toSave) {cals}]; %#ok<AGROW>
                    end
                    qRegenSnapShotMenuListing   = true;
                    qSaveSnapShot               = false;
                end
                
                if qRegenSnapShotMenuListing
                    % this menu's length may change, have to generate
                    % each time it opens
                    nElem           = size(snapshots,1)+1;  % always have the "add snapshot" button at the end
                    totHeight       = nElem*(menuElemHeight+menuPad)-menuPad;
                    width           = 900;
                    % menu background
                    snapMenuBackRect= [-.5*width+obj.scrInfo.center{end}(1)-menuMargin -.5*totHeight+obj.scrInfo.center{end}(2)-menuMargin .5*width+obj.scrInfo.center{end}(1)+menuMargin .5*totHeight+obj.scrInfo.center{end}(2)+menuMargin];
                    % menuRects
                    snapMenuRects   = repmat([-.5*width+obj.scrInfo.center{end}(1) -menuElemHeight/2+obj.scrInfo.center{end}(2) .5*width+obj.scrInfo.center{end}(1) menuElemHeight/2+obj.scrInfo.center{end}(2)],nElem,1);
                    snapMenuRects   = snapMenuRects+bsxfun(@times,[menuElemHeight*([0:nElem-1]+.5)+[0:nElem-1]*menuPad-totHeight/2].',[0 1 0 1]); %#ok<NBRAK>
                    % text in each rect
                    Screen('TextFont', wpnt(end), obj.settings.UI.mancal.menu.text.font, obj.settings.UI.mancal.menu.text.style);
                    Screen('TextSize', wpnt(end), obj.settings.UI.mancal.menu.text.size);
                    currentSnapMenuItem = nan;
                    for c=nElem:-1:1
                        if c==nElem
                            str = '(+): add snapshot';
                        else
                            whichAttempt    = snapshots{c,1};
                            whichCal        = snapshots{c,2};
                            currCal         = getLastManualCal(out.attempt{kCal});
                            if whichAttempt==kCal && whichCal==currCal
                                % currently active calibration is equal to
                                % this snapshot, mark for highlight
                                currentSnapMenuItem = c;
                            end
                            
                            % denote which eye
                            eyeStr = '';
                            if ismember(out.attempt{whichAttempt}.eye,{'both','left'})
                                eyeStr = sprintf('<color=%s>L<color>',clr2hex(obj.settings.UI.mancal.menu.text.eyeColors{1}));
                            end
                            if ismember(out.attempt{whichAttempt}.eye,{'both','right'})
                                if strcmp(out.attempt{whichAttempt}.eye,'both')
                                    eyeStr = [eyeStr '+']; %#ok<AGROW>
                                end
                                eyeStr = [eyeStr sprintf('<color=%s>R<color>',clr2hex(obj.settings.UI.mancal.menu.text.eyeColors{2}))]; %#ok<AGROW>
                            end
                            
                            % get which calibration points used for cal
                            if whichCal>0
                                whichCalPoints  = sort(getWhichCalibrationPoints(cPointsP(:,1:2),snapshots{c,3}{end}.computeResult.points));
                                calStr          = sprintf('%d ',whichCalPoints);
                            else
                                calStr          = '';
                            end
                            
                            % find the active/last valid validation for this
                            % calibration, if any
                            valStr = 'no validation available';
                            if isfield(out.attempt{whichAttempt},'val')
                                idx = nan;
                                for p=length(out.attempt{whichAttempt}.val):-1:1
                                    if ~isnan(out.attempt{whichAttempt}.val{p}.point(1)) && out.attempt{whichAttempt}.val{p}.whichCal==whichCal && ~out.attempt{whichAttempt}.val{p}.wasCancelled && ~out.attempt{whichAttempt}.val{p}.wasDiscarded
                                        idx = p;
                                        break;
                                    end
                                end
                                if ~isnan(idx)
                                    myVal = out.attempt{whichAttempt}.val{idx}.allPoints;
                                    % acc field is [lx rx; ly ry]
                                    [strl,strr,strsep] = deal('');
                                    if ismember(out.attempt{whichAttempt}.eye,{'both','left'})
                                        strl = sprintf( '<color=%s>Left<color>: %.2f%s, (%.2f%s,%.2f%s)',clr2hex(obj.settings.UI.mancal.menu.text.eyeColors{1}),myVal.acc1D( 1 ),degChar,myVal.acc2D(1, 1 ),degChar,myVal.acc2D(2, 1 ),degChar);
                                    end
                                    if ismember(out.attempt{whichAttempt}.eye,{'both','right'})
                                        idx = 1+strcmp(out.attempt{whichAttempt}.eye,'both');
                                        strr = sprintf('<color=%s>Right<color>: %.2f%s, (%.2f%s,%.2f%s)',clr2hex(obj.settings.UI.mancal.menu.text.eyeColors{2}),myVal.acc1D(idx),degChar,myVal.acc2D(1,idx),degChar,myVal.acc2D(2,idx),degChar);
                                    end
                                    if strcmp(out.attempt{whichAttempt}.eye,'both')
                                        strsep = ', ';
                                    end
                                    valStr = sprintf('val: %s%s%s',strl,strsep,strr);
                                end
                            end
                            str = sprintf('(%d): %s, cal points: [%s], %s',c,eyeStr,calStr(1:end-1),valStr);
                        end
                        snapMenuTextCache(c) = obj.getTextCache(wpnt(end),str,snapMenuRects(c,:),'baseColor',obj.settings.UI.mancal.menu.text.color);
                    end
                    
                    currentMenuBackRect         = snapMenuBackRect;
                    currentMenuRects            = snapMenuRects;
                    currentMenuTextCache        = snapMenuTextCache;
                    currentMenuSel              = currentSnapMenuItem;
                    menuActiveItem              = currentSnapMenuItem==[1:size(snapshots,1)+1]; %#ok<NBRAK>
                    if isnan(currentMenuSel)
                        currentMenuSel          = size(snapshots,1)+1;
                    end
                    qChangeMenuArrow            = true;
                    qRegenSnapShotMenuListing   = false;
                    qUpdateCursors              = true;
                end
                
                % switch on/off eye images
                if qHasEyeIm
                    % toggle eye images on or off if requested
                    if qToggleEyeImage
                        if qShowEyeImage && ~obj.settings.mancal.doRecordEyeImages
                            % switch off
                            obj.buffer.stop('eyeImage');
                            obj.buffer.clearTimeRange('eyeImage',eyeStartTime);  % default third argument, clearing from startT until now
                        elseif ~obj.settings.mancal.doRecordEyeImages
                            % switch on
                            eyeStartTime = obj.getTimeAsSystemTime();
                            obj.buffer.start('eyeImage');
                        end
                        qShowEyeImage   = ~qShowEyeImage;
                        qToggleEyeImage = false;
                    end
                end
                
                % update cursors
                if qUpdateCursors
                    headRects   = [];
                    headCursors = [];
                    if qShowHead
                        [headRects,headCursors] = getSelectionRects(headORect,3,obj.settings.UI.cursor);
                    end
                    if qSelectEyeMenuOpen || qSelectSnapMenuOpen
                        otherRects  = currentMenuRects.';
                    else
                        otherRects  = [butRects calValRectsSel];
                    end
                    otherCursors    = repmat(obj.settings.UI.cursor.clickable,1,size(otherRects,2));    % clickable items
                    cursors.rect    = [headRects otherRects];
                    cursors.cursor  = [headCursors otherCursors];      
                    cursors.other   = obj.settings.UI.cursor.normal;                                    % default
                    cursors.qReset  = false;
                    % NB: don't reset cursor to invisible here as it will then flicker every
                    % time you click something. default behaviour is good here
                    cursor = cursorUpdater(cursors);
                    qUpdateCursors = false;
                end
                
                % update calibration mode
                if qSelectedEyeChanged
                    switch currentMenuSel
                        case 1
                            mode = 'both';
                        case 2
                            mode = 'left';
                        case 3
                            mode = 'right';
                    end
                    obj.changeAndCheckCalibEyeMode(mode);
                    obj.sendMessage(sprintf('CHANGE SETUP to %s',getEyeLbl(obj.settings.calibrateEye)));
                    % exit and reenter calibration mode, if needed
                    if obj.doLeaveCalibrationMode()     % returns false if we weren't in calibration mode to begin with
                        obj.doEnterCalibrationMode();
                    end
                    extraInp = {};
                    if ~strcmp(obj.settings.calibrateEye,'both')
                        extraInp        = {obj.settings.calibrateEye};
                    end
                    % update states of this screen
                    currentEyeMenuItem  = currentMenuSel;
                    headP.crossEye      = (~obj.calibrateLeftEye)*1+(~obj.calibrateRightEye)*2; % will be 0, 1 or 2 (as we must calibrate at least one eye)
                    headO.crossEye      = headP.crossEye;
                    qSelectedEyeChanged = false;
                    % reset cal state
                    qNewCal             = true;
                    qClearState         = true;
                    continue;   % execute immediately, restart this update loop from top
                end
                
                % update line displays of calibration/validation data
                if ~isempty(awaitingCalChangeType)
                    switch awaitingCalChangeType
                        case 'compute'
                            if calibrationStatus==2
                                % still waiting for computation to complete
                                computeResult = obj.buffer.calibrationRetrieveResult();
                                if ~isempty(computeResult)
                                    % store calibration result
                                    out.attempt{kCal}.cal{calAction}.computeResult = fixupTobiiCalResult(computeResult.calibrationResult,obj.calibrateLeftEye,obj.calibrateRightEye);
                                    if ~strcmpi(out.attempt{kCal}.cal{calAction}.computeResult.status(1:7),'Success') % 1:7 so e.g. SuccessLeftEye is also supported
                                        % calibration unsuccessful, we bail now
                                        calibrationStatus       = -1;
                                        awaitingCalChangeType   = '';
                                    else
                                        % calibration successful
                                        calibrationStatus       = 1;
                                        % issue command to get calibration
                                        % data
                                        obj.buffer.calibrationGetData();
                                        % denote all validation points as
                                        % not collected
                                        vPointsP(:,end-[1 0]) = 0;
                                        % calibration output for a
                                        % successful calibration may show
                                        % that data for some calibration
                                        % points was removed, update their
                                        % state
                                        usedCalibrationPoints = getWhichCalibrationPoints(pointsP(:,1:2),out.attempt{kCal}.cal{calAction}.computeResult.points);
                                        qNoData   = ~ismember([1:size(pointsP,1)],usedCalibrationPoints); %#ok<NBRAK>
                                        if any(qNoData)
                                            pointsP(qNoData,end-[1 0]) = 0; %#ok<AGROW>
                                            qUpdatePointHover = true;
                                        end
                                    end
                                    qUpdateLineDisplay  = true;
                                    qUpdateCalStatusText= true;
                                end
                            elseif calibrationStatus==1
                                % computed succesfully, waiting for
                                % calibration data retrieval
                                calData = obj.buffer.calibrationRetrieveResult();
                                if ~isempty(calData) && strcmp(calData.workItem.action,'GetCalibrationData')
                                    out.attempt{kCal}.cal{calAction}.computedCal    = calData.calibrationData;
                                    awaitingCalChangeType                           = '';   % done with calibration/data acquisition sequence
                                end
                            end
                        case 'load'
                            if calibrationStatus~=3
                                switch calLoadSource
                                    case 'snapshot'
                                        whichAttempt    = snapshots{currentMenuSel,1};
                                        whichCal        = snapshots{currentMenuSel,2};
                                    case 'previousCal'
                                        whichAttempt    = kCal;
                                        whichCal        = currentSelection(2);
                                end
                                % start new cal
                                kCal = length(out.attempt)+1;
                                out.attempt{kCal}.timestamp = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                                out.attempt{kCal}.device    = obj.settings.tracker;
                                out.attempt{kCal}.eye       = out.attempt{whichAttempt}.eye;
                                % copy over old calibration, set state
                                % accordingly
                                % 1. calibration points
                                if whichCal>0
                                    switch calLoadSource
                                        case 'snapshot'
                                            out.attempt{kCal}.cal = snapshots{currentMenuSel,3};
                                        case 'previousCal'
                                            out.attempt{kCal}.cal = collectCalsForSave(out,currentSelection,cPointsP);
                                    end
                                    calAction = length(out.attempt{kCal}.cal);
                                else
                                    calAction = 0;
                                end
                                % 2. validation points
                                if strcmp(calLoadSource, 'previousCal')
                                    % clear old validation, if any, so that
                                    % it doesn't get copied over. Do here
                                    % as below we set state according to
                                    % old val, and deleting after would
                                    % thus be too late
                                    if isfield(out.attempt{whichAttempt},'val')
                                        out.attempt{whichAttempt} = rmfield(out.attempt{whichAttempt},'val');
                                    end
                                end
                                if isfield(out.attempt{whichAttempt},'val')
                                    qFound  = false(1,size(pointsP,1));
                                    vals    = out.attempt{whichAttempt}.val;
                                    oidx    = nan;
                                    for p=length(vals):-1:1
                                        idx = vals{p}.point(1);
                                        if ~isnan(idx) && ~qFound(idx) && vals{p}.whichCal==whichCal && ~vals{p}.wasCancelled && ~vals{p}.wasDiscarded
                                            % we don't yet have validation data for
                                            % this point, and it is for the current
                                            % calibration -> collect
                                            qFound(idx) = true;
                                            if isnan(oidx)
                                                oidx = size(vals{p}.allPoints.pointPos,1);
                                                qKeepAll = true;
                                            end
                                            % copy over all fields
                                            out.attempt{kCal}.val{oidx} = vals{p};
                                            out.attempt{kCal}.val{oidx}.whichCal = calAction;
                                            if ~qKeepAll && isfield(out.attempt{kCal}.val{oidx},'allPoints')
                                                out.attempt{kCal}.val{oidx} = rmfield(out.attempt{kCal}.val{oidx},'allPoints');
                                            end
                                            oidx = oidx-1;
                                            qKeepAll = false;
                                        end
                                    end
                                end
                                if isfield(out.attempt{kCal},'val')
                                    valAction = length(out.attempt{kCal}.val);
                                else
                                    valAction = 0;
                                end
                                % 3. extra info
                                out.attempt{kCal}.loadedFrom.source         = calLoadSource;
                                out.attempt{kCal}.loadedFrom.whichAttempt   = whichAttempt;
                                out.attempt{kCal}.loadedFrom.whichCal       = whichCal;
                                out.attempt{kCal}.loadedFrom.timestamp      = out.attempt{whichAttempt}.timestamp;
                                % 4. further state updates
                                if calAction>0
                                    usedCalibrationPoints = getWhichCalibrationPoints(cPointsP(:,1:2),out.attempt{kCal}.cal{calAction}.computeResult.points);
                                else
                                    usedCalibrationPoints = [];
                                end
                                cPointsP(:,end-[1 0]) = 0;
                                cPointsP(usedCalibrationPoints,end) = 1;
                                vPointsP(:,end-[1 0]) = 0;
                                if isfield(out.attempt{kCal},'val')
                                    vPointsP(out.attempt{kCal}.val{end}.allPoints.pointPos(:,1),end) = 1;
                                end
                                if strcmp(stage,'cal')
                                    pointsP = cPointsP;
                                else
                                    pointsP = vPointsP;
                                end
                                % apply
                                % log message
                                pointStr = sprintf('%d ',sort(usedCalibrationPoints));
                                obj.sendMessage(sprintf('LOAD CALIBRATION (%s), attempt %d, cal %d, points [%s]',getEyeLbl(out.attempt{kCal}.eye),whichAttempt,whichCal,pointStr(1:end-1)));
                                % change eye if needed
                                if ~strcmp(obj.settings.calibrateEye,out.attempt{kCal}.eye)
                                    % can't use code from above sadly as
                                    % these actions need to occur exactly
                                    % here. so some code duplication
                                    % follows...
                                    obj.changeAndCheckCalibEyeMode(out.attempt{kCal}.eye);
                                    obj.sendMessage(sprintf('CHANGE SETUP to %s',getEyeLbl(obj.settings.calibrateEye)));
                                    % exit and reenter calibration mode, if
                                    % needed
                                    if obj.doLeaveCalibrationMode()     % returns false if we weren't in calibration mode to begin with
                                        obj.doEnterCalibrationMode();
                                    end
                                    extraInp = {};
                                    if ~strcmp(obj.settings.calibrateEye,'both')
                                        extraInp        = {obj.settings.calibrateEye};
                                    end
                                    % update states of this screen
                                    currentEyeMenuItem  = find(ismember({'both','left','right'},obj.settings.calibrateEye));
                                    headP.crossEye      = (~obj.calibrateLeftEye)*1+(~obj.calibrateRightEye)*2; % will be 0, 1 or 2 (as we must calibrate at least one eye)
                                    headO.crossEye      = headP.crossEye;
                                end
                                if whichCal==0
                                    % there was no calibration, so clear
                                    % it. We do that by leaving and
                                    % reentering calibration mode
                                    if obj.doLeaveCalibrationMode()     % returns false if we weren't in calibration mode to begin with
                                        obj.doEnterCalibrationMode();
                                    end
                                    calibrationStatus       = 0;        % status: not calibrated
                                    awaitingCalChangeType   = '';       % done with loading calibration
                                else
                                    obj.buffer.calibrationApplyData(out.attempt{kCal}.cal{calAction}.computedCal);
                                    calibrationStatus = 3;      % status: loading
                                end
                                % some final cleanup
                                switch calLoadSource
                                    case 'snapshot'
                                        % adjust this item in snapshot menu to the
                                        % current one (only first two items, cals
                                        % still fine)
                                        snapshots{currentMenuSel,1} = kCal;
                                        snapshots{currentMenuSel,2} = calAction;
                                    case 'previousCal'
                                        % remove all previous calls, just
                                        % keep the loaded one
                                        temp        = out.attempt{kCal};
                                        out.attempt = {temp};
                                        kCal        = 1;
                                end
                                % done
                                qUpdateLineDisplay      = true;
                                qUpdateCalStatusText    = true;
                            else
                                % check we've loaded yet
                                % computed succesfully, waiting for
                                % calibration data retrieval
                                calData = obj.buffer.calibrationRetrieveResult();
                                if ~isempty(calData) && strcmp(calData.workItem.action,'ApplyCalibrationData')
                                    qUpdatePointHover       = true;
                                    qUpdateLineDisplay      = true;
                                    qUpdateCalStatusText    = true;
                                    calibrationStatus       = 1;    % status: calibrated
                                    awaitingCalChangeType   = '';   % done with loading calibration
                                end
                            end
                    end
                end
                    
                if qUpdateLineDisplay
                    % updates calibration/validation line displays
                    % if in validation mode, also updates validation data
                    % quality info, which is used below for various other
                    % things
                    linesForPoints = cell(1,size(pointsP,1));
                    valInfoTopTextCache = [];
                    
                    % prep to draw captured data in characteristic Tobii
                    % plot
                    if calibrationStatus~=3  % no lines when loading cal
                        if strcmp(stage,'cal')
                            if isfield(out.attempt{kCal},'cal') && isfield(out.attempt{kCal}.cal{calAction},'computeResult')
                                myCal       = out.attempt{kCal}.cal{calAction}.computeResult;
                                pointIdxs   = getWhichCalibrationPoints(pointsP(:,1:2),myCal.points);
                                for p=1:length(myCal.points)
                                    point.left = [];
                                    point.right= [];
                                    % left eye
                                    if ismember(out.attempt{kCal}.eye,{'both','left'})
                                        qVal        = strcmp(myCal.points(p).samples.left.validity,'validAndUsed');
                                        point.left  = myCal.points(p).samples.left.position(:,qVal);
                                    end
                                    % right eye
                                    if ismember(out.attempt{kCal}.eye,{'both','right'})
                                        qVal        = strcmp(myCal.points(p).samples.right.validity,'validAndUsed');
                                        point.right = myCal.points(p).samples.right.position(:,qVal);
                                    end
                                    linesForPoints{pointIdxs(p)} = point;
                                end
                            end
                        elseif isfield(out.attempt{kCal},'val')
                            % collect latest gaze data for each point
                            strSetup        = fieldnames(out.attempt{kCal}.val{1}.gazeData).';
                            [strSetup{2,:}] = deal(cell(1,size(pointsP,1)));
                            val.gazeData    = struct(strSetup{:});
                            val.pointPos    = nan(size(pointsP,1),5);
                            qFound          = false(1,size(pointsP,1));
                            whichCal        = getLastManualCal(out.attempt{kCal});
                            for p=length(out.attempt{kCal}.val):-1:1
                                idx = out.attempt{kCal}.val{p}.point(1);
                                if ~isnan(idx) && isempty(val.gazeData(idx).(strSetup{1,1})) && out.attempt{kCal}.val{p}.whichCal==whichCal && ~out.attempt{kCal}.val{p}.wasCancelled && ~out.attempt{kCal}.val{p}.wasDiscarded
                                    % we don't yet have validation data for
                                    % this point, and it is for the current
                                    % calibration -> collect
                                    qFound(idx) = true;
                                    % copy over all fields
                                    for f=1:size(strSetup,2)
                                        val.gazeData(idx).(strSetup{1,f}) = out.attempt{kCal}.val{p}.gazeData.(strSetup{1,f});
                                    end
                                    % also needs point position
                                    val.pointPos(idx,:) = out.attempt{kCal}.val{p}.point;
                                end
                            end
                            val.gazeData(~qFound)   = [];
                            val.pointPos(~qFound,:) = [];
                            
                            % compute data quality for these
                            if ~isempty(val.pointPos)
                                out.attempt{kCal}.val{valAction}.allPoints = obj.ProcessValData(val);
                                qUpdatePointHover = true;   % may need to update point hover
                                
                                % prep displaying
                                myVal = out.attempt{kCal}.val{valAction}.allPoints;
                                for p=1:length(myVal.gazeData)
                                    point.left = [];
                                    point.right= [];
                                    % left eye
                                    if ismember(out.attempt{kCal}.eye,{'both','left'})
                                        qVal        = myVal.gazeData(p). left.gazePoint.valid;
                                        point.left  = myVal.gazeData(p). left.gazePoint.onDisplayArea(:,qVal);
                                    end
                                    % right eye
                                    if ismember(out.attempt{kCal}.eye,{'both','right'})
                                        qVal        = myVal.gazeData(p).right.gazePoint.valid;
                                        point.right = myVal.gazeData(p).right.gazePoint.onDisplayArea(:,qVal);
                                    end
                                    linesForPoints{myVal.pointPos(p,1)} = point;
                                end
                                
                                % update info text
                                % acc field is [lx rx; ly ry]
                                % text only changes when calibration selection changes,
                                % but putting these lines in the above if makes logic
                                % more complicated. Now we regenerate the same text
                                % when switching between viewing calibration and
                                % validation output, thats an unimportant price to pay
                                % for simpler logic
                                Screen('TextFont', wpnt(end), obj.settings.UI.mancal.avg.text.font, obj.settings.UI.mancal.avg.text.style);
                                Screen('TextSize', wpnt(end), obj.settings.UI.mancal.avg.text.size);
                                [strl,strr,strsep] = deal('');
                                if ismember(out.attempt{kCal}.eye,{'both','left'})
                                    strl = sprintf(' <color=%s>Left eye<color>:  %.2f%s, (%.2f%s,%.2f%s)   %.2f%s   %.2f%s  %3.0f%%',clr2hex(obj.settings.UI.mancal.avg.text.eyeColors{1}),myVal.acc1D( 1 ),degChar,myVal.acc2D(1, 1 ),degChar,myVal.acc2D(2, 1 ),degChar,myVal.STD1D( 1 ),degChar,myVal.RMS1D( 1 ),degChar,myVal.dataLoss( 1 )*100);
                                end
                                if ismember(out.attempt{kCal}.eye,{'both','right'})
                                    idx = 1+strcmp(out.attempt{kCal}.eye,'both');
                                    strr = sprintf('<color=%s>Right eye<color>:  %.2f%s, (%.2f%s,%.2f%s)   %.2f%s   %.2f%s  %3.0f%%',clr2hex(obj.settings.UI.mancal.avg.text.eyeColors{2}),myVal.acc1D(idx),degChar,myVal.acc2D(1,idx),degChar,myVal.acc2D(2,idx),degChar,myVal.STD1D(idx),degChar,myVal.RMS1D(idx),degChar,myVal.dataLoss(idx)*100);
                                end
                                if strcmp(out.attempt{kCal}.eye,'both')
                                    strsep = '\n';
                                end
                                valText = sprintf('<u>Validation<u>    <i>offset 2D, (X,Y)      SD    RMS-S2S  loss<i>\n%s%s%s',strl,strsep,strr);
                                valInfoTopTextCache = obj.getTextCache(wpnt(end),valText,OffsetRect([-5 0 5 10],obj.scrInfo.resolution{end}(1)/2,.02*obj.scrInfo.resolution{end}(2)),'vSpacing',obj.settings.UI.mancal.avg.text.vSpacing,'yalign','top','xlayout','left','baseColor',obj.settings.UI.mancal.avg.text.color);
                            end
                        end
                    end
                    for p=1:length(linesForPoints)
                        if isempty(linesForPoints{p})
                            continue;
                        end
                        if ~isempty(linesForPoints{p}.left)
                            linesForPoints{p}.left  = bsxfun(@plus,bsxfun(@times,linesForPoints{p}.left,obj.scrInfo.resolution{1}.')*obj.scrInfo.sFac,obj.scrInfo.offset.');
                        end
                        if ~isempty(linesForPoints{p}.right)
                            linesForPoints{p}.right = bsxfun(@plus,bsxfun(@times,linesForPoints{p}.right,obj.scrInfo.resolution{1}.')*obj.scrInfo.sFac,obj.scrInfo.offset.');
                        end
                    end
                    qUpdateLineDisplay = false;
                end
                
                if qUpdateCalStatusText
                    % get color and text
                    switch calibrationStatus
                        case -1
                            % failed
                            text = 'calibration failed';
                            clr = [255 0 0];
                        case 0
                            % not calibrated
                            text = 'not calibrated';
                            clr = [200 200 200];
                        case 1
                            % calibrated
                            text = 'calibration succeeded';
                            clr = [0 255 0];
                        case 2
                            % calibrating
                            text = 'calibrating';
                            clr = [0 255 255];
                        case 3
                            % calibrating
                            text = 'loading calibration';
                            clr = [0 255 255];
                    end
                    Screen('TextFont', wpnt(end), obj.settings.UI.mancal.calState.text.font, obj.settings.UI.mancal.calState.text.style);
                    Screen('TextSize', wpnt(end), obj.settings.UI.mancal.calState.text.size);
                    if strcmp(stage,'cal')
                        modetxt = 'calibrating';
                    else
                        modetxt = 'validating';
                    end
                    pointStr = sprintf('%d ',sort(usedCalibrationPoints));
                    text = sprintf('<u>%s<u>\n<color=%s>%s<color>\nactive cal based on:\npoints [%s]',modetxt,clr2hex(clr),text,pointStr(1:end-1));
                    calTextCache = obj.getTextCache(wpnt(end), text,[10 10 10 10],'xalign','left','yalign','top');
                    qUpdateCalStatusText = false;
                end
                
                % calibration/validation logic variables
                if ~isempty(discardList) && isnan(whichPoint) && isnan(whichPointDiscard)
                    % point discard logic
                    whichPointDiscard               = discardList(1);
                    if strcmp(stage,'cal')
                        calAction                                   = calAction+1;
                        % start discard action
                        obj.buffer.calibrationDiscardData(pointsP(whichPointDiscard,1:2),extraInp{:});
                        pointsP(whichPointDiscard,end)              = 5;    %#ok<AGROW> % status: discarding
                        out.attempt{kCal}.cal{calAction}.point      = pointsP(whichPointDiscard,[5 3 4 1 2]);
                        out.attempt{kCal}.cal{calAction}.timestamp  = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                        discardList(1)                              = [];
                        qUpdatePointHover                           = true;
                    elseif isfield(out.attempt{kCal},'val')
                        valAction                                   = valAction+1;
                        % for validation, find the point in question and
                        % mark it as discarded, done super quick
                        for p=length(out.attempt{kCal}.val):-1:1
                            if out.attempt{kCal}.val{p}.point(1)==whichPointDiscard && ~out.attempt{kCal}.val{p}.wasCancelled && ~out.attempt{kCal}.val{p}.wasDiscarded
                                out.attempt{kCal}.val{p}.wasDiscarded = true;
                                break;
                            end
                        end
                        pointsP(whichPointDiscard,end-[1 0])        = 0;    %#ok<AGROW> % status: not collected
                        % need to updating lines display
                        out.attempt{kCal}.val{valAction}.point      = nan(1,5);         % dummy point
                        out.attempt{kCal}.val{valAction}.whichCal   = out.attempt{kCal}.val{valAction-1}.whichCal;
                        out.attempt{kCal}.val{valAction}.timestamp  = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                        qUpdateLineDisplay                          = true;
                        discardList(1)                              = [];
                        whichPointDiscard                           = nan;              % we're done already
                        qUpdatePointHover                           = true;
                        continue;
                    end
                end
                if ~isempty(pointList) && isnan(whichPoint) && isnan(whichPointDiscard) && isempty(awaitingCalChangeType)
                    % point collect logic
                    whichPoint              = pointList(1);
                    drawCmd                 = 'new';
                    nCollectionTries        = 0;
                    qWaitForAllowAccept     = true;
                    tick0p                  = nan;
                    tick0v                  = nan;
                    frameMsg                = sprintf('POINT ON %d (%.0f %.0f)',whichPoint,pointsP(whichPoint,3:4));
                    pointsP(whichPoint,end) = 2;    %#ok<AGROW> % status: displayed
                    qUpdatePointHover       = true;
                    pointList(1)            = [];
                    if strcmp(stage,'cal')
                        calAction                                   = calAction+1;
                        out.attempt{kCal}.cal{calAction}.point      = pointsP(whichPoint,[5 3 4 1 2]);
                        out.attempt{kCal}.cal{calAction}.timestamp  = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                    else
                        valAction                                   = valAction+1;
                        out.attempt{kCal}.val{valAction}.point      = pointsP(whichPoint,[5 3 4 1 2]);
                        % store for which calibration this validation is
                        % find last successful calibration (a calibration
                        % was successful if it has points in the result
                        % field)
                        out.attempt{kCal}.val{valAction}.whichCal   = getLastManualCal(out.attempt{kCal});
                        out.attempt{kCal}.val{valAction}.timestamp  = datestr(now,'yyyy-mm-dd HH:MM:SS.FFF');
                    end
                end
                
                % setup overlay with data quality info for specific point
                if ~isnan(openInfoForPoint) || (qUpdatePointHover && ~isnan(pointToShowInfoFor))
                    if ~isnan(openInfoForPoint)
                        pointToShowInfoFor = openInfoForPoint;
                        openInfoForPoint   = nan;
                    end
                    qUpdatePointHover   = false;
                    switch pointsP(pointToShowInfoFor,end)
                        case -1
                            % failed
                            clr = [255 0 0];
                            txt = 'collection failed';
                        case 0
                            % not collected
                            clr = [200 200 200];
                            txt = 'not collected';
                        case 1
                            % collected
                            clr = [0 255 0];
                            txt = 'collected successfully';
                        case 2
                            % displaying
                            clr = [131 177 255];
                            txt = 'being shown to subject';
                        case 3
                            % collecting
                            clr = [0 0 255];
                            txt = 'data is being collected';
                        case 4
                            % enqueued
                            clr = [0 255 255];
                            txt = 'enqueued to be shown to participant';
                        case 5
                            % discarding
                            clr = [188 61 18];
                            txt = 'data is being discarded';
                    end
                    txt = sprintf('status: <color=%s>%s',clr2hex(clr),txt);
                    % prepare text
                    Screen('TextFont', wpnt(end), obj.settings.UI.mancal.hover.text.font, obj.settings.UI.mancal.hover.text.style);
                    Screen('TextSize', wpnt(end), obj.settings.UI.mancal.hover.text.size);
                    if strcmp(stage,'val') && isfield(out.attempt{kCal},'val') && isfield(out.attempt{kCal}.val{valAction},'allPoints')
                        myVal = out.attempt{kCal}.val{valAction}.allPoints;
                        % see if we have info for the requested point
                        idx = find(myVal.pointPos(:,1)==pointToShowInfoFor,1);
                        if ~isempty(idx)
                            if strcmp(out.attempt{kCal}.eye,'both')
                                lE = myVal.quality(idx).left;
                                rE = myVal.quality(idx).right;
                                c1 = clr2hex(obj.settings.UI.mancal.hover.text.eyeColors{1});
                                c2 = clr2hex(obj.settings.UI.mancal.hover.text.eyeColors{2});
                                txt = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>, <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>                 <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>                 <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>                  <color=%s>%3.0f%%<color>',c1,lE.acc1D,degChar,abs(lE.acc2D(1)),degChar,abs(lE.acc2D(2)),degChar, c2,rE.acc1D,degChar,abs(rE.acc2D(1)),degChar,abs(rE.acc2D(2)),degChar, c1,lE.STD1D,degChar, c2,rE.STD1D,degChar, c1,lE.RMS1D,degChar, c2,rE.RMS1D,degChar, c1,lE.dataLoss*100, c2,rE.dataLoss*100);
                            elseif strcmp(out.attempt{kCal}.eye,'left')
                                lE = myVal.quality(idx).left;
                                c = clr2hex(obj.settings.UI.mancal.hover.text.eyeColors{1});
                                txt = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>',c,lE.acc1D,degChar,abs(lE.acc2D(1)),degChar,abs(lE.acc2D(2)),degChar, c,lE.STD1D,degChar, c,lE.RMS1D,degChar, c,lE.dataLoss*100);
                            elseif strcmp(out.attempt{kCal}.eye,'right')
                                rE = myVal.quality(idx).right;
                                c = clr2hex(obj.settings.UI.mancal.hover.text.eyeColors{2});
                                txt = sprintf('Offset:       <color=%s>%.2f%s, (%.2f%s,%.2f%s)<color>\nPrecision SD:        <color=%s>%.2f%s<color>\nPrecision RMS:       <color=%s>%.2f%s<color>\nData loss:            <color=%s>%3.0f%%<color>',c,rE.acc1D,degChar,abs(rE.acc2D(1)),degChar,abs(rE.acc2D(2)),degChar, c,rE.STD1D,degChar, c,rE.RMS1D,degChar, c,rE.dataLoss*100);
                            end
                        end
                    end
                    [pointInfoTextCache,txtbounds] = obj.getTextCache(wpnt(end),txt,[],'xlayout','left','baseColor',obj.settings.UI.mancal.hover.text.color);
                    % get box around text
                    margin = 10;
                    infoBoxRect = GrowRect(txtbounds,margin,margin);
                    infoBoxRect = OffsetRect(infoBoxRect,-infoBoxRect(1),-infoBoxRect(2));  % make sure rect is [0 0 w h]
                end
                
                % draw loop
                while true
                    tick        = tick+1;
                    nextFlipT   = out.flips(end)+1/1000;
                    
                    % get eye data if needed
                    if qShowGaze || qShowHead || qShowGazeToAll || (qShowEyeImage && qDrawEyeValidity)
                        if ~qShowGaze
                            eyeData     = obj.buffer.peekN('gaze',1);
                        else
                            eyeData     = obj.buffer.peekN('gaze',nDataPointLiveView);
                        end
                    end
                    % per frame updates
                    if qShowGazeToAll
                        % prep to show gaze data on participant screen
                        gazePosP    = nan(2,2);
                        if ~isempty(eyeData.systemTimeStamp)
                            if obj.calibrateLeftEye  && eyeData. left.gazePoint.valid(end)
                                gazePosP(:,1) = eyeData. left.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            end
                            if obj.calibrateRightEye && eyeData.right.gazePoint.valid(end)
                                gazePosP(:,2) = eyeData.right.gazePoint.onDisplayArea(:,end).*obj.scrInfo.resolution{1}.';
                            end
                        end
                    end
                    
                    % prep head
                    if qShowHead
                        posGuide    = obj.buffer.peekN('positioning',1);
                        if ~isempty(eyeData.systemTimeStamp)
                            inp = {
                                 eyeData.left.gazeOrigin.valid(end),  eyeData.left.gazeOrigin.inUserCoords(:,end),  posGuide.left.user_position,  eyeData.left.pupil.valid(end),  eyeData.left.pupil.diameter(end),  eyeData.left.eyeOpenness.valid(end),  eyeData.left.eyeOpenness.diameter(end),...
                                eyeData.right.gazeOrigin.valid(end), eyeData.right.gazeOrigin.inUserCoords(:,end), posGuide.right.user_position, eyeData.right.pupil.valid(end), eyeData.right.pupil.diameter(end), eyeData.right.eyeOpenness.valid(end), eyeData.right.eyeOpenness.diameter(end)
                                };
                        else
                            inp = {
                                [], [],  posGuide.left.user_position, [], [], [], [],...
                                [], [], posGuide.right.user_position, [], [], [], []
                                };
                        end
                        headO.update(inp{:});
                        if qShowHeadToAll
                            headP.update(inp{:});
                        end
                    end
                    
                    % prep eye image
                    if qHasEyeIm && qShowEyeImage
                        % get eye image
                        if ~obj.settings.mancal.doRecordEyeImages
                            eyeIm       = obj.buffer.consumeTimeRange('eyeImage',eyeStartTime);  % from start time onward (default third argument: now)
                        else
                            eyeIm       = obj.buffer.peekN('eyeImage',8);    % peek (up to) last eight from end (so we certainly have some for each camera and region), keep them in buffer
                        end
                        [eyeTexs,eyeSzs,eyePoss,eyeImageRectLocal]  = ...
                            UploadImages(eyeIm,eyeTexs,eyeSzs,eyePoss,eyeImageRectLocal,wpnt(end),obj.eyeImageCanvasSize);
                        
                        % update eye image locations if size of returned eye image changed
                        if isempty(obj.eyeImageCanvasSize) && (any(eyeSzs(:,1).'~=diff(reshape(eyeImageRect(:,1),2,2))) || any(eyeSzs(:,3).'~=diff(reshape(eyeImageRect(:,3),2,2))))
                            visible = [but.visible];
                            if ~any(visible)
                                basePos = round(obj.scrInfo.resolution{end}(2)*.95);
                            else
                                basePos = min(butRects(2,[but(1:5).visible]));
                            end
                            eyeImageRect(:,1) = OffsetRect([0 0 eyeSzs(:,1).'],obj.scrInfo.center{end}(1)-eyeSzs(1,1)-eyeImageMargin/2,basePos-eyeImageMargin-eyeSzs(2,1)).';
                            eyeImageRect(:,3) = OffsetRect([0 0 eyeSzs(:,3).'],obj.scrInfo.center{end}(1)            +eyeImageMargin/2,basePos-eyeImageMargin-eyeSzs(2,3)).';
                        elseif ~isempty(obj.eyeImageCanvasSize)
                            % turn canvas-local eye image locations into
                            % screen locations
                            for p=1:size(eyeImageRectLocal,2)
                                camIdx = abs(ceil(p/2)-3);  % [1 2] -> 1 -> 2, [3 4] -> 2 -> 1: flip 1<->2 at end because cam 1 is right camera, cam 2 left camera
                                eyeImageRect(:,p) = eyeImageRectLocal(:,p)+eyeCanvasPoss([1 2 1 2],camIdx);
                            end
                        end
                    end
                    
                    if qChangeMenuArrow
                        % setup arrow that can be moved with arrow keys
                        rect = currentMenuRects(currentMenuSel,:);
                        rect(3) = rect(1)+menuMargin+20;
                        menuActiveCache = obj.getTextCache(wpnt(end),' <color=ff0000>-><color>',rect);
                        qChangeMenuArrow = false;
                    end

                    
                    % drawing
                    Screen('FillRect', wpnt(1), bgClrP);
                    Screen('FillRect', wpnt(2), bgClrO);
                    % draw text with validation accuracy etc info
                    if ~isempty(valInfoTopTextCache)
                        obj.drawCachedText(valInfoTopTextCache);
                    end
                    % draw text with calibration status
                    obj.drawCachedText(calTextCache);
                    % draw buttons
                    mousePos = [mx my];
                    but(1).draw(mousePos,qSelectEyeMenuOpen);
                    but(2).draw(mousePos,qShowEyeImage);
                    but(3).draw(mousePos);
                    but(4).draw(mousePos);
                    but(5).draw(mousePos,qSelectSnapMenuOpen);
                    but(6).draw(mousePos,qShowHead);
                    but(7).draw(mousePos,qShowGaze);
                    
                    % draw eye images, if any
                    if qShowEyeImage
                        qTex = ~~eyeTexs;
                        if any(qTex)
                            if qDrawEyeValidity
                                validityRects   = GrowRect(eyeImageRect.',3,3).';
                                if ~isempty(eyeData.systemTimeStamp)
                                    qValid          = [eyeData.left.gazeOrigin.valid(end) eyeData.right.gazeOrigin.valid(end)];
                                else
                                    qValid          = [false false];
                                end
                                qValid          = qValid([2 1 2 1]); % first and third are right eye, second and fourth left eye
                                clrs            = zeros(3,4);
                                clrs(:,qValid)  = repmat([0 120 0].',1,sum( qValid));
                                clrs(:,~qValid) = repmat([150 0 0].',1,sum(~qValid));
                                Screen('FillRect', wpnt(end), clrs(:,qTex), validityRects(:,qTex));
                            end
                            Screen('DrawTextures', wpnt(end), eyeTexs(qTex),[],eyeImageRect(:,qTex));
                        end
                    end
                    
                    % draw calibration/validation points
                    % 1. first draw circles behind each point, denoting point state
                    for p=1:size(pointsO,1)
                        switch pointsP(p,end)
                            case -1
                                % failed
                                clr = [255 0 0];
                            case 0
                                % not collected
                                clr = [200 200 200];
                            case 1
                                % collected
                                clr = [0 255 0];
                            case 2
                                % displaying
                                clr = [131 177 255];
                            case 3
                                % collecting
                                clr = [0 0 255];
                            case 4
                                % enqueued
                                clr = [0 255 255];
                            case 5
                                % discarding
                                clr = [188 61 18];
                        end
                        Screen('gluDisk', wpnt(end),obj.getColorForWindow(clr,wpnt(end)), pointsO(p,1), pointsO(p,2), obj.settings.UI.mancal.fixBackSize*obj.scrInfo.sFac*1.5/2);
                    end
                    % 2. then draw points themselves
                    obj.drawFixPoints(wpnt(end),pointsO,obj.settings.UI.mancal.fixBackSize*obj.scrInfo.sFac,obj.settings.UI.mancal.fixFrontSize*obj.scrInfo.sFac,obj.settings.UI.mancal.fixBackColor,obj.settings.UI.mancal.fixFrontColor);
                    % 3. draw text annotations
                    for p=size(pointsO,1):-1:1
                        obj.drawCachedText(pointTextCache(p));
                    end
                    
                    % draw line displays
                    for p=1:length(linesForPoints)
                        if isempty(linesForPoints{p})
                            continue;
                        end
                        if ~isempty(linesForPoints{p}.left)
                            lines  = reshape([repmat(pointsO(p,:).',1,size(linesForPoints{p}.left,2)) ; linesForPoints{p}.left ],2,[]);
                            Screen('DrawLines',wpnt(end),lines,1,eyeClrs{1},[],2);
                        end
                        if ~isempty(linesForPoints{p}.right)
                            lines  = reshape([repmat(pointsO(p,:).',1,size(linesForPoints{p}.right,2)); linesForPoints{p}.right],2,[]);
                            Screen('DrawLines',wpnt(end),lines,1,eyeClrs{2},[],2);
                        end
                    end
                    
                    % if head shown, draw on top
                    if qShowHead
                        Screen('FillRect',wpnt(end),headBgClrO,headORect);
                        drawOrientedPoly(wpnt(end),circVerts,1,[0 0],[0 1; 1 0],refSzO,refPosO,[],refClrO,5*facO);
                        headO.draw();
                        Screen('TextFont', wpnt(end), obj.settings.UI.mancal.instruct.font, obj.settings.UI.mancal.instruct.style);
                        Screen('TextSize', wpnt(end), max(round(obj.settings.UI.mancal.instruct.size*facO),4));
                        str = obj.settings.UI.mancal.instruct.strFun(headO.avgX,headO.avgY,headO.avgDist,obj.settings.UI.setup.referencePos(1),obj.settings.UI.setup.referencePos(2),obj.settings.UI.setup.referencePos(3));
                        if ~isempty(str)
                            DrawFormattedText2(str,'win',wpnt(2),'sx','center','xalign','center','xlayout','center','sy',.03*RectHeight(headORect),'yalign','top','baseColor',obj.settings.UI.mancal.instruct.color,'vSpacing',obj.settings.UI.mancal.instruct.vSpacing,'winRect',headORect);
                        end
                        if qShowHeadToAll
                            drawOrientedPoly(wpnt(1),circVerts,1,[0 0],[0 1; 1 0],refSzP,refPosP,[],refClrP,5);
                            headP.draw();
                        end
                    end
                    
                    % if showing gaze, draw
                    if qShowGaze
                        clrs = {[],[]};
                        if obj.calibrateLeftEye
                            clrs{1} = onlineGazeClr{1,end};
                        end
                        if obj.calibrateRightEye
                            clrs{2} = onlineGazeClr{2,end};
                        end
                        drawLiveData(wpnt(end),eyeData,dataWindowLength,clrs{:},4,obj.scrInfo.resolution{1},obj.scrInfo.sFac,obj.scrInfo.offset);    % yes, that is resolution of screen 1 on purpose, sFac and offset transform it to screen 2
                        if qShowGazeToAll
                            if ~isnan(gazePosP(1,1))
                                Screen('gluDisk', wpnt(1),onlineGazeClr{1,1}, gazePosP(1,1), gazePosP(2,1), 10);
                            end
                            if ~isnan(gazePosP(1,2))
                                Screen('gluDisk', wpnt(1),onlineGazeClr{2,1}, gazePosP(1,2), gazePosP(2,2), 10);
                            end
                        end
                    end
                    
                    % if hovering over validation point, show info
                    if ~isnan(pointToShowInfoFor)
                        rect = OffsetRect(infoBoxRect,mx,my);
                        % make sure does not go offscreen
                        if rect(3)>obj.scrInfo.resolution{end}(1)
                            rect = OffsetRect(rect,obj.scrInfo.resolution{end}(1)-rect(3),0);
                        end
                        if rect(4)>obj.scrInfo.resolution{end}(2)
                            rect = OffsetRect(rect,0,obj.scrInfo.resolution{end}(2)-rect(4));
                        end
                        Screen('FillRect',wpnt(end),hoverBgClr,rect);
                        obj.drawCachedText(pointInfoTextCache,rect);
                    end
                    
                    
                    % if selection menu open, draw on top
                    if qSelectEyeMenuOpen || qSelectSnapMenuOpen
                        % menu background
                        Screen('FillRect',wpnt(end),menuBgClr,currentMenuBackRect);
                        % menuRects, inactive and currently active
                        if any(~menuActiveItem)
                            Screen('FillRect',wpnt(end),menuItemClr      ,currentMenuRects(~menuActiveItem,:).');
                        end
                        if any(menuActiveItem)
                            Screen('FillRect',wpnt(end),menuItemClrActive,currentMenuRects( menuActiveItem,:).');
                        end
                        % text in each rect
                        for c=1:length(currentMenuTextCache)
                            obj.drawCachedText(currentMenuTextCache(c));
                        end
                        % arrow
                        obj.drawCachedText(menuActiveCache);
                    end
                    
                    % on participant screen, draw fixation point if
                    % currently active
                    if ~isnan(whichPoint)
                        qAllowAccept= drawFunction(wpnt(1),drawCmd,whichPoint,pointsP(whichPoint,3:4),tick,stage);
                        drawCmd     = 'draw';
                        if qWaitForAllowAccept && qAllowAccept
                            tick0p              = tick;
                            qWaitForAllowAccept = false;
                        end
                    end
                    
                    % drawing done, show
                    out.flips(end+1) = Screen('Flip',wpnt(1),nextFlipT);
                                       Screen('Flip',wpnt(2),[],[],2);
                    if ~isempty(frameMsg)
                        obj.sendMessage(frameMsg,out.flips(end));
                        frameMsg = '';
                    end
                    
                    % calibration logic
                    % check for status of discarding point
                    if ~isnan(whichPointDiscard)
                        % check status
                        callResult  = obj.buffer.calibrationRetrieveResult();
                        if ~isempty(callResult) && strcmp(callResult.workItem.action,'DiscardData')
                            pointsP(whichPointDiscard,end-[1 0]) = 0;        % status: not collected
                            out.attempt{kCal}.cal{calAction}.discardStatus = callResult;
                            out.attempt{kCal}.cal{calAction}.wasCancelled = false;
                            out.attempt{kCal}.cal{calAction}.wasDiscarded = false;
                            
                            % find which point we just discarded, mark it
                            % as such
                            for p=length(out.attempt{kCal}.cal):-1:1
                                if out.attempt{kCal}.cal{p}.point(1)==whichPointDiscard && ~out.attempt{kCal}.cal{p}.wasCancelled && ~out.attempt{kCal}.cal{p}.wasDiscarded && ~isfield(out.attempt{kCal}.cal{p},'discardStatus')
                                    out.attempt{kCal}.cal{p}.wasDiscarded = true;
                                    break;
                                end
                            end
                            
                            % if in calibration mode and point states have
                            % changed, and no further calibration points
                            % queued up for collection or discarding ->
                            % kick off a new calibration
                            if strcmp(stage,'cal') && ~isequal(pointsP(:,end),pointStateLastCal) && isempty(pointList) && isempty(discardList)
                                qUpdateCalStatusText    = true;
                                pointStateLastCal       = pointsP(:,end);
                                if all(pointsP(:,end)==0)
                                    % if no points left, user intention is
                                    % to clear the calibration. We do that
                                    % by leaving and reentering calibration
                                    % mode
                                    if obj.doLeaveCalibrationMode()     % returns false if we weren't in calibration mode to begin with
                                        obj.doEnterCalibrationMode();
                                    end
                                    qNewCal     = true;
                                    qClearState = true;
                                else
                                    % data for some points left: issue
                                    % calibration command
                                    calibrationStatus       = 2;
                                    awaitingCalChangeType   = 'compute';
                                    obj.buffer.calibrationComputeAndApply();
                                end
                            end
                            
                            whichPointDiscard = nan;
                            qUpdatePointHover = true;
                            break;
                        end
                    end
                    % accept point
                    if tick>tick0p+paceIntervalTicks && ~isnan(whichPoint)
                        qPointDone = false;
                        if strcmp(stage,'cal')
                            if ~nCollectionTries
                                % start collection
                                obj.buffer.calibrationCollectData(pointsP(whichPoint,1:2),extraInp{:});
                                pointsP(whichPoint,end-[1 0])   = [0 3];            % status: collecting, and set previous to not collected since it'll now be wiped
                                pointStateLastCal(whichPoint)   = 0; %#ok<AGROW>    % denote that no calibration data available for this point (either not yet collected so its true, or this recollection discards previous
                                nCollectionTries                = 1;
                                out.attempt{kCal}.cal{calAction}.wasCancelled = false;
                                out.attempt{kCal}.cal{calAction}.wasDiscarded = false;
                                qUpdatePointHover               = true;
                                break;
                            else
                                % check status
                                callResult  = obj.buffer.calibrationRetrieveResult();
                                if ~isempty(callResult)
                                    if strcmp(callResult.workItem.action,'CollectData') && callResult.status==0     % TOBII_RESEARCH_STATUS_OK
                                        % success, next point
                                        pointsP(whichPoint,end-[1 0]) = 1;        % status: collected
                                        qPointDone              = true;
                                        out.attempt{kCal}.cal{calAction}.collectStatus = callResult;
                                    else
                                        % failed
                                        if nCollectionTries==1
                                            % if failed first time, immediately try again
                                            obj.buffer.calibrationCollectData(pointsP(whichPoint,1:2),extraInp{:});
                                            nCollectionTries = 2;
                                        else
                                            % failed again, stop trying
                                            pointsP(whichPoint,end-[1 0]) = -1;       % status: failed
                                            qPointDone              = true;
                                            out.attempt{kCal}.cal{calAction}.collectStatus = callResult;
                                        end
                                    end
                                end
                            end
                        else
                            if isnan(tick0v)
                                tick0v = tick;
                                out.attempt{kCal}.val{valAction}.wasCancelled = false;
                                out.attempt{kCal}.val{valAction}.wasDiscarded = false;
                                pointsP(whichPoint,end) = 3;        % status: collecting
                                qUpdatePointHover       = true;
                                break;
                            end
                            if tick>tick0v+collectInterval
                                dat = obj.buffer.peekN('gaze',nDataPoint);
                                out.attempt{kCal}.val{valAction}.gazeData = dat;
                                tick0v              = nan;
                                qPointDone          = true;
                                qUpdateLineDisplay  = true;
                                pointsP(whichPoint,end) = 1;        % status: collected
                            end
                        end
                        % if finished collecting, log, clean up, and if in
                        % calibration mode, calibrate if collection was
                        % successful
                        if qPointDone
                            frameMsg = sprintf('POINT OFF %d (%.0f %.0f)',whichPoint,pointsP(whichPoint,3:4));
                            if strcmp(stage,'cal')
                                if callResult.status==0
                                    % success
                                    frameMsg = [frameMsg ', status: ok']; %#ok<AGROW>
                                else
                                    % failure
                                    frameMsg = [frameMsg sprintf(', status: failed (%s)',callResult.statusString)]; %#ok<AGROW>
                                end
                                fun = obj.settings.mancal.cal.pointNotifyFunction;
                                extra = {out.attempt{kCal}.cal{calAction}.collectStatus};
                            else
                                fun = obj.settings.mancal.val.pointNotifyFunction;
                                extra = {};
                            end
                            if isa(fun,'function_handle')
                                fun(obj,whichPoint,pointsP(whichPoint,1:2),pointsP(whichPoint,3:4),stage,extra{:});
                            end
                            whichPoint = nan;
                            % if no points enqueued, reset calibration
                            % point drawer function (if any)
                            if isempty(pointList)
                                drawFunction(wpnt(1),'cleanUp',nan,nan,nan,nan);
                            end
                            % if in calibration mode and point states have
                            % changed, and no further calibration points
                            % queued up for collection or discarding ->
                            % kick off a new calibration
                            if strcmp(stage,'cal') && ~isequal(pointsP(:,end),pointStateLastCal) && isempty(pointList) && isempty(discardList)
                                calibrationStatus       = 2;
                                qUpdateCalStatusText    = true;
                                pointStateLastCal       = pointsP(:,end);
                                awaitingCalChangeType   = 'compute';
                                obj.buffer.calibrationComputeAndApply();
                            end
                            qUpdatePointHover = true;
                            % done with draw loop
                            break;
                        end
                    end

                    % get user response
                    [mx,my,mousePress,keyPress,shiftIsDown,mouseRelease] = obj.getNewMouseKeyPress(wpnt(end));
                    mousePos = [mx my];
                    % if any drag active change head rect position/size
                    if qDraggingHead || ~isnan(headResizingGrip)
                        % update headORect
                        if qDraggingHead
                            vec         = mousePos-dragPos;
                            headORect   = OffsetRect(headOriRect,vec(1),vec(2));
                        else
                            % get which to check against
                            switch headResizingGrip
                                case 1
                                    % left-upper corner
                                    rIdx = [1 2];
                                    mIdx = [1 2];
                                case 2
                                    % right-upper corner
                                    rIdx = [3 2];
                                    mIdx = [1 2];
                                case 3
                                    % left-lower corner
                                    rIdx = [1 4];
                                    mIdx = [1 2];
                                case 4
                                    % right upper corner
                                    rIdx = [3 4];
                                    mIdx = [1 2];
                                case 5
                                    % upper edge
                                    rIdx = 2;
                                    mIdx = 2;
                                case 6
                                    % lower edge
                                    rIdx = 4;
                                    mIdx = 2;
                                case 7
                                    % left edge
                                    rIdx = 1;
                                    mIdx = 1;
                                case 8
                                    % right edge
                                    rIdx = 3;
                                    mIdx = 1;
                            end
                            headORect = headOriRect;
                            headORect(rIdx) = mousePos(mIdx);
                            if RectWidth(headORect)~=RectWidth(headOriRect) || RectHeight(headORect)~=RectHeight(headOriRect)
                                % scale changed, do update
                                
                                % first, check rect did not get too small.
                                % arbitrarily decide rect should be at
                                % least 100 px high and wide
                                w = RectWidth(headORect);
                                if w<100
                                    add = 100-w;
                                    % find at which side to add
                                    if any(rIdx==1)
                                        % resize involves change of left edge,
                                        % so add to that
                                        headORect(1) = headORect(1)-add;
                                    else
                                        % right edge instead
                                        headORect(3) = headORect(3)+add;
                                    end
                                end
                                h = RectHeight(headORect);
                                if h<100
                                    add = 100-h;
                                    % find at which side to add
                                    if any(rIdx==2)
                                        % resize involves change of top edge,
                                        % so add to that
                                        headORect(2) = headORect(2)-add;
                                    else
                                        % bottom edge instead
                                        headORect(4) = headORect(4)+add;
                                    end
                                end
                                
                                % next, check if aspect ratio should be
                                % maintained
                                scaleFacs = [RectWidth(headORect)/RectWidth(headOriRect) RectHeight(headORect)/RectHeight(headOriRect)];
                                if ~isscalar(rIdx) && shiftIsDown
                                    % we are dragging a corner, make
                                    % non-max dimension consistent with
                                    % scaling of max dimension
                                    [scaleFac,i] = max(scaleFacs(mIdx));    % get largest scale fac
                                    i=mod(i,2)+1;                           % get dimension's scaleFac is smaller
                                    aspectr = RectWidth(headOriRect)/RectHeight(headOriRect);
                                    switch i
                                        case 1
                                            % horizontal should be adjusted
                                            newSize = RectHeight(headOriRect)*scaleFac*aspectr;
                                            if rIdx(i)==1
                                                % left edge needs changing
                                                headORect(1) = headORect(3)-newSize;
                                            else
                                                % right edge needs changing
                                                headORect(3) = headORect(1)+newSize;
                                            end
                                        case 2
                                            % vertical
                                            newSize = RectWidth(headOriRect)*scaleFac/aspectr;
                                            if rIdx(i)==2
                                                % top edge needs changing
                                                headORect(2) = headORect(4)-newSize;
                                            else
                                                % bottom edge needs changing
                                                headORect(4) = headORect(2)+newSize;
                                            end
                                    end
                                end
                            end
                            
                            % now update scale factor of some of the
                            % visualizations
                            scaleFacs   = [RectWidth(headORect)/obj.scrInfo.resolution{2}(1) RectHeight(headORect)/obj.scrInfo.resolution{2}(2)];
                            facO        = min(scaleFacs);
                            refSzO      = ovalVSz*obj.scrInfo.resolution{2}(2)*facO;
                        end
                        refPosO     = updateHeadDragResize(headORect,obj.scrInfo.resolution{2},facO,headO,refSzO,obj.settings.UI.setup.headCircleEdgeWidth);
                        % also update cursor rects
                        headRects   = getSelectionRects(headORect,3,obj.settings.UI.cursor);
                        cursor.cursorRects(1:size(headRects,2)) = num2cell(headRects,1);
                    end
                    % update cursor look if needed
                    cursor.update(mx,my);
                    if (qDraggingHead || ~isnan(headResizingGrip)) && any(mouseRelease)
                        % drag/resize finished, headORect already reflects
                        % correct position/size, just update
                        % dragging/resizing state
                        qDraggingHead           = false;
                        headResizingGrip        = nan;
                    elseif any(mousePress)
                        % don't care which button for now. determine if clicked on either
                        % of the buttons
                        if qSelectEyeMenuOpen || qSelectSnapMenuOpen
                            iIn = find(inRect(mousePos,[currentMenuRects.' currentMenuBackRect.']),1);   % press on button is also in rect of whole menu, so we get multiple returns here in this case. ignore all but first, which is the actual menu button pressed
                            if ~isempty(iIn)
                                if qSelectEyeMenuOpen
                                    if iIn<=3
                                        currentMenuSel      = iIn;
                                        qSelectedEyeChanged = currentEyeMenuItem~=currentMenuSel;
                                        qToggleSelectEyeMenu= true;
                                        break;
                                    end
                                elseif qSelectSnapMenuOpen
                                    if iIn==size(snapshots,1)+1
                                        % save current state to new
                                        % snapshot, don't close menu when
                                        % doing so
                                        qSaveSnapShot = true;
                                    else
                                        % load another snapshot
                                        currentMenuSel          = iIn;
                                        if currentSnapMenuItem~=currentMenuSel
                                            awaitingCalChangeType   = 'load';
                                            calLoadSource           = 'snapshot';
                                        end
                                        qToggleSelectSnapMenu   = true;
                                    end
                                    break;
                                end
                            else
                                if qSelectEyeMenuOpen
                                    qToggleSelectEyeMenu    = true;
                                elseif qSelectSnapMenuOpen
                                    qToggleSelectSnapMenu   = true;
                                end
                                break;
                            end
                        end
                        if ~(qSelectEyeMenuOpen || qSelectSnapMenuOpen) || qToggleSelectEyeMenu || qToggleSelectSnapMenu    % if menu not open or menu closing because pressed outside the menu, check if pressed any of these menu buttons
                            qInBut      = inRect(mousePos,butRects);
                            qOnHead     = inRect(mousePos,headRects);
                            qOnFixTarget= inRect(mousePos,calValRectsSel);
                            if any(qOnHead)
                                % starting drag/resize of head
                                if qOnHead(end)
                                    qDraggingHead       = true;
                                    dragPos             = mousePos;
                                else
                                    headResizingGrip    = find(qOnHead,1);  % sometimes due to rounding, there is slight overlap between corner and edge rects. Corners are first in rects, so this puts preference on corners
                                end
                                headOriRect             = headORect;
                            elseif any(qInBut)
                                if qInBut(1)
                                    qToggleSelectEyeMenu= true;
                                elseif qInBut(2)
                                    qToggleEyeImage     = true;
                                elseif qInBut(3)
                                    qToggleStage        = true;
                                elseif qInBut(4)
                                    status              = 1;
                                    qDoneWithManualCalib= true;
                                elseif qInBut(5)
                                    qToggleSelectEyeMenu= true;
                                elseif qInBut(6)
                                    qShowHead           = ~qShowHead;
                                    qShowHeadToAll      = shiftIsDown;
                                    qUpdateCursors      = true;
                                elseif qInBut(7)
                                    qShowGaze           = ~qShowGaze;
                                    qShowGazeToAll      = shiftIsDown;
                                end
                                break;
                            elseif any(qOnFixTarget)
                                which                   = find(qOnFixTarget,1);
                                if shiftIsDown
                                    qDoneSomething = false;
                                    % if clicked point is enqueued, cancel
                                    % it
                                    qInList = pointList==which;
                                    if any(qInList)
                                        % reset to previous state
                                        pointsP(qInList,end) = pointsP(qInList,end-1);
                                        qDoneSomething = true;
                                        % clear from list of enqueued points
                                        pointList(qInList) = []; %#ok<AGROW>
                                    end
                                    
                                    % if currently showing point but not
                                    % yet trying to collect, cancel as well
                                    if ~isnan(whichPoint) && whichPoint==which && pointsP(whichPoint,end)==2
                                        qCancelPointCollect = true;
                                    end
                                    
                                    % if point already collected, enqueue a
                                    % discard for it
                                    if pointsP(which,end)==1
                                        discardList = [discardList which]; %#ok<AGROW>
                                        qDoneSomething = true;
                                    end
                                    if qDoneSomething
                                        qUpdatePointHover = true;
                                        break;
                                    end
                                        
                                elseif ~ismember(pointsP(which,end),[2 3 4])
                                    % clicked point is not in enqueued,
                                    % displaying or collecting status:
                                    % enqueue
                                    pointList(1,end+1) = which; %#ok<AGROW>
                                    pointsP(which,end) = 4; % status: enqueued
                                    qUpdatePointHover  = true;
                                    break;
                                end
                            end
                        end
                    elseif any(keyPress)
                        keys = KbName(keyPress);
                        if iscell(keys)
                            % multiple keys pressed at exactly the same
                            % time. We're handling only the first, else
                            % logic below becomes impossible (what if
                            % 'shift' and '+=' pressed at the same time?,
                            % should be processed as {'shift','+','='}, but
                            % i can't write the logic to pull that appart..
                            keys = keys{1};
                        end
                        
                        % these key combinations should always be
                        % available, and override anything the user has set
                        % or other logic below
                        if any(strcmpi(keys,'escape')) && shiftIsDown
                            status = -5;
                            qDoneWithManualCalib = true;
                            break;
                        elseif any(strcmpi(keys,'s')) && shiftIsDown
                            % skip calibration
                            status = 2;
                            qDoneWithManualCalib = true;
                            break;
                        elseif any(strcmpi(keys,'d')) && shiftIsDown
                            % take screenshot
                            takeScreenshot(wpnt(1));
                        elseif any(strcmpi(keys,'o')) && shiftIsDown
                            % take screenshot of operator screen
                            takeScreenshot(wpnt(2));
                        end
                        
                        % user-defined accelerators and other logic
                        if qSelectEyeMenuOpen || qSelectSnapMenuOpen
                            if any(strcmpi(keys,'escape')) || (qSelectEyeMenuOpen && any(strcmpi(keys,obj.settings.UI.button.mancal.changeeye.accelerator))) || (qSelectSnapMenuOpen && any(strcmpi(keys,obj.settings.UI.button.mancal.snapshot.accelerator)))
                                if qSelectEyeMenuOpen
                                    qToggleSelectEyeMenu    = true;
                                elseif qSelectSnapMenuOpen
                                    qToggleSelectSnapMenu   = true;
                                end
                                break;
                            elseif any(ismember(num2cell(keys),{'1','2','3','4','5','6','7','8','9','+'}))    % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                qWhich      = ismember(num2cell(keys),{'1','2','3','4','5','6','7','8','9','+'});
                                requested   = str2double(keys(qWhich));
                                if qSelectEyeMenuOpen
                                    if requested<=3
                                        currentMenuSel      = requested;
                                        qSelectedEyeChanged = currentEyeMenuItem~=currentMenuSel;
                                        qToggleSelectEyeMenu= true;
                                        break;
                                    end
                                elseif qSelectSnapMenuOpen
                                    if isnan(requested) && strcmp(keys(qWhich),'+')
                                        % save current state to new
                                        % snapshot, don't close menu when
                                        % doing so
                                        qSaveSnapShot = true;
                                    elseif requested<=size(snapshots,1)
                                        % load another snapshot
                                        currentMenuSel          = requested;
                                        if currentSnapMenuItem~=currentMenuSel
                                            awaitingCalChangeType   = 'load';
                                            calLoadSource           = 'snapshot';
                                        end
                                        qToggleSelectSnapMenu   = true;
                                    end
                                    break;
                                end
                                break;
                            elseif any(ismember(lower(keys),{'kp_enter','return','enter'})) % lowercase versions of possible return key names (also include numpad's enter)
                                if qSelectEyeMenuOpen
                                    qSelectedEyeChanged = currentEyeMenuItem~=currentMenuSel;
                                    qToggleSelectEyeMenu= true;
                                elseif qSelectSnapMenuOpen
                                    if currentMenuSel==size(snapshots,1)+1
                                        % save current state to new
                                        % snapshot, don't close menu when
                                        % doing so
                                        qSaveSnapShot = true;
                                    else
                                        % load another snapshot
                                        if currentSnapMenuItem~=currentMenuSel
                                            awaitingCalChangeType   = 'load';
                                            calLoadSource           = 'snapshot';
                                        end
                                        qToggleSelectSnapMenu   = true;
                                    end
                                end
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
                                    if (qSelectEyeMenuOpen && currentMenuSel<3) || (qSelectSnapMenuOpen && currentMenuSel<=size(snapshots,1))   % NB: snapshots menu goes to number of snapshots+1
                                        currentMenuSel   = currentMenuSel+1;
                                        qChangeMenuArrow = true;
                                        break;
                                    end
                                end
                            end
                        else
                            if any(strcmpi(keys,'escape'))
                                if qDraggingHead || ~isnan(headResizingGrip)
                                    % cancel drag/resize of head display
                                    qDraggingHead       = false;
                                    headResizingGrip    = nan;
                                    headORect           = headOriRect;
                                    scaleFacs           = [RectWidth(headORect)/obj.scrInfo.resolution{2}(1) RectHeight(headORect)/obj.scrInfo.resolution{2}(2)];
                                    facO                = min(scaleFacs);
                                    refSzO              = ovalVSz*obj.scrInfo.resolution{2}(2)*facO;
                                    refPosO             = updateHeadDragResize(headORect,obj.scrInfo.resolution{2},facO,headO,refSzO,obj.settings.UI.setup.headCircleEdgeWidth);
                                    qUpdateCursors      = true;
                                    break;
                                elseif ~isempty(pointList) || ~isnan(whichPoint)
                                    qDoneSomething = false;
                                    % cancel all queued points
                                    for p=1:length(pointList)
                                        % reset to previous state
                                        pointsP(pointList(p),end) = pointsP(pointList(p),end-1);
                                        qDoneSomething = true;
                                    end
                                    % clear list of enqueued points
                                    pointList = [];
                                    
                                    % if currently showing point but not
                                    % yet trying to collect, cancel as well
                                    if ~isnan(whichPoint) && pointsP(whichPoint,end)==2
                                        qCancelPointCollect = true;
                                    end
                                    if qDoneSomething
                                        qUpdatePointHover = true;
                                        break;
                                    end
                                end
                            elseif any(ismember(num2cell(keys),{'1','2','3','4','5','6','7','8','9'}))    % key 1 is '1!', for instance, so check if 1 is contained instead if strcmp
                                % calibration/validation point
                                qWhich      = ismember(num2cell(keys),{'1','2','3','4','5','6','7','8','9'});
                                requested   = str2double(keys(qWhich));
                                if requested<=size(pointsP,1)
                                    if shiftIsDown
                                        qDoneSomething = false;
                                        % if clicked point is enqueued, cancel
                                        % it
                                        qInList = pointList==requested;
                                        if any(qInList)
                                            % reset to previous state
                                            pointsP(qInList,end) = pointsP(qInList,end-1);
                                            qDoneSomething = true;
                                            % clear from list of enqueued points
                                            pointList(qInList) = []; %#ok<AGROW>
                                        end
                                        
                                        % if currently showing point but not
                                        % yet trying to collect, cancel as well
                                        if ~isnan(whichPoint) && whichPoint==requested && pointsP(whichPoint,end)==2
                                            qCancelPointCollect = true;
                                        end
                                        
                                        % if point already collected, enqueue a
                                        % discard for it
                                        if pointsP(requested,end)==1
                                            discardList = [discardList requested]; %#ok<AGROW>
                                            qDoneSomething = true;
                                        end
                                        if qDoneSomething
                                            qUpdatePointHover = true;
                                            break;
                                        end
                                    elseif ~ismember(pointsP(requested,end),[2 3 4])
                                        % point is not in enqueued,
                                        % displaying or collecting status:
                                        % enqueue
                                        pointList(1,end+1)      = requested; %#ok<AGROW>
                                        pointsP(requested,end)  = 4; % status: enqueued
                                        qUpdatePointHover       = true;
                                        break;
                                    end
                                end
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.continue.accelerator)) && ~shiftIsDown
                                status = 1;
                                qDoneWithManualCalib= true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.changeeye.accelerator)) && qCanDoMonocularCalib && ~shiftIsDown
                                qToggleSelectEyeMenu= true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.toggEyeIm.accelerator)) && qHasEyeIm && ~shiftIsDown
                                qToggleEyeImage     = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.calval.accelerator)) && ~shiftIsDown
                                qToggleStage        = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.snapshot.accelerator)) && ~shiftIsDown
                                qToggleSelectSnapMenu = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.toggHead.accelerator))
                                qShowHead           = ~qShowHead;
                                qShowHeadToAll      = shiftIsDown;
                                qUpdateCursors      = true;
                                break;
                            elseif any(strcmpi(keys,obj.settings.UI.button.mancal.toggGaze.accelerator))
                                qShowGaze           = ~qShowGaze;
                                qShowGazeToAll      = shiftIsDown;
                                break;
                            end
                        end
                    end
                    % check if a point collections needs to be cancelled
                    if qCancelPointCollect && ~isnan(whichPoint)
                        frameMsg = sprintf('POINT OFF %d (%.0f %.0f), cancelled',whichPoint,pointsP(whichPoint,3:4));
                        if strcmp(stage,'cal')
                            out.attempt{kCal}.cal{calAction}.wasCancelled = true;
                        else
                            out.attempt{kCal}.val{valAction}.wasCancelled = true;
                        end
                        % reset to previous state
                        pointsP(whichPoint,end) = pointsP(whichPoint,end-1);
                        whichPoint = nan;
                        % reset calibration point drawer
                        % function
                        drawFunction(wpnt(1),'cleanUp',nan,nan,nan,nan);
                        % done, break from draw loop
                        qCancelPointCollect     = false;
                        qUpdatePointHover       = true;
                        break;
                    end
                    % check if hovering over point for which we have info,
                    % and no menus open
                    iIn = find(inRect(mousePos,calValRectsHover));
                    if ~isempty(iIn) && ~qSelectSnapMenuOpen && ~qSelectEyeMenuOpen
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
                    % if awaiting calibration status change, break out of
                    % draw loop to check for state change
                    if ~isempty(awaitingCalChangeType)
                        break;
                    end
                end
            end
            
            % return selected cal
            out.status      = status;
            out.selectedCal = [kCal getLastManualCal(out.attempt{kCal})];
            
            % clean up
            HideCursor;
            obj.buffer.stop('positioning');
            obj.buffer.stop('gaze');
            if qHasEyeOpenness
                obj.buffer.setIncludeEyeOpennessInGaze(prevEyeOpennessState);
            end
            obj.sendMessage('STOP MANUAL CALIBRATION ROUTINE');
            obj.buffer.clear('positioning');                % this one is not meant to be kept around (useless as it doesn't have time stamps). So just clear completely.
            if qHasEyeIm
                obj.buffer.stop('eyeImage');
                if any(eyeTexs)
                    Screen('Close',eyeTexs(eyeTexs>0));
                end
                % NB: buffer is cleared below by the ClearAllBuffers() call
            end
            if obj.buffer.hasStream('externalSignal')
                obj.buffer.stop('externalSignal');
            end
            
            out.allData   = obj.ConsumeAllData(startT);
            obj.StopRecordAll();
            obj.ClearAllBuffers(startT);                    % clean up data buffers
        end
        
        function status = drawValidationDataPlots(obj,wpnt,cal,selection,iVal)
            qHaveOperatorScreen = ~isscalar(wpnt);
            % get info about screen
            screenState = obj.getScreenInfo(wpnt);
            
            %%% prep data to plot:
            valData             = cal{selection}.val{iVal};
            qHasLeft            = isfield(valData.allData.gaze,'left');
            qHasRight           = isfield(valData.allData.gaze,'right');
            qHasEyeOpenness     = false;
            nValPoint           = size(valData.pointPos,1);
            % 1
            % 1) get all gaze data and turn into pixels on the screen,
            %    highlight data used for validation calculations
            % 2) get data for each validation point turn gaze data for each
            %    validation point into offsets from validation point
            plotData.all.t = valData.allData.gaze.systemTimeStamp;
            plotData.all.x = [];
            plotData.all.y = [];
            plotData.all.p = [];
            plotData.all.o = [];
            if qHasLeft
                plotData.all.x = valData.allData.gaze.left.gazePoint.onDisplayArea(1,:);
                plotData.all.y = valData.allData.gaze.left.gazePoint.onDisplayArea(2,:);
                plotData.all.p = valData.allData.gaze.left.pupil.diameter;
                if any(valData.allData.gaze.left.eyeOpenness.available)
                    plotData.all.o = valData.allData.gaze.left.eyeOpenness.diameter;
                    qHasEyeOpenness = true;
                end
            end
            if qHasRight
                plotData.all.x = [plotData.all.x; valData.allData.gaze.right.gazePoint.onDisplayArea(1,:)];
                plotData.all.y = [plotData.all.y; valData.allData.gaze.right.gazePoint.onDisplayArea(2,:)];
                plotData.all.p = [plotData.all.p; valData.allData.gaze.right.pupil.diameter];
                if any(valData.allData.gaze.right.eyeOpenness.available)
                    plotData.all.o = [plotData.all.o; valData.allData.gaze.right.eyeOpenness.diameter];
                    qHasEyeOpenness = true;
                end
            end
            plotData.all.x = plotData.all.x .* obj.scrInfo.resolution{1}(1);
            plotData.all.y = plotData.all.y .* obj.scrInfo.resolution{1}(2);
            % get Ts of validation points, make all time relative to t0, in
            % seconds
            plotData.pointIDs           = valData.pointPos(:,1);
            plotData.points             = bsxfun(@rdivide,valData.pointPos(:,2:3),obj.scrInfo.resolution{1});
            plotData.pointsTrackSpace   = valData.pointPos(:,4:5);
            qHaveTrackerSpacePos        = ~isempty(obj.settings.cal.pointPosTrackerSpace);
            plotData.all.pointTs        = valData.pointTs(:,2:3) - double(plotData.all.t(1))/1000/1000;          % time point on screen
            plotData.all.collectTs      = arrayfun(@(d) d.systemTimeStamp([1 end]),valData.gazeData,'uni',false);% time data collected for point
            plotData.all.collectTs      = double(cat(1,plotData.all.collectTs{:})-plotData.all.t(1))/1000/1000;
            plotData.all.t              = double(plotData.all.t-plotData.all.t(1))/1000/1000;
            % cut off last bit of all validation data that lies beyond last
            % bit used for offset computation
            qRem = plotData.all.t>plotData.all.collectTs(end,2);
            plotData.all.t(qRem)    = [];
            plotData.all.x(:,qRem)  = [];
            plotData.all.y(:,qRem)  = [];
            plotData.all.p(:,qRem)  = [];
            if qHasEyeOpenness
                plotData.all.o(:,qRem)  = [];
            end
            plotData.all.pointTs(end,2) = plotData.all.collectTs(end,2);
            
            % 2
            % get timestamps, make new fake time signal to glue data
            % together with only small gaps in between
            t0s     = arrayfun(@(d) d.systemTimeStamp( 1 )  ,valData.gazeData);
            tes     = arrayfun(@(d) d.systemTimeStamp(end)  ,valData.gazeData);
            dur     = tes-t0s;
            nSamp   = arrayfun(@(d) numel(d.systemTimeStamp),valData.gazeData);
            sampIdx = cumsum([1; nSamp]);
            plotData.off.t = cat(2,valData.gazeData.systemTimeStamp);
            plotData.off.collectTs = nan(nValPoint,2);
            gapDur = int64(mean(dur)*.15);  % 15% gap
            for v=1:nValPoint
                toff = -t0s(v) + sum([0; dur(1:v-1)]) + (v-1)*gapDur;
                plotData.off.t(sampIdx(v):sampIdx(v+1)-1) = plotData.off.t(sampIdx(v):sampIdx(v+1)-1)+toff;
                plotData.off.collectTs(v,:) = plotData.off.t([sampIdx(v) sampIdx(v+1)-1]);
            end
            plotData.off.t          = double(plotData.off.t)/1000/1000;         % time to seconds
            plotData.off.collectTs  = double(plotData.off.collectTs)/1000/1000;
            % get gaze data, turn into offsets from target
            plotData.off.x = [];
            plotData.off.y = [];
            plotData.off.p = [];
            plotData.off.o = [];
            if qHasLeft
                [angs1D,offOnScreenDir] = arrayfun(@(x,y) obj.getOffsetFromPoint(x.left,y{1}), valData.gazeData, num2cell(valData.pointPos(:,4:5),2), 'uni',false);
                temp    = cellfun(@(m,a) bsxfun(@times,m,[cos(a); sin(a)]),angs1D,offOnScreenDir,'uni',false);
                temp    = cat(2,temp{:});
                plotData.off.x = temp(1,:);
                plotData.off.y = temp(2,:);
                temp    = arrayfun(@(x) x.left.pupil.diameter, valData.gazeData, 'uni',false);
                plotData.off.p = cat(2,temp{:});
                if qHasEyeOpenness
                    temp    = arrayfun(@(x) x.left.eyeOpenness.diameter, valData.gazeData, 'uni',false);
                    plotData.off.o = cat(2,temp{:});
                end
            end
            if qHasRight
                [angs1D,offOnScreenDir] = arrayfun(@(x,y) obj.getOffsetFromPoint(x.right,y{1}), valData.gazeData, num2cell(valData.pointPos(:,4:5),2), 'uni',false);
                temp    = cellfun(@(m,a) bsxfun(@times,m,[cos(a); sin(a)]),angs1D,offOnScreenDir,'uni',false);
                temp    = cat(2,temp{:});
                plotData.off.x = [plotData.off.x; temp(1,:)];
                plotData.off.y = [plotData.off.y; temp(2,:)];
                temp    = arrayfun(@(x) x.right.pupil.diameter, valData.gazeData, 'uni',false);
                plotData.off.p = [plotData.off.p; cat(2,temp{:})];
                if qHasEyeOpenness
                    temp    = arrayfun(@(x) x.right.eyeOpenness.diameter, valData.gazeData, 'uni',false);
                    plotData.off.o = [plotData.off.o; cat(2,temp{:})];
                end
            end
            % add nan in data gaps
            fields = 'xyp';
            fieldsT= 'txyp';
            if qHasEyeOpenness
                fields = [fields  'o'];
                fieldsT= [fieldsT 'o'];
            end
            for f=fieldsT
                for v=nValPoint:-1:2
                    plotData.off.(f) = [plotData.off.(f)(:,1:sampIdx(v)-1) nan(size(plotData.off.(f),1),1) plotData.off.(f)(:,sampIdx(v):end)];
                end
            end
            
            %%% prep plots
            numPanel = 3;
            if qHasEyeOpenness
                numPanel = 4;
            end
            % get axis ticks
            % first get ranges of data
            for t={'all.t','all.x','all.y','all.p','all.o','off.t','off.x','off.y','off.p','off.o'; false,true,true,false,false,false,false,false,false,false}
                idxBase = structPathToIdx(t{1});
                if t{1}(end)=='o' && ~qHasEyeOpenness
                    continue;
                end
                idx     = structPathToIdx([t{1} '.data']);
                plotData= subsasgn(plotData,idxBase,struct('data',subsref(plotData,idxBase)));
                if t{2} % use screen dimensions instead of data range to set plot dimensions
                    lim = [0 obj.scrInfo.resolution{1}(idx(2).subs=='xy')];
                else
                    dat = subsref(plotData,idx);
                    lim = [mynanmin(dat(:),[]) mynanmax(dat(:),[])];
                end
                plotData = subsasgn(plotData,structPathToIdx([t{1} '.lim']), lim);
                if t{1}(end)~='t'
                    plotData = subsasgn(plotData,structPathToIdx([t{1} '.clr']), obj.getColorForWindow(obj.settings.UI.plot.eyeColors([qHasLeft qHasRight]),wpnt(end)));
                end
            end
            % for offset x and y, use same axis ranges
            plotData.off.x.lim(1) = min([plotData.off.x.lim(1) plotData.off.y.lim(1)]);
            plotData.off.x.lim(2) = max([plotData.off.x.lim(2) plotData.off.y.lim(2)]);
            plotData.off.y.lim    = plotData.off.x.lim([2 1]);  % negative if upward for y plots, flip lim to indicate
            plotData.all.y.lim    = plotData.all.y.lim([2 1]);  % negative if upward for y plots, flip lim to indicate
            
            % set text settings to those of the axis tick labels, to reduce
            % unnecessary changing of font properties to a minimum
            Screen('TextFont' ,wpnt(end),obj.settings.UI.plot.ax.tickLbl.font, obj.settings.UI.plot.ax.tickLbl.style);
            Screen('TextColor',wpnt(end),obj.settings.UI.plot.ax.tickLbl.color);
            Screen('TextSize' ,wpnt(end),obj.settings.UI.plot.ax.tickLbl.size);
            
            % determine tick values, and setup axis labels (draw to cache,
            % determine size)
            for t={'all.t','all.x','all.y','all.p','all.o','off.t','off.x','off.y','off.p','off.o'}
                tt=t{1};
                if tt(end)=='o' && ~qHasEyeOpenness
                    continue;
                end
                if strcmp(tt(1:3),'off') || tt(end)=='p' || tt(end)=='o'
                    fmt = '%.2f';
                else
                    fmt = '%.0f';
                end
                lim         = subsref(plotData,structPathToIdx([tt '.lim']));
                % make the ticks and store them in lookup table
                ticks       = getPlotTicks(lim);
                plotData    = subsasgn(plotData,structPathToIdx([tt '.ticks']), ticks);
                
                % get text, with formatting
                for q=length(ticks):-1:1
                    theText = sprintf(['<font=%s><size=%d>' fmt],obj.settings.UI.plot.ax.tickLbl.font,obj.settings.UI.plot.ax.tickLbl.size,ticks(q));
                    % get and store text cache
                    textCache = obj.getTextCache(wpnt(end),theText,[],'baseColor',obj.settings.UI.plot.ax.tickLbl.color);
                    where   = cat(2,structPathToIdx([tt '.ticksTextCache']), substruct('()',{q}));
                    plotData= subsasgn(plotData, where, textCache);
                end
            end
            % get axis labels
            % set text settings to those of the axis labels, to reduce
            % unnecessary changing of font properties to a minimum
            Screen('TextFont' ,wpnt(end),obj.settings.UI.plot.ax.axisLbl.font, obj.settings.UI.plot.ax.axisLbl.style);
            Screen('TextColor',wpnt(end),obj.settings.UI.plot.ax.axisLbl.color);
            Screen('TextSize' ,wpnt(end),obj.settings.UI.plot.ax.axisLbl.size);
            % now get the labels and their size
            for t={'all','off'}
                tt=t{1};
                if strcmp(tt,'all')
                    lbl = 'full';
                else
                    lbl = 'offset';
                end
                plotData.(tt).lbl.x = obj.getTextCache(wpnt(end),...
                    sprintf('<font=%s><size=%d>%s',obj.settings.UI.plot.ax.axisLbl.font,obj.settings.UI.plot.ax.axisLbl.size,obj.settings.UI.plot.ax.axisLbls.x),...
                    [],'baseColor',obj.settings.UI.plot.ax.axisLbl.color);
                for l=1:numPanel
                    plotData.(tt).lbl.y(l) = obj.getTextCache(wpnt(end),...
                        sprintf('<font=%s><size=%d>%s',obj.settings.UI.plot.ax.axisLbl.font,obj.settings.UI.plot.ax.axisLbl.size,obj.settings.UI.plot.ax.axisLbls.(lbl){l}),...
                        [],'xlayout','center','baseColor',obj.settings.UI.plot.ax.axisLbl.color, 'transform',{'rotate',-90});
                end
            end
            % get val lbls
            % set text settings to those of the validation ID labels, to
            % reduce unnecessary changing of font properties to a minimum
            Screen('TextFont' ,wpnt(end),obj.settings.UI.plot.ax.valLbl.font, obj.settings.UI.plot.ax.valLbl.style);
            Screen('TextColor',wpnt(end),obj.settings.UI.plot.ax.valLbl.color);
            Screen('TextSize' ,wpnt(end),obj.settings.UI.plot.ax.valLbl.size);
            for t={'all','off'}
                tt=t{1};
                if strcmp(tt,'all') && ~qHaveTrackerSpacePos
                    fmt = '%.0f,%0.f';
                    fac = obj.scrInfo.resolution{1};
                else
                    fmt = '%.2f,%.2f';
                    fac = [1 1];
                end
                for q=nValPoint:-1:1
                    plotData.(tt).lbl.val(q) = obj.getTextCache(wpnt(end),...
                        sprintf(['<font=%s><size=%d>%d @ (' fmt ')'],obj.settings.UI.plot.ax.valLbl.font,obj.settings.UI.plot.ax.valLbl.size,plotData.pointIDs(q),plotData.pointsTrackSpace(q,:).*fac),...
                        [],'baseColor',obj.settings.UI.plot.ax.valLbl.color);
                end
            end
            % get info text, if needed
            if qHaveTrackerSpacePos
                plotData.infoText = obj.getTextCache(wpnt(end),...
                    sprintf('<font=%s><size=%d>Shown gaze positions are in tracker space',obj.settings.UI.plot.ax.valLbl.font,obj.settings.UI.plot.ax.valLbl.size),...
                    [],'baseColor',obj.settings.UI.plot.ax.axisLbl.color);
            else
                plotData.infoText = [];
            end
            
            %%% layout the screen
            % make toggle button
            funs    = struct('textCacheGetter',@obj.getTextCache, 'textCacheDrawer', @obj.drawCachedText, 'cacheOffSetter', @obj.positionButtonText, 'colorGetter', @(clr) obj.getColorForWindow(clr,wpnt(end)));
            but(1)  = PTBButton(obj.settings.UI.plot.but.exit  , true, wpnt(end), funs, obj.settings.UI.button.margins);
            but(2)  = PTBButton(obj.settings.UI.plot.but.valSel, true, wpnt(end), funs, obj.settings.UI.button.margins);
            % position them
            yPosTop = .02*obj.scrInfo.resolution{end}(2);
            
            butSz       = but(1).rect(3)-but(1).rect(1);
            but(1).rect = OffsetRect(but(1).rect, -but(1).rect(1)+obj.scrInfo.resolution{end}(1)-5-butSz, yPosTop);
            butSz       = but(2).rect(3)-but(2).rect(1);
            but(2).rect = OffsetRect(but(2).rect, -but(2).rect(1)+but(1).rect(1)-15-butSz, yPosTop);
            
            butRects = cat(1,but.rect).';

            % position info text, if any, at same height as buttons
            if ~isempty(plotData.infoText)
                plotData.infoText = obj.repositionTextCache(plotData.infoText,[10-plotData.infoText.bbox(1) but(2).rect(2)-plotData.infoText.bbox(2)]);
            end
            
            % figure out where to put plots
            % total size occupied by panels
            scrUsed = obj.scrInfo.resolution{end} .* (1-sum(reshape(obj.settings.UI.plot.scrMargins,2,[])));
            margins = obj.scrInfo.resolution{end}([1 1 2 2]) .* obj.settings.UI.plot.scrMargins;
            % size of each panel, including y-labels, excluding x-label as
            % only under last panel
            panelPad        = obj.scrInfo.resolution{end}(2) * obj.settings.UI.plot.panelPad;
            panelSz         = [scrUsed(1) (scrUsed(2)-(numPanel-1)*panelPad)/numPanel];
            halfAxLineWidth = obj.settings.UI.plot.ax.lineWidth/2;
            
            % position axes
            for t={'all','off'}
                tt=t{1};
                % get which part of that is for the axes
                yTickTextRects                  = cat(1,cat(1,plotData.(tt).x.ticksTextCache.bbox),cat(1,plotData.(tt).y.ticksTextCache.bbox),cat(1,plotData.(tt).p.ticksTextCache.bbox));
                if qHasEyeOpenness
                    yTickTextRects                  = cat(1,yTickTextRects,cat(1,plotData.(tt).o.ticksTextCache.bbox));
                end
                yTickTextWidth                  = max(yTickTextRects(:,3)-yTickTextRects(:,1));
                yLblTextRects                   = cat(1,plotData.(tt).lbl.y.bbox);
                yLblTextWidths                  = yLblTextRects(:,3)-yLblTextRects(:,1);
                plotData.(tt).lbl.labelSpace(1) = halfAxLineWidth + obj.settings.UI.plot.ax.tickLbl.pad + yTickTextWidth  + obj.settings.UI.plot.ax.axisLbl.pad + max(yLblTextWidths);

                % position axes
                xspaceLeft = (obj.scrInfo.resolution{end}(1)-panelSz(1))/2+plotData.(tt).lbl.labelSpace(1);
                plotData.(tt).ax.rects = [...
                    xspaceLeft*ones(1,numPanel);
                    margins(3)+(0:numPanel-1)*(panelSz(2)+panelPad);
                    xspaceLeft*ones(1,numPanel)+panelSz(1)-plotData.(tt).lbl.labelSpace(1);
                    margins(3)+(0:numPanel-1)*(panelSz(2)+panelPad) + panelSz(2)
                    ];
            end
            % make sure axes have same position for both screens, so they
            % don't jump
            plotData.all.ax.rects(1:2,:) = max(plotData.all.ax.rects(1:2,:),plotData.off.ax.rects(1:2,:));
            plotData.all.ax.rects(3:4,:) = min(plotData.all.ax.rects(3:4,:),plotData.off.ax.rects(3:4,:));
            plotData.off.ax.rects = plotData.all.ax.rects;
            
            % position all other stuff
            for t={'all','off'}
                tt=t{1};
                % get which part of that is for the axes
                yTickTextRects                  = cat(1,cat(1,plotData.(tt).x.ticksTextCache.bbox),cat(1,plotData.(tt).y.ticksTextCache.bbox),cat(1,plotData.(tt).p.ticksTextCache.bbox));
                if qHasEyeOpenness
                    yTickTextRects                  = cat(1,yTickTextRects,cat(1,plotData.(tt).o.ticksTextCache.bbox));
                end
                yTickTextWidth                  = max(yTickTextRects(:,3)-yTickTextRects(:,1));
                yLblTextRects                   = cat(1,plotData.(tt).lbl.y.bbox);
                yLblTextWidths                  = yLblTextRects(:,3)-yLblTextRects(:,1);
                
                xTickTextRects                  = cat(1,plotData.(tt).t.ticksTextCache.bbox);
                xTickTextHeight                 = max(xTickTextRects(:,4)-xTickTextRects(:,2));
                plotData.(tt).lbl.labelSpace(2) = halfAxLineWidth + obj.settings.UI.plot.ax.tickLbl.pad + xTickTextHeight + obj.settings.UI.plot.ax.axisLbl.pad + plotData.(tt).lbl.x.bbox(4)-plotData.(tt).lbl.x.bbox(2);
                
                % prepare axis lines
                idxs = [1 1 1 3; 2 4 4 4];
                plotData.(tt).ax.lines = plotData.(tt).ax.rects([idxs idxs+4 idxs+8]);
                if qHasEyeOpenness
                    plotData.(tt).ax.lines = cat(2,plotData.(tt).ax.lines,plotData.(tt).ax.rects(idxs+12));
                end
                
                % make functions for converting data positions to pixel
                % positions in axis
                plotData.(tt).ax.dat2pix = cell(numPanel,1);
                for f=1:length(fields)
                    xLim    = plotData.(tt).     t     .lim;
                    yLim    = plotData.(tt).(fields(f)).lim;
                    plotData.(tt).ax.dat2pix{f} = @(x,y) dat2pix(x,y,xLim,yLim,plotData.(tt).ax.rects(:,f));
                end
                
                % prepare tick lines
                plotData.(tt).ax.tickLinesX = cell(numPanel,1);
                plotData.(tt).ax.tickLinesY = cell(numPanel,1);
                tickLength = obj.settings.UI.plot.ax.tickLength*obj.scrInfo.resolution{end}(2);
                for f=1:length(fields)
                    xt          = plotData.(tt).     t     .ticks;
                    yt          = plotData.(tt).(fields(f)).ticks;
                    xLim        = plotData.(tt).     t     .lim;
                    yLim        = plotData.(tt).(fields(f)).lim;
                    dat2pixfun  = plotData.(tt).ax.dat2pix{f};
                    
                    %%% x axis
                    % get on-axis part of tick line
                    startsX = dat2pixfun(xt,repmat(yLim(1),size(xt)));
                    % double up points for other end of each tick line
                    idxs = repmat(1:size(startsX,2),2,1);
                    startsX = startsX(1:2,idxs(:).');
                    % add offset to every second point to create end of tick lines
                    startsX(:,2:2:end) = bsxfun(@plus,startsX(:,2:2:end),[0 -tickLength].');
                    plotData.(tt).ax.tickLinesX{f} = startsX;
                    
                    %%% y axis
                    % get on-axis part of tick line
                    startsY = dat2pixfun(repmat(xLim(1),size(yt)),yt);
                    % double up points for other end of each tick line
                    idxs = repmat(1:size(startsY,2),2,1);
                    startsY = startsY(1:2,idxs(:).');
                    % add offset to every second point to create end of tick lines
                    startsY(:,2:2:end) = bsxfun(@plus,startsY(:,2:2:end),[tickLength 0].');
                    plotData.(tt).ax.tickLinesY{f} = startsY;
                end
                
                % position tick labels
                for f=fieldsT
                    if f=='t'
                        tickLines = plotData.(tt).ax.tickLinesX{end}(:,1:2:end);
                        ax = 'x';
                    else
                        tickLines = plotData.(tt).ax.tickLinesY{f=='xypo'}(:,1:2:end);
                        ax = 'y';
                    end
                    
                    %%% x axis
                    for r=1:length(plotData.(tt).(f).ticksTextCache)
                        [rx,ry] = RectCenterd(plotData.(tt).(f).ticksTextCache(r).bbox);
                        [rw,rh] = RectSize   (plotData.(tt).(f).ticksTextCache(r).bbox);
                        if ax=='x'
                            labelCent = [tickLines(1,r) tickLines(2,r)+halfAxLineWidth+obj.settings.UI.plot.ax.tickLbl.pad+rh/2];
                        else
                            labelCent = [tickLines(1,r)-halfAxLineWidth-obj.settings.UI.plot.ax.tickLbl.pad-rw/2 tickLines(2,r)];
                        end
                        off = labelCent-[rx ry];
                        plotData.(tt).(f).ticksTextCache(r) = obj.repositionTextCache(plotData.(tt).(f).ticksTextCache(r),off);
                    end
                end
                
                % position axis labels
                yLabelCent = [plotData.(tt).ax.rects(1,1) - halfAxLineWidth - obj.settings.UI.plot.ax.tickLbl.pad - yTickTextWidth - obj.settings.UI.plot.ax.axisLbl.pad - yLblTextWidths.'./2; (plotData.(tt).ax.rects(2,:)+plotData.(tt).ax.rects(4,:))./2];
                for p=1:length(yLblTextWidths)
                    [rx,ry] = RectCenterd(plotData.(tt).lbl.y(p).bbox);
                    off     = [yLabelCent(1,p)-rx yLabelCent(2,p)-ry];
                    plotData.(tt).lbl.y(p) = obj.repositionTextCache(plotData.(tt).lbl.y(p),off);
                end
                [rx,ry]     = RectCenterd(plotData.(tt).lbl.x.bbox);
                xLabelCent  = [(plotData.(tt).ax.rects(1,end)+plotData.(tt).ax.rects(3,end))./2; plotData.(tt).ax.rects(4,end)+plotData.(tt).lbl.labelSpace(2)-RectHeight(plotData.(tt).lbl.x.bbox)/2];
                off         = [xLabelCent(1)-rx xLabelCent(2)-ry];
                plotData.(tt).lbl.x = obj.repositionTextCache(plotData.(tt).lbl.x,off);
                
                % position validation labels
                for q=1:nValPoint
                    x       = mean(plotData.(tt).collectTs(q,:));
                    pos     = plotData.(tt).ax.dat2pix{1}(x,0); pos(3)=[];
                    pos(2)  = plotData.(tt).ax.rects(2,1)-obj.settings.UI.plot.ax.valLbl.pad-RectHeight(plotData.(tt).lbl.val(q).bbox)/2;
                    [rx,ry] = RectCenterd(plotData.(tt).lbl.val(q).bbox);
                    plotData.(tt).lbl.val(q) = obj.repositionTextCache(plotData.(tt).lbl.val(q),pos-[rx ry].');
                end
            end
            
            % prep background highlight indicating when validation data was
            % collected when plotting all
            plotData.all.ax.highLightRects = nan(4,nValPoint*numPanel);
            for q=1:nValPoint
                pos = plotData.all.ax.dat2pix{1}(plotData.all.collectTs(q,:),[0 0]);
                plotData.all.ax.highLightRects(1,(1:numPanel)+(q-1)*numPanel) = pos(1,1);
                plotData.all.ax.highLightRects(3,(1:numPanel)+(q-1)*numPanel) = pos(1,2);
            end
            for q=1:numPanel
                plotData.all.ax.highLightRects(2,q:numPanel:nValPoint*numPanel) = plotData.all.ax.rects(2,q);
                plotData.all.ax.highLightRects(4,q:numPanel:nValPoint*numPanel) = plotData.all.ax.rects(4,q);
            end
                    
            % prep line indicating dot position
            plotData.all.ax.dotPosLines = nan(2,nValPoint*2*2);
            for q=1:nValPoint
                for r=1:2
                    pos = plotData.all.ax.dat2pix{r}(plotData.all.pointTs(q,:),plotData.pointsTrackSpace(q,r).*[1 1].*obj.scrInfo.resolution{1}(r));
                    plotData.all.ax.dotPosLines(:,(q-1)*4+(r-1)*2+(1:2)) = pos(1:2,:);
                end
            end
            
            %%% plot loop
            % prep
            % set text settings to those of the axis tick labels, those
            % will get drawn the most, so having those as bases reduces
            % unnecessary changing of font properties to a minimum
            Screen('TextFont' ,wpnt(end),obj.settings.UI.plot.ax.tickLbl.font, obj.settings.UI.plot.ax.tickLbl.style);
            Screen('TextColor',wpnt(end),obj.settings.UI.plot.ax.tickLbl.color);
            Screen('TextSize' ,wpnt(end),obj.settings.UI.plot.ax.tickLbl.size);
            
            % setup cursors
            cursors.rect    = butRects;
            cursors.cursor  = repmat(obj.settings.UI.cursor.clickable,1,length(cursors.rect));  % clickable items
            cursors.other   = obj.settings.UI.cursor.normal;                                    % default
            cursors.qReset  = false;
            % NB: don't reset cursor to invisible here as it will then flicker every
            % time you click something. default behaviour is good here
            cursor = cursorUpdater(cursors);
            
            bgClrP          = obj.getColorForWindow(obj.settings.UI.plot.bgColor,wpnt(1));
            if qHaveOperatorScreen
                bgClrO      = obj.getColorForWindow(obj.settings.UI.plot.bgColor,wpnt(2));
            end
            axBgColor       = obj.getColorForWindow(obj.settings.UI.plot.ax.bgColor,wpnt(end));
            lineColor   	= obj.getColorForWindow(obj.settings.UI.plot.ax.lineColor,wpnt(end));
            dotPosLineColor = obj.getColorForWindow(obj.settings.UI.plot.dotPosLine.color,wpnt(end));
            highlightColor  = obj.getColorForWindow(obj.settings.UI.plot.ax.highlightColor,wpnt(end));
            plotWhich = 'off';
            % Refresh internal key-/mouseState to make sure we don't
            % trigger on already pressed buttons
            [mx,my] = obj.getNewMouseKeyPress(wpnt(end));
            status = 0;
            while true
                Screen('FillRect',wpnt(1),bgClrP);
                if qHaveOperatorScreen
                    Screen('FillRect',wpnt(end),bgClrO);
                end
                
                % draw axis backgrounds
                Screen('FillRect',wpnt(end),axBgColor,plotData.(plotWhich).ax.rects);
                
                if strcmp(plotWhich,'all')
                    % draw background highlight indicating when validation
                    % data was collected
                    Screen('FillRect',wpnt(end),highlightColor,plotData.all.ax.highLightRects);
                    
                    % draw line indicating dot position
                    Screen('DrawLines',wpnt(end),plotData.all.ax.dotPosLines,obj.settings.UI.plot.dotPosLine.width,dotPosLineColor,[],2);
                end
                
                % draw data
                obj.drawPlotData(wpnt,plotData,plotWhich,qHasEyeOpenness);
                
                % draw axes and ticks
                Screen('DrawLines',wpnt(end),plotData.(plotWhich).ax.lines               ,obj.settings.UI.plot.ax.lineWidth,lineColor,[],2);
                Screen('DrawLines',wpnt(end),cat(2,plotData.(plotWhich).ax.tickLinesX{:}),obj.settings.UI.plot.ax.lineWidth,lineColor,[],2);
                Screen('DrawLines',wpnt(end),cat(2,plotData.(plotWhich).ax.tickLinesY{:}),obj.settings.UI.plot.ax.lineWidth,lineColor,[],2);
                
                % draw labels
                obj.drawCachedText(plotData.(plotWhich).t.ticksTextCache);
                obj.drawCachedText(plotData.(plotWhich).x.ticksTextCache);
                obj.drawCachedText(plotData.(plotWhich).y.ticksTextCache);
                obj.drawCachedText(plotData.(plotWhich).p.ticksTextCache);
                if qHasEyeOpenness
                    obj.drawCachedText(plotData.(plotWhich).o.ticksTextCache);
                end
                obj.drawCachedText(plotData.(plotWhich).lbl.x);
                obj.drawCachedText(plotData.(plotWhich).lbl.y);
                obj.drawCachedText(plotData.(plotWhich).lbl.val);
                
                % draw buttons
                but(1).draw([mx my]);
                but(2).draw([mx my],strcmp(plotWhich,'all'));
                
                % draw info text, if any
                if ~isempty(plotData.infoText)
                    obj.drawCachedText(plotData.infoText);
                end
                
                % drawing done, show
                Screen('Flip',wpnt(1),[]);
                if qHaveOperatorScreen
                    Screen('Flip',wpnt(end),[],[],2);
                end
                
                % get user response
                [mx,my,buttons,keyCode,shiftIsDown] = obj.getNewMouseKeyPress(wpnt(end));
                % update cursor look if needed
                cursor.update(mx,my);
                if any(buttons)
                    % don't care which button for now. determine if clicked on either
                    % of the buttons
                    qIn = inRect([mx my],butRects);
                    if qIn(1)
                        break;
                    elseif qIn(2)
                        if strcmp(plotWhich,'off')
                            plotWhich = 'all';
                        else
                            plotWhich = 'off';
                        end
                    end
                elseif any(keyCode)
                    keys = KbName(keyCode);
                    
                    % these key combinations should always be available,
                    % and override anything the user has set
                    if any(strcmpi(keys,'escape')) && shiftIsDown
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

                    % user-defined accelerators
                    if any(strcmpi(keys,obj.settings.UI.plot.but.exit.accelerator))
                        break;
                    elseif any(strcmpi(keys,obj.settings.UI.plot.but.valSel.accelerator))
                        if strcmp(plotWhich,'off')
                            plotWhich = 'all';
                        else
                            plotWhich = 'off';
                        end
                    end
                end
            end
            
            % clean up and reset PTB state
            obj.resetScreen(wpnt,screenState);
        end
        
        function drawPlotData(obj,wpnt,plotData,plotWhich,qHasEyeOpenness)
            fields = 'xyp';
            if qHasEyeOpenness
                fields = [fields 'o'];
            end
            for f=1:length(fields)
                % get data on plot
                [xyo,axRect] = plotData.(plotWhich).ax.dat2pix{f}(plotData.(plotWhich).t.data,plotData.(plotWhich).(fields(f)).data);
                % double up internal points as they are both the end of one line
                % segment and the start of the next line segment
                idxs = repmat(2:size(xyo,2),2,1);
                xyo  = xyo(:,[1 idxs(:).' end],:);
                
                % deal with data that would be outside the axis. Instead, move point to
                % where line segment intersects the axis, so we show as much of the
                % data as possible
                for q=1:size(xyo,3)
                    i   = 1;
                    idx = find(xyo(3,i:end,q),1);
                    while idx
                        % get other part of line segment
                        idx  = idx+i-1;
                        idxs = idx+[0 -1+2*mod(idx,2)];
                        points = xyo(1:2,idxs,q);
                        % check if line segment crosses plot axis
                        if bitand(xyo(3,idxs(1),q),xyo(3,idxs(2),q))==0 && ...  % if none of the same bits are set, the line segment crosses the axis
                                all(~isnan(points(2,:)))                        % and if neither of the points is nan
                            % get which axis is intersected.
                            ax = nan(2,2,2);
                            if bitand(xyo(3,idx,q),1)         % left axis
                                ax(:,:,1) = axRect([1 1; 2 4]);
                            elseif bitand(xyo(3,idx,q),2)     % right axis
                                ax(:,:,1) = axRect([3 3; 2 4]);
                            end
                            if bitand(xyo(3,idx,q),4)         % bottom axis
                                ax(:,:,2) = axRect([1 3; 4 4]);
                            elseif bitand(xyo(3,idx,q),8)     % top axis
                                ax(:,:,2) = axRect([1 3; 2 2]);
                            end
                            
                            % calculate intersection point and place at idx
                            % adapted from http://stackoverflow.com/a/1968345/3103767
                            s1_x = diff(points(1,:));
                            s1_y = diff(points(2,:));
                            s2_x = squeeze(diff(ax(1,:,:),[],2));
                            s2_y = squeeze(diff(ax(2,:,:),[],2));
                            s = (-s1_y .* (points(1,1) - squeeze(ax(1,1,:))) + s1_x .* (points(2,1) - squeeze(ax(2,1,:)))) ./ (-s2_x .* s1_y + s1_x .* s2_y);
                            t = ( s2_x .* (points(2,1) - squeeze(ax(2,1,:))) - s2_y .* (points(1,1) - squeeze(ax(1,1,:)))) ./ (-s2_x .* s1_y + s1_x .* s2_y);
                            % if s and t in [0 1] we've got an intersection within the
                            % line segments. Use this to know which intersection point
                            % to use (in some edge cases there are two, of which only
                            % one is valid)
                            iIdx = find(s>=0&s<=1&t>=0&t<=1,1); % if intersecting exactly the axis corner, there will be two valid intersections, choose one (doesn't matter which one as they are the same)
                            if isempty(iIdx)
                                % data-line did not intersect axis (e.g. two points,
                                % one that is left of left axis and other that is below
                                % bottom axis) may not intersect the axis in all cases,
                                % can be too far left and too far below.
                                xyo(1:2,idx,q) = nan;
                            else
                                % next compute intersection coordinate
                                xInt = points(1,1) + (t(iIdx) .* s1_x);
                                yInt = points(2,1) + (t(iIdx) .* s1_y);
                                
                                % move point that is outside line further up the line segment
                                % so that it is exactly at the axis
                                xyo(1:2,idx,q) = [xInt yInt];
                            end
                        else
                            % can't do anything with this data point as the other part of
                            % the line segment is missing or also not on the plot, remove
                            % it
                            xyo(1:2,idx,q) = nan;
                        end
                        
                        % move forward in data
                        i   = idx+1;
                        idx = find(xyo(3,i:end,q),1);
                    end
                    
                    % deal with data points flanked by missing on both sides. we need
                    % to make these into very short lines so that they are still
                    % visible on the plot
                    [don,doff] = bool2bounds(~isnan(xyo(2,:,q)));
                    if any(doff-don+1<=2)
                        % since we double up data for plotting, an isolated point
                        % flanked by missing on both sides will show up as data length
                        % of 2 (unless at start or end of data, where it will be 1
                        % get where this happens, and change that line segment into a
                        % short line so that it is visible on the plot. remove the
                        % next line segment
                        % make line segment that is just as long as its wide
                        idxs = don(doff-don+1<=2);  % this always gets the end of a line segment
                        for l=1:length(idxs)
                            if idxs(l)==1
                                % special case: start of data
                                xyo(1:2,idxs(l)+[ 0 1],q) = [xyo(1,idxs(l))+[ 0 1]*obj.settings.UI.plot.lineWidth  ; xyo(2,idxs([l l]))];
                            elseif idxs(l)==size(xyo,2)
                                % special case: end of data
                                xyo(1:2,idxs(l)+[-1 0],q) = [xyo(1,idxs(l))+[-1 0]*obj.settings.UI.plot.lineWidth  ; xyo(2,idxs([l l]))];
                            else
                                xyo(1:2,idxs(l)+[-1 0],q) = [xyo(1,idxs(l))+[-1 1]*obj.settings.UI.plot.lineWidth/2; xyo(2,idxs([l l]))];
                                % remove next line segment
                                xyo(1:2,idxs(l)+1) = nan;
                            end
                        end
                    end
                    
                    Screen('DrawLines',wpnt(end),xyo(1:2,:,q),obj.settings.UI.plot.lineWidth,plotData.(plotWhich).(fields(f)).clr{q},[],2);
                end
            end
        end
        
        function [head,refPos] = setupHead(obj,wpnt,refSz,scrRes,fac,showYaw,isParticipantScreen)
            % create head and setup looks
            head                    = ETHead(wpnt,obj.geom.trackBox.halfWidth,obj.geom.trackBox.halfHeight);
            head.refSz              = refSz;
            head.rectWH             = scrRes*fac;
            head.headCircleFillClr  = obj.settings.UI.setup.headCircleFillClr;
            head.headCircleEdgeClr  = obj.settings.UI.setup.headCircleEdgeClr;
            head.headCircleEdgeWidth= obj.settings.UI.setup.headCircleEdgeWidth*fac;
            head.showYaw            = showYaw;
            head.showEyes           = obj.settings.UI.setup.showEyes;
            head.eyeClr             = obj.settings.UI.setup.eyeClr;
            head.eyeClrPosMissing   = obj.settings.UI.setup.eyeClrPosMissing;
            head.eyeBorderClr       = obj.settings.UI.setup.eyeBorderClr;
            head.eyeBorderWidth     = obj.settings.UI.setup.eyeBorderWidth;
            head.showEyeLids        = obj.settings.UI.setup.showEyeLids;
            head.eyeLidClr          = obj.settings.UI.setup.eyeLidClr;
            head.showPupils         = obj.settings.UI.setup.showPupils;
            head.pupilClr           = obj.settings.UI.setup.pupilClr;
            head.crossClr           = obj.settings.UI.setup.crossClr;
            head.crossEye           = (~obj.calibrateLeftEye)*1+(~obj.calibrateRightEye)*2; % will be 0, 1 or 2 (as we must calibrate at least one eye)
            
            % get reference position
            if isempty(obj.settings.UI.setup.referencePos)
                obj.settings.UI.setup.referencePos = [NaN NaN NaN];
            end
            head.referencePos       = obj.settings.UI.setup.referencePos;
            
            % position reference circle on screen
            refPos          = scrRes/2*fac;
            allPosOff       = [0 0];
            if isParticipantScreen && ~isnan(obj.settings.UI.setup.referencePos(1)) && any(obj.settings.UI.setup.referencePos(1:2)~=0)
                scrWidth        = obj.geom.displayArea.width/10;
                scrHeight       = obj.geom.displayArea.height/10;
                pixPerCm        = mean(scrRes./[scrWidth scrHeight])*[1 -1];   % flip Y because positive UCS is upward, should be downward for drawing on screen
                allPosOff       = obj.settings.UI.setup.referencePos(1:2).*pixPerCm*fac;
            end
            refPos          = refPos+allPosOff;
            head.allPosOff  = allPosOff;
        end
        
        function doEnterCalibrationMode(obj)
            qDoMonocular = ismember(obj.settings.calibrateEye,{'left','right'});
            if qDoMonocular
                assert(obj.hasCap('CanDoMonocularCalibration'),'You requested calibrating only the %s eye, but this %s does not support monocular calibrations. Set settings.calibrateEye to ''both''',obj.settings.calibrateEye,obj.settings.tracker);
            end
            obj.buffer.enterCalibrationMode(qDoMonocular);
            while true
                callResult  = obj.buffer.calibrationRetrieveResult();
                if ~isempty(callResult) && strcmp(callResult.workItem.action,'Enter')
                    if callResult.status==0
                        break;
                    else
                        error('Titta: error entering calibration mode: %s',callResult.statusString);
                    end
                end
                WaitSecs('YieldSecs',0.001);    % don't spin too hard
            end
        end
        
        function issuedLeave = doLeaveCalibrationMode(obj)
            issuedLeave = obj.buffer.leaveCalibrationMode();    % returns false if we never were in calibration mode to begin with
            while true && issuedLeave
                callResult  = obj.buffer.calibrationRetrieveResult();
                if ~isempty(callResult) && strcmp(callResult.workItem.action,'Exit')
                    if callResult.status==0
                        break;
                    else
                        error('Titta: error exiting calibration mode: %s',callResult.statusString);
                    end
                end
                WaitSecs('YieldSecs',0.001);    % don't spin too hard
            end
        end
        
        function loadOtherCal(obj,cal,calNo,skipCheck,alsoSwitchMode)
            if ~isempty(cal.cal.computedCal)    % empty when doing zero-point calibration. There is nothing to load or change then anyway, so is ok to skip. NB: rethink if user ever gains interface for changing number of calibration points
                obj.sendMessage(sprintf('LOAD CALIBRATION (%s), calibration no. %d',getEyeLbl(cal.eye),calNo));
                
                % first check we're in right calibration mode
                if nargin>4 && ~isempty(alsoSwitchMode) && alsoSwitchMode
                    % check that current calibration mode matches that
                    % of the calibration selected to be loaded.
                    % If not exit, calibration mode and reenter the
                    % correct one
                    if ~strcmp(cal.eye,obj.settings.calibrateEye)
                        % first change eye to be calibrated
                        obj.changeAndCheckCalibEyeMode(cal.eye);
                        obj.sendMessage(sprintf('CHANGE SETUP to %s',getEyeLbl(obj.settings.calibrateEye)));
                        % now also change mode in all cases (as this
                        % also wipes state clean, so also wanted when
                        % we remain monocular, but switch from left to
                        % right eye)
                        obj.doLeaveCalibrationMode();
                        obj.doEnterCalibrationMode();
                    end
                end
                
                % load previous calibration
                obj.buffer.calibrationApplyData(cal.cal.computedCal);
                
                if nargin>3 && ~isempty(skipCheck) && skipCheck
                    % return immediately
                    return
                end
                
                % wait for it to have loaded successfully
                while true
                    callResult  = obj.buffer.calibrationRetrieveResult();
                    if ~isempty(callResult) && strcmp(callResult.workItem.action,'ApplyCalibrationData')
                        if callResult.status==0
                            break;
                        else
                            error('Titta: error loading calibration: %s',callResult.statusString);
                        end
                    end
                    WaitSecs('YieldSecs',0.001);    % don't spin too hard
                end
            end
        end
        
        function logCalib(obj,out)
            % log to messages which calibration was selected
            if ~isnan(out.selectedCal)
                add = '';
                if out.wasSkipped
                    add = ' (note that operator skipped instead of accepted calibration)';
                end
                if strcmp(out.type,'manual')
                    if out.selectedCal(2)==0
                        calStr  = 'none';
                        add     = '';   % note not relevant (in case there is any) if no calibration
                    else
                        calStr = sprintf('attempt %d, cal %d',out.selectedCal);
                    end
                else
                    calStr = sprintf('no. %d',out.selectedCal);
                end
                str = sprintf('%s%s',calStr,add);
            else
                str = 'none';
            end
            obj.sendMessage(sprintf('CALIBRATION (%s) APPLIED: %s',getEyeLbl(obj.settings.calibrateEye),str));
            
            % store calibration info in calibration history, for later
            % retrieval if wanted
            if isempty(obj.calibrateHistory)
                obj.calibrateHistory{1} = out;
            else
                obj.calibrateHistory{end+1} = out;
            end
        end
        
        function [mx,my,mouse,key,shiftIsDown,mouseRelease,keyRelease] = getNewMouseKeyPress(obj,win)
            % function that only returns key depress state changes in the
            % down and up directions, not keys that are held down or
            % anything else
            % NB: before using this, make sure internal state is up to
            % date!
            if nargin<2
                win = [];
            end
            
            [~,~,keyCode]   = KbCheck();
            [mx,my,buttons] = GetMouse(win);
            if ~isempty(win)
                % check if panel fitter active, if so, map mouse position
                % to original stimulus image. Can't use RemapMouse and the
                % mod() operation in there doesn't play nice with multiple
                % screens
                p = Screen('PanelFitter', win);
                
                % Panelfitter active aka p non-zero?
                if any(p)
                    % Non-Zero rotation angle?
                    if p(9) ~= 0
                        % Yes, need some extra rotation inversion transforms:
                        xoff = p(5); yoff = p(6);
                        cx = p(10); cy = p(11);
                        angle = p(9);
                        
                        mx = mx - (xoff + cx);
                        my = my - (yoff + cy);
                        rot = atan2(my, mx) - (angle * pi / 180);
                        rad = norm([my, mx]);
                        mx = rad * cos(rot);
                        my = rad * sin(rot);
                        mx = mx + (xoff + cx);
                        my = my + (yoff + cy);
                    end
                    
                    % Invert scaling and offsets:
                    mx = ((mx - p(5)) / (p(7) - p(5)) * (p(3) - p(1))) + p(1);
                    my = ((my - p(6)) / (p(8) - p(6)) * (p(4) - p(2))) + p(2);
                end
            end
            
            % get only fresh mouse and key presses (so change from state
            % "up" to state "down")
            key         = keyCode & ~obj.keyState;
            mouse       = buttons & ~obj.mouseState;
            % check also for key or mouse button releases
            mouseRelease= ~buttons & obj.mouseState;
            keyRelease  = ~keyCode & obj.keyState;
            
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

function iValid = getCalsWithValidValidations(cal)
iValid = find(cellfun(@(x) isfield(x,'val') && any(cellfun(@(y) y.status, x.val)==1),cal));
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

function [texs,szs,poss,eyeImageRect] = UploadImages(image,texs,szs,poss,eyeImageRect,wpnt,canvasSize)
if isempty(image)
    return;
end
qHave = false(1,4);
for p=length(image.cameraID):-1:1
    % use cameraID and regionID to get index into our arrays
    % coding:
    % for camera, 0 is right, 1 is left
    % for region, 0 is right eye, 1 is left eye
    % 0: cameraID: 0, regionID: 0 -> right camera, right eye
    % 1: cameraID: 0, regionID: 1 -> right camera,  left eye
    % 2: cameraID: 1, regionID: 0 ->  left camera, right eye
    % 3: cameraID: 1, regionID: 1 ->  left camera,  left eye
    idx = image.regionID(p)+bitshift(image.cameraID(p),1)+1;      % add 1 as matlab indices are one-based
    
    % if we have already uploaded an image for this camera/region, skip
    % NB: we run from back to front over this array, and thus encounter
    % latest images first. Later encounters in this loop (earlier images)
    % should thus be skipped
    if qHave(idx)
        continue;
    end
    
    otherRegionIdx = bitxor(idx-1,1)+1; % flip regionID bit to get other region for same camera
    
    % if we have a full image (not cropped), for the camera from which it
    % was received we will: reset szs and poss, and dump any textures we
    % may have
    if strcmp(image.type{p},'TOBII_RESEARCH_EYE_IMAGE_TYPE_FULL')
        idxs = [idx otherRegionIdx];
        tex = texs(idxs);
        if any(tex)
            Screen('Close',tex(~~tex));
        end
        texs  (idxs)= 0;
        szs (:,idxs)= 0;
        poss(:,idxs)= 0;
    end
    
    % if we're here, we haven't encountered this image for this update
    % cycle yet. So upload it now
    w = image.width(p);
    h = image.height(p);
    if iscell(image.image)
        im = image.image{p};
    else
        im = image.image(:,p);
    end
    im = reshape(im,w,h).';
    texs (idx) = UploadImage(texs(idx),wpnt,im);
    qHave(idx) = true;
    szs(:,idx) = [w h].';
    poss(:,idx)= [image.regionLeft(p) image.regionTop(p)].';    % store position of eye image on sensor
    
    % update image rects
    % position eye image
    if any(poss(:,otherRegionIdx))
        % if we have a position for other region of same camera, update
        % position of both to center the constellation on the canvas
        minX    = min(poss(1,[idx otherRegionIdx]));
        rangeX  = max(poss(1,[idx otherRegionIdx])+szs(1,[idx otherRegionIdx]))-minX;
        minY    = min(poss(2,[idx otherRegionIdx]));
        rangeY  = max(poss(2,[idx otherRegionIdx])+szs(2,[idx otherRegionIdx]))-minY;
        for r=[idx otherRegionIdx]
            x = poss(1,r)-minX + (canvasSize(1)-rangeX)/2;
            y = poss(2,r)-minY + (canvasSize(2)-rangeY)/2;
            eyeImageRect(:,r) = [x y x+szs(1,r) y+szs(2,r)].';
        end
        % since leftmost on sensor is right eye (looking from other
        % perspective), flip image positions. We want the screen to be like
        % a mirror, with left eye displayed left of the right eye on both
        % canvasses
        eyeImageRect([1 3],[idx otherRegionIdx]) = fliplr(eyeImageRect([1 3],[idx otherRegionIdx]));
    else
        % if this is the only image, simply center it on canvas
        if isempty(canvasSize)
            % no canvas
            eyeImageRect(:,idx) = [0 0 w h].';
        else
            eyeImageRect(:,idx) = CenterRectOnPointd([0 0 w h],canvasSize(1)/2,canvasSize(2)/2);
        end
    end
    
    % if we have now found images for all, we don't have to continue
    % backwards into the array
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

function [headRects,headCursors] = getSelectionRects(headORect,margin,cursors)
headRects = repmat(headORect.',1,9);
% add resize handle points
rs = GrowRect(headORect,-margin,-margin);
rb = GrowRect(headORect, margin, margin);
%%% corners
% left-upper
headRects(:,1) = [rb(1) rb(2) rs(1) rs(2)];
% right-upper
headRects(:,2) = [rs(3) rb(2) rb(3) rs(2)];
% left-lower
headRects(:,3) = [rb(1) rs(4) rs(1) rb(4)];
% right-lower
headRects(:,4) = [rs(3) rs(4) rb(3) rb(4)];
%%% edges
% upper
headRects(:,5) = [rs(1) rb(2) rs(3) rs(2)];
% lower
headRects(:,6) = [rs(1) rs(4) rs(3) rb(4)];
% left
headRects(:,7) = [rb(1) rs(2) rs(1) rs(4)];
% right
headRects(:,8) = [rs(3) rs(2) rb(3) rs(4)];
% drag rect should be the smaller rect itself
headRects(:,9) = rs;
% corresponding cursors
headCursors = [cursors.sizetopleft cursors.sizetopright cursors.sizebottomleft cursors.sizebottomright ...
    cursors.sizetop cursors.sizebottom cursors.sizeleft cursors.sizeright ...
    cursors.normal];
end

function refPosO = updateHeadDragResize(headRect,scrRes,fac,headO,refSzO,headCircleEdgeWidth)
scaleFacs   = [RectWidth(headRect)/scrRes(1) RectHeight(headRect)/scrRes(2)];
if scaleFacs(1)<=scaleFacs(2)
    extraOff = (RectHeight(headRect)-scrRes(2)*scaleFacs(1))/2;
    headO.allPosOff = headRect(1:2)+[0 extraOff];
else
    extraOff = (RectWidth(headRect)-scrRes(1)*scaleFacs(2))/2;
    headO.allPosOff = headRect(1:2)+[extraOff 0];
end

refPosO         = scrRes/2*fac;
refPosO         = refPosO+headO.allPosOff;


headO.refSz     = refSzO;
headO.rectWH    = scrRes*fac;
headO.headCircleEdgeWidth = headCircleEdgeWidth*fac;
end

function whichCal = getLastManualCal(attempt)
% no valid calibration: denoted by cal==0
whichCal = 0;
if isfield(attempt,'cal')
    for c=length(attempt.cal):-1:1
        if isfield(attempt.cal{c},'computeResult') && ~isempty(attempt.cal{c}.computeResult.points)
            whichCal = c;
            break;
        end
    end
end
end

function pointIdxs = getWhichCalibrationPoints(allPointsNormPos,calResultPoints)
pointIdxs = [];
for p=1:length(calResultPoints)
    qPoint      = sum(abs(bsxfun(@minus,allPointsNormPos,calResultPoints(p).position(:).'))<0.0001,2)==2;
    assert(sum(qPoint)==1,'unknown or not unique calibration point: [%s]',num2str(calResultPoints(p).position(:).'));
    pointIdxs   = [pointIdxs find(qPoint)]; %#ok<AGROW>
end
end

function cals = collectCalsForSave(out,toSave,cPointsP)
kCal    = toSave(1);
whichCal= toSave(2);
idxs    = nan(1,size(cPointsP,1));
count   = 0;
% find cal actions for points
for c=whichCal:-1:1
    idx = out.attempt{kCal}.cal{c}.point(1);
    if isnan(idxs(idx)) && ~out.attempt{kCal}.cal{c}.wasCancelled && ~out.attempt{kCal}.cal{c}.wasDiscarded && ((isfield(out.attempt{kCal}.cal{c},'collectStatus') && out.attempt{kCal}.cal{c}.collectStatus.status==0) || (isfield(out.attempt{kCal}.cal{c},'discardStatus') && out.attempt{kCal}.cal{c}.discardStatus.status==0))
        idxs(idx)   = c;
        count       = count+1;
    end
end
% copy over in chronological order
fields = {'point','timestamp','wasCancelled','wasDiscarded','collectStatus','discardStatus'};
[~,i] = sort(idxs);
cals = cell(1,count);
for c=1:count
    for f=1:length(fields)
        if isfield(out.attempt{kCal}.cal{idxs(i(c))},fields{f})
            cals{c}.(fields{f}) = out.attempt{kCal}.cal{idxs(i(c))}.(fields{f});
        end
    end
end
% calibration data, etc
if count
    cals{end}.computeResult  = out.attempt{kCal}.cal{whichCal}.computeResult;
    cals{end}.computedCal    = out.attempt{kCal}.cal{whichCal}.computedCal;
end
end

function ticks = getPlotTicks(lim)
% This function and below helpers are ported and simplified from
% matplotlib.ticker's MaxNLocator with AutoLocator's default parameters
nbins       = 9;
steps       = [1, 2, 2.5, 5, 10];
threshold   = 100;

% swap input so its increasing, if needed
if lim(2)<lim(1)
    lim = lim([2 1]);
end

range = abs(lim(2) - lim(1));  % > 0 as nonsingular is called before.
meanv = mean(lim);
if (abs(meanv) / range) < threshold
    offset = 0;
else
    offset = (10 ^ floor(log10(abs(meanv)))) * sign(meanv);
end
scale   = 10 ^ floor(log10(range / nbins));

vmin     = lim(1) - offset;
vmax     = lim(2) - offset;
raw_step = (vmax - vmin) / nbins;
steps    = [steps(1:end-1)/10 steps 10*steps(2)] * scale;   % _extended_steps in python code

istep    = find(steps >= raw_step,1);

% This is an upper limit; move to smaller steps if necessary.
for istep=istep:-1:1
    step = steps(istep);
    best_vmin = floor(vmin / step) * step;
    
    % Find tick locations spanning the vmin-vmax range, taking into
    % account degradation of precision when there is a large offset.
    % The edge ticks beyond vmin and/or vmax are needed for the
    % "round_numbers" autolimit mode.
    low   = edge_le(step, offset, vmin - best_vmin);
    high  = edge_ge(step, offset, vmax - best_vmin);
    ticks = (low:high) * step + best_vmin;
    % Count only the ticks that will be displayed.
    nticks = sum((ticks <= vmax) & (ticks >= vmin));
    if nticks >= 2
        break
    end
end
ticks = ticks + offset;

% added by DN: trim the ticks that are outside the plot range, not needed
% for us
ticks(ticks<lim(1) | ticks>lim(2)) = [];
end

function v = edge_le(step, offset, x)
% Return the largest n: n*step <= x.
d = floor(x/step);
m = mod(x,step);
if closeto(step, offset, m / step, 1)
    v = d + 1;
else
    v = d;
end
end

function v = edge_ge(step, offset, x)
% Return the smallest n: n*step >= x.
d = floor(x/step);
m = mod(x,step);
if closeto(step, offset, m / step, 0)
    v = d;
else
    v = d + 1;
end
end

function close = closeto(step, offset, ms, edge)
% Allow more slop when the offset is large compared to the step.
if offset > 0
    digits = log10(offset / step);
    tol    = max(1e-10, 10 ^ (digits - 12));
    tol    = min(0.4999, tol);
else
    tol    = 1e-10;
end
close = abs(ms - edge) < tol;
end

function [xyo,axRect] = dat2pix(x,y,xlim,ylim,axRect)

if size(x,1)==1 && size(y,1)>1
    % spread additional data columns over third dimension
    x = repmat(x(:).',1,1,size(y,1));
    y = permute(y,[3 2 1]);
else
    % ensure row vectors
    x = x(:).';
    y = y(:).';
end

% check if axis flipped
qFlipX = xlim(2)<xlim(1);
if qFlipX
    xlim = xlim([2 1]);
end
qFlipY = ylim(2)<ylim(1);
if qFlipY
    ylim = ylim([2 1]);
end

% normalize data to limits
xyo = [(x-xlim(1))./(xlim(2)-xlim(1)); (y-ylim(1))./(ylim(2)-ylim(1)); zeros(size(x))];

% flip data if axis is flipped
if qFlipX
    xyo(1,:,:) = 1-xyo(1,:,:);
end
if qFlipY
    xyo(2,:,:) = 1-xyo(2,:,:);
end

% mark data points that are outside limits, so we can deal with those how
% we want. mark with bitflags as data can be both outside x and y axis
for p=1:size(xyo,3)
    xyo(3,xyo(1,:,p)<0,p) = 1;                          % outside of left y axis
    xyo(3,xyo(1,:,p)>1,p) = 2;                          % outside of right y axis
    xyo(3,xyo(2,:,p)<0,p) = xyo(3,xyo(2,:,p)<0,p)+4;    % outside of bottom x axis
    xyo(3,xyo(2,:,p)>1,p) = xyo(3,xyo(2,:,p)>1,p)+8;    % outside of top x axis
end

% place in axis rect
xyo(1,:,:) = xyo(1,:,:)*(axRect(3)-axRect(1))+axRect(1);
xyo(2,:,:) = xyo(2,:,:)*(axRect(2)-axRect(4))+axRect(4);    % note that y increases downward in pixels, so need to do reverse here: higher in plot is lower y
end
