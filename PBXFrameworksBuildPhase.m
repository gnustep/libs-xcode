#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "GSXCBuildContext.h"
#import "NSArray+Additions.h"
#import "GSXCCommon.h"

@implementation PBXFrameworksBuildPhase

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
  return NO;
}

@end
