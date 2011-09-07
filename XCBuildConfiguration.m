#import "PBXCommon.h"
#import "XCBuildConfiguration.h"
#import "GSXCBuildContext.h"

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
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSEnumerator *en = [buildSettings keyEnumerator];
  NSString *key = nil;

  while((key = [en nextObject]) != nil)
    {
      id value = [buildSettings objectForKey: key];
      if([value isKindOfClass: [NSString class]])
	{	  
	  NSLog(@"\t%@ = %@\t\t# Environment",key,value);
	  setenv([key cString],[value cString],1);
	}
      else if([value isKindOfClass: [NSArray class]])
	{
	  /*
	  NSString *string = @"";
	  NSEnumerator *en = [value objectEnumerator];
	  id val = nil;
	  while((val = [en nextObject]) != nil)
	    {
	      string = [string stringByAppendingString: val];
	      string = [string stringByAppendingString: @" "];
	    }
	  NSLog(@"\t%@ = %@",key,string);
	  setenv([key cString],[string cString],1);
	  */
	  [context setObject: value
		      forKey: key];
	  NSLog(@"\t%@ = %@\t\t# Context",key,value);
	}
      else
	{
	  NSLog(@"\tWARNING: Can't interpret value %@, for environment variable %@", value, key);
	}
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
