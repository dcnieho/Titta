Usage instructions for using the TobiiMex class are found in [the Titta documentation](../readme.md).

### Working on the source
The enclosed `TobiiMex.sln` file is to be opened and built with Visual Studio 2019 (last tested with version 16.4.1).

### Building the mex files
Run `makeTobiiMex.m` to build the mex file. To build the 32bit Windows version, use the Visual Studio project.

For building the 32bit Windows mex file, a 32bit version of matlab must be installed. R2015b is the last version supporting 32bit.

For building the Linux mex file the default gcc version 7.4.0 included with Ubuntu 18.04 was used.
The mex file also builds with gcc 7.4.0 provided in the mingw64 distribution that comes with Octave 5.1.0. The Titta class is currently however not supported on Octave due to bugs in how Octave deals with function handles.

### Required environment variables
Some environment variables must be set when working on the code or building it from Visual Studio. Here are the values i used:
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2019b`
- `MATLAB32_ROOT`: `C:\Program Files (x86)\MATLAB\R2015b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy3`

### Dependencies
#### [readerwriterqueue](https://github.com/cameron314/readerwriterqueue)
readerwriterqueue located at `deps/include/readerwriterqueue` is required for compiling TobiiMex. Make sure you clone the Titta repository including all submodules so that this dependency is available.

#### [Tobii Pro SDK](https://www.tobiipro.com/product-listing/tobii-pro-sdk/)
To update the Tobii Pro C SDK used to build TobiiMex against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\TobiiMex\deps\include`
2. The Windows \*.lib link libraries are placed in `\TobiiMex\deps\lib`, renaming `Tobii_C_SDK\64\lib\tobii_research.lib` as `tobii_research64.lib`, and `Tobii_C_SDK\32\lib\tobii_research.lib` as `tobii_research32.lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\TobiiMex\TobiiMex_matlab\64` and `\TobiiMex\TobiiMex_matlab\32` (the latter Windows only)

#### [PsychoPy](https://www.psychopy.org/) and [PyBind11](https://github.com/pybind/pybind11)
1. Make sure the PsychoPy version you want to work with is installed.
2. Make sure the `PYTHON_ROOT` environment variable is set to the location of your PsychoPy installation.
3. Install PyBind11: in the root folder of your PsychoPy installation, execute `python -m pip install pybind11`
4. As per [here](https://docs.microsoft.com/en-us/visualstudio/python/working-with-c-cpp-python-in-visual-studio?view=vs-2019#prerequisites), make sure you have the Python Development workload for visual studio installed. Note however that you can unselect the Python 3 installation, the web tools and the miniconda installation that it by default installs, as we will be using the PsychoPy installation's Python environment. Check the "Python native development tools" option.

### Set up the Python environment for Visual Studio Python integration
Last, visual studio needs to be able to find your PsychoPy's Python environment. To do so, add a new Python environment, choose existing environment, and point it to the root of your PsychoPy install. In my case, that is `C:\Program Files\PsychoPy3`.

#### Enabling native debugging
To be able to debug both the Python and C++ side of things with PsychoPy, you must install the debug symbols for the Python installation. This is done through the installer normally, but we don't have an option to do that with PyschoPy. So we have to add them manually. Here's how:
1. For 64bit Python 3.6.6 (what I am using in the current example), navigate to this [download location](https://www.python.org/ftp/python/3.6.6/amd64/).
2. Download all `*_d.msi` and `*_pdb.msi` files there (might be overkill, but better have them all).
3. Open a cmd with admin privileges, navigate to your download location.
4. Execute for each file a command like: `core_d.msi TARGETDIR="C:\Program Files\PsychoPy3"`, where the `TARGETDIR` is set to the location of your PsychoPy installation.
