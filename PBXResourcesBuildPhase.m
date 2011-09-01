#import "PBXCommon.h"
#import "PBXResourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"
#import "PBXVariantGroup.h"

@implementation PBXResourcesBuildPhase
- (BOOL) build
{
  NSLog(@"=== Executing Resources Build Phase");
  NSString *projectRoot = [NSString stringWithCString: getenv("PROJECT_ROOT")];
  NSString *sourceRoot = [NSString stringWithCString: getenv("SOURCE_ROOT")];
  NSString *path = [projectRoot stringByAppendingPathComponent: sourceRoot];
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
      PBXVariantGroup *group = (PBXVariantGroup *)[file fileRef];
      PBXFileReference *fileRef = [[group children] objectAtIndex: 0]; // FIXME: Assume English only for now...
      NSString *filePath = [path stringByAppendingPathComponent: [fileRef path]];
      NSString *fileName = [filePath lastPathComponent];
      NSString *destPath = [resourcesDir stringByAppendingPathComponent: fileName];
      NSString *command = [NSString stringWithFormat: @"cp %@ %@",filePath,destPath];
      NSLog(@"\t%@",command);
      int sysresult = system([command cString]);
      result = (sysresult != 127);
    }

  // return, if we failed...
  if(result == NO)
    {
      return result;
    }
  
  NSString *productName = [NSString stringWithCString: getenv("PRODUCT_NAME")];
  NSString *plistName = [productName stringByAppendingString: @"-Info.plist"];
  NSString *inputPlist = [[projectRoot stringByAppendingPathComponent: sourceRoot] stringByAppendingPathComponent: plistName];
  NSString *outputPlist = [resourcesDir stringByAppendingPathComponent: @"Info-gnustep.plist"];
  NSString *awkCommand = [NSString stringWithFormat: 
				     @"awk '{while(match($0,\"[$]{[^}]*}\")) {var=substr($0,RSTART+2,RLENGTH -3);gsub(\"[$]{\"var\"}\",ENVIRON[var])}}1' < %@ > %@",
				   inputPlist, outputPlist];
  NSLog(@"\t%@",awkCommand);
  int sysresult = system([awkCommand cString]);
  result = (sysresult != 127);
  NSLog(@"=== Resources Build Phase Completed");
  return result;
}
@end
