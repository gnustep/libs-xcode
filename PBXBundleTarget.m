#import "PBXCommon.h"
#import "PBXBundleTarget.h"

@implementation PBXBundleTarget

- (id) init
{
  self = [super init];
  if(self)
    {
      [self setProductType: BUNDLE_TYPE];
    }
  return self;
}

@end
