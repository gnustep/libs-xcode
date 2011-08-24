#import "PBXCommon.h"
#import "PBXShellScriptBuildPhase.h"

@implementation PBXShellScriptBuildPhase

// Methods....
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

- (NSString *) name // getter
{
  return name;
}

- (void) setName: (NSString *)object; // setter
{
  ASSIGN(name,object);
}

- (BOOL) build
{
  NSLog(@"Executing... %@ %@",self,name);
  return YES;
}
@end
