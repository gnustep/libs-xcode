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
#import "YCInspectorView.h"
#import "YCodeTextView.h"
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

static void testEditorEditing(NSString *directory)
{
  NSString *root = [directory stringByAppendingPathComponent:@"Editing Rules"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
    initWithFilePath:[root stringByAppendingPathComponent:@"Example.m"] content:@""];
  YCodeTextView *view = (YCodeTextView *)[document textView];
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
    styleMask:NSTitledWindowMask | NSResizableWindowMask backing:NSBackingStoreBuffered defer:NO];
  [window setReleasedWhenClosed:NO];
  [window setContentView:[document editorView]];
  [window makeKeyAndOrderFront:nil];
  [window makeFirstResponder:view];
  testAssert([view isKindOfClass:[YCodeTextView class]], @"Documents use ProjectCenter editing rules");
  testAssert([view editorIndentWidth] == 2 && [view editorTabWidth] == 2 && ![view editorUsesTabs],
    @"Default to ProjectCenter's two-space indentation");
  [view insertTab:nil];
  testAssert([[view string] isEqual:@"  "], @"Tab in an empty document inserts one tab stop");

  [document setContent:@"if (ready)"];
  [view setSelectedRange:NSMakeRange([[view string] length], 0)];
  [view insertNewline:nil];
  testAssert([[view string] isEqual:@"if (ready)\n  "], @"Return indents control statement bodies");
  [view insertText:@"{"];
  [view insertNewline:nil];
  testAssert([[view string] isEqual:@"if (ready)\n  {\n    "], @"Return indents inside an opening delimiter");
  [view insertText:@"}"];
  testAssert([[view string] isEqual:@"if (ready)\n  {\n  }"], @"Closing delimiter aligns with its opening line");
  [document setContent:@"{\n      value;\n}"];
  [view setSelectedRange:NSMakeRange(8, 0)];
  [view insertTab:nil];
  testAssert([[view string] isEqual:@"{\n  value;\n}"], @"Tab reindents the current line");
  [document setContent:@"{\n"];
  [view setSelectedRange:NSMakeRange(2, 0)];
  [view insertTab:nil];
  testAssert([[view string] isEqual:@"{\n  "], @"Tab handles the empty line at end of file");

  [document setContent:@"one\ntwo\nthree\n"];
  [document setModified:NO];
  [view setSelectedRange:NSMakeRange(0, 8)];
  NSUndoManager *undo = [view undoManager];
  [undo removeAllActions];
  [undo beginUndoGrouping];
  [view insertTab:nil];
  [undo endUndoGrouping];
  testAssert([[view string] isEqual:@"  one\n  two\nthree\n"],
    @"Tab shifts selected lines without touching the following line");
  testAssert([document isModified], @"Block indentation marks the document modified");
  [undo undo];
  testAssert([[view string] isEqual:@"one\ntwo\nthree\n"], @"Block indentation is undoable");
  [view setSelectedRange:NSMakeRange(0, 8)];
  [view insertTab:nil];
  [view insertBacktab:nil];
  testAssert([[view string] isEqual:@"one\ntwo\nthree\n"], @"Shift-Tab reverses block indentation");
  [view setSelectedRange:NSMakeRange(1, 0)];
  [view moveDownAndModifySelection:nil];
  testAssert(NSEqualRanges([view selectedRange], NSMakeRange(1, 4)), @"Shift-Down preserves the column and selection anchor");
  [view moveUpAndModifySelection:nil];
  testAssert(NSEqualRanges([view selectedRange], NSMakeRange(1, 0)), @"Reversing Shift-arrow contracts the selection");
  [view moveLeftAndModifySelection:nil];
  testAssert(NSEqualRanges([view selectedRange], NSMakeRange(0, 1)), @"Shift-Left extends backwards");
  [view moveRightAndModifySelection:nil];
  testAssert(NSEqualRanges([view selectedRange], NSMakeRange(1, 0)), @"Shift-Right contracts a backward selection");
  [document setContent:@"last\n"];
  [view setSelectedRange:NSMakeRange(2, 0)];
  [view moveDownAndModifySelection:nil];
  testAssert(NSMaxRange([view selectedRange]) == 5, @"Shift-Down can reach a trailing empty line");

  NSString *config = [root stringByAppendingPathComponent:@".clang-format"];
  [@"IndentWidth: 4\nTabWidth: 8\nUseTab: Never\n" writeToFile:config atomically:YES
    encoding:NSUTF8StringEncoding error:NULL];
  [document setFilePath:[root stringByAppendingPathComponent:@"Nested/Other.m"]];
  testAssert([view editorIndentWidth] == 4 && [view editorTabWidth] == 8 && ![view editorUsesTabs],
    @"Read indentation settings from the nearest parent .clang-format");
  [document setContent:@"{"];
  [view setSelectedRange:NSMakeRange(1, 0)];
  [view insertNewline:nil];
  testAssert([[view string] isEqual:@"{\n    "], @"Return uses the file's configured indent width");
  CGFloat cellWidth = [[view font] widthOfString:@"8"];
  testAssert(fabs([[view defaultParagraphStyle] defaultTabInterval] - 8 * cellWidth) < 0.01,
    @"Displayed tabs use the configured tab width");
  [@"IndentWidth: 4\nTabWidth: 4\nUseTab: Always\n" writeToFile:config atomically:YES
    encoding:NSUTF8StringEncoding error:NULL];
  [document setFilePath:[root stringByAppendingPathComponent:@"Tabs.m"]];
  [document setContent:@"{"];
  [view setSelectedRange:NSMakeRange(1, 0)];
  [view insertNewline:nil];
  testAssert([[view string] isEqual:@"{\n\t"], @"UseTab emits literal tabs");
  [view insertText:@"{"];
  [view insertNewline:nil];
  testAssert([[view string] isEqual:@"{\n\t{\n\t\t"], @"Nested literal-tab indentation uses visual columns");
  [view insertText:@"}"];
  testAssert([[view string] isEqual:@"{\n\t{\n\t}"], @"Closing delimiters preserve literal-tab indentation");
  [document setFilePath:[directory stringByAppendingPathComponent:@"Unconfigured.m"]];
  testAssert([view editorIndentWidth] == 2 && ![view editorUsesTabs], @"Changing files resets indentation settings");

  [document setContent:@""];
  [window setContentSize:NSMakeSize(900, 650)];
  NSClipView *clip = [[document scrollView] contentView];
  testAssert(NSWidth([view frame]) >= NSWidth([clip bounds]) &&
    NSHeight([view frame]) >= NSHeight([clip bounds]), @"Empty editable area grows with the window");
  [window setContentSize:NSMakeSize(350, 250)];
  testAssert(fabs(NSWidth([view frame]) - NSWidth([clip bounds])) < 1 &&
    fabs(NSHeight([view frame]) - NSHeight([clip bounds])) < 1, @"Empty editor shrinks without stale scrollable space");
  [document setContent:@"short"];
  [window setContentSize:NSMakeSize(1000, 700)];
  testAssert(NSWidth([view frame]) >= NSWidth([clip bounds]) &&
    NSHeight([view frame]) >= NSHeight([clip bounds]), @"Short source files fill the enlarged editable area");
  [window close];
  [window release];
  [document release];

  YCEditorView *editor = [[YCEditorView alloc] initWithFrame:NSMakeRect(0, 0, 400, 300)];
  [editor setFrameSize:NSMakeSize(850, 600)];
  testAssert(NSWidth([[editor textView] frame]) >= NSWidth([[[editor scrollView] contentView] bounds]),
    @"Standalone editor uses the same viewport resizing");
  [[editor textView] insertTab:nil];
  testAssert([[editor text] isEqual:@"  "], @"Standalone editor uses the same editing rules");
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
  [[editor currentDocument] setContent:@"short source\n"];
  [editorWindow setContentSize:NSMakeSize(1500, 900)];
  [editorWindow display];
  NSClipView *editorClip = [editorScroll contentView];
  testAssert(NSWidth([scrollingText frame]) >= NSWidth([editorClip bounds]) &&
    NSHeight([scrollingText frame]) >= NSHeight([editorClip bounds]),
    @"Actual project editor fills the viewport after enlarging the window");
  testAssert(NSEqualRects([editorScroll frame], [[editor tabView] contentRect]),
    @"Actual project scroll view fills the enlarged tab");
  // Switching away and back must size the formerly hidden editor as well.
  [editor openFile:second];
  [editorWindow setContentSize:NSMakeSize(1700, 1000)];
  [editor openFile:first];
  testAssert(NSWidth([scrollingText frame]) >= NSWidth([editorClip bounds]),
    @"Reselected source tab fills the window's new width");
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

  // New project/document instances exercise restoration, not existing tabs.
  document = [[YCodeProject alloc] init];
  [document readFromURL:[NSURL fileURLWithPath:package] ofType:@"YCodeXcodeProjectType" error:NULL];
  [document makeWindowControllers];
  editor = [document editorController];
  testAssert([[[editor currentDocument] filePath] isEqual:first] && [[editor openDocuments] count] == 1,
    @"Reopening a project restores its last source file");
  [editor openFile:second];
  [[editor tabView] selectTabViewItem:[editor tabForDocument:[editor documentForFilePath:first]]];
  [document close];
  [document release];

  NSString *otherPackage = [directory stringByAppendingPathComponent:@"Other.xcodeproj"];
  [manager copyItemAtPath:package toPath:otherPackage error:NULL];
  document = [[YCodeProject alloc] init];
  [document readFromURL:[NSURL fileURLWithPath:otherPackage] ofType:@"YCodeXcodeProjectType" error:NULL];
  [document makeWindowControllers];
  testAssert([[[document editorController] openDocuments] count] == 0,
    @"Source restoration is isolated to each project");
  [document close];
  [document release];

  document = [[YCodeProject alloc] init];
  [document readFromURL:[NSURL fileURLWithPath:package] ofType:@"YCodeXcodeProjectType" error:NULL];
  [document makeWindowControllers];
  editor = [document editorController];
  testAssert([[[editor currentDocument] filePath] isEqual:first],
    @"Restoration follows the selected tab rather than the last file opened");
  [editor closeFile:first];
  [document close];
  [document release];

  document = [[YCodeProject alloc] init];
  [document readFromURL:[NSURL fileURLWithPath:package] ofType:@"YCodeXcodeProjectType" error:NULL];
  [document makeWindowControllers];
  testAssert([[[document editorController] openDocuments] count] == 0,
    @"Explicitly closing the last source tab clears restoration");
  [[document editorController] openFile:first];
  [document close];
  [document release];
  [manager removeItemAtPath:first error:NULL];

  document = [[YCodeProject alloc] init];
  [document readFromURL:[NSURL fileURLWithPath:package] ofType:@"YCodeXcodeProjectType" error:NULL];
  [document makeWindowControllers];
  testAssert([[[document editorController] openDocuments] count] == 0,
    @"A deleted remembered source file does not create an empty tab or block project loading");
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

