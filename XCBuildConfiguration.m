#import "PBXCommon.h"
#import "XCBuildConfiguration.h"

@implementation XCBuildConfiguration

// Methods....
- (NSMutableDictionary *) buildSettings // getter
{
  return buildSettings;
}

- (void) setBuildSettings: (NSMutableDictionary *)object; // setter
{
  ASSIGN(buildSettings,object);
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