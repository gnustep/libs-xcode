#import "PBXCommon.h"
#import "PBXFrameworksBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

@implementation PBXFrameworksBuildPhase

- (BOOL) build
{
  NSLog(@"=== Executing Frameworks Build Phase");
  char *cc = getenv("CC");
  NSString *compiler = (cc == NULL)?@"gcc":[NSString stringWithCString: cc];
  NSString *systemLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_SYSTEM_ROOT")] 
				      stringByAppendingPathComponent: @"Library"] 
				     stringByAppendingPathComponent: @"Libraries"];
  NSString *localLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_LOCAL_ROOT")] 
				     stringByAppendingPathComponent: @"Library"] 
				    stringByAppendingPathComponent: @"Libraries"];
  NSString *userLibDir = [[[NSString stringWithCString: getenv("GNUSTEP_USER_ROOT")] 
				    stringByAppendingPathComponent: @"Library"] 
				   stringByAppendingPathComponent: @"Libraries"];
  NSString *outputFiles = [NSString stringWithCString: getenv("OUTPUT_FILES")];
  NSString *outputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *productName = [NSString stringWithCString: getenv("PRODUCT_NAME")];
  NSString *outputPath = [outputDir stringByAppendingPathComponent: productName];
  
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
	  linkString = [linkString stringByAppendingString: [NSString stringWithFormat: @"-l%@ ",name]];
	}
    }

  linkString = [linkString stringByAppendingString: @"-lpthread -lobjc -lm "];

  NSString *command = [NSString stringWithFormat: @"%@ -rdynamic -shared-libgcc -fexceptions -fgnu-runtime -o %@ %@ %@",
    compiler, 
    outputPath,
    outputFiles,
    linkString];

  NSLog(@"\t%@",command);
  int result = system([command cString]);

  NSLog(@"=== Frameworks Build Phase Completed");
  return (result != 127);
}

@end
