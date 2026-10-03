/*
 * Tests for libs-xcode.
 */

#import <Foundation/Foundation.h>

#import <XCode/PBXCoder.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>

#import "ToolDelegate.h"
#import "ArgPair.h"
#import <XCode/GSXCBuildContext.h>
#import <XCode/XCBuildConfiguration.h>
#import <XCode/XCConfigurationList.h>
#import <XCode/PBXNativeTarget.h>
#import <XCode/PBXFrameworksBuildPhase.h>

@interface PBXFrameworksBuildPhase (LinkTest)
- (NSString *)linkString;
@end

static int failures = 0;

static void testAssert(BOOL condition, NSString *message)
{
  if (condition == NO)
    {
      NSLog(@"FAIL: %@", message);
      failures++;
    }
}

static XCBuildConfiguration *configuration(NSDictionary *settings)
{
  return AUTORELEASE([[XCBuildConfiguration alloc] initWithName: @"Debug"
    buildSettings: [NSMutableDictionary dictionaryWithDictionary: settings]]);
}

static XCConfigurationList *configurationList(NSDictionary *settings)
{
  XCConfigurationList *list = AUTORELEASE([[XCConfigurationList alloc]
    initWithConfigurations: [NSMutableArray arrayWithObject: configuration(settings)]]);
  [list setDefaultConfigurationName: @"Debug"];
  return list;
}

@interface SettingsTarget : PBXNativeTarget
{ @public NSArray *observed; }
@end
@implementation SettingsTarget
- (BOOL)build
{
  [[self buildConfigurationList] applyDefaultConfiguration];
  ASSIGN(observed, [[GSXCBuildContext sharedBuildContext] objectForKey: @"OTHER_LDFLAGS"]);
  return YES;
}
- (void)dealloc { [observed release]; [super dealloc]; }
@end

static void testBuildSettingInheritance(void)
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *projectFlags = [NSArray arrayWithObjects: @"-framework", @"UIKit", nil];
  PBXCoder *coder = AUTORELEASE([[PBXCoder alloc] initWithContentsOfFile: @"../libs-xcode.xcodeproj/project.pbxproj"]);
  PBXContainer *container = [coder unarchive];
  PBXProject *project = [container rootObject];
  [project setContainer: container];
  [project setBuildConfigurationList: configurationList(
    [NSDictionary dictionaryWithObject: projectFlags forKey: @"OTHER_LDFLAGS"])];
  SettingsTarget *first = AUTORELEASE([[SettingsTarget alloc] init]);
  SettingsTarget *second = AUTORELEASE([[SettingsTarget alloc] init]);
  [first setName: @"First"]; [second setName: @"Second"];
  [first setBuildConfigurationList: configurationList([NSDictionary dictionaryWithObject:
    [NSArray arrayWithObjects: @"$(inherited)", @"-framework", @"Foundation", nil] forKey: @"OTHER_LDFLAGS"])];
  [second setBuildConfigurationList: configurationList([NSDictionary dictionary])];
  [project setTargets: [NSMutableArray arrayWithObjects: first, second, nil]];
  NSArray *expected = [projectFlags arrayByAddingObjectsFromArray:
    [NSArray arrayWithObjects: @"-framework", @"Foundation", nil]];
  for (NSUInteger i = 0; i < 2; i++) {
    testAssert([project build], @"settings-only project builds");
    testAssert([first->observed isEqual: expected], @"target inherits project flags exactly once");
    testAssert([second->observed isEqual: projectFlags], @"sibling target retains project flags without sibling overrides");
    testAssert([context currentContext] == nil, @"target context is popped on repeated builds");
  }
  [context contextDictionaryForName: @"Override"];
  [configuration([NSDictionary dictionaryWithObject: projectFlags forKey: @"OTHER_LDFLAGS"]) apply];
  [configuration([NSDictionary dictionaryWithObject: @"${inherited} -framework 'Framework With Spaces'" forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert([[context objectForKey: @"OTHER_LDFLAGS"] isEqual:
    [projectFlags arrayByAddingObjectsFromArray: [NSArray arrayWithObjects: @"-framework", @"Framework With Spaces", nil]]],
    @"string flags preserve quoted arguments and expand inherited arrays");
  [configuration([NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"-lOnlyTarget"] forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert([[context objectForKey: @"OTHER_LDFLAGS"] isEqual: [NSArray arrayWithObject: @"-lOnlyTarget"]], @"override without inherited replaces parent");
  [configuration([NSDictionary dictionaryWithObject: @"parent" forKey: @"GSXC_TEST_SETTING"]) apply];
  [configuration([NSDictionary dictionaryWithObject: @"$(inherited)-child" forKey: @"GSXC_TEST_SETTING"]) apply];
  testAssert([[context objectForKey: @"GSXC_TEST_SETTING"] isEqual: @"parent-child"], @"scalar inheritance");
  PBXFrameworksBuildPhase *phase = AUTORELEASE([[PBXFrameworksBuildPhase alloc] init]);
  [phase setTarget: first];
  testAssert([[phase linkString] rangeOfString: @"-lOnlyTarget"].location != NSNotFound,
    @"ordinary linker flags are emitted");
  [context setObject: @"com.apple.product-type.bundle.unit-test" forKey: @"PRODUCT_TYPE"];
  NSString *testLink = [phase linkString];
  testAssert([testLink rangeOfString: @"-lXCTest"].location != NSNotFound &&
    [testLink rangeOfString: @"-framework XCTest"].location == NSNotFound,
    @"test bundles link XCTest through the GNUstep framework mapping");
  [configuration([NSDictionary dictionaryWithObject:
    @"-framework XCTest" forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert([[[phase linkString] componentsSeparatedByString: @"-lXCTest"] count] == 2,
    @"explicit XCTest linkage is not duplicated");
  [context popCurrentContext];
  unsetenv("GSXC_TEST_SETTING");
}

static void testHeaderSearchPaths(void)
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *key = @"HEADER_SEARCH_PATHS";
  [context contextDictionaryForName: @"HeaderSearchPaths"];
  [configuration([NSDictionary dictionaryWithObject: @"$(SRCROOT)/UIKitTest" forKey: key]) apply];
  testAssert([[context objectForKey: key] isEqual:
    [NSArray arrayWithObject: @"$(SRCROOT)/UIKitTest"]],
    @"single string header path becomes an array for source compilation");

  NSArray *parent = [NSArray arrayWithObjects: @"Parent Headers", @"Other", nil];
  [configuration([NSDictionary dictionaryWithObject: parent forKey: key]) apply];
  testAssert([[context objectForKey: key] isEqual: parent],
    @"array header paths preserve spaces");
  [configuration([NSDictionary dictionaryWithObject:
    @"$(inherited) \"$(SRCROOT)/Quoted Headers\" 'Single Quoted' Escaped\\ Path" forKey: key]) apply];
  NSArray *expected = [parent arrayByAddingObjectsFromArray:
    [NSArray arrayWithObjects: @"$(SRCROOT)/Quoted Headers", @"Single Quoted", @"Escaped Path", nil]];
  testAssert([[context objectForKey: key] isEqual: expected],
    @"string paths preserve quotes, escapes, and inherited array boundaries");
  [configuration([NSDictionary dictionaryWithObject: @"${inherited} Extra" forKey: key]) apply];
  testAssert([[context objectForKey: key] isEqual: [expected arrayByAddingObject: @"Extra"]],
    @"brace inheritance works for header paths");
  [configuration([NSDictionary dictionaryWithObject: @"Replacement" forKey: key]) apply];
  testAssert([[context objectForKey: key] isEqual: [NSArray arrayWithObject: @"Replacement"]],
    @"header paths without inherited replace parent paths");
  [configuration([NSDictionary dictionaryWithObject: @"" forKey: key]) apply];
  testAssert([[context objectForKey: key] isEqual: [NSArray array]],
    @"empty string header paths become an empty array");
  [context popCurrentContext];
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
  testBuildSettingInheritance();
  testHeaderSearchPaths();

  if (failures == 0)
    {
      NSLog(@"PASS: libs-xcode tests");
    }

  [pool drain];

  return failures == 0 ? 0 : 1;
}
