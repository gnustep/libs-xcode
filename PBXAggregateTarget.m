#import "PBXCommon.h"
#import "PBXAggregateTarget.h"

@implementation PBXAggregateTarget
- (BOOL) build
{
  // puts([buildPhases cString]);
  return YES;
}
@end
