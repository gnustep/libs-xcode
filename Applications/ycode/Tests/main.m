/*
   Project: Ycode

   Copyright (C) 2025 Free Software Foundation

   Author: Gregory Casamento

   Created: 2025-01-15

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <AppKit/AppKit.h>
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>
#import <XCode/PBXGroup.h>
#import <XCode/PBXNativeTarget.h>
#import <XCode/PBXFileReference.h>
#import "YCodeBuildSystem.h"
#import "YCodeWindowController.h"
#import "YCodeProject.h"
#import "YCodeDocumentController.h"
#import "YCodeProjectNavigatorController.h"
#import "YCodeProjectNavigatorItem.h"
#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCodeSyntaxHighlighter.h"
#import "YCEditorView.h"
#import "AppController.h"
#include <math.h>

@interface YCodeProjectNavigatorController (Testing)
- (NSString *)resolvedFilePathForNavigatorItem:(YCodeProjectNavigatorItem *)item;
@end

static NSUInteger failures = 0;

static void testAssert(BOOL condition, NSString *message)
{
  if (!condition)
    {
      NSLog(@"FAIL: %@", message);
      failures++;
    }
}

static BOOL colorMatches(NSColor *color, CGFloat red, CGFloat green, CGFloat blue)
{
  NSColor *rgb = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
  return rgb && fabs([rgb redComponent] - red) < 0.001
    && fabs([rgb greenComponent] - green) < 0.001
    && fabs([rgb blueComponent] - blue) < 0.001;
}

static void testApplicationStartup(void)
{
  AppController *delegate = [[AppController alloc] init];
  [NSApp setDelegate:delegate];
  [delegate buildMainMenu];
  [NSApp finishLaunching];
  [delegate applicationDidFinishLaunching:nil];
  testAssert([[[NSDocumentController sharedDocumentController] documents] count] == 0,
    @"Launching does not open an untitled project");
  testAssert(![delegate applicationShouldOpenUntitledFile:NSApp], @"Suppress automatic untitled documents");
#ifdef GNUSTEP
  NSMenu *menu = [NSApp mainMenu];
  testAssert([[[menu itemAtIndex:0] title] isEqualToString:@"Info"],
    @"GNUstep main menu starts with Info after launch");
  testAssert([[[menu itemWithTitle:@"Info"] submenu] itemWithTitle:@"Preferences..."] != nil,
    @"Preferences belong to Info");
  testAssert([[[menu itemWithTitle:@"Info"] submenu] itemWithTitle:@"Help"] != nil,
    @"Help belongs to Info");
  testAssert([[menu itemWithTitle:@"Services"] submenu] == [NSApp servicesMenu],
    @"Services submenu is registered with the application");
  testAssert([[menu itemWithTitle:@"Windows"] submenu] == [NSApp windowsMenu]
    && [menu itemWithTitle:@"Project"] != nil, @"GNUstep Project and Windows menus are available");
  testAssert([[menu itemAtIndex:[menu numberOfItems] - 1] action] == @selector(terminate:)
    && [[menu itemAtIndex:[menu numberOfItems] - 2] action] == @selector(hide:),
    @"Hide and Quit are at the end of the main menu");
#endif
  [NSApp setDelegate:nil];
  [delegate autorelease];
}

static void testEditorColors(void)
{
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
    initWithFilePath:@"Example.c" content:@"int ordinary = 42;"];
  NSTextView *view = [document textView];
  YCodeSyntaxHighlighter *highlighter = [document syntaxHighlighter];
  NSArray *backgrounds = [NSArray arrayWithObjects:[NSColor whiteColor],
    [NSColor blackColor], [NSColor colorWithDeviceRed:0.2 green:0.4 blue:0.7 alpha:1.0], nil];
  NSUInteger index;
  for (index = 0; index < [backgrounds count]; index++)
    {
      NSColor *background = [[backgrounds objectAtIndex:index]
        colorUsingColorSpaceName:NSDeviceRGBColorSpace];
      CGFloat red = 1.0 - [background redComponent];
      CGFloat green = 1.0 - [background greenComponent];
      CGFloat blue = 1.0 - [background blueComponent];
      [view setBackgroundColor:background];
      [document applySyntaxHighlighting];
      testAssert(colorMatches([[view textStorage] attribute:NSForegroundColorAttributeName
        atIndex:4 effectiveRange:NULL], red, green, blue), @"Ordinary text inverts background RGB");
      testAssert([[[view textStorage] attribute:NSForegroundColorAttributeName
        atIndex:15 effectiveRange:NULL] isEqual:[highlighter numberColor]], @"Keep number color");
      testAssert(colorMatches([[view typingAttributes] objectForKey:NSForegroundColorAttributeName],
        red, green, blue), @"New text uses inverse background");
      [highlighter removeHighlighting];
      testAssert(colorMatches([[view textStorage] attribute:NSForegroundColorAttributeName
        atIndex:0 effectiveRange:NULL], red, green, blue), @"Removing syntax keeps inverse foreground");
    }
  [document release];
  YCEditorView *editor = [[YCEditorView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
  [editor setText:@"plain text"];
  [editor setBackgroundColor:[NSColor blackColor]];
  testAssert(colorMatches([[editor textView] textColor], 1, 1, 1),
    @"Editor without a highlighter refreshes foreground when background changes");
  [editor release];
}

static void testEditorFiles(NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *package = [directory stringByAppendingPathComponent:@"Nested.xcodeproj"];
  NSString *sources = [directory stringByAppendingPathComponent:@"Sources With Spaces/Nested"];
  NSString *first = [sources stringByAppendingPathComponent:@"Example.h"];
  NSString *second = [directory stringByAppendingPathComponent:@"Example.h"];
  NSString *contents = @"{ objects = {"
    @" ROOT = { isa = PBXProject; mainGroup = MAIN; };"
    @" MAIN = { isa = PBXGroup; children = (GROUP); sourceTree = \"<group>\"; };"
    @" GROUP = { isa = PBXGroup; path = \"Sources With Spaces\"; children = (VIRTUAL); sourceTree = \"<group>\"; };"
    @" VIRTUAL = { isa = PBXGroup; name = Logical; children = (NESTED); sourceTree = \"<group>\"; };"
    @" NESTED = { isa = PBXGroup; path = Nested; children = (FILE, ROOTFILE, ABSOLUTE, SDK); sourceTree = \"<group>\"; };"
    @" FILE = { isa = PBXFileReference; path = Example.h; sourceTree = \"<group>\"; };"
    @" ROOTFILE = { isa = PBXFileReference; path = Example.h; sourceTree = SOURCE_ROOT; };"
    @" ABSOLUTE = { isa = PBXFileReference; path = \"/tmp/Ycode-absolute.h\"; sourceTree = \"<absolute>\"; };"
    @" SDK = { isa = PBXFileReference; path = Example.h; sourceTree = SDKROOT; };"
    @" }; rootObject = ROOT; }";
  [manager createDirectoryAtPath:package withIntermediateDirectories:YES attributes:nil error:NULL];
  [manager createDirectoryAtPath:sources withIntermediateDirectories:YES attributes:nil error:NULL];
  [contents writeToFile:[package stringByAppendingPathComponent:@"project.pbxproj"]
            atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [@"// nested source\n" writeToFile:first atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [@"// root source\n" writeToFile:second atomically:YES encoding:NSUTF8StringEncoding error:NULL];

  YCodeProject *document = [[YCodeProject alloc] init];
  NSError *error = nil;
  testAssert([document readFromURL:[NSURL fileURLWithPath:package]
                           ofType:@"YCodeXcodeProjectType" error:&error], @"Load nested file fixture");
  [document makeWindowControllers];
  [document showWindows];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  YCodeEditorController *editor = [document editorController];
  NSDictionary *objects = [[document container] objects];
  YCodeProjectNavigatorItem *nested = [navigator itemForObject:[objects objectForKey:@"FILE"]];
  YCodeProjectNavigatorItem *root = [navigator itemForObject:[objects objectForKey:@"ROOTFILE"]];
  testAssert([[navigator resolvedFilePathForNavigatorItem:nested] isEqual:first],
             @"Resolve nested groups, spaces, and logical groups without paths");
  testAssert([[navigator resolvedFilePathForNavigatorItem:root] isEqual:second],
             @"SOURCE_ROOT ignores parent group paths and duplicate basenames");
  testAssert([[navigator resolvedFilePathForNavigatorItem:
    [navigator itemForObject:[objects objectForKey:@"ABSOLUTE"]]] isEqual:@"/tmp/Ycode-absolute.h"],
    @"Keep absolute file paths");
  testAssert([navigator resolvedFilePathForNavigatorItem:
    [navigator itemForObject:[objects objectForKey:@"SDK"]]] == nil,
    @"Do not open a project file for an unresolved SDK reference");

  // Repeated failed reads used to release the project's editor controller.
  NSUInteger index;
  for (index = 0; index < 3; index++)
    testAssert(![editor openFile:[directory stringByAppendingPathComponent:@"Missing.h"]],
               @"Missing file returns failure without destroying the editor");
  testAssert([[editor openDocuments] count] == 0, @"Failed reads create no tabs");
  [[navigator outlineView] expandItem:[[navigator rootItems] objectAtIndex:0] expandChildren:YES];
  testAssert([[navigator outlineView] rowForItem:nested] >= 0, @"Nested file is visible for selection");
  [navigator selectItem:nested];
  testAssert([[[editor currentDocument] content] isEqual:@"// nested source\n"],
             @"Selecting a nested source displays its contents");
  [navigator selectItem:root];
  testAssert([[[editor currentDocument] content] isEqual:@"// root source\n"],
             @"Selecting another source displays its own contents");
  [navigator selectItem:nested];
  testAssert([[editor openDocuments] count] == 2, @"Repeated selection reuses open tabs");
  NSMutableString *longText = [NSMutableString string];
  for (index = 0; index < 200; index++)
    [longText appendString:@"A long source line that must remain reachable when scrolling through the editor.\n"];
  [longText appendString:[@"wide " stringByPaddingToLength:2000 withString:@"wide " startingAtIndex:0]];
  [[editor currentDocument] setContent:longText];
  NSTextView *scrollingText = [[editor currentDocument] textView];
  NSScrollView *editorScroll = [[editor currentDocument] scrollView];
  testAssert([[editorScroll horizontalRulerView] isKindOfClass:[YCEditorRulerView class]]
    && [[editorScroll verticalRulerView] isKindOfClass:[YCEditorRulerView class]],
    @"Both editor rulers use text coordinates");
  [[scrollingText window] display];
  [[scrollingText layoutManager] ensureLayoutForTextContainer:[scrollingText textContainer]];
  [[scrollingText window] display];
  testAssert(NSHeight([scrollingText frame]) > NSHeight([editorScroll documentVisibleRect]),
    @"Long files extend beyond the editor viewport");
  testAssert(NSWidth([scrollingText frame]) > NSWidth([editorScroll documentVisibleRect]),
    @"Long source lines extend horizontally beyond the editor viewport");
  [scrollingText scrollRangeToVisible:NSMakeRange([longText length], 0)];
  testAssert(NSMinY([editorScroll documentVisibleRect]) > 0,
    @"Can scroll to the end of a long file");
  testAssert(NSMinX([editorScroll documentVisibleRect]) > 0,
    @"Can scroll to the end of a long line");
  testAssert(NSEqualRects([editorScroll frame], [[editor tabView] contentRect]),
    @"Editor scroll view fills the selected tab");
  NSWindow *editorWindow = [scrollingText window];
  [editorWindow setContentSize:NSMakeSize(1100, 760)];
  testAssert(NSEqualRects([editorScroll frame], [[editor tabView] contentRect]),
    @"Editor scroll view fills the tab after resizing the window");
  [scrollingText scrollRangeToVisible:NSMakeRange(0, 0)];
  testAssert(NSMinY([editorScroll documentVisibleRect]) == 0,
    @"Can scroll back to the start after resizing");
  [editor setEditorFont:[NSFont userFixedPitchFontOfSize:18.0]];
  [[editor currentDocument] setContent:@"0123456789012345678901234567890123456789\r\n\r\nUnicode: é 漢字\nLast line\n"];
  [editorWindow display];
  [[editor currentDocument] setContent:@"int ordinary = 42;"];
  [editor setBackgroundColor:[NSColor colorWithDeviceRed:0.2 green:0.4 blue:0.7 alpha:1.0]];
  NSTextView *textView = [[editor currentDocument] textView];
  testAssert(colorMatches([[textView textStorage] attribute:NSForegroundColorAttributeName
    atIndex:4 effectiveRange:NULL], 0.8, 0.6, 0.3), @"Background updates open documents");
  [editor setSyntaxHighlighting:NO];
  testAssert(colorMatches([[textView textStorage] attribute:NSForegroundColorAttributeName
    atIndex:15 effectiveRange:NULL], 0.8, 0.6, 0.3), @"Disabling syntax restores inverse color");
  [editor setSyntaxHighlighting:YES];
  testAssert([[[textView textStorage] attribute:NSForegroundColorAttributeName
    atIndex:15 effectiveRange:NULL] isEqual:[[[editor currentDocument] syntaxHighlighter] numberColor]],
    @"Enabling syntax restores token colors");
  [[editor currentDocument] setModified:NO];
  testAssert([editor closeFile:first] && [editor closeFile:second], @"Close source tabs");
  testAssert([editor openFile:first], @"Reopen source after closing tabs");
  [document close];
  [document release];
}

static void waitForBuild(YCodeBuildSystem *build, BOOL running)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
  while ([deadline timeIntervalSinceNow] > 0 && [build isBusy])
    {
      if (running && [build isRunning] &&
          [[build buildOutput] rangeOfString:@"application output"].location != NSNotFound &&
          [[build buildErrors] rangeOfString:@"application-output"].location != NSNotFound) break;
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
}

static void writeExecutable(NSString *path, NSString *contents)
{
  [contents writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [[NSFileManager defaultManager] setAttributes:
    [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0755] forKey:NSFilePosixPermissions]
    ofItemAtPath:path error:NULL];
}

static void testBuildAndRun(NSString *temporaryDirectory)
{
  NSString *root = [temporaryDirectory stringByAppendingPathComponent:@"Build With Spaces"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
  YCodeProject *document = [[YCodeProject alloc] init];
  PBXProject *project = AUTORELEASE([[PBXProject alloc] init]);
  PBXNativeTarget *target = AUTORELEASE([[PBXNativeTarget alloc] init]);
  [target setName:@"RunTarget"];
  [target setProductType:@"com.apple.product-type.application"];
  [target setProductReference:AUTORELEASE([[PBXFileReference alloc] initWithPath:@"Run Product.app"])];
  [project setTargets:[NSMutableArray arrayWithObject:target]];
  [document setProject:project];
  [document setProjectPath:[root stringByAppendingPathComponent:@"Run Project.xcodeproj"]];
  YCodeBuildSystem *build = [document buildSystem];
  [build setEnvironmentVariable:[root stringByAppendingString:@":/usr/bin:/bin"] forKey:@"PATH"];
#ifdef GNUSTEP
  NSString *tool = [root stringByAppendingPathComponent:@"buildtool"];
#else
  NSString *tool = [root stringByAppendingPathComponent:@"xcodebuild"];
#endif
  writeExecutable(tool, @"#!/bin/sh\nprintf '%s\\n' \"$@\"\necho build-error >&2\n"
    @"if [ \"$MODE\" = fail ]; then exit 3; fi\n"
    @"if [ \"$MODE\" = slow ]; then echo waiting; sleep 30; touch unwanted; fi\n"
    @"mkdir -p 'build/RunTarget/Products/Run Product.app'\n"
    @"cp runner 'build/RunTarget/Products/Run Product.app/Run Product'\n");
  writeExecutable([root stringByAppendingPathComponent:@"runner"],
    @"#!/bin/sh\necho application-output >&2\necho 'application output'\n"
    @"if [ \"$MODE\" = exit ]; then exit 0; fi\nexec sleep 30\n");
  // An executable in the source directory must never be mistaken for the product.
  writeExecutable([root stringByAppendingPathComponent:@"unrelated"], @"#!/bin/sh\ntouch unwanted\n");
  YCodeWindowController *window = [[YCodeWindowController alloc] init];
  [window setProject:document];
  [window showWindow:nil];
  [window runProject:nil];
  testAssert([build isBuilding], @"Play starts an asynchronous build");
  testAssert(![build run] && ![build build], @"Reject duplicate operations while busy");
  waitForBuild(build, YES);
  testAssert([build isRunning], @"Successful build launches the named application product");
  testAssert([[build buildOutput] rangeOfString:[document projectPath]].location != NSNotFound,
    @"Build arguments preserve project paths containing spaces");
  testAssert([[build buildOutput] rangeOfString:@"RunTarget"].location != NSNotFound,
    @"Build selects the runnable target");
  testAssert([[build buildErrors] rangeOfString:@"build-error"].location != NSNotFound &&
    [[build buildErrors] rangeOfString:@"application-output"].location != NSNotFound,
    @"Drain stderr from both the build and application");
  NSTextView *console = [window valueForKey:@"_consoleTextView"];
  testAssert([[console string] rangeOfString:@"application output"].location != NSNotFound,
    @"Window console receives live process output");
  [window stopProject:nil];
  waitForBuild(build, NO);
  testAssert(![build isBusy] && [build status] == YCodeBuildStatusCancelled,
    @"Stop terminates the application and preserves cancelled status");
  [build setEnvironmentVariable:@"fail" forKey:@"MODE"];
  [window runProject:nil];
  waitForBuild(build, NO);
  testAssert([build status] == YCodeBuildStatusFailed &&
    [[build buildOutput] rangeOfString:@"application output"].location == NSNotFound,
    @"Failed build never launches a stale product");
  [build setEnvironmentVariable:@"slow" forKey:@"MODE"];
  [window runProject:nil];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5];
  while ([deadline timeIntervalSinceNow] > 0 &&
    [[build buildOutput] rangeOfString:@"waiting"].location == NSNotFound)
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
  [window stopProject:nil];
  waitForBuild(build, NO);
  testAssert(![build isBusy] && [build status] == YCodeBuildStatusCancelled,
    @"Stop cancels an active build including its child process");
  testAssert(![manager fileExistsAtPath:[root stringByAppendingPathComponent:@"unwanted"]],
    @"Cancellation prevents remaining build steps and unrelated scripts never run");
  [build setEnvironmentVariable:@"exit" forKey:@"MODE"];
  [window runProject:nil];
  waitForBuild(build, NO);
  testAssert([build status] == YCodeBuildStatusIdle &&
    [[build buildOutput] rangeOfString:@"application output"].location != NSNotFound,
    @"Play works again after cancellation and drains output before finishing");
  [window buildProject:nil];
  waitForBuild(build, NO);
  testAssert([build status] == YCodeBuildStatusSuccess &&
    [[build buildOutput] rangeOfString:@"application output"].location == NSNotFound,
    @"Build alone does not run the application");
  [build setEnvironmentVariable:@"/nonexistent" forKey:@"PATH"];
  [window runProject:nil];
  waitForBuild(build, NO);
  testAssert([build status] == YCodeBuildStatusFailed && [[build buildErrors] length] > 0,
    @"Missing build tools fail with console diagnostics");
  [build setEnvironmentVariable:[root stringByAppendingString:@":/usr/bin:/bin"] forKey:@"PATH"];
  [document setProjectPath:[root stringByAppendingPathComponent:@"Run Project.pcproj"]];
  [@"# fixture" writeToFile:[root stringByAppendingPathComponent:@"CMakeLists.txt"]
    atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  writeExecutable([root stringByAppendingPathComponent:@"cmake"],
    @"#!/bin/sh\nif [ \"$1\" = -S ]; then sleep 0.1; touch build/CMakeCache.txt; echo configured; "
    @"else test -f build/CMakeCache.txt || exit 4; echo compiled; fi\n");
  [window runProject:nil];
  waitForBuild(build, NO);
  testAssert([build status] == YCodeBuildStatusIdle &&
    [[build buildOutput] rangeOfString:@"configured"].location != NSNotFound &&
    [[build buildOutput] rangeOfString:@"compiled"].location != NSNotFound,
    @"CMake configuration finishes before building and running");
  [build setTargetName:@"MissingTarget"];
  testAssert(![build run] && ![build isBusy], @"Missing runnable targets fail without launching another product");
  [build setTargetName:nil];
  [document setProjectPath:nil];
  testAssert(![build build] && ![build isBusy], @"Missing project paths do not leave the build busy");
  [window setProject:nil];
  [window close];
  [window release];
  [document close];
  [document release];
}

static void testBuildIssuesPane(NSString *temporaryDirectory)
{
  YCodeProject *project = [[YCodeProject alloc] init];
  [project setProjectPath:[temporaryDirectory stringByAppendingPathComponent:@"Issues.xcodeproj"]];
  YCodeWindowController *controller = [[YCodeWindowController alloc] init];
  [controller setProject:project];
  [controller showWindow:nil];
  [controller setBottomPanelVisible:YES];
  NSSplitView *split = [controller valueForKey:@"_editorSplitView"];
  NSTabView *editor = [controller valueForKey:@"_editorTabView"];
  NSView *results = [controller valueForKey:@"_bottomView"];
  NSTabView *tabs = [controller valueForKey:@"_bottomTabView"];
  NSTableView *table = [controller valueForKey:@"_issuesTableView"];
  testAssert(![split isVertical] && [editor superview] == split && [results superview] == split,
    @"Source and build results share a horizontal split view");
  testAssert(!NSIntersectsRect([editor frame], [results frame]) &&
    NSHeight([editor frame]) > 0 && NSHeight([results frame]) > 0 &&
    NSMaxY([editor frame]) <= NSMinY([results frame]),
    @"Build results resize the source instead of covering it");
  [split setPosition:NSHeight([split bounds]) * 0.6 ofDividerAtIndex:0];
  [[controller window] setContentSize:NSMakeSize(1200, 780)];
  testAssert(!NSIntersectsRect([editor frame], [results frame]) &&
    NSContainsRect([split bounds], [results frame]), @"Dragging and resizing keeps panes separate");
  [controller setBottomPanelVisible:NO];
  testAssert([results superview] == nil && fabs(NSHeight([editor frame]) - NSHeight([split bounds])) < 1,
    @"Hiding build results restores the editor's full height");
  [controller setBottomPanelVisible:YES];
  testAssert([[split subviews] count] == 2 && !NSIntersectsRect([editor frame], [results frame]),
    @"Showing results restores the split without duplicate panes");

  NSString *source = [temporaryDirectory stringByAppendingPathComponent:@"Issue Source.m"];
  NSString *text = @"first line\n  invalidSymbol();\nlast line\n";
  [text writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  YCodeBuildSystem *build = [project buildSystem];
  [controller buildSystemDidStartBuild:build];
  [controller buildSystem:build didReceiveOutput:@"ordinary build progress\n"];
  [controller buildSystem:build didReceiveError:@"\033[1mIssue Source.m:2:"];
  testAssert([table numberOfRows] == 0, @"Incomplete diagnostic waits for its remaining output");
  [controller buildSystem:build didReceiveError:@"3: \033[31merror: unknown symbol\033[0m\n"];
  [controller buildSystem:build didReceiveOutput:[NSString stringWithFormat:
    @"%@:3: warning: unused expression\n", source]];
  [controller buildSystem:build didReceiveError:@"Issue Source.m:1: note: declared here"];
  [controller buildSystemDidFinishBuild:build success:NO];
  testAssert([table numberOfRows] == 3, @"Collect chunked, colored, stdout and unterminated diagnostics");
  testAssert([[[tabs selectedTabViewItem] identifier] isEqual:@"issues"],
    @"Build completion selects issues when diagnostics exist");
  testAssert(fabs([[[table tableColumns] objectAtIndex:0] width] -
    [[table enclosingScrollView] contentSize].width) < 4,
    @"Issues column fills the results pane");
  NSArray *issues = [controller valueForKey:@"_buildIssues"];
  testAssert([[[issues objectAtIndex:0] objectForKey:@"message"] isEqual:@"unknown symbol"] &&
    [[[issues objectAtIndex:0] objectForKey:@"path"] isEqual:source],
    @"Remove ANSI colors and resolve relative diagnostic paths");
  [table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  YCodeEditorDocument *document = [[controller editorController] currentDocument];
  testAssert([[document filePath] isEqual:source] && [document selectedRange].location == 13,
    @"Selecting an issue opens the source at its reported line and column");
  [document setSelectedRange:NSMakeRange(0, 0)];
  [table sendAction:[table action] to:[table target]];
  testAssert([document selectedRange].location == 13,
    @"Clicking the already selected issue returns to its location");
  [table selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
  testAssert([[document selectedText] isEqual:@"last line"],
    @"Diagnostics without columns select their source line");
  testAssert([[controller editorController] openDocuments].count == 1,
    @"Navigating another issue reuses the open source tab");

  [controller buildSystemDidStartBuild:build];
  testAssert([table numberOfRows] == 0, @"A new build clears stale issues");
  [controller buildSystem:build didReceiveOutput:[NSString stringWithFormat:
    @"make[1]: Entering directory '%@'\n", temporaryDirectory]];
  [controller buildSystem:build didReceiveError:@"Issue Source.m:999:999: warning: stale location\n"];
  [controller buildSystem:build didReceiveError:@"clang: error: linker command failed\n"];
  [controller buildSystemDidFinishBuild:build success:YES];
  testAssert([table numberOfRows] == 2, @"Include tool errors without a source location");
  [table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
  testAssert(NSMaxRange([document selectedRange]) <= [[document content] length],
    @"Outdated diagnostic positions are clamped to the source");
  [controller buildSystem:build didReceiveOutput:@"Issue Source.m:2:3: error: runtime text\n"];
  testAssert([table numberOfRows] == 2, @"Runtime output does not become a build issue");
  [controller setProject:nil];
  [controller close];
  [controller release];
  [project close];
  [project release];
}

int main(void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *temporaryDirectory = [NSTemporaryDirectory()
    stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]];
  NSString *package = [temporaryDirectory stringByAppendingPathComponent:@"Sample Project.xcodeproj"];
  NSError *error = nil;
  YCodeDocumentController *controller = [YCodeDocumentController sharedDocumentController];
  YCodeProject *document;
  NSURL *url;

  [NSApplication sharedApplication];
  testApplicationStartup();
  testEditorColors();
  testAssert([manager createDirectoryAtPath:temporaryDirectory
              withIntermediateDirectories:YES attributes:nil error:&error],
             @"Create test directory");
  testAssert([manager copyItemAtPath:@"../Ycode.xcodeproj" toPath:package error:&error],
             @"Copy project fixture to a path with spaces");
  url = [NSURL fileURLWithPath:package];
  document = [controller openDocumentWithContentsOfURL:url display:NO error:&error];
  testAssert(document != nil && error == nil, @"Open xcodeproj through document controller");
  testAssert([[document project] isKindOfClass:[PBXProject class]], @"Decode PBXProject root");
  testAssert([[[document project] targets] count] > 0, @"Load targets");
  testAssert([[[[document project] mainGroup] children] count] > 0, @"Load groups and files");
  testAssert([[document project] container] == [document container], @"Associate project with container");
  testAssert([[[document container] filename] isEqualToString:
               [package stringByAppendingPathComponent:@"project.pbxproj"]], @"Use package contents path");
  testAssert([[document projectDirectoryPath] isEqualToString:temporaryDirectory], @"Resolve project directory");
  testAssert([controller openDocumentWithContentsOfURL:url display:NO error:&error] == document,
             @"Reuse already open project document");

  [document makeWindowControllers];
  [document showWindows];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  testAssert([[navigator rootItems] count] == 1, @"Populate project navigator");
  testAssert([[navigator outlineView] numberOfRows] > 1, @"Display and expand project in window");
  testAssert([[document windowControllers] count] == 1, @"Create project window");
  NSOutlineView *outline = [navigator outlineView];
  NSScrollView *navigatorScroll = [outline enclosingScrollView];
  testAssert([outline gridStyleMask] == NSTableViewGridNone, @"Navigator has no grid lines");
  testAssert(NSContainsRect([[navigatorScroll superview] bounds], [navigatorScroll frame]),
    @"Navigator scroll view stays inside its section");
  testAssert(fabs(NSWidth([navigatorScroll frame]) - NSWidth([[navigatorScroll superview] bounds])) < 1,
    @"Navigator scroll view fills the section width");
  testAssert(fabs([[outline outlineTableColumn] width] - [navigatorScroll contentSize].width) < 3,
    @"Navigator column fits the available viewport");
  testAssert(NSMinX([outline frame]) == 0 && NSMinX([navigatorScroll documentVisibleRect]) == 0,
    @"Navigator rows start at the left of the viewport");
  NSWindow *projectWindow = [[[document windowControllers] objectAtIndex:0] window];
  [projectWindow setContentSize:NSMakeSize(1100, 760)];
  testAssert(fabs([[outline outlineTableColumn] width] - [navigatorScroll contentSize].width) < 3,
    @"Navigator column follows the viewport after resizing");
  testAssert(NSContainsRect([[navigatorScroll superview] bounds], [navigatorScroll frame]),
    @"Resized navigator stays inside its section");
  NSSplitView *navigatorSplit = (NSSplitView *)[[navigatorScroll superview] superview];
  [navigatorSplit setPosition:300 ofDividerAtIndex:0];
  testAssert(fabs([[outline outlineTableColumn] width] - [navigatorScroll contentSize].width) < 3
    && NSMinX([outline frame]) == 0, @"Navigator remains fully visible after moving the divider");

  // A failed read must report an error and preserve an already loaded project.
  PBXProject *originalProject = [document project];
  NSArray *invalidContents = [NSArray arrayWithObjects:@"", @"not a property list",
    @"{ objects = {}; }",
    @"{ objects = { ROOT = { isa = PBXGroup; }; }; rootObject = ROOT; }", nil];
  NSString *invalidPackage = [temporaryDirectory stringByAppendingPathComponent:@"Invalid.xcodeproj"];
  [manager createDirectoryAtPath:invalidPackage withIntermediateDirectories:YES attributes:nil error:NULL];
  NSUInteger index;
  for (index = 0; index < [invalidContents count]; index++)
    {
      if (index > 0)
        [[invalidContents objectAtIndex:index] writeToFile:
          [invalidPackage stringByAppendingPathComponent:@"project.pbxproj"]
          atomically:YES encoding:NSUTF8StringEncoding error:NULL];
      error = nil;
      testAssert(![document readFromURL:[NSURL fileURLWithPath:invalidPackage]
                                ofType:@"YCodeXcodeProjectType" error:&error] && error != nil,
                 @"Reject missing, malformed, or invalid project root");
      testAssert([document project] == originalProject && [[document fileURL] isEqual:url],
                 @"Keep loaded document intact after failed read");
    }
  [document close];
  testEditorFiles(temporaryDirectory);
  testBuildAndRun(temporaryDirectory);
  testBuildIssuesPane(temporaryDirectory);
  [manager removeItemAtPath:temporaryDirectory error:NULL];
  NSLog(@"Ycode project loading checks: %lu failures", (unsigned long)failures);
  [pool drain];
  return failures ? 1 : 0;
}
