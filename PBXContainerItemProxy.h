#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"


@interface PBXContainerItemProxy : NSObject
{
  NSString *proxyType;
  NSString *remoteGlobalIDString;
  id containerPortal;
  NSString *remoteInfo;
}

// Methods....
- (NSString *) proxyType; // getter
- (void) setProxyType: (NSString *)object; // setter
- (NSString *) remoteGlobalIDString; // getter
- (void) setRemoteGlobalIDString: (NSString *)object; // setter
- (id) containerPortal; // getter
- (void) setContainerPortal: (id)object; // setter
- (NSString *) remoteInfo; // getter
- (void) setRemoteInfo: (NSString *)object; // setter

- (BOOL) build;
@end
