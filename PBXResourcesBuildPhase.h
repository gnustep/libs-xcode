#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXResourcesBuildPhase : NSObject
{
  NSMutableArray *files;
  NSString *buildActionMask;
  NSString *runOnlyForDeploymentPostprocessing;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end