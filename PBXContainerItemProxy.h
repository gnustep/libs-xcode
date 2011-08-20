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
- (NSString *) proxyType; // getter
- (void) setProxyType: (NSString *)object; // setter
- (NSString *) remoteGlobalIDString; // getter
- (void) setRemoteGlobalIDString: (NSString *)object; // setter
- (PBXFileReference *) containerPortal; // getter
- (void) setContainerPortal: (PBXFileReference *)object; // setter
- (NSString *) remoteInfo; // getter
- (void) setRemoteInfo: (NSString *)object; // setter

@end