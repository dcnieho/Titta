# to build, run python -m pip wheel .
# to install, run python -m pip install .
# add -v switch to see output during build

from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext
import sys
import os
import platform

# detect platform
isOSX = sys.platform.startswith("darwin")
isAppleSilicon = isOSX and 'arm64' in platform.uname().version.lower()

__version__ = '1.4.2'

with open('README.md') as f:
    readme = f.read()


class get_pybind_include(object):
    """Helper class to determine the pybind11 include path

    The purpose of this class is to postpone importing pybind11
    until it is actually installed, so that the ``get_include()``
    method can be invoked. """

    def __init__(self, user=False):
        self.user = user

    def __str__(self):
        import pybind11
        return pybind11.get_include(self.user)

def get_extension_def(sdk_version):
    return Extension(
        'TittaLSLPy_v%d' % sdk_version,
        ['../SDK_wrapper/src/Titta.cpp','../SDK_wrapper/src/types.cpp','../SDK_wrapper/src/utils.cpp','src/TittaLSL.cpp','TittaLSLPy/TittaLSLPy.cpp'],
        include_dirs=[
            # Path to pybind11 headers
            get_pybind_include(),
            get_pybind_include(user=True),
            '.',
            'deps/include',
            '../SDK_wrapper',
            '../SDK_wrapper/deps/include',
            '../SDK_wrapper/deps/include/SDKv%d' % sdk_version
        ],
        library_dirs=[
            'deps/lib',
            '../SDK_wrapper/deps/lib'
            ],
        language='c++'
    )

if isAppleSilicon:
    # only SDK v2 is supports Apple Silicon
    ext_modules = [get_extension_def(2)]
else:
    ext_modules = [
        get_extension_def(1),
        get_extension_def(2)
    ]


class BuildExt(build_ext):
    """A custom build extension for adding compiler-specific options."""
    c_opts = {
        'msvc': ['/DBUILD_FROM_SCRIPT','/DNDEBUG','/Zp8','/GR','/W3','/EHs','/nologo','/MD','/std:c++latest','/Gy','/Oi','/GL','/permissive-','/O2'],
        'unix': ['-DBUILD_FROM_SCRIPT','-DNDEBUG','-std=c++2a','-O3','-fvisibility=hidden','-ffunction-sections','-fdata-sections','-flto'],
    }
    l_opts = {
        'msvc': ['/LTCG','/OPT:REF','/OPT:ICF'],
        'unix': ['-flto', '-llsl'],
    }
    if isOSX:
        c_opts['unix'].append('-mmacosx-version-min=11')
        # set rpath so that delocate can find .dylib
        l_opts['unix'].extend(['-L./TittaLSLMex/+TittaLSL/+detail/', '-Wl,-rpath,''./LSL_streamer/TittaLSLMex/+TittaLSL/+detail/''','-dead_strip'])
    else:
        l_opts['unix'].extend(['-L./TittaLSLMex/+TittaLSL/+detail/', '-Wl,--gc-sections'])

    def build_extensions(self):
        ct = self.compiler.compiler_type
        opts = self.c_opts.get(ct, [])
        link_opts = self.l_opts.get(ct, [])
        if ct == 'msvc':
            opts.append('/DVERSION_INFO="%s"' % self.distribution.get_version())
        elif ct == 'unix':
            opts.append('-DVERSION_INFO="%s"' % self.distribution.get_version())
        for ext in self.extensions:
            this_opts      =      opts.copy()
            this_link_opts = link_opts.copy()
            sdk_version = int(ext.name[-1])
            if ct == 'msvc':
                this_opts.append('/DTOBII_SDK_MAJOR_VERSION=%d' % sdk_version)
            elif ct == 'unix':
                this_opts.append('-DTOBII_SDK_MAJOR_VERSION=%d' % sdk_version)
                if isOSX:
                    this_link_opts.append('-ltobii_research.%d' % sdk_version)
                else:
                    this_link_opts.append('-l:libtobii_research.so.%d' % sdk_version)
            ext.extra_compile_args.extend(this_opts)
            ext.extra_link_args.extend(this_link_opts)
        build_ext.build_extensions(self)

        # if OSX, fix up tobii_research load path for v1 so v2 is not picked up
        if isOSX:
            ext_path = None
            # find path to build extension for SDKv1
            for ext in self.extensions:
                if int(ext.name[-1])==1:
                    ext_path = os.path.abspath(self.get_ext_fullpath(ext.name))
                    print('patching: %s' % ext_path)
                    break
            # fix it up
            if ext_path is not None:
                os.system('install_name_tool -change @rpath/libtobii_research.dylib @rpath/libtobii_research.1.dylib ' + ext_path)

setup(
    name='TittaLSLPy',
    version=__version__,
    author='Diederick C. Niehorster',
    author_email='diederick_c.niehorster@humlab.lu.se',
    url='https://github.com/dcnieho/Titta',
    description='Interface for streaming and receiving Tobii eye tracker data using Lab Streaming Layer',
    keywords="Tobii PsychoPy Eye-tracking streaming remote LSL",
    long_description=readme,
    long_description_content_type = 'text/markdown',
    ext_modules=ext_modules,
    python_requires=">=3.8",
    setup_requires=['pybind11>=2.10.1'],  # this fixes problem if c++23 std::forward_like is available that i ran into
    install_requires=['numpy',f'TittaPy=={__version__}'],
    cmdclass={'build_ext': BuildExt},
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: Science/Research',
        'Topic :: Scientific/Engineering',
        'Topic :: Software Development :: Libraries',
        'Environment :: MacOS X',
        'Environment :: Win32 (MS Windows)',
        'Environment :: X11 Applications',
        'Operating System :: Microsoft :: Windows',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python :: 3',
        'Programming Language :: C++',
    ]
)
