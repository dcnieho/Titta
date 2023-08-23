This folder contains a series of simple readme scripts that demonstrate different functionality of Titta. The recorded data is stored in a `.mat` file, and can be analyzed using the example scripts in the [`demo_analysis`](../demo_analysis) folder of this repository.

Furthermore contained are a simple [smooth pursuit display demo](smoothPursuitDemo.m) that shows how to access the acquired data by plotting it after running a trial, [a complete antisaccade protocol](antiSaccade) and an eye-controlled version of the [BreakOut! game](breakOut) implemented using Titta functionality.

Each readme script is configured for use with a Tobii Pro Spectrum at its default sampling rate (600 Hz). If you have a different eye tracker, or your Spectrum does not support 600 Hz, the script will not run with the default setup, providing you clear error messages telling you what is wrong. To adapt Titta's settings to your setup, as needed:
- Change the line `settings = Titta.getDefaults('Tobii Pro Spectrum');` in the scripts to name a different eye tracker (see the main [readme](../readme.md#usage) for naming of the eye trackers, or just run the demo as is and it will tell you what eye tracker it did find)
- Add a line `settings.freq = 300;` to change the sampling frequency to, e.g., 300 Hz.

In general the logic is that you should never change any of the code in the Titta distribution to adapt to your setup (if that is necessary, that is a bug--please let me know by [opening an issue](https://github.com/dcnieho/Titta/issues)), but by changing the settings in your script, like the readme scripts demonstrate. Note that Titta's debug mode is switched on in the demos (`settings.debugMode = true;`) to provide more verbosity about its operation, to provide some insight about what is going on behind the scenes (mostly during calibration and validation). You can skip this in your own scripts without changing functionality.

The following readme scripts are available:
- `readmeMinimal.m`: Base readme script, showing "default" operation and providing the best starting point for developing your own experiment.
- `readme.m`: Expanded version of the `readmeMinimal.m` base script adding some less-used options (such as bi-monocular calibration and more configurability of the calibration display).
- `readmeChangeColors.m`: Version of `readme.m` showing how to change the background screen color of the calibration display, as well as the colors of various other elements on the setup and calibration screens.
- `readmeImageCal.m`: Version of `readme.m` showing how to use the `ImageCalibrationDisplay` class included with Titta to use a set of images as calibration/validation point. Includes support for animated gifs.
- `readmeVideoCal.m`: Version of `readme.m` showing how to use the `VideoCalibrationDisplay` class included with Titta to use a video or set of videos as calibration/validation point.
- `readmeProLabIntegration.m`: Version of `readme.m` showing how to use the [TalkToProLab class](../readme.md#the-talktoprolab-class) for allowing experiments created and run from MATLAB/Octave to be visualized and analyzed in Tobii Pro Lab.
- `readmeTwoScreens.m`: Version of `readme.m` showing use of the dual monitor mode of Titta that provides separate participant and operator screens.

Besides the default operation mode with a simple interface for calibration and validation that is suitable for cooperative participants, Titta also includes a separate more advanced calibration interface that gives the operator more control over what is shown to participants. This may be suitable for calibrating non-cooperative participants such as infants and primates. This mode is demoed in the following readme scripts:
- `readmeAdvancedCalibration.m`: Version of `readme.m` showing use of the advanced calibration interface implemented with the `Titta.calibrateAdvanced()` function.