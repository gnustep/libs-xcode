#import "PBXCommon.h"
#import "PBXAbstractBuildPhase.h"

@implementation PBXAbstractBuildPhase

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

- (NSString *) runOnlyForDeploymentPostprocessing // getter
{
  return runOnlyForDeploymentPostprocessing;
}

- (void) setRunOnlyForDeploymentPostprocessing: (NSString *)object; // setter
{
  ASSIGN(runOnlyForDeploymentPostprocessing,object);
}

- (BOOL) showEnvVarsInLog; // setter
{
  return showEnvVarsInLog;
}

- (void) setEnvVarsInLog: (BOOL)flag
{
  showEnvVarsInLog = flag;
}

- (void) setTarget: (PBXNativeTarget *)t
{
  ASSIGN(target, t);
}

- (void) setName: (NSString *)n
{
  ASSIGN(_name, n);
}

- (NSString *) name
{
  return _name;
}

- (BOOL) build
{
  NSDebugLog(@"Abstract build... %@, %@",self, files);
  return YES;
}

- (BOOL) generate
{
  NSLog(@"Abstract generate... %@, %@",self,files);
  return YES;
}

@end
