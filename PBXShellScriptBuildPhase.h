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
- (NSMutableArray *) files; // getter
- (void) setFiles: (NSMutableArray *)object; // setter
- (NSString *) buildActionMask; // getter
- (void) setBuildActionMask: (NSString *)object; // setter
- (NSString *) shellPath; // getter
- (void) setShellPath: (NSString *)object; // setter
- (NSString *) shellScript; // getter
- (void) setShellScript: (NSString *)object; // setter
- (NSMutableArray *) inputPaths; // getter
- (void) setInputPaths: (NSMutableArray *)object; // setter
- (NSMutableArray *) outputPaths; // getter
- (void) setOutputPaths: (NSMutableArray *)object; // setter
- (NSString *) runOnlyForDeploymentPostprocessing; // getter
- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
- (NSString *) name; // getter
- (void) setName: (NSString *)object; // setter

@end