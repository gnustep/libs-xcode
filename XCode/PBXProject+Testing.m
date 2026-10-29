/*
   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by: Daniel Boyd <danieljboyd@icloud.com>
   Date: 2026
   
   This file is part of the GNUstep XCode Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.
*/

#import "PBXCommon.h"
#import "PBXProject+Testing.h"
#import "PBXContainer.h"
#import "PBXFileReference.h"
#import "PBXNativeTarget.h"
#import "GSXCCommon.h"
#import "XCBuildConfiguration.h"
#import "XCConfigurationList.h"

#include <stdio.h>
#include <unistd.h>

/**
 * The test part of an .xcscheme: the test targets it runs and, for each,
 * the tests it skips or (with useTestSelectionWhitelist) only runs.
 */
@interface GSXCSchemeTests : NSObject
{
  NSMutableArray *_targets;
  NSMutableDictionary *_skipped;
  NSMutableDictionary *_selected;
  NSString *_currentTarget;
  BOOL _currentSkipped;
  BOOL _currentWhitelist;
  BOOL _inTestable;
  BOOL _inSkipped;
  BOOL _inSelected;
}
+ (GSXCSchemeTests *) testsFromSchemeAtPath: (NSString *)path;
/** Test target names, in order. */
- (NSArray *) targets;
/** TestTarget/TestClass[/testMethod] identifiers. */
- (NSArray *) skippedTests;
- (NSArray *) selectedTests;
@end

@implementation GSXCSchemeTests

+ (GSXCSchemeTests *) testsFromSchemeAtPath: (NSString *)path
{
  NSData *data = [NSData dataWithContentsOfFile: path];
  NSXMLParser *parser = nil;
  GSXCSchemeTests *tests = nil;

  if (data == nil)
    {
      return nil;
    }

  tests = AUTORELEASE([[self alloc] init]);
  parser = AUTORELEASE([[NSXMLParser alloc] initWithData: data]);
  [parser setDelegate: tests];
  if ([parser parse] == NO)
    {
      return nil;
    }
  return tests;
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _targets = [[NSMutableArray alloc] init];
      _skipped = [[NSMutableDictionary alloc] init];
      _selected = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_targets);
  RELEASE(_skipped);
  RELEASE(_selected);
  RELEASE(_currentTarget);
  [super dealloc];
}

- (NSArray *) targets
{
  return _targets;
}

- (NSArray *) _identifiersIn: (NSDictionary *)tests
{
  NSMutableArray *identifiers = [NSMutableArray array];
  NSEnumerator *en = [_targets objectEnumerator];
  NSString *target = nil;

  while ((target = [en nextObject]) != nil)
    {
      NSEnumerator *ten = [[tests objectForKey: target] objectEnumerator];
      NSString *test = nil;

      while ((test = [ten nextObject]) != nil)
        {
          [identifiers addObject: [NSString stringWithFormat: @"%@/%@", target, test]];
        }
    }
  return identifiers;
}

- (NSArray *) skippedTests
{
  return [self _identifiersIn: _skipped];
}

- (NSArray *) selectedTests
{
  return [self _identifiersIn: _selected];
}

- (void) parser: (NSXMLParser *)parser
didStartElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
     attributes: (NSDictionary *)attributes
{
  if ([elementName isEqualToString: @"TestableReference"])
    {
      _inTestable = YES;
      _currentSkipped = [[attributes objectForKey: @"skipped"] isEqualToString: @"YES"];
      _currentWhitelist = [[attributes objectForKey: @"useTestSelectionWhitelist"] isEqualToString: @"YES"];
      DESTROY(_currentTarget);
    }
  else if (_inTestable && [elementName isEqualToString: @"BuildableReference"])
    {
      ASSIGN(_currentTarget, [attributes objectForKey: @"BlueprintName"]);
      if (_currentTarget != nil && _currentSkipped == NO)
        {
          [_targets addObject: _currentTarget];
          [_skipped setObject: [NSMutableArray array] forKey: _currentTarget];
          if (_currentWhitelist)
            {
              [_selected setObject: [NSMutableArray array] forKey: _currentTarget];
            }
        }
    }
  else if (_inTestable && [elementName isEqualToString: @"SkippedTests"])
    {
      _inSkipped = YES;
    }
  else if (_inTestable && [elementName isEqualToString: @"SelectedTests"])
    {
      _inSelected = YES;
    }
  else if (_inTestable && [elementName isEqualToString: @"Test"] && _currentTarget != nil)
    {
      NSString *identifier = [attributes objectForKey: @"Identifier"];

      // Swift identifiers end in "()"; xctest names methods without it.
      if ([identifier hasSuffix: @"()"])
        {
          identifier = [identifier substringToIndex: [identifier length] - 2];
        }
      if (identifier != nil && _inSkipped)
        {
          [[_skipped objectForKey: _currentTarget] addObject: identifier];
        }
      else if (identifier != nil && _inSelected)
        {
          [[_selected objectForKey: _currentTarget] addObject: identifier];
        }
    }
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
  if ([elementName isEqualToString: @"TestableReference"])
    {
      _inTestable = NO;
    }
  else if ([elementName isEqualToString: @"SkippedTests"])
    {
      _inSkipped = NO;
    }
  else if ([elementName isEqualToString: @"SelectedTests"])
    {
      _inSelected = NO;
    }
}

@end

// The xctest program: $XCTEST, else the first in PATH, else GNUstep's.
static NSString *GSXCTestProgram(void)
{
  NSDictionary *env = [[NSProcessInfo processInfo] environment];
  NSString *program = [env objectForKey: @"XCTEST"];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *en = nil;
  NSString *dir = nil;

  if ([program length] > 0)
    {
      return program;
    }

  en = [[[env objectForKey: @"PATH"] componentsSeparatedByString: @":"] objectEnumerator];
  while ((dir = [en nextObject]) != nil)
    {
      NSString *candidate = [dir stringByAppendingPathComponent: @"xctest"];

      if ([fm isExecutableFileAtPath: candidate])
        {
          return candidate;
        }
    }

  en = [[NSArray arrayWithObjects: @"/usr/GNUstep/Local/Tools/xctest",
                 @"/usr/GNUstep/System/Tools/xctest", nil] objectEnumerator];
  while ((program = [en nextObject]) != nil)
    {
      if ([fm isExecutableFileAtPath: program])
        {
          return program;
        }
    }
  return nil;
}

// xctest's usage text. tools-xctest has gained options over time, so the
// test action passes only the ones the program lists.
static NSString *GSXCTestUsage(NSString *xctest)
{
  NSTask *task = AUTORELEASE([[NSTask alloc] init]);
  NSPipe *pipe = [NSPipe pipe];
  NSData *data = nil;

  [task setLaunchPath: xctest];
  [task setArguments: [NSArray arrayWithObject: @"--help"]];
  [task setStandardOutput: pipe];
  [task setStandardError: pipe];
  NS_DURING
    {
      [task launch];
      data = [[pipe fileHandleForReading] readDataToEndOfFile];
      [task waitUntilExit];
    }
  NS_HANDLER
    {
      data = nil;
    }
  NS_ENDHANDLER
  if (data == nil)
    {
      return @"";
    }
  return AUTORELEASE([[NSString alloc] initWithData: data
                                           encoding: NSUTF8StringEncoding]);
}

// xctest's -XCTest selection (Class or Class.method, comma-separated) for
// the identifiers (TestTarget/Class[/method]) of one target, or nil when
// one of them names the whole target.
static NSString *GSXCSelectionForTarget(NSArray *identifiers, NSString *target)
{
  NSMutableArray *names = [NSMutableArray array];
  NSEnumerator *en = [identifiers objectEnumerator];
  NSString *identifier = nil;

  while ((identifier = [en nextObject]) != nil)
    {
      NSArray *components = [identifier componentsSeparatedByString: @"/"];

      if (![[components objectAtIndex: 0] isEqualToString: target])
        {
          continue;
        }
      if ([components count] == 1)
        {
          return nil;
        }
      if ([components count] == 2)
        {
          [names addObject: [components objectAtIndex: 1]];
        }
      else
        {
          [names addObject: [NSString stringWithFormat: @"%@.%@",
                                      [components objectAtIndex: 1],
                                      [components objectAtIndex: 2]]];
        }
    }
  return [names componentsJoinedByString: @","];
}

// Where buildtool puts a target's product.
static NSString *GSXCProductPath(PBXNativeTarget *target)
{
  return [[[@"./build" stringByAppendingPathComponent: [target name]]
            stringByAppendingPathComponent: @"Products"]
           stringByAppendingPathComponent: [[target productReference] path]];
}

// xcodebuild identifiers (TestTarget/...) for one target, renamed for its
// bundle (xctest names the target after the bundle).
static NSArray *GSXCIdentifiersForTarget(NSArray *identifiers, NSString *target, NSString *bundleName)
{
  NSMutableArray *result = [NSMutableArray array];
  NSEnumerator *en = [identifiers objectEnumerator];
  NSString *identifier = nil;

  while ((identifier = [en nextObject]) != nil)
    {
      NSMutableArray *components = [NSMutableArray arrayWithArray:
                                      [identifier componentsSeparatedByString: @"/"]];

      if ([components count] > 0 && [[components objectAtIndex: 0] isEqualToString: target])
        {
          [components replaceObjectAtIndex: 0 withObject: bundleName];
          [result addObject: [components componentsJoinedByString: @"/"]];
        }
    }
  return result;
}

@implementation PBXProject (Testing)

- (NSString *) _schemePathForName: (NSString *)name
{
  NSString *projectDir = [[[self container] filename] stringByDeletingLastPathComponent];
  NSString *fileName = [name stringByAppendingPathExtension: @"xcscheme"];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *path = [[projectDir stringByAppendingPathComponent: @"xcshareddata/xcschemes"]
                     stringByAppendingPathComponent: fileName];
  NSString *userDir = [projectDir stringByAppendingPathComponent: @"xcuserdata"];
  NSEnumerator *en = nil;
  NSString *user = nil;

  if ([fm fileExistsAtPath: path])
    {
      return path;
    }

  en = [[fm contentsOfDirectoryAtPath: userDir error: NULL] objectEnumerator];
  while ((user = [en nextObject]) != nil)
    {
      path = [[[userDir stringByAppendingPathComponent: user]
                stringByAppendingPathComponent: @"xcschemes"]
               stringByAppendingPathComponent: fileName];
      if ([fm fileExistsAtPath: path])
        {
          return path;
        }
    }
  return nil;
}

- (PBXNativeTarget *) _targetNamed: (NSString *)name
{
  NSEnumerator *en = [[self targets] objectEnumerator];
  id target = nil;

  while ((target = [en nextObject]) != nil)
    {
      if ([[target name] isEqualToString: name])
        {
          return target;
        }
    }
  return nil;
}

// The application a test target's TEST_HOST names, as built here; nil if
// it has none (or it isn't an application in this project).
- (NSString *) _hostForTestTarget: (PBXNativeTarget *)target
{
  XCBuildConfiguration *config = [[target buildConfigurationList] defaultConfiguration];
  NSString *testHost = [[config buildSettings] objectForKey: @"TEST_HOST"];
  NSEnumerator *en = nil;
  NSString *component = nil;
  NSString *appName = nil;
  id candidate = nil;

  if ([testHost length] == 0)
    {
      return nil;
    }

  // e.g. $(BUILT_PRODUCTS_DIR)/MyApp.app/Contents/MacOS/MyApp
  en = [[testHost pathComponents] objectEnumerator];
  while ((component = [en nextObject]) != nil)
    {
      if ([[component pathExtension] isEqualToString: @"app"])
        {
          appName = component;
          break;
        }
    }

  en = [[self targets] objectEnumerator];
  while ((candidate = [en nextObject]) != nil)
    {
      if ([candidate isKindOfClass: [PBXNativeTarget class]]
          && [[candidate productType] isEqualToString: APPLICATION_TYPE]
          && [[[[candidate productReference] path] lastPathComponent] isEqualToString: appName])
        {
          return GSXCProductPath(candidate);
        }
    }

  xcprintf("\t** TEST_HOST %s isn't an application built by this project; running without a host\n",
           [testHost cString]);
  return nil;
}

- (BOOL) testWithOptions: (NSDictionary *)options
{
  NSString *targetName = [options objectForKey: @"target"];
  NSString *schemeName = [options objectForKey: @"scheme"];
  NSMutableArray *only = [NSMutableArray arrayWithArray: [options objectForKey: @"only"]];
  NSMutableArray *skip = [NSMutableArray arrayWithArray: [options objectForKey: @"skip"]];
  NSMutableArray *testTargets = [NSMutableArray array];
  NSString *xctest = GSXCTestProgram();
  NSArray *extraFlags = nil;
  NSString *usage = nil;
  BOOL canSkip = NO;
  BOOL canHost = NO;
  NSString *flags = [[[NSProcessInfo processInfo] environment] objectForKey: @"XCTEST_FLAGS"];
  NSEnumerator *en = nil;
  id target = nil;
  BOOL passed = YES;
  NSUInteger ran = 0;

  // Which test targets.
  if (targetName != nil)
    {
      target = [self _targetNamed: targetName];
      if (target == nil || ![[target productType] isEqualToString: TEST_TYPE])
        {
          xcprintf("*** %s is not a unit-test target in this project\n", [targetName cString]);
          return NO;
        }
      [testTargets addObject: target];
    }
  else if (schemeName != nil)
    {
      NSString *path = [self _schemePathForName: schemeName];
      GSXCSchemeTests *scheme = path ? [GSXCSchemeTests testsFromSchemeAtPath: path] : nil;
      NSString *name = nil;

      if (scheme == nil)
        {
          xcprintf("*** Could not read scheme %s\n", [schemeName cString]);
          return NO;
        }
      en = [[scheme targets] objectEnumerator];
      while ((name = [en nextObject]) != nil)
        {
          target = [self _targetNamed: name];
          if (target != nil && [[target productType] isEqualToString: TEST_TYPE])
            {
              [testTargets addObject: target];
            }
        }
      [skip addObjectsFromArray: [scheme skippedTests]];
      [only addObjectsFromArray: [scheme selectedTests]];
    }
  else
    {
      en = [[self targets] objectEnumerator];
      while ((target = [en nextObject]) != nil)
        {
          if ([target isKindOfClass: [PBXNativeTarget class]]
              && [[target productType] isEqualToString: TEST_TYPE])
            {
              [testTargets addObject: target];
            }
        }
    }

  if ([testTargets count] == 0)
    {
      xcputs("*** No unit-test targets to run");
      return NO;
    }
  if (xctest == nil)
    {
      xcputs("*** Could not find xctest (install tools-xctest, or set XCTEST)");
      return NO;
    }

  usage = GSXCTestUsage(xctest);
  canSkip = [usage rangeOfString: @"-skip-testing"].location != NSNotFound;
  canHost = [usage rangeOfString: @"-host"].location != NSNotFound;

  // As xcodebuild test does, build first.
  if ([self build] == NO)
    {
      return NO;
    }

  extraFlags = [flags length] > 0
    ? [[flags componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]]
        filteredArrayUsingPredicate: [NSPredicate predicateWithFormat: @"length > 0"]]
    : [NSArray array];

  en = [testTargets objectEnumerator];
  while ((target = [en nextObject]) != nil)
    {
      NSString *bundle = GSXCProductPath(target);
      NSString *bundleName = [[bundle lastPathComponent] stringByDeletingPathExtension];
      NSArray *targetOnly = GSXCIdentifiersForTarget(only, [target name], bundleName);
      NSArray *targetSkip = GSXCIdentifiersForTarget(skip, [target name], bundleName);
      NSString *host = [self _hostForTestTarget: target];
      NSMutableArray *arguments = [NSMutableArray arrayWithObject: bundle];
      NSEnumerator *ien = nil;
      NSString *identifier = nil;
      NSTask *task = nil;

      // Selecting tests elsewhere leaves this target out, as in xcodebuild.
      if ([only count] > 0 && [targetOnly count] == 0)
        {
          continue;
        }

      if ([targetOnly count] > 0)
        {
          NSString *selection = GSXCSelectionForTarget(only, [target name]);

          if (selection != nil)
            {
              [arguments addObject: @"-XCTest"];
              [arguments addObject: selection];
            }
        }
      if ([targetSkip count] > 0)
        {
          if (canSkip == NO)
            {
              xcprintf("*** %s: skipping tests needs an xctest with -skip-testing, which %s lacks\n",
                       [[target name] cString], [xctest cString]);
              passed = NO;
              ran++;
              continue;
            }
          ien = [targetSkip objectEnumerator];
          while ((identifier = [ien nextObject]) != nil)
            {
              [arguments addObject: [@"-skip-testing:" stringByAppendingString: identifier]];
            }
        }
      if (host != nil)
        {
          if (canHost == NO)
            {
              xcprintf("*** %s runs inside %s (TEST_HOST), which needs an xctest with -host, which %s lacks\n",
                       [[target name] cString], [host cString], [xctest cString]);
              passed = NO;
              ran++;
              continue;
            }
          [arguments addObject: @"-host"];
          [arguments addObject: host];
        }
      [arguments addObjectsFromArray: extraFlags];

      xcprintf("=== Testing Target %s%s%s%s with %s\n", BOLD, GREEN, [[target name] cString], RESET,
               [xctest cString]);
      fflush(stdout);

      task = AUTORELEASE([[NSTask alloc] init]);
      [task setLaunchPath: xctest];
      [task setArguments: arguments];
      [task launch];
      [task waitUntilExit];
      ran++;

      if ([task terminationStatus] != 0)
        {
          passed = NO;
          xcprintf("=== Tests %sFAILED%s for %s\n", RED, RESET, [[target name] cString]);
        }
      else
        {
          xcprintf("=== Tests %spassed%s for %s\n", GREEN, RESET, [[target name] cString]);
        }
    }

  if (ran == 0)
    {
      xcputs("*** No test target matched the selected tests");
      return NO;
    }
  return passed;
}

@end
