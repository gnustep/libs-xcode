# XCode lib manual

This manual is intended as a guide to using the libs-xcode library along with buildtool, it's command line front-end.   This library and tool were written for the purpose of allowing the user to easily build xcode projects on any other platform that GNUstep currently supports.

## Property list values

With any project it is possible to use a propertly list file called buildtool.plist.  This propery file allows you to set specific paramters to alter the behavior of the build for whatever platform you are building on.

An example property list is here: 

```
{
    target = "msvc";

    setupScript = "/home/gregc/Scripts/setup_env.sh";

    buildType = "parallel";

    "# Comment" = "This target name maps to the above...";
    msvc = {
		additional = (
			   "-lgdi32",
		);
		copylibs = YES;
		ignored = ( "VideoToolbox", "CoreMedia" );
    }; 
        
    headerPaths = (	"/home/gregc/headers" );

    remappedSource = { "ASourceFile.m" = "AlternateSourceFile.m"; };

    skippedTarget = ( "ASkippedTargetName" );

	mapped = { "curl" = "-llibcurl"; };

    ignored = ( "ssh2" );

    substitutions = { "-lSomeLibrary" = "-lSubtituteLib"; "-lAnotherLib" = ""; };

    additional = ( "-lAdditionalLib" );

    linkerPaths = ( "/c/src/vcpkg/installed/x64-windows/lib" );

    additionalCFlags = "-DSOME_DEFINE";
}
```

The property list contains the following elements, many of which are fairely self explanitory:

* ```target``` = the values of this can be "msvc", "linux", or "msys2" usually this is left blank.   It is usually only specified when building on msvc (or VisualStudio) targets since buildtool/xcode can't currently detect if you are using msvc automatically.  The need for this parameter might become obsolete.

* ```setupScript``` = This is a script which is run before the build is done.   In this case it is used to set up a new environment for buildtool/xcode to use to build the application.  This is done, for instance, to set up paths for alternate tool chains (Android/VisualStudio/etc).

* ```TargetName``` = In our example this is a proxy for whatever target you need to set up specific parameters for.  For example if your target is named "Foo" replace "TargetName" with that name.   This dictionary can contain all of the same entries as the parent list, but they will only be applied to the given target

* ```buildType``` = The values for this are "linear" and "parallel".  A linear build builds the files one by one, the parallel mode builds on all available processors unless otherwise specified.

* ```cpus``` = This specifies the number of cpus to use in a parallel build.

* ```copylibs``` = YES / NO - If YES then the tool will copy shared libraries into the .app folder (presuming you're building an application or other bundle) when the build completes.

* ```ignored``` = Ignore a given set (array) of frameworks or libraries when linking.

* ```headerPaths``` = An array of additional header paths to add when building.

* ```remappedSource	``` = A dictionary of source files to remap.  Remapping a file causes the file it is mapped to to build instead.  This is useful for GNUstep specific code.

* ```skippedTarget``` = An array of targets to skip.

* ```linkerPaths``` = An array of additional paths to check when linking.  This adds -L directives to the compiler invocation.

* ```additionalCFlags``` = A string that contains any additional C flags that need to be added.

* ```substitutions``` = An dictionary containing mappings of a library to a given library on your architecture.  Mapping a library to "" is equivalent to adding it to the ```ignored``` array.

* ```additional``` = An array containing more libraries to be added

### Planned for the future:

* For ```buildType``` the value distributed will be used to send files to build "servers" to help speed up the build.  In this case the ```cpus``` setting will be used to determine the number of servers to use.

### Also planned:

Work on the YCode application is planned in the near future.  Currently it is a stub, but it should start seeing serious development in 2023.

### Maintainer

The maintainer of this package is Gregory John Casamento <greg.casamento@gmail.com>

### How to contribute

You can submit patches on the github page.   I usually respond quickly to updates and changes.  Report any bugs there as well.
