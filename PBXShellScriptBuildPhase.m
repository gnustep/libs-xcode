#import "PBXCommon.h"
#import "PBXShellScriptBuildPhase.h"

@implementation PBXShellScriptBuildPhase

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

- (NSString *) shellPath // getter
{
  return shellPath;
}

- (void) setShellPath: (NSString *)object; // setter
{
  ASSIGN(shellPath,object);
}

- (NSString *) shellScript // getter
{
  return shellScript;
}

- (void) setShellScript: (NSString *)object; // setter
{
  ASSIGN(shellScript,object);
}

- (NSMutableArray *) inputPaths // getter
{
  return inputPaths;
}

- (void) setInputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(inputPaths,object);
}

- (NSMutableArray *) outputPaths // getter
{
  return outputPaths;
}

- (void) setOutputPaths: (NSMutableArray *)object; // setter
{
  ASSIGN(outputPaths,object);
}

- (NSString *) runOnlyForDeploymentPostprocessing // getter
{
  return runOnlyForDeploymentPostprocessing;
}

- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
{
  ASSIGN(runOnlyForDeploymentPostprocessing,object);
}

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}


@end