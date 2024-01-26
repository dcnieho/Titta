[![Downloads](https://static.pepy.tech/badge/tittapy)](https://pepy.tech/project/tittapy)
[![Citation Badge](https://img.shields.io/endpoint?url=https%3A%2F%2Fapi.juleskreuer.eu%2Fcitation-badge.php%3Fshield%26doi%3D10.3758%2Fs13428-020-01358-8&color=blue)](https://scholar.google.com/citations?view_op=view_citation&citation_for_view=uRUYoVgAAAAJ:J_g5lzvAfSwC)
[![PyPI Latest Release](https://img.shields.io/pypi/v/TittaPy.svg)](https://pypi.org/project/TittaPy/)
[![image](https://img.shields.io/pypi/pyversions/TittaPy.svg)](https://pypi.org/project/TittaPy/)
[![DOI](https://zenodo.org/badge/DOI/10.3758/s13428-020-01358-8.svg)](https://doi.org/10.3758/s13428-020-01358-8)

Usage instructions for using the Titta class (through its TittaMex and TittaPy interfaces) are found in [the Titta documentation](https://github.com/dcnieho/Titta/blob/master/readme.md#titta-tittamex-tittapy-classes).

### Working on the source
The enclosed `Titta.sln` file is to be opened and built with Visual Studio 2022 (last tested with version 17.8.4).

### Building the mex files
Run `makeTittaMex.m` to build the mex file.

32-bit builds are no longer supported on Windows (they have never been on Linux). The last version of Titta/TittaMex supporting 32-bit Matlab is [available here](https://github.com/dcnieho/Titta/releases/tag/last_32bit_version).

For building the Linux mex file the default gcc version 11.2.0 included with Ubuntu 22.04 was used.
(The mex file currently does not build with gcc 9.3.0 provided in the mingw64 distribution that comes with Octave 6.4.0 on Windows.)
For compatibility with an earlier version of Ubuntu, either install the right GLIBCXX version or recompile following the instructions here. See [this issue](https://github.com/dcnieho/Titta/issues/40) for more information.

### Required environment variables
Some environment variables must be set when working on the code or building it from Visual Studio. Here are the values i used (at the time of writing):
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2023b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy`

### Dependencies
#### [readerwriterqueue](https://github.com/cameron314/readerwriterqueue)
readerwriterqueue located at `deps/include/readerwriterqueue` is required for compiling Titta. Make sure you clone the Titta repository including all submodules so that this dependency is available.

#### [Tobii Pro SDK](https://www.tobiipro.com/product-listing/tobii-pro-sdk/)
To update the Tobii Pro C SDK used to build Titta against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\SDK_wrapper\deps\include`
2. The Windows `Tobii_C_SDK\64\lib\tobii_research.lib` link library is placed in `\SDK_wrapper\deps\lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\SDK_wrapper\TittaMex\64\Windows` and `\SDK_wrapper\TittaMex\64\Linux`, respectively.

#### [PsychoPy](https://www.psychopy.org/) and [PyBind11](https://github.com/pybind/pybind11)
Please note that the code for the Python wrapper is currently not actively maintained and will not build as is now. However, assuming its updated, the following steps will build the code:
1. Make sure the PsychoPy version you want to work with is installed.
2. Make sure the `PYTHON_ROOT` environment variable is set to the location of your PsychoPy installation.
3. Install PyBind11: in the root folder of your PsychoPy installation, execute `python -m pip install pybind11`. Alternatively, install pybind11 through a package manager like vcpkg.
4. As per [here](https://docs.microsoft.com/en-us/visualstudio/python/working-with-c-cpp-python-in-visual-studio?view=vs-2019#prerequisites), make sure you have the Python Development workload for visual studio installed. Note however that you can unselect the Python 3 installation, the web tools and the miniconda installation that it by default installs, as we will be using the PsychoPy installation's Python environment. Check the "Python native development tools" option.

### Set up the Python environment for Visual Studio Python integration
Last, visual studio needs to be able to find your PsychoPy's Python environment. To do so, add a new Python environment, choose existing environment, and point it to the root of your PsychoPy install. In my case, that is `C:\Program Files\PsychoPy`.

#### Enabling native debugging
To be able to debug both the Python and C++ side of things with PsychoPy, you must install the debug symbols for the Python installation. This is done through the installer normally, but we don't have an option to do that with PyschoPy. So we have to add them manually. Here's how:
1. For 64bit Python 3.8.10 (what I am using in the current example), navigate to this [download location](https://www.python.org/ftp/python/3.8.10/amd64/).
2. Download all `*_d.msi` and `*_pdb.msi` files there (might be overkill, but better have them all).
3. Open a cmd with admin privileges, navigate to your download location.
4. Execute for each file a command like: `core_d.msi TARGETDIR="C:\Program Files\PsychoPy"`, where the `TARGETDIR` is set to the location of your PsychoPy installation.
