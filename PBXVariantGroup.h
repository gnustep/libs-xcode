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
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end