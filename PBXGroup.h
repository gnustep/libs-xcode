#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXGroup : NSObject
{
  NSString *sourceTree;
  NSString *usesTabs;
  NSString *tabWidth;
  NSString *path;
  NSMutableArray *children;
  NSString *name;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end