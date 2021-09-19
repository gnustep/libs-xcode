#import "PBXCommon.h"
#import "XCConfigurationList.h"
#import "XCBuildConfiguration.h"

@implementation XCConfigurationList

// Methods....
- (NSString *) defaultConfigurationIsVisible // getter
{
  return defaultConfigurationIsVisible;
}

- (void) setDefaultConfigurationIsVisible: (NSString *)object; // setter
{
  ASSIGN(defaultConfigurationIsVisible,object);
}

- (NSMutableArray *) buildConfigurations // getter
{
  return buildConfigurations;
}

- (void) setBuildConfigurations: (NSMutableArray *)object; // setter
{
  ASSIGN(buildConfigurations,object);
}

- (NSString *) defaultConfigurationName // getter
{
  return defaultConfigurationName;
}

- (void) setDefaultConfigurationName: (NSString *)object; // setter
{
  ASSIGN(defaultConfigurationName,object);
}

- (XCBuildConfiguration *) defaultConfiguration
{
  NSEnumerator *en = [buildConfigurations objectEnumerator];
  NSString *defaultConfig = (defaultConfigurationName == nil)?
    @"Release":defaultConfigurationName;
  XCBuildConfiguration *config = nil;

  while((config = [en nextObject]) != nil)
    {
      if([[config name] 
	   isEqualToString: 
	     defaultConfig])
	{
	  break;
	}
    }

  return config;
}

- (void) applyDefaultConfiguration
{
  [[self defaultConfiguration] apply];
}

- (instancetype) init
{
  self = [super init];
  return self;
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ -- %@", [super description],
		   buildConfigurations];
}
@end
