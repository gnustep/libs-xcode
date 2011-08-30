#import "PBXCommon.h"
#import "PBXSourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

@implementation PBXSourcesBuildPhase

- (BOOL) build
{
  NSLog(@"=== Executing Sources Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      [file build];
    }
  NSLog(@"=== Sources Build Phase Completed");

  return result;
}

@end
