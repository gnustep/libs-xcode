#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"
#import "XCConfigurationList.h"
#import "PBXGroup.h"
#import "PBXGroup.h"


@interface PBXProject : NSObject
{
  NSString *developmentRegion;
  NSMutableArray *knownRegions;
  NSString *compatibilityVersion;
  NSMutableArray *targets;
  NSString *projectDirPath;
  NSString *projectRoot;
  XCConfigurationList *buildConfigurationList;
  PBXGroup *mainGroup;
  NSString *hasScannedForEncodings;
  PBXGroup *productRefGroup;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end