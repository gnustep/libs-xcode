#import <Foundation/NSObject.h>
#import <GNUstepBase/NSObject+GNUstepBase.h>

#import "GSXCGenerator.h"
#import "GSXCCommon.h"
#import "PBXAbstractTarget.h"

@implementation GSXCGenerator

- (instancetype) initWithTarget: (PBXAbstractTarget *)target
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

- (void) setTarget: (PBXAbstractTarget *)target
{
  ASSIGN(_target, target);
}

- (PBXAbstractTarget *) target
{
  return _target;
}

- (BOOL) generate
{
  return ([self notImplemented: _cmd] != nil);
}

@end
