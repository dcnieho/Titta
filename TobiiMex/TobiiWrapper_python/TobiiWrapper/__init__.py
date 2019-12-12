debug = False
import sys;
if sys.maxsize > 2**32:
    # running on 64bit platform
    if debug:
        from .x64.TobiiWrapper_python_d import *
    else:
        from .x64.TobiiWrapper_python import *
else:
    # running on 32bit platform
    if debug:
        from .x86.TobiiWrapper_python_d import *
    else:
        from .x86.TobiiWrapper_python import *