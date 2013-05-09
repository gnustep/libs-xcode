#import "PBXCommon.h"
#import "PBXApplicationTarget.h"

@implementation PBXApplicationTarget

- (id) init
{
  self = [super init];
  if(self)
    {
      [self setProductType: APPLICATION_TYPE];
    }
  return self;
}

@end
