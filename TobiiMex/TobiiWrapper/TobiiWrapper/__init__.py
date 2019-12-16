_debug = False
import sys;
if sys.maxsize > 2**32:
    # running on 64bit platform
    if _debug:
        from .x64.TobiiWrapper_python_d import *
    else:
        from .x64.TobiiWrapper_python import *
else:
    # running on 32bit platform
    if _debug:
        from .x86.TobiiWrapper_python_d import *
    else:
        from .x86.TobiiWrapper_python import *

# numpy must be imported because module is built including numpy
# functionality. Random crashes will ensure otherwise, even when
# not using the numpy-exporting method call
import numpy