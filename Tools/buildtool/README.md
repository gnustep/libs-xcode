buildtool
--
The purpose of this tool is to duplicate the functionality of xcodebuild.
The associated library for this tool is libs-xcode.   This library provides
the means of parsing and "executing" the build.

This tool is a simple front-end to the XCode library.  It provides
the user with a simple interface with which to build xcode projects.

How to use it:
----
1) Go into an Xcode project directory.
2) type "buildtool"
   * by default, buildtool executes its 'build' sub-command
   that builds the Xcode project using the build phases and
   settings defined there
3) buildtool will create a build directory with the following structure:
   * ```build/$(TARGET_NAME)/Products/$(PRODUCT_NAME).app```

The tool will copy all the resources into the directory for the application.
The above is simply an example, you can build any kind of target based on the
frameworks we have.

Other sub-commands for buildtool include:
* generate - the purpose of generate is to translate the Xcode
  project file into a GNUmakefile
* clean - this cleans the build directory
* install - this installs the built targets
* link - this links the built targets
* save - this saves the parsed project into a new project directory

buildtool accepts these xcodebuild-style options in addition to the
sub-commands above:

* ```-project <path>``` - build an ```.xcodeproj```.
* ```-workspace <path>``` - build an ```.xcworkspace```.
* ```-target <name>``` - build only the named target.
* ```-scheme <name>``` - accepted as a target-name alias when no
  ```-target``` is supplied.
* ```-configuration <name>``` - use the named build configuration.
* ```-alltargets``` - build all targets, even when a target or scheme is
  supplied.
* ```-sdk <sdk>```, ```-arch <arch>```, ```-destination <destination>```,
  ```-derivedDataPath <path>```, ```-archivePath <path>```, ```-jobs <count>```,
  ```-parallelizeTargets```, ```-quiet```, ```-verbose```, ```-list```, and
  ```-showBuildSettings``` are accepted for command-line compatibility.

Examples:

```
buildtool -project MyApp.xcodeproj
buildtool -workspace MyWorkspace.xcworkspace
buildtool -project MyApp.xcodeproj -target MyApp -configuration Debug
buildtool -project MyApp.xcodeproj clean
buildtool -project MyApp.xcodeproj generate make
```

XCode
----
This library is what makes the above command work.  I separated it out into
a lib so that it could easily be leveraged by applications that might want
to use it to build targets and also to get information about xcode projects.

Please enjoy using and testing these as I have enjoyed creating them.
Please do not hesistate to report bugs in their respective repos.
