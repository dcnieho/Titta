Usage instructions for using the TobiiMex class are found in [the Titta documentation](../readme.md).

Run `makeTobiiMex.m` to build the mex files. To build the 32bit Windows version, use the Visual Studio project.

readerwriterqueue located at `deps/include/readerwriterqueue` is required for compiling TobiiMex. Make sure you clone the Titta repository including all submodules so that this dependency is available.

To update the Tobii Pro C SDK used to build TobiiMex against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\TobiiMex\deps\include`
2. The Windows \*.lib link libraries are placed in `\TobiiMex\deps\lib`, renaming `Tobii_C_SDK\64\lib\tobii_research.lib` as `tobii_research64.lib`, and `Tobii_C_SDK\32\lib\tobii_research.lib` as `tobii_research32.lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\TobiiMex\TobiiMex_matlab\64` and `\TobiiMex\TobiiMex_matlab\32` (the latter Windows only)

For building the 32bit Windows mex file, a 32bit version of matlab must be installed. R2015b is the last version supporting 32bit.

For building the Linux mex file the default 7.4.0 included with Ubuntu 18.04 was used.
The mex file also builds with gcc 7.4.0 provided in the mingw64 distribution that comes with Octave 5.1.0. The Titta class is currently however not supported on Octave due to bugs in Octave with handling function handles.
