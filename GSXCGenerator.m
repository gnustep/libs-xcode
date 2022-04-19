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
      [self setTarget: target];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_target);
  [super dealloc];
}

- (void) setTarget: (PBXNativeTarget *)target
{
  ASSIGN(_target, target);
}

- (PBXNativeTarget *) target
{
  return _target;
}

- (BOOL) generate
{
  return ([self notImplemented: _cmd] != nil);
}

@end
