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
  NSError *error = nil;
  NSString *fileName = [NSString stringWithFormat: @"script_%lu",[shellScript hash]];
  NSString *command = [NSString stringWithFormat: @"%@ %@",shellPath,fileName];
  puts([[NSString stringWithFormat: @"=== Executing Script Build Phase... %@",name] cString]);
  puts([[NSString stringWithFormat: @"\t%@",command] cString]);
  [shellScript writeToFile: fileName
                atomically: YES
                  encoding: NSASCIIStringEncoding
                     error: &error];
  system([shellScript cString]);
  // NSString *deleteCommand = [NSString stringWithFormat: @"rm -rf %@",fileName];
  puts([[NSString stringWithFormat: @"=== Done Executing Script Build Phase... %@",name] cString]);

  return YES; // be forgiving since this is not a mac...
}
@end
