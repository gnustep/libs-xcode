#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXVariantGroup : NSObject
{
  NSString *sourceTree;
  NSString *path;
  NSMutableArray *children;
  NSString *name;
}

// Methods....
- (NSString *) sourceTree; // getter
- (void) setSourceTree: (NSString *)object; // setter
- (NSString *) path; // getter
- (void) setPath: (NSString *)object; // setter
- (NSMutableArray *) children; // getter
- (void) setChildren: (NSMutableArray *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

// build...
- (NSString *) buildPath;

@end
