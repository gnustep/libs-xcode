#import <Foundation/NSObject.h>
#import <GNUstepBase/NSObject+GNUstepBase.h>

#import "GSXCGenerator.h"
#import "GSXCCommon.h"
#import "PBXNativeTarget.h"

@implementation GSXCGenerator

- (instancetype) initWithTarget: (PBXNativeTarget *)target
{
  self = [super init];
  if (self != nil)
    {
      _target = target;
    }
  return self;
}

- (PBXNativeTarget *) target
{
  return _target;
}

- (BOOL) build
{
  return ([self notImplemented: _cmd] != nil);
}

@end
