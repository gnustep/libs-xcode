#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXFileReference.h"


@interface PBXNativeTarget : NSObject
{
  NSMutableArray *dependencies;
  XCConfigurationList *buildConfigurationList;
  PBXFileReference *productReference;
  NSString *productInstallPath;
  NSString *productName;
  NSString *productType;
  NSMutableArray *buildRules;
  NSString *name;
  NSMutableArray *buildPhases;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end