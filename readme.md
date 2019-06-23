Titta is a toolbox for using eye trackers from Tobii Pro AB with MATLAB,
specifically offering integration with [PsychToolbox](http://psychtoolbox.org/). A Python version
that integrates with PsychoPy is also available from
https://github.com/marcus-nystrom/Titta. For a similar toolbox for SMI eye trackers, please see www.github.com/dcnieho/SMITE.

Cite as:
Niehorster, D.C., Andersson, R., & Nyström, M., (in prep). Titta: A
toolbox for creating Psychtoolbox and Psychopy experiments with Tobii eye
trackers.

For questions, bug reports or to check for updates, please visit
www.github.com/dcnieho/Titta. 

Titta is licensed under the Creative Commons Attribution 4.0 (CC BY 4.0) license, except the code and compiled libraries in the `./TobiiMatlabSDK` subfolder of this repository. Those files are copyright Tobii, please refer to the included EULA for their conditions.

`demos/readme.m` shows a minimal example of using the toolbox's
functionality.

To run the toolbox, the [Tobii Pro SDK](https://www.tobiipro.com/product-listing/tobii-pro-sdk/) must be installed. While older versions may work, the current version of Titta is tested against version 1.7 of the Tobii Pro SDK. An up-to-date version of PsychToolbox is recommended. Make sure PsychToolbox's GStreamer dependency is installed.

Tested on MATLAB R2015b & R2019a. Octave is currently not supported, but planned.
Currently the toolbox is only supported on Windows (tested on Windows 10 and Windows 7), Linux support is planned, and OSX support may appear if time and hardware availability permit. Given that OSX is not recommended for visual stimulus presentation, this however is low priority.

*Note* that this toolbox is in a beta state. The API may change drastically at any time without notice. Work is ongoing, and code may also be in a broken or untested state without warning.

## Contents
The toolbox consists of multiple parts:
### The `Titta` class
The Titta class is the main workhorse of this toolbox, providing a wrapper around the Tobii Pro SDK as well as the TobiiBuffer class described below, and a convenient GUI interface (rendered through PsychToolbox) for participant setup, calibration and validation.
### The `TobiiBuffer` class
The `TobiiBuffer` class is an alternative to the Tobii Pro MATLAB SDK for handling data streams and calibration, and can be used without making use of the Titta interface. It is used by Titta under the hood (accessed directly through `Titta.buffer`). It has two main features: (1) more complete an granular access to the data streams: (a): support for both consuming (destructive) and peeking (non-destructive) data streams; (b): support for only accessing or clearing specific parts of the tracker's data streams; and (c) data provided as structs-of-arrays instead of arrays-of-structs which makes data access significantly simpler and is much more memory efficient. The second main feature is (2) asynchronous calibration methods, allowing to issue non-blocking method calls for all stages of the calibration process, such that the interface can remain responsive.
### The `TalkToProLab` class
The `TalkToProLab` class provides an implementation of [Tobii Pro Lab](https://www.tobiipro.com/product-listing/tobii-pro-lab/)'s External Presenter interface, allowing experiments to be created and run from MATLAB+PsychToolbox, while recording, project management, recording playback/visualization and analysis can be performed in Tobii Pro Lab.

## Usage
As demonstrated in the demo scripts, the toolbox is configured through
the following interface:
1. Retrieve (default) settings for eye tracker of interest: `settings =
Titta.getDefaults('trackerName');` Supported tracker model names are `Tobii Pro Spectrum`,
`Tobii TX300`, `X2-60_Compact`, `Tobii Pro Nano`, and `IS4_Large_Peripheral` (the Tobii 4C eye tracker). (TODO: this list is currently incomplete, I have not yet tested other systems).
2. Change settings from their defaults if wanted (see [supported options](#supported-options) section below)
3. Create a Titta instance using this settings struct: `EThndl = Titta(settings);`

## API
### `Titta` class
#### Static methods
The below method can be called on a Titta instance or on the Titta class directly.

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|`getDefaults`|<ol><li>`tracker`: one of the supported eye tracker model names</li></ol>|<ol><li>`settings`: struct with all supported settings for a specific model of eyeTracker</li></ol>|Gets all supported settings with defaulted values for the indicated eyeTracker, can be modified and used for constructing an instance of Titta. See the [supported options](#supported-options) section below.|
|`getSystemTime`||<ol><li>`time`: An int64 scalar denoting Tobii and Psychtoolbox system time in microseconds</li></ol>|Gets the current system time using the PsychToolbox function `GetSecs()`, but provided in microseconds to match the system time provided by the Tobii Pro SDK.|
|`getValidationQualityMessage`|<ol><li>`cal`: a list of calibration attempts, or a specific calibration attempt</li><li>`kCal`: an (optional) index into the list of calibration attempts to indicate which to process</li></ol>|<ol><li>`message`: A tab-separated text rendering of the per-point and average validation data quality for each eye that was calibrated</li></ol>|Provides a textual rendering of data quality as assessed through a validation procedure.|

#### Construction
An instance of Titta is constructed by calling `Titta()` with either the name of a specific supported eye tracker model (in which case default settings for this model will be used) or with a settings struct retrieved from `Titta.getDefaults()`, possibly with changed settings (passing the settings struct unchanged is equivalent to using the eye tracker model name as input argument).

#### Methods
The following method calls are available on a Titta instance

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|`setDummyMode()`||<ol><li>`obj`: `TittaDummyMode` instance (output cannot be ignored)</li></ol>|Turn the current `Titta` instance into a dummy mode class.|
|`getOptions()`||<ol><li>`settings`: struct with current settings</li></ol>|Get active settings, returns only those that can be changed in the current state (which is a subset of all settings once `init()` has been called)|
|`setOptions()`|<ol><li>`settings`: struct with updated settings</li></ol>||Change active settings. First use `getOptions()` to get an up-to-date settings struct, then edit the wanted settings and use this function to set them|
|`init()`|||Connect to the Tobii eye tracker and initialize it according to the requested settings|
|`calibrate()`|<ol><li>`wpnt`: window pointer to PsychToolbox screen where the calibration stimulus should be shown. See `PsychImaging('OpenWindow')` or `Screen('OpenWindow')`</li><li>`flag`: optional. Flag indicating whether this call to calibrate should cause the eye-tracker to enter before start calibration, or exit calibration mode when finished. The flag is a bitfield whose values can be bitand()ed together. Understood values: `1`: enter calibration mode when starting calibration; `2`: exit calibration mode when calibration finished. Default: `3`: both enter and exit calibration mode during this function call. Used for bimonocular calibrations, when the `calibrate()` function is called twice in a row, first to calibrate the first eye (use `flag=1` to enter calibration mode here but not exit), and then a second time to calibrate the other eye (use `flag=2` to exit calibration mode when done).</li></ol>|<ol><li>`calibrationAttempt`: struct containing information about the calibration/validation run</li></ol>|Do participant setup, calibration and validation. During anywhere on the participant setup and calibration screens, the following three key combinations are available: <ol><li>`shift-escape`: hard exit from the calibration mode (causes en error to be thrown and script execution to stop if that error is not caught).</li><li>`shift-s`: skip calibration. If still at setup screen for the first time, the last calibration (perhaps of a previous session) remains active. To clear any calibration, enter the calibration screen and immediately then skip with this key combination.</li><li>`shift-d`: take screenshot, which will be stored to the current active directory (`cd`).</li></ol>|
|`sendMessage()`|<ol><li>`message`: Message to be written into idf file</li><li>`time`: (optional) timestamp of the message (in seconds, will be stored as microseconds). Candidate times are the timestamps provided by PsychToolbox, such as the timestamp returned by `Screen('Flip')` or keyboard functions such as `KbEventGet`.</li></ol>|<ol><li>`time`: timestamp (microseconds) stored with the message</li></ol>|Store timestamped message|
|`getMessages()`||<ol><li>`messages`: returns Nx2 cell array containing N timestamps (microseconds, first column) and the associated N messages (second column)</li></ol>|Get all the timestamped messages stored during the current session.|
|`collectSessionData()`||<ol><li>`data`: struct with all information and data collected during the current session. Contains information about all calibration attemps; all timestamped messages; eye-tracker system information; setup geometry and settings that are in effect; and log messages generated by the eye tracker; and any data in the buffers of any of the eye-tracker's data streams</li></ol>|Collects all data one may want to store to file, neatly organized.|
|`saveData()`|<ol><li>`filename`: filename (including path) where mat file will be stored</li><li>`doAppendVersion`: optional. Boolean indicating whether version numbers (`_1`, `_2`, etc) will automatically get appended to the filename if the destination file already exists</li></ol>||Save data returned by `collectSessionData()` directly to mat file at specified location|
|`deInit()`||<ol><li>`log`: struct of log messages generated by the eye tracker during the current session, if any.</li></ol>|Close connection to the eye tracker and clean up|


#### Properties
The following read-only properties are available for a Titta instance

|Property|description|
| --- | --- |
|`systemInfo`|Filled by `init()`. Struct with information about the eye tracker connected to, such as serial number.|
|`geom`|Filled by `init()`. Struct with information about the setup geometry known to the eye tracker, such as screen width and height, and the screen's location in the eye tracker's user coordinate system.|
|`calibrateHistory`|Returns cell array with information about all calibration attempts during the current session|
|`buffer`|Initialized by call to `init()`. Returns handle to [`TobiiBuffer`](#tobiibuffer-class) instance for interaction with the eye tracker's data streams.|
|`rawSDK`|Returns handle to Tobii SDK instance used by Titta (as constructed by calling `EyeTrackingOperations()` from the Tobii SDK)|
|`rawET`|Initialized by call to `init()`. Returns Tobii SDK handle to the connected eye tracker|

#### Supported options
Which of the below options are available depends on the eye tracker model. The `getDefaults()` and `getOptions()` method calls return the appropriate set of options for the indicated eye tracker.

| Option name | Explanation |
| --- | --- |
|`settings.trackingMode`|Some trackers, like the Spectrum with firmware version >=1.7.6, have multiple tracking modes, select tracking mode by providing its name.|
|`settings.freq`|Sampling frequency|
|`settings.calibrateEye`|Which eye to calibrate: 'both', also possible if supported by eye tracker: 'left' and 'right'.|
|`settings.serialNumber`|If looking to connect to a specific eye tracker when multiple are available on the network, provide its serial number here.|
|`settings.licenseFile`|If you tracker needs a license file applied (e.g. Tobii 4C), provide the full path to the license file here, or a cell array of full paths if there are multiple licenses to apply.|
|`settings.nTryReConnect`|How many times to retry connecting before giving up? Something larger than zero is good as it may take more time than the first call to find_all_eyetrackers for network eye trackers to be found.|
|`settings.connectRetryWait`|Seconds: time to wait between connection retries.|
|`settings.debugMode`|Only for Titta developer use.|
|  |  |
|`settings.cal.pointPos`|Nx2 matrix of screen positions ([0,1] range) of calibration points, leave empty to do a zero-point calibration, i.e., use the tracker's default calibration.|
|`settings.cal.autoPace`|0: manually confirm each calibration point. 1: only manually confirm the first point, the rest will be autoaccepted. 2: all calibration points will be auto-accepted. Applies also to validation points since calibration and validation points are shown as one continuous stream.|
|`settings.cal.paceDuration`|Minimum duration (s) that each calibration point is shown.|
|`settings.cal.doRandomPointOrder`|If true, the calibration points are shown in random order. If false, each row in `settings.cal.pointPos` is worked through in order.|
|`settings.cal.bgColor`|RGB (0-255) background color for calibration/validation screen.|
|`settings.cal.fixBackSize`|Size (pixels) of large circle in fixation cross.|
|`settings.cal.fixFrontSize`|Size (pixels) of small circle in fixation cross.|
|`settings.cal.fixBackColor`|Color (RGB, 0-255) of large circle in fixation cross.|
|`settings.cal.fixFrontColor`|Color (RGB, 0-255) of small circle in fixation cross.|
|`settings.cal.drawFunction`|Function to be called to draw calibration screen. See the `AnimatedCalibrationDisplay` class packaged with Titta for an example.|
|`settings.cal.doRecordEyeImages`|If true, eye images are recorded during calibration and validation, if supported by the eye tracker.|
|`settings.cal.doRecordExtSignal`|If true, external signals are recorded during calibration and validation, if supported by the eye tracker.|
|  |  |
|`settings.val.pointPos`|Nx2 matrix of screen positions ([0,1] range) of validation points.|
|`settings.val.paceDuration`|Minimum duration (s) that each validation point is shown.|
|`settings.val.collectDuration`|Amount of validation data (seconds) to collect for each validation point|
|`settings.val.doRandomPointOrder`|If true, the calibration points are shown in random order. If false, each row in `settings.val.pointPos` is worked through in order|
|  |  |
|`settings.UI.startScreen`|0: skip head positioning, go straight to calibration; 1: start with head positioning interface.|
|`settings.UI.setup.showEyes`|Show eyes on disk representing head used for head position visualization?|
|`settings.UI.setup.showPupils`|Show pupils in the eyes?|
|`settings.UI.setup.referencePos`|Location of head in trackbox for which head circle exactly overlaps reference circle in the head positioning visualization. [x y z] in cm. If empty, default: middle of trackbox|
|`settings.UI.setup.doCenterRefPos`|if true, reference circle is always at center of screen, regardless of x- and y-components of `settings.UI.setup.referencePos`. If false, circle is positioned `settings.UI.setup.referencePos(1)` cm horizontally and `settings.UI.setup.referencePos(2)` cm vertically from the center of the screen (assuming screen dimensions were correctly set in Tobii Eye Tracker Manager).|
|`settings.UI.setup.bgColor`|RGB (0-255) background color for setup screen.|
|`settings.UI.setup.refCircleClr`|Color of reference circle for head position visualization.|
|`settings.UI.setup.headCircleEdgeClr`|Color of egde of disk representing head used for head position visualization.|
|`settings.UI.setup.headCircleFillClr`|Color of fill of disk representing head used for head position visualization.|
|`settings.UI.setup.eyeClr`|Color of eyes in head.|
|`settings.UI.setup.pupilClr`|Color of pupils in eyes.|
|`settings.UI.setup.crossClr`|Color of cross taking position of ignored eye when doing monocular calibration.|
|`settings.UI.setup.fixBackSize`|Size (pixels) of large circle in fixation cross.|
|`settings.UI.setup.fixFrontSize`|Size (pixels) of small circle in fixation cross.|
|`settings.UI.setup.fixBackColor`|Color (RGB, 0-255) of large circle in fixation cross.|
|`settings.UI.setup.fixFrontColor`|Color (RGB, 0-255) of small circle in fixation cross.|
|`settings.UI.setup.instruct.strFun`|Function handle to function producing positioning instruction string. This function should take six inputs: current head position `x`, `y`, and `z` as well as reference position `x`, `y` and `z`.|
|`settings.UI.setup.instruct.font`|See [Text options](#text-options).|
|`settings.UI.setup.instruct.size`|See [Text options](#text-options).|
|`settings.UI.setup.instruct.color`|See [Text options](#text-options).|
|`settings.UI.setup.instruct.style`|See [Text options](#text-options).|
|`settings.UI.setup.instruct.vSpacing`|See [Text options](#text-options).|
|||
|`settings.UI.button.margins`|For all interface buttons, internal margins around their text content.|
|`settings.UI.button.setup.text.font`|Setting for all buttons on the setup screen. See [Text options](#text-options).|
|`settings.UI.button.setup.text.size`|Setting for all buttons on the setup screen. See [Text options](#text-options).|
|`settings.UI.button.setup.text.style`|Setting for all buttons on the setup screen. See [Text options](#text-options).|
|`settings.UI.button.setup.eyeIm`|Toggle button for showing or hiding eye image (if eye tracker provides them). See [Button options](#button-options).|
|`settings.UI.button.setup.cal`|Button for starting a calibration. See [Button options](#button-options).|
|`settings.UI.button.setup.prevcal`|Button for going to the validation result screen, only available if there are previous successful calibrations. See [Button options](#button-options).|
|`settings.UI.button.val.text.font`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.text.size`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.text.style`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.recal`|Button for starting a new calibration. See [Button options](#button-options).|
|`settings.UI.button.val.reval`|Button for revalidating the currently selected calibration. See [Button options](#button-options).|
|`settings.UI.button.val.continue`|Button for confirming selection of calibration and returning from the calibration interface to user code. See [Button options](#button-options).|
|`settings.UI.button.val.selcal`|Toggle button to bring up or close a calibration selection menu. Only available if there multiple successful calibration are available. See [Button options](#button-options).|
|`settings.UI.button.val.setup`|Button for returning to the setup screen. See [Button options](#button-options).|
|`settings.UI.button.val.toggGaze`|Toggle button switching on/off an online visualization of current gaze location. See [Button options](#button-options).|
|`settings.UI.button.val.toggCal`|Toggle button for switching between showing the validation output and the calibration output on the validation result screen. See [Button options](#button-options).|
|||
|`settings.UI.cal.errMsg.string`|String to display when the Tobii calibration functions inform that calibration was unsuccessful.|
|`settings.UI.cal.errMsg.font`|See [Text options](#text-options).|
|`settings.UI.cal.errMsg.size`|See [Text options](#text-options).|
|`settings.UI.cal.errMsg.color`|See [Text options](#text-options).|
|`settings.UI.cal.errMsg.style`|See [Text options](#text-options).|
|`settings.UI.cal.errMsg.wrapAt`|See [Text options](#text-options).|
|||
|`settings.UI.val.eyeColors`|Colors to use for plotting the collected validation data for the left and right eye on the validation result screen. Provide as a two-element cell array, `{leftEyeColor,rightEyeColor}`, where each color is RGB (0-255).|
|`settings.UI.val.bgColor`|RGB (0-255) background color for validation result screen.|
|`settings.UI.val.fixBackSize`|Size (pixels) of large circle in fixation crosses denoting the validation point positions.|
|`settings.UI.val.fixFrontSize`|Size (pixels) of small circle in fixation cross denoting the validation point positions.|
|`settings.UI.val.fixBackColor`|Color (RGB, 0-255) of large circle in fixation cross denoting the validation point positions.|
|`settings.UI.val.fixFrontColor`|Color (RGB, 0-255) of small circle in fixation cross denoting the validation point positions.|
|`settings.UI.val.onlineGaze.eyeColors`|Colors to use for displaying online gaze location of the left and right eye. For format, see `settings.UI.val.eyeColors`.|
|`settings.UI.val.onlineGaze.fixBackSize`|Size (pixels) of large circle in fixation crosses shown when online gaze display is active.|
|`settings.UI.val.onlineGaze.fixFrontSize`|Size (pixels) of small circle in fixation cross shown when online gaze display is active.|
|`settings.UI.val.onlineGaze.fixBackColor`|Color (RGB, 0-255) of large circle in fixation cross shown when online gaze display is active.|
|`settings.UI.val.onlineGaze.fixFrontColor`|Color (RGB, 0-255) of small circle in fixation cross shown when online gaze display is active.|
|`settings.UI.val.avg.text.font`|Font for rendering information about validation data quality averaged over the validation points. Should be a monospaced font.|
|`settings.UI.val.avg.text.size`|See [Text options](#text-options).|
|`settings.UI.val.avg.text.color`|See [Text options](#text-options).|
|`settings.UI.val.avg.text.eyeColors`|Colors to use for labeling data quality for the left and right eye. For format, see `settings.UI.val.eyeColors`.|
|`settings.UI.val.avg.text.style`|See [Text options](#text-options).|
|`settings.UI.val.avg.text.vSpacing`|See [Text options](#text-options).|
|`settings.UI.val.hover.bgColor`|RGB (0-255) background color for popup that appears when hovering over a validation point.|
|`settings.UI.val.hover.text.font`|Font for rendering information about validation data for a specific validation point in the hover popup. Should be a monospaced font.|
|`settings.UI.val.hover.text.size`|See [Text options](#text-options).|
|`settings.UI.val.hover.text.color`|See [Text options](#text-options).|
|`settings.UI.val.hover.text.eyeColors`|Colors to use for labeling data quality for the left and right eye. For format, see `settings.UI.val.eyeColors`.|
|`settings.UI.val.hover.text.style`|See [Text options](#text-options).|
|`settings.UI.val.menu.bgColor`|RGB (0-255) background color for calibration selection menu.|
|`settings.UI.val.menu.itemColor`|RGB (0-255) background color for non-selected items in the calibration menu.|
|`settings.UI.val.menu.itemColorActive`|RGB (0-255) background color for selected item in the calibration menu.|
|`settings.UI.val.menu.text.font`|Font for rendering information about a calibration in the calibration selection menu. Should be a monospaced font.|
|`settings.UI.val.menu.text.eyeColors`|Colors to use for labeling data quality for the left and right eye. For format, see `settings.UI.val.eyeColors`.|
|`settings.UI.val.menu.text.size`|See [Text options](#text-options).|
|`settings.UI.val.menu.text.color`|See [Text options](#text-options).|
|`settings.UI.val.menu.text.style`|See [Text options](#text-options).|

##### Text options
Texts take all or some of the below options

| Option name | Explanation |
| --- | --- |
|`font`|Font in which to render the string.|
|`size`|Text size at which to render the string.|
|`color`|Color in which to render the string.|
|`style`|Style with which to render the string. The following can ORed together: 0=normal, 1=bold, 2=italic, 4=underline, 8=outline, 32=condense, 64=extend.|
|`vSpacing`|Long strings will be wrapped such that each line is no longer than this many characters.|
|`wrapAt`|Vertical space between lines. 1 is normal spacing.|

##### Button options
Each button takes the below options

| Option name | Explanation |
| --- | --- |
|`accelerator`|Keyboard key to activate this buttton.|
|`visible`|If false, button will not be shown in the interface. The functionality remains accessible through the accelerator key (see `accelerator`).|
|`string`|Text to be show on the button.|
|`fillColor`|Fill color of the button: RGB (0-255).|
|`edgeColor`|Edge color of the button: RGB (0-255).|
|`textColor`|Color of the text on the button: RGB (0-255).|

The fields `string`, `fillColor`, `edgeColor` and `textColor` can be single entries, 2-element cell array or 3-element cell arrays. This is used to specify different looks for the button when in inactive state, hovered state, and activated state. If a single text or color is provided, this text/look applies to all three button states. If two are provided, the first text/color applies to both the inactive and hovered button states and the second to the activated state. If three are provided, they apply to the inactive, hovered and activated states, respectively. The `string`, `fillColor`, `edgeColor` and `textColor` can have these properties set independently from each other (you could thus provide different strings for the three states, while keeping colors constant over them).

### `TobiiBuffer` class
#### Static methods
The TobiiBuffer class does not have static methods.

#### Construction and initialization
An instance of TobiiBuffer is constructed by calling `TobiiBuffer()`. Before it becomes fully functional, its `init()` method should be called to provide it with the address of an eye tracker to connect to.

#### Methods
The following method calls are available on a TobiiBuffer instance

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|||||


### `TalkToProLab` class
#### Static methods
The below method can be called on a TalkToProLab instance or on the TalkToProLab class directly.

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|`makeAOITag`|<ol><li>`tagName`: The name of the tag</li><li>`groupName`: (optional) the name of the tag group the tag belongs to.</li></ol>|<ol><li>`tag`: The AOI tag.</li></ol>|Generates an AOI tag in the format expected by `TalkToProLab.attachAOIToImage()`.|

#### Construction
An instance of TalkToProLab is constructed by calling `TalkToProLab()` and provided the constructor with the name of the External Presenter project that should be opened in Pro Lab.

#### Methods
The following method calls are available on a TalkToProLab instance

|Call|inputs|outputs|description|
| --- | --- | --- | --- |
|||||


# Scratch space
`vcpkg install readerwriterqueue readerwriterqueue:x64-windows`
