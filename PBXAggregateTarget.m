#import "PBXCommon.h"
#import "PBXAggregateTarget.h"

@implementation PBXAggregateTarget
- (BOOL) build
{
  NSLog(@"%@",buildPhases);
  return YES;
}
@end
