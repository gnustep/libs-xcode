#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "PBXFileReference.h"


@interface XCBuildConfiguration : NSObject
{
  NSMutableDictionary *buildSettings;
  PBXFileReference *baseConfigurationReference;
  NSString *name;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end