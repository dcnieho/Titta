Usage instructions for using the Titta class are found in [the Titta documentation](../readme.md).

### Working on the source
The enclosed `TittaMex.sln` file is to be opened and built with Visual Studio 2022 (last tested with version 17.2.4).

### Building the mex files
Run `makeTittaMex.m` to build the mex file.

32-bit builds are no longer supported on Windows (they have never been on Linux). The last version of Titta/TittaMex supporting 32-bit Matlab is [available here](https://github.com/dcnieho/Titta/releases/tag/last_32bit_version).

For building the Linux mex file the default gcc version 11.2.0 included with Ubuntu 22.04 was used.
(The mex file currently does not build with gcc 9.3.0 provided in the mingw64 distribution that comes with Octave 6.4.0 on Windows.)
For compatibility with an earlier version of Ubuntu, either install the right GLIBCXX version or recompile following the instructions here. See [this issue](https://github.com/dcnieho/Titta/issues/40) for more information.

### Required environment variables
Some environment variables must be set when working on the code or building it from Visual Studio. Here are the values i used (at the time of writing):
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2019b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy3`

### Dependencies
#### [readerwriterqueue](https://github.com/cameron314/readerwriterqueue)
readerwriterqueue located at `deps/include/readerwriterqueue` is required for compiling Titta. Make sure you clone the Titta repository including all submodules so that this dependency is available.

#### [Tobii Pro SDK](https://www.tobiipro.com/product-listing/tobii-pro-sdk/)
To update the Tobii Pro C SDK used to build Titta against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\TittaMex\deps\include`
2. The Windows `Tobii_C_SDK\64\lib\tobii_research.lib` link library is placed in `\TittaMex\deps\lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\TittaMex\TittaMex\64\Windows` and `\TittaMex\TittaMex\64\Linux`, respectively.

#### [PsychoPy](https://www.psychopy.org/) and [PyBind11](https://github.com/pybind/pybind11)
Please note that the code for the Python wrapper is currently not actively maintained and will not build as is now. However, assuming its updated, the following steps will build the code:
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
