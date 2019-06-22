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
3. Create a SMITE instance using this settings struct: `EThndl = Titta(settings);`

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
|||||

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
