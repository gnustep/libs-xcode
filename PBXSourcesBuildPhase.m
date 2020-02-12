#import "PBXCommon.h"
#import "PBXSourcesBuildPhase.h"
#import "PBXFileReference.h"
#import "PBXBuildFile.h"

@implementation PBXSourcesBuildPhase

- (BOOL) build
{
  puts("=== Executing Sources Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      result = [file build];
    }
  puts("=== Sources Build Phase Completed");

  return result;
}

@end
