#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"


@interface PBXBuildFile : NSObject
{
  PBXFileReference *fileRef;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end