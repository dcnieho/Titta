Usage instructions for using the TobiiMex class are found in [the Titta documentation](../readme.md).

### Working on the source
The enclosed `TobiiMex.sln` file is to be opened and built with Visual Studio 2019 (last tested with version 16.4.1).

### Building the mex files
Run `makeTobiiMex.m` to build the mex file. To build the 32bit Windows version, use the Visual Studio project.

For building the 32bit Windows mex file, a 32bit version of matlab must be installed. R2015b is the last version supporting 32bit.

For building the Linux mex file the default 7.4.0 included with Ubuntu 18.04 was used.
The mex file also builds with gcc 7.4.0 provided in the mingw64 distribution that comes with Octave 5.1.0. The Titta class is currently however not supported on Octave due to bugs in how Octave deals with function handles.

### Required environment variables
Some environment variables must be set when working on the code or building it from Visual Studio. Here are the values i used:
- `MATLAB_ROOT`: `C:\Program Files\MATLAB\R2019b`
- `MATLAB32_ROOT`: `C:\Program Files (x86)\MATLAB\R2015b`
- `PYTHON_ROOT`: `C:\Program Files\PsychoPy3`

### Dependencies
#### readerwriterqueue
readerwriterqueue located at `deps/include/readerwriterqueue` is required for compiling TobiiMex. Make sure you clone the Titta repository including all submodules so that this dependency is available.

#### Tobii Pro SDK
To update the Tobii Pro C SDK used to build TobiiMex against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\TobiiMex\deps\include`
2. The Windows \*.lib link libraries are placed in `\TobiiMex\deps\lib`, renaming `Tobii_C_SDK\64\lib\tobii_research.lib` as `tobii_research64.lib`, and `Tobii_C_SDK\32\lib\tobii_research.lib` as `tobii_research32.lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\TobiiMex\TobiiMex_matlab\64` and `\TobiiMex\TobiiMex_matlab\32` (the latter Windows only)

#### PsychoPy
Building the Python wrapper is somewhat involved. Follow the below steps for Windows using Visual Studio:

The below steps are specific to PsychoPy version 3.2.4, 64bit, using Python 3.6.6. Furthermore using vcpkg commit `7a14422290e7583c68ee290f7dbb5d61872a7a99`. If your version of PsychoPy uses a different Python version, is installed in a different location, or the vcpkg port cmake file has changed, you may need to adapt the below accordingly.

1. setup vcpkg:
```
git clone https://github.com/Microsoft/vcpkg.git

cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
```
2. Make sure the PsychoPy version you want to work with is installed.
3. Determine the location of PsychoPy. For me it is: `C:/Program Files/PsychoPy3` (note the forward slashes)
4. In your vcpkg directory, you need to edit some files.

   a. At `<vcpkg root>\ports\boost-python`, open the file `CONTROL`. Remove `, python3` from the `Build-Depends:` line. Save.
   
   b. At `<vcpkg root>\ports\boost-python`, open the file `portfile.cmake`. Apply the following patch
   ```diff
    )

    # Find Python. Can't use find_package here, but we already know where everything is
   -file(GLOB PYTHON_INCLUDE_PATH "${CURRENT_INSTALLED_DIR}/include/python[0-9.]*")
   -set(PYTHONLIBS_RELEASE "${CURRENT_INSTALLED_DIR}/lib")
   -set(PYTHONLIBS_DEBUG "${CURRENT_INSTALLED_DIR}/debug/lib")
   -string(REGEX REPLACE ".*python([0-9\.]+)$" "\\1" PYTHON_VERSION "${PYTHON_INCLUDE_PATH}")
   +set(PYTHON_INCLUDE_PATH "C:/Program Files/PsychoPy3/include")^M
   +set(PYTHONLIBS_RELEASE "C:/Program Files/PsychoPy3/Libs")^M
   +set(PYTHONLIBS_DEBUG "C:/Program Files/PsychoPy3/Libs")^M
   +set(PYTHON_VERSION "3.6")^M
    include(${CURRENT_INSTALLED_DIR}/share/boost-build/boost-modular-build.cmake)
    boost_modular_build(SOURCE_PATH ${SOURCE_PATH})
    include(${CURRENT_INSTALLED_DIR}/share/boost-vcpkg-helpers/boost-modular-headers.cmake)
   ```
   Save the file and close it.

5. Now you are ready to install boost-python, issue:
`vcpkg install boost-python:x64-windows`

### Set up the Python environment for Visual Studio Python integration
Last, visual studio needs to be able to find your PsychoPy's Python environment. To do so, add a new Python environment, choose existing environment, and point it to the root of your PsychoPy install, in my case, `C:\Program Files\PsychoPy3`.
