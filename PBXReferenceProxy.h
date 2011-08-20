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
- (NSString *) sourceTree; // getter
- (void) setSourceTree: (NSString *)object; // setter
- (NSString *) fileType; // getter
- (void) setFileType: (NSString *)object; // setter
- (PBXContainerItemProxy *) remoteRef; // getter
- (void) setRemoteRef: (PBXContainerItemProxy *)object; // setter
- (NSString *) path; // getter
- (void) setPath: (NSString *)object; // setter

@end