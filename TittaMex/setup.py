# to build, run python -m pip wheel .
# to install, run python -m pip install .
# add -v switch to see output during build

from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext
import sys
import setuptools
import platform

__version__ = '1.0.0-rc1'

# choose right version of dll to install along with built module
if platform.architecture()[0]=="64bit":
    data_files = [('lib\\site-packages\\',["./TittaMex_matlab/64/tobii_research.dll"])]
else:
    data_files = [('lib\\site-packages\\',["./TittaMex_matlab/32/tobii_research.dll"])]


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


ext_modules = [
    Extension(
        'TobiiWrapper',
        ['src/TittaMex.cpp','src/types.cpp','src/utils.cpp','TobiiWrapper/TobiiWrapper.cpp'],
        include_dirs=[
            # Path to pybind11 headers
            get_pybind_include(),
            get_pybind_include(user=True),
            '.',
            'deps/include'
        ],
        library_dirs=[
            'deps/lib'
            ],
        language='c++'
    ),
]


class BuildExt(build_ext):
    """A custom build extension for adding compiler-specific options."""
    c_opts = {
        'msvc': ['/DBUILD_FROM_SCRIPT','/DNDEBUG','/Zp8','/GR','/W3','/EHs','/nologo','/MD','/std:c++latest','/Gy','/Oi','/GL','/permissive-','/O2'],
        'unix': ['-DBUILD_FROM_SCRIPT','-DNDEBUG','-std=c++17','-O3','-fvisibility=hidden'],
    }
    l_opts = {
        'msvc': ['/LTCG','/OPT:REF','/OPT:ICF'],
        'unix': ['-Wl,-rpath,''$ORIGIN'''],
    }

    def build_extensions(self):
        ct = self.compiler.compiler_type
        opts = self.c_opts.get(ct, [])
        link_opts = self.l_opts.get(ct, [])
        if ct == 'unix':
            opts.append('-DVERSION_INFO="%s"' % self.distribution.get_version())
        elif ct == 'msvc':
            opts.append('/DVERSION_INFO=\\"%s\\"' % self.distribution.get_version())
        for ext in self.extensions:
            ext.extra_compile_args = opts
            ext.extra_link_args = link_opts
        build_ext.build_extensions(self)

setup(
    name='TobiiWrapper',
    version=__version__,
    author='Diederick C. Niehorster',
    author_email='diederick_c.niehorster@humlab.lu.se',
    url='https://github.com/dcnieho/Titta',
    description='Matlab and PsychToolbox interface to Tobii eye trackers using Tobii Pro SDK',
    keywords="Tobii PsychoPy",
    long_description='',
    ext_modules=ext_modules,
    install_requires=['pybind11>=2.4'],
    setup_requires=['pybind11>=2.4'],
    cmdclass={'build_ext': BuildExt},
    data_files=data_files
)
