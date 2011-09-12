#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "GSXCCommon.h"

@implementation PBXFrameworksBuildPhase

- (void) generateDummyClass
{
  NSString *frameworkPath = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Frameworks"];
  NSString *frameworkVersion = [NSString stringWithCString: getenv("FRAMEWORK_VERSION")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *classList = @"";
  NSString *outputDir = [[NSString stringWithCString: getenv("PROJECT_ROOT")] 
			  stringByAppendingPathComponent: @"derived_src"];
  NSString *fileName = [NSString stringWithFormat: @"NSFramework_%@.m",executableName];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: fileName];
  NSString *buildDir = [NSString stringWithCString: getenv("TARGET_BUILD_DIR")];
  NSString *objDir = [NSString stringWithCString: getenv("BUILT_PRODUCTS_DIR")];
  NSError *error = nil;
  NSString *systemIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Headers"];
  NSString *localIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Headers"];
  NSString *userIncludeDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Headers"];

  // Create the derived source directory...
  [[NSFileManager defaultManager] createDirectoryAtPath:outputDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];

  NSString *classesFilename = [[outputDir stringByAppendingPathComponent: executableName] stringByAppendingString: @"-class-list"];
  NSString *classesFormat = 
    @"echo \"(\" > %@; nm -Pg %@/*.o | grep __objc_class_name | "
    @"sed -e '/^__objc_class_name_[A-Za-z0-9_.]* [^U]/ {s/^__objc_class_name_\\([A-Za-z0-9_.]*\\) [^U].*/\\1/p;}' | "
    @"grep -v __objc_class_name | sort | uniq | while read class; do echo \"${class},\"; done >> %@; echo \")\" >> %@;"; 
  NSString *classesCommand = [NSString stringWithFormat: classesFormat,
				       classesFilename,
				       buildDir,
				       classesFilename,
				       classesFilename];
  system([classesCommand cString]);
  
  // build the list...
  NSArray *classArray = [NSArray arrayWithContentsOfFile: classesFilename];
  NSEnumerator *en = [classArray objectEnumerator];
  NSString *className = nil;
  while((className = [en nextObject]) != nil)
    {
      classList = [classList stringByAppendingString: [NSString stringWithFormat: @"@\"%@\",",className]];
    }

  // Write the file out...
  NSString *classTemplate = 
    @"#include <Foundation/NSString.h>\n\n"
    @"@interface NSFramework_%@\n"
    @"+ (NSString *)frameworkEnv;\n"
    @"+ (NSString *)frameworkPath;\n"
    @"+ (NSString *)frameworkVersion;\n"
    @"+ (NSString *const*)frameworkClasses;\n"
    @"@end\n\n"
    @"@implementation NSFramework_%@\n"
    @"+ (NSString *)frameworkEnv { return nil; }\n"
    @"+ (NSString *)frameworkPath { return @\"%@\"; }\n"
    @"+ (NSString *)frameworkVersion { return @\"%@\"; }\n"
    @"static NSString *allClasses[] = {%@NULL};\n"
    @"+ (NSString *const*)frameworkClasses { return allClasses; }\n"
    @"@end\n";
  NSString *dummyClass = [NSString stringWithFormat: classTemplate, 
				   executableName,
				   executableName,
				   frameworkPath,
				   frameworkVersion,
				   classList];
  [dummyClass writeToFile: outputPath 
	       atomically: YES
		 encoding: NSASCIIStringEncoding
		    error: &error];
  
  // compile...
  NSString *compiler = [NSString stringWithCString: getenv("CC")];
  NSString *buildPath = outputPath;
  NSString *objPath = [objDir stringByAppendingPathComponent: [fileName stringByAppendingString: @".o"]];
  if([compiler isEqualToString: @""] ||
     compiler == nil)
    {
      compiler = @"gcc";
    }
  
  NSString *buildTemplate = @"%@ %@ -c -MMD -MP -DGNUSTEP -fno-strict-aliasing -fexceptions -fobjc-exceptions -D_NATIVE_OBJC_EXCEPTIONS -fPIC -DDEBUG -fno-omit-frame-pointer -Wall -DGSWARN -DGSDIAGNOSE -Wno-import -g -fgnu-runtime -fconstant-string-class=NSConstantString -I. -I%@ -I%@ -I%@ -o %@";
  
  NSString *buildCommand = [NSString stringWithFormat: buildTemplate, 
				     compiler,
				     buildPath,
				     userIncludeDir,
				     localIncludeDir,
				     systemIncludeDir,
				     objPath];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *of = [context objectForKey: @"OUTPUT_FILES"];
  NSString *outputFiles = (of == nil)?@"":of;
  outputFiles = [[outputFiles stringByAppendingString: objPath] 
		  stringByAppendingString: @" "];
  [context setObject: outputFiles forKey: @"OUTPUT_FILES"];

  NSLog(@"\t%@",buildCommand);
  system([buildCommand cString]);
}

- (NSString *) linkString
{
  NSString *systemLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Libraries"];
  NSString *localLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Libraries"];
  NSString *userLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Libraries"];
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  NSString *linkString = [NSString stringWithFormat: @"-L%@ -L%@ -L%@ ",
				   userLibDir,
				   localLibDir,
				   systemLibDir];;

  while((file = [en nextObject]) != nil)
    {
      PBXFileReference *fileRef = [file fileRef];
      NSString *name = [[[fileRef path] lastPathComponent] stringByDeletingPathExtension];
      if([name isEqualToString: @"Cocoa"])
	{
	  linkString = [linkString stringByAppendingString: @"-lgnustep-gui -lgnustep-base "];
	}
      else if([name isEqualToString: @"Foundation"])
	{
	  linkString = [linkString stringByAppendingString: @"-lgnustep-base "];
	}
      else if([name isEqualToString: @"AppKit"])
	{
	  linkString = [linkString stringByAppendingString: @"-lgnustep-gui "];
	}
      else if([name isEqualToString: @"CoreFoundation"])
	{
	  linkString = [linkString stringByAppendingString: @"-lcorebase "];
	}
      else if([name isEqualToString: @"CoreGraphics"])
	{
	  linkString = [linkString stringByAppendingString: @"-lopal "];
	}
      else if([name isEqual: @"Carbon"] ||
	 [name isEqual: @"IOKit"] ||
	 [name isEqual: @"Quartz"] ||
	 [name isEqual: @"QuartzCore"] ||
	 [name isEqual: @"QuickTime"] ||
	 [name isEqual: @"ApplicationServices"])
	{
	  continue;
	}
      else
	{
	  linkString = [linkString stringByAppendingString: 
				[NSString stringWithFormat: @"-l%@ ",
					  name]];
	}
    }

  linkString = [linkString stringByAppendingString: @"-lpthread -lobjc -lm "];

  return linkString;
}

- (BOOL) buildTool
{
  NSLog(@"=== Executing Frameworks Build Phase (Tool)");
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"gcc":[NSString stringWithCString: cc];
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fexceptions -fgnu-runtime -o %@ %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  NSLog(@"\t%@",command);
  int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result != 127);
}

- (BOOL) buildApp
{
  NSLog(@"=== Executing Frameworks Build Phase (Application)");
  // GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"gcc":[NSString stringWithCString: cc];
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *linkString = [self linkString];

  NSString *command = [NSString stringWithFormat: 
				  @"%@ -rdynamic -shared-libgcc -fexceptions -fgnu-runtime -o %@ %@ %@",
				compiler, 
				outputPath,
				outputFiles,
				linkString];

  NSLog(@"\t%@",command);
  int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result != 127);
}

- (BOOL) buildStaticLib
{
  NSLog(@"=== Executing Frameworks Build Phase (Static Library)");
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *commandTemplate = @"ar rc %@ %@; ranlib %@";
  NSString *command = [NSString stringWithFormat: commandTemplate,
				outputPath,
				outputFiles,
				outputPath];
  
  NSLog(@"\t%@",command);
  int result = system([command cString]);
  NSLog(@"=== Frameworks Build Phase Completed");

  return (result != 127);
}

- (BOOL) buildFramework
{
  int result = 0;
  NSLog(@"=== Executing Frameworks Build Phase (Framework)");
  [self generateDummyClass];
  NSString *outputFiles = [[GSXCBuildContext sharedBuildContext] objectForKey: 
								   @"OUTPUT_FILES"];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *executableName = [NSString stringWithCString: getenv("EXECUTABLE_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: executableName];
  NSString *libraryPath = [outputDir stringByAppendingPathComponent: 
					 [NSString stringWithFormat: @"lib%@.so.0",
						   executableName]];
  NSString *systemLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Libraries"];
  NSString *localLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Libraries"];
  NSString *userLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Libraries"];


  NSString *commandTemplate = @"%@ -shared -Wl,-soname,%@.so.0  -rdynamic " 
    @"-shared-libgcc -fexceptions -o %@ %@ "
    @"-L%@ -L/%@ -L%@";     
  NSString *compiler = [NSString stringWithCString: getenv("CC")];
  if([compiler isEqualToString: @""] ||
     compiler == nil)
    {
      compiler = @"gcc";
    }
  NSString *command = [NSString stringWithFormat: commandTemplate,
				compiler,
				executableName,
				libraryPath,
				outputFiles,
				userLibDir,
				localLibDir,
				systemLibDir];

  
  NSLog(@"\t%@",command);
  result = system([command cString]);
  NSLog(@"=== Frameworks Build Phase Completed");
  return (result != 127);
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
  else if([productType isEqualToString: FRAMEWORK_TYPE])
    {
      return [self buildFramework];
    }
  return NO;
}

@end
