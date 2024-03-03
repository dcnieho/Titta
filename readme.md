[![Downloads](https://static.pepy.tech/badge/tittapy)](https://pepy.tech/project/tittapy)
[![Citation Badge](https://img.shields.io/endpoint?url=https%3A%2F%2Fapi.juleskreuer.eu%2Fcitation-badge.php%3Fshield%26doi%3D10.3758%2Fs13428-020-01358-8&color=blue)](https://scholar.google.com/citations?view_op=view_citation&citation_for_view=uRUYoVgAAAAJ:J_g5lzvAfSwC)
[![DOI](https://zenodo.org/badge/DOI/10.3758/s13428-020-01358-8.svg)](https://doi.org/10.3758/s13428-020-01358-8)

Titta is a toolbox for using eye trackers from Tobii Pro AB with MATLAB or GNU Octave,
specifically offering integration with [PsychToolbox](http://psychtoolbox.org/). A Python version
that integrates with PsychoPy is also available from
https://github.com/marcus-nystrom/Titta. For a similar toolbox for SMI eye trackers, please see www.github.com/dcnieho/SMITE.

The current repository furthermore offers a C++ wrapper around the Tobii SDK, which is in turn used as a basis for the MEX file `TittaMex` providing MATLAB/Octave with connectivity to the Tobii eye trackers and `TittaPy` (`pip install TittaPy`) for providing Python 3 with the same. This C++ wrapper can be consumed by your own C++ projects as well, or be wrapped for other programming languages (pull requests welcome).

Please cite:
[Niehorster, D.C., Andersson, R. & Nyström, M. (2020). Titta: A toolbox for creating PsychToolbox and Psychopy experiments with Tobii eye trackers. Behavior Research Methods. doi: 10.3758/s13428-020-01358-8](https://doi.org/10.3758/s13428-020-01358-8)

For questions, bug reports or to check for updates, please visit
www.github.com/dcnieho/Titta. 

Titta is licensed under the Creative Commons Attribution 4.0 (CC BY 4.0) license. Note that the `tobii_research*.h` header files located in this repository at `SDK_wrapper/deps/include/` carry a different license, please refer to [the Tobii License Agreement](SDK_wrapper/deps/Tobii_Pro_SDLA_for_Research_Use.pdf) for more information.

`demos/readmeMinimal.m` shows a minimal example of using the toolbox's functionality, and the [demo_experiments](/demo_experiments) folder contains various other examples. For documentation of the various data fields in the `.mat` file produced by the demos, see [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html). Example fixation detection and AOI analysis code [is also included](/demo_analysis).

Ideally, make sure that the eye tracker is detected and works in the [Tobii Eye Tracker Manager](https://www.tobii.com/products/software/applications-and-developer-kits/tobii-pro-eye-tracker-manager) before trying to use it with Titta. Note also that some of the supported eye trackers require several setup steps before they are ready for use (e.g. do a display setup in Eye Tracker Manager). If these steps have not been performed, Titta will throw strange error messages.

To run the toolbox, the [Tobii Pro SDK](https://www.tobii.com/products/software/applications-and-developer-kits/tobii-pro-sdk) must be available. Titta for MATLAB and PsychToolbox includes the Tobii Pro SDK dynamic link libraries, so you do not have to install it separately. An up-to-date version of [PsychToolbox](http://psychtoolbox.org/) is recommended. 

Only the `Titta.calibrate()` and `Titta.calibrateAdvanced()` functions and optionally the `TalkToProLab` constructor use Psychtoolbox functionality, the rest of the toolbox can be used from MATLAB/Octave without having PsychToolbox installed.

## Supported platforms
Currently the toolbox is only supported on Windows 10 (Windows 7 may continue to work but is not tested) and Linux. OSX support may appear if time and hardware availability permit. Given that OSX is not recommended for visual stimulus presentation, this however is low priority.

Only 64-bit MATLAB and GNU Octave are supported. 32-bit MATLAB support was previously available for Windows, but has been discontinued when the Tobii SDK dropped support for 32-bit platforms. The last version of Titta supporting 32-bit Matlab is [available here](https://github.com/dcnieho/Titta/releases/tag/last_32bit_version).

### Windows
Using the newest Psychtoolbox version is recommended for use with both Matlab and GNU Octave. For use with Matlab, at minimum [PsychToolbox version 3.0.16 "Crowning achievement", released on 2020-05-10](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/PTB_Beta-2020-05-10_V3.0.16) is required. Titta has been tested on MATLAB version R2022b. To use Titta with GNU Octave at minimum Octave version 7.3 is required, which also entails at minimum [PsychToolbox version 3.0.19, "Virtuality", released on 2023-02-17](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/3.0.19.0). The main Titta class, TittaMex and the readme demos have been tested to work on Octave. The breakOut demo does not work due to incomplete classdef support in Octave.

### Linux
Using version [Psychtoolbox 3.0.18.7 release "Experimental Taylor expansion" SP2, released on 2022-04-20](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/3.0.18.7) or later is recommended, but at minimum [PsychToolbox version 3.0.16 "Crowning achievement", released on 2020-05-10](https://github.com/Psychtoolbox-3/Psychtoolbox-3/releases/tag/PTB_Beta-2020-05-10_V3.0.16) is required. Titta has been tested on MATLAB version R2022a. GNU Octave support has been tested with Octave versions 6.4 and 7.3. Titta for Linux is currently built on Ubuntu 22.04, which means it doesn not work out of the box on other Ubuntu releases. See [the TittaMex readme](/SDK_wrapper/README.md) for more information how to make it work on your platform.

### Mac OSX
OSX is currently not supported, although the TittaMex file does build succesfully on OSX with the [`makeTittaMex.m`](SDK_wrapper/makeTittaMex.m) script.

## How to acquire
The recommended way to acquire Titta is to use the `git` tool to download it. Alternatively you can download the components separately and place them in the right locations. Here are instructions for these two routes:
1. Using Git
    1. install git from https://git-scm.org if you don't already have it. If you do not
       like using the command line/terminal, consider using a graphical git tool such as
       [SmartGit](https://www.syntevo.com/smartgit/), which is available free for non-commercial use.
    1. Download Titta and its dependencies in one go using the following command:
       `git clone --recurse-submodules -j8 git://github.com/dcnieho/Titta.git`.
    1. Should this not work due to your git version being too old, try executing the
       following commands:
       ```
       git clone git://github.com/dcnieho/Titta.git`
       cd Titta
       git submodule update --init --recursive
       ```
       If you have already cloned Titta but do not have the MatlabWebSocket submodule populated yet,
       issuing the `git submodule update --init --recursive` command will take care of that.
1. Manual download:
    1. First download Titta and place it, unzipped if necessary, in your preferred folder.
    1. Then download MatlabWebSocket (available from https://github.com/jebej/MatlabWebSocket). Download the [currently tested version](https://github.com/jebej/MatlabWebSocket/tree/7454ab1564d3142a643a4d381f67206698abb8d6).
    1. Put the MatlabWebSocket directory inside Titta at the right location:
      `<tittaRootDir>/talkToProLab/MatlabWebSocket`).
1. When running on Windows, ensure you have the latest version of the [Microsoft Visual C++ Redistributable for Visual Studio 2015, 2017, 2019 and 2022](https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads) installed. This is the most likely cause of errors like "The specified module could not be found" when loading the TittaMex file.

## Contents
The toolbox consists of multiple parts:

### The `Titta` class
The Titta class is the main workhorse of this toolbox, providing a wrapper around the Tobii Pro SDK as well as the TittaMex class described below, and a convenient graphical user interface (rendered through PsychToolbox) for participant setup, calibration and validation. Only the `Titta.calibrate()` and `Titta.calibrateAdvanced()` participant setup and calibration interfaces require PsychToolbox.

### The `Titta`, `TittaMex` and `TittaPy` classes in the `SDK_wrapper` directory
[The `Titta` C++ class, the `TittaMex` MATLAB/Octave wrapper and the `TittaPy` Python wrapper](#titta-tittamex-tittapy-classes) are alternatives to the Tobii Pro MATLAB and Python SDKs for handling data streams and calibration, and can be used without making use of the Titta interface. The C++ code can be compiled and used as a static library without Matlab/Octave or Python. It is used by both the MATLAB and Python versions of Titta under the hood (Titta users can access it directly through the [`Titta.buffer` property](#properties)).

Besides providing access to the same tracker functionality as the Tobii Pro MATLAB SDK, it has two main features: (1) more complete and granular access to the data streams: (a): support for both consuming (destructive) and peeking (non-destructive) data streams; (b): support for only accessing or clearing specific parts of the tracker's data streams; and (c) data provided as structs-of-arrays instead of arrays-of-structs which makes data access significantly simpler and is much more memory efficient. The second main feature is (2) asynchronous calibration methods, allowing to issue non-blocking method calls for all stages of the calibration process, such that the interface can remain responsive. It furthermore offers GNU Octave support, which the MATLAB SDK has dropped since version 1.10, and provides eye openness data alongside data in the gaze stream instead of in a separate stream that the user then has to link up later themselves. Finally, other functions implemented in [`TittaMex`](#titta-tittamex-tittapy-classes) provide return values that are a bit friendlier to use in MATLAB/Octave, in the author's opinion (e.g. `double`s which are MATLAB's native data type instead of `single`s) and no use of MATLAB classes to just hold plain data.

On the Python side, besides the above benefits, use of the `Titta` C++ wrapper in [`TittaPy`](#titta-tittamex-tittapy-classes) prevents issues where data is lost with the Tobii Python SDK's callback-style interface if the user does not sleep or yield often enough in their code, and also provides data from the various streams as a dict-of-lists instead of a list-of-dicts, which in the author's opinion is easier to use, and is straightforwardly transformed to a `pandas.DataFrame`, or saved to an HDF5 file.

### The `TalkToProLab` class
The `TalkToProLab` class provides an implementation of [Tobii Pro Lab](https://www.tobiipro.com/product-listing/tobii-pro-lab/)'s External Presenter interface, allowing experiments to be created and run from MATLAB/Octave with PsychToolbox or other presentation methods, while recording, project management, recording playback/visualization and analysis can be performed in Tobii Pro Lab.

The `TalkToProLab` class must be able to communicate with the External Presenter interface of Pro Lab for it to operate. As such, to use the `TalkToProLab` class, do the following:
1) Open an External Presenter project in Tobii Pro Lab, make sure its name matches what you provide to the [`TalkToProLab` constructor](#construction-1).
2) Navigate to the 'record'-tab in Pro Lab
3) Make sure that the External presenter button is red and says 'not connected'
4) Run this script

## Usage
As demonstrated in the [demo scripts](demo_experiments), the toolbox is configured through
the following interface:
1. Retrieve (default) settings for eye tracker of interest: `settings =
Titta.getDefaults('tracker model name');` Supported eye trackers and their corresponding model names in the Tobii Pro SDK/Titta are:

    |Eye tracker|Model name|
    |---|---|
    |Tobii Pro Spectrum|`Tobii Pro Spectrum`|
    |Tobii Pro Fusion|`Tobii Pro Fusion`|
    |Tobii Pro TX300|`Tobii TX300`|
    |Tobii Pro T60 XL|`Tobii T60 XL`|
    |Tobii Pro Spark|`Tobii Pro Spark`|
    |Tobii Pro Nano|`Tobii Pro Nano`|
    |Tobii Pro X3-120|`Tobii Pro X3-120` or `Tobii Pro X3-120 EPU`|
    |Tobii Pro X2-60|`X2-60_Compact`|
    |Tobii Pro X2-30|`X2-30_Compact`|
    |Tobii Pro X60|`Tobii X60`|
    |Tobii Pro X120|`Tobii X120`|
    |Tobii Pro T60|`Tobii T60`|
    |Tobii Pro T120|`Tobii T120`|
    |Tobii 4C<sup>*</sup>|`IS4_Large_Peripheral`|
  
    Note that the VR eye trackers are not supported by Titta.
    
    <sup>*</sup>Note that a Pro upgrade license key is required to be able to use the Tobii 4C for research purposes, and for it to function with Titta. Unfortunately, the Pro upgrade license key is no longer sold by Tobii Pro. If you try to use a 4C without upgrade key with Titta, you will not receive data streams, and some calls, such as `calibrate()`, will yield `error 201: TOBII_RESEARCH_STATUS_SE_INSUFFICIENT_LICENSE`.
  
2. Change settings from their defaults if wanted (see [supported options](#supported-options) section below)
3. Create a Titta instance using this settings struct: `EThndl = Titta(settings);`
4. Interact with the eye tracker using the below API.
5. When calling `Titta.calibrate()`, a participant setup and calibration interface is shown. For each screen, several keyboard hotkeys are available to activate certain functionality. By default, the hotkey for each button is printed in the button's label. It can be configured to different keys with the `settings.UI.button` options [listed below](#supported-options). In addition, a few global hotkeys are available. These are documented below in the API documentation of the `Titta.calibrate()` method. A more advanced participant setup and calibration interface intended especially to enable work with non-cooperative subject populations such as infants and primates is provided by the `Titta.calibrateAdvanced()` function.
6. Example analysis scripts for the recorded data (fixation classification and AOI analysis) are [also provided](demo_analysis).

## API
### `Titta` class
Help on each of the below listed static methods, methods and properties can be had inside MATLAB by typing on the commands line `help Titta.<function name>`, e.g. `help Titta.calibrate`. Help on the constructor is had with `help Titta.Titta`.
#### Static methods
The below method can be called on a Titta instance or on the Titta class directly.

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`getDefaults()`|<ol><li>`tracker`: one of the supported eye tracker model names, [see above](#usage).</li></ol>|<ol><li>`settings`: struct with all supported settings for a specific model of eyeTracker</li></ol>|Gets all supported settings with defaulted values for the indicated eyeTracker, can be modified and used for constructing an instance of Titta. See the [supported options](#supported-options) section below.|
|`getFileName()`|<ol><li>`filename`: filename (including path) where mat file will be stored</li><li>`doAppendVersion`: optional. Boolean indicating whether version numbers (`_1`, `_2`, etc) will automatically get appended to the filename if the destination file already exists. Default: `false`.</li><li>`ext`: optional. Extension to use when checking if file exists. Default: 'mat'.</li><li>`ignoreSuffix`: optional. Ignore suffixes when checking if files with the provided filename exist. E.g. if `test` is provided as filename, and `test_gaze.parq` exists at the provided path, this will be considered a hit when the `_gaze` suffix is ignored. Default: `false`.</li><li>`addExt`: optional. Add the extension `ext` to the end of the output filename. May be unwanted when generating a base filename, such as when storing data to a series of Parquet files. Default: `true`.</li></ol>|<ol><li>`filename`: filename with versioning added where data file could be saved.</li></ol>|Get filename for saving data, with optional versioning.|
|`getTimeAsSystemTime()`|<ol><li>`time`: A PsychtoolBox timestamp that is to be converted to Tobii system time. Optional, if not provided, current GetSecs time is used.</li></ol>|<ol><li>`time`: An int64 scalar denoting Tobii system time in microseconds.</li></ol>|Maps the provided PsychtoolBox timestamp (or the current PsychtoolBox time provided by the `GetSecs()` function) to the Tobii system time provided in microseconds by the Tobii Pro SDK. On Windows, PsychtoolBox time and Tobii system time use the same clock, and this operation thus only entails a conversion from seconds to microseconds. On Linux, the clocks are different, and remapping is performed using the PTB function `GetSecs('AllClocks')` with an accuracy of 20 microseconds or better.|
|`getValidationQualityMessage()`|<ol><li>`cal`: a list of calibration attempts, a specific calibration attempt, or a specific validation data quality struct</li><li>`kCal`: an (optional) index into the list of calibration attempts to indicate which to process</li></ol>|<ol><li>`message`: A tab-separated text rendering of the per-point and average validation data quality for each eye that was calibrated</li></ol>|Provides a textual rendering of data quality as assessed through a validation procedure.|
|`saveData()`|<ol><li>`data`: data (struct) to be saved to a `.mat` file. Data would usually be what is returned by `Titta.collectSessionData()` but can be anything, and can optionally include extra metadata added by the user.</li><li>`filename`: filename (including path) where mat file will be stored</li><li>`doAppendVersion`: optional. Boolean indicating whether version numbers (`_1`, `_2`, etc) will automatically get appended to the filename if the destination file already exists. Default: `false`.</li></ol>|<ol><li>`filename`: filename at which the data was saved.</li></ol>|Save data returned by `Titta.collectSessionData()` directly to mat file at the specified location.|
|`saveDataToParquet()`|<ol><li>`data`: data (struct) to be saved to a series of Apache Parquet and JSON files. `data` is expected to contain the fields from `Titta.CollectSessionData()`. Extra user-added metadata is ignored, expect information about screen resolution if it is provided in either `data.resolution` or `data.expt.resolution`.</li><li>`filenameBase`: filename (including path) where the files will be stored.</li><li>`doAppendVersion`: optional. Boolean indicating whether version numbers (`_1`, `_2`, etc) will automatically get appended to the filenameBase if the destination files already exist. Default: `false`.</li></ol>|<ol><li>`filenameBase`: filename base at which the files were saved.</li></ol>|Save data returned by `Titta.collectSessionData()` to a series of Apache Parquet and JSON files at the specified location. Data from the various streams is written as tables into Parquet files, metadata and calibration info as JSON files.|
|`saveGazeDataToTSV()`|<ol><li>`data`: data (struct) from which gaze and messages are to be saved to `.tsv` files. `data` is expected to contain the fields from `Titta.CollectSessionData()`, and as such messages are expected at `data.messages`, and gaze data at `data.data.gaze`. Tab characters in the messages are replaced with `\t`.</li><li>`filenameBase`: filename (including path) where the files will be stored.</li><li>`doAppendVersion`: optional. Boolean indicating whether version numbers (`_1`, `_2`, etc) will automatically get appended to the filenameBase if the destination files already exist. Default: `false`.</li><li>`messageTruncateMode`: optional. Specify what happens with messages that consist of more than one line. By default (mode: `truncate`) only the first line of such messages is stored. Mode `replace` replaces newline characters with `\n`.</li></ol>|<ol><li>`filenameBase`: filename base at which the files were saved.</li></ol>|Save gaze data and messages returned by `Titta.collectSessionData()` to tsv files at the specified location.|

#### Construction
An instance of Titta is constructed by calling `Titta()` with either the name of a specific supported eye tracker model (in which case default settings for this model will be used) or with a settings struct retrieved from `Titta.getDefaults()`, possibly with changed settings (passing the settings struct unchanged is equivalent to using the eye tracker model name as input argument).

#### Methods
The following method calls are available on a Titta instance:

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`setDummyMode()`||<ol><li>`obj`: `TittaDummyMode` instance (output cannot be ignored)</li></ol>|Turn the current `Titta` instance into a dummy mode class.|
|`getOptions()`||<ol><li>`settings`: struct with current settings</li></ol>|Get active settings, returns only those that can be changed in the current state (which is a subset of all settings once `init()` has been called)|
|`setOptions()`|<ol><li>`settings`: struct with updated settings</li></ol>||Change active settings. First use `getOptions()` to get an up-to-date settings struct, then edit the wanted settings and use this function to set them|
|`init()`|<ol><li>`address`: optional. A specific eyetracker address</li></ol>||Connect to the Tobii eye tracker and initialize it according to the requested settings. If a specific eye tracker address is provided, this eye tracker is directly connected to.|
|`calibrate()`|<ol><li>`wpnt`: window pointer to PsychToolbox screen where the calibration stimulus should be shown. See `PsychImaging('OpenWindow')` or `Screen('OpenWindow')`. Can be an array of two window pointers. In this case, the first window pointer is taken to refer to the participant screen, and the second to an operator screen. In this case, a minimal interface is presented on the participant screen, while full information is shown on the operator screen, including a live view of gaze data and eye images (if available) during calibration and validation.</li><li>`flag`: optional. Flag indicating whether this call to calibrate should cause the eye-tracker to enter before start calibration, or exit calibration mode when finished. The flag is a bitfield whose values can be bitand()ed together. Understood values: `1`: enter calibration mode when starting calibration; `2`: exit calibration mode when calibration finished. Default: `3`: both enter and exit calibration mode during this function call. Used for bimonocular calibrations, when the `calibrate()` function is called twice in a row, first to calibrate the first eye (use `flag=1` to enter calibration mode here but not exit), and then a second time to calibrate the other eye (use `flag=2` to exit calibration mode when done).</li><li>`previousCalibs`: `calibrationAttempt` struct returned by a previous run of `Titta.calibrate()`. Allows to prepopulate the interface with previous calibration(s). The previously selected calibration is made active and it can then be revalidated and used, or replaced. Note that the `previousCalibs` functionality should be used together with bimonocular calibration _only_ when the calibration of the first eye is not replaced (validating it is ok, and recommended). This because prepopulating calibrations for the second eye will load this previous calibration, and thus undo any new calibration for the first eye.</li></ol>|<ol><li>`calibrationAttempt`: struct containing information about the calibration/validation run</li></ol>|Do participant setup, calibration and validation. Issue `help Titta.calibrate` on the matlab command prompt for further documentation.|
|`calibrateAdvanced()`|<ol><li>`wpnt`: an array of two window pointers to PsychToolbox screens where the calibration stimulus and operator interfaces should be shown. See `PsychImaging('OpenWindow')` or `Screen('OpenWindow')`. The first window pointer is taken to refer to the participant screen, and the second to an operator screen.</li><li>`previousCalibs`: `calibration` struct returned by a previous run of `Titta.calibrateAdvanced()`. Allows to prepopulate the interface with previous calibration(s). The previously selected calibration is made active and it can then be revalidated and used, or replaced.</li></ol>|<ol><li>`calibration`: struct containing information about the calibration/validation run</li></ol>|Do participant setup, calibration and validation using an advanced procedure suitable for non-compliant subjects. Issue `help Titta.calibrateAdvanced` on the matlab command prompt for further documentation.|
|`sendMessage()`|<ol><li>`message`: Message to be written into idf file</li><li>`time`: (optional) timestamp of the message (in seconds, will be stored as microseconds). Candidate times are the timestamps provided by PsychToolbox, such as the timestamp returned by `Screen('Flip')` or keyboard functions such as `KbEventGet`.</li></ol>|<ol><li>`time`: timestamp (microseconds) stored with the message</li></ol>|Store timestamped message|
|`getMessages()`||<ol><li>`messages`: returns Nx2 cell array containing N timestamps (microseconds, first column) and the associated N messages (second column)</li></ol>|Get all the timestamped messages stored during the current session.|
|`collectSessionData()`||<ol><li>`data`: struct with all information and data collected during the current session. Contains information about all calibration attemps; all timestamped messages; eye-tracker system information; setup geometry and settings that are in effect; and log messages generated by the eye tracker; and any data in the buffers of any of the eye-tracker's data streams</li></ol>|Collects all data one may want to store to file, neatly organized.|
|`deInit()`||<ol><li>`log`: struct of log messages generated by the eye tracker during the current session, if any.</li></ol>|Close connection to the eye tracker and clean up|


#### Properties
The following **read-only** properties are available for a Titta instance:

|Property|Description|
| --- | --- |
|`geom`|Filled by `init()`. Struct with information about the setup geometry known to the eye tracker, such as screen width and height, and the screen's location in the eye tracker's user coordinate system.|
|`calibrateHistory`|Returns cell array with information about all calibration attempts during the current session|
|`buffer`|Initialized by call to `init()`. Returns handle to [`TittaMex`](#titta-tittamex-tittapy-classes) instance for interaction with the eye tracker's data streams. This handle can furthermore be used for directly interacting with the eye tracker through the Tobii Pro SDK, but note that this is at your own risk. Titta should have minimal assumptions about eye-tracker state, but I cannot guarantee that direct interaction with the eye tracker does not interfere with later use of Titta in the same session.|
|`deviceName`|Get connected eye tracker's device name.|
|`serialNumber`|Get connected eye tracker's serial number.|
|`model`|Get connected eye tracker's model name.|
|`firmwareVersion`|Get connected eye tracker's firmware version.|
|`runtimeVersion`|Get connected eye tracker's runtime version.|
|`address`|Get connected eye tracker's address.|
|`capabilities`|Get connected eye tracker's exposed capabilities.|
|`supportedFrequencies`|Get connected eye tracker's supported sampling frequencies.|
|`supportedModes`|Get connected eye tracker's supported tracking modes.|
|`systemInfo`|Filled by `init()`. Struct with information about the eye tracker connected to: the device name, serial number, model name, firmware version, runtime version, address, sampling frequency, tracking mode, capabilities, supported sampling frequencies, and supported tracking modes of the connected eye tracker.|

The following **settable** properties are available for a Titta instance:

|Property|Description|
| --- | --- |
|`frequency`|Get or set connected eye tracker's sampling frequency.|
|`trackingMode`|Get or set connected eye tracker's tracking mode.|

#### Supported options
Which of the below options are available depends on the eye tracker model. The `getDefaults()` and `getOptions()` method calls return the appropriate set of options for the indicated eye tracker.

| Option name | Explanation |
| --- | --- |
|`settings.trackingMode`|Some trackers, like the Spectrum with firmware version>=1.7.6, have multiple tracking modes, select tracking mode by providing its name.|
|`settings.freq`|Sampling frequency|
|`settings.calibrateEye`|Which eye to calibrate: 'both', also possible if supported by eye tracker: 'left' and 'right'.|
|`settings.serialNumber`|If looking to connect to a specific eye tracker when multiple are available on the network, provide its serial number here.|
|`settings.licenseFile`|If you tracker needs a license file applied (e.g. Tobii 4C), provide the full path to the license file here, or a cell array of full paths if there are multiple licenses to apply.|
|`settings.nTryReConnect`|How many times to retry connecting before giving up? Something larger than zero is good as it may take more time than the first call to `TittaMex.findAllEyeTrackers()` for network eye trackers to be found.|
|`settings.connectRetryWait`|Seconds: time to wait between connection retries.|
|`settings.debugMode`|Only for Titta developer use. Prints some debug output to command window.|
|  |  |
|`settings.cal.pointPos`|Nx2 matrix of screen positions (`[0,1]` range) of calibration points, leave empty to do a zero-point calibration, i.e., use the tracker's default calibration.|
|`settings.cal.pointPosTrackerSpace`|Nx2 matrix of screen positions (`[0,1]` range) of calibration points to be sent to the Tobii SDK during calibration. Use when the screen shown to the participant does not match the plane to which the eye tracker is calibrated (e.g. because it is flipped because it is viewed through a mirror). Should be the same size as `settings.cal.pointPos`. See also `settings.val.pointPosTrackerSpace`.|
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
|`settings.cal.pointNotifyFunction`|If provided, this callback is called for each calibration point when collecting data for the point completes (either successfully or failed).|
|  |  |
|`settings.val.pointPos`|Nx2 matrix of screen positions ([0,1] range) of validation points.|
|`settings.val.pointPosTrackerSpace`|Nx2 matrix of screen positions ([0,1] range) of validation points in tracker space. Only needed when `settings.cal.pointPosTrackerSpace` is specified.|
|`settings.val.paceDuration`|Minimum duration (s) that each validation point is shown.|
|`settings.val.collectDuration`|Amount of validation data (seconds) to collect for each validation point.|
|`settings.val.doRandomPointOrder`|If true, the calibration points are shown in random order. If false, each row in `settings.val.pointPos` is worked through in order.|
|`settings.val.pointNotifyFunction`|If provided, this callback is called for each validation point when collecting gaze data for the point completes.|
|  |  |
|`settings.UI.startScreen`|0: skip head positioning, go straight to calibration; 1: start with head positioning interface.|
|`settings.UI.hardExitClosesPTB`|If `true` (default), pressing shift-escape in the calibration interface causes the PTB window to close.|
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
|`settings.UI.setup.showHeadToSubject`|If `true` (default), the reference circle and head display are shown on the participant monitor when showing setup display.|
|`settings.UI.setup.showInstructionToSubject`|If `true` (default), the instruction text is shown on the participant monitor when showing setup display.|
|`settings.UI.setup.showFixPointsToSubject`|If `true` (default), the fixation points in the corners of the screen are shown on the participant monitor when showing setup display.|
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
|`settings.UI.button.setup.eyeIm`|Toggle button for showing or hiding eye image (if eye tracker provides them). See [Button options](#button-options). Default hotkey: `e`.|
|`settings.UI.button.setup.cal`|Button for starting a calibration. See [Button options](#button-options). Default hotkey: `spacebar`.|
|`settings.UI.button.setup.prevcal`|Button for going to the validation result screen, only available if there are previous successful calibrations. See [Button options](#button-options). Default hotkey: `p`.|
|`settings.UI.button.val.text.font`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.text.size`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.text.style`|Setting for all buttons on the validation result screen. See [Text options](#text-options).|
|`settings.UI.button.val.recal`|Button for starting a new calibration. See [Button options](#button-options). Default hotkey: `escape`.|
|`settings.UI.button.val.reval`|Button for revalidating the currently selected calibration. See [Button options](#button-options). Default hotkey: `v`.|
|`settings.UI.button.val.continue`|Button for confirming selection of calibration and returning from the calibration interface to user code. See [Button options](#button-options). Default hotkey: `spacebar`.|
|`settings.UI.button.val.selcal`|Toggle button to bring up or close a calibration selection menu. Only available if there multiple successful calibration are available. See [Button options](#button-options). Default hotkey: `c`.|
|`settings.UI.button.val.setup`|Button for returning to the setup screen. See [Button options](#button-options). Default hotkey: `s`.|
|`settings.UI.button.val.toggGaze`|Toggle button switching on/off an online visualization of current gaze location. See [Button options](#button-options). Default hotkey: `g`. When in dual screen mode, by default the online gaze visualization is only shown on the operator screen. To also show it on the participant screen, hold down the `shift` key while pressing this hotkey.|
|`settings.UI.button.val.toggCal`|Toggle button for switching between showing the validation output and the calibration output on the validation result screen. See [Button options](#button-options). Default hotkey: `t`.|
|`settings.UI.button.val.toggSpace`|Toggle button for switching between showing the validation output and the calibration output on the validation result screen in screen space or in tracker space. Only available if a different tracker space was set up using the settings.cal.pointPosTrackSpace option. See [Button options](#button-options). Default hotkey: `x`.|
|`settings.UI.button.val.toggPlot`|Toggle button for switching between showing the validation result screen and a screen showing timeseries plots of the data collected during validation. See [Button options](#button-options). Default hotkey: `p`.|
|||
|`settings.UI.plot.bgColor`|RGB (0-255) background color for calibration/validation screen.|
|`settings.UI.plot.eyeColors`|Colors to use for plotting the collected validation data for the left and right eye on the validation result screen. Provide as a two-element cell array, `{leftEyeColor,rightEyeColor}`, where each color is RGB (0-255).|
|`settings.UI.plot.lineWidth`|Linewidth (pixels) used for plotting the data.|
|`settings.UI.plot.scrMargins`|Fraction of screen used as blank margin (`[left right top bottom]`) around the plot screen.|
|`settings.UI.plot.panelPad`|Vertical padding between the plot panels, expressed as fraction of screen.|
|`settings.UI.plot.dotPosLine.color`|RGB (0-255) color of lines showing fixation point position on the time series plots.|
|`settings.UI.plot.dotPosLine.width`|Linewidth (pixels) of lines showing fixation point position on the time series plots.|
|`settings.UI.plot.ax.bgColor`|RGB (0-255) background color for plot panels.|
|`settings.UI.plot.ax.lineColor`|RGB (0-255) background color for plot panel axis lines.|
|`settings.UI.plot.ax.lineWidth`|Linewidth (pixels) of plot panel axis lines.|
|`settings.UI.plot.ax.tickLength`|Length of plot ticks, expressed as fraction of screen.|
|`settings.UI.plot.ax.highlightColor`|RGB (0-255) or RGBA (including opacity) color for highlight on plot with context indicating which data recorded during validation was used for data quality calculations.|
|`settings.UI.plot.ax.axisLbls.x`|X-axis label.|
|`settings.UI.plot.ax.axisLbls.offset`|Y-axis labels for plots without context.|
|`settings.UI.plot.ax.axisLbl`|Text formatting options for axis labels, see [Text options](#text-options).|
|`settings.UI.plot.ax.tickLbl`|Text formatting options for tick label values, see [Text options](#text-options).|
|`settings.UI.plot.ax.valLbl`|Text formatting options for validation instance labels atop the plots, see [Text options](#text-options).|
|`settings.UI.plot.but.exit`|Button to exit the plot view and return to the validation result screen. See [Button options](#button-options). Default hotkey: `escape`.|
|`settings.UI.plot.but.valSel`|Toggle button for switching between showing just the data used for data quality calculations or all the data recorded during validation. See [Button options](#button-options). Default hotkey: `c`.|
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
|||
|`settings.UI.operator.setup`|A subset of the options in `settings.UI.setup` that controls the look of the operator screen when running in a two-screen setup.|
|`settings.UI.operator.cal`|A subset of the options in `settings.cal` that controls the look of the operator screen when running in a two-screen setup.|
|`settings.UI.operator.val`|A subset of the options in `settings.UI.val` that controls the look of the operator screen when running in a two-screen setup.|

##### Text options
Texts take all or some of the below options:

| Option name | Explanation |
| --- | --- |
|`font`|Font in which to render the string.|
|`size`|Text size at which to render the string.|
|`color`|Color in which to render the string.|
|`style`|Style with which to render the string. The following can ORed together: 0=normal, 1=bold, 2=italic, 4=underline, 8=outline, 32=condense, 64=extend.|
|`vSpacing`|Long strings will be wrapped such that each line is no longer than this many characters.|
|`wrapAt`|Vertical space between lines. 1 is normal spacing.|

##### Button options
Each button takes the below options:

| Option name | Explanation |
| --- | --- |
|`accelerator`|Keyboard key to activate this buttton.|
|`visible`|If false, button will not be shown in the interface. The functionality remains accessible through the accelerator key (see `accelerator`).|
|`string`|Text to be show on the button.|
|`fillColor`|Fill color of the button: RGB (0-255).|
|`edgeColor`|Edge color of the button: RGB (0-255).|
|`textColor`|Color of the text on the button: RGB (0-255).|

The fields `string`, `fillColor`, `edgeColor` and `textColor` can be single entries, 2-element cell array or 3-element cell arrays. This is used to specify different looks for the button when in inactive state, hovered state, and activated state. If a single text or color is provided, this text/look applies to all three button states. If two are provided, the first text/color applies to both the inactive and hovered button states and the second to the activated state. If three are provided, they apply to the inactive, hovered and activated states, respectively. The `string`, `fillColor`, `edgeColor` and `textColor` can have these properties set independently from each other (you could thus provide different strings for the three states, while keeping colors constant over them).

### `Titta`, `TittaMex`, `TittaPy` classes
The below documents the available functions and properties on a `Titta` SDK wrapper class. The functionality below is exposed under the same names in `TittaMex`. The same functionality is also available from a `TittaPy` instance, but in that case all function and property names as well as stream names use `snake_case` names instead of `camelCase`. Furthermore, static functions in the `Titta` class are found at the module level in `TittaPy`.

#### Static methods
|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`findAllEyeTrackers()`||<ol><li>`eyeTrackerList`: An array of structs with information about the connected eye trackers.</li></ol>|Gets the eye trackers that are connected to the system, as listed by the Tobii Pro SDK.|
|`getSDKVersion()`||<ol><li>`SDKVersion`: A string containing the version of the Tobii SDK.</li></ol>|Get the version of the Tobii Pro SDK dynamic library that is used by Titta.|
|`getSystemTimestamp()`||<ol><li>`timestamp`: An int64 scalar denoting Tobii system time in microseconds.</li></ol>|Get the current system time through the Tobii Pro SDK.|
|||||
|`startLogging()`|<ol><li>`initialBufferSize`: (optional) value indicating for how many event memory should be allocated</li></ol>|<ol><li>`success`: a boolean indicating whether logging was started successfully</li></ol>|Start listening to the eye tracker's log stream, store any events to buffer.|
|`getLog()`|<ol><li>`clearLogBuffer`: (optional) boolean indicating whether the log buffer should be cleared</li></ol>|<ol><li>`data`: struct containing all events in the log buffer, if available. If not available, an empty struct is returned.</li></ol>|Return and (optionally) remove log events from the buffer.|
|`stopLogging()`|||Stop listening to the eye tracker's log stream.|

#### Construction and initialization
An instance of Titta/TittaMex/TittaPy is constructed by calling `Titta()`, `TittaMex()` or `TittaPy()`. Before it becomes fully functional, its `init()` method should be called to provide it with the address of an eye tracker to connect to. A list of connected eye trackers is provided by calling the static function `Titta.findAllEyeTrackers()`.

#### Methods
The following method calls are available on a `Titta` instance:

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`init()`|<ol><li>`address`: address of the eye tracker to connect to</li></ol>||Connect the Titta class instance to the Tobii eye tracker and prepare it for use.|
|||||
|`getEyeTrackerInfo()`||<ol><li>`eyeTracker`: information about the eyeTracker that Titta is connected to.</li></ol>|Get information about the eye tracker that the Titta instance is connected to.|
|`getTrackBox()`||<ol><li>`trackBox`: track box of the connected eye tracker.</li></ol>|Get the track box of the connected eye tracker.|
|`getDisplayArea()`||<ol><li>`displayArea`: display area of the connected eye tracker.</li></ol>|Get the display area of the connected eye tracker.|
|`applyLicenses()`|<ol><li>`licenses`: a cell array of licenses (`char` of `uint8` representations of the license file read in binary mode).</li></ol>|<ol><li>`applyResults`: a cell array of strings indicating whether license(s) were successfully applied.</li></ol>|Apply license(s) to the connected eye tracker.|
|`clearLicenses()`|||Clear all licenses that may have been applied to the connected eye tracker. Refreshes the eye tracker's info, so use `getConnectedEyeTracker()` to check for any updated capabilities.|
|||||
|`hasStream()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li></ol>|<ol><li>`supported`: a boolean indicating whether the connected eye tracker supports providing data of the requested stream type.</li></ol>|Check whether the connected eye tracker supports providing a data stream of a specified type.|
|`setIncludeEyeOpennessInGaze()`|<ol><li>`include`: a boolean, indicating whether eye openness samples should be provided in the recorded gaze stream or not. Default false.</li></ol>|<ol><li>`previousState`: a boolean indicating the previous state of the include setting.</li></ol>|Set whether calls to start or stop the gaze stream should also start or stop the eye openness stream. An error will be raised if set to true, but the connected eye tracker does not provide an eye openness stream. If set to true, calls to start or stop the eyeOpenness stream will also start or stop the gaze stream.|
|`start()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li><li>`initialBufferSize`: (optional) value indicating for how many samples memory should be allocated</li><li>`asGif`: an (optional) boolean that is ignored unless the stream type is `eyeImage`. It indicates whether eye images should be provided gif-encoded (true) or a raw grayscale pixel data (false).</li></ol>|<ol><li>`success`: a boolean indicating whether streaming to buffer was started for the requested stream type</li></ol>|Start streaming data of a specified type to buffer. The default initial buffer size should cover about 30 minutes of recording gaze data at 600Hz, and longer for the other streams. Growth of the buffer should cause no performance impact at all as it happens on a separate thread. To be certain, you can indicate a buffer size that is sufficient for the number of samples that you expect to record. Note that all buffers are fully in-memory. As such, ensure that the computer has enough memory to satify your needs, or you risk a recording-destroying crash.|
|`isRecording()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li></ol>|<ol><li>`status`: a boolean indicating whether data of the indicated type is currently being streamed to buffer</li></ol>|Check if data of a specified type is being streamed to buffer.|
|`consumeN()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li><li>`N`: (optional) number of samples to consume from the start of the buffer. Defaults to all.</li><li>`side`: a string, possible values: `first` and `last`. Indicates from which side of the buffer to consume N samples. Default: `first`.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer, if available. If not available, an empty struct is returned.</li></ol>|Return and remove data of the specified type from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`consumeTimeRange()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync` and `notification`.</li><li>`startT`: (optional) timestamp indicating start of interval for which to return data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to return data. Defaults to end of buffer.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer in the indicated time range, if available. If not available, an empty struct is returned.</li></ol>|Return and remove data of the specified type from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`peekN()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li><li>`N`: (optional) number of samples to peek from the end of the buffer. Defaults to 1.</li><li>`side`: a string, possible values: `first` and `last`. Indicates from which side of the buffer to peek N samples. Default: `last`.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer, if available. If not available, an empty struct is returned.</li></ol>|Return but do not remove data of the specified type from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`peekTimeRange()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync` and `notification`.</li><li>`startT`: (optional) timestamp indicating start of interval for which to return data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to return data. Defaults to end of buffer.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer in the indicated time range, if available. If not available, an empty struct is returned.</li></ol>|Return but do not remove data of the specified type from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`clear()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li></ol>||Clear the buffer for data of the specified type.|
|`clearTimeRange()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync` and `notification`.</li><li>`startT`: (optional) timestamp indicating start of interval for which to clear data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to clear data. Defaults to end of buffer.</li></ol>||Clear data of the specified type within specified time range from the buffer.|
|`stop()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeOpenness`, `eyeImage`, `externalSignal`, `timeSync`, `positioning` and `notification`.</li><li>`doClearBuffer`: (optional) boolean indicating whether the buffer of the indicated stream type should be cleared</li></ol>|<ol><li>`success`: a boolean indicating whether streaming to buffer was stopped for the requested stream type</li></ol>|Stop streaming data of a specified type to buffer.|
|||||
|`enterCalibrationMode()`|<ol><li>`doMonocular`: boolean indicating whether the calibration is monocular or binocular</li></ol>|<ol><li>`hasEnqueuedEnter`: boolean indicating whether a request to enter calibration mode has been sent to worker thread. Will return false if already in calibration mode through a previous call to this interface (it does not detect if other programs/code have put the eye tracker in calibration mode).</li></ol>|Queue request for the tracker to enter into calibration mode.|
|`isInCalibrationMode()`|<ol><li>`throwErrorIfNot`: Optionally throws error if not in calibration mode. Default `false`.</li></ol>|<ol><li>`isInCalibrationMode`: Boolean indicating whether eye tracker is in calibration mode.</li></ol>|Check whether eye tracker is in calibration mode.|
|`leaveCalibrationMode()`|<ol><li>`force`: set to true if you want to be completely sure that the tracker is not in calibration mode after this call: this also ensures calibration mode is left if code other than this interface put the eye tracker into calibration mode</li></ol>|<ol><li>`hasEnqueuedLeave`: boolean indicating whether a request to leave calibration mode has been sent to worker thread. Will return false if force leaving or if not in calibration mode through a previous call to this interface.</li></ol>|Queue request for the tracker to leave the calibration mode.|
|`calibrationCollectData()`|<ol><li>`coordinates`: the coordinates of the point that the participant is asked to fixate, 2-element array with values in the range [0,1]</li><li>`eye`: (optional) the eye for which to collect calibration data. Possible values: `left` and `right`</li></ol>||Queue request for the tracker to collect gaze data for a single calibration point.|
|`calibrationDiscardData()`|<ol><li>`coordinates`: the coordinates of the point for which calibration data should be discarded, 2-element array with values in the range [0,1]</li><li>`eye`: (optional) the eye for which collected calibration data should be discarded. Possible values: `left` and `right`</li></ol>||Queue request for the tracker to discard any already collected gaze data for a single calibration point.|
|`calibrationComputeAndApply()`|||Queue request for the tracker to compute the calibration function and start using it.|
|`calibrationGetData()`|||Request retrieval of the computed calibration as an (uninterpretable) binary stream.|
|`calibrationApplyData()`|<ol><li>`cal`: a binary stream as gotten through `calibrationGetData()`</li></ol>||Apply the provided calibration data.|
|`calibrationGetStatus()`||<ol><li>`status`: a string, possible values: `NotYetEntered`, `AwaitingCalPoint`, `CollectingData`, `DiscardingData`, `Computing`, `GettingCalibrationData`, `ApplyingCalibrationData` and `Left`</li></ol>|Get the current state of Titta's calibration mechanism.|
|`calibrationRetrieveResult()`||<ol><li>`result`: a struct containing a submitted work item and the associated result, if any compelted work items are available</li></ol>|Get information about tasks completed by Titta's calibration mechanism.|

#### Properties
The following **read-only** properties are available for a Titta instance:

|Property|Description|
| --- | --- |
|`serialNumber`|Get connected eye tracker's serial number.|
|`model`|Get connected eye tracker's model name.|
|`firmwareVersion`|Get connected eye tracker's firmware version.|
|`runtimeVersion`|Get connected eye tracker's runtime version.|
|`address`|Get connected eye tracker's address.|
|`capabilities`|Get connected eye tracker's exposed capabilities.|
|`supportedFrequencies`|Get connected eye tracker's supported sampling frequencies.|
|`supportedModes`|Get connected eye tracker's supported tracking modes.|

The following **settable** properties are available for a Titta instance:

|Property|Description|
| --- | --- |
|`deviceName`|Get or set connected eye tracker's device name.|
|`frequency`|Get or set connected eye tracker's sampling frequency.|
|`trackingMode`|Get or set connected eye tracker's tracking mode.|

### `TalkToProLab` class
#### Static methods
The below method can be called on a TalkToProLab instance or on the TalkToProLab class directly.

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`makeAOITag`|<ol><li>`tagName`: The name of the tag</li><li>`groupName`: (optional) the name of the tag group the tag belongs to.</li></ol>|<ol><li>`tag`: The AOI tag.</li></ol>|Generates an AOI tag in the format expected by `TalkToProLab.attachAOIToImage()`.|

#### Construction
An instance of TalkToProLab is constructed by calling `TalkToProLab()` and providing the constructor with the name of the External Presenter project that should be opened in Pro Lab. Two optional additional constructor arguments can be provided.
- `doCheckSync`: (default `true`) determines whether clock sync between PsychToolbox and Pro Lab endpoint should be checked. Set to false if you want to use `TalkToProLab` without PsychToolbox (no other part of the `TalkToProLab` class uses PsychToolbox functionality), or if you want to use `TalkToProLab` with a two-computer setup, where Pro Lab runs on a different machine than MATLAB. Note that in this case, you are responsible for figuring out the sync between Pro Lab your local machine yourself. This is important because `TalkToProLab.sendStimulusEvent()` and `TalkToProLab.sendCustomEvent()` take timestamps in Pro Lab time, not local time. You can use the `TalkToProLab.clientClock` WebSocket interface to talk directly to Pro Lab's clock websocket service.
- `IPorFQDN`: this is to indicate the IP or FQDN where the Pro Lab instance can be contacted. Defaults to `localhost` for a one-computer setup.

#### Methods
The following method calls are available on a TalkToProLab instance

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`disconnect()`|||Disconnect from Tobii Pro Lab.|
|`createParticipant()`|<ol><li>`name`: name of the media to find</li><li>`allowExisting`: (optional) boolean indicating what to do if a participant with the provided name already exists in the Tobii Pro Lab project. If false, as error is generated, if true, the already existing participant. This toolbox will not create multiple participants with the same name (case sensitive).</li></ol>|<ol><li>`participantID`: string: a unique ID for identifying the participant in the Pro Lab project</li></ol>|Create a new participant in the Tobii Pro Lab project.|
|`findMedia()`|<ol><li>`name`: name of the media to find (case sensitive)</li><li>`throwWhenNotFound`: (optional) boolean indicating whether an error should be thrown when the requested media is not found. Default: false</li></ol>|<ol><li>`mediaID`: string: a unique ID for identifying the media in the Pro Lab project, or empty if not found</li><li>`mediaInfo`: a struct containing other info about the media</li></ol>|Find media by name in the Tobii Pro Lab project.|
|`uploadMedia()`|<ol><li>`fileNameOrArray`: either full path to a file to upload, or an array of pixel data (NxMx1 or NxMx3). Understood media types when a filename is provided are `bmp`, `jpg`, `jpeg`, `png`, `gif`, `mp4` and `avi`</li><li>`name`: name to store the media under</li></ol>|<ol><li>`mediaID`: string: a unique ID for identifying the media in the Pro Lab project</li><li>`wasUploaded`: a boolean indicated whether the media was uploaded (true) or whether media with the same name already existed in the Pro Lab project (false, not overwritten)</li></ol>|Upload media to the Tobii Pro Lab project.|
|`attachAOIToImage`|<ol><li>`mediaName`: name of the media to define an AOI for</li><li>`aoiName`: name of the AOI</li><li>`aoiColor`: color in which to show the AOI in Pro Lab (RGB, 0-255)</li><li>`vertices`: 2xN matrix of vertices of the AOI</li><li>`tags`: array-of-structs defining tags to attach to the AOI, use the static function `TalkToProLab.makeAOITag` to create the structs</li></ol>||Define an AOI for a specific media in the Pro Lab project.|
|`attachAOIToVideo`|<ol><li>`mediaName`: name of the media to define an AOI for</li><li>`request`: request struct or JSON string defining the AOI to add to the video. Read the Tobii Pro Lab API Reference Guide to see how to format this request</li></ol>||Define an AOI for a specific media in the Pro Lab project.|
|||||
|`getExternalPresenterState()`||<ol><li>`EPState`: string indicating the state of the external presenter service in Pro Lab</li></ol>|Get the state of the external presenter service in Pro Lab.|
|`startRecording()`|<ol><li>`name`: name by which the recording will be identified in Pro Lab</li><li>`scrWidth`: width of the screen in pixels</li><li>`scrHeight`: height of the screen in pixels</li><li>`scrLatency`: (optional) numeric value indicating delay between drawing commands being issued and the image actually appearing on the screen</li><li>`skipStateCheck`: boolean (optional) if true, checking whether Pro Lab is in the expected state is skipped</li></ol>|<ol><li>`recordingID`: string: a unique ID for identifying the recording in the Pro Lab project</li></ol>|Tell Pro Lab to start a recording.|
|`stopRecording()`|||Stop a currently ongoing recording of Tobii Pro Lab.|
|`finalizeRecording()`|||Finalize the stopped recording in Tobii Pro Lab. Note: after this call, you must still click ok in the Pro Lab user interface.|
|`discardRecording()`|||Discard (remove) the stopped recording in Tobii Pro Lab.|
|||||
|`sendStimulusEvent()`|<ol><li>`mediaID`: unique identifier by which shown media stimulus is identified in Pro Lab</li><li>`mediaPosition`: location of the stimulus on screen in pixels, format: `[left top right bottom]`</li><li>`startTimeStamp`: timestamp (in seconds or microseconds) at which stimulus presentation started (in Pro Lab time, which is equal to PsychToolbox time when using a single-machine setup).</li><li>`endTimeStamp`: (optional) timestamp (in seconds or microseconds) of when presentation of this stimulus ended (in Pro Lab time). If empty, it is assumed stimulus remained on screen until start of the next stimulus</li><li>`background`: color of background (RGB: 0-255) on top of which stimulus was shown</li><li>`qDoTimeConversion`: boolean (optional) if true, will convert provided timestamps from seconds to microseconds</li></ol>||Inform Pro Lab when and where a media (stimulus) was shown.|
|`sendCustomEvent()`|<ol><li>`timeStamp`: (optional) timestamp (in s) at which event occured (in Pro Lab time, which is equal to PsychToolbox time when using a single-machine setup). If empty, current time is taken as event time</li><li>`eventType`: string: event type name</li><li>`value`: (optional) string, the value of the event</li></ol>||Add an event to Pro Lab's timeline.|

#### Properties
The following read-only properties are available for a TalkToProLab instance:

|Property|Description|
| --- | --- |
|`projectID`|The GUID indentifying the project opened in Pro Lab.|
|`participantID`|Filled by `TalkToProLab.createParticipant()`. The GUID indentifying the participant for which a recording will be created in Pro Lab.|
|`recordingID`|Filled by `TalkToProLab.startRecording()`. The GUID indentifying the current recording in Pro Lab.|
|`clientClock`|Websocket interface to the clock API of Tobii Pro Lab.|
|`clientProject`|Websocket interface to the project API of Tobii Pro Lab.|
|`clientEP`|Websocket interface to the external presenter API of Tobii Pro Lab.|
