// Released under the terms of LGPL 2.1, Please see COPYING.LIB

#import "GSXCCMakeGenerator.h"
#import "PBXNativeTarget.h"
#import "XCConfigurationList.h"
#import "PBXBuildFile.h"
#import "PBXFileReference.h"
#import "NSString+PBXAdditions.h"

@interface GSXCCMakeGenerator (Private)
- (void) createInfoPlist;
@end

@implementation GSXCCMakeGenerator

- (instancetype) init
{
  self = [super init];

  if (self != nil)
    {
      _append = NO;
      _projectName = nil;
      _projectType = nil;
    }
  
  return self;
}

- (NSString *) cmakePreamble
{
  NSString *output = @"";
  NSString *header = [NSString stringWithFormat: @"## CMake Generated by buildtool - %@\n\n", _projectName];
  NSString *project = [NSString stringWithFormat: @"project(%@ C CXX)\n", _projectName];
  NSString *ccompiler = [NSString stringForCommand: @"gnustep-config --variable=CC"];
  NSString *cxxcompiler = [NSString stringForCommand: @"gnustep-config --variable=CXX"];
  
  output = [output stringByAppendingString: header];
  output = [output stringByAppendingString: @"## Begin header\n"];
  output = [output stringByAppendingString: @"cmake_minimum_required(VERSION 3.13)\n"];
  output = [output stringByAppendingString: @"set(CMAKE_EXPORT_COMPILE_COMMANDS ON)\n"];
  output = [output stringByAppendingString: @"if (EXISTS CMake/common.cmake)\n  include(CMake/common.cmake)\nendif()\n"];
  output = [output stringByAppendingString: @"set(CMAKE_CXX_STANDARD 11)\n"];
  output = [output stringByAppendingString: [NSString stringWithFormat: @"set(CMAKE_C_COMPILER \"%@\")\n", ccompiler]]; // These should be set dynamically...
  output = [output stringByAppendingString: [NSString stringWithFormat: @"set(CMAKE_CXX_COMPILER \"%@\")\n", cxxcompiler]]; // So should this one...
  output = [output stringByAppendingString: project];
  output = [output stringByAppendingString: @"set(BUILD_FOLDER_NAME \"build\")\n"];
  output = [output stringByAppendingString: @"set(CMAKE_SOURCE_DIR \".\")\n\n"];

  return output;
}

- (NSString *) cmakeSourceFiles: (NSArray *)array
{
  NSString *output = @"";
  NSEnumerator *en = [array objectEnumerator];
  NSString *file = nil;
  
  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @"# Begin sources\n"];

      if (_append == NO)
	{
	  output = [output stringByAppendingString: @"set (SOURCES\n"];
	  _append = YES;
	}
      else
	{
	  output = [output stringByAppendingString: @"list (APPEND SOURCES\n"];
	}
    }
  
  while((file = [en nextObject]) != nil)
    {
      output = [output stringByAppendingString: [NSString stringWithFormat: @"  ${CMAKE_SOURCE_DIR}/%@\n", file]];
    }

  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @")\n\n"];
      output = [output stringByAppendingString: @"if (EXISTS CMake/sources.cmake)\n  include(CMake/sources.cmake)\nendif()\n\n"];
    }
  
  return output;
}

- (NSString *) cmakeHeaderFiles: (NSArray *)array
{
  NSString *output = @"";
  NSEnumerator *en = [array objectEnumerator];
  id file = nil;
  
  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @"# Begin headers\n"];
      output = [output stringByAppendingString: @"set (HEADERS\n"];
    }
  
  while((file = [en nextObject]) != nil)
    {
      if ([file isKindOfClass: [PBXBuildFile class]])
	{
	  output = [output stringByAppendingString: [NSString stringWithFormat: @"  ${CMAKE_SOURCE_DIR}/%@\n", [file buildPath]]];
	}
      else if ([file isKindOfClass: [NSString class]])
	{
	  output = [output stringByAppendingString: [NSString stringWithFormat: @"  ${CMAKE_SOURCE_DIR}/%@\n", file]];	  
	}
    }
  
  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @")\n\n"];

      if ([_projectType isEqualToString: @"library"])
	{
	}
      else if ([_projectType isEqualToString: @"framework"])
	{
	  output = [output stringByAppendingString:
			     [NSString stringWithFormat: @"file(COPY ${HEADERS} DESTINATION \"%@.framework/Headers\")\n",
				       _projectName]];
	}
      
      output = [output stringByAppendingString: @"if (EXISTS CMake/headers.cmake)\n  include(CMake/headers.cmake)\nendif()\n\n"];
    }
  
  return output;
}

- (NSString *) cmakeLibraryFiles: (NSArray *)array
{
  NSString *output = @"";

  if ([_projectType isEqualToString: @"application"])
    {
    }
  else if ([_projectType isEqualToString: @"bundle"])
    {
    }
  else if ([_projectType isEqualToString: @"library"])
    {
    }
  else if ([_projectType isEqualToString: @"tool"])
    {
    }

  return output;  
}

- (NSString *) cmakeResourceFiles: (NSArray *)array
{
  NSString *output = @"";
  NSString *file = nil;

  if ([_projectType isEqualToString: @"tool"] || array == nil || [array count] == 0)
    {
      return @"";
    }

  // handle info plist file...
  NSMutableArray *resources = [NSMutableArray arrayWithArray: array];
  NSString *infoPlistName = [NSString stringWithFormat: @"%@Info.plist", _projectName];
  NSEnumerator *en = [resources objectEnumerator];

  [resources removeObject: infoPlistName]; // remove the plist if it exists...
  [resources addObject: @"Info-gnustep.plist"];

  [self createInfoPlist];
  
  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @"# Begin resources\n"];
      output = [output stringByAppendingString: @"set (GLOBAL_RESOURCES\n"];
    }
  
  while((file = [en nextObject]) != nil)
    {
      output = [output stringByAppendingString: [NSString stringWithFormat: @"  ${CMAKE_SOURCE_DIR}/%@\n", file]];
    }

  if ([array count] > 0)
    {
      output = [output stringByAppendingString: @")\n\n"];
      output = [output stringByAppendingString: @"if (EXISTS CMake/resources.cmake)\n  include(CMake/resources.cmake)\nendif()\n\n"];      
    }
  
  return output;
}

- (NSString *) cmakeDeclareProject
{
  NSString *output = @"# Copy resources\n";

  if ([_projectType isEqualToString: @"application"])
    {
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"set_target_properties(%@ PROPERTIES RUNTIME_OUTPUT_DIRECTORY \"%@.app\")\n",
				   _projectName, _projectName]];
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"file(COPY ${GLOBAL_RESOURCES} DESTINATION \"%@.app/Resources\")\n",
				   _projectName]];
    }
  else if ([_projectType isEqualToString: @"bundle"])
    {
      NSString *bundleName = @"bundle"; // this should be set by a variable/setting.
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"set_target_properties(%@ PROPERTIES RUNTIME_OUTPUT_DIRECTORY \"%@.%@\")\n",
				   _projectName, _projectName, bundleName]];
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"file(COPY ${GLOBAL_RESOURCES} DESTINATION \"%@.%@/Resources\")\n",
				   _projectName, bundleName]];
    }
  else if ([_projectType isEqualToString: @"framework"])
    {
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"set_target_properties(%@ PROPERTIES RUNTIME_OUTPUT_DIRECTORY \"%@.framework\")\n",
				   _projectName, _projectName]];
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"file(COPY ${GLOBAL_RESOURCES} DESTINATION \"%@.framework/Resources\")\n",
				   _projectName]];
    }
  else // if ([_projectType isEqualToString: @"tool"]) // ([_projectType isEqualToString: @"library"])
    {
      output = [output stringByAppendingString:
			 [NSString stringWithFormat: @"set_target_properties(%@ PROPERTIES RUNTIME_OUTPUT_DIRECTORY .)\n",
				   _projectName]];
    }

  return output;
}

- (NSString *) cmakeIncludeDirList: (NSArray *)includeArray
{
  NSString *output = [NSString stringWithFormat: @"# Include directories\ntarget_include_directories(%@ PRIVATE\n", _projectName];
  NSEnumerator *en = [includeArray objectEnumerator];
  NSString *includeDir = nil;

  while ((includeDir = [en nextObject]) != nil)
    {
      output = [output stringByAppendingString: [NSString stringWithFormat: @"  %@\n", includeDir]];
    }

  // Add canonical directories...
  NSString *localIncludes = [NSString stringForCommand: @"gnustep-config --variable=GNUSTEP_LOCAL_HEADERS"];
  output = [output stringByAppendingString: [NSString stringWithFormat: @"  %@\n", localIncludes]];
  
  NSString *systemIncludes = [NSString stringForCommand: @"gnustep-config --variable=GNUSTEP_SYSTEM_HEADERS"];
  output = [output stringByAppendingString: [NSString stringWithFormat: @"  %@\n", systemIncludes]];

  // Close declaration...
  output = [output stringByAppendingString: @")\n\n"];
  output = [output stringByAppendingString: @"if (EXISTS CMake/include.cmake)\n  include(CMake/include.cmake)\nendif()\n\n"];
  
  return output;
}

- (NSString *) cmakeTargetCompileOptions
{
  NSString *output = [NSString stringWithFormat: @"# Compile options\n"
			       @"target_compile_options(%@ PRIVATE ", _projectName];
  NSString *command = [NSString stringForCommand: @"gnustep-config --objc-flags"];

  output = [output stringByAppendingString: command];
  output = [output stringByAppendingString: @")\n\n"];
  
  return output;
}

- (NSString *) cmakeTargetLinkOptions
{
  NSString *output = [NSString stringWithFormat: @"# Link options\n"
			       @"target_link_options(%@ PRIVATE ", _projectName];
  NSString *command = nil;

  if ([_projectType isEqualToString: @"application"])
    {
      command = [NSString stringForCommand: @"gnustep-config --gui-libs"];      
    }
  else if ([_projectType isEqualToString: @"bundle"])
    {
      command = [NSString stringForCommand: @"gnustep-config --base-libs"];      
    }
  else if ([_projectType isEqualToString: @"library"])
    {
      command = [NSString stringForCommand: @"gnustep-config --base-libs"];      
    }
  else if ([_projectType isEqualToString: @"framework"])
    {
      command = [NSString stringForCommand: @"gnustep-config --base-libs"];      
    }
  else // tool
    {
      command = [NSString stringForCommand: @"gnustep-config --base-libs"];            
    }

  output = [output stringByAppendingString: command];
  output = [output stringByAppendingString: @")\n\n"];
  output = [output stringByAppendingString: @"if (EXISTS CMake/link.cmake)\n  include(CMake/link.cmake)\nendif()\n\n"];  
  
  return output;
}

- (NSString *) cmakeDeclareTarget
{
  NSString *output = @"";

  output = [output stringByAppendingString:
		     [NSString stringWithFormat:
				 @"# Declare target\n"
			       @"add_executable(\n"
			       @"  %@\n"
			       @"  ${SOURCES}\n"
			       @")\n\n", _projectName]];

  return output;
}

// TODO: Need to find a way to make this a common function....
- (BOOL) processInfoPlistInput: (NSString *)inputFileName
                        output: (NSString *)outputFileName
{
  if (inputFileName != nil)
    {
      GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
      NSString *settings = [context objectForKey: @"PRODUCT_SETTINGS_XML"];
      if(settings == nil)
        {
          NSString *inputFileString = [NSString stringWithContentsOfFile: inputFileName];
          NSString *outputFileString = [inputFileString stringByReplacingEnvironmentVariablesWithValues];
          NSMutableDictionary *plistDict = [NSMutableDictionary dictionaryWithDictionary: [outputFileString propertyList]];
          // NSString *filename = [self processAssets];
	  /*
          if (filename != nil)
            {
              [plistDict setObject: filename forKey: @"NSIcon"];
            }
	  */
          [plistDict writeToFile: outputFileName
                      atomically: YES];
          
          NSDebugLog(@"%@", plistDict);
        }
      else
        {
          [settings writeToFile: outputFileName
                     atomically: YES
                       encoding: NSUTF8StringEncoding
                          error: NULL];      
        }
    }
  else
    {
      NSArray *keys = [NSArray arrayWithObjects: @"NSPrincipalClass", @"NSMainNibFile", nil];
      NSArray *objs = [NSArray arrayWithObjects: @"NSApplication", @"MainMenu", nil];
      NSDictionary *ipl = [NSDictionary dictionaryWithObjects: objs
                                                      forKeys: keys];
      [ipl writeToFile: outputFileName
            atomically: YES];
    }
  
  return YES;
}

- (void) createInfoPlist
{
  if ([_projectType isEqualToString: @"tool"])
    {
      return;
    }
  
  NSString *inputFileName = [NSString stringWithFormat: @"%@Info.plist", _projectName];
  [self processInfoPlistInput: inputFileName output: @"Info-gnustep.plist"];
}

- (BOOL) generate
{
  BOOL result = YES;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *projectType = [context objectForKey: @"PROJECT_TYPE"];
  NSString *name = [_target name];
  NSString *projName = [name stringByDeletingPathExtension];
  NSString *outputName = @"CMakeLists.txt";
  NSString *outputString = @"";

  // Assign to ivars...
  ASSIGN(_projectType, projectType);
  ASSIGN(_projectName, projName);
  
  // Construct the makefile out of the data we have thusfar collected.
  xcputs("\t* Generating CMakeLists.txt...");

  // Sometimes the build will generate all of the target makefiles in one place,
  // depending on the version of Xcode the project was created with.
  if([[NSFileManager defaultManager] fileExistsAtPath: @"CMakeLists.txt"])
    {
      // if it collides with the existing name, add the target name...
      outputName = [outputName stringByAppendingString: [NSString stringWithFormat: @"_%@.txt", _projectName]];
    }

  // Initial setup...
  outputString = [self cmakePreamble];

  // Add sources...
  outputString = [outputString stringByAppendingString:
                                [self cmakeSourceFiles: [context objectForKey: @"OBJC_FILES"]]];
  outputString = [outputString stringByAppendingString:
                                [self cmakeSourceFiles: [context objectForKey: @"C_FILES"]]];
  outputString = [outputString stringByAppendingString:
                                [self cmakeSourceFiles: [context objectForKey: @"CPP_FILES"]]];
  outputString = [outputString stringByAppendingString:
                                [self cmakeSourceFiles: [context objectForKey: @"OBJCPP_FILES"]]];
  
  // Declare target
  outputString = [outputString stringByAppendingString: [self cmakeDeclareTarget]];

  // Headers
  outputString = [outputString stringByAppendingString:
				[self cmakeHeaderFiles: [context objectForKey: @"HEADERS"]]];

  outputString = [outputString stringByAppendingString:
			       [self cmakeLibraryFiles: [context objectForKey: @"ADDITIONAL_OBJC_LIBS"]]];
  // Include dirs
  outputString = [outputString stringByAppendingString: [self cmakeIncludeDirList: nil]];
  
  // Resources
  outputString = [outputString stringByAppendingString:
			      [self cmakeResourceFiles: [context objectForKey: @"RESOURCES"]]];

  // Compile options...
  outputString = [outputString stringByAppendingString: [self cmakeTargetCompileOptions]];
  
  // Link options...
  outputString = [outputString stringByAppendingString: [self cmakeTargetLinkOptions]];
  
  // Handle project type... this builds the directory structure needed for a given type.
  outputString = [outputString stringByAppendingString: [self cmakeDeclareProject]];
  
  
  NSDebugLog(@"output = %@", outputString);
  [outputString writeToFile: outputName atomically: YES];
  xcputs([[NSString stringWithFormat: @"=== Completed generation for target %@", name] cString]);

  return result; 
}

@end
