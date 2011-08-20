#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"


@interface PBXContainerItemProxy : NSObject
{
  NSString *proxyType;
  NSString *remoteGlobalIDString;
  PBXFileReference *containerPortal;
  NSString *remoteInfo;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end