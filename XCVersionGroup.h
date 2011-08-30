#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"


@interface XCVersionGroup : NSObject
{
  NSString *sourceTree;
  PBXFileReference *currentVersion;
  NSString *versionGroupType;
  NSString *path;
  NSMutableArray *children;
}

// Methods....
- (NSString *) sourceTree; // getter
- (void) setSourceTree: (NSString *)object; // setter
- (PBXFileReference *) currentVersion; // getter
- (void) setCurrentVersion: (PBXFileReference *)object; // setter
- (NSString *) versionGroupType; // getter
- (void) setVersionGroupType: (NSString *)object; // setter
- (NSString *) path; // getter
- (void) setPath: (NSString *)object; // setter
- (NSMutableArray *) children; // getter
- (void) setChildren: (NSMutableArray *)object; // setter

@end