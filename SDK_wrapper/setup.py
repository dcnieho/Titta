# to build, run python -m pip wheel .
# to install, run python -m pip install .
# add -v switch to see output during build

from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext
import sys

# detect platform
isOSX = sys.platform.startswith("darwin")

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
        'TittaPy_v%d' % sdk_version,
        ['src/Titta.cpp','src/types.cpp','src/utils.cpp','TittaPy/TittaPy.cpp'],
        include_dirs=[
            # Path to pybind11 headers
            get_pybind_include(),
            get_pybind_include(user=True),
            '.',
            'deps/include',
            'deps/include/SDKv%d' % sdk_version
        ],
        library_dirs=[
            'deps/lib'
            ],
        language='c++'
    )

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
        'unix': ['-flto'],
    }
    if isOSX:
        c_opts['unix'].append('-mmacosx-version-min=11')
        # set rpath so that delocate can find .dylib
        l_opts['unix'].extend(['-L./TittaMex/64/OSX/', '-Wl,-rpath,''./SDK_wrapper/TittaMex/64/OSX/''','-dead_strip'])
    else:
        l_opts['unix'].extend(['-L./TittaMex/64/Linux/', '-Wl,--gc-sections'])

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
                    this_link_opts.append('-llibtobii_research.%d' % sdk_version)
                else:
                    this_link_opts.append('-l:libtobii_research.so.%d' % sdk_version)
            ext.extra_compile_args.extend(this_opts)
            ext.extra_link_args.extend(this_link_opts)
        build_ext.build_extensions(self)

setup(
    name='TittaPy',
    version=__version__,
    author='Diederick C. Niehorster',
    author_email='diederick_c.niehorster@humlab.lu.se',
    url='https://github.com/dcnieho/Titta',
    description='Interface to Tobii eye trackers using Tobii Pro SDK',
    keywords="Tobii PsychoPy Eye-tracking",
    long_description=readme,
    long_description_content_type = 'text/markdown',
    ext_modules=ext_modules,
    python_requires=">=3.8",
    setup_requires=['pybind11>=2.10.1'],  # this fixes problem if c++23 std::forward_like is available that i ran into
    install_requires=['numpy'],
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
