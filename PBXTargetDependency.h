#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXContainerItemProxy.h"
#import "PBXNativeTarget.h"

@interface PBXTargetDependency : NSObject
{
  PBXContainerItemProxy *targetProxy;
  NSString *name;
  PBXNativeTarget *target;
}

// Methods....
- (PBXContainerItemProxy *) targetProxy; // getter
- (void) setTargetProxy: (PBXContainerItemProxy *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter
- (PBXNativeTarget *)target;
- (void) setTarget: (PBXNativeTarget *)object;

// build
- (BOOL) build;
@end
