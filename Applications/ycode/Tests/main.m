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
#import <XCode/PBXBuildFile.h>
#import <XCode/PBXBuildPhase.h>
#import <XCode/PBXSourcesBuildPhase.h>
#import <XCode/PBXResourcesBuildPhase.h>
#import <XCode/PBXHeadersBuildPhase.h>
#import <XCode/PBXFrameworksBuildPhase.h>
#import <XCode/XCBuildConfiguration.h>
#import <XCode/XCConfigurationList.h>
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
- (void)updateThumbnailForItem:(YCodeProjectNavigatorItem *)item;
@end

@interface NSTabViewItem (CloseButtonTesting)
- (NSButton *)closeButton;
@end

@interface YCodeTabCloseTest : NSObject
+ (void)answerAlert:(NSTimer *)timer;
@end
@implementation YCodeTabCloseTest
+ (void)answerAlert:(NSTimer *)timer
{
  if (![NSApp modalWindow]) return;
  NSMutableArray *views = [NSMutableArray arrayWithObject:[[NSApp modalWindow] contentView]];
  while ([views count] > 0) {
    NSView *view = AUTORELEASE(RETAIN([views lastObject]));
    [views removeLastObject];
    if ([view isKindOfClass:[NSButton class]]
      && [(NSButton *)view tag] == [[timer userInfo] integerValue]) {
      [timer invalidate];
      [(NSButton *)view sendAction:[(NSButton *)view action] to:[(NSButton *)view target]];
      // Wake the modal event wait after the timer delivers the button action.
      [NSApp postEvent:[NSEvent otherEventWithType:NSApplicationDefined
        location:NSZeroPoint modifierFlags:0 timestamp:0
        windowNumber:[[NSApp modalWindow] windowNumber] context:nil
        subtype:0 data1:0 data2:0] atStart:NO];
      return;
    }
    [views addObjectsFromArray:[view subviews]];
  }
}
@end

static void answerCloseAlert(NSInteger response)
{
  NSTimer *timer = [NSTimer timerWithTimeInterval:0.1 target:[YCodeTabCloseTest class]
    selector:@selector(answerAlert:) userInfo:[NSNumber numberWithInteger:response] repeats:YES];
  [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSModalPanelRunLoopMode];
}

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

