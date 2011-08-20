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
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end