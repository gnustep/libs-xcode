#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXContainerItemProxy.h"


@interface PBXTargetDependency : NSObject
{
  PBXContainerItemProxy *targetProxy;
  NSString *name;
}

// Methods....
- (PBXContainerItemProxy *) targetProxy; // getter
- (void) setTargetProxy: (PBXContainerItemProxy *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

@end