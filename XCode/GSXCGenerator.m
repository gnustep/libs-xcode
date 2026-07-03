// Released under the terms of LGPLv2.1, please see COPYING.LIB

#import <Foundation/NSObject.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#ifdef GNUSTEP
#import <GNUstepBase/NSObject+GNUstepBase.h>
#endif

#import "GSXCGenerator.h"
#import "GSXCCommon.h"
#import "PBXTarget.h"

@implementation GSXCGenerator

- (id) initWithTarget: (PBXTarget *)target
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
#ifdef GNUSTEP
  return ([self notImplemented: _cmd] != nil);
#else
  [NSException raise: NSInternalInconsistencyException
	      format: @"%@ must be implemented by subclasses",
		      NSStringFromSelector(_cmd)];
  return NO;
#endif
}

@end
