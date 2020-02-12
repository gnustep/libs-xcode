#import "PBXCommon.h"
#import "PBXRezBuildPhase.h"

@implementation PBXRezBuildPhase

-(BOOL) build
{
  puts("=== Executing Rez Build Phase");
  NSEnumerator *en = [files objectEnumerator];
  id file = nil;
  BOOL result = YES;
  while((file = [en nextObject]) != nil && result)
    {
      puts([[NSString stringWithFormat: @"\tFile = %@",file] cString]);
    }
  puts("=== Completed Rez Build Phase");
  return result;
}

@end
