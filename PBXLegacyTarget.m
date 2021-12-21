#import "PBXLegacyTarget.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@implementation PBXLegacyTarget

- (void) dealloc
{
  RELEASE(_buildArgumentsString);
  RELEASE(_buildToolPath);
  RELEASE(_dependencies);
  [super dealloc];
}

- (NSString *) buildArgumentsString
{
  return _buildArgumentsString;
}

- (void) setBuildArgumentsString: (NSString *)string
{
  ASSIGN(_buildArgumentsString, string);
}

- (NSString *) buildToolPath
{
  return _buildToolPath;
}

- (void) setBuildToolPath: (NSString *)path
{
  ASSIGN(_buildToolPath, path);
}

- (NSArray *) dependencies
{
  return _dependencies;
}

- (void) setDependencies: (NSArray *)deps
{
  ASSIGN(_dependencies, deps);
}

- (BOOL) passBuildSettingsInEnvironment
{
  return _passBuildSettingsInEnvironment;
}

- (void) setPassBuildSettingsInEnvironment: (BOOL)f
{
  _passBuildSettingsInEnvironment = f;
}

- (BOOL) build
{
  return system([_buildToolPath cString]);
}

- (BOOL) clean
{
  NSString *build_cmd = [_buildToolPath stringByAppendingString: @" clean"];
  return system([build_cmd cString]);
}

- (BOOL) install
{
  NSString *build_cmd = [_buildToolPath stringByAppendingString: @" install"];
  return system([build_cmd cString]);
}

@end
