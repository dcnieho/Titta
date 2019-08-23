Usage instructions for using the TobiiMex class are found in [the Titta documentation](../readme.md).

readerwriterqueue is required for compiling TobiiMex. Make sure you clone the Titta repository including all submodules so that this dependency is included.

To update the Tobii Pro C SDK used to build TobiiMEx against, you need to manually put the some files in the right place:
1. The \*.h include files are placed in `\TobiiMex\deps\include`
2. The Windows \*.lib link libraries are placed in `\TobiiMex\deps\lib`, naming `Tobii_C_SDK\64\lib\tobii_research.lib` as `tobii_research64.lib`, and `Tobii_C_SDK\32\lib\tobii_research.lib` as `tobii_research32.lib`.
3. The \*.dll and \*.so files are placed in the respective output directories, `\TobiiMex\TobiiMex_matlab\64` and `\TobiiMex\TobiiMex_matlab\32` (the latter Windows only)

For building the 32bit Windows mex file, a 32bit version of matlab must be installed. R2015b is the last version supporting 32bit.

For building the Linux mex file the default 7.4.0 included with Ubuntu 18.04 was used.
