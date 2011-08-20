#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXContainerItemProxy.h"


@interface PBXReferenceProxy : NSObject
{
  NSString *sourceTree;
  NSString *fileType;
  PBXContainerItemProxy *remoteRef;
  NSString *path;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end