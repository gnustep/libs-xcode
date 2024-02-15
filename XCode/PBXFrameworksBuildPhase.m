/*
   Copyright (C) 2018, 2019, 2020, 2021 Free Software Foundation, Inc.

   Written by: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2022
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "NSString+PBXAdditions.h"
#import "PBXTarget.h"

#import "GSXCCommon.h"

#import <Foundation/NSPathUtilities.h>

@implementation PBXFrameworksBuildPhase

- (NSString *) _gsConfigString
{
  NSString *configString = nil;
  
  configString = @"gnustep-config";
    
  return configString;
}

- (NSString *) linkerForBuild
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  BOOL linkWithCpp = [[context objectForKey: @"LINK_WITH_CPP"] isEqualToString: @"YES"];
  NSString *compiler = [NSString stringWithFormat: @"`%@ --variable=CC`", [self _gsConfigString]];

  if (linkWithCpp)
    {
      compiler = [NSString stringWithFormat: @"`%@ --variable=CXX`", [self _gsConfigString]];
    }

  return compiler;
}

- (NSString *) processOutputFilesString
{
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  return outputFiles;
}

- (void) generateDummyClass
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *executableName = [context objectForKey: @"EXECUTABLE_NAME"];
  NSString *outputDir = [[context objectForKey: @"PROJECT_ROOT"]
			  stringByAppendingPathComponent: @"derived_src"];
  NSString *fileName = [NSString stringWithFormat: @"NSFramework_%@.m",executableName];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: fileName];
  NSString *buildDir = [context objectForKey: @"TARGET_BUILD_DIR"];
  NSString *objDir = [context objectForKey: @"BUILT_PRODUCTS_DIR"];
  NSString *scriptPath = [[NSBundle bundleForClass: [self class]]
			   pathForResource: @"create-dummy-class" ofType: @"sh"];
  NSString *of = [self processOutputFilesString];
  NSString *outputFiles = (of == nil)?@"":of;
  NSString *files = [outputFiles stringByReplacingOccurrencesOfString: @"'" withString: @""];
  
  objDir = (objDir == nil) ? buildDir : objDir;

  BOOL f = NO;
  NSString *classesCommand = [NSString stringWithFormat: @"%@ '%@' '%@'", scriptPath, files, executableName];  
  // NSLog(@"classesCommand = %@\n", classesCommand); // [context currentContext]);
  f = xcsystem(classesCommand) == 0;

  if( f )
    {
      NSString *compiler = nil; 
      NSString *buildPath = outputPath;
      NSString *objPath = [objDir stringByAppendingPathComponent: [fileName stringByAppendingString: @".o"]];
      if([compiler isEqualToString: @""] || compiler == nil)
	{
	  compiler = [self linkerForBuild]; 
	}

      NSString *configString = [context objectForKey: @"CONFIG_STRING"]; 
      NSString *buildTemplate = @"%@ %@ -c %@ -o %@";
      NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
					 compiler,
					 [buildPath stringByEscapingSpecialCharacters],
					 configString,
					 [objPath stringByEscapingSpecialCharacters]];
      NSString *of = [self processOutputFilesString];
      NSString *outputFiles = (of == nil)?@"":of;
      //NSLog(@"\t%@ %@",buildCommand, outputFiles);
      BOOL success = xcsystem(buildCommand) == 0;
      if (success)
	{
	  outputFiles = [outputFiles stringByAppendingString: [NSString stringWithFormat: @" %@", objPath]];
	  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];
	}
      else
	{
	  NSLog(@"** build of framework dummy class failed.");
	}
    }
  else
    {
      NSLog(@"** failed to run dummy class generation script");
    }
}

- (NSString *) frameworkLinkString: (NSString*)framework
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *path = [[NSBundle bundleForClass: [self class]]
                     pathForResource: @"Framework-mapping" ofType: @"plist"];
  NSDictionary *propList = [[NSString stringWithContentsOfFile: path] propertyList];
  NSMutableArray *ignored = [[propList objectForKey: @"Ignored"] mutableCopy];
  NSMutableDictionary *mapped = [[propList objectForKey: @"Mapped"] mutableCopy];
  NSDictionary *configDict = [context configForTargetName: [[self target] name]];
  NSString *result = nil;
  NSString *fw = [framework copy];

  if ([fw hasPrefix: @"lib"])
    {
      fw = [fw stringByReplacingCharactersInRange: NSMakeRange(0,3)
				       withString: @""];
    }
  
  NSDebugLog(@"\t* config = %@", configDict);
  NSDebugLog(@"\t* target = %@", [[self target] name]);
  
  if ([configDict objectForKey: @"mapped"] != nil)
    {
      [mapped addEntriesFromDictionary: [configDict objectForKey: @"mapped"]];
    }
  
  if ([configDict objectForKey: @"ignored"] != nil)
    {
      [ignored addObjectsFromArray: [configDict objectForKey: @"ignored"]];
    }
  
  NSDebugLog(@"path = %@", path);
  NSDebugLog(@"%@", fw);

  if ([ignored containsObject: fw])
    {
      xcprintf("\t- Ignored: %s\n",[fw cString]);
      return @"";
    }
  else
    {
      NSDebugLog(@"%@ not found in %@", fw, ignored);
    }
  
  result = [mapped objectForKey: fw];
  if (result == nil)
    {
      result =  [NSString stringWithFormat: @"-l%@ ", fw];
      xcprintf("\t* Linking: %s\n", [result cString]);
    }
  else
    {
      result = [result stringByAppendingString: @" "];
      xcprintf("\t+ Remapped: %s -> %s\n", [fw cString], [result cString]);
    }
  
  return result;
} 

- (NSString *) linkString
{
  NSString *cfgString = [self _gsConfigString];
  NSString *systemLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_SYSTEM_LIBRARIES`", cfgString];
  NSString *localLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_LOCAL_LIBRARIES`", cfgString];
  NSString *userLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_USER_LIBRARIES`", cfgString];
  NSString *buildDir = [NSString stringForEnvironmentVariable: @"TARGET_BUILD_DIR" defaultValue: @"build"];
  NSString *uninstalledProductsDir = [buildDir stringByAppendingPathComponent: @"Products"];
  NSString *linkString = [NSString stringWithFormat: @"-L/usr/local/lib -L/opt/local/lib -L%@ -L%@ -L%@ ",
				   userLibDir,
				   localLibDir,
				   systemLibDir];;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSDirectoryEnumerator *dirEnumerator = [manager enumeratorAtPath:uninstalledProductsDir];
  NSEnumerator *en = [_files objectEnumerator];
  id file = nil;
  NSString *lpath = nil;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *configDict = [context configForTargetName: [[self target] name]];
  NSArray *linkerPaths = [configDict objectForKey: @"linkerPaths"];
  NSString *wsLink = [context objectForKey: @"WORKSPACE_LINK_LINE"];
  NSString *wsLibs = [context objectForKey: @"WORKSPACE_LIBS_LINE"];
  
  // If the workspace link string exists, add it...
  if (wsLink != nil)
    {
      linkString = [linkString stringByAppendingString: wsLink];
      NSDebugLog(@"linkString = %@", linkString);
    }
  
  if (wsLibs != nil)
    {
      linkString = [linkString stringByAppendingString: wsLibs];
      xcprintf("\t* Linking from Workspace: %s\n", [wsLibs cString]);
      NSDebugLog(@"linkString = %@", linkString);
    }
  
  en = [linkerPaths objectEnumerator];
  while((lpath = [en nextObject]) != nil)
    {
      linkString = [linkString stringByAppendingString: [NSString stringWithFormat: @"-L%@ ", lpath]];
    }
  
  en = [_files objectEnumerator];
  while((file = [en nextObject]) != nil)
    {
      PBXFileReference *fileRef = [file fileRef];
      NSString *name = [[[fileRef path] lastPathComponent] stringByDeletingPathExtension];
      
      linkString = [linkString stringByAppendingString: [self frameworkLinkString: name]];
    }

  // Find any frameworks and add them to the -L directive...
  while((file = [dirEnumerator nextObject]) != nil)
    {
      NSString *ext = [file pathExtension];
      if([ext isEqualToString:@"framework"])
	{
	  NSString *headerDir = [file stringByAppendingPathComponent:@"Headers"];
	  linkString = [linkString stringByAppendingString:
                                [NSString stringWithFormat:@"-I%@ ",
                                          [uninstalledProductsDir stringByAppendingPathComponent:headerDir]]];
	  linkString = [linkString stringByAppendingString:
                                [NSString stringWithFormat:@"-L%@ ",
                                          [uninstalledProductsDir stringByAppendingPathComponent:file]]];
	}
    }

  NSArray *otherLDFlags = [context objectForKey: @"OTHER_LDFLAGS"];
  NSDebugLog(@"OTHER_LDFLAGS = %@", otherLDFlags);
  en = [otherLDFlags objectEnumerator];
  while((file = [en nextObject]) != nil)
    {
      if ([file isEqualToString: @"-framework"])
        {
          NSString *framework = [en nextObject];
          linkString = [linkString stringByAppendingString: [self frameworkLinkString: framework]];
        }
    }

  // linkString = [linkString stringByAppendingString: @" -lpthread -lobjc -lm "];
  linkString = [linkString stringByAppendingString: @" -lobjc "];
  
  // Do substitutions and additions for buildtool.plist...
  NSDictionary *substitutionList = [configDict objectForKey: @"substitutions"];
  NSArray *additionalFlags = [configDict objectForKey: @"additional"];
  // NSNumber *flag = [configDict objectForKey: @"translateDylibs"];
  
  NSDebugLog(@"%@",configDict);
  NSDebugLog(@"%@", additionalFlags);
  if (additionalFlags != nil)
    {
      [context setObject: additionalFlags forKey: @"ADDITIONAL_OBJC_LIBS"];
    }
  
  // Replace anything that needs substitution... not all libraries on macos map directly...
  en = [[substitutionList allKeys] objectEnumerator];
  id o = nil;
  while ((o = [en nextObject]) != nil)
    {
      NSString *r = [substitutionList objectForKey: o];
      linkString = [linkString stringByReplacingOccurrencesOfString: o
                                                         withString: r];
    }

  // Add any additional libs...
  en = [additionalFlags objectEnumerator];
  o = nil;
  while ((o = [en nextObject]) != nil)
    {
      linkString = [linkString stringByAppendingFormat: @" %@ ", o];
      xcprintf("\t+ Additional: %s\n",[o cString]);
    }
  
  return linkString;
}

- (BOOL) buildTool
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *cfgString = [self _gsConfigString];

  xcputs([[NSString stringWithFormat: @"=== Executing Frameworks / Linking Build Phase (Tool)"] cString]);
  NSString *compiler = [self linkerForBuild];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  NSString *executableName = [context objectForKey: @"EXECUTABLE_NAME"];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  linkString = [linkString stringByAppendingString: [NSString stringWithFormat:
								@" `%@ --base-libs` `%@ --variable=LDFLAGS` -lgnustep-base ",
						     cfgString, cfgString]];

  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSUInteger os = [pi operatingSystem];
  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];
  
  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      outputPath = [outputPath stringByAppendingPathExtension: @"exe"];
      command = [NSString stringWithFormat: 
			    @"%@ -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
			  compiler, 
			  outputPath,
			  outputFiles,
			  linkString];
    }

  NSDebugLog(@"command = %@", command);
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      result = xcsystem(command);
      if (result != 0)
        {
          NSLog(@"%sReturn Value:%s %d", RED, RESET, result);
          NSLog(@"%sCommand:%s %s%@%s", RED, RESET, GREEN, command, RESET);
        }
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildApp
{
  xcputs("=== Executing Frameworks / Linking Build Phase (Application)");
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *compiler = [self linkerForBuild];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  // NSString *errorPath = [outputDir stringByAppendingPathComponent: @"linker.err"];
  NSString *executableName = [context objectForKey: @"EXECUTABLE_NAME"];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  NSString *cfgString = [self _gsConfigString];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSUInteger os = [pi operatingSystem];

  NSDebugLog(@"Output files = %@", outputFiles);

  if (outputFiles == nil)
    {
      xcputs("\t++++ No object files found. Nothing to link  ++++\n");
      return YES;
    }

  linkString = [NSString stringWithFormat: [linkString stringByAppendingString: @" `%@ --objc-flags --objc-libs " \
						       @"--base-libs --gui-libs` `%@ --variable=LDFLAGS` " \
						       @"-lgnustep-base -lgnustep-gui "], cfgString, cfgString];
  NSDebugLog(@"LINK: %@", linkString);
           
  NSString *command = nil;
  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      outputPath = [outputPath stringByAppendingPathExtension: @"exe"];
      command = [NSString stringWithFormat: 
			    @"%@ -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
			  compiler,
			  outputPath,
			  outputFiles,
			  linkString];
    }
  else
    {
      command = [NSString stringWithFormat: 
			    @"%@ -rdynamic -shared-libgcc -fgnu-runtime -o \"%@\" %@ %@",
			  compiler,
			  outputPath,
			  outputFiles,
			  linkString];
    }
  
  // NSLog(@"Link command = %@", command);
  // NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if(YES) // [modified isEqualToString: @"YES"])
    {
      xcputs([[NSString stringWithFormat: @"\t* Linking \"%@\"",outputPath] cString]);
      result = xcsystem(command);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for \"%@\", no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");
  fflush(stdout);
  
  return (result == 0);
}

- (NSString *) _execName
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *name = [context objectForKey: @"EXECUTABLE_NAME"];

  if( name == nil )
    {
      name = [context objectForKey: @"PRODUCT_NAME"];
      if ( name == nil )
	{
	  name = [context objectForKey: @"TARGET_NAME"];
	}
    }

  return name;
}

- (NSString *) _productOutputDir
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *outputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];

  if( outputDir == nil )
    {
      outputDir = [@"./build" stringByAppendingPathComponent: [self _execName]];
      outputDir = [outputDir stringByAppendingPathComponent: @"Products"];
    }

  return outputDir;
}

- (BOOL) buildStaticLib
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  // NSDictionary *config = [context config];
  // NSString *ctarget = [config objectForKey: @"target"];
  // NSString *libext = [ctarget isEqualToString: @"msvc"] ? @"lib" : @"a";
  // NSString *libpfx = [ctarget isEqualToString: @"msvc"] ? @"" : @"lib";
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [self _productOutputDir];
  NSString *executableName = [[[_target productReference] path] lastPathComponent];
  // [[NSString stringWithFormat: @"%@%@", libpfx,[self _execName]]
  //			       stringByReplacingPathExtensionWith: libext];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *commandTemplate = @"ar rc %@ %@; ranlib %@";
  NSString *command = [NSString stringWithFormat: commandTemplate,
				outputPath,
				outputFiles,
				outputPath];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;

  xcputs("=== Executing Frameworks / Archiving Build Phase (Static Library)");  
  if([modified isEqualToString: @"YES"])
    {
      xcputs([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);
      result = xcsystem(command);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");

  return (result == 0);
}

- (BOOL) buildDynamicLib
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *config = [context config];
  NSString *ctarget = [config objectForKey: @"target"];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  NSString *executableName = [context objectForKey: @"EXECUTABLE_NAME"];
  NSString *executableNameStripped = [executableName stringByDeletingPathExtension];
  NSString *libName = [NSString stringWithFormat: @"%@.so",executableNameStripped];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: libName];

  NSString *libraryPath = [outputDir stringByAppendingPathComponent: libName];
  NSString *cfgString = [self _gsConfigString];
  NSString *systemLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_SYSTEM_LIBRARIES`", cfgString];
  NSString *localLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_LOCAL_LIBRARIES`", cfgString];
  NSString *userLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_USER_LIBRARIES`", cfgString];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSUInteger os = [pi operatingSystem];
  NSString *compiler = [self linkerForBuild];
  NSString *command = nil;
  NSString *commandTemplate = nil;
  NSInteger result = 0;
  
  xcputs("=== Executing Frameworks / Linking Build Phase (Dynamic Library");
  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      if ([ctarget containsString: @"msvc"])
	{
	  outputPath = [outputPath stringByReplacingOccurrencesOfString: @"lib" withString: @""];

	  NSString *msvcLibname = [outputPath stringByAppendingPathExtension: @"lib"];
          NSString *dllLibname = [libraryPath stringByReplacingPathExtensionWith: @"dll"];
          
	  commandTemplate = @"%@ -g -Wl,-dll -Wl,implib:%@ -o %@ %@ `gnustep-config --base-libs` "	    
	    @"-L%@ -L%@ -L%@";
	  libraryPath = [outputDir stringByAppendingPathComponent: msvcLibname];

	  
	  command = [NSString stringWithFormat: commandTemplate,
			      compiler,
                              libraryPath,
                              dllLibname,
			      outputFiles,
			      userLibDir,
			      localLibDir,
			      systemLibDir];
	  
	}
      else
	{
	  commandTemplate = @"%@ -shared -Wl,-soname,lib%@.so " 
	    @"-shared-libgcc -o %@ %@ "
	    @"-L%@ -L%@ -L%@";
	  
	  
	  command = [NSString stringWithFormat: commandTemplate,
			      compiler,
			      executableName,
			      libraryPath,
			      outputFiles,
			      userLibDir,
			      localLibDir,
			      systemLibDir];
	}
    }
  else
    {
      commandTemplate = @"%@ -shared -Wl,-soname,lib%@.so  -rdynamic " 
        @"-shared-libgcc -o %@ %@ "
        @"-L%@ -L%@ -L%@";

      command = [NSString stringWithFormat: commandTemplate,
			  compiler,
			  executableName,
			  libraryPath,
			  outputFiles,
			  userLibDir,
			  localLibDir,
			  systemLibDir];
    }

  if([modified isEqualToString: @"YES"])
    {      
      xcputs([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);      
      result = xcsystem(command);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildFramework
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSDictionary *config = [context config];
  NSString *ctarget = [config objectForKey: @"target"];
  NSInteger result = 0;

  xcputs("=== Executing Frameworks / Linking Build Phase (Framework)");
  [self generateDummyClass];
  
  NSString *outputFiles = [self processOutputFilesString];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  NSString *outputDir = [context objectForKey: @"PRODUCT_OUTPUT_DIR"];
  NSString *executableName = [context objectForKey: @"EXECUTABLE_NAME"];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *frameworkVersion = [NSString stringForEnvironmentVariable: "FRAMEWORK_VERSION"];
  if (frameworkVersion == nil)
    {
      frameworkVersion = @"0";
    }
  NSString *libNameWithVersion =  [NSString stringWithFormat: @"lib%@.so.%@",
					    executableName,frameworkVersion];
  NSString *libName = [NSString stringWithFormat: @"lib%@.so",executableName];

  NSString *libraryPath = [outputDir stringByAppendingPathComponent: libNameWithVersion];
  NSString *libraryPathNoVersion = [outputDir stringByAppendingPathComponent: libName];
  NSString *cfgString = [self _gsConfigString];
  NSString *systemLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_SYSTEM_LIBRARIES`", cfgString];
  NSString *localLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_LOCAL_LIBRARIES`", cfgString];
  NSString *userLibDir = [NSString stringWithFormat: @"`%@ --variable=GNUSTEP_USER_LIBRARIES`", cfgString];
  NSString *frameworkRoot = [context objectForKey: @"FRAMEWORK_DIR"];
  NSString *libraryLink = [frameworkRoot stringByAppendingPathComponent: libName];
  NSString *execLink = [frameworkRoot stringByAppendingPathComponent: executableName];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSUInteger os = [pi operatingSystem];
  NSString *compiler = [self linkerForBuild];
  NSString *command = nil;
  NSString *commandTemplate = nil;
  
  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      if ([ctarget containsString: @"msvc"])
	{
	  NSString *msvcLibname = [outputPath stringByAppendingPathExtension: @"lib"];
          NSString *dllLibname = [libraryPathNoVersion stringByReplacingPathExtensionWith: @"dll"];
          
	  commandTemplate = @"%@ -g -Wl,-dll -Wl,implib:%@ -o %@ %@ "
	    @"-L%@ -L%@ -L%@ "
	    @"`gnustep-config --gui-libs` ";
	  libraryPath = msvcLibname;

	  
	  command = [NSString stringWithFormat: commandTemplate,
			      compiler,
                              libraryPath,
                              dllLibname,
			      outputFiles,
			      userLibDir,
			      localLibDir,
			      systemLibDir];
	  
	}
      else
	{
	  commandTemplate = @"%@ -shared -Wl,-soname,lib%@.so "
	    @"-shared-libgcc -o %@ %@ "
	    @"-L%@ -L%@ -L%@ "
	    @"`gnustep-config --gui-libs` ";
	  
	  command = [NSString stringWithFormat: commandTemplate,
			      compiler,
			      executableName,
			      libraryPath,
			      outputFiles,
			      userLibDir,
			      localLibDir,
			      systemLibDir];
	}
    }
  else
    {
      commandTemplate = @"%@ -shared -Wl,-soname,lib%@.so.%@  -rdynamic " 
        @"-shared-libgcc -o %@ %@ "
        @"-L%@ -L%@ -L%@";

      command = [NSString stringWithFormat: commandTemplate,
			  compiler,
			  executableName,
			  frameworkVersion,
			  libraryPath,
			  outputFiles,
			  userLibDir,
			  localLibDir,
			  systemLibDir];
    }
  

  // Create link to library...
  [[NSFileManager defaultManager] createSymbolicLinkAtPath: outputPath
					       pathContent: libName];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: libraryPathNoVersion
					       pathContent: libNameWithVersion];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: libraryLink
					       pathContent: 
				[NSString stringWithFormat: @"Versions/Current/%@",libName]];

  [[NSFileManager defaultManager] createSymbolicLinkAtPath: execLink
					       pathContent: 
				[NSString stringWithFormat: @"Versions/Current/%@",executableName]];


  // NSLog(@"Link command = %@", command);
  if([modified isEqualToString: @"YES"])
    {      
      xcputs([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);      
      result = xcsystem(command);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildBundle
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  xcputs("=== Executing Frameworks / Linking Build Phase (Bundle)");
  NSString *compiler = [self linkerForBuild];
  NSString *outputFiles = [self processOutputFilesString];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSUInteger os = [pi operatingSystem];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared -o \"%@\" %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  if (os == NSWindowsNTOperatingSystem || os == NSWindows95OperatingSystem)
    {
      command = [NSString stringWithFormat: 
			    @"%@ -shared  -o \"%@\" %@ %@",
			  compiler, 
			  outputPath,
			  outputFiles,
			  linkString];
    }
  
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int result = 0;
  if([modified isEqualToString: @"YES"])
    {
      xcputs([[NSString stringWithFormat: @"\t* Linking %@",outputPath] cString]);            
      result = xcsystem(command);
    }
  else
    {
      xcputs([[NSString stringWithFormat: @"\t** Nothing to be done for %@, no modifications.",outputPath] cString]);
    }

  xcputs("=== Frameworks / Linking Build Phase Completed");
  return (result == 0);
}

- (BOOL) buildTest
{
  xcputs("=== Build tests...  currently unsupported...");
  return YES;
}

- (BOOL) build
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productType = [context objectForKey: @"PRODUCT_TYPE"];
  if([productType isEqualToString: APPLICATION_TYPE])
    {
      return [self buildApp];
    }
  else if([productType isEqualToString: TOOL_TYPE])
    {
      return [self buildTool];
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      return [self buildStaticLib];
    }
  else if([productType isEqualToString: DYNAMIC_LIBRARY_TYPE])
    {
      return [self buildDynamicLib];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      return [self buildFramework];
    }
  else if([productType isEqualToString: BUNDLE_TYPE])
    {
      return [self buildBundle];
    }
  else if([productType isEqualToString: TEST_TYPE])
    {
      return [self buildTest];
    }
  else 
    {
      xcputs([[NSString stringWithFormat: @"***** ERROR: Unknown product type: %@",productType] cString]);
    }
  return NO;
}

- (BOOL) generate
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *productType = [context objectForKey: @"PRODUCT_TYPE"];
  NSDictionary *configDict = [context configForTargetName: [[self target] name]];
  NSArray *additionalFlags = [configDict objectForKey: @"additional"];
  
  NSDebugLog(@"%@", additionalFlags);
  if (additionalFlags != nil)
    {
      [context setObject: additionalFlags forKey: @"ADDITIONAL_OBJC_LIBS"];
    }

  xcprintf("\t* Adding product type entry: %s\n", [productType cStringUsingEncoding: NSUTF8StringEncoding]);
  
  if([productType isEqualToString: APPLICATION_TYPE])
    {
      [context setObject: @"application"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: TOOL_TYPE])
    {
      [context setObject: @"tool"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: LIBRARY_TYPE])
    {
      [context setObject: @"library"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: DYNAMIC_LIBRARY_TYPE])
    {
      [context setObject: @"library"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      [context setObject: @"framework"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: BUNDLE_TYPE])
    {
      [context setObject: @"bundle"
                  forKey: @"PROJECT_TYPE"];
    }
  else if([productType isEqualToString: TEST_TYPE])
    {
      [context setObject: @"test"
                  forKey: @"PROJECT_TYPE"];
    }
  else 
    {
      xcputs([[NSString stringWithFormat: @"***** ERROR: Unknown product type: %@",productType] cString]);
    }
  
  return YES;
}

- (BOOL) link
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];

  [context setObject: @"YES" forKey: @"MODIFIED_FLAG"];
  
  return [self build];
}

@end