@interface YCodeDebuggerProbe : NSObject <YCodeDebuggerDelegate>
{
@public
  NSMutableString *commands;
  NSMutableString *output;
  NSString *file;
  NSUInteger line;
}
@end
@implementation YCodeDebuggerProbe
- (id)init
{
  if ((self = [super init])) { commands = [NSMutableString new]; output = [NSMutableString new]; }
  return self;
}
- (void)dealloc { [commands release]; [output release]; [file release]; [super dealloc]; }
- (void)debugger:(YCodeDebugger *)debugger sendCommand:(NSString *)command { [commands appendString:command]; }
- (void)debugger:(YCodeDebugger *)debugger output:(NSString *)text { [output appendString:text]; }
- (void)debugger:(YCodeDebugger *)debugger stoppedAtFile:(NSString *)path line:(NSUInteger)number
{ ASSIGN(file, path); line = number; }
@end

static void testDebuggerRecords(void)
{
  YCodeDebugger *debugger = [YCodeDebugger new];
  YCodeDebuggerProbe *probe = [YCodeDebuggerProbe new];
  [debugger setDelegate:probe];
  NSString *storage = [@"YCodeDebuggerTest:" stringByAppendingString:[[NSProcessInfo processInfo] globallyUniqueString]];
  [debugger setBreakpointStorageKey:storage];
  [debugger toggleBreakpointAtFile:@"/tmp/A \"quoted\".m" line:4];
  YCodeDebugger *restored = [YCodeDebugger new];
  [restored setBreakpointStorageKey:storage];
  [restored setDelegate:probe];
  [restored receiveData:[@"(gdb) \n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->commands rangeOfString:@"-break-insert"].location != NSNotFound,
    @"A new session restores project source breakpoints from preferences");
  [restored release];
  [probe->commands setString:@""];
  NSString *records = @"(gdb) \r\n12^done,bkpt={number=\"3\",fullname=\"/tmp/A \\\"quoted\\\".m\",line=\"4\"}\n"
    @"*running,thread-id=\"all\"\n~\"café\\n\"\n"
    @"*stopped,reason=\"breakpoint-hit\",frame={fullname=\"/tmp/A \\\"quoted\\\".m\",line=\"4\",args=[{name=\"argc\",value=\"1\"}]}\n";
  NSData *bytes = [records dataUsingEncoding:NSUTF8StringEncoding];
  for (NSUInteger i = 0; i < [bytes length]; i++)
    [debugger receiveData:[bytes subdataWithRange:NSMakeRange(i, 1)]];
  testAssert([debugger isReady] && ![debugger isRunning], @"Chunked MI records update ready/running/stopped state");
  testAssert([probe->file isEqual:@"/tmp/A \"quoted\".m"] && probe->line == 4,
    @"Escaped source paths and nested frames navigate correctly");
  testAssert([probe->output rangeOfString:@"café\n"].location != NSNotFound &&
    [probe->output rangeOfString:@"thread-id"].location == NSNotFound,
    @"Keep split UTF-8 stream output and hide MI bookkeeping");
  testAssert([probe->commands rangeOfString:@"-break-insert -f \"/tmp/A \\\"quoted\\\".m:4\"\n"].location != NSNotFound,
    @"Restore prelaunch breakpoints with MI quoting");
  [debugger toggleBreakpointAtFile:probe->file line:4];
  testAssert([probe->commands hasSuffix:@"-break-delete 3\n"], @"Delete breakpoint using debugger-assigned number");
  [debugger toggleBreakpointAtFile:@"/tmp/blank.m" line:1];
  [debugger receiveData:[@"^done,bkpt={number=\"4\",fullname=\"/tmp/blank.m\",line=\"2\",original-location=\"/tmp/blank.m:1\"}\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [debugger toggleBreakpointAtFile:@"/tmp/blank.m" line:1];
  testAssert([probe->commands hasSuffix:@"-break-delete 4\n"],
    @"Toggling the requested line removes a breakpoint relocated by GDB");
  [debugger receiveData:[@"*running,thread-id=\"all\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  [debugger restart];
  testAssert([probe->commands hasSuffix:@"-exec-interrupt --all\n"], @"Restart interrupts a running inferior first");
  [debugger receiveData:[@"*stopped,reason=\"signal-received\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->commands hasSuffix:@"-exec-run\n"], @"Restart waits for the stopped event before running");
  [debugger receiveData:[@"9^error,msg=\"No symbol\\n\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->output rangeOfString:@"Debugger error: No symbol"].location != NSNotFound,
    @"Display MI command failures in the console");
  NSDictionary *parsed = [YCodeDebugger parseRecord:@"24^done,stack=[frame={level=\"0\"},frame={level=\"1\"}]"];
  testAssert([[parsed objectForKey:@"stack"] count] == 2, @"Parse MI result lists as well as value lists");
  [YCodeDebugger parseRecord:@"^done,bad=[garbage"];
  [debugger reset];
  testAssert(![debugger isReady] && ![debugger isRunning], @"Reset session state after termination");
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:storage];
  [debugger release]; [probe release];
}

static void waitForDebugger(YCodeBuildSystem *build)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
  while ([deadline timeIntervalSinceNow] > 0 && [build isBusy] && ![[build debugger] isReady])
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
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
  // Exercise the actual asynchronous build/MI transport without requiring GDB on CI.
  id savedDebuggerPath = [[[NSUserDefaults standardUserDefaults] objectForKey:@"DebuggerPath"] retain];
  NSString *fakeGDB = [root stringByAppendingPathComponent:@"fake gdb"];
  writeExecutable(fakeGDB, @"#!/bin/sh\nprintf '%s\\n' \"$@\" > debugger-arguments\n"
    @"printf '(gdb) \\n'\nwhile IFS= read -r command; do\n"
    @"printf '%s\\n' \"$command\" >> debugger-commands\n"
    @"case \"$command\" in\n-exec-run) printf '*running,thread-id=\"all\"\\n*stopped,reason=\"exited-normally\"\\n';;\n"
    @"-gdb-exit) exit 0;;\n*) printf '^done\\n';;\nesac\ndone\n");
  [[NSUserDefaults standardUserDefaults] setObject:fakeGDB forKey:@"DebuggerPath"];
  for (NSUInteger session = 0; session < 2; session++) {
    [window debugProject:nil];
    waitForDebugger(build);
    testAssert([build isDebugging] && [[build debugger] isReady], @"Build and start a fresh debugger session");
    testAssert(![build debug] && ![build run], @"Debug session excludes competing builds and runs");
    [[build debugger] command:@"-exec-run"];
    [[build debugger] command:@"-gdb-exit"];
    waitForBuild(build, NO);
    testAssert(![build isBusy] && ![build isDebugging] && ![[build debugger] isReady],
      @"Debugger exit drains pipes and permits another session");
    testAssert([[build buildOutput] rangeOfString:@"exited-normally"].location != NSNotFound,
      @"MI transport reports inferior exit");
  }
  NSString *arguments = [NSString stringWithContentsOfFile:[root stringByAppendingPathComponent:@"debugger-arguments"]
    encoding:NSUTF8StringEncoding error:NULL];
  testAssert([arguments rangeOfString:@"--interpreter=mi2\n"].location != NSNotFound &&
    [arguments rangeOfString:@"Run Product.app/Run Product\n"].location != NSNotFound,
    @"Launch GDB in MI mode with the resolved bundle executable as one argument");
  [window debugProject:nil];
  waitForDebugger(build);
  [window stopProject:nil];
  waitForBuild(build, NO);
  testAssert(![build isBusy] && [build status] == YCodeBuildStatusCancelled, @"Stop closes a debugger session");
  [[NSUserDefaults standardUserDefaults] setObject:@"/missing/ycode-gdb" forKey:@"DebuggerPath"];
  [window debugProject:nil];
  waitForBuild(build, NO);
  testAssert(![build isDebugging] && [build status] == YCodeBuildStatusFailed,
    @"Missing debugger reports failure and releases session resources");
  if (savedDebuggerPath) [[NSUserDefaults standardUserDefaults] setObject:savedDebuggerPath forKey:@"DebuggerPath"];
  else [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DebuggerPath"];
  [savedDebuggerPath release];
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

  NSView *consolePane = [[tabs tabViewItemAtIndex:0] view];
  NSTextField *commandField = [[consolePane subviews] lastObject];
  NSView *consoleScroll = [[consolePane subviews] objectAtIndex:0];
  testAssert([commandField isKindOfClass:[NSTextField class]] &&
    [commandField action] == @selector(debugConsoleCommand:) &&
    !NSIntersectsRect([commandField frame], [consoleScroll frame]) &&
    NSContainsRect([consolePane bounds], [commandField frame]),
    @"Debugger input remains visible below console output after resizing");
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
  [controller buildSystem:build stoppedAtFile:source line:2];
  testAssert([[document selectedText] isEqual:@"  invalidSymbol();"],
    @"Debugger stop selects the source line in the existing editor tab");
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
  testDebuggerRecords();
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
  YCodeWindowController *windowController = [[document windowControllers] objectAtIndex:0];
  NSSplitView *navigatorSplit = [windowController valueForKey:@"_mainSplitView"];
  [navigatorSplit setPosition:300 ofDividerAtIndex:0];
  testAssert(fabs([[outline outlineTableColumn] width] - [navigatorScroll contentSize].width) < 3
    && NSMinX([outline frame]) == 0, @"Navigator remains fully visible after moving the divider");

  NSTabView *navigatorTabs = [windowController valueForKey:@"_navigatorTabView"];
  NSCell *navigatorCell = [[outline outlineTableColumn] dataCell];
  testAssert([navigatorCell isKindOfClass:NSClassFromString(@"YCodeNavigatorCell")],
    @"Navigator cell draws an icon alongside the filename");
  NSArray *extensions = [NSArray arrayWithObjects:@"m", @"mm", @"c", @"C",
    @"cc", @"cp", @"cpp", @"cxx", @"c++", @"h", @"hh", @"hpp", @"hxx",
    @"h++", @"swift", @"plist", @"png", @"xib", @"gorm", @"unknown", @"", nil];
  for (NSString *extension in extensions) {
    PBXFileReference *file = [[PBXFileReference alloc]
      initWithPath:[@"Example" stringByAppendingPathExtension:extension]];
    YCodeProjectNavigatorItem *item = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject:file type:YCodeNavigatorItemTypeFile];
    testAssert([item icon] != nil && NSEqualSizes([[item icon] size], NSMakeSize(16, 16)),
      [NSString stringWithFormat:@"Navigator has a small icon for '%@'", extension]);
    [[outline delegate] outlineView:outline willDisplayCell:navigatorCell
      forTableColumn:[outline outlineTableColumn] item:item];
    testAssert([navigatorCell image] == [item icon], @"Reused row receives its file icon");
    [item release];
    [file release];
  }
  for (NSString *name in [NSArray arrayWithObjects:@"FileM", @"FileMM", @"FileC",
      @"FileH", @"FileProject", nil]) {
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"tiff"
      inDirectory:@"ProjectCenterIcons"];
    NSImage *image = path ? [[NSImage alloc] initWithContentsOfFile:path] : nil;
    testAssert(image != nil, @"ProjectCenter icon resources are bundled and readable");
    [image release];
  }
  NSTabView *inspectorTabs = [windowController valueForKey:@"_inspectorTabView"];
  testAssert([navigatorTabs isKindOfClass:[NSTabView class]]
    && [navigatorTabs numberOfTabViewItems] == 3, @"Navigator uses three native tabs");
  for (NSTabViewItem *item in [navigatorTabs tabViewItems])
    testAssert(![[item label] isEqual:@"Issues"], @"No Issues navigator tab");
  [navigatorTabs selectTabViewItemWithIdentifier:@"search"];
  testAssert([[[navigatorTabs selectedTabViewItem] identifier] isEqual:@"search"],
    @"Native navigator switches pages");
  [navigatorTabs selectTabViewItemWithIdentifier:@"project"];
  [windowController setupInspectorArea];
  [windowController setupNavigatorArea];
  testAssert([inspectorTabs numberOfTabViewItems] == 1,
    @"Repeated setup keeps a single File inspector without Quick Help");
  YCInspectorView *extra = [[YCInspectorView alloc] initWithFrame:NSZeroRect];
  [windowController registerInspectorView:extra];
  [windowController registerInspectorView:extra];
  testAssert([inspectorTabs numberOfTabViewItems] == 2, @"Inspectors register uniquely");
  [extra release];
  NSString *inspectedPath = [temporaryDirectory stringByAppendingPathComponent:@"Inspector.m"];
  [@"int main(void) { return 0; }" writeToFile:inspectedPath atomically:YES
    encoding:NSUTF8StringEncoding error:NULL];
  YCodeEditorController *editor = [windowController editorController];
  [editor openFile:inspectedPath];
  NSView *fileInspector = [[inspectorTabs tabViewItemAtIndex:0] view];
  NSTextView *details = [fileInspector valueForKey:@"_details"];
  testAssert([[details string] rangeOfString:inspectedPath].location != NSNotFound
    && [[details string] rangeOfString:@"Objective-C source"].location != NSNotFound,
    @"File inspector follows the active source file");
  for (YCodeEditorDocument *openDocument in [NSArray arrayWithArray:[editor openDocuments]])
    [editor closeFile:[openDocument filePath]];
  testAssert([[details string] isEqual:@"No source file selected."],
    @"Closing the final editor clears File inspector");

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
  testEditorEditing(temporaryDirectory);
  testEditorFiles(temporaryDirectory);
  testBuildAndRun(temporaryDirectory);
  testBuildIssuesPane(temporaryDirectory);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  for (NSString *key in [[defaults dictionaryRepresentation] allKeys]) {
    if ([key hasPrefix:@"YCodeLastSourceFile:"] &&
        [key rangeOfString:temporaryDirectory].location != NSNotFound)
      [defaults removeObjectForKey:key];
  }
  [defaults synchronize];
  [manager removeItemAtPath:temporaryDirectory error:NULL];
  NSLog(@"Ycode project loading checks: %lu failures", (unsigned long)failures);
  [pool drain];
  return failures ? 1 : 0;
}
