#import "PBXCommon.h"
#import "PBXBuildFile.h"
#import "PBXNativeTarget.h"

@implementation PBXBuildFile

// Methods....
- (PBXFileReference *) fileRef // getter
{
  return fileRef;
}

- (void) setFileRef: (PBXFileReference *)object; // setter
{
  ASSIGN(fileRef,object);
}

- (NSMutableDictionary *) settings // getter
{
  return settings;
}

- (void) setSettings: (NSMutableDictionary *)object; // setter
{
  ASSIGN(settings,object);
}

- (void) applySettings
{
  // puts("%@",settings);
}

- (NSString *) buildPath
{
  return [fileRef buildPath];
}

- (NSString *) path
{
  return [fileRef path];
}

- (void) setTarget: (PBXNativeTarget *)t
{
  ASSIGN(target, t);
}

- (BOOL) build
{
  [self applySettings];
  puts([[NSString stringWithFormat: @"\t* Building \033[1;34m%@\033[1;0m",[fileRef buildPath]] cString]);
  [fileRef setTarget: target];
  return [fileRef build];
}

- (BOOL) generate
{
  [self applySettings];
  puts([[NSString stringWithFormat: @"\t* Creating entry for %@",[fileRef buildPath]] cString]);
  [fileRef setTarget: target];
  return [fileRef generate];
}

- (NSString *) description
{
  NSString *s = [super description];
  return [s stringByAppendingFormat: @" <%@>", fileRef]; 
}

@end
