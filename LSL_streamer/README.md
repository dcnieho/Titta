Usage instructions for using the TittaLSL class are found in [the Titta documentation](../readme.md).

### Working on the source
The enclosed Visual Studio project files can be opened using the `Titta.sln` file in the [SDK_wrapper directory](../SDK_wrapper). It is to be opened and built with Visual Studio 2022 (last tested with version 17.8.4).

### Building the mex files
Run `makeTittaLSLMex.m` to build the mex file.

For building the Linux mex file the default gcc version 11.2.0 included with Ubuntu 22.04 was used.
(The mex file currently does not build with gcc 9.3.0 provided in the mingw64 distribution that comes with Octave 6.4.0 on Windows.)
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
3. The \*.dll and \*.so files are placed in the respective output directories, `\LSL_streamer\TittaLSLMex\64\Windows` and `\TittaMex\TittaLSLMex\64\Linux`, respectively.