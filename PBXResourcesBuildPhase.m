#import "PBXCommon.h"
#import "PBXResourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "PBXVariantGroup.h"
#import "NSString+PBXAdditions.h"
#import "GSXCBuildContext.h"

@implementation PBXResourcesBuildPhase
- (BOOL) build
{
  NSLog(@"=== Executing Resources Build Phase");
  NSString *projectRoot = [NSString stringWithCString: getenv("PROJECT_ROOT")];
  NSString *productOutputDir = [NSString stringWithCString: getenv("PRODUCT_OUTPUT_DIR")];
  NSString *resourcesDir = [productOutputDir stringByAppendingPathComponent: @"Resources"];
  NSError *error = nil;

  [[NSFileManager defaultManager] createDirectoryAtPath:resourcesDir
			    withIntermediateDirectories:YES
					     attributes:nil
						  error:&error];

  NSEnumerator *en = [files objectEnumerator];
  BOOL result = YES;
  PBXBuildFile *file = nil;
  while((file = [en nextObject]) != nil && result)
    {
      NSString *filePath = [file buildPath];
      NSString *fileName = [filePath lastPathComponent];
      NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
      NSError *error = nil;
      NSLog(@"\tCopy %@ -> %@",filePath,destPath);
      BOOL copyResult = [[NSFileManager defaultManager] copyItemAtPath: filePath
								toPath: destPath
								 error: &error];
      if(!copyResult)
	{
	  NSLog(@"\tFile exists...");
	}
    }

  // return, if we failed...
  if(result == NO)
    {
      return result;
    }
  
  NSString *inputPlist = [projectRoot stringByAppendingPathComponent: 
					 [NSString stringWithCString: getenv("INFOPLIST_FILE")]];
  NSString *outputPlist = [resourcesDir stringByAppendingPathComponent: @"Info-gnustep.plist"];
  NSString *awkCommand = [NSString stringWithFormat: 
				     @"awk '{while(match($0,\"[$]{[^}]*}\")) {var=substr($0,RSTART+2,RLENGTH -3);gsub(\"[$]{\"var\"}\",ENVIRON[var])}}1' < %@ > %@",
				   [inputPlist stringByEscapingSpecialCharacters], [outputPlist stringByEscapingSpecialCharacters]];
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *modified = [context objectForKey: @"MODIFIED_FLAG"];
  int sysresult = 0;
  if([modified isEqualToString: @"YES"])
    {
      NSLog(@"\t%@",awkCommand);
      sysresult = system([awkCommand cString]);
      result = (sysresult != 127);
    }
  else
    {
      NSLog(@"\t** Nothing to be done for %@, no modifications.",outputPlist);
    }

  NSLog(@"=== Resources Build Phase Completed");
  return result;
}
@end
