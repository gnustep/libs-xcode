#import "PBXCommon.h"
#import "XCBuildConfiguration.h"
#import "GSXCBuildContext.h"

#import <stdlib.h>

@implementation XCBuildConfiguration

- (NSString *) description
{
  return [NSString stringWithFormat: @"%@ -- buildSettings = %@, name = %@", [super description], buildSettings, name];
}

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
  puts([[NSString stringWithFormat: @"=== Applying Build Configuration %@",name] cString]);
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [buildSettings keyEnumerator];
  NSString *key = nil;

  while ((key = [en nextObject]) != nil)
    {
      id value = [buildSettings objectForKey: key];
      if ([value isKindOfClass: [NSString class]])
	{	  
	  setenv([key cString],[value cString],1);
	}
      else if([value isKindOfClass: [NSArray class]])
	{
	  [context setObject: value
		      forKey: key];
	  NSDebugLog(@"\tContext: %@ = %@",key,value);
	}
      else
	{
	  NSDebugLog(@"\tWARNING: Can't interpret value %@, for environment variable %@", value, key); 
	}
    }
  
  if ([buildSettings objectForKey: @"TARGET_BUILD_DIR"] == nil)
    {
      NSDebugLog(@"\tEnvironment: TARGET_BUILD_DIR = build (built-in)");
      setenv("TARGET_BUILD_DIR","build",1);
    }
  if ([buildSettings objectForKey: @"BUILT_PRODUCTS_DIR"] == nil)
    {
      NSDebugLog(@"\tEnvironment: BUILT_PRODUCTS_DIR = build (built-in)");
      setenv("BUILT_PRODUCTS_DIR","build",1);
    }
  puts([[NSString stringWithFormat: @"=== Done Applying Build Configuration for %@",name] cString]);
}
@end
