#import "PBXCommon.h"
#import "XCBuildConfiguration.h"
#import <stdlib.h>

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

- (void) apply
{
  NSLog(@"=== Applying Build Configuration %@",name);
  NSEnumerator *en = [buildSettings keyEnumerator];
  NSString *key = nil;
  while((key = [en nextObject]) != nil)
    {
      NSString *value = [buildSettings objectForKey: key];
      NSLog(@"\t%@ = %@",key,value);
      setenv([key cString],[value cString],1);
    }
  if([buildSettings objectForKey: @"TARGET_BUILD_DIR"] == nil)
    {
      NSLog(@"\tTARGET_BUILD_DIR = build");
      setenv("TARGET_BUILD_DIR","build",1);
    }
  if([buildSettings objectForKey: @"BUILT_PRODUCTS_DIR"] == nil)
    {
      NSLog(@"\tBUILT_PRODUCTS_DIR = build");
      setenv("BUILT_PRODUCTS_DIR","build",1);
    }
  NSLog(@"=== Done Applying Build Configuration for %@",name);
}
@end
