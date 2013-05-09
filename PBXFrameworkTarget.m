#import "PBXCommon.h"
#import "PBXFrameworkTarget.h"

@implementation PBXFrameworkTarget

- (id) init
{
  self = [super init];
  if(self)
    {
      [self setProductType: FRAMEWORK_TYPE];
    }
  return self;
}

@end
