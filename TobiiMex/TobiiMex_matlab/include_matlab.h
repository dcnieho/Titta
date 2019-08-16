#pragma once

#if defined(_WIN64) || defined(__linux__)
// for 64bit build, at least when using R2019a, we need to make sure to request using the old API so mex file works with older matlab versions (we support back to R2015b)
#	define MATLAB_MEXCMD_RELEASE R2017b    // ensure using the 700 API, so mex file also works on the older matlab versions we support
#	define MW_NEEDS_VERSION_H	// looks like a bug in R2018b onwards, don't know how to check if this is R2018b, define for now
#else
// this is building against R2015b (or earlier, no later matlab has 32bit support). Needs some different defines
#	define MX_COMPAT_32
#	define DLL_EXPORT_SYM __declspec(dllexport) // this is what is needed for earlier matlab versions instead
#endif

#include <mex.h>