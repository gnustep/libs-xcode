/*
 * Tests for libs-xcode.
 */

#import <Foundation/Foundation.h>
#import <XCode/GSXCCommon.h>

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
#import <XCode/PBXResourcesBuildPhase.h>
#import <XCode/NSString+PBXAdditions.h>

@interface PBXFrameworksBuildPhase (LinkTest)
- (NSString *) linkString;
@end

static int failures = 0;

static void
testAssert (BOOL condition, NSString *message)
{
  if (condition == NO)
    {
      NSLog (@"FAIL: %@", message);
      failures++;
    }
}

static XCBuildConfiguration *
configuration (NSDictionary *settings)
{
  return AUTORELEASE ([[XCBuildConfiguration alloc]
       initWithName: @"Debug"
      buildSettings: [NSMutableDictionary dictionaryWithDictionary: settings]]);
}

static XCConfigurationList *
configurationList (NSDictionary *settings)
{
  XCConfigurationList *list = AUTORELEASE ([[XCConfigurationList alloc]
      initWithConfigurations: [NSMutableArray
                                 arrayWithObject: configuration (settings)]]);
  [list setDefaultConfigurationName: @"Debug"];
  return list;
}

@interface SettingsTarget : PBXNativeTarget
{
@public
  NSArray *observed;
}
@end
@implementation SettingsTarget
- (BOOL) build
{
  [[self buildConfigurationList] applyDefaultConfiguration];
  ASSIGN (observed, [[GSXCBuildContext sharedBuildContext]
                        objectForKey: @"OTHER_LDFLAGS"]);
  return YES;
}
- (void) dealloc
{
  [observed release];
  [super dealloc];
}
@end

static void
testBuildSettingInheritance (void)
{
  NSUInteger i;
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSArray *projectFlags =
      [NSArray arrayWithObjects: @"-framework", @"UIKit", nil];
  PBXCoder *coder = AUTORELEASE ([[PBXCoder alloc]
      initWithContentsOfFile: @"../libs-xcode.xcodeproj/project.pbxproj"]);
  PBXContainer *container = [coder unarchive];
  PBXProject *project = [container rootObject];
  [project setContainer: container];
  [project
      setBuildConfigurationList: configurationList ([NSDictionary
                                    dictionaryWithObject: projectFlags
                                                  forKey: @"OTHER_LDFLAGS"])];
  SettingsTarget *first = AUTORELEASE ([[SettingsTarget alloc] init]);
  SettingsTarget *second = AUTORELEASE ([[SettingsTarget alloc] init]);
  [first setName: @"First"];
  [second setName: @"Second"];
  [first setBuildConfigurationList:
             configurationList ([NSDictionary
                 dictionaryWithObject: [NSArray
                                          arrayWithObjects: @"$(inherited)",
                                                           @"-framework",
                                                           @"Foundation", nil]
                               forKey: @"OTHER_LDFLAGS"])];
  [second
      setBuildConfigurationList: configurationList ([NSDictionary dictionary])];
  [project setTargets: [NSMutableArray arrayWithObjects: first, second, nil]];
  NSArray *expected = [projectFlags
      arrayByAddingObjectsFromArray: [NSArray arrayWithObjects: @"-framework",
                                                              @"Foundation",
                                                              nil]];
  for (i = 0; i < 2; i++)
    {
      testAssert ([project build], @"settings-only project builds");
      testAssert ([first->observed isEqual: expected],
                  @"target inherits project flags exactly once");
      testAssert (
          [second->observed isEqual: projectFlags],
          @"sibling target retains project flags without sibling overrides");
      testAssert ([context currentContext] == nil,
                  @"target context is popped on repeated builds");
    }
  [context contextDictionaryForName: @"Override"];
  [configuration ([NSDictionary dictionaryWithObject: projectFlags
                                              forKey: @"OTHER_LDFLAGS"]) apply];
  [configuration ([NSDictionary
      dictionaryWithObject: @"${inherited} -framework 'Framework With Spaces'"
                    forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert (
      [[context objectForKey: @"OTHER_LDFLAGS"]
          isEqual: [projectFlags
                      arrayByAddingObjectsFromArray:
                          [NSArray arrayWithObjects: @"-framework",
                                                    @"Framework With Spaces",
                                                    nil]]],
      @"string flags preserve quoted arguments and expand inherited arrays");
  [configuration ([NSDictionary
      dictionaryWithObject: [NSArray arrayWithObject: @"-lOnlyTarget"]
                    forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert ([[context objectForKey: @"OTHER_LDFLAGS"]
                  isEqual: [NSArray arrayWithObject: @"-lOnlyTarget"]],
              @"override without inherited replaces parent");
  [configuration ([NSDictionary dictionaryWithObject: @"parent"
                                              forKey: @"GSXC_TEST_SETTING"])
      apply];
  [configuration ([NSDictionary dictionaryWithObject: @"$(inherited)-child"
                                              forKey: @"GSXC_TEST_SETTING"])
      apply];
  testAssert (
      [[context objectForKey: @"GSXC_TEST_SETTING"] isEqual: @"parent-child"],
      @"scalar inheritance");
  PBXFrameworksBuildPhase *phase
      = AUTORELEASE ([[PBXFrameworksBuildPhase alloc] init]);
  [phase setTarget: first];
  testAssert ([[phase linkString] rangeOfString: @"-lOnlyTarget"].location
                  != NSNotFound,
              @"ordinary linker flags are emitted");
  [context setObject: @"com.apple.product-type.bundle.unit-test"
              forKey: @"PRODUCT_TYPE"];
  NSString *testLink = [phase linkString];
  testAssert (
      [testLink rangeOfString: @"-lXCTest"].location != NSNotFound &&
          [testLink rangeOfString: @"-framework XCTest"].location == NSNotFound,
      @"test bundles link XCTest through the GNUstep framework mapping");
  [configuration ([NSDictionary dictionaryWithObject: @"-framework XCTest"
                                              forKey: @"OTHER_LDFLAGS"]) apply];
  testAssert (
      [[[phase linkString] componentsSeparatedByString: @"-lXCTest"] count]
          == 2,
      @"explicit XCTest linkage is not duplicated");
  [context popCurrentContext];
  unsetenv ("GSXC_TEST_SETTING");
}

static void
testHeaderSearchPaths (void)
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  NSString *key = @"HEADER_SEARCH_PATHS";
  [context contextDictionaryForName: @"HeaderSearchPaths"];
  [configuration ([NSDictionary dictionaryWithObject: @"$(SRCROOT)/UIKitTest"
                                              forKey: key]) apply];
  testAssert (
      [[context objectForKey: key]
          isEqual: [NSArray arrayWithObject: @"$(SRCROOT)/UIKitTest"]],
      @"single string header path becomes an array for source compilation");

  NSArray *parent =
      [NSArray arrayWithObjects: @"Parent Headers", @"Other", nil];
  [configuration ([NSDictionary dictionaryWithObject: parent
                                              forKey: key]) apply];
  testAssert ([[context objectForKey: key] isEqual: parent],
              @"array header paths preserve spaces");
  [configuration ([NSDictionary
      dictionaryWithObject:
          @"$(inherited) \"$(SRCROOT)/Quoted Headers\" 'Single Quoted' Escaped\\ Path"
                    forKey: key]) apply];
  NSArray *expected = [parent
      arrayByAddingObjectsFromArray:
          [NSArray arrayWithObjects: @"$(SRCROOT)/Quoted Headers",
                                    @"Single Quoted", @"Escaped Path", nil]];
  testAssert (
      [[context objectForKey: key] isEqual: expected],
      @"string paths preserve quotes, escapes, and inherited array boundaries");
  [configuration ([NSDictionary dictionaryWithObject: @"${inherited} Extra"
                                              forKey: key]) apply];
  testAssert ([[context objectForKey: key]
                  isEqual: [expected arrayByAddingObject: @"Extra"]],
              @"brace inheritance works for header paths");
  [configuration ([NSDictionary dictionaryWithObject: @"Replacement"
                                              forKey: key]) apply];
  testAssert ([[context objectForKey: key]
                  isEqual: [NSArray arrayWithObject: @"Replacement"]],
              @"header paths without inherited replace parent paths");
  [configuration ([NSDictionary dictionaryWithObject: @"" forKey: key]) apply];
  testAssert ([[context objectForKey: key] isEqual: [NSArray array]],
              @"empty string header paths become an empty array");
  [context popCurrentContext];
}

static void
testBuildtoolArgumentParsing (void)
{
  ToolDelegate *delegate = AUTORELEASE ([[ToolDelegate alloc] init]);
  NSDictionary *args = [delegate parseArguments];
  ArgPair *pair = nil;

  testAssert (args != nil, @"parseArguments should return a dictionary");

  pair = [args objectForKey: @"-project"];
  testAssert ([[pair value] isEqualToString: @"Sample.xcodeproj"],
              @"-project should accept a path value");

  pair = [args objectForKey: @"-workspace"];
  testAssert ([[pair value] isEqualToString: @"Sample.xcworkspace"],
              @"-workspace should accept a path value");

  pair = [args objectForKey: @"-target"];
  testAssert ([[pair value] isEqualToString: @"SampleTarget"],
              @"-target should accept a target name");

  pair = [args objectForKey: @"-scheme"];
  testAssert ([[pair value] isEqualToString: @"SampleScheme"],
              @"-scheme should accept a scheme name");

  pair = [args objectForKey: @"-configuration"];
  testAssert ([[pair value] isEqualToString: @"Debug"],
              @"-configuration should accept a configuration name");

  testAssert ([args objectForKey: @"-alltargets"] != nil,
              @"-alltargets should be accepted without a value");

  testAssert ([args objectForKey: @"build"] != nil,
              @"build should remain an accepted sub-command");
}

@interface OperationToolDelegate : ToolDelegate
{
@public
  NSDictionary *arguments;
}
@end

@implementation OperationToolDelegate
- (NSDictionary *) parseArguments
{
  return arguments;
}
@end

static NSDictionary *
operationArguments (NSString *path)
{
  ArgPair *pair = AUTORELEASE ([[ArgPair alloc] init]);
  [pair setArgument: @"-project"];
  [pair setValue: path];
  return [NSDictionary dictionaryWithObject: pair forKey: @"-project"];
}

static void
testBuildtoolOperationResults (void)
{
  OperationToolDelegate *delegate
      = AUTORELEASE ([[OperationToolDelegate alloc] init]);
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *directory = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[NSProcessInfo processInfo]
                                         globallyUniqueString]];
  NSString *path =
      [directory stringByAppendingPathComponent: @"project.pbxproj"];
  [manager createDirectoryAtPath: directory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];

  delegate->arguments = nil;
  testAssert (![delegate process], @"invalid arguments fail the operation");
  delegate->arguments = operationArguments (@"unsupported.project");
  testAssert (![delegate process],
              @"explicit unsupported paths do not build another project");
  delegate->arguments = operationArguments (path);
  testAssert (![delegate process],
              @"missing project files fail the operation");

  NSMutableDictionary *fixture = [NSMutableDictionary
      dictionaryWithContentsOfFile: @"../libs-xcode.xcodeproj/project.pbxproj"];
  NSMutableDictionary *objects = [NSMutableDictionary
      dictionaryWithDictionary: [fixture objectForKey: @"objects"]];
  NSString *rootKey = [fixture objectForKey: @"rootObject"];
  NSMutableDictionary *root = [NSMutableDictionary
      dictionaryWithDictionary: [objects objectForKey: rootKey]];
  [root setObject: [NSArray array] forKey: @"targets"];
  [objects setObject: root forKey: rootKey];
  [fixture setObject: objects forKey: @"objects"];
  [fixture writeToFile: path atomically: YES];
  testAssert ([delegate process],
              @"successful project operations return success");

  [manager removeItemAtPath: directory error: NULL];
}

static void
testFrameworkResourcesAndEnvironment (void)
{
  NSBundle *bundle = [NSBundle bundleForClass: [PBXFrameworksBuildPhase class]];
  NSString *path = [bundle pathForResource: @"Framework-mapping"
                                    ofType: @"plist"];
  NSDictionary *mapping = [NSDictionary dictionaryWithContentsOfFile: path];
  testAssert ([[mapping objectForKey: @"Mapped"] objectForKey: @"Foundation"]
                  != nil,
              @"framework bundle contains its framework mapping");

  const char *oldValue = getenv ("GSXC_TEST_LIVE_ENVIRONMENT");
  NSString *savedValue
      = oldValue ? [NSString stringWithUTF8String: oldValue] : nil;
  setenv ("GSXC_TEST_LIVE_ENVIRONMENT", "first", 1);
  testAssert ([[@"$(GSXC_TEST_LIVE_ENVIRONMENT)"
                  stringByReplacingEnvironmentVariablesWithValues]
                  isEqualToString: @"first"],
              @"environment expansion reads live process variables");
  setenv ("GSXC_TEST_LIVE_ENVIRONMENT", "second", 1);
  testAssert ([[@"$(GSXC_TEST_LIVE_ENVIRONMENT)"
                  stringByReplacingEnvironmentVariablesWithValues]
                  isEqualToString: @"second"],
              @"environment expansion sees subsequent changes");
  if (savedValue != nil)
    setenv ("GSXC_TEST_LIVE_ENVIRONMENT", [savedValue UTF8String], 1);
  else
    unsetenv ("GSXC_TEST_LIVE_ENVIRONMENT");
}

static void
testGeneratedBundleExecutable (void)
{
  GSXCBuildContext *context = [GSXCBuildContext sharedBuildContext];
  PBXResourcesBuildPhase *phase = AUTORELEASE ([PBXResourcesBuildPhase new]);
  NSArray *names =
      [NSArray arrayWithObjects: @"Host App", @"Hosted Tests", nil];
  NSEnumerator *enumerator = [names objectEnumerator];
  NSString *name;
  while ((name = [enumerator nextObject]) != nil)
    {
      [context contextDictionaryForName: name];
      [context setObject: name forKey: @"EXECUTABLE_NAME"];
      NSDictionary *plist =
          [phase configToInfoPlist: configuration ([NSDictionary dictionary])
                      withIconFile: nil];
      testAssert (
          [[plist objectForKey: @"CFBundleExecutable"] isEqual: name],
          @"Generated Info.plist names the current target executable, including spaces");
      testAssert (
          [plist objectForKey: @"CFBundlExecutable"] == nil,
          @"Generated Info.plist does not use the misspelled executable key");
#ifdef GNUSTEP
      testAssert (
          [[plist objectForKey: @"NSExecutable"] isEqual: name],
          @"Generated GNUstep test bundle identifies its loadable executable");
#endif
      [context popCurrentContext];
    }
}

static void
testProjectUnarchive (void)
{
  NSString *path = @"../libs-xcode.xcodeproj/project.pbxproj";
  PBXCoder *coder
      = AUTORELEASE ([[PBXCoder alloc] initWithContentsOfFile: path]);
  PBXContainer *container = [coder unarchive];
  PBXProject *project = [container rootObject];

  testAssert (container != nil,
              @"PBXCoder should unarchive a project container");
  testAssert (project != nil,
              @"unarchived container should have a root project");
  testAssert ([[project targets] count] > 0,
              @"unarchived project should contain targets");

  NSDictionary *root = [[coder objects]
      objectForKey: [[coder dictionary] objectForKey: @"rootObject"]];
  NSDictionary *list = [[coder objects]
      objectForKey: [root objectForKey: @"buildConfigurationList"]];
  NSArray *references = [list objectForKey: @"buildConfigurations"];
  testAssert ([references count] > 0,
              @"configuration reference fixture is nonempty");
  NSUInteger i;
  for (i = 0; i < 2; i++)
    {
      NSArray *array = i == 0 ? AUTORELEASE ([references copy])
                              : AUTORELEASE ([references mutableCopy]);
      NSMutableDictionary *dictionary =
          [NSMutableDictionary dictionaryWithDictionary: list];
      [dictionary setObject: array forKey: @"buildConfigurations"];
      XCConfigurationList *decoded =
          [coder unarchiveFromDictionary: dictionary];
      NSArray *configurations = [decoded buildConfigurations];
      testAssert (
          [configurations isKindOfClass: [NSMutableArray class]],
          @"decoded reference arrays remain editable regardless of input mutability");
      testAssert ([configurations count] == [references count],
                  @"decoding retains every configuration reference");
      NSEnumerator *enumerator = [configurations objectEnumerator];
      id value;
      while ((value = [enumerator nextObject]) != nil)
        testAssert (
            [value isKindOfClass: [XCBuildConfiguration class]],
            @"mutable and immutable reference arrays both decode configuration objects");
    }
}

int
main (int argc, const char **argv, char **env)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

#ifdef GNUSTEP
  [NSProcessInfo initializeWithArguments: (char **)argv
                                   count: argc
                             environment: env];
#endif

  testBuildtoolArgumentParsing ();
  testProjectUnarchive ();
  testBuildSettingInheritance ();
  testHeaderSearchPaths ();
  testFrameworkResourcesAndEnvironment ();
  testGeneratedBundleExecutable ();
  testBuildtoolOperationResults ();

  if (failures == 0)
    {
      NSLog (@"PASS: libs-xcode tests");
    }

  [pool drain];

  return failures == 0 ? 0 : 1;
}
