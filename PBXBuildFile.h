#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"

@class PBXNativeTarget;

@interface PBXBuildFile : NSObject
{
  PBXFileReference *fileRef;
  NSMutableDictionary *settings;
  PBXNativeTarget *target;
  NSString *platformFilter;
}

// Methods....
- (PBXFileReference *) fileRef; // getter
- (void) setFileRef: (PBXFileReference *)object; // setter
- (NSMutableDictionary *) settings; // getter
- (void) setSettings: (NSMutableDictionary *)object; // setter
- (void) setPlatformFilter: (NSString *)f;
- (void) setTarget: (PBXNativeTarget *)t;

- (NSString *) path;
- (NSString *) buildPath;
- (BOOL) build;
- (BOOL) generate;

@end
