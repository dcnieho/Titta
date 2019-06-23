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
|`calibrate()`|<ol><li>`wpnt`: window pointer to PsychToolbox screen where the calibration stimulus should be shown. See `PsychImaging('OpenWindow')` or `Screen('OpenWindow')`</li><li>`flag`: optional. Flag indicating whether this call to calibrate should cause the eye-tracker to enter before start calibration, or exit calibration mode when finished. The flag is a bitfield whose values can be bitand()ed together. Understood values: `1`: enter calibration mode when starting calibration; `2`: exit calibration mode when calibration finished. Default: `3`: both enter and exit calibration mode during this function call. Used for bimonocular calibrations, when the `calibrate()` function is called twice in a row, first to calibrate the first eye (use `flag=1` to enter calibration mode here but not exit), and then a second time to calibrate the other eye (use `flag=2` to exit calibration mode when done).</li></ol>|<ol><li>`calibrationAttempt`: struct containing information about the calibration/validation run</li></ol>|Do participant setup, calibration and validation|
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
|||


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
