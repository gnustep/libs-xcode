# libs-xcode

[![CI](https://github.com/gnustep/libs-xcode/actions/workflows/main.yml/badge.svg)](https://github.com/gnustep/libs-xcode/actions/workflows/main.yml?query=branch%3Amaster)

## 1 README

The GNUstep Xcode Library is a library for building xcode projects.
It can be used to parse and provide information regarding an
xcode project or used to build an xcode project directly.

### 1.1 License

The GNUstep libraries and library resources are covered under the GNU
Lesser General Public License.  This means you can use these libraries
in any program (even non-free programs). If you distribute the libraries
along with your program, you must make the improvements you have made to
the libraries freely available. You should read the COPYING.LIB file for
more information.

For Applications we are using the LICENSE file (GPLv3) and we use COPYING.LIB
which is (LGPLv2.1) for the libraries/framworks.

### 1.2 Ycode

Ycode is the GNUstep graphical IDE included in this repository. It uses
libs-xcode to work with Xcode projects and also opens ProjectCenter projects
and folders containing a GNUmakefile or Makefile.

- Create applications, tools, bundles, frameworks, and libraries from templates;
  import and export ProjectCenter projects.
- Browse groups and files with directories first, image previews, and the icons
  of compiled applications. Double-click a file to open its default application,
  including Gorm for associated interface files.
- Edit source with syntax highlighting, configurable indentation (two spaces by
  default), project search, and a find/replace panel. **Edit > Convert Tabs to
  Spaces** normalizes the current file as one undoable edit. Modified files
  prompt to save when closing tabs, closing projects, or quitting.
- Build, run, clean, and run tests with target, configuration, and architecture
  selection. Console, Issues, and Test views show output and results.
- Debug with GDB using source breakpoints, stepping controls, and a command
  transcript. A resizable, hideable variables pane shows locals and globals
  from the selected frame's source file. Both Console and Debugger output can
  be selected and copied.
- Use **File > Create .ycode.plist** for a directory or ProjectCenter project
  without an existing settings file. Xcode projects do not use this command. The command creates and opens the file, preserving current
  settings, adding the runnable executable, and supplying default Clean and Test
  targets. If automatic detection is ambiguous, choose the executable in a file
  panel. Add build targets or architecture environments as needed.

![Ycode development environment](https://github.com/user-attachments/assets/0fa131b6-b02a-4870-bfd1-d2d78d511e27)

Build Ycode with an installed GNUstep development environment, including
GNUstep GUI:

```sh
make -C XCode
make -C Applications/ycode
```

The top-level `make` also builds Ycode. GDB is required for debugging; test
runners and toolchains depend on the project. See the [Ycode guide](Applications/ycode/README.md)
for installation, project formats, editing, debugging, tests, and `.ycode.plist`
configuration. Ycode uses GNUstep build tools and GDB; it does not provide
Apple's SDKs, simulators, signing, or the full Xcode toolchain.

### 1.3 How to use

To use this library you need to build it and install it and then compile
the front-end which is in the Tools directory and is called buildtool.  
Simply go into a directory which contains an Xcode project and type buildtool
and it should build the project.  If it doesn't then submit a bug.  
Currently GNUstep can only build projects for macOS.  Once support for UIKit and
other frameworks are available, those will be added.

buildtool also accepts xcodebuild-style options alongside its original
sub-commands.  The default action is `build`; `clean`, `install`, `generate`,
`link`, and `save` remain available.

Common examples:

```
buildtool -project MyApp.xcodeproj
buildtool -workspace MyWorkspace.xcworkspace
buildtool -project MyApp.xcodeproj -target MyApp -configuration Debug
buildtool -project MyApp.xcodeproj clean
buildtool -project MyApp.xcodeproj generate make
```

Supported xcodebuild-style options:

* `-project <path>` - build an `.xcodeproj`.
* `-workspace <path>` - build an `.xcworkspace`.
* `-target <name>` - build only the named target.
* `-scheme <name>` - accepted as a target-name alias when no `-target` is
  supplied.
* `-configuration <name>` - use the named build configuration.
* `-alltargets` - build all targets, even when a target or scheme is supplied.
* `-sdk <sdk>`, `-arch <arch>`, `-destination <destination>`,
  `-derivedDataPath <path>`, `-archivePath <path>`, `-jobs <count>`,
  `-parallelizeTargets`, `-quiet`, `-verbose`, `-list`, and
  `-showBuildSettings` are accepted for command-line compatibility.

Buildtool exits with status 0 on success and nonzero on a failed operation,
invalid project path, or exception. An explicit project path never falls back
to another project in the current directory.

#### 1.3.1 Native macOS build

With full Xcode installed and selected as the active developer directory,
build the framework and command-line tools against Apple's frameworks:

```sh
xcodebuild -project libs-xcode.xcodeproj \
  -target XCodeNative -target buildtool-native \
  -target pc2xc-native -target pcpg-native \
  -configuration Debug SYMROOT="$PWD/build/macos" CODE_SIGNING_ALLOWED=NO build
```

Products are in `build/macos/Debug`. Keep the command-line tools beside
`XCode.framework` so their runtime search paths can locate it. The native
targets use manual reference counting and do not require GNUstep or CocoaPods.
The other targets in this project, including `All`, invoke GNUstep make.

To build and run the regression tests and a buildtool startup check:

```sh
sh Tests/run-macos.sh
CONFIGURATION=Release sh Tests/run-macos.sh
```

Link clients against `XCode.framework` and import its public headers:

```
#import <XCode/XCode.h>
```

This native build supports using the project parsing library and tools on
macOS. Buildtool's project-building backend still uses GNUstep tools and
framework mappings; it is not a replacement for Apple's SDK build pipeline.

#### 1.3.2 Project generators and conversion

The library includes Makefile, CMake, ProjectCenter, and ProjectBuilder
output generators. `buildtool generate` selects an output format; the `pc2xc`
and `pcpg` tools provide additional project conversion and generation support.
See the [buildtool guide](Tools/buildtool/README.md) for command usage and
supported options.

#### 1.3.3 Documentation

The [documentation guide](Documentation/README.md) covers `buildtool.plist`
configuration and the manual. The [Ycode guide](Applications/ycode/README.md)
covers the graphical IDE and its separate `.ycode.plist` settings.

## 1.4 How can you help?

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