static void testSaveActiveFile(YCodeProject *project, NSString *directory)
{
  YCodeEditorController *editor = [project editorController];
  NSString *firstPath = [directory stringByAppendingPathComponent:@"Save First.m"];
  NSString *secondPath = [directory stringByAppendingPathComponent:@"Save Second.m"];
  NSString *original = @"// original\n";
  [original writeToFile:firstPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [original writeToFile:secondPath atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  testAssert([editor openFile:firstPath] && [editor openFile:secondPath], @"Open source files for Save regression");
  YCodeEditorDocument *first = [editor documentForFilePath:firstPath];
  YCodeEditorDocument *second = [editor documentForFilePath:secondPath];
  [first insertText:@"// first edit\n" atLocation:0];
  [second insertText:@"// second edit\n" atLocation:0];
  [editor setCurrentDocument:first];
  YCodeWindowController *window = [[project windowControllers] objectAtIndex:0];
  [[window window] makeKeyAndOrderFront:nil];
  testAssert([[NSDocumentController sharedDocumentController] currentDocument] == project,
    @"Save resolves the project belonging to the active window");
  NSString *projectFile = [[project projectPath] stringByAppendingPathComponent:@"project.pbxproj"];
  NSData *projectBefore = [NSData dataWithContentsOfFile:projectFile];
  [project updateChangeCount:NSChangeDone];
  NSMenuItem *save = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu] ?
    [[[[NSApp mainMenu] itemWithTitle:@"File"] submenu] itemWithTitle:@"Save"] : nil;
  testAssert(save != nil && [[save keyEquivalent] isEqual:@"s"] && [save action] == @selector(saveDocument:),
    @"File Save and its shortcut invoke the same action");
  [NSApp sendAction:[save action] to:[save target] from:save];
  NSString *written = [NSString stringWithContentsOfFile:firstPath encoding:NSUTF8StringEncoding error:NULL];
  testAssert([written isEqual:[first content]] && ![first isModified],
    @"File Save writes the active editor contents and clears its modified flag");
  testAssert([[NSString stringWithContentsOfFile:secondPath encoding:NSUTF8StringEncoding error:NULL] isEqual:original]
    && [second isModified], @"Saving one source tab leaves the other tab's edits unsaved");
  testAssert([projectBefore isEqual:[NSData dataWithContentsOfFile:projectFile]] && [project isDocumentEdited],
    @"Saving a source file does not save or clear pending project changes");
  [editor setCurrentDocument:second];
  [NSApp sendAction:[save action] to:[save target] from:save];
  testAssert([[NSString stringWithContentsOfFile:secondPath encoding:NSUTF8StringEncoding error:NULL]
    isEqual:[second content]] && ![second isModified], @"Save follows the selected source tab");
  // Keep cleanup independent of a failed Save assertion, without opening a modal prompt.
  [first setModified:NO];
  [second setModified:NO];
  [editor closeFile:firstPath];
  [editor closeFile:secondPath];
  [project updateChangeCount:NSChangeCleared];
}

static NSUInteger buildReferenceCount(YCodeProject *project, PBXFileReference *reference)
{
  NSUInteger count = 0;
  for (PBXTarget *target in [[project project] targets])
    for (PBXBuildPhase *phase in [target buildPhases])
      for (PBXBuildFile *file in [phase files])
        if ([file fileRef] == reference) count++;
  return count;
}

static void testProjectFileMembership(YCodeProject *project, NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *source = [directory stringByAppendingPathComponent:@"Added Source.cc"];
  NSString *nestedDirectory = [directory stringByAppendingPathComponent:@"Nested Folder"];
  NSString *nestedSource = [nestedDirectory stringByAppendingPathComponent:@"Added Source.cc"];
  [manager createDirectoryAtPath:nestedDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
  [@"int value;\n" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  [@"int nestedValue;\n" writeToFile:nestedSource atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  PBXGroup *mainGroup = [[project project] mainGroup];
  NSUInteger originalCount = [[mainGroup children] count];
  [project addFilesToProject:[NSArray arrayWithObjects:source, source, nil]];
  testAssert([project isDocumentEdited] && [[mainGroup children] count] == originalCount + 1,
    @"Adding a file marks the project modified and avoids duplicates in one operation");
  PBXFileReference *reference = [[[mainGroup children] lastObject] retain];
  testAssert([[reference path] isEqual:@"Added Source.cc"] && [[reference sourceTree] isEqual:@"SOURCE_ROOT"],
    @"Files inside the project use portable source-root-relative references");
  testAssert(buildReferenceCount(project, reference) > 0, @"Added C++ files enter the sources build phase");
  [project updateChangeCount:NSChangeCleared];
  [project addFilesToProject:[NSArray arrayWithObject:@"./Added Source.cc"]];
  testAssert(![project isDocumentEdited] && [[mainGroup children] count] == originalCount + 1,
    @"Adding the same file through a relative path is a clean no-op");
  testAssert([project addGroupToProject:@"Membership Group"] && [project isDocumentEdited],
    @"Adding a group also marks the project modified");
  PBXGroup *nested = [[mainGroup children] lastObject];
  [nested setPath:@"Nested Folder"];
  [nested setSourceTree:@"SOURCE_ROOT"];
  PBXFileReference *nestedReference = AUTORELEASE([[PBXFileReference alloc] initWithPath:@"Added Source.cc"]);
  [nested setChildren:[NSMutableArray arrayWithObject:nestedReference]];
  // The same reference may appear in several build phases; removal must clean all of them.
  PBXTarget *target = [[[project project] targets] objectAtIndex:0];
  for (PBXBuildPhase *phase in [target buildPhases]) {
    if (![phase files]) [phase setFiles:[NSMutableArray array]];
    PBXBuildFile *file = AUTORELEASE([[PBXBuildFile alloc] init]);
    [file setFileRef:nestedReference];
    [[phase files] addObject:file];
  }
  testAssert([project saveProjectToPath:[project projectPath]] && ![project isDocumentEdited],
    @"Successful project save clears the project modified state");
  YCodeProject *reopened = [YCodeProject new];
  testAssert([reopened readFromURL:[project fileURL] ofType:@"YCodeXcodeProjectType" error:NULL],
    @"Reopen the project after adding files");
  PBXFileReference *savedReference = [[[[reopened project] mainGroup] children] objectAtIndex:originalCount];
  testAssert([[savedReference path] isEqual:@"Added Source.cc"] && buildReferenceCount(reopened, savedReference) > 0,
    @"Added file and its build membership survive save and reload");
  [reopened close]; [reopened release];
  [project removeFilesFromProject:[NSArray arrayWithObject:@"Nested Folder/Added Source.cc"]];
  testAssert([project isDocumentEdited] && [[nested children] count] == 0 && buildReferenceCount(project, nestedReference) == 0,
    @"Removing a nested file updates its group and every build phase");
  testAssert([[mainGroup children] containsObject:reference] && [manager fileExistsAtPath:nestedSource],
    @"Removal preserves the source on disk and same-named files in other groups");
  NSString *badDestination = [directory stringByAppendingPathComponent:@"Not A Directory.xcodeproj"];
  [@"blocked" writeToFile:badDestination atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  testAssert(![project saveProjectToPath:badDestination] && [project isDocumentEdited],
    @"Failed project saves retain the modified state");
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  [navigator expandItem:[navigator itemForObject:mainGroup]];
  [navigator selectItem:[navigator itemForObject:reference]];
  [navigator deleteItem:nil];
  testAssert(![[mainGroup children] containsObject:reference] && [manager fileExistsAtPath:source],
    @"Navigator Remove File changes the project without deleting the disk file");
  NSMenuItem *saveProject = [[[[NSApp mainMenu] itemWithTitle:@"File"] submenu] itemWithTitle:@"Save Project"];
  testAssert(saveProject != nil, @"A separate Save Project action is available with an editor tab open");
  [NSApp sendAction:[saveProject action] to:[saveProject target] from:saveProject];
  testAssert(![project isDocumentEdited], @"Save Project persists membership changes while a source tab is open");
  reopened = [YCodeProject new];
  testAssert([reopened readFromURL:[project fileURL] ofType:@"YCodeXcodeProjectType" error:NULL], @"Reopen project after removal");
  NSDictionary *archive = [NSDictionary dictionaryWithContentsOfFile:[[project projectPath] stringByAppendingPathComponent:@"project.pbxproj"]];
  for (NSDictionary *object in [[archive objectForKey:@"objects"] allValues])
    testAssert(![[object objectForKey:@"path"] isEqual:@"Added Source.cc"],
      @"Removed file references are absent from the serialized project");
  [reopened close]; [reopened release];
  [project removeFilesFromProject:[NSArray arrayWithObject:source]];
  testAssert(![project isDocumentEdited], @"Removing a missing project reference is a clean no-op");
  [reference release];
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
  [[editor tabView] display];
  YCodeEditorDocument *selectedDocument = [editor currentDocument];
  NSString *backgroundPath = [[selectedDocument filePath] isEqual:first] ? second : first;
  NSTabViewItem *backgroundTab = [editor tabForDocument:[editor documentForFilePath:backgroundPath]];
  NSButton *closeButton = [backgroundTab closeButton];
  testAssert([closeButton superview] == [editor tabView] && ![closeButton isHidden],
    @"File tabs display a close button beside the label");
  [closeButton performClick:nil];
  testAssert([[editor openDocuments] count] == 1 && [editor currentDocument] == selectedDocument
    && [editor documentForFilePath:backgroundPath] == nil,
    @"Closing a background tab preserves the selected document");
  NSTabViewItem *selectedTab = [editor tabForDocument:selectedDocument];
  [selectedDocument setModified:YES];
  answerCloseAlert(NSAlertThirdButtonReturn);
  [[selectedTab closeButton] performClick:nil];
  testAssert([[editor openDocuments] count] == 1 && [selectedDocument isModified],
    @"Cancel keeps the modified tab open");
  answerCloseAlert(NSAlertSecondButtonReturn);
  [[selectedTab closeButton] performClick:nil];
  testAssert([[editor openDocuments] count] == 0 && [editor currentDocument] == nil
    && [[editor tabView] numberOfTabViewItems] == 0,
    @"Discard closes the last tab and clears the active editor");
  testAssert([editor openFile:first], @"Reopen source after closing tabs");
  [editor openFile:second];
  [editor openFile:first];
  [[editor currentDocument] setModified:YES];
  answerCloseAlert(NSAlertFirstButtonReturn);
  [[[editor tabForDocument:[editor currentDocument]] closeButton] performClick:nil];
  testAssert([editor documentForFilePath:first] == nil
    && [[[editor currentDocument] filePath] isEqual:second],
    @"Save closes the selected tab and activates a remaining file");
  [editor closeFile:second];
  [editor openFile:first];
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
  testAssert([[debugger executionFile] isEqual:probe->file] && [debugger executionLine] == 4,
    @"Breakpoint stop records the execution arrow's source location");
  [debugger toggleBreakpointEnabledAtFile:probe->file line:4];
  testAssert([debugger breakpointStateAtFile:probe->file line:4] == YCodeBreakpointInactive &&
    [probe->commands hasSuffix:@"-break-disable 3\n"], @"Disable keeps a grey source breakpoint and tells GDB");
  YCodeDebugger *disabledSession = [YCodeDebugger new];
  [disabledSession setDelegate:probe];
  [disabledSession setBreakpointStorageKey:storage];
  [disabledSession receiveData:[@"(gdb)\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->commands rangeOfString:@"-break-insert -f -d"].location != NSNotFound,
    @"Disabled breakpoints remain disabled when restored in a new session");
  [disabledSession release];
  [debugger toggleBreakpointEnabledAtFile:probe->file line:4];
  testAssert([debugger breakpointStateAtFile:probe->file line:4] == YCodeBreakpointEnabled &&
    [probe->commands hasSuffix:@"-break-enable 3\n"], @"Re-enable makes the breakpoint red and tells GDB");
  [debugger toggleBreakpointAtFile:probe->file line:4];
  testAssert([probe->commands hasSuffix:@"-break-delete 3\n"], @"Delete breakpoint using debugger-assigned number");
  [debugger toggleBreakpointAtFile:@"/tmp/blank.m" line:1];
  [debugger receiveData:[@"^done,bkpt={number=\"4\",fullname=\"/tmp/blank.m\",line=\"2\",original-location=\"/tmp/blank.m:1\"}\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([[[debugger breakpointLinesForFile:@"/tmp/blank.m"] objectForKey:@2] intValue] == YCodeBreakpointEnabled &&
    [[debugger breakpointLinesForFile:@"/tmp/blank.m"] objectForKey:@1] == nil,
    @"Draw relocated breakpoints at the executable line rather than the requested blank line");
  [debugger toggleBreakpointAtFile:@"/tmp/blank.m" line:1];
  testAssert([probe->commands hasSuffix:@"-break-delete 4\n"],
    @"Toggling the requested line removes a breakpoint relocated by GDB");
  [debugger receiveData:[@"*running,thread-id=\"all\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([debugger executionFile] == nil && [debugger executionLine] == 0,
    @"Resuming removes the old execution arrow");
  [debugger restart];
  testAssert([probe->commands hasSuffix:@"-exec-interrupt --all\n"], @"Restart interrupts a running inferior first");
  [debugger receiveData:[@"*stopped,reason=\"signal-received\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->commands hasSuffix:@"-exec-run\n"], @"Restart waits for the stopped event before running");
  [debugger receiveData:[@"9^error,msg=\"No symbol\\n\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([probe->output rangeOfString:@"Debugger error: No symbol"].location != NSNotFound,
    @"Display MI command failures in the console");
  NSDictionary *parsed = [YCodeDebugger parseRecord:@"24^done,stack=[frame={level=\"0\"},frame={level=\"1\"}]"];
  testAssert([[parsed objectForKey:@"stack"] count] == 2, @"Parse MI result lists as well as value lists");
  [debugger setSourceDirectory:@"/tmp/Source Folder"];
  [debugger receiveData:[@"=breakpoint-created,bkpt={number=\"7\",file=\"main.c\",line=\"3\",enabled=\"y\"}\n"
    @"=breakpoint-modified,bkpt={number=\"7\",file=\"main.c\",line=\"3\",enabled=\"n\"}\n"
    dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([debugger breakpointStateAtFile:@"/tmp/Source Folder/main.c" line:3] == YCodeBreakpointInactive,
    @"GDB console breakpoint changes update the correct absolute source path");
  [debugger receiveData:[@"=breakpoint-deleted,id=\"7\"\n" dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([debugger breakpointStateAtFile:@"/tmp/Source Folder/main.c" line:3] == YCodeBreakpointNone,
    @"GDB deletion removes its source marker");
  [debugger toggleBreakpointAtFile:@"/tmp/later.c" line:5];
  [debugger receiveData:[@"^done,bkpt={number=\"8\",addr=\"<PENDING>\",pending=\"/tmp/later.c:5\",original-location=\"/tmp/later.c:5\",enabled=\"y\"}\n"
    dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([debugger breakpointStateAtFile:@"/tmp/later.c" line:5] == YCodeBreakpointInactive,
    @"Unresolved breakpoints are grey until GDB resolves them");
  [debugger receiveData:[@"=breakpoint-modified,bkpt={number=\"8\",fullname=\"/tmp/later.c\",line=\"5\",addr=\"0x1234\",enabled=\"y\"}\n"
    dataUsingEncoding:NSUTF8StringEncoding]];
  testAssert([debugger breakpointStateAtFile:@"/tmp/later.c" line:5] == YCodeBreakpointEnabled,
    @"Resolved breakpoints become red");
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
  NSString *breakpointStorage = [@"YCodeDebuggerUITest:" stringByAppendingString:root];
  [[build debugger] setBreakpointStorageKey:breakpointStorage];
  for (NSUInteger session = 0; session < 2; session++) {
    [window debugProject:nil];
    waitForDebugger(build);
    testAssert([build isDebugging] && [[build debugger] isReady], @"Build and start a fresh debugger session");
    NSTabView *bottomTabs = [window valueForKey:@"_bottomTabView"];
    testAssert([[[bottomTabs selectedTabViewItem] identifier] isEqual:@"debugger"],
      @"Starting GDB selects its dedicated tab");
    NSTextView *debugOutput = [window valueForKey:@"_debuggerTextView"];
    testAssert([[debugOutput string] rangeOfString:@"Debugger ready"].location != NSNotFound &&
      [[console string] rangeOfString:@"Debugger ready"].location == NSNotFound,
      @"Debugger output goes to its own transcript instead of the program console");
    NSString *source = [root stringByAppendingPathComponent:@"gutter.c"];
    [@"// first\nint main(void) {\n  return 0;\n}\n" writeToFile:source atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[window editorController] openFile:source];
    YCodeEditorDocument *editorDocument = [[window editorController] currentDocument];
    YCEditorRulerView *ruler = (YCEditorRulerView *)[[editorDocument scrollView] verticalRulerView];
    testAssert([ruler debugGutterVisible] && [ruler ruleThickness] == 72,
      @"Active debugger adds a clickable gutter to a newly opened source file");
    NSTextView *sourceView = [editorDocument textView];
    NSLayoutManager *layout = [sourceView layoutManager];
    NSUInteger glyph = [layout glyphRangeForCharacterRange:NSMakeRange(9, 1) actualCharacterRange:NULL].location;
    NSRect fragment = [layout lineFragmentRectForGlyphAtIndex:glyph effectiveRange:NULL];
    NSPoint point = [ruler convertPoint:NSMakePoint(0, [sourceView textContainerOrigin].y + NSMidY(fragment)) fromView:sourceView];
    point.x = 10;
    testAssert([ruler sourceLineAtPoint:point] == 2, @"Gutter hit testing uses source line layout");
    NSPoint clickPoint = [ruler convertPoint:point toView:nil];
    NSEvent *click = [NSEvent mouseEventWithType:NSLeftMouseDown location:clickPoint modifierFlags:0
      timestamp:0 windowNumber:[[window window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
    [ruler mouseDown:click];
    testAssert([[build debugger] breakpointStateAtFile:source line:2] != YCodeBreakpointNone,
      @"Clicking the gutter creates a breakpoint in that file");
    NSString *response = [NSString stringWithFormat:@"^done,bkpt={number=\"9\",fullname=%@,line=\"2\",enabled=\"y\"}\n"
      @"*stopped,reason=\"breakpoint-hit\",frame={fullname=%@,line=\"2\"}\n",
      [YCodeDebugger quote:source], [YCodeDebugger quote:source]];
    [[build debugger] receiveData:[response dataUsingEncoding:NSUTF8StringEncoding]];
    testAssert([[build debugger] executionLine] == 2 &&
      [[[build debugger] executionFile] isEqual:source], @"Stopped source and breakpoint share the gutter line");
    click = [NSEvent mouseEventWithType:NSLeftMouseDown location:clickPoint modifierFlags:NSShiftKeyMask
      timestamp:0 windowNumber:[[window window] windowNumber] context:nil eventNumber:0 clickCount:1 pressure:1];
    [ruler mouseDown:click];
    testAssert([[build debugger] breakpointStateAtFile:source line:2] == YCodeBreakpointInactive,
      @"Shift-click disables the breakpoint without deleting it");
    [[build debugger] toggleBreakpointAtFile:source line:2];
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
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:breakpointStorage];
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
  testAssert([consolePane isKindOfClass:[NSScrollView class]],
    @"Console is a full-height transcript without a debugger command field");
  [tabs selectTabViewItemWithIdentifier:@"debugger"];
  NSView *debuggerPane = [[tabs selectedTabViewItem] view];
  NSTextField *commandField = [controller valueForKey:@"_debuggerCommandField"];
  NSView *debuggerScroll = [[debuggerPane subviews] objectAtIndex:1];
  testAssert([commandField action] == @selector(debugConsoleCommand:) &&
    !NSIntersectsRect([commandField frame], [debuggerScroll frame]) &&
    NSContainsRect([debuggerPane bounds], [commandField frame]) &&
    NSContainsRect([debuggerPane bounds], [debuggerScroll frame]),
    @"Debugger command field and transcript remain separate and visible after resizing");
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

static void testProjectCenterImport(NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *package = [directory stringByAppendingPathComponent:@"Imported Project.pcproj"];
  [manager createDirectoryAtPath:package withIntermediateDirectories:YES attributes:nil error:NULL];
  NSString *projectFile = [package stringByAppendingPathComponent:@"PC.project"];
  NSString *sourcePath = [directory stringByAppendingPathComponent:@"Imported Source.m"];
  [@"int main(void) { return 0; }\n" writeToFile:sourcePath atomically:YES
    encoding:NSUTF8StringEncoding error:NULL];
  NSMutableDictionary *contents = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    @"Imported Tool", @"PROJECT_NAME", @"Tool", @"PROJECT_TYPE",
    [NSArray arrayWithObject:@"Imported Source.m"], @"CLASS_FILES",
    [NSArray arrayWithObject:@"Imported Source.m"], @"OTHER_SOURCES",
    [NSArray arrayWithObject:@"Public.h"], @"HEADER_FILES",
    [NSArray arrayWithObject:@"Public.h"], @"PUBLIC_HEADERS",
    [NSArray arrayWithObject:@"Images/Icon.png"], @"IMAGES",
    [NSArray arrayWithObject:@"English.lproj/Main.gorm"], @"INTERFACES",
    [NSArray arrayWithObject:@"English.lproj/Localizable.strings"], @"LOCALIZED_RESOURCES",
    [NSArray arrayWithObject:@"data.txt"], @"OTHER_RESOURCES",
    [NSArray arrayWithObject:@"ImportedInfo.plist"], @"SUPPORTING_FILES",
    [NSArray arrayWithObject:@"README"], @"DOCU_FILES",
    [NSArray arrayWithObject:@"Foundation"], @"FRAMEWORKS",
    [NSArray arrayWithObject:@"gnustep-base"], @"LIBRARIES",
    [NSArray arrayWithObject:@"Include Files"], @"SEARCH_HEADER_DIRS",
    [NSArray arrayWithObject:@"Library Files"], @"SEARCH_LIB_DIRS",
    @"-DIMPORT_TEST=1", @"COMPILEROPTIONS", @"-Wl,--as-needed", @"LINKEROPTIONS", nil];
  [contents writeToFile:projectFile atomically:YES];
  NSData *original = [NSData dataWithContentsOfFile:projectFile];
  YCodeProject *document = [[YCodeProject alloc] init];
  NSError *error = nil;
  testAssert([document readFromURL:[NSURL fileURLWithPath:package]
    ofType:@"YCodeProjectCenterProjectType" error:&error], @"Import a ProjectCenter package");
  PBXProject *project = [document project];
  PBXNativeTarget *target = [[project targets] lastObject];
  testAssert([[target productType] isEqual:@"com.apple.product-type.tool"]
    && [[[target productReference] path] isEqual:@"Imported Tool"],
    @"Import preserves the ProjectCenter product type and name");
  PBXFileReference *source = nil;
  NSUInteger sources = 0, headers = 0, resources = 0, frameworks = 0;
  for (PBXBuildPhase *phase in [target buildPhases]) {
    if ([phase isKindOfClass:[PBXSourcesBuildPhase class]]) {
      sources = [[phase files] count];
      source = [[[phase files] lastObject] fileRef];
    } else if ([phase isKindOfClass:[PBXHeadersBuildPhase class]]) {
      headers = [[phase files] count];
      testAssert([[[[[phase files] lastObject] settings] objectForKey:@"ATTRIBUTES"]
        containsObject:@"Public"], @"Imported public headers retain their visibility");
    } else if ([phase isKindOfClass:[PBXResourcesBuildPhase class]]) resources = [[phase files] count];
    else if ([phase isKindOfClass:[PBXFrameworksBuildPhase class]]) frameworks = [[phase files] count];
  }
  testAssert(sources == 1 && headers == 1 && resources == 4 && frameworks == 1,
    @"Import separates build phases and removes duplicate entries");
  [document makeWindowControllers];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  YCodeProjectNavigatorItem *item = [navigator itemForObject:source];
  testAssert(item != nil && [[navigator resolvedFilePathForNavigatorItem:item] isEqual:sourcePath],
    @"Imported navigator references resolve outside the pcproj package, including spaces");
  testAssert([[navigator outlineView] rowForItem:item] >= 0,
    @"Imported source files are visible immediately without expanding hidden groups");
  testAssert([[document editorController] openFile:[navigator resolvedFilePathForNavigatorItem:item]],
    @"Imported source opens in the editor");
  NSDictionary *settings = [[[target buildConfigurationList] defaultConfiguration] buildSettings];
  testAssert([[settings objectForKey:@"HEADER_SEARCH_PATHS"] isEqual:[contents objectForKey:@"SEARCH_HEADER_DIRS"]]
    && [[settings objectForKey:@"OTHER_CFLAGS"] isEqual:@"-DIMPORT_TEST=1"]
    && [[settings objectForKey:@"OTHER_LDFLAGS"] isEqual:@"-Wl,--as-needed -lgnustep-base"]
    && [[settings objectForKey:@"INFOPLIST_FILE"] isEqual:@"ImportedInfo.plist"],
    @"Import retains search paths, compiler and linker flags, libraries, and Info.plist");
  testAssert([document saveProjectToPath:package], @"Save imported project as Xcode format");
  NSString *converted = [[package stringByDeletingPathExtension] stringByAppendingPathExtension:@"xcodeproj"];
  testAssert([[document projectPath] isEqual:converted]
    && [[[document fileURL] path] isEqual:converted]
    && [[NSData dataWithContentsOfFile:projectFile] isEqual:original]
    && [[manager contentsOfDirectoryAtPath:package error:NULL] count] == 1,
    @"Conversion saves beside the original package without changing PC.project");
  YCodeProject *reopened = [[YCodeProject alloc] init];
  testAssert([reopened readFromURL:[NSURL fileURLWithPath:converted]
    ofType:@"YCodeXcodeProjectType" error:NULL]
    && [[reopened projectDirectoryPath] isEqual:directory], @"Reopen the saved import with the same source root");
  PBXNativeTarget *reopenedTarget = [[[reopened project] targets] lastObject];
  testAssert([[reopenedTarget productType] isEqual:[target productType]]
    && [[reopenedTarget buildPhases] count] == 4, @"Imported target survives serialization");
  [reopened close]; [reopened release];
  YCodeProject *relocated = [[YCodeProject alloc] init];
  [relocated readFromURL:[NSURL fileURLWithPath:package] ofType:@"YCodeProjectCenterProjectType" error:NULL];
  NSString *relocatedPath = [directory stringByAppendingPathComponent:@"Elsewhere/Imported.xcodeproj"];
  testAssert([relocated saveProjectToPath:relocatedPath], @"Save an import in another directory");
  [relocated close]; [relocated release];
  relocated = [[YCodeProject alloc] init];
  testAssert([relocated readFromURL:[NSURL fileURLWithPath:relocatedPath]
    ofType:@"YCodeXcodeProjectType" error:NULL], @"Reopen a relocated import");
  [relocated makeWindowControllers];
  PBXNativeTarget *relocatedTarget = [[[relocated project] targets] lastObject];
  PBXFileReference *relocatedSource = [[[[[relocatedTarget buildPhases] objectAtIndex:0] files] lastObject] fileRef];
  YCodeProjectNavigatorController *relocatedNavigator = [relocated navigatorController];
  testAssert([[relocatedNavigator resolvedFilePathForNavigatorItem:
    [relocatedNavigator itemForObject:relocatedSource]] isEqual:sourcePath],
    @"Relocated import still points to its original source files");
  testAssert([[[[[relocatedTarget buildConfigurationList] defaultConfiguration] buildSettings]
    objectForKey:@"HEADER_SEARCH_PATHS"] isEqual:[NSArray arrayWithObject:
        [directory stringByAppendingPathComponent:@"Include Files"]]],
    @"Relocated import retains its header search directory");
  [relocated close]; [relocated release];
  NSArray *types = [NSArray arrayWithObjects:@"Application", @"Framework", @"Library", @"Bundle", nil];
  for (NSString *type in types) {
    [contents setObject:type forKey:@"PROJECT_TYPE"];
    [contents writeToFile:projectFile atomically:YES];
    YCodeProject *variant = [[YCodeProject alloc] init];
    testAssert([variant readFromURL:[NSURL fileURLWithPath:package]
      ofType:@"YCodeProjectCenterProjectType" error:NULL],
      [NSString stringWithFormat:@"Import ProjectCenter %@ target", type]);
    [variant close]; [variant release];
  }
  for (id invalid in [NSArray arrayWithObjects:[NSDictionary dictionary],
      [NSDictionary dictionaryWithObjectsAndKeys:@"Bad", @"PROJECT_NAME", @"Tool", @"PROJECT_TYPE",
        [NSNumber numberWithInt:42], @"CLASS_FILES", nil], nil]) {
    [invalid writeToFile:projectFile atomically:YES];
    error = nil;
    testAssert(![document readFromURL:[NSURL fileURLWithPath:package]
      ofType:@"YCodeProjectCenterProjectType" error:&error] && error != nil
      && [document project] == project && [[[document fileURL] path] isEqual:converted],
      @"Malformed imports fail without replacing the loaded project");
  }
  [document close]; [document release];
}

static void testProjectCenterExport(NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root = [directory stringByAppendingPathComponent:@"ProjectCenter Export"];
  [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"Resources"]
    withIntermediateDirectories:YES attributes:nil error:NULL];
  [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"English.lproj/Main.gorm"]
    withIntermediateDirectories:YES attributes:nil error:NULL];
  for (NSString *name in [NSArray arrayWithObjects:@"Main.m", @"Public.h", @"Resources/Icon.png", @"Notes.txt", nil])
    [@"fixture" writeToFile:[root stringByAppendingPathComponent:name] atomically:YES
      encoding:NSUTF8StringEncoding error:NULL];
  NSString *legacyPath = [root stringByAppendingPathComponent:@"Legacy.pcproj"];
  NSDictionary *metadata = [NSDictionary dictionaryWithObjectsAndKeys:
    @"Legacy", @"PROJECT_NAME", @"PCAppProject", @"PROJECT_TYPE",
    @"Main.m", @"CLASS_FILES", @"Public.h", @"HEADER_FILES", @"Public.h", @"PUBLIC_HEADERS",
    @"Icon.png", @"IMAGES", @"Main.gorm", @"INTERFACES", @"Main.gorm", @"LOCALIZED_RESOURCES",
    @"Notes.txt", @"OTHER_FILES", @"English", @"LANGUAGE",
    @"-lgnustep-base -lgnustep-gui", @"LINKEROPTIONS",
    @"Preserve this metadata", @"PROJECT_COPYRIGHT", nil];
  [metadata writeToFile:legacyPath atomically:YES];
  YCodeProject *document = [[YCodeProject alloc] init];
  testAssert([document readFromURL:[NSURL fileURLWithPath:legacyPath]
    ofType:@"YCodeProjectCenterProjectType" error:NULL],
    @"Read a legacy flat pcproj with singleton file lists and legacy product type");
  [document makeWindowControllers];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  NSMutableArray *expectedPaths = [NSMutableArray array];
  for (PBXGroup *group in [[[document project] mainGroup] children]) {
    for (PBXFileReference *reference in [group children]) {
      if ([[reference sourceTree] isEqual:@"BUILT_PRODUCTS_DIR"]) continue;
      YCodeProjectNavigatorItem *item = [navigator itemForObject:reference];
      NSString *path = [navigator resolvedFilePathForNavigatorItem:item];
      testAssert([[navigator outlineView] rowForItem:item] >= 0,
        @"Imported sources, headers, resources, and supporting files are visible");
      testAssert([manager fileExistsAtPath:path], @"ProjectCenter category paths locate the actual files");
      if (path) [expectedPaths addObject:path];
    }
  }
  testAssert([expectedPaths count] == 5
    && [expectedPaths containsObject:[root stringByAppendingPathComponent:@"Resources/Icon.png"]]
    && [expectedPaths containsObject:[root stringByAppendingPathComponent:@"English.lproj/Main.gorm"]],
    @"Import resolves Resources and localized interface files without duplicates");
  [document updateChangeCount:NSChangeDone];
  NSString *exportPath = [root stringByAppendingPathComponent:@"Exports/Exported.pcproj"];
  NSError *error = nil;
  testAssert([document exportProjectCenterToPath:exportPath error:&error] && error == nil,
    @"Export a ProjectCenter package to another directory");
  testAssert([[document projectPath] isEqual:legacyPath] && [document isDocumentEdited],
    @"Export leaves the current project identity and unsaved state intact");
  NSDictionary *exported = [NSDictionary dictionaryWithContentsOfFile:
    [exportPath stringByAppendingPathComponent:@"PC.project"]];
  testAssert([[exported objectForKey:@"PROJECT_COPYRIGHT"] isEqual:@"Preserve this metadata"]
    && [[exported objectForKey:@"CLASS_FILES"] count] == 1
    && [[exported objectForKey:@"PUBLIC_HEADERS"] count] == 1
    && [[exported objectForKey:@"LIBRARIES"] count] == 2,
    @"Export retains file membership, public headers, libraries, and ProjectCenter metadata");
  YCodeProject *reopened = [[YCodeProject alloc] init];
  testAssert([reopened readFromURL:[NSURL fileURLWithPath:exportPath]
    ofType:@"YCodeProjectCenterProjectType" error:NULL], @"Reimport the exported ProjectCenter package");
  [reopened makeWindowControllers];
  NSMutableArray *actualPaths = [NSMutableArray array];
  for (PBXGroup *group in [[[reopened project] mainGroup] children]) {
    for (PBXFileReference *reference in [group children]) {
      NSString *path = [[reopened navigatorController] resolvedFilePathForNavigatorItem:
        [[reopened navigatorController] itemForObject:reference]];
      if (path) [actualPaths addObject:path];
    }
  }
  testAssert([[actualPaths sortedArrayUsingSelector:@selector(compare:)]
    isEqual:[expectedPaths sortedArrayUsingSelector:@selector(compare:)]],
    @"Export and reimport preserve every original file location");
  [reopened close]; [reopened release];
  NSString *blocked = [root stringByAppendingPathComponent:@"Notes.txt/Blocked.pcproj"];
  error = nil;
  testAssert(![document exportProjectCenterToPath:blocked error:&error] && error != nil,
    @"Export reports an unwritable destination");
  NSMenu *fileMenu = [[[NSApp mainMenu] itemWithTitle:@"File"] submenu];
  testAssert([[fileMenu itemWithTitle:@"Export ProjectCenter Project..."] action]
    == @selector(exportProjectCenter:), @"File menu exposes ProjectCenter export");
  [document updateChangeCount:NSChangeCleared];
  [document close]; [document release];
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
  testAssert([inspectorTabs numberOfTabViewItems] == 2,
    @"Repeated setup keeps File and Image inspectors without duplicates");
  YCInspectorView *extra = [[YCInspectorView alloc] initWithFrame:NSZeroRect];
  [windowController registerInspectorView:extra];
  [windowController registerInspectorView:extra];
  testAssert([inspectorTabs numberOfTabViewItems] == 3, @"Inspectors register uniquely");
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
  NSString *imagePath = [temporaryDirectory stringByAppendingPathComponent:@"Preview.PNG"];
  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
    initWithBitmapDataPlanes:NULL pixelsWide:32 pixelsHigh:24 bitsPerSample:8
    samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
    bytesPerRow:0 bitsPerPixel:0];
  memset([bitmap bitmapData], 128, [bitmap bytesPerRow] * [bitmap pixelsHigh]);
  NSData *imageData = [bitmap representationUsingType:NSPNGFileType
    properties:[NSDictionary dictionary]];
  [imageData writeToFile:imagePath atomically:YES];
  [bitmap release];
  testAssert([editor openFile:imagePath], @"Open image through the ordinary file selection path");
  YCodeEditorDocument *imageDocument = [editor currentDocument];
  testAssert([imageDocument isImageDocument] && [imageDocument textView] == nil
    && [[[imageDocument scrollView] documentView] isKindOfClass:[NSImageView class]]
    && ![[imageDocument scrollView] rulersVisible], @"Image editor displays a preview without text or rulers");
  NSClipView *imageClip = [[imageDocument scrollView] contentView];
  NSRect imageFrame = [[[imageDocument scrollView] documentView] frame];
  testAssert(fabs(NSMidX([imageClip bounds]) - NSMidX(imageFrame)) < 1
    && fabs(NSMidY([imageClip bounds]) - NSMidY(imageFrame)) < 1,
    @"Small image is centered in both axes");
  NSSize originalClipSize = [imageClip frame].size;
  [imageClip setFrameSize:NSMakeSize(180, 140)];
  testAssert(fabs(NSMidX([imageClip bounds]) - NSMidX(imageFrame)) < 1
    && fabs(NSMidY([imageClip bounds]) - NSMidY(imageFrame)) < 1,
    @"Image stays centered when the viewport resizes");
  [[imageClip documentView] setFrameSize:NSMakeSize(10000, 10000)];
  [imageClip scrollToPoint:NSMakePoint(100, 100)];
  testAssert(NSMinX([imageClip bounds]) == 100 && NSMinY([imageClip bounds]) == 100,
    @"Images larger than the viewport remain scrollable");
  [[imageClip documentView] setFrameSize:imageFrame.size];
  [imageClip setFrameSize:originalClipSize];
  PBXFileReference *previewFile = [[PBXFileReference alloc] init];
  [previewFile setPath:imagePath];
  YCodeProjectNavigatorItem *previewItem = [[YCodeProjectNavigatorItem alloc]
    initWithRepresentedObject:previewFile type:YCodeNavigatorItemTypeFile];
  NSImage *fallbackIcon = [[previewItem icon] retain];
  [navigator updateThumbnailForItem:previewItem];
  testAssert([previewItem icon] != fallbackIcon
    && NSEqualSizes([[previewItem icon] size], NSMakeSize(16, 12)),
    @"Readable image gets a miniature navigator thumbnail");
  NSBitmapImageRep *thumbnailPixels = [NSBitmapImageRep imageRepWithData:
    [[previewItem icon] TIFFRepresentation]];
  testAssert([[thumbnailPixels colorAtX:8 y:8] alphaComponent] > 0,
    @"Thumbnail retains decoded image pixels");
  navigatorCell = [[[navigator outlineView] outlineTableColumn] dataCell];
  [navigatorCell setImage:[previewItem icon]];
  NSRect thumbnailRect = [navigatorCell imageRectForBounds:NSMakeRect(0, 0, 100, 20)];
  testAssert(NSEqualSizes(thumbnailRect.size, NSMakeSize(16, 12))
    && NSMidY(thumbnailRect) == 10,
    @"Navigator centers the thumbnail without stretching its proportions");
  [fallbackIcon release];
  [previewItem release];
  [previewFile release];
  testAssert([[[inspectorTabs selectedTabViewItem] identifier] isEqual:@"image"],
    @"Selecting an image shows its inspector");
  NSTextView *imageDetails = [[[inspectorTabs selectedTabViewItem] view] valueForKey:@"_details"];
  testAssert([[imageDetails string] rangeOfString:@"32 × 24 pixels"].location != NSNotFound
    && [[imageDetails string] rangeOfString:@"Transparency\nYes"].location != NSNotFound,
    @"Image inspector reports decoded dimensions and transparency");
  [imageDocument setContent:@"Do not overwrite image bytes"];
  [imageDocument insertText:@"text" atLocation:0];
  testAssert(![imageDocument isModified] && [editor saveCurrentFile]
    && [[NSData dataWithContentsOfFile:imagePath] isEqual:imageData],
    @"Text editing and saving cannot corrupt an image");
  NSUInteger openCount = [[editor openDocuments] count];
  testAssert([editor openFile:imagePath] && [[editor openDocuments] count] == openCount,
    @"Repeated image selection reuses its tab");
  testAssert([imageDocument reloadFromFile], @"Reload image preview");
  [editor openFile:inspectedPath];
  testAssert(![[editor currentDocument] isImageDocument]
    && [[editor currentDocument] textView] != nil
    && [[[inspectorTabs selectedTabViewItem] identifier] isEqual:@"file"]
    && [[imageDetails string] isEqual:@"No image selected."],
    @"Switching back to source restores text editing and clears image details");
  NSString *invalidImage = [temporaryDirectory stringByAppendingPathComponent:@"Broken.png"];
  [@"not an image" writeToFile:invalidImage atomically:YES encoding:NSUTF8StringEncoding error:NULL];
  PBXFileReference *brokenFile = [[PBXFileReference alloc] init];
  [brokenFile setPath:invalidImage];
  YCodeProjectNavigatorItem *brokenItem = [[YCodeProjectNavigatorItem alloc]
    initWithRepresentedObject:brokenFile type:YCodeNavigatorItemTypeFile];
  NSImage *brokenIcon = [brokenItem icon];
  [navigator updateThumbnailForItem:brokenItem];
  testAssert([brokenItem icon] == brokenIcon,
    @"Unreadable image retains the normal navigator file icon");
  [brokenItem release];
  [brokenFile release];
  testAssert(![editor openFile:invalidImage] && [[editor openDocuments] count] == openCount,
    @"Invalid images do not open as editable text");
  for (YCodeEditorDocument *openDocument in [NSArray arrayWithArray:[editor openDocuments]])
    [[[editor tabForDocument:openDocument] closeButton] performClick:nil];
  testAssert([[editor openDocuments] count] == 0,
    @"Close buttons remove both source and image tabs");
  testAssert([[details string] isEqual:@"No source file selected."],
    @"Closing the final editor clears File inspector");

  testSaveActiveFile(document, temporaryDirectory);
  testProjectFileMembership(document, temporaryDirectory);

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
  testProjectCenterImport(temporaryDirectory);
  testProjectCenterExport(temporaryDirectory);
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
