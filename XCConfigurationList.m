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

- (void) applyDefaultConfiguration
{
  NSEnumerator *en = [buildConfigurations objectEnumerator];
  id config = nil;
  while((config = [en nextObject]) != nil)
    {
      if([[config name] 
	   isEqualToString: 
	     defaultConfigurationName])
	{
	  break;
	}
    }
  [config apply];
}
@end
