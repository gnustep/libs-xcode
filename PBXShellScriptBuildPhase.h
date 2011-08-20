#import <Foundation/Foundation.h>

// Local includes
#import "PBXCoder.h"


@interface PBXShellScriptBuildPhase : NSObject
{
  NSMutableArray *files;
  NSString *buildActionMask;
  NSString *shellPath;
  NSString *shellScript;
  NSMutableArray *inputPaths;
  NSMutableArray *outputPaths;
  NSString *runOnlyForDeploymentPostprocessing;
  NSString *name;
}

// Methods....
- (id) initWithPBXCoder: (PBXCoder *)coder;

@end