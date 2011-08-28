#!/usr/bin/env python
# -*- coding: utf-8 -*-

PROJECT = 'virtualenvwrapper-powershell'

# YY.M.D[a-z]
VERSION = '11.8.28'

# Bootstrap installation of Distribute
import distribute_setup
distribute_setup.use_setuptools()

from setuptools import setup

from distutils.util import convert_path
from fnmatch import fnmatchcase
import os
import sys

try:
    long_description = open('README.txt', 'rt').read()
except IOError:
    long_description = ''

###############################################################################
# Windows: Bulk of the code needed to retrieve the actual "Documents" folder.
# -----------------------------------------------------------------------------
from ctypes import windll
from ctypes import byref
from ctypes import Structure
from ctypes import c_short
from ctypes import c_int
from ctypes import c_long
from ctypes import c_byte
from ctypes import c_wchar_p


EightBytes = c_byte * 8


class GUID(Structure):
    _fields_ = [
                ("Data1", c_long),
                ("Data2", c_short),
                ("Data3", c_short),
                ("Data4", EightBytes)
    ]


# KNOWNFOLDERID for "Documents" folder. (Knownfolders.h)
# Works only for Windows Vista and later.
FOLDERID_Documents = GUID(
    0xFDD39AD0,
    0x238F,
    0x46AF,
    EightBytes(
            0xAD, 0xB4, 0x6C, 0x85,
            0x48, 0x03, 0x69, 0xC7
            ))

path = c_wchar_p(chr(0x00) * 256)

# Use new function if it's available.
if hasattr(windll.shell32, 'SHGetKnownFolderPath'):
    windll.shell32.SHGetKnownFolderPath(
                                        byref(FOLDERID_Documents),
                                        0,
                                        None,
                                        byref(path)
                                        )

# Resort to the older function if the newer isn't available (Windows XP).
# XXX: Not much error checking around here, is it?
else:
    # XXX: Document header files where all this comes from.
    TOKEN_READ = 0x00020000L | 0x0008
    # Works for Windows XP.
    CSIDL_PERSONAL = 0x0005

    acces_token = c_int()

    windll.advapi32.OpenProcessToken(
                                    windll.kernel32.GetCurrentProcess(),
                                    TOKEN_READ,
                                    byref(acces_token)
                                    )

    windll.shell32.SHGetFolderPathW(
                                    None,
                                    CSIDL_PERSONAL,
                                    acces_token,
                                    0, # Retrieve the actual path.
                                    path
                                    )

    windll.kernel32.CloseHandle(acces_token)


# Assume ~\Documents\WindowsPowerShell\Modules is in $PSModulePath, which
# should be true in a default installation of PowerShell 2.0.
ps_modules = os.path.join(path.value, 'WindowsPowerShell', 'Modules')
data_target = os.path.join(ps_modules, 'VirtualEnvWrapper')
data_target2 = os.path.join(data_target, 'Extensions')

data_files = [
    (data_target, ['virtualenvwrapper/VirtualEnvWrapper.psm1']),
    (data_target, ['virtualenvwrapper/VirtualEnvWrapper.psd1']),
    (data_target, ['virtualenvwrapper/Win.psm1']),
    (data_target, ['virtualenvwrapper/Support.psm1']),
    (data_target, ['virtualenvwrapper/VirtualenvWrapperTabExpansion.psm1']),
    (data_target2, ['virtualenvwrapper/Extensions/Extension.UserScripts.ps1']),
    (data_target2, ['virtualenvwrapper/Extensions/Extension.Project.ps1']),
    (os.path.join(data_target, 'en-US'), ['virtualenvwrapper/en-US/about_virtualenvwrapper_powershell.help.txt']),
    (os.path.join(data_target, 'en-US'), ['virtualenvwrapper/en-US/about_virtualenvwrapper_powershell_extensions.help.txt']),
]
# =============================================================================

################################################################################
# find_package_data is an Ian Bicking creation.

# Provided as an attribute, so you can append to these instead
# of replicating them:
standard_exclude = ('*.py', '*.pyc', '*~', '.*', '*.bak', '*.swp*')
standard_exclude_directories = ('.*', 'CVS', '_darcs', './build',
                                './dist', 'EGG-INFO', '*.egg-info')

def find_package_data(
    where='.', package='',
    exclude=standard_exclude,
    exclude_directories=standard_exclude_directories,
    only_in_packages=True,
    show_ignored=False):
    """
    Return a dictionary suitable for use in ``package_data``
    in a distutils ``setup.py`` file.

    The dictionary looks like::

        {'package': [files]}

    Where ``files`` is a list of all the files in that package that
    don't match anything in ``exclude``.

    If ``only_in_packages`` is true, then top-level directories that
    are not packages won't be included (but directories under packages
    will).

    Directories matching any pattern in ``exclude_directories`` will
    be ignored; by default directories with leading ``.``, ``CVS``,
    and ``_darcs`` will be ignored.

    If ``show_ignored`` is true, then all the files that aren't
    included in package data are shown on stderr (for debugging
    purposes).

    Note patterns use wildcards, or can be exact paths (including
    leading ``./``), and all searching is case-insensitive.
    
    This function is by Ian Bicking.
    """

    out = {}
    stack = [(convert_path(where), '', package, only_in_packages)]
    while stack:
        where, prefix, package, only_in_packages = stack.pop(0)
        for name in os.listdir(where):
            fn = os.path.join(where, name)
            if os.path.isdir(fn):
                bad_name = False
                for pattern in exclude_directories:
                    if (fnmatchcase(name, pattern)
                        or fn.lower() == pattern.lower()):
                        bad_name = True
                        if show_ignored:
                            print >> sys.stderr, (
                                "Directory %s ignored by pattern %s"
                                % (fn, pattern))
                        break
                if bad_name:
                    continue
                if os.path.isfile(os.path.join(fn, '__init__.py')):
                    if not package:
                        new_package = name
                    else:
                        new_package = package + '.' + name
                    stack.append((fn, '', new_package, False))
                else:
                    stack.append((fn, prefix + name + '/', package, only_in_packages))
            elif package or not only_in_packages:
                # is a file
                bad_name = False
                for pattern in exclude:
                    if (fnmatchcase(name, pattern)
                        or fn.lower() == pattern.lower()):
                        bad_name = True
                        if show_ignored:
                            print >> sys.stderr, (
                                "File %s ignored by pattern %s"
                                % (fn, pattern))
                        break
                if bad_name:
                    continue
                out.setdefault(package, []).append(prefix+name)
    return out
################################################################################
    

setup(
    name = PROJECT,
    version = VERSION,
    
    description = "Enhancements to virtualenv (for Windows). A clone of Doug Hellmann's virtualenvwrapper",
    long_description = long_description,
    
    author = 'Guillermo López',
    author_email = 'guilan70@hotmail.com',

    url = 'https://bitbucket.org/guillermooo/%s/overview' % PROJECT,

    classifiers = [ 'Development Status :: 4 - Beta',
                    'License :: OSI Approved :: BSD License',
                    'Programming Language :: Python',
                    'Programming Language :: Python :: 2.6',
                    'Intended Audience :: Developers',
                    'Environment :: Console',
                    ],

    platforms = ['Windows XP', 'Windows Vista', 'Windows 7'],

    scripts = [],

    # install_requires=['virtualenv', 'virtualenvwrapper>=2.6'],

    # namespace_packages = [ 'virtualenvwrapper' ],
    # packages = find_packages(),
    include_package_data = True,
    # Scan the input for package information
    # to grab any data files (text, images, etc.) 
    # associated with sub-packages.
    # package_data = find_package_data(PROJECT, 
    #                                  package=PROJECT,
    #                                  only_in_packages=False,
    #                                  ),
    zip_safe=False,
    data_files=data_files
    )
