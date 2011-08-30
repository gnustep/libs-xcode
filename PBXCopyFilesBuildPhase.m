#import "PBXCommon.h"
#import "PBXCopyFilesBuildPhase.h"

@implementation PBXCopyFilesBuildPhase

// Methods....
- (NSMutableArray *) files // getter
{
  return files;
}

- (void) setFiles: (NSMutableArray *)object; // setter
{
  ASSIGN(files,object);
}

- (NSString *) buildActionMask // getter
{
  return buildActionMask;
}

- (void) setBuildActionMask: (NSString *)object; // setter
{
  ASSIGN(buildActionMask,object);
}

- (NSString *) dstPath // getter
{
  return dstPath;
}

- (void) setDstPath: (NSString *)object; // setter
{
  ASSIGN(dstPath,object);
}

- (NSString *) dstSubfolderSpec // getter
{
  return dstSubfolderSpec;
}

- (void) setDstSubfolderSpec: (NSString *)object; // setter
{
  ASSIGN(dstSubfolderSpec,object);
}

- (NSString *) runOnlyForDeploymentPostprocessing // getter
{
  return runOnlyForDeploymentPostprocessing;
}

- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
{
  ASSIGN(runOnlyForDeploymentPostprocessing,object);
}


@end