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
  [manager removeItemAtPath:temporaryDirectory error:NULL];
  NSLog(@"Ycode project loading checks: %lu failures", (unsigned long)failures);
  [pool drain];
  return failures ? 1 : 0;
}
