// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>
#import <GNUstepBase/NSObject+GNUstepBase.h>

#import "GSXCGenerator.h"
#import "GSXCCommon.h"
#import "PBXTarget.h"

@implementation GSXCGenerator

- (instancetype) initWithTarget: (PBXTarget *)target
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

- (void) setTarget: (PBXTarget *)target
{
  ASSIGN(_target, target);
}

- (PBXTarget *) target
{
  return _target;
}

- (BOOL) generate
{
  return ([self notImplemented: _cmd] != nil);
}

@end
