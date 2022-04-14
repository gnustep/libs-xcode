#import <Foundation/NSObject.h>
#import "GSXCCommon.h"

@class PBXNativeTarget;

@interface GSXCGenerator : NSObject
{
  PBXNativeTarget *_target;
}

- (instancetype) initWithTarget: (PBXNativeTarget *)target;

- (PBXNativeTarget *) target;

- (BOOL) build;

@end
