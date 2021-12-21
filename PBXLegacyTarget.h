#import "PBXAbstractTarget.h"

@class NSString;
@class NSMutableArray;

@interface PBXLegacyTarget : PBXAbstractTarget
{
  NSString *_buildArgumentsString;
  NSString *_buildToolPath;
  NSMutableArray *_dependencies;
  BOOL _passBuildSettingsInEnvironment;
}

- (NSString *) buildArgumentsString;
- (void) setBuildArgumentsString: (NSString *)string;

- (NSString *) buildToolPath;
- (void) setBuildToolPath: (NSString *)path;

- (NSArray *) dependencies;
- (void) setDependencies: (NSArray *)deps;

- (BOOL) passBuildSettingsInEnvironment;
- (void) setPassBuildSettingsInEnvironment: (BOOL)f;

@end
