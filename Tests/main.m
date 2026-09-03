/*
 * Tests for libs-xcode.
 */

#import <Foundation/Foundation.h>

#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>

#import "ToolDelegate.h"
#import "ArgPair.h"

static int failures = 0;

static void testAssert(BOOL condition, NSString *message)
{
  if (condition == NO)
    {
      NSLog(@"FAIL: %@", message);
      failures++;
    }
}

static void testBuildtoolArgumentParsing(void)
{
  ToolDelegate *delegate = AUTORELEASE([[ToolDelegate alloc] init]);
  NSDictionary *args = [delegate parseArguments];
  ArgPair *pair = nil;

  testAssert(args != nil, @"parseArguments should return a dictionary");

  pair = [args objectForKey: @"-project"];
  testAssert([[pair value] isEqualToString: @"Sample.xcodeproj"],
	     @"-project should accept a path value");

  pair = [args objectForKey: @"-workspace"];
  testAssert([[pair value] isEqualToString: @"Sample.xcworkspace"],
	     @"-workspace should accept a path value");

  pair = [args objectForKey: @"-target"];
  testAssert([[pair value] isEqualToString: @"SampleTarget"],
	     @"-target should accept a target name");

  pair = [args objectForKey: @"-scheme"];
  testAssert([[pair value] isEqualToString: @"SampleScheme"],
	     @"-scheme should accept a scheme name");

  pair = [args objectForKey: @"-configuration"];
  testAssert([[pair value] isEqualToString: @"Debug"],
	     @"-configuration should accept a configuration name");

  testAssert([args objectForKey: @"-alltargets"] != nil,
	     @"-alltargets should be accepted without a value");

  testAssert([args objectForKey: @"build"] != nil,
	     @"build should remain an accepted sub-command");
}

static void testProjectUnarchive(void)
{
  NSString *path = @"../libs-xcode.xcodeproj/project.pbxproj";
  PBXCoder *coder = AUTORELEASE([[PBXCoder alloc] initWithContentsOfFile: path]);
  PBXContainer *container = [coder unarchive];
  PBXProject *project = [container rootObject];

  testAssert(container != nil, @"PBXCoder should unarchive a project container");
  testAssert(project != nil, @"unarchived container should have a root project");
  testAssert([[project targets] count] > 0,
	     @"unarchived project should contain targets");
}

int main(int argc, const char **argv, char **env)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  [NSProcessInfo initializeWithArguments: (char **)argv
				   count: argc
			     environment: env];

  testBuildtoolArgumentParsing();
  testProjectUnarchive();

  if (failures == 0)
    {
      NSLog(@"PASS: libs-xcode tests");
    }

  [pool drain];

  return failures == 0 ? 0 : 1;
}
