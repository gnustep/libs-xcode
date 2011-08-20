#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXFileReference : NSObject
{
  NSString *lastKnownFileType;
  NSString *sourceTree;
  NSString *indentWidth;
  NSString *usesTabs;
  NSString *tabWidth;
  NSString *fileEncoding;
  NSString *path;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end