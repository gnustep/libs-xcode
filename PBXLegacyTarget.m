#import "PBXAbstractTarget.h"

#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>

@interface PBXLegacyTarget : PBXAbstractTarget
{
  NSString *_buildArgumentsString;
  NSString *_buildToolPath;
  NSMutableArray *_dependencies;
  BOOL _passBuildSettingsInEnvironment;
}

- (void) dealloc
{
  RELEASE(_buildArgumentsString);
  RELEASE(_buildToolPath);
  RELEASE(_dependencies);
  [super dealloc];
}

- (NSString *) buildArgumentsString;
{
  return _buildArgumentsString;
}

- (void) setBuildArgumentsString: (NSString *)string
{
  ASSIGN(_buildArgumentsString, string);

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

@end
