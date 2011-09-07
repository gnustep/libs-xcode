#import "PBXCommon.h"
#import "PBXRezBuildPhase.h"

@implementation PBXRezBuildPhase

-(BOOL) build
{
  NSLog(@"=== Executing Rez Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      NSLog(@"\tFile = %@",file);
    }
  NSLog(@"=== Completed Rez Build Phase");
  return result;
}

@end
