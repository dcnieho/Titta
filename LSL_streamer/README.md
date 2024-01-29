[![Downloads](https://static.pepy.tech/badge/tittalslpy)](https://pepy.tech/project/tittalslpy)
[![PyPI Latest Release](https://img.shields.io/pypi/v/TittaLSLPy.svg)](https://pypi.org/project/TittaLSLPy/)
[![image](https://img.shields.io/pypi/pyversions/TittaLSLPy.svg)](https://pypi.org/project/TittaLSLPy/)

# TittaLSL
The TittaLSL tool is an extension to [Titta (and its TittaMex and TittaPy wrappers)](/readme.md#titta-tittamex-tittapy-classes). It allows to stream data from Tobii eye trackers in Titta's format using Lab Streaming Layer and to receive such data and access it through an API that is identical to that of Titta. That allows handling local and remote eye tracker data sources in a uniform manner, making it possible to design interesting experiments using multiple eye trackers.

TittaLSL is a C++ library that can be compiled and used as a static library without Matlab/Octave or Python. However, MATLAB and Python wrappers are also provided in the form of TittaLSLMex and TittaLSLPy, respectively.

In comparison to the the [Lab Streaming Layer TobiiPro Connector](https://github.com/labstreaminglayer/App-TobiiPro), Titta LSL provides access to all gaze data fields instead of only gaze position on the screen, as well as the eye image, external signal, time synchronization and positioning streams. Samples are furthermore properly timestamped using the timestamps from the eye tracker, where possible (all streams except for the positioning stream, which doesn't have timestamps).

## The `TittaLSL`, `TittaLSLMex` and `TittaLSLPy` classes
The functionality of TittaLSL is divided over two classes, `Sender` for making eye tracker data available on the network (AKA an outlet in Lab Streaming Layer terminology) and `Receiver` for recording from TittaLSL data streams available on the network (AKA an inlet). The below documents the available methods of these classes. The functionality below is exposed under the same names in MATLAB as `TittaLSL.Sender` and `TittaLSL.Receiver`, respectively. The same functionality is also available from `TittaLSLPy.Sender` and `TittaLSLPy.Receiver` instances, but in that case all function and property names as well as stream names use `snake_case` names instead of `camelCase`. In C++ all below functions and classes are in the `TittaLSL` namespace. See [here for example C++ code](/LSL_streamer/cppLSLTest/main.cpp) using the library, and [here for example Python code](/LSL_streamer/TittaLSLPy/test.py).

### Free functions
|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`getTobiiSDKVersion()`||<ol><li>`SDKVersion`: A string containing the version of the Tobii SDK.</li></ol>|Get the version of the Tobii Pro SDK dynamic library that is used by TittaLSL.|
|`getLSLVersion()`||<ol><li>`LSLVersion`: An int32 scalar denoting the version of Lab Streaming Layer.</li></ol>|Get the version of the Lab Streaming Layer dynamic library that is used by TittaLSL.|

### Construction and initialization
|Call|Inputs|Notes|
| --- | --- | --- |
|`TittaLSL::Sender()` (C++)<br>`TittaLSL.Sender()` (MATLAB)<br>`TittaLSLPy.Sender` (Python)|<ol><li>`address`: address of the eye tracker to be made available on the network. A list of connected eye trackers and their addresses can be using the static function [`Titta.findAllEyeTrackers()` in the Titta library](/readme.md#titta-tittamex-tittapy-classes).</li></ol>||
|`TittaLSL::Receiver()` (C++)<br>`TittaLSL.Receiver()` (MATLAB)<br>`TittaLSLPy.Receiver` (Python)|<ol><li>`streamSourceID`: Source ID of LSL stream to record from. Must be a TittaLSL stream.</li><li>`initialBufferSize`: (optional) value indicating for how many samples memory should be allocated.</li><li>`doStartRecording`: (optional) value indicating whether recording from the stream should immediately be started.</li></ol>|The default initial buffer size should cover about 30 minutes of recording gaze data at 600Hz, and longer for the other streams. Growth of the buffer should cause no performance impact at all as it happens on a separate thread. To be certain, you can indicate a buffer size that is sufficient for the number of samples that you expect to record. Note that all buffers are fully in-memory. As such, ensure that the computer has enough memory to satify your needs, or you risk a recording-destroying crash.|

### Methods
The following method calls are available on a `TittaLSL.Sender` instance:

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`getEyeTracker()`||<ol><li>`eyeTracker`: information about the eyeTracker that TittaLSL is connected to.</li></ol>|Get information about the eye tracker that the TittaLSL instance is connected to and will stream data from.|
|`start()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeImage`, `externalSignal`, `timeSync` and `positioning`.</li><li>`asGif`: an (optional) boolean that is ignored unless the stream type is `eyeImage`. It indicates whether eye images should be provided gif-encoded (true) or a raw grayscale pixel data (false).</li></ol>|<ol><li>`success`: a boolean indicating whether sending of the stream was started. May be false if sending was already started.</li></ol>|Start providing data of a specified type on the network.|
|`setIncludeEyeOpennessInGaze()`|<ol><li>`include`: a boolean, indicating whether eye openness samples should be provided in the sent gaze stream or not. Default false.</li></ol>||Set whether calls to start or stop providing the gaze stream will include data from the eye openness stream. An error will be raised if set to true, but the connected eye tracker does not provide an eye openness stream.|
|`isStreaming()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeImage`, `externalSignal`, `timeSync` and `positioning`.</li></ol>|<ol><li>`streaming`: a boolean indicating whether the indicated stream type is being made available on the network.</li></ol>|Check whether the specified stream type from the connected eye tracker is being made available on the network.|
|`stop()`|<ol><li>`stream`: a string, possible values: `gaze`, `eyeImage`, `externalSignal`, `timeSync` and `positioning`.</li></ol>||Stop providing data of a specified type on the network.|


The following static calls are available for `TittaLSL.Receiver`:
|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`GetStreams()`|<ol><li>`stream`: (optional) string, possible values: `gaze`, `eyeImage`, `externalSignal`, `timeSync` and `positioning`. If provided, only streams of this type are discovered on the network.</li></ol>|<ol><li>`streamInfoList`: list of objects containing info about discovered streams.</li></ol>|Discover what TittaLSL streams are available on the network.|

The following method calls are available on a `TittaLSL.Receiver` instance. Note that samples provided by the `consume*()` and `peek*()` functions are almost identical to those provided by their namesakes in `Titta` for a local eye tracker. The only difference is that the samples provided by TittaLSL have two extra fields, `remoteSystemTimeStamp` and `localSystemTimeStamp`. `remoteSystemTimeStamp` is the timestamp as provided by the Tobii SDK on the system where the eye tracker is connected. `localSystemTimeStamp` is the same timestamp, but expressed in the clock of the receiving machine. This local time is computed by using the offset provided by Lab Streaming Layer's `time_correction` function for the stream that the receiver is connected to. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the other fields.

|Call|Inputs|Outputs|Description|
| --- | --- | --- | --- |
|`getInfo()`||<ol><li>`info`: object containing info about the remote stream.</li></ol>|Get info about the connected remote stream.|
|`getType()`||<ol><li>`stream`: a stream indicating what type of data this remote source provides. Possible values: `gaze`, `eyeImage`, `externalSignal`, `timeSync` and `positioning`.</li></ol>|Get data type provided by the remote stream.|
|`start()`|||Start recording data from this remote stream to buffer.|
|`isRecording()`||<ol><li>`status`: a boolean indicating whether data of the indicated type is currently being recorded to the buffer.</li></ol>|Check if data from this remote stream is being recorded to buffer.|
|`consumeN()`|<ol><li>`N`: (optional) number of samples to consume from the start of the buffer. Defaults to all.</li><li>`side`: a string, possible values: `first` and `last`. Indicates from which side of the buffer to consume N samples. Default: `first`.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer, if available. If not available, an empty struct is returned.</li></ol>|Return and remove data from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`consumeTimeRange()`|<ol><li>`startT`: (optional) timestamp indicating start of interval for which to return data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to return data. Defaults to end of buffer.</li><li>`timeIsLocalTime`: (optional) boolean value indicating whether time provided `startT` and `endT` parameters are in local system time (true, default) or remote time (false).</li></ol>|<ol><li>`data`: struct containing data from the requested buffer in the indicated time range, if available. If not available, an empty struct is returned.</li></ol>|Return and remove data from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`peekN()`|<ol><li>`N`: (optional) number of samples to peek from the end of the buffer. Defaults to 1.</li><li>`side`: a string, possible values: `first` and `last`. Indicates from which side of the buffer to peek N samples. Default: `last`.</li></ol>|<ol><li>`data`: struct containing data from the requested buffer, if available. If not available, an empty struct is returned.</li></ol>|Return but do not remove data from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`peekTimeRange()`|<ol><li>`startT`: (optional) timestamp indicating start of interval for which to return data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to return data. Defaults to end of buffer.</li><li>`timeIsLocalTime`: (optional) boolean value indicating whether time provided `startT` and `endT` parameters are in local system time (true, default) or remote time (false).</li></ol>|<ol><li>`data`: struct containing data from the requested buffer in the indicated time range, if available. If not available, an empty struct is returned.</li></ol>|Return but do not remove data from the buffer. See [the Tobii SDK documentation](https://developer.tobiipro.com/commonconcepts.html) for a description of the fields.|
|`clear()`|||Clear the buffer.|
|`clearTimeRange()`|<ol><li>`startT`: (optional) timestamp indicating start of interval for which to clear data. Defaults to start of buffer.</li><li>`endT`: (optional) timestamp indicating end of interval for which to clear data. Defaults to end of buffer.</li><li>`timeIsLocalTime`: (optional) boolean value indicating whether time provided `startT` and `endT` parameters are in local system time (true, default) or remote time (false).</li></ol>||Clear data within specified time range from the buffer.|
|`stop()`|<ol><li>`doClearBuffer`: (optional) boolean indicating whether the buffer of the indicated stream type should be cleared.</li></ol>||Stop recording data from this remote stream to buffer.|



## Working on the source
The enclosed Visual Studio project files can be opened using the `Titta.sln` file in the [SDK_wrapper directory](/SDK_wrapper). It is to be opened and built with Visual Studio 2022 (last tested with version 17.8.4).

### Building the mex files
Run `makeTittaLSLMex.m` to build the mex file.

For building the Linux mex file the default gcc version 11.2.0 included with Ubuntu 22.04 was used.
For compatibility with an earlier version of Ubuntu, either install the right GLIBCXX version or recompile following the instructions here. See [this issue](https://github.com/dcnieho/Titta/issues/40) for more information.

### Required environment variables
Some environment variables must be set when working on the code or building it from Visual Studio. Here are the values i used (at the time of writing):
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2023b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy`

### Dependencies
#### [Lab Streaming Layer library](https://github.com/sccn/liblsl)
To update the Lab Streaming Layer library used to build TittaLSL against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\LSL_streamer\deps\include`
2. The Windows `lsl.lib` link library is placed in `\LSL_streamer\deps\lib`.
3. The \*.dll, \*.so and \*.dylib files are placed in the output directory, `\LSL_streamer\TittaLSLMex\+TittaLSL\+detail`.

#### [Titta](/SDK_wrapper)
TittaLSL also requires Titta and its dependencies to build. The build scripts are set up such that Titta is automatically built. However, ensure to check [Titta's dependencies](/SDK_wrapper/README.md#dependencies) and make sure they are available, or the build will fail.

## Acknowledgements
This project was made possible by funding from the [LMK foundation, Sweden](https://lmkstiftelsen.se/).
