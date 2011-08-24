#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXFileReference : NSObject
{
  NSString *sourceTree;
  NSString *lastKnownFileType;
  NSString *path;
  NSString *fileEncoding;
  NSString *explicitFileType;
  NSString *usesTabs;
  NSString *indentWidth;
  NSString *tabWidth;
  NSString *name;
  NSString *includeInIndex;
}

// Methods....
- (NSString *) sourceTree; // getter
- (void) setSourceTree: (NSString *)object; // setter
- (NSString *) lastKnownFileType; // getter
- (void) setLastKnownFileType: (NSString *)object; // setter
- (NSString *) path; // getter
- (void) setPath: (NSString *)object; // setter
- (NSString *) fileEncoding; // getter
- (void) setFileEncoding: (NSString *)object; // setter

@end
