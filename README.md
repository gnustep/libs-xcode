# libs-xcode

[![CI](https://github.com/gnustep/libs-xcode/actions/workflows/main.yml/badge.svg)](https://github.com/gnustep/libs-xcode/actions/workflows/main.yml?query=branch%3Amaster)

1 README
==

The GNUstep Xcode Library is a library for building xcode projects. 
It can be used to parse and provide information regarding an 
xcode project or used to build an xcode project directly.

1.1 License
===========

The GNUstep libraries and library resources are covered under the GNU
Lesser General Public License.  This means you can use these libraries 
in any program (even non-free programs). If you distribute the libraries 
along with your program, you must make the improvements you have made to 
the libraries freely available. You should read the COPYING.LIB file for
more information. 

1.2 How to use
==============

To use this library you need to build it and install it and then compile
the front-end which is in the Tools directory and is called buildtool.  
Simply go into a directory which contains an Xcode project and type buildtool 
and it should build the project.  If it doesn't then submit a bug.  
Currently GNUstep can only build projects for macOS.  Once support for UIKit and
other frameworks are available, those will be added.

1.2.1 Plans for the future
==========================

  * Create delegate which will provide a way for the library to
  execute callbacks into the caller so that information can be shown.
  This should eliminate the need to print anything in the library as all
  of the printing will be done on the front end based on information sent
  back by the library to the delegate.
  * Add more options to how the build is run so that the caller can specify
  which target should be built.
  * Add support for translated to .pcproj files.
  
1.2.2 Documentation
===================
I am working on a manual as well as gsdocs for the code so that the library is
properly documented.  There is a manual for buildtool.plist settings and other 
information in the Documentation directory of this project.

1.3 How can you help?
=====================

   * Give us feedback!  Tell us what you like; tell us what you think
     could be better.

     Please log bug reports on the GNUstep project page
     `https://github.com/gnustep/libs-xcode/issues` or send bug reports
     to <bug-gnustep@gnu.org>.

     Happy hacking!

   Copyright (C) 2005 Free Software Foundation

   Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.

