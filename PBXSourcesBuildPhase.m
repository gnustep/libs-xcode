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
      [file setTarget: target];
      result = [file build];
    }
  puts("=== Sources Build Phase Completed");

  return result;
}

- (BOOL) generate
{
  puts("=== Generating using Sources Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      [file setTarget: target];
      result = [file generate];
    }
  puts("=== Sources Build Phase generation completed");

  return result;
}

@end
