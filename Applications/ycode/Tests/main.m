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
#ifdef GNUSTEP
#import <GNUstepGUI/GSGormLoading.h>
#import <GNUstepGUI/GSNibLoading.h>
#endif
#import <XCode/PBXContainer.h>
#import <XCode/PBXProject.h>
#import <XCode/PBXGroup.h>
#import <XCode/PBXNativeTarget.h>
#import <XCode/PBXTargetDependency.h>
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
#import "YCodeEditorRegistry.h"
#import "YCodeSyntaxHighlighter.h"
#import "YCEditorView.h"
#import "YCInspectorView.h"
#import "YCodeTextView.h"
#import "YCodeLanguage.h"
#import "YCodeDebuggerVariables.h"
#import "YCodeDebuggerRegistry.h"
#import "../DebuggerBundles/GDB/YCodeGDBDebugger.h"
#import "YCodeVariablesView.h"
#import "AppController.h"
#import "YCodePreferences.h"
#import "YCSoundInspectorView.h"
#import "YCodeTerminalView.h"
#include <math.h>
#ifndef _WIN32
#include <signal.h>
#include <errno.h>
#endif

@interface YCodeTerminalView (Testing)
- (BOOL) cellAtRow: (NSInteger)row
           column: (int)column
             cell: (YCodeTerminalGlyph *)cell;
- (void) queueBytes: (const char *)bytes length: (size_t)length;
- (NSPasteboard *) pasteboard;
- (void) advanceBlink;
@end

@interface YCodeTerminalMenuTestController : AppController
{
@public
  YCodeWindowController *terminalWindow;
}

@end
@implementation YCodeTerminalMenuTestController
- (YCodeWindowController *) currentProjectWindowController
{
  return terminalWindow;
}

@end

@interface YCodeTerminalTestView : YCodeTerminalView
{
  NSMutableData *_captured;
}

- (NSData *) takeOutput;
@end
@implementation YCodeTerminalTestView
- (NSPasteboard *) pasteboard
{
  return [NSPasteboard pasteboardWithName: @"YcodeTerminalRegression"];
}

- (void) queueBytes: (const char *)bytes length: (size_t)length
{
  if (!_captured)
    _captured = [NSMutableData new];
  [_captured appendBytes: bytes length: length];
  [super queueBytes: bytes length: length];
}

- (NSData *) takeOutput
{
  NSData *result = [NSData dataWithData: _captured ? _captured : [NSData data]];
  [_captured setLength: 0];
  return result;
}

- (void) dealloc
{
  [_captured release];
  [super dealloc];
}

@end

@interface YCodeProjectNavigatorController (Testing)
- (NSString *) resolvedPathForNavigatorItem: (YCodeProjectNavigatorItem *)item;
- (NSString *) resolvedFilePathForNavigatorItem:
    (YCodeProjectNavigatorItem *)item;
- (void) updateThumbnailForItem: (YCodeProjectNavigatorItem *)item;
@end

@interface YCodeThumbnailTestNavigator : YCodeProjectNavigatorController
{
  NSUInteger _thumbnailRequests;
}

- (NSUInteger) thumbnailRequests;
@end

@implementation YCodeThumbnailTestNavigator
- (void) updateThumbnailForItem: (YCodeProjectNavigatorItem *)item
{
  _thumbnailRequests++;
  [super updateThumbnailForItem: item];
}

- (NSUInteger) thumbnailRequests
{
  return _thumbnailRequests;
}

@end

@interface YCodeProjectNavigatorItem (SoundIconTesting)
- (NSImage *) iconForFileExtension: (NSString *)extension;
@end

@interface NSTabViewItem (CloseButtonTesting)
- (NSButton *) closeButton;
@end

@interface YCodeTabCloseTest : NSObject
+ (void) answerAlert: (NSTimer *)timer;
@end
@implementation YCodeTabCloseTest
+ (void) wakeModal: (NSTimer *)timer
{
}

+ (void) answerAlert: (NSTimer *)timer
{
  if (![NSApp modalWindow])
    return;
  NSMutableArray *views =
      [NSMutableArray arrayWithObject: [[NSApp modalWindow] contentView]];
  while ([views count] > 0)
    {
      NSView *view = AUTORELEASE (RETAIN ([views lastObject]));
      [views removeLastObject];
      if ([view isKindOfClass: [NSButton class]] &&
          [(NSButton *)view tag] == [[timer userInfo] integerValue])
        {
          [timer invalidate];
          // Keep the modal run loop's poll bounded after this timer is invalidated.
          [[NSRunLoop currentRunLoop]
              addTimer: [NSTimer timerWithTimeInterval: 0.01
                                               target: self
                                             selector: @selector (wakeModal:)
                                             userInfo: nil
                                              repeats: NO]
               forMode: NSModalPanelRunLoopMode];
          [(NSButton *)view sendAction: [(NSButton *)view action]
                                    to: [(NSButton *)view target]];
          // Wake the modal event wait after the timer delivers the button action.
          [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                              location: NSZeroPoint
                                         modifierFlags: 0
                                             timestamp: 0
                                          windowNumber: [[NSApp modalWindow]
                                                           windowNumber]
                                               context: nil
                                               subtype: 0
                                                 data1: 0
                                                 data2: 0]
                   atStart: NO];
          return;
        }
      [views addObjectsFromArray: [view subviews]];
    }
}

@end

static void
answerCloseAlert (NSInteger response)
{
  NSTimer *timer =
      [NSTimer timerWithTimeInterval: 0.1
                              target: [YCodeTabCloseTest class]
                            selector: @selector (answerAlert:)
                            userInfo: [NSNumber numberWithInteger: response]
                             repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
}

static NSUInteger failures = 0;

static void
testAssert (BOOL condition, NSString *message)
{
  if (!condition)
    {
      NSLog (@"FAIL: %@", message);
      failures++;
    }
}

static BOOL
colorMatches (NSColor *color, CGFloat red, CGFloat green, CGFloat blue)
{
  NSColor *rgb = [color colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  return rgb && fabs ([rgb redComponent] - red) < 0.001
         && fabs ([rgb greenComponent] - green) < 0.001
         && fabs ([rgb blueComponent] - blue) < 0.001;
}

static void
testApplicationStartup (void)
{
  AppController *delegate = [[AppController alloc] init];
  [NSApp setDelegate: delegate];
  [delegate buildMainMenu];
  [NSApp finishLaunching];
  [delegate applicationDidFinishLaunching: nil];
  testAssert (
      [[[NSDocumentController sharedDocumentController] documents] count] == 0,
      @"Launching does not open an untitled project");
  testAssert (![delegate applicationShouldOpenUntitledFile: NSApp],
              @"Suppress automatic untitled documents");
#ifdef GNUSTEP
  NSMenu *menu = [NSApp mainMenu];
  testAssert ([[[menu itemAtIndex: 0] title] isEqualToString: @"Info"],
              @"GNUstep main menu starts with Info after launch");
  testAssert (
      [[[menu itemWithTitle: @"Info"] submenu] itemWithTitle: @"Preferences..."]
          != nil,
      @"Preferences belong to Info");
  testAssert ([[[menu itemWithTitle: @"Info"] submenu] itemWithTitle: @"Help"]
                  != nil,
              @"Help belongs to Info");
  testAssert ([[menu itemWithTitle: @"Services"] submenu] ==
                  [NSApp servicesMenu],
              @"Services submenu is registered with the application");
  testAssert ([[menu itemWithTitle: @"Windows"] submenu] == [NSApp windowsMenu]
                  && [menu itemWithTitle: @"Project"] != nil,
              @"GNUstep Project and Windows menus are available");
  testAssert ([[menu itemAtIndex: [menu numberOfItems] - 1] action] ==
                      @selector (terminate:)
                  && [[menu itemAtIndex: [menu numberOfItems] - 2] action] ==
                         @selector (hide:),
              @"Hide and Quit are at the end of the main menu");
#endif
  [NSApp setDelegate: nil];
  [delegate autorelease];
}

static void
terminalFeed (YCodeTerminalView *view, NSString *text)
{
  [view consumeData: [text dataUsingEncoding: NSUTF8StringEncoding]];
}

static BOOL
terminalWait (YCodeTerminalView *view, NSString *text)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 8];
  while ([deadline timeIntervalSinceNow] > 0)
    {
      if ([[view screenText] rangeOfString: text].location != NSNotFound)
        return YES;
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
    }
  return NO;
}

// Exercise cursor painting without starting a shell or a polling timer.
@interface YCodeCursorTestView : YCodeTerminalView
{
@public
  NSUInteger fullInvalidations, partialInvalidations;
}

@end
@implementation YCodeCursorTestView
- (BOOL) isRunning
{
  return YES;
}

- (void) setNeedsDisplay: (BOOL)flag
{
  if (flag)
    fullInvalidations++;
  [super setNeedsDisplay: flag];
}

- (void) setNeedsDisplayInRect: (NSRect)rect
{
  partialInvalidations++;
  [super setNeedsDisplayInRect: rect];
}

@end

static BOOL
terminalCursorPixelVisible (YCodeTerminalView *view)
{
  [view setNeedsDisplay: YES];
  [[view window] display];
  NSBitmapImageRep *bitmap =
      [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
  [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
  return colorMatches ([bitmap colorAtX: 2 y: 2], 1, 0, 0);
}

static NSData *
terminalRenderedPixels (YCodeTerminalView *view)
{
  [view lockFocus];
  NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc]
      initWithFocusedViewRect: [view bounds]] autorelease];
  [view unlockFocus];
  return [bitmap representationUsingType: NSPNGFileType
                              properties: [NSDictionary dictionary]];
}

static void
testTerminalRedrawing (void)
{
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps: YES];
  [YCodePreferences setTerminalCursorShape: 1];
  testAssert ([YCodePreferences terminalCursorBlink],
              @"Cursor blinking is enabled by default");
  NSWindow *windows[2];
  YCodeCursorTestView *views[2];
  int i;
  for (i = 0; i < 2; i++)
    {
      windows[i] = [[NSWindow alloc]
          initWithContentRect: NSMakeRect (40 + i * 40, 40, 320, 180)
                    styleMask: NSTitledWindowMask
                      backing: NSBackingStoreBuffered
                        defer: NO];
      [windows[i] setReleasedWhenClosed: NO];
      views[i] = [[YCodeCursorTestView alloc]
          initWithFrame: NSMakeRect (0, 0, 320, 180)];
      [windows[i] setContentView: views[i]];
      [windows[i] makeKeyAndOrderFront: nil];
      [windows[i] makeFirstResponder: views[i]];
    }
  views[0]->fullInvalidations = views[0]->partialInvalidations = 0;
  views[1]->fullInvalidations = views[1]->partialInvalidations = 0;
  [views[0] advanceBlink];
  [views[1] advanceBlink];
  testAssert (views[0]->fullInvalidations == 0
                  && views[0]->partialInvalidations == 0,
              @"Inactive cursor blink causes no repaint");
  testAssert (views[1]->fullInvalidations == 0
                  && views[1]->partialInvalidations > 0,
              @"Active cursor blink repaints only its cells");
  views[1]->fullInvalidations = views[1]->partialInvalidations = 0;
  terminalFeed (views[1], @"x\b \b");
  testAssert (views[1]->fullInvalidations == 0
                  && views[1]->partialInvalidations > 0,
              @"Text and cursor updates request partial redraws");
  views[1]->fullInvalidations = views[1]->partialInvalidations = 0;
  NSEvent *typing = [NSEvent keyEventWithType: NSKeyDown
                                     location: NSZeroPoint
                                modifierFlags: 0
                                    timestamp: 0
                                 windowNumber: 0
                                      context: nil
                                   characters: @"a"
                  charactersIgnoringModifiers: @"a"
                                    isARepeat: NO
                                      keyCode: 0];
  [views[1] keyDown: typing];
  testAssert (
      views[1]->fullInvalidations == 0,
      @"Typing at the live prompt does not invalidate the whole terminal");
  views[1]->fullInvalidations = views[1]->partialInvalidations = 0;
  terminalFeed (views[1], @"\033[?1000h\033[?1000l\033]0;title\007");
  testAssert (views[1]->fullInvalidations == 0
                  && views[1]->partialInvalidations == 0,
              @"Mouse modes and ignored OSC titles cause no repaint");
  [views[0] setValue: [NSNumber numberWithBool: NO] forKey: @"_blinkOn"];
  [views[1] setValue: [NSNumber numberWithBool: NO] forKey: @"_blinkOn"];
  testAssert (
      terminalCursorPixelVisible (views[0])
          && !terminalCursorPixelVisible (views[1]),
      @"Only the active terminal hides its cursor during the blink off phase");
  [windows[0] makeKeyAndOrderFront: nil];
  testAssert (terminalCursorPixelVisible (views[0])
                  && terminalCursorPixelVisible (views[1]),
              @"Switching active windows immediately restores both cursors");
  [views[0] setValue: [NSNumber numberWithBool: NO] forKey: @"_blinkOn"];
  [views[1] setValue: [NSNumber numberWithBool: NO] forKey: @"_blinkOn"];
  testAssert (!terminalCursorPixelVisible (views[0])
                  && terminalCursorPixelVisible (views[1]),
              @"Blinking follows the newly active terminal");
  [YCodePreferences setTerminalCursorBlink: NO];
  [views[0] setValue: [NSNumber numberWithBool: NO] forKey: @"_blinkOn"];
  testAssert (terminalCursorPixelVisible (views[0]),
              @"Disabling cursor blink keeps the active cursor steady");
  views[0]->fullInvalidations = views[0]->partialInvalidations = 0;
  [views[0] advanceBlink];
  testAssert (views[0]->fullInvalidations == 0
                  && views[0]->partialInvalidations == 0,
              @"Disabled cursor blink causes no repaint");
  terminalFeed (views[0], @"\033[5mX\033[0m");
  views[0]->fullInvalidations = views[0]->partialInvalidations = 0;
  [views[0] advanceBlink];
  testAssert (
      views[0]->fullInvalidations == 0 && views[0]->partialInvalidations > 0,
      @"ANSI blinking text still repaints with cursor blinking disabled");
  [views[0] setHidden: YES];
  views[0]->fullInvalidations = views[0]->partialInvalidations = 0;
  [views[0] advanceBlink];
  testAssert (views[0]->fullInvalidations == 0
                  && views[0]->partialInvalidations == 0,
              @"Hidden terminal tabs do not redraw for blinking text");
  [views[0] setHidden: NO];
  terminalFeed (views[0], @"\033[2J\033[H");
  [YCodePreferences setTerminalCursorBlink: YES];
  terminalFeed (views[0], @"\033[?25l");
  testAssert (!terminalCursorPixelVisible (views[0]),
              @"Application-requested hidden cursor remains hidden");
  NSArray *updates = [NSArray
      arrayWithObjects: @"\033[?25hhello", @"\rH", @"\033[2;2H中é",
                       @"\033[2;3HX", @"\033[3;1H\033[4;41m   \033[0m",
                       @"\033[3;2H\033[K", @"\033[?1049hother screen",
                       @"\033[?1049l", @"\033[2J\033[H", nil];
  NSEnumerator *enumerator = [updates objectEnumerator];
  NSString *update;
  while ((update = [enumerator nextObject]) != nil)
    {
      terminalFeed (views[0], update);
      [views[0] displayIfNeeded];
      NSData *partial = [[terminalRenderedPixels (views[0]) copy] autorelease];
      [views[0] setNeedsDisplay: YES];
      [views[0] displayIfNeeded];
      testAssert (
          [partial isEqual: terminalRenderedPixels (views[0])],
          @"Incremental painting matches a complete repaint (text, wide glyphs, decorations, alternate screen)");
    }
  [YCodePreferences resetTerminalPreferences];
  for (i = 0; i < 2; i++)
    {
      [windows[i] close];
      [views[i] release];
      [windows[i] release];
    }
}

static void
testNativeTerminalParser (void)
{
  YCodeTerminalTestView *view = [[YCodeTerminalTestView alloc]
      initWithFrame: NSMakeRect (0, 0, 800, 400)];
  YCodeTerminalTestView *other = [[YCodeTerminalTestView alloc]
      initWithFrame: NSMakeRect (0, 0, 800, 400)];
  YCodeTerminalGlyph cell;
  terminalFeed (view, @"\033[2;4H\033[s\033[H\033[");
  terminalFeed (view, @"uX");
  [view cellAtRow: 1 column: 3 cell: &cell];
  testAssert (cell.chars[0] == 'X',
              @"Native parser restores bpytop CSI s/u cursor across reads");
  terminalFeed (view, @"\033c\033[?69h\033[3;8s\033[?6hZ");
  [view cellAtRow: 0 column: 2 cell: &cell];
  testAssert (cell.chars[0] == 'Z',
              @"CSI s still sets enabled horizontal margins");
  terminalFeed (view, @"\033c\033[38:2::12:34:56mC\033[48:5:236m ");
  [view cellAtRow: 0 column: 0 cell: &cell];
  testAssert (cell.fg.rgb.red == 12 && cell.fg.rgb.blue == 56,
              @"Native parser accepts colon-delimited truecolor");
  terminalFeed (view, @"\033c\033[99999999999999999999;2HOK");
  testAssert ([[view screenText] hasPrefix: @"OK"],
              @"Overflowing terminal parameters are discarded");
  terminalFeed (view, @"\033c\033]2;");
  NSMutableData *oversized = [NSMutableData dataWithLength: 70000];
  memset ([oversized mutableBytes], 'z', [oversized length]);
  [view consumeData: oversized];
  terminalFeed (view, @"\007OK");
  testAssert (
      [[view screenText] hasPrefix: @"OK"],
      @"Oversized control strings are bounded and do not print payloads");
  terminalFeed (view, @"\033c中\033[1;2HX");
  [view cellAtRow: 0 column: 0 cell: &cell];
  testAssert (cell.width == 1 && !cell.chars[0],
              @"Overwriting wide continuation clears its leading glyph");
  terminalFeed (view, @"\033c\033[31mR\033]4;1;rgb:12/34/56\033\\");
  YCodeTerminalParser *parser = [view valueForKey: @"_terminal"];
  [view cellAtRow: 0 column: 0 cell: &cell];
  YCodeTerminalColor color = [parser resolvedColor: cell.fg];
  testAssert (color.rgb.red == 0x12 && color.rgb.blue == 0x56,
              @"OSC palette changes resolve existing indexed cells");
  terminalFeed (other, @"\033[31mR");
  [other cellAtRow: 0 column: 0 cell: &cell];
  color = [[other valueForKey: @"_terminal"] resolvedColor: cell.fg];
  testAssert (color.rgb.red != 0x12,
              @"Palette state is isolated between project terminals");
  terminalFeed (view, @"\033[6 q");
  testAssert ([[view valueForKey: @"_cursorShape"] intValue] == 3
                  && ![[view valueForKey: @"_cursorBlink"] boolValue],
              @"Program-controlled steady bar cursor reaches the renderer");
  [view takeOutput];
  terminalFeed (view, @"\033[?1004h");
  [parser focusChanged: YES];
  [parser focusChanged: NO];
  testAssert (
      [[view takeOutput]
          isEqual: [@"\033[I\033[O" dataUsingEncoding: NSUTF8StringEncoding]],
      @"Focus reporting follows the enabled terminal mode");
  terminalFeed (view, @"\033[?1002h\033[?1006h");
  [parser mouseAtRow: 2 column: 3 button: 1 pressed: YES modifiers: 0];
  [parser mouseAtRow: 2 column: 4 button: 0 pressed: YES modifiers: 0];
  [parser mouseAtRow: 2 column: 4 button: 1 pressed: NO modifiers: 0];
  testAssert (
      [[view takeOutput] isEqual: [@"\033[<0;4;3M\033[<32;5;3M\033[<0;5;3m"
                                     dataUsingEncoding: NSUTF8StringEncoding]],
      @"SGR mouse reporting preserves press, drag, and release");
  terminalFeed (view, @"\033c\033[?1000h");
  [parser mouseAtRow: 0 column: 0 button: 1 pressed: YES modifiers: 0];
  [parser mouseAtRow: 0 column: 0 button: 1 pressed: NO modifiers: 0];
  testAssert (
      [[view takeOutput] isEqual: [@"\033[M !!\033[M#!!"
                                     dataUsingEncoding: NSUTF8StringEncoding]],
      @"Legacy mouse reports remain byte-compatible");
  terminalFeed (view, @"\033c\033[?1049h\033[2;4H\033[s\033[H\033[u⣿");
  [view cellAtRow: 1 column: 3 cell: &cell];
  testAssert (cell.chars[0] == 0x28ff && cell.width == 1,
              @"bpytop braille graphs stay in their saved terminal cell");
  [view release];
  [other release];
}

static void
testTerminal (NSString *temporaryDirectory)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id savedTerminalPreferences =
      [[defaults objectForKey: @"YCodeTerminalPreferences"] retain];
  [YCodePreferences resetTerminalPreferences];
  testNativeTerminalParser ();
  testTerminalRedrawing ();
  id savedWindowFrame =
      [[defaults objectForKey: @"NSWindow Frame YCodeMainWindow"] retain];
  YCodeTerminalTestView *view = [[YCodeTerminalTestView alloc]
      initWithFrame: NSMakeRect (0, 0, 800, 400)];
  testAssert (![view isRunning],
              @"Constructing a terminal does not start a shell");
  terminalFeed (view, @"abc\rZ\033[2;4HQ\033[1;2H\033[K");
  YCodeTerminalGlyph cell;
  [view cellAtRow: 0 column: 0 cell: &cell];
  testAssert (cell.chars[0] == 'Z',
              @"Terminal carriage return overwrites the current line");
  [view cellAtRow: 0 column: 1 cell: &cell];
  testAssert (cell.chars[0] == 0, @"Erase-to-end clears terminal cells");
  [view cellAtRow: 1 column: 3 cell: &cell];
  testAssert (cell.chars[0] == 'Q',
              @"ANSI absolute cursor addressing uses rows and columns");
  terminalFeed (view, @"\033[H\033[38;2;12;");
  terminalFeed (view, @"34;56;48;5;196;1;4mC");
  [view cellAtRow: 0 column: 0 cell: &cell];
  testAssert (
      cell.chars[0] == 'C' && cell.fg.rgb.red == 12 && cell.fg.rgb.green == 34
          && cell.fg.rgb.blue == 56 && cell.bg.index == 196
          && (cell.attributes & YCodeTerminalBold)
          && (cell.attributes & YCodeTerminalUnderline),
      @"Fragmented SGR supports truecolor, indexed color, bold, and underline");
  terminalFeed (view, @"\033[0m\033[2J\033[Hnormal\033[?1049h\033[Halternate");
  testAssert ([[view screenText] hasPrefix: @"alternate"],
              @"Full-screen applications get an alternate screen");
  terminalFeed (view, @"\033[?1049l");
  testAssert ([[view screenText] hasPrefix: @"normal"],
              @"Leaving alternate screen restores shell contents");
  terminalFeed (view, @"\033[2J\033[H\033(0lqk\033(B");
  testAssert ([[view screenText] hasPrefix: @"┌─┐"],
              @"DEC line drawing character set renders box characters");
  terminalFeed (view, @"\033[2J\033[H");
  NSData *unicode = [@"é中é" dataUsingEncoding: NSUTF8StringEncoding];
  NSUInteger byte;
  for (byte = 0; byte < [unicode length]; byte++)
    [view consumeData: [unicode subdataWithRange: NSMakeRange (byte, 1)]];
  testAssert (
      [[view screenText] hasPrefix: @"é中é"],
      @"Split UTF-8, wide characters, and combining marks survive reads");
  terminalFeed (view, @"\033[2J\033[H1\r\n2\r\n3\r\n4\033[2;3r\033[3;1H\n");
  [view cellAtRow: 0 column: 0 cell: &cell];
  testAssert (cell.chars[0] == '1',
              @"Scrolling margins preserve the line above the region");
  [view cellAtRow: 1 column: 0 cell: &cell];
  testAssert (cell.chars[0] == '3',
              @"Scrolling margins move only the selected region");
  terminalFeed (view, @"\033[r\033[2J\033[HABC\033[1;2H\033[@X");
  testAssert ([[view screenText] hasPrefix: @"AXBC"],
              @"Insert-character shifts terminal cells");
  terminalFeed (view, @"\033[1;2H\033[P");
  testAssert ([[view screenText] hasPrefix: @"ABC"],
              @"Delete-character shifts terminal cells back");
  terminalFeed (view, @"\033]0;untrusted title\007\033[2J\033[Hsafe");
  testAssert (
      [[view screenText] hasPrefix: @"safe"],
      @"OSC title bytes are consumed without printing escape payloads");
  int row;
  for (row = 0; row < 100; row++)
    terminalFeed (view, @"history\r\n");
  testAssert ([[view valueForKey: @"_history"] count] > 0,
              @"Terminal retains bounded scrollback");
  NSScroller *historyScroller = [view valueForKey: @"_historyScroller"];
  testAssert (
      [historyScroller knobProportion] < 1.0 &&
          [historyScroller doubleValue] == 1.0,
      @"Terminal scrollbar follows live output when history is available");
  [historyScroller setDoubleValue: 0];
  [historyScroller sendAction: [historyScroller action]
                           to: [historyScroller target]];
  testAssert (
      [[view valueForKey: @"_scrollOffset"] integerValue] ==
          [[view valueForKey: @"_history"] count],
      @"Dragging the scrollbar to the top reaches the oldest retained output");
  NSInteger previousOffset =
      [[view valueForKey: @"_scrollOffset"] integerValue];
  terminalFeed (view, @"new output\r\n");
  testAssert ([[view valueForKey: @"_scrollOffset"] integerValue]
                  == previousOffset + 1,
              @"New output preserves the position while browsing history");
  [historyScroller setDoubleValue: 1];
  [historyScroller sendAction: [historyScroller action]
                           to: [historyScroller target]];
  testAssert ([[view valueForKey: @"_scrollOffset"] integerValue] == 0,
              @"Dragging the scrollbar to the bottom returns to live output");
  terminalFeed (view, @"\033[?1049h");
  testAssert ([historyScroller knobProportion] == 1.0,
              @"Alternate screens do not expose shell history");
  terminalFeed (view, @"\033[?1049l");
  testAssert (
      [historyScroller knobProportion] < 1.0,
      @"Returning from an alternate screen restores the history scrollbar");
  terminalFeed (view, @"\033[3J\033[2J\033[H");
  testAssert (
      [[view valueForKey: @"_history"] count] == 0 &&
          [historyScroller knobProportion] == 1.0,
      @"Erase-scrollback clears retained history and disables the scrollbar");
  [view takeOutput];
  terminalFeed (view, @"\033[4;9H\033[6n");
  testAssert (
      [[view takeOutput]
          isEqual: [@"\033[4;9R" dataUsingEncoding: NSUTF8StringEncoding]],
      @"Device status query returns the current terminal cursor position");
  unichar arrow = NSUpArrowFunctionKey;
  NSString *up = [NSString stringWithCharacters: &arrow length: 1];
  NSEvent *upEvent = [NSEvent keyEventWithType: NSKeyDown
                                      location: NSZeroPoint
                                 modifierFlags: 0
                                     timestamp: 0
                                  windowNumber: 0
                                       context: nil
                                    characters: up
                   charactersIgnoringModifiers: up
                                     isARepeat: NO
                                       keyCode: 0];
  [view keyDown: upEvent];
  testAssert ([[view takeOutput]
                  isEqual: [@"\033[A" dataUsingEncoding: NSUTF8StringEncoding]],
              @"Normal cursor keys send CSI sequences");
  terminalFeed (view, @"\033[?1h");
  [view keyDown: upEvent];
  testAssert ([[view takeOutput]
                  isEqual: [@"\033OA" dataUsingEncoding: NSUTF8StringEncoding]],
              @"Application cursor mode switches keyboard sequences");
  terminalFeed (view, @"\033[?1l\033[?2004h");
  NSPasteboard *pasteboard = [view pasteboard];
  [pasteboard declareTypes: [NSArray arrayWithObject: NSStringPboardType]
                     owner: nil];
  [pasteboard setString: @"first\nsecond" forType: NSStringPboardType];
  [view paste: nil];
  testAssert (
      [[view takeOutput] isEqual: [@"\033[200~first\rsecond\033[201~"
                                     dataUsingEncoding: NSUTF8StringEncoding]],
      @"Bracketed paste wraps multiline clipboard text for supporting applications");
  terminalFeed (view, @"\033[?2004l\033[2J\033[Hcopy me");
  [view selectAll: nil];
  [view copy: nil];
  testAssert (
      [[pasteboard stringForType: NSStringPboardType] hasPrefix: @"copy me\n"],
      @"Terminal selection copies text without escape sequences");
  [view setValue: [NSNumber numberWithInt: -1] forKey: @"_selectionStart"];
  [view setValue: [NSNumber numberWithInt: -1] forKey: @"_selectionEnd"];
  terminalFeed (view, @"\033[2J\033[H");

  // Exercise AppKit drawing, including wide glyphs, in a real window.
  NSWindow *preview = [[NSWindow alloc]
      initWithContentRect: NSMakeRect (20, 20, 800, 400)
                styleMask: NSTitledWindowMask | NSClosableWindowMask
                          | NSResizableWindowMask
                  backing: NSBackingStoreBuffered
                    defer: NO];
  [preview setReleasedWhenClosed: NO];
  [preview setTitle: @"Ycode Terminal"];
  [preview setContentView: view];
  [preview makeKeyAndOrderFront: nil];
  terminalFeed (
      view,
      @"Ycode Terminal — ANSI / VT100\r\n\r\n\033[1mBold\033[0m  \033[4mUnderline\033[0m  \033[3mItalic\033[0m\r\n");
  for (row = 0; row < 16; row++)
    terminalFeed (
        view, [NSString stringWithFormat: @"\033[48;5;%dm  %2d  ", row, row]);
  terminalFeed (
      view,
      @"\033[0m\r\n\r\n\033[38;2;90;200;255mTruecolor\033[0m  UTF-8: café 中 é\r\n\r\n\033(0lqqqqqqqqqqqqqqqqqqqqk\r\nx\033(B ANSI line drawing  \033(0x\r\nmqqqqqqqqqqqqqqqqqqqqj\033(B\r\n\r\n$ ");
  [preview display];
  if ([[[NSProcessInfo processInfo] arguments]
          containsObject: @"--terminal-preview"])
    {
      NSBitmapImageRep *bitmap =
          [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
      [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
      [[bitmap representationUsingType: NSPNGFileType
                            properties: [NSDictionary dictionary]]
          writeToFile: @"/tmp/ycode-terminal-preview.png"
           atomically: YES];
    }
#ifndef _WIN32
  NSString *directory = [temporaryDirectory
      stringByAppendingPathComponent: @"Terminal Folder With Spaces"];
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSError *error = nil;
  testAssert ([view startInDirectory: directory error: &error] && error == nil,
              @"Launch interactive shell on a PTY");
  if ([view isRunning])
    {
      int child = [[view valueForKey: @"_child"] intValue];
      testAssert ([view startInDirectory: @"/" error: &error] &&
                      [[view valueForKey: @"_child"] intValue] == child,
                  @"Repeated opening preserves the project shell");
      [view
          sendData:
              [@"stty -echo; printf '\\033[2J\\033[H'; test -t 0 && printf '%s%s\\n' YCODE_ISTTY _YES; pwd\r"
                  dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert (
          terminalWait (view, @"YCODE_ISTTY_YES")
              && terminalWait (view, directory),
          @"Shell has a controlling terminal and starts in the project directory with spaces");
      [view sendData: [@"printf '%s%s\\n' YCODE_TERM_ \"$TERM\"\r"
                         dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert (terminalWait (view, @"YCODE_TERM_xterm-256color"),
                  @"Shell advertises the implemented terminal protocol");
      [view setFrameSize: NSMakeSize (640, 320)];
      NSString *dimensions =
          [NSString stringWithFormat: @"%@ %@", [view valueForKey: @"_rows"],
                                     [view valueForKey: @"_columns"]];
      [view sendData: [@"stty size\r" dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert (
          terminalWait (view, dimensions),
          @"Resizing propagates row and column counts through the PTY");
      // A foreground job must receive Ctrl-C through the PTY, not terminate Ycode.
      [view sendData: [@"sleep 30\r" dataUsingEncoding: NSUTF8StringEncoding]];
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
      NSEvent *interrupt = [NSEvent keyEventWithType: NSKeyDown
                                            location: NSZeroPoint
                                       modifierFlags: NSControlKeyMask
                                           timestamp: 0
                                        windowNumber: [preview windowNumber]
                                             context: nil
                                          characters: @"\003"
                         charactersIgnoringModifiers: @"c"
                                           isARepeat: NO
                                             keyCode: 0];
      [view keyDown: interrupt];
      [view sendData: [@"printf '%s%s\\n' YCODE_INTERRUPT _OK\r"
                         dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert (terminalWait (view, @"YCODE_INTERRUPT_OK") &&
                      [view isRunning],
                  @"Ctrl-C interrupts the job and preserves the shell");
      if ([[NSFileManager defaultManager]
              isExecutableFileAtPath: @"/usr/bin/vim"])
        {
          [view
              sendData:
                  [@"/usr/bin/vim -Nu NONE -i NONE -n 'terminal editor.txt'\r"
                      dataUsingEncoding: NSUTF8StringEncoding]];
          NSDate *editorDeadline = [NSDate dateWithTimeIntervalSinceNow: 8];
          while (![[view valueForKey: @"_alternateScreen"] boolValue] &&
                 [editorDeadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
          testAssert ([[view valueForKey: @"_alternateScreen"] boolValue],
                      @"Vim enters its full-screen terminal mode");
          [view sendData: [@"iYcode terminal editor test\033:wq\r"
                             dataUsingEncoding: NSUTF8StringEncoding]];
          editorDeadline = [NSDate dateWithTimeIntervalSinceNow: 8];
          while ([[view valueForKey: @"_alternateScreen"] boolValue] &&
                 [editorDeadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
          testAssert (
              ![[view valueForKey: @"_alternateScreen"] boolValue] &&
                  [[NSString stringWithContentsOfFile:
                                 [directory stringByAppendingPathComponent:
                                                @"terminal editor.txt"]
                                             encoding: NSUTF8StringEncoding
                                                error: NULL]
                      isEqual: @"Ycode terminal editor test\n"],
              @"An interactive Vim session edits, saves, exits, and restores the shell screen");
        }
      if ([[[NSProcessInfo processInfo] arguments]
              containsObject: @"--terminal-bpytop"])
        {
          [preview
              setContentSize: NSMakeSize (
                                 [[view valueForKey: @"_cellWidth"] doubleValue]
                                         * 100
                                     + [NSScroller scrollerWidth],
                                 [[view valueForKey: @"_cellHeight"]
                                     doubleValue]
                                     * 35)];
          NSString *config = [temporaryDirectory
              stringByAppendingPathComponent: @"bpytop-config"];
          NSString *quoted =
              [config stringByReplacingOccurrencesOfString: @"'"
                                                withString: @"'\\''"];
          NSString *command = [NSString
              stringWithFormat: @"XDG_CONFIG_HOME='%@' /usr/bin/bpytop\r",
                               quoted];
          [view sendData: [command dataUsingEncoding: NSUTF8StringEncoding]];
          NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 6];
          while ([deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
          NSString *screen = [view screenText];
          NSUInteger i, graphCells = 0;
          for (i = 0; i < [screen length]; i++)
            if ([screen characterAtIndex: i] >= 0x2800 &&
                [screen characterAtIndex: i] <= 0x28ff)
              graphCells++;
          testAssert (
              [[view valueForKey: @"_alternateScreen"] boolValue]
                  && graphCells > 0,
              @"Live bpytop draws braille graphs in its alternate screen");
          [preview display];
          NSBitmapImageRep *bitmap =
              [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
          [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
          [[bitmap representationUsingType: NSPNGFileType
                                properties: [NSDictionary dictionary]]
              writeToFile: @"/tmp/ycode-bpytop-native.png"
               atomically: YES];
          [view sendData: [@"q" dataUsingEncoding: NSUTF8StringEncoding]];
          deadline = [NSDate dateWithTimeIntervalSinceNow: 5];
          while ([[view valueForKey: @"_alternateScreen"] boolValue] &&
                 [deadline timeIntervalSinceNow] > 0)
            [[NSRunLoop currentRunLoop]
                runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
          testAssert (![[view valueForKey: @"_alternateScreen"] boolValue],
                      @"Live bpytop exits on q and restores the shell");
        }
      [view sendData: [@"exit\r" dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert (terminalWait (view, @"Shell exited.") && ![view isRunning],
                  @"Shell exit drains output and releases the PTY");
      [view restart: nil];
      testAssert ([view isRunning], @"Exited shells can be restarted");
      child = [[view valueForKey: @"_child"] intValue];
      [preview close];
      testAssert (![view isRunning],
                  @"Closing the project window hangs up its terminal");
      NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 3];
      while (kill (child, 0) == 0 && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop]
            runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
      testAssert (kill (child, 0) < 0 && errno == ESRCH,
                  @"Terminal cleanup reaps the shell without zombies");
    }
  error = nil;
  testAssert (
      ![view startInDirectory: [directory
                                  stringByAppendingPathComponent: @"missing"]
                        error: &error]
          && error != nil,
      @"Invalid terminal directories produce a useful error");
#endif
  [preview close];
  [preview release];
  [view release];

  // Verify project integration without launching a shell during normal startup.
  YCodeProject *project = [[YCodeProject alloc] init];
  NSError *loadError = nil;
  NSString *integrationDirectory = [temporaryDirectory
      stringByAppendingPathComponent: @"Terminal Integration"];
  [[NSFileManager defaultManager] createDirectoryAtPath: integrationDirectory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  testAssert ([project readFromURL: [NSURL fileURLWithPath: integrationDirectory]
                            ofType: @"YCodeMakeProjectType"
                             error: &loadError],
              @"Open a directory project for terminal integration");
  [project makeWindowControllers];
  YCodeWindowController *window =
      [[project windowControllers] objectAtIndex: 0];
  NSTabView *tabs = [window valueForKey: @"_bottomTabView"];
  YCodeTerminalView *terminal = RETAIN ([window valueForKey: @"_terminalView"]);
  testAssert ([tabs indexOfTabViewItemWithIdentifier: @"terminal"] != NSNotFound
                  && ![terminal isRunning],
              @"Project has a Terminal tab with no shell until selected");
#ifndef _WIN32
  [window setBottomPanelVisible: NO];
  [[window window] setContentSize: NSMakeSize (1100, 700)];
  [window openTerminal: nil];
  testAssert (
      [terminal isRunning] &&
          [[[tabs selectedTabViewItem] identifier] isEqual: @"terminal"],
      @"Open Terminal reveals its tab and starts a project shell");
  int expectedColumns = MAX (
      2, (int)(([tabs contentRect].size.width - [NSScroller scrollerWidth]) /
               [[terminal valueForKey: @"_cellWidth"] doubleValue]));
  int expectedRows
      = MAX (2, (int)([tabs contentRect].size.height /
                      [[terminal valueForKey: @"_cellHeight"] doubleValue]));
  testAssert (
      [[terminal valueForKey: @"_columns"] intValue] == expectedColumns &&
          [[terminal valueForKey: @"_rows"] intValue] == expectedRows,
      @"Opening Terminal sizes its screen to the visible tab after the window was resized");
  [terminal sendData: [@"stty -echo; stty size\r"
                         dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      terminalWait (
          terminal,
          [NSString stringWithFormat: @"%d %d", expectedRows, expectedColumns]),
      @"The shell receives the visible terminal dimensions on first opening");
  [tabs selectTabViewItemWithIdentifier: @"console"];
  testAssert ([terminal isRunning],
              @"Switching tabs keeps the terminal session alive");
  int terminalChild = [[terminal valueForKey: @"_child"] intValue];
  [[window window] setContentSize: NSMakeSize (900, 600)];
  [tabs selectTabViewItemWithIdentifier: @"terminal"];
  expectedColumns = MAX (
      2, (int)(([tabs contentRect].size.width - [NSScroller scrollerWidth]) /
               [[terminal valueForKey: @"_cellWidth"] doubleValue]));
  expectedRows
      = MAX (2, (int)([tabs contentRect].size.height /
                      [[terminal valueForKey: @"_cellHeight"] doubleValue]));
  testAssert (
      [[terminal valueForKey: @"_columns"] intValue] == expectedColumns &&
          [[terminal valueForKey: @"_child"] intValue] == terminalChild,
      @"Returning to Terminal updates its width without restarting the shell");
  [terminal sendData: [@"stty size\r" dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      terminalWait (
          terminal,
          [NSString stringWithFormat: @"%d %d", expectedRows, expectedColumns]),
      @"The running shell receives the new dimensions when its tab is reopened");
  testAssert ([window isTerminalVisible], @"Selected Terminal tab is visible");
  YCodeTerminalMenuTestController *menuController =
      [YCodeTerminalMenuTestController new];
  menuController->terminalWindow = window;
  NSMenuItem *terminalItem =
      [[NSMenuItem alloc] initWithTitle: @"Open Terminal"
                                 action: @selector (openTerminal:)
                          keyEquivalent: @""];
  testAssert (
      [menuController validateMenuItem: terminalItem] &&
          [[terminalItem title] isEqual: @"Close Terminal"],
      @"Menu validation offers Close Terminal when the pane is visible");
  [menuController openTerminal: terminalItem];
  testAssert ([[terminalItem title] isEqual: @"Open Terminal"],
              @"Closing immediately updates the menu title");
  testAssert (![window isTerminalVisible] && ![window isBottomPanelVisible] &&
                  [terminal isRunning],
              @"Close Terminal hides the pane while preserving its shell");
  [window openTerminal: nil];
  testAssert ([window isTerminalVisible] &&
                  [[terminal valueForKey: @"_child"] intValue] == terminalChild,
              @"Open Terminal restores the same shell after closing the pane");
  [tabs selectTabViewItemWithIdentifier: @"console"];
  testAssert (![window isTerminalVisible],
              @"A different bottom tab does not count as an open Terminal");
  [window openTerminal: nil];
  testAssert ([window isTerminalVisible],
              @"Open Terminal switches from another visible bottom tab");
  menuController->terminalWindow = nil;
  testAssert (![menuController validateMenuItem: terminalItem] &&
                  [[terminalItem title] isEqual: @"Open Terminal"],
              @"Terminal menu resets and disables without a project window");
  [terminalItem release];
  [menuController release];
  [project close];
  testAssert (![terminal isRunning],
              @"Closing the project stops the terminal session");
#else
  [project close];
#endif
  [project release];
  [terminal release];
  if (savedWindowFrame)
    [defaults setObject: savedWindowFrame
                 forKey: @"NSWindow Frame YCodeMainWindow"];
  else
    [defaults removeObjectForKey: @"NSWindow Frame YCodeMainWindow"];
  [savedWindowFrame release];
  if (savedTerminalPreferences)
    [defaults setObject: savedTerminalPreferences
                 forKey: @"YCodeTerminalPreferences"];
  else
    [defaults removeObjectForKey: @"YCodeTerminalPreferences"];
  [savedTerminalPreferences release];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeTerminalPreferencesDidChangeNotification
                    object: nil];
}

static void
testTerminalPreferences (NSString *temporaryDirectory)
{
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps: YES];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeTerminalPreferences"] retain];
  id editorFonts = [[defaults objectForKey: @"YCodeFonts"] retain];
  [defaults
      setObject: [NSDictionary
                    dictionaryWithObjectsAndKeys:
                        @"missing font", @"fontName", @"bad size", @"fontSize",
                        [NSNumber numberWithInt: -1], @"scrollbackLines",
                        [NSArray arrayWithObject: @"invalid"], @"foreground",
                        @"invalid", @"cursorBlink", nil]
         forKey: @"YCodeTerminalPreferences"];
  testAssert (
      [[YCodePreferences terminalFont] pointSize] == 13 &&
          [YCodePreferences terminalScrollbackLines] == 5000 &&
          [YCodePreferences terminalCursorBlink]
          && colorMatches ([YCodePreferences terminalForegroundColor],
                           230.0 / 255.0, 230.0 / 255.0, 230.0 / 255.0),
      @"Invalid saved terminal preferences fall back to usable defaults");
  [YCodePreferences resetTerminalPreferences];
  YCodeTerminalView *terminal =
      [[YCodeTerminalView alloc] initWithFrame: NSMakeRect (0, 0, 800, 400)];
  AppController *app = [AppController new];
  [app showPrefPanel: nil];
  NSPopUpButton *groups = [app valueForKey: @"_preferencesGroup"];
  [groups selectItemWithTitle: @"Terminal"];
  [groups sendAction: [groups action] to: [groups target]];
  NSView *pane = [app valueForKey: @"_terminalPreferencesView"];
  testAssert (![pane isHidden] &&
                  [[app valueForKey: @"_fontPreferencesView"] isHidden],
              @"Preferences provides a separate Terminal section");
  NSButton *fontChoice = [app valueForKey: @"_terminalFontChoice"];
  testAssert ([fontChoice isKindOfClass: [NSButton class]]
                  && ![fontChoice isKindOfClass: [NSPopUpButton class]],
              @"Terminal font uses the native Fonts panel");
#ifndef _WIN32
  [[NSFileManager defaultManager] createDirectoryAtPath: temporaryDirectory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSError *error = nil;
  testAssert ([terminal startInDirectory: temporaryDirectory error: &error],
              @"Start terminal for live preference updates");
  int child = [[terminal valueForKey: @"_child"] intValue];
#endif
  [fontChoice performClick: nil];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  NSFontManager *manager = [NSFontManager sharedFontManager];
  NSFontPanel *fontPanel = [manager fontPanel: YES];
  [fontPanel setPanelFont: [manager convertFont: [YCodePreferences terminalFont]
                                        toSize: 20]
               isMultiple: NO];
  [fontPanel makeKeyAndOrderFront: nil];
  [manager modifyFontViaPanel: fontPanel];
  testAssert ([[YCodePreferences terminalFont] pointSize] == 20 &&
                  [[terminal valueForKey: @"_font"] pointSize] == 20,
              @"Native Fonts panel persists and updates the terminal font");
  [fontPanel orderOut: nil];
#ifndef _WIN32
  testAssert ([terminal isRunning] &&
                  [[terminal valueForKey: @"_child"] intValue] == child,
              @"Changing terminal preferences preserves the live shell");
  [terminal sendData: [@"stty -echo; stty size\r"
                         dataUsingEncoding: NSUTF8StringEncoding]];
  NSString *size =
      [NSString stringWithFormat: @"%@ %@", [terminal valueForKey: @"_rows"],
                                 [terminal valueForKey: @"_columns"]];
  testAssert (terminalWait (terminal, size),
              @"Font changes update the live shell's PTY dimensions");
#endif
  NSColorWell *foreground = [app valueForKey: @"_terminalForegroundWell"];
  NSColorWell *background = [app valueForKey: @"_terminalBackgroundWell"];
  terminalFeed (terminal, @"\033[2J\033[H\033[31mX\033[0m preserved");
  [foreground activate: YES];
  [[NSColorPanel sharedColorPanel]
      setColor: [NSColor colorWithCalibratedRed: 0.2
                                         green: 0.8
                                          blue: 0.6
                                         alpha: 1]];
  [foreground deactivate];
  [background activate: YES];
  [[NSColorPanel sharedColorPanel]
      setColor: [NSColor colorWithCalibratedRed: 0.1
                                         green: 0.15
                                          blue: 0.2
                                         alpha: 1]];
  [background deactivate];
  testAssert (
      colorMatches ([terminal valueForKey: @"_foregroundColor"], 0.2, 0.8, 0.6)
          && colorMatches ([terminal valueForKey: @"_backgroundColor"], 0.1,
                           0.15, 0.2),
      @"Terminal color controls immediately update default foreground and background");
  YCodeTerminalGlyph cell;
  [terminal cellAtRow: [[terminal valueForKey: @"_history"] count]
               column: 0
                 cell: &cell];
  testAssert (
      cell.fg.index == 1 &&
          [[terminal screenText] rangeOfString: @"preserved"].location
              != NSNotFound,
      @"Preference changes retain terminal text and explicit ANSI colors");
  testAssert (colorMatches ([YCodePreferences terminalCursorColor], 1, 0, 0),
              @"Cursor defaults to red");
  NSColorWell *cursorWell = [app valueForKey: @"_terminalCursorWell"];
  [cursorWell activate: YES];
  [[NSColorPanel sharedColorPanel] setColor: [NSColor greenColor]];
  [cursorWell deactivate];
  [[NSColorPanel sharedColorPanel] orderOut: nil];
  NSPopUpButton *shape = [app valueForKey: @"_terminalCursorShapeChoice"];
  NSInteger cursorShape;
  for (cursorShape = 0; cursorShape <= 4; cursorShape++)
    {
      [shape selectItemAtIndex: cursorShape];
      [shape sendAction: [shape action] to: [shape target]];
      testAssert (
          [YCodePreferences terminalCursorShape] == cursorShape &&
              [[terminal valueForKey: @"_preferredCursorShape"] integerValue]
                  == cursorShape,
          @"Cursor shape selection persists and updates existing terminals");
    }
  testAssert (colorMatches ([terminal valueForKey: @"_cursorColor"], 0, 1, 0),
              @"Color panel changes the live cursor color");
  NSUInteger i;
  for (i = 0; i < 100; i++)
    terminalFeed (terminal, @"scrollback\r\n");
  testAssert ([[terminal valueForKey: @"_history"] count] > 0,
              @"Populate scrollback before reducing its limit");
  NSPopUpButton *scrollback = [app valueForKey: @"_terminalScrollbackChoice"];
  [scrollback selectItemWithTitle: @"0"];
  [scrollback sendAction: [scrollback action] to: [scrollback target]];
  terminalFeed (terminal, @"more\r\n");
  testAssert (
      [YCodePreferences terminalScrollbackLines] == 0 &&
          [[terminal valueForKey: @"_history"] count] == 0,
      @"Setting scrollback to zero discards history and stops retaining new lines");
  NSButton *bell = [app valueForKey: @"_terminalBellCheckbox"],
           *blink = [app valueForKey: @"_terminalBlinkCheckbox"];
  [bell setState: NSOffState];
  [bell sendAction: [bell action] to: [bell target]];
  [blink setState: NSOffState];
  [blink sendAction: [blink action] to: [blink target]];
  testAssert (![[terminal valueForKey: @"_audibleBell"] boolValue]
                  && ![[terminal valueForKey: @"_allowCursorBlink"] boolValue],
              @"Bell and cursor-blink controls update existing terminals");
  YCodeTerminalView *newTerminal =
      [[YCodeTerminalView alloc] initWithFrame: NSMakeRect (0, 0, 800, 400)];
  testAssert (
      [[newTerminal valueForKey: @"_font"] pointSize] == 20
          && colorMatches ([newTerminal valueForKey: @"_foregroundColor"], 0.2,
                           0.8, 0.6)
          && ![[newTerminal valueForKey: @"_audibleBell"] boolValue],
      @"New terminals load saved preferences");
  NSWindow *renderWindow =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 800, 400)
                                  styleMask: NSBorderlessWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [renderWindow setReleasedWhenClosed: NO];
  [renderWindow setContentView: newTerminal];
  [renderWindow orderFront: nil];
  terminalFeed (newTerminal, @"M\r\n");
  for (cursorShape = 1; cursorShape <= 4; cursorShape++)
    {
      [YCodePreferences setTerminalCursorShape: cursorShape];
      [renderWindow display];
      NSBitmapImageRep *bitmap = [newTerminal
          bitmapImageRepForCachingDisplayInRect: [newTerminal bounds]];
      [newTerminal cacheDisplayInRect: [newTerminal bounds]
                     toBitmapImageRep: bitmap];
      NSUInteger x, y, cursorPixels = 0, textPixels = 0;
      NSUInteger width =
          [[newTerminal valueForKey: @"_cellWidth"] unsignedIntegerValue];
      NSUInteger height =
          [[newTerminal valueForKey: @"_cellHeight"] unsignedIntegerValue];
      for (y = 0; y < height * 2; y++)
        for (x = 0; x < width; x++)
          {
            NSColor *pixel = [bitmap colorAtX: x y: y];
            if (colorMatches (pixel, 0, 1, 0))
              cursorPixels++;
            if (colorMatches (pixel, 0.2, 0.8, 0.6))
              textPixels++;
          }
      NSUInteger expected = cursorShape == 1   ? width * height
                            : cursorShape == 2 ? 2 * (width + height) - 4
                            : cursorShape == 3 ? 2 * height
                                               : 2 * width;
      testAssert (cursorPixels == expected,
                  @"Rendered cursor uses the selected color and shape");
      testAssert (
          textPixels > 0
              && colorMatches ([bitmap colorAtX: 400 y: 200], 25.0 / 255.0,
                               38.0 / 255.0, 51.0 / 255.0),
          @"Terminal renders the selected default foreground and background colors");
    }
  [renderWindow close];
  [renderWindow release];
  [newTerminal release];
  NSPanel *panel = [app valueForKey: @"_preferencesPanel"];
  [panel display];
  if ([[[NSProcessInfo processInfo] arguments]
          containsObject: @"--terminal-preferences-preview"])
    {
      NSView *content = [panel contentView];
      NSBitmapImageRep *bitmap =
          [content bitmapImageRepForCachingDisplayInRect: [content bounds]];
      [content cacheDisplayInRect: [content bounds] toBitmapImageRep: bitmap];
      [[bitmap representationUsingType: NSPNGFileType
                            properties: [NSDictionary dictionary]]
          writeToFile: @"/tmp/ycode-terminal-preferences.png"
           atomically: YES];
    }
  NSEnumerator *controls = [[pane subviews] objectEnumerator];
  id control;
  BOOL reset = NO;
  while ((control = [controls nextObject]) != nil)
    {
      if ([control isKindOfClass: [NSButton class]] &&
          [[control title] isEqual: @"Restore Defaults"])
        {
          [control performClick: nil];
          reset = YES;
          break;
        }
    }
  testAssert (
      reset && [[terminal valueForKey: @"_font"] pointSize] == 13 &&
          [YCodePreferences terminalScrollbackLines] == 5000 &&
          [YCodePreferences terminalAudibleBell] &&
          [YCodePreferences terminalCursorBlink],
      @"Restore Defaults resets only Terminal settings and updates open views");
  testAssert (
      editorFonts == [defaults objectForKey: @"YCodeFonts"] ||
          [editorFonts isEqual: [defaults objectForKey: @"YCodeFonts"]],
      @"Terminal preferences leave editor and other pane fonts unchanged");
  [groups selectItemWithTitle: @"Editor"];
  [groups sendAction: [groups action] to: [groups target]];
  testAssert ([pane isHidden],
              @"Changing preference groups hides Terminal controls");
  [terminal stop];
  [terminal release];
  [panel close];
  [app autorelease];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeTerminalPreferences"];
  else
    [defaults removeObjectForKey: @"YCodeTerminalPreferences"];
  [saved release];
  [editorFonts release];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeTerminalPreferencesDidChangeNotification
                    object: nil];
}

static void
testHelp (void)
{
  AppController *delegate = [[AppController alloc] init];
  [delegate buildMainMenu];
  [delegate awakeFromNib];
#ifdef GNUSTEP
  id item = [[[[NSApp mainMenu] itemWithTitle: @"Info"] submenu]
      itemWithTitle: @"Help"];
#else
  id item = [[[[NSApp mainMenu] itemWithTitle: @"Help"] submenu]
      itemWithTitle: @"Ycode Help"];
#endif
  testAssert ([item target] == delegate &&
                  [item action] == @selector (showHelp:),
              @"Help menu routes to the application user guide");
  NSUInteger count =
      [[[NSDocumentController sharedDocumentController] documents] count];
  testAssert ([NSApp sendAction: [item action] to: [item target] from: item],
              @"Invoke Help through its menu action");
  NSWindow *window = [delegate valueForKey: @"_helpWindow"];
  testAssert ([window isVisible] && [[window title] isEqual: @"Ycode Help"],
              @"Help displays without opening a project");
  NSScrollView *scroll = [[[window contentView] subviews] lastObject];
  NSTextView *view = [scroll documentView];
  testAssert (![view isEditable] && [view isSelectable] &&
                  [scroll hasVerticalScroller],
              @"Help is scrollable and copyable but cannot be edited");
  testAssert ([[view string] rangeOfString: @"4. MAKEFILE PROJECTS"].location
                      != NSNotFound
                  && [[view string] rangeOfString: @"5. DEBUGGING"].location
                         != NSNotFound
                  &&
                  [[view string] rangeOfString: @"7. TROUBLESHOOTING"].location
                      != NSNotFound,
              @"Help loads the bundled user documentation");
  [delegate showHelp: nil];
  testAssert ([delegate valueForKey: @"_helpWindow"] == window,
              @"Repeated Help reuses its window");
  [window close];
  [delegate showHelp: nil];
  testAssert ([window isVisible] &&
                  [delegate valueForKey: @"_helpWindow"] == window,
              @"Help reopens safely after closing");
  testAssert (
      [[[NSDocumentController sharedDocumentController] documents] count]
          == count,
      @"Help does not create project documents");
  [window close];
  [delegate autorelease];
}

static void
testRecentDocuments (YCodeProject *project, NSString *directory)
{
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  NSArray *saved = [[controller recentDocumentURLs] copy];
  NSMenu *menu = [[[[[NSApp mainMenu] itemWithTitle: @"File"] submenu]
      itemWithTitle: @"Recent Documents"] submenu];
  testAssert (menu != nil, @"File menu exposes Recent Documents");
  [controller clearRecentDocuments: nil];
  NSURL *missing = [NSURL
      fileURLWithPath:
          [directory stringByAppendingPathComponent: @"Missing.xcodeproj"]];
  [controller noteNewRecentDocumentURL: missing];
  [controller noteNewRecentDocumentURL: [project fileURL]];
  [menu update];
  NSMenuItem *first = [menu itemAtIndex: 0];
  testAssert ([[first representedObject] isEqual: [project fileURL]] &&
                  [first isEnabled],
              @"Recent Documents shows the latest project first");
  testAssert (![[menu itemAtIndex: 1] isEnabled],
              @"Missing recent projects are disabled");
  NSUInteger count = [[controller documents] count];
  [NSApp sendAction: [first action] to: [first target] from: first];
  testAssert ([[controller documents] count] == count &&
                  [controller documentForURL: [project fileURL]] == project,
              @"Opening a recent project reuses its existing document");
  [menu update];
  NSUInteger occurrences = 0;
  {
    NSEnumerator *itemEnumerator = [[menu itemArray] objectEnumerator];
    NSMenuItem *item;
    while ((item = [itemEnumerator nextObject]) != nil)
      if ([[item representedObject] isEqual: [project fileURL]])
        occurrences++;
  }
  testAssert (occurrences == 1,
              @"Reopening does not duplicate recent entries");
  NSMenuItem *clear = (NSMenuItem *)[menu itemWithTitle: @"Clear Menu"];
  [NSApp sendAction: [clear action] to: [clear target] from: clear];
  testAssert ([[controller recentDocumentURLs] count] == 0 &&
                  [menu numberOfItems] == 1
                  && ![[menu itemAtIndex: 0] isEnabled],
              @"Clear Menu clears recent history and disables itself");
#ifdef GNUSTEP
  {
    NSEnumerator *urlEnumerator = [saved objectEnumerator];
    NSURL *url;
    while ((url = [urlEnumerator nextObject]) != nil)
      [controller noteNewRecentDocumentURL: url];
  }
#else
  {
    NSEnumerator *urlEnumerator = [saved reverseObjectEnumerator];
    NSURL *url;
    while ((url = [urlEnumerator nextObject]) != nil)
      [controller noteNewRecentDocumentURL: url];
  }
#endif
  [menu update];
  [saved release];
}

static void
testSaveActiveFile (YCodeProject *project, NSString *directory)
{
  YCodeEditorController *editor = [project editorController];
  NSString *firstPath =
      [directory stringByAppendingPathComponent: @"Save First.m"];
  NSString *secondPath =
      [directory stringByAppendingPathComponent: @"Save Second.m"];
  NSString *original = @"// original\n";
  [original writeToFile: firstPath
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  [original writeToFile: secondPath
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  testAssert ([editor openFile: firstPath] && [editor openFile: secondPath],
              @"Open source files for Save regression");
  YCodeEditorDocument *first = [editor documentForFilePath: firstPath];
  YCodeEditorDocument *second = [editor documentForFilePath: secondPath];
  [first insertText: @"// first edit\n" atLocation: 0];
  [second insertText: @"// second edit\n" atLocation: 0];
  [editor setCurrentDocument: first];
  YCodeWindowController *window =
      [[project windowControllers] objectAtIndex: 0];
  [[window window] makeKeyAndOrderFront: nil];
  testAssert ([[NSDocumentController sharedDocumentController] currentDocument]
                  == project,
              @"Save resolves the project belonging to the active window");
  NSString *projectFile = [[project projectPath]
      stringByAppendingPathComponent: @"project.pbxproj"];
  NSData *projectBefore = [NSData dataWithContentsOfFile: projectFile];
  [project updateChangeCount: NSChangeDone];
  NSMenuItem *save = (NSMenuItem *)[[[[NSApp mainMenu] itemWithTitle: @"File"]
      submenu] itemWithTitle: @"Save"];
  testAssert (save != nil && [[save keyEquivalent] isEqual: @"s"] &&
                  [save action] == @selector (saveDocument:),
              @"File Save and its shortcut invoke the same action");
  [NSApp sendAction: [save action] to: [save target] from: save];
  NSString *written = [NSString stringWithContentsOfFile: firstPath
                                                encoding: NSUTF8StringEncoding
                                                   error: NULL];
  testAssert (
      [written isEqual: [first content]] && ![first isModified],
      @"File Save writes the active editor contents and clears its modified flag");
  testAssert ([[NSString stringWithContentsOfFile: secondPath
                                         encoding: NSUTF8StringEncoding
                                            error: NULL] isEqual: original]
                  && [second isModified],
              @"Saving one source tab leaves the other tab's edits unsaved");
  testAssert (
      [projectBefore isEqual: [NSData dataWithContentsOfFile: projectFile]] &&
          [project isDocumentEdited],
      @"Saving a source file does not save or clear pending project changes");
  [editor setCurrentDocument: second];
  [NSApp sendAction: [save action] to: [save target] from: save];
  testAssert (
      [[NSString stringWithContentsOfFile: secondPath
                                 encoding: NSUTF8StringEncoding
                                    error: NULL] isEqual: [second content]]
          && ![second isModified],
      @"Save follows the selected source tab");
  // Keep cleanup independent of a failed Save assertion, without opening a modal prompt.
  [first setModified: NO];
  [second setModified: NO];
  [editor closeFile: firstPath];
  [editor closeFile: secondPath];
  [project updateChangeCount: NSChangeCleared];
}

static NSUInteger
buildReferenceCount (YCodeProject *project, PBXFileReference *reference)
{
  NSUInteger count = 0;
  {
    NSEnumerator *targetEnumerator =
        [[[project project] targets] objectEnumerator];
    PBXTarget *target;
    while ((target = [targetEnumerator nextObject]) != nil)
      {
        NSEnumerator *phaseEnumerator =
            [[target buildPhases] objectEnumerator];
        PBXBuildPhase *phase;
        while ((phase = [phaseEnumerator nextObject]) != nil)
          {
            NSEnumerator *fileEnumerator = [[phase files] objectEnumerator];
            PBXBuildFile *file;
            while ((file = [fileEnumerator nextObject]) != nil)
              if ([file fileRef] == reference)
                count++;
          }
      }
  }
  return count;
}

static void
testProjectFileMembership (YCodeProject *project, NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *source =
      [directory stringByAppendingPathComponent: @"Added Source.cc"];
  NSString *nestedDirectory =
      [directory stringByAppendingPathComponent: @"Nested Folder"];
  NSString *nestedSource =
      [nestedDirectory stringByAppendingPathComponent: @"Added Source.cc"];
  [manager createDirectoryAtPath: nestedDirectory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [@"int value;\n" writeToFile: source
                    atomically: YES
                      encoding: NSUTF8StringEncoding
                         error: NULL];
  [@"int nestedValue;\n" writeToFile: nestedSource
                          atomically: YES
                            encoding: NSUTF8StringEncoding
                               error: NULL];
  PBXGroup *mainGroup = [[project project] mainGroup];
  NSUInteger originalCount = [[mainGroup children] count];
  [project addFilesToProject: [NSArray arrayWithObjects: source, source, nil]];
  testAssert (
      [project isDocumentEdited] &&
          [[mainGroup children] count] == originalCount + 1,
      @"Adding a file marks the project modified and avoids duplicates in one operation");
  PBXFileReference *reference = [[[mainGroup children] lastObject] retain];
  testAssert (
      [[reference path] isEqual: @"Added Source.cc"] &&
          [[reference sourceTree] isEqual: @"SOURCE_ROOT"],
      @"Files inside the project use portable source-root-relative references");
  testAssert (buildReferenceCount (project, reference) > 0,
              @"Added C++ files enter the sources build phase");
  [project updateChangeCount: NSChangeCleared];
  [project addFilesToProject: [NSArray arrayWithObject: @"./Added Source.cc"]];
  testAssert (
      ![project isDocumentEdited] &&
          [[mainGroup children] count] == originalCount + 1,
      @"Adding the same file through a relative path is a clean no-op");
  testAssert ([project addGroupToProject: @"Membership Group"] &&
                  [project isDocumentEdited],
              @"Adding a group also marks the project modified");
  PBXGroup *nested = [[mainGroup children] lastObject];
  [nested setPath: @"Nested Folder"];
  [nested setSourceTree: @"SOURCE_ROOT"];
  PBXFileReference *nestedReference = AUTORELEASE (
      [[PBXFileReference alloc] initWithPath: @"Added Source.cc"]);
  [nested setChildren: [NSMutableArray arrayWithObject: nestedReference]];
  // The same reference may appear in several build phases; removal must clean all of them.
  PBXTarget *target = [[[project project] targets] objectAtIndex: 0];
  {
    NSEnumerator *phaseEnumerator = [[target buildPhases] objectEnumerator];
    PBXBuildPhase *phase;
    while ((phase = [phaseEnumerator nextObject]) != nil)
      {
        if (![phase files])
          [phase setFiles: [NSMutableArray array]];
        PBXBuildFile *file = AUTORELEASE ([[PBXBuildFile alloc] init]);
        [file setFileRef: nestedReference];
        [[phase files] addObject: file];
      }
  }
  testAssert ([project saveProjectToPath: [project projectPath]]
                  && ![project isDocumentEdited],
              @"Successful project save clears the project modified state");
  YCodeProject *reopened = [YCodeProject new];
  testAssert ([reopened readFromURL: [project fileURL]
                             ofType: @"YCodeXcodeProjectType"
                              error: NULL],
              @"Reopen the project after adding files");
  PBXFileReference *savedReference =
      [[[[reopened project] mainGroup] children] objectAtIndex: originalCount];
  testAssert ([[savedReference path] isEqual: @"Added Source.cc"]
                  && buildReferenceCount (reopened, savedReference) > 0,
              @"Added file and its build membership survive save and reload");
  [reopened close];
  [reopened release];
  [project removeFilesFromProject:
               [NSArray arrayWithObject: @"Nested Folder/Added Source.cc"]];
  testAssert (
      [project isDocumentEdited] && [[nested children] count] == 0
          && buildReferenceCount (project, nestedReference) == 0,
      @"Removing a nested file updates its group and every build phase");
  testAssert (
      [[mainGroup children] containsObject: reference] &&
          [manager fileExistsAtPath: nestedSource],
      @"Removal preserves the source on disk and same-named files in other groups");
  NSString *badDestination =
      [directory stringByAppendingPathComponent: @"Not A Directory.xcodeproj"];
  [@"blocked" writeToFile: badDestination
               atomically: YES
                 encoding: NSUTF8StringEncoding
                    error: NULL];
  testAssert (![project saveProjectToPath: badDestination] &&
                  [project isDocumentEdited],
              @"Failed project saves retain the modified state");
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  [navigator expandItem: [navigator itemForObject: mainGroup]];
  [navigator selectItem: [navigator itemForObject: reference]];
  [navigator deleteItem: nil];
  testAssert (
      ![[mainGroup children] containsObject: reference] &&
          [manager fileExistsAtPath: source],
      @"Navigator Remove File changes the project without deleting the disk file");
  NSMenuItem *saveProject
      = (NSMenuItem *)[[[[NSApp mainMenu] itemWithTitle: @"File"] submenu]
          itemWithTitle: @"Save Project"];
  testAssert (
      saveProject != nil,
      @"A separate Save Project action is available with an editor tab open");
  [NSApp sendAction: [saveProject action]
                 to: [saveProject target]
               from: saveProject];
  testAssert (
      ![project isDocumentEdited],
      @"Save Project persists membership changes while a source tab is open");
  reopened = [YCodeProject new];
  testAssert ([reopened readFromURL: [project fileURL]
                             ofType: @"YCodeXcodeProjectType"
                              error: NULL],
              @"Reopen project after removal");
  NSDictionary *archive = [NSDictionary
      dictionaryWithContentsOfFile:
          [[project projectPath]
              stringByAppendingPathComponent: @"project.pbxproj"]];
  {
    NSEnumerator *objectEnumerator =
        [[[archive objectForKey: @"objects"] allValues] objectEnumerator];
    NSDictionary *object;
    while ((object = [objectEnumerator nextObject]) != nil)
      testAssert (
          ![[object objectForKey: @"path"] isEqual: @"Added Source.cc"],
          @"Removed file references are absent from the serialized project");
  }
  [reopened close];
  [reopened release];
  [project removeFilesFromProject: [NSArray arrayWithObject: source]];
  testAssert (![project isDocumentEdited],
              @"Removing a missing project reference is a clean no-op");
  [reference release];
}

static void
testEditorColorPreferences (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeEditorColors"] retain];
  id savedRulers = [[defaults objectForKey: @"YCodeHideEditorRulers"] retain];
  [defaults removeObjectForKey: @"YCodeHideEditorRulers"];
  [YCodeSyntaxHighlighter resetColorPreferences];
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: @"Colors.m"
                                            content: @"int ordinary = 42;"];
  [document setModified: NO];
  testAssert (
      colorMatches ([[document textView] insertionPointColor], 1, 0, 0),
      @"Insertion cursor defaults to red");
  YCodeEditorController *existingEditor = [YCodeEditorController new];
  AppController *app = [AppController new];
  [app showPrefPanel: nil];
  NSPanel *panel = [app valueForKey: @"_preferencesPanel"];
  NSArray *wells = [app valueForKey: @"_editorColorWells"];
  NSArray *keys = [YCodeSyntaxHighlighter colorPreferenceKeys];
  testAssert (
      colorMatches ([[wells objectAtIndex: 0] color], 0, 0, 0)
          && colorMatches ([[wells objectAtIndex: 1] color], 1, 1, 1)
          && colorMatches ([[document textView] backgroundColor], 0, 0, 0)
          && colorMatches ([[[document textView] textStorage]
                                    attribute: NSForegroundColorAttributeName
                                      atIndex: 4
                               effectiveRange: NULL],
                           1, 1, 1),
      @"Default preferences and editor both use white text on black regardless of the system theme");
  testAssert (
      [panel isVisible] && [wells count] == 11,
      @"Preferences exposes background, plain text, cursor and all eight syntax colors");
  NSUInteger i;
  for (i = 0; i < [wells count]; i++)
    {
      NSColorWell *well = [wells objectAtIndex: i];
      testAssert (NSContainsRect ([[panel contentView] bounds], [well frame]),
                  @"Color controls fit within the preferences panel");
      [well setColor: [NSColor colorWithDeviceRed: 0.1 + i * 0.04
                                           green: 0.2
                                            blue: 0.3
                                           alpha: 1]];
      [well sendAction: [well action] to: [well target]];
      testAssert (
          colorMatches ([YCodeSyntaxHighlighter
                            preferredColorForKey: [keys objectAtIndex: i]],
                        0.1 + i * 0.04, 0.2, 0.3),
          @"Color wells save each chosen color");
      if ([[keys objectAtIndex: i] isEqual: @"cursor"])
        {
          testAssert (
              colorMatches ([[document textView] insertionPointColor], 0.5,
                            0.2, 0.3),
              @"Cursor preference updates the open editor immediately");
        }
      else if (i >= 2)
        {
          NSString *property =
              [[keys objectAtIndex: i] stringByAppendingString: @"Color"];
          testAssert (
              colorMatches (
                  [[document syntaxHighlighter] valueForKey: property],
                  0.1 + i * 0.04, 0.2, 0.3),
              @"Open highlighters update every syntax category immediately");
        }
    }
  testAssert (
      colorMatches ([[document textView] backgroundColor], 0.1, 0.2, 0.3)
          && colorMatches ([[[document textView] textStorage]
                                    attribute: NSForegroundColorAttributeName
                                      atIndex: 4
                               effectiveRange: NULL],
                           0.14, 0.2, 0.3)
          && ![document isModified],
      @"Live background and plain text updates do not mark source files modified");
  NSPopUpButton *groups = [app valueForKey: @"_preferencesGroup"];
  NSView *colorsGroup = [app valueForKey: @"_colorPreferencesView"];
  NSView *editorGroup = [app valueForKey: @"_editorPreferencesView"];
  NSButton *rulers = [app valueForKey: @"_showEditorRulers"];
  testAssert ([groups numberOfItems] == 7 && ![colorsGroup isHidden] &&
                  [editorGroup isHidden],
              @"Preferences starts with the color group selected");
  [groups selectItemAtIndex: 1];
  [groups sendAction: [groups action] to: [groups target]];
  testAssert (
      [colorsGroup isHidden] && ![editorGroup isHidden] &&
          [rulers state] == NSOnState,
      @"Selecting Editor exposes ruler preferences with rulers enabled by default");
  [rulers setState: NSOffState];
  [rulers sendAction: [rulers action] to: [rulers target]];
  testAssert (
      ![[document scrollView] rulersVisible] && ![document isModified] &&
          [defaults boolForKey: @"YCodeHideEditorRulers"],
      @"Turning rulers off updates open editors and saves the preference without modifying source");
  YCodeEditorDocument *newDocument =
      [[YCodeEditorDocument alloc] initWithFilePath: @"NewColors.m"
                                            content: @"int value;"];
  testAssert (![[newDocument scrollView] rulersVisible],
              @"New editors respect the saved ruler preference");
  NSString *reopenedPath = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[[NSProcessInfo processInfo]
                                         globallyUniqueString]
                                         stringByAppendingPathExtension: @"m"]];
  [@"int ordinary = 42;" writeToFile: reopenedPath
                          atomically: YES
                            encoding: NSUTF8StringEncoding
                               error: NULL];
  testAssert (
      [existingEditor openFile: reopenedPath]
          && colorMatches (
              [[[existingEditor currentDocument] textView] backgroundColor],
              0.1, 0.2, 0.3)
          && ![[[existingEditor currentDocument] scrollView] rulersVisible],
      @"Existing controllers open files with the updated palette and ruler settings");
  NSTask *reader = [NSTask new];
  [reader
      setLaunchPath: [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0]];
  [reader setArguments: [NSArray arrayWithObjects: @"--check-editor-preferences",
                                                 reopenedPath, nil]];
  [reader launch];
  [reader waitUntilExit];
  testAssert (
      [reader terminationStatus] == 0,
      @"A separate process reloads saved colors and ruler settings when opening a source file");
  [reader release];
  [existingEditor closeFile: reopenedPath];
  [existingEditor release];
  [[NSFileManager defaultManager] removeItemAtPath: reopenedPath error: NULL];
  [rulers setState: NSOnState];
  [rulers sendAction: [rulers action] to: [rulers target]];
  testAssert ([[document scrollView] rulersVisible] &&
                  [[newDocument scrollView] rulersVisible],
              @"Turning rulers back on restores them in all open editors");
  [groups selectItemAtIndex: 0];
  [groups sendAction: [groups action] to: [groups target]];
  testAssert (![colorsGroup isHidden] && [editorGroup isHidden],
              @"Returning to Colors restores its controls");
  testAssert (
      colorMatches ([[newDocument textView] backgroundColor], 0.1, 0.2, 0.3)
          && colorMatches ([[newDocument syntaxHighlighter] keywordColor],
                           0.18, 0.2, 0.3)
          && [[defaults dictionaryForKey: @"YCodeEditorColors"] count] == 11,
      @"New editors inherit the persisted palette");
  testAssert (colorMatches ([[newDocument textView] insertionPointColor], 0.5,
                            0.2, 0.3),
              @"New editors inherit the saved cursor color");
  [YCodeSyntaxHighlighter resetColorPreferences];
  testAssert (
      [defaults objectForKey: @"YCodeEditorColors"] == nil
          && colorMatches ([[document syntaxHighlighter] keywordColor], 0.67,
                           0.20, 0.89),
      @"Restoring defaults clears saved overrides and recolors open editors");
  testAssert (colorMatches ([[document textView] insertionPointColor], 1, 0, 0)
                  && ![document isModified],
              @"Reset restores a red cursor without modifying the document");
  [panel close];
  [app release];
  [newDocument release];
  [document release];
  if (savedRulers)
    [defaults setObject: savedRulers forKey: @"YCodeHideEditorRulers"];
  else
    [defaults removeObjectForKey: @"YCodeHideEditorRulers"];
  [savedRulers release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeEditorColors"];
  [saved release];
  [defaults synchronize];
}

@interface YCodeTestSound : NSSound
{
  BOOL _playing;
}

@end
@implementation YCodeTestSound
- (BOOL) play
{
  _playing = YES;
  return YES;
}

- (BOOL) pause
{
  _playing = NO;
  return YES;
}

- (BOOL) resume
{
  _playing = YES;
  return YES;
}

- (BOOL) stop
{
  _playing = NO;
  return YES;
}

- (BOOL) isPlaying
{
  return _playing;
}

@end

static void
testSoundInspector (NSString *directory)
{
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  [@"all:\n\t@true\n"
      writeToFile: [directory stringByAppendingPathComponent: @"Makefile"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  unsigned char header[]
      = { 'R', 'I', 'F',  'F',  0xa4, 0x3e, 0,    0,    'W',  'A', 'V',
          'E', 'f', 'm',  't',  ' ',  16,   0,    0,    0,    1,   0,
          1,   0,   0x40, 0x1f, 0,    0,    0x80, 0x3e, 0,    0,   2,
          0,   16,  0,    'd',  'a',  't',  'a',  0x80, 0x3e, 0,   0 };
  NSMutableData *wave = [NSMutableData dataWithBytes: header
                                              length: sizeof (header)];
  NSUInteger i;
  for (i = 0; i < 8000; i++)
    {
      unsigned char sample[] = { 0, i % 2 ? 0x40 : 0xc0 };
      [wave appendBytes: sample length: 2];
    }
  NSString *path = [directory stringByAppendingPathComponent: @"Tone.WAV"];
  [wave writeToFile: path atomically: YES];
  YCodeProject *project = [YCodeProject new];
  [project readFromURL: [NSURL fileURLWithPath: directory]
                ofType: @"YCodeMakeProjectType"
                 error: NULL];
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: project];
  [[window window] setContentSize: NSMakeSize (1200, 760)];
  [[window window] makeKeyAndOrderFront: nil];
  testAssert ([[project editorController] openFile: path],
              @"Sound files open as project resources");
  YCodeEditorDocument *document = [[project editorController] currentDocument];
  testAssert ([document isSoundDocument] && [document textView] == nil
                  && ![document isModified],
              @"Sound previews are read-only, not binary text editors");
  NSTabView *tabs = [window valueForKey: @"_inspectorTabView"];
  testAssert ([[[tabs selectedTabViewItem] identifier] isEqual: @"sound"],
              @"Selecting sound files selects the Sound inspector");
  YCSoundInspectorView *inspector = (id)[[tabs selectedTabViewItem] view];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 5];
  while (![inspector valueForKey: @"_peaks"] &&
         [deadline timeIntervalSinceNow] > 0)
    [[NSRunLoop currentRunLoop]
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
#ifdef YCODE_HAVE_SNDFILE
  NSData *peaks = [inspector valueForKey: @"_peaks"];
  testAssert (
      [peaks length] == 1024 * sizeof (float)
          && fabs (((const float *)[peaks bytes])[100] - 0.5) < 0.01
          && fabs ([[inspector valueForKey: @"_duration"] doubleValue] - 1)
                 < 0.01,
      @"Waveform decodes actual PCM peaks and duration");
#endif
  [document saveToFile];
  testAssert ([[NSData dataWithContentsOfFile: path] isEqual: wave],
              @"Save never alters sound bytes");
  YCodeProjectNavigatorItem *item = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject: nil
                           type: YCodeNavigatorItemTypeFile];
  testAssert ([[item iconForFileExtension: @"WAV"] isValid] &&
                  [item iconForFileExtension: @"WAV"] ==
                      [item iconForFileExtension: @"flac"],
              @"Audio extensions share a dedicated sound icon");
  PBXFileReference *audioFile = [PBXFileReference new];
  [audioFile setPath: path];
  [item setRepresentedObject: audioFile];
  NSBitmapImageRep *iconPixels =
      [NSBitmapImageRep imageRepWithData: [[item icon] TIFFRepresentation]];
  testAssert (
      iconPixels != nil && [[item icon] isValid] &&
          [[iconPixels colorAtX: 8 y: 8] alphaComponent] > 0,
      @"Sound icon retains visible pixels after the navigator copies it");
  NSString *iconPath = [[[NSProcessInfo processInfo] environment]
      objectForKey: @"YCODE_TEST_ICON_PATH"];
  if (iconPath)[[iconPixels representationUsingType: NSPNGFileType
                                         properties: [NSDictionary dictionary]]
      writeToFile: iconPath
       atomically: YES]
    ;
  [audioFile release];
  [item release];
  NSSound *realSound = [[NSSound alloc] initWithContentsOfFile: path
                                                   byReference: YES];
  testAssert (realSound != nil && fabs ([realSound duration] - 1) < 0.01,
              @"System audio decodes the selected sound");
  [realSound setVolume: 0];
  testAssert ([realSound play],
              @"System audio can start muted preview playback");
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
  [realSound stop];
  [realSound release];
  YCodeTestSound *sound = [YCodeTestSound new];
  [inspector setValue: sound forKey: @"_sound"];
  [inspector togglePlayback: nil];
  testAssert ([sound isPlaying] &&
                  [[[inspector valueForKey: @"_play"] title] isEqual: @"Pause"],
              @"Play starts audio and presents Pause");
  [inspector togglePlayback: nil];
  testAssert (![sound isPlaying] &&
                  [[[inspector valueForKey: @"_play"] title] isEqual: @"Resume"],
              @"Pause presents Resume");
  [inspector togglePlayback: nil];
  testAssert ([sound isPlaying], @"Resume restarts paused playback");
  [inspector inspectDocument: nil];
  testAssert (![sound isPlaying]
                  && ![[inspector valueForKey: @"_play"] isEnabled],
              @"Changing selection stops playback and disables controls");
  [sound release];
  NSString *bad = [directory stringByAppendingPathComponent: @"Invalid.wav"];
  [@"not audio" writeToFile: bad
                 atomically: YES
                   encoding: NSUTF8StringEncoding
                      error: NULL];
  testAssert ([[project editorController] openFile: bad],
              @"Invalid audio still opens a safe read-only preview");
  [inspector togglePlayback: nil];
  testAssert ([[[inspector valueForKey: @"_status"] stringValue]
                  rangeOfString: @"Unable to play"]
                      .location
                  != NSNotFound,
              @"Unsupported or corrupt audio has a visible playback error");
  [inspector inspectDocument: document];
  YCodeTestSound *closingSound = [YCodeTestSound new];
  [inspector setValue: closingSound forKey: @"_sound"];
  [inspector togglePlayback: nil];
  [window close];
  testAssert (![closingSound isPlaying],
              @"Closing the project window stops preview playback");
  [closingSound release];
  [window setProject: nil];
  [window release];
  [project release];
}

static void
testTabPreferences (NSString *directory)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *keys =
      [NSArray arrayWithObjects: @"YCodeTabWidth", @"YCodeUseTabCharacters",
                                @"YCodeIgnoreProjectIndentation",
                                @"YCodeControlIndentWidth", nil];
  NSMutableDictionary *saved = [NSMutableDictionary dictionary];
  NSEnumerator *e = [keys objectEnumerator];
  NSString *key;
  while ((key = [e nextObject]))
    {
      if ([defaults objectForKey: key])
        [saved setObject: [defaults objectForKey: key] forKey: key];
      [defaults removeObjectForKey: key];
    }
  testAssert ([YCodePreferences tabWidth] == 2 &&
                  [YCodePreferences useSpacesForTabs],
              @"Tabs default to two spaces");
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
      initWithFilePath: [directory stringByAppendingPathComponent: @"Tabs.m"]
               content: @"\t{\n    {"];
  YCodeTextView *view = (YCodeTextView *)[document textView];
  [document setModified: NO];
  AppController *app = [AppController new];
  [app showPrefPanel: nil];
  NSPopUpButton *group = [app valueForKey: @"_preferencesGroup"];
  [group selectItemWithTitle: @"Indentation"];
  [group sendAction: [group action] to: [group target]];
  testAssert (![[app valueForKey: @"_tabPreferencesView"] isHidden],
              @"Indentation group is available in Preferences");
  NSPopUpButton *controlWidth = [app valueForKey: @"_controlIndentChoice"];
  testAssert ([controlWidth indexOfSelectedItem] == 1,
              @"Control indentation defaults to two spaces");
  [controlWidth selectItemAtIndex: 3];
  [controlWidth sendAction: [controlWidth action] to: [controlWidth target]];
  testAssert ([YCodePreferences controlIndentWidth] == 4 &&
                  [YCodePreferences tabWidth] == 2,
              @"Control indentation preference is independent of tab width");
  [controlWidth selectItemAtIndex: 1];
  [controlWidth sendAction: [controlWidth action] to: [controlWidth target]];
  NSPopUpButton *width = [app valueForKey: @"_tabWidthChoice"];
  [width selectItemAtIndex: 3];
  [width sendAction: [width action] to: [width target]];
  testAssert ([view editorTabWidth] == 4 && [view editorIndentWidth] == 4,
              @"Preference changes update open editors immediately");
  testAssert (
      ![document isModified] && [[view string] isEqual: @"\t{\n    {"],
      @"Tab preferences preserve source whitespace and modified state");
  NSLayoutManager *layout = [view layoutManager];
  NSRect tabBrace = [layout
      boundingRectForGlyphRange: [layout
                                    glyphRangeForCharacterRange: NSMakeRange (1,
                                                                             1)
                                           actualCharacterRange: NULL]
                inTextContainer: [view textContainer]];
  NSRect spaceBrace = [layout
      boundingRectForGlyphRange: [layout
                                    glyphRangeForCharacterRange: NSMakeRange (7,
                                                                             1)
                                           actualCharacterRange: NULL]
                inTextContainer: [view textContainer]];
  testAssert (
      fabs (tabBrace.origin.x - spaceBrace.origin.x) < 0.1,
      @"A tab and four spaces align braces at the same displayed column");
  [document setContent: @""];
  [view insertTab: nil];
  testAssert ([[view string] isEqual: @"    "],
              @"Tab insertion uses the chosen space width");
  NSButton *spaces = [app valueForKey: @"_spacesForTabs"];
  [spaces setState: NSOffState];
  [spaces sendAction: [spaces action] to: [spaces target]];
  [document setContent: @""];
  [view insertTab: nil];
  testAssert ([[view string] isEqual: @"\t"],
              @"Tabs preference can insert literal tabs");
  NSTask *reader = [NSTask new];
  [reader
      setLaunchPath: [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0]];
  [reader setArguments: [NSArray arrayWithObject: @"--read-tab-preferences"]];
  [reader launch];
  [reader waitUntilExit];
  testAssert ([reader terminationStatus] == 0,
              @"Fresh process restores tab preferences");
  [reader release];
  [@"TabWidth: 8\nIndentWidth: 8\nUseTab: Never\n"
      writeToFile: [directory stringByAppendingPathComponent: @".clang-format"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [view setFilePath: [document filePath]];
  testAssert ([view editorTabWidth] == 8 && ![view editorUsesTabs],
              @"Project formatting settings retain precedence by default");
  NSButton *project = [app valueForKey: @"_projectIndentation"];
  [project setState: NSOffState];
  [project sendAction: [project action] to: [project target]];
  testAssert (
      [view editorTabWidth] == 4 && [view editorUsesTabs],
      @"Disabling project settings applies the user's choices to the open file");
  [[app valueForKey: @"_preferencesPanel"] close];
  [app release];
  [document release];
  e = [keys objectEnumerator];
  while ((key = [e nextObject]))
    {
      if ([saved objectForKey: key])
        [defaults setObject: [saved objectForKey: key] forKey: key];
      else
        [defaults removeObjectForKey: key];
    }
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeTabsDidChange"
                    object: nil];
}

static void
testFontAndSidebarPreferences (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray *keys = [NSArray
      arrayWithObjects: @"YCodeFonts", @"YCodeNavigatorWidth",
                       @"YCodeInspectorWidth", @"YCodeNavigatorHidden",
                       @"YCodeInspectorHidden",
                       @"NSWindow Frame YCodeMainWindow", nil];
  NSMutableDictionary *saved = [NSMutableDictionary dictionary];
  NSEnumerator *e = [keys objectEnumerator];
  NSString *key;
  while ((key = [e nextObject]))
    if ([defaults objectForKey: key])
      [saved setObject: [defaults objectForKey: key] forKey: key];
  [defaults setBool: NO forKey: @"YCodeNavigatorHidden"];
  [defaults setBool: NO forKey: @"YCodeInspectorHidden"];
  YCodeProject *project = [YCodeProject new];
  [project setProjectPath: @"/tmp/FontPreferences.xcodeproj"];
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: project];
  [[window window] setContentSize: NSMakeSize (1200, 800)];
  NSSplitView *main = [window valueForKey: @"_mainSplitView"];
  NSSplitView *content = [window valueForKey: @"_contentSplitView"];
  [main setPosition: 280 ofDividerAtIndex: 0];
  [content setPosition: NSWidth ([content bounds]) - [content dividerThickness]
                       - 210
      ofDividerAtIndex: 0];
  CGFloat navigatorWidth = [defaults doubleForKey: @"YCodeNavigatorWidth"];
  CGFloat inspectorWidth = [defaults doubleForKey: @"YCodeInspectorWidth"];
  testAssert (fabs (navigatorWidth - 280) < 2
                  && fabs (inspectorWidth - 210) < 2,
              @"Dragging sidebar dividers saves their widths");
  [window setNavigatorVisible: NO];
  [window setInspectorVisible: NO];
  testAssert (
      fabs ([defaults doubleForKey: @"YCodeNavigatorWidth"] - navigatorWidth)
              < 1
          && fabs ([defaults doubleForKey: @"YCodeInspectorWidth"]
                   - inspectorWidth)
                 < 1,
      @"Hiding sidebars preserves their expanded widths");
  YCodeEditorDocument *source =
      [[YCodeEditorDocument alloc] initWithFilePath: @"Fonts.m"
                                            content: @"int value;"];
  [source setModified: NO];
  YCodeBuildSystem *build = [project buildSystem];
  [window buildSystemDidStartBuild: build];
  [window buildSystem: build didReceiveOutput: @"\033[1;31mcolored\033[0m\n"];
  [window buildSystem: build didReceiveError: @"Fonts.m:1: error: message\n"];
  [window buildSystem: build didReceiveDebuggerOutput: @"debugger\n"];
  AppController *app = [AppController new];
  [app showPrefPanel: nil];
  NSPopUpButton *groups = [app valueForKey: @"_preferencesGroup"];
  [groups selectItemAtIndex: 2];
  [groups sendAction: [groups action] to: [groups target]];
  testAssert (![[app valueForKey: @"_fontPreferencesView"] isHidden],
              @"Fonts is an independent preference group");
  NSArray *choices = [app valueForKey: @"_fontChoices"];
  NSUInteger i;
  for (i = 0; i < 4; i++)
    {
      NSButton *choice = [choices objectAtIndex: i];
      [choice performClick: nil];
      NSFontManager *manager = [NSFontManager sharedFontManager];
      testAssert (
          [[choice window] firstResponder] == choice &&
              [[manager fontPanel: NO] isVisible],
          @"Each preference opens the font panel with its button as font responder");
      NSFont *selected = [NSFont fontWithName: @"DejaVuSerif" size: 18 + i];
      if (!selected)
        selected = [NSFont userFontOfSize: 18 + i];
      [[manager fontPanel: NO] setPanelFont: selected isMultiple: NO];
      [[manager fontPanel: NO] makeKeyAndOrderFront: nil];
      [manager modifyFontViaPanel: [manager fontPanel: NO]];
      testAssert (
          [[YCodePreferences fontForPane: [[YCodePreferences fontPanes]
                                             objectAtIndex: i]] pointSize]
              == 18 + i,
          @"Each pane saves its own font size");
      testAssert (
          [[[YCodePreferences fontForPane: [[YCodePreferences fontPanes]
                                              objectAtIndex: i]] fontName]
              isEqualToString: [selected fontName]]
              && [[choice title] rangeOfString: [selected displayName]].location
                     != NSNotFound,
          @"Selected font family is saved and displayed in Preferences");
      testAssert (
          [[[choice font] fontName] isEqualToString: [selected fontName]],
          @"Preference previews render using the selected font face");
    }
  NSTextView *console = [window valueForKey: @"_consoleTextView"];
  NSTextView *debugger = [window valueForKey: @"_debuggerTextView"];
  NSArray *issues = [window valueForKey: @"_buildIssues"];
  NSAttributedString *issue =
      [[issues objectAtIndex: 0] objectForKey: @"display"];
  testAssert (
      [[[source textView] font] pointSize] == 18 && ![source isModified] &&
          [[[console textStorage] attribute: NSFontAttributeName
                                    atIndex: 0
                             effectiveRange: NULL] pointSize]
              == 19
          && [[issue attribute: NSFontAttributeName
                        atIndex: 0
                 effectiveRange: NULL] pointSize]
                 == 20
          && [[[debugger textStorage] attribute: NSFontAttributeName
                                        atIndex: 0
                                 effectiveRange: NULL] pointSize]
                 == 21,
      @"Font changes update existing editor, console, issue and debugger text");
  [window buildSystem: build didReceiveOutput: @"\033[0mnew output"];
  testAssert ([[[console textStorage] attribute: NSFontAttributeName
                                        atIndex: [[console string] length] - 1
                                 effectiveRange: NULL] pointSize]
                  == 19,
              @"ANSI reset and new output retain the selected console font");
  [[[NSFontManager sharedFontManager] fontPanel: NO] orderOut: nil];
  [[app valueForKey: @"_preferencesPanel"] close];
  [app release];
  [window close];
  [window release];
  [project release];
  [source release];
  window = [YCodeWindowController new];
  [window setNavigatorVisible: YES];
  [window setInspectorVisible: YES];
  testAssert (
      fabs (NSWidth ([[window valueForKey: @"_navigatorView"] frame])
            - navigatorWidth)
              < 2
          && fabs (NSWidth ([[window valueForKey: @"_inspectorView"] frame])
                   - inspectorWidth)
                 < 2,
      @"Reopened windows restore both sidebar widths even when last hidden");
  NSTask *reader = [NSTask new];
  [reader
      setLaunchPath: [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0]];
  [reader setArguments: [NSArray arrayWithObject: @"--read-font-layout"]];
  [reader launch];
  [reader waitUntilExit];
  testAssert ([reader terminationStatus] == 0,
              @"Fresh process restores fonts and sidebar widths");
  [reader release];
  [window close];
  [window release];
  e = [keys objectEnumerator];
  while ((key = [e nextObject]))
    {
      if ([saved objectForKey: key])
        [defaults setObject: [saved objectForKey: key] forKey: key];
      else
        [defaults removeObjectForKey: key];
    }
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeFontsDidChange"
                    object: nil];
}

static void
testCloseModifiedFiles (NSString *directory)
{
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps: YES];
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSString *path = [directory stringByAppendingPathComponent: @"Closing.m"];
  [@"saved" writeToFile: path
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  YCodeProject *project = [YCodeProject new];
  [project makeWindowControllers];
  [[[project windowControllers] objectAtIndex: 0] showWindow: nil];
  YCodeEditorController *editor = [project editorController];
  [editor openFile: path];
  YCodeEditorDocument *file = [editor currentDocument];
  [file insertText: @"edit " atLocation: 0];
  answerCloseAlert (NSAlertThirdButtonReturn);
  testAssert (
      ![project canCloseDocument] && [file isModified],
      @"Cancel blocks project closure when a source file has unsaved edits");
  answerCloseAlert (NSAlertSecondButtonReturn);
  testAssert (
      [project canCloseDocument] && [file isModified] &&
          [[NSString stringWithContentsOfFile: path
                                     encoding: NSUTF8StringEncoding
                                        error: NULL] isEqual: @"saved"],
      @"Don't Save permits closure without writing the file or discarding edits prematurely");
  answerCloseAlert (NSAlertFirstButtonReturn);
  testAssert (
      [project canCloseDocument] && ![file isModified] &&
          [[NSString stringWithContentsOfFile: path
                                     encoding: NSUTF8StringEncoding
                                        error: NULL] isEqual: @"edit saved"],
      @"Save writes the edited source before permitting project closure");
  [file insertText: @"more " atLocation: 0];
  NSDocumentController *documents =
      [NSDocumentController sharedDocumentController];
  [documents addDocument: project];
  AppController *app = [AppController new];
  answerCloseAlert (NSAlertThirdButtonReturn);
  testAssert (
      [app applicationShouldTerminate: NSApp] == NSTerminateCancel,
      @"Quit reviews source edits even when project metadata is unchanged");
  answerCloseAlert (NSAlertFirstButtonReturn);
  testAssert ([app applicationShouldTerminate: NSApp] == NSTerminateNow
                  && ![file isModified],
              @"Quit saves modified files before allowing termination");
  [documents removeDocument: project];
  [app release];
  [project close];
  [project release];
}

static void
testFindReplace (NSString *directory)
{
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSString *path = [directory stringByAppendingPathComponent: @"Find.m"];
  [@"One one ONE\n[one] café café" writeToFile: path
                                    atomically: YES
                                      encoding: NSUTF8StringEncoding
                                         error: NULL];
  YCodeProject *project = [YCodeProject new];
  [project makeWindowControllers];
  YCodeEditorController *editor = [project editorController];
  [editor openFile: path];
  YCodeEditorDocument *document = [editor currentDocument];
  NSTextView *view = [document textView];
  [view setSelectedRange: NSMakeRange (0, 3)];
  [editor findInFile: nil];
  NSPanel *panel = [editor valueForKey: @"_findPanel"];
  NSTextField *find = [editor valueForKey: @"_findField"];
  NSTextField *replace = [editor valueForKey: @"_replaceField"];
  NSButton *caseSensitive = [editor valueForKey: @"_findCaseSensitive"];
  NSButton *wrap = [editor valueForKey: @"_findWrap"];
  testAssert ([panel isVisible] && [[find stringValue] isEqual: @"One"],
              @"Find opens a modeless panel seeded with selected text");
  NSString *screenshot = [[[NSProcessInfo processInfo] environment]
      objectForKey: @"YCODE_FIND_PANEL_IMAGE"];
  if ([screenshot length])
    {
      [[panel contentView] lockFocus];
      NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
          initWithFocusedViewRect: [[panel contentView] bounds]];
      [[panel contentView] unlockFocus];
      [[bitmap representationUsingType: NSPNGFileType
                            properties: [NSDictionary dictionary]]
          writeToFile: screenshot
           atomically: YES];
      [bitmap release];
    }
  [[[editor valueForKey: @"_findButtons"] objectAtIndex: 1] performClick: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (4, 3)),
              @"Find next ignores case by default");
  [editor findPrevious: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (0, 3)),
              @"Find previous selects preceding match");
  [editor findPrevious: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (13, 3)),
              @"Find previous wraps to last match");
  [editor findNext: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (0, 3)),
              @"Find next wraps to first match");
  [caseSensitive setState: NSOnState];
  [find setStringValue: @"ONE"];
  [editor findNext: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (8, 3)),
              @"Case-sensitive search selects exact case");
  [wrap setState: NSOffState];
  [editor findNext: nil];
  testAssert (
      NSEqualRanges ([view selectedRange], NSMakeRange (8, 3)) &&
          [[[editor valueForKey: @"_findStatus"] stringValue]
              isEqual: @"No match found."],
      @"No-wrap search preserves selection when no following match exists");
  testAssert (![document isModified] && ![project isDocumentEdited],
              @"Searching does not modify files or project");
  [replace setStringValue: @"two"];
  [editor replaceMatch: nil];
  testAssert ([[view string] hasPrefix: @"One one two"] &&
                  [document isModified],
              @"Replace edits selected match");
  [[view undoManager] undo];
  testAssert ([[view string] hasPrefix: @"One one ONE"]
                  && ![document isModified],
              @"Replace can be undone to saved text");
  [[view undoManager] redo];
  testAssert ([[view string] hasPrefix: @"One one two"],
              @"Replacement supports redo");
  [find setStringValue: @"one"];
  [caseSensitive setState: NSOffState];
  [replace setStringValue: @"oneone"];
  [wrap setState: NSOnState];
  [editor replaceAll: nil];
  testAssert (
      [[view string] isEqual: @"oneone oneone two\n[oneone] café café"],
      @"Replace All handles replacement containing the search term without looping");
  [[view undoManager] undo];
  testAssert ([[view string] isEqual: @"One one two\n[one] café café"],
              @"Replace All is one undo operation");
  [find setStringValue: @"[one]"];
  [replace setStringValue: @""];
  [editor replaceAll: nil];
  testAssert ([[view string] isEqual: @"One one two\n café café"],
              @"Search is literal and empty replacement deletes matches");
  [find setStringValue: @"café"];
  [replace setStringValue: @"茶"];
  [editor replaceAll: nil];
  testAssert ([[view string] hasSuffix: @"茶 茶"],
              @"Replace All handles Unicode text");
  NSString *before = [[view string] copy];
  [find setStringValue: @""];
  [editor replaceAll: nil];
  testAssert ([[view string] isEqual: before],
              @"Empty search never changes text");
  [before release];
  [find setStringValue: @"one"];
  [replace setStringValue: @"new"];
  [view setSelectedRange: NSMakeRange (0, 3)];
  [editor replaceAndFind: nil];
  testAssert ([[view string] hasPrefix: @"new one"]
                  && NSEqualRanges ([view selectedRange], NSMakeRange (4, 3)),
              @"Replace and Find advances to the next match");
  NSString *other = [directory stringByAppendingPathComponent: @"Other.md"];
  [@"one" writeToFile: other
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  [editor openFile: other];
  [editor replaceAll: nil];
  testAssert (
      [[[editor currentDocument] content] isEqual: @"new"] &&
          [[document content] hasPrefix: @"new one"],
      @"The panel follows the active tab without changing the previous file");
  [editor setCurrentDocument: nil];
  [editor replaceAll: nil];
  testAssert (
      ![[[editor valueForKey: @"_findButtons"] objectAtIndex: 0] isEnabled],
      @"Find controls are disabled when no text document is active");
  [project close];
  testAssert (![panel isVisible], @"Closing the project hides its find panel");
  [project release];
}

static void
testFileModificationTracking (NSString *directory)
{
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  YCodeProject *project = [YCodeProject new];
  [project makeWindowControllers];
  YCodeWindowController *controller =
      [[project windowControllers] objectAtIndex: 0];
  NSWindow *window = [controller window];
  YCodeEditorController *editor = [project editorController];
  NSUndoManager *uiUndo = [window undoManager];
  [uiUndo beginUndoGrouping];
  [[uiUndo prepareWithInvocationTarget: window] setTitle: [window title]];
  [uiUndo endUndoGrouping];
  testAssert (![project isDocumentEdited] && ![window isDocumentEdited],
              @"UI undo groups do not mark the project changed");
  [uiUndo removeAllActions];
  NSArray *names = [NSArray arrayWithObjects: @"main.m", @"README.md", nil];
  NSEnumerator *enumerator = [names objectEnumerator];
  NSString *name;
  while ((name = [enumerator nextObject]) != nil)
    {
      NSString *path = [directory stringByAppendingPathComponent: name];
      [@"original\n" writeToFile: path
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
      testAssert ([editor openFile: path], @"Open modification fixture");
      YCodeEditorDocument *file = [editor currentDocument];
      NSTextView *text = [file textView];
      NSTabViewItem *fileTab = [[editor tabView] selectedTabViewItem];
      testAssert ([[fileTab label] isEqual: name],
                  @"Unmodified file tab has no marker");
      [file applySyntaxHighlighting];
      [text didChangeText];
      [controller buildSystem: [project buildSystem]
             didReceiveOutput: @"Build output\n"];
      [controller buildSystem: nil
          didReceiveDebuggerOutput: @"Debugger output\n"];
      testAssert (
          ![file isModified] && ![window isDocumentEdited],
          @"Opening, highlighting, and output leave unchanged files clean");
      NSUndoManager *undo = [text undoManager];
      testAssert (undo != uiUndo,
                  @"File undo history is isolated from UI fields");
      [undo beginUndoGrouping];
      [text setSelectedRange: NSMakeRange (0, 0)];
      [text insertText: @"edit "];
      [undo endUndoGrouping];
      testAssert (
          [file isModified] && [window isDocumentEdited]
              && ![project isDocumentEdited],
          @"Source and supporting file edits mark the window without dirtying project metadata");
      testAssert (
          [[fileTab label] isEqual: [@"* " stringByAppendingString: name]],
          @"Modified file tab prefixes its name with an asterisk");
      [undo undo];
      testAssert (![file isModified] && ![window isDocumentEdited],
                  @"Undoing to saved text clears the edited indicator");
      testAssert ([[fileTab label] isEqual: name],
                  @"Undo to saved content clears the tab marker");
      [undo redo];
      testAssert ([file isModified] && [window isDocumentEdited],
                  @"Redo marks the file changed again");
      testAssert ([[fileTab label] hasPrefix: @"* "],
                  @"Redo restores the tab marker");
      testAssert ([file saveToFile] && ![file isModified]
                      && ![window isDocumentEdited],
                  @"Saving clears file and window modification state");
      testAssert ([[fileTab label] isEqual: name],
                  @"Saving clears the tab marker");
      [text didChangeText];
      testAssert (![file isModified], @"Saving updates the text baseline");
      [file setContent: @"replacement\n"];
      [file setModified: YES];
      testAssert ([file isModified],
                  @"Replacing content does not replace the saved baseline");
      [file saveToFile];
      [editor closeFile: path];
    }
  [project close];
  [project release];
}

static void
testTranscriptCopy (void)
{
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps: YES];
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSMutableDictionary *saved = [NSMutableDictionary dictionary];
  NSEnumerator *types = [[pasteboard types] objectEnumerator];
  NSString *type;
  while ((type = [types nextObject]) != nil)
    {
      NSData *data = [pasteboard dataForType: type];
      if (data)
        [saved setObject: data forKey: type];
    }
  YCodeWindowController *controller = [YCodeWindowController new];
  [controller setBottomPanelVisible: YES];
  [controller showWindow: nil];
  [[controller window] makeKeyAndOrderFront: nil];
  NSArray *keys = [NSArray
      arrayWithObjects: @"_consoleTextView", @"_debuggerTextView", nil];
  NSArray *tabs = [NSArray arrayWithObjects: @"console", @"debugger", nil];
  NSUInteger i;
  for (i = 0; i < [keys count]; i++)
    {
      [[controller valueForKey: @"_bottomTabView"]
          selectTabViewItemWithIdentifier: [tabs objectAtIndex: i]];
      NSTextView *view = [controller valueForKey: [keys objectAtIndex: i]];
      [view setString: @"Copy this output\nsecond line\n"];
      testAssert (![view isEditable] && [view isSelectable],
                  @"Both output panes are selectable but read-only");
      [[controller window] makeFirstResponder: view];
      [view setSelectedRange: NSMakeRange (0, 4)];
      [NSApp sendAction: @selector (copy:) to: nil from: nil];
      testAssert (
          [[pasteboard stringForType: NSStringPboardType] isEqual: @"Copy"],
          @"Edit Copy routes to the selected output pane");
      [view setSelectedRange: NSMakeRange (5, 4)];
      [[view menu] update];
      [[view menu] performActionForItemAtIndex: 0];
      testAssert (
          [[pasteboard stringForType: NSStringPboardType] isEqual: @"this"],
          @"Output context menu copies the selected text");
      NSEvent *select =
          [NSEvent keyEventWithType: NSKeyDown
                                 location: NSZeroPoint
                            modifierFlags: NSControlKeyMask
                                timestamp: 0
                             windowNumber: [[controller window] windowNumber]
                                  context: nil
                               characters: @"a"
              charactersIgnoringModifiers: @"a"
                                isARepeat: NO
                                  keyCode: 0];
      [view keyDown: select];
      NSEvent *copy =
          [NSEvent keyEventWithType: NSKeyDown
                                 location: NSZeroPoint
                            modifierFlags: NSControlKeyMask
                                timestamp: 0
                             windowNumber: [[controller window] windowNumber]
                                  context: nil
                               characters: @"c"
              charactersIgnoringModifiers: @"c"
                                isARepeat: NO
                                  keyCode: 0];
      [view keyDown: copy];
      testAssert (
          [[pasteboard stringForType: NSStringPboardType]
              isEqual: [view string]],
          @"Ctrl+A and Ctrl+C copy the complete transcript without editing it");
    }
  [controller close];
  [controller release];
  [pasteboard declareTypes: [saved allKeys] owner: nil];
  types = [saved keyEnumerator];
  while ((type = [types nextObject]) != nil)
    [pasteboard setData: [saved objectForKey: type] forType: type];
}

static void
testBreakpointFileTypes (void)
{
  YCodeProject *project = [YCodeProject new];
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: project];
  YCodeDebugger *debugger = [[project buildSystem] debugger];
  [debugger receiveData: [@"(gdb)\n*running,thread-id=\"all\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  NSArray *files = [NSArray
      arrayWithObjects: @"Example.m", @"Example.mm", @"Example.cpp",
                       @"Example.h", @"Example.hpp", @"Example.hxx",
                       @"Info.plist", @"README.md", @"GNUmakefile", nil];
  NSUInteger index;
  for (index = 0; index < [files count]; index++)
    {
      NSString *file = [@"/tmp/YcodeBreakpointTypes"
          stringByAppendingPathComponent: [files objectAtIndex: index]];
      BOOL allowed = index < 3;
      YCodeEditorDocument *document =
          [[YCodeEditorDocument alloc] initWithFilePath: file
                                                content: @"first line\n"];
      [[project editorController] setCurrentDocument: document];
      [[document textView] setSelectedRange: NSMakeRange (0, 0)];
      testAssert (
          [window validateDebuggerAction: @selector (toggleBreakpoint:) tag: 0]
              == allowed,
          [NSString
              stringWithFormat: @"Breakpoint menu eligibility for %@", file]);
      [window toggleBreakpoint: nil];
      testAssert (
          [debugger breakpointStateAtFile: file line: 1]
              == (allowed ? YCodeBreakpointEnabled : YCodeBreakpointNone),
          @"Breakpoint menu action rejects headers and non-source files");
      [debugger toggleBreakpointAtFile: file line: 2];
      testAssert (
          [debugger breakpointStateAtFile: file line: 2]
              == (allowed ? YCodeBreakpointEnabled : YCodeBreakpointNone),
          @"Debugger also enforces source-only breakpoint creation");
      YCEditorRulerView *ruler
          = (YCEditorRulerView *)[[document scrollView] verticalRulerView];
      [ruler setDebugger: debugger file: file active: YES];
      testAssert (
          [ruler debugGutterVisible] == allowed,
          @"Breakpoint gutter is hidden for headers and non-source files even during debugging");
      [[project editorController] setCurrentDocument: nil];
      [document release];
    }
  NSString *storage = [[NSProcessInfo processInfo] globallyUniqueString];
  [[NSUserDefaults standardUserDefaults]
      setObject: [NSArray arrayWithObjects: @"/tmp/Example.m:1",
                                          @"/tmp/Example.h:1",
                                          @"/tmp/Info.plist:1", nil]
         forKey: storage];
  [debugger setBreakpointStorageKey: storage];
  testAssert (
      [debugger breakpointStateAtFile: @"/tmp/Example.m" line: 1]
              == YCodeBreakpointEnabled
          && [debugger breakpointStateAtFile: @"/tmp/Example.h" line: 1]
                 == YCodeBreakpointNone
          && [debugger breakpointStateAtFile: @"/tmp/Info.plist" line: 1]
                 == YCodeBreakpointNone,
      @"Restoring saved breakpoints skips headers and non-source files");
  [debugger setBreakpointStorageKey: nil];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: storage];
  [window setProject: nil];
  [window close];
  [window release];
  [project release];
}

static void
testHiddenRulersDebugGutter (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeHideEditorRulers"] retain];
  [defaults setBool: YES forKey: @"YCodeHideEditorRulers"];
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
      initWithFilePath: @"Gutter.m"
               content: @"first line\nsecond line\n"];
  NSScrollView *scroll = [document scrollView];
  YCEditorRulerView *ruler = (YCEditorRulerView *)[scroll verticalRulerView];
  testAssert (![scroll rulersVisible],
              @"Hidden rulers stay hidden outside debugging");
  [ruler setDebugger: nil file: @"Gutter.m" active: YES];
  testAssert (
      [scroll rulersVisible] && [scroll hasVerticalRuler]
          && ![scroll hasHorizontalRuler] && [ruler debugGutterVisible] &&
          [ruler ruleThickness] == 22,
      @"Debugging shows a breakpoint-only gutter while line and column rulers remain hidden");
  [defaults setBool: NO forKey: @"YCodeHideEditorRulers"];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeEditorRulersDidChange"
                    object: nil];
  testAssert (
      [scroll hasHorizontalRuler] && [ruler ruleThickness] == 72,
      @"Enabling rulers adds line numbers alongside the debugger gutter");
  [defaults setBool: YES forKey: @"YCodeHideEditorRulers"];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeEditorRulersDidChange"
                    object: nil];
  testAssert ([scroll rulersVisible] && ![scroll hasHorizontalRuler] &&
                  [ruler ruleThickness] == 22,
              @"Turning rulers off during debugging preserves the gutter");
  [ruler setDebugger: nil file: @"Gutter.m" active: NO];
  testAssert (![scroll rulersVisible],
              @"Stopping debugging restores the hidden-ruler layout");
  [document release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeHideEditorRulers"];
  else
    [defaults removeObjectForKey: @"YCodeHideEditorRulers"];
  [saved release];
  [defaults synchronize];
}

static void
testEditorColors (void)
{
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: @"Example.c"
                                            content: @"int ordinary = 42;"];
  NSTextView *view = [document textView];
  YCodeSyntaxHighlighter *highlighter = [document syntaxHighlighter];
  NSArray *backgrounds =
      [NSArray arrayWithObjects: [NSColor whiteColor], [NSColor blackColor],
                                [NSColor colorWithDeviceRed: 0.2
                                                      green: 0.4
                                                       blue: 0.7
                                                      alpha: 1.0],
                                nil];
  NSUInteger index;
  for (index = 0; index < [backgrounds count]; index++)
    {
      NSColor *background = [[backgrounds objectAtIndex: index]
          colorUsingColorSpaceName: NSDeviceRGBColorSpace];
      CGFloat red = 1.0 - [background redComponent];
      CGFloat green = 1.0 - [background greenComponent];
      CGFloat blue = 1.0 - [background blueComponent];
      [view setBackgroundColor: background];
      [document applySyntaxHighlighting];
      testAssert (
          colorMatches ([[view textStorage]
                                 attribute: NSForegroundColorAttributeName
                                   atIndex: 4
                            effectiveRange: NULL],
                        red, green, blue),
          @"Ordinary text inverts background RGB");
      testAssert ([[[view textStorage] attribute: NSForegroundColorAttributeName
                                         atIndex: 15
                                  effectiveRange: NULL]
                      isEqual: [highlighter numberColor]],
                  @"Keep number color");
      testAssert (
          colorMatches ([[view typingAttributes]
                            objectForKey: NSForegroundColorAttributeName],
                        red, green, blue),
          @"New text uses inverse background");
      [highlighter removeHighlighting];
      testAssert (
          colorMatches ([[view textStorage]
                                 attribute: NSForegroundColorAttributeName
                                   atIndex: 0
                            effectiveRange: NULL],
                        red, green, blue),
          @"Removing syntax keeps inverse foreground");
    }
  [document release];
  YCEditorView *editor =
      [[YCEditorView alloc] initWithFrame: NSMakeRect (0, 0, 400, 300)];
  [editor setText: @"plain text"];
  [editor setBackgroundColor: [NSColor blackColor]];
  testAssert (
      colorMatches ([[editor textView] textColor], 1, 1, 1),
      @"Editor without a highlighter refreshes foreground when background changes");
  [editor release];
}

static void
assertSyntaxColor (YCodeEditorDocument *document, NSString *token,
                   NSColor *expected, NSString *message)
{
  NSRange range = [[document content] rangeOfString: token];
  BOOL matches = range.location != NSNotFound;
  if (matches)
    {
      NSUInteger index;
      for (index = range.location; index < NSMaxRange (range); index++)
        if (![[[[document textView] textStorage]
                     attribute: NSForegroundColorAttributeName
                       atIndex: index
                effectiveRange: NULL] isEqual: expected])
          {
            matches = NO;
            break;
          }
    }
  testAssert (matches, message);
}

static void
testSyntaxHighlighting (void)
{
  NSString *source
      = @"@interface Example : NSObject\n@property(copy) NSString *title;\n@end\n"
        @"BOOL ready = YES; int returnValue = 0xFF; double fraction = .5e-2;\n"
        @"[self setTitle:@\"https://example/* return 123 */\"]; NSLog(@\"hi\"); [items count];\n"
        @"// return 42 \"quoted\"\n/* if 9\n NSString *text = @\"comment\"; */\n"
        @"if (ready) return _value;\n";
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: @"Example.m"
                                            content: source];
  YCodeSyntaxHighlighter *highlighter = [document syntaxHighlighter];
  assertSyntaxColor (document, @"@interface", [highlighter keywordColor],
                     @"Objective-C @keywords are highlighted");
  assertSyntaxColor (document, @"NSString", [highlighter typeColor],
                     @"Foundation types are highlighted");
  assertSyntaxColor (document, @"Example", [highlighter typeColor],
                     @"Custom class names are highlighted");
  assertSyntaxColor (document, @"BOOL", [highlighter typeColor],
                     @"Known types take precedence over constant heuristics");
  assertSyntaxColor (document, @"setTitle", [highlighter symbolColor],
                     @"Objective-C selectors are highlighted");
  assertSyntaxColor (document, @"count", [highlighter symbolColor],
                     @"Unary Objective-C messages are highlighted");
  assertSyntaxColor (document, @"NSLog", [highlighter symbolColor],
                     @"Function calls are highlighted");
  assertSyntaxColor (document, @"_value", [highlighter symbolColor],
                     @"Instance variables are highlighted");
  assertSyntaxColor (document, @"0xFF", [highlighter numberColor],
                     @"Hexadecimal literals are highlighted");
  assertSyntaxColor (document, @".5e-2", [highlighter numberColor],
                     @"Fractional exponent literals are highlighted");
  assertSyntaxColor (
      document, @"@\"https://example/* return 123 */\"",
      [highlighter stringColor],
      @"Comment markers, keywords and numbers inside strings stay string-colored");
  assertSyntaxColor (
      document, @"// return 42 \"quoted\"", [highlighter commentColor],
      @"Keywords, numbers and quotes inside comments stay comment-colored");
  NSString *block = @"/* if 9\n NSString *text = @\"comment\"; */";
  assertSyntaxColor (document, block, [highlighter commentColor],
                     @"Multiline comments retain one color");
  NSColor *plain = [YCodeSyntaxHighlighter
      plainTextColorForBackground: [[document textView] backgroundColor]];
  assertSyntaxColor (document, @"returnValue", plain,
                     @"Keywords do not match inside identifiers");
  NSRange partial = [source rangeOfString: @"text ="];
  [[[document textView] textStorage]
      addAttribute: NSForegroundColorAttributeName
             value: plain
             range: partial];
  [highlighter highlightRange: partial];
  assertSyntaxColor (document, block, [highlighter commentColor],
                     @"Partial repaint retains multiline lexical context");
  [[document textView] setSelectedRange: NSMakeRange (5, 3)];
  NSFont *font = [[document textView] font];
  [document setModified: NO];
  [document applySyntaxHighlighting];
  testAssert (
      NSEqualRanges ([[document textView] selectedRange], NSMakeRange (5, 3))
          && [[[document textView] font] isEqual: font] &&
          [[document content] isEqual: source] && ![document isModified],
      @"Highlighting preserves content, selection, font and modified state");
  [document setFilePath: @"Example.txt"];
  assertSyntaxColor (
      document, source, plain,
      @"Renaming to plain text clears all syntax colors immediately");
  [document setFilePath: @"Example.m"];
  [document setContent: @"/* unfinished\nreturn 123"];
  highlighter = [document syntaxHighlighter];
  assertSyntaxColor (document, [document content], [highlighter commentColor],
                     @"Unterminated comments extend through EOF");
  [document setContent: @"return 123"];
  assertSyntaxColor (document, @"return", [highlighter keywordColor],
                     @"Removing a comment opener recolors the following code");
  [document release];

  // Exercise filename detection and the less frequently opened source/configuration formats.
  NSArray *cases = [NSArray
      arrayWithObjects:
          [NSArray arrayWithObjects: @"Example.java",
                                    @"public class Example {}", @"public",
                                    @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.java",
                                    @"@Override void work() {}", @"@Override",
                                    @"preprocessorColor", nil],
          [NSArray
              arrayWithObjects: @"Example.java",
                               @"String text = \"\"\"\n// class {}\n\"\"\";",
                               @"\"\"\"\n// class {}\n\"\"\"", @"stringColor",
                               nil],
          [NSArray arrayWithObjects: @"Example.rb", @"class Example\nend",
                                    @"class", @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.rb", @"value = :example",
                                    @":example", @"symbolColor", nil],
          [NSArray arrayWithObjects: @"Example.rb", @"# class Example {}",
                                    @"# class Example {}", @"commentColor",
                                    nil],
          [NSArray arrayWithObjects: @"Example.rb", @"value = \"# end {\"",
                                    @"\"# end {\"", @"stringColor", nil],
          [NSArray arrayWithObjects: @"Rakefile",
                                    @"=begin\nclass Hidden {}\n=end",
                                    @"=begin\nclass Hidden {}\n=end",
                                    @"commentColor", nil],
          [NSArray arrayWithObjects: @"Example.swift", @"let value: Int = 42",
                                    @"let", @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.hpp",
                                    @"constexpr int count = 1;", @"constexpr",
                                    @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.C", @"namespace demo {}",
                                    @"namespace", @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.mm", @"nullptr", @"nullptr",
                                    @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.tsx",
                                    @"async function work() {}", @"async",
                                    @"keywordColor", nil],
          [NSArray arrayWithObjects: @"Example.js",
                                    @"const value = `// return\n42`;",
                                    @"`// return\n42`", @"stringColor", nil],
          [NSArray arrayWithObjects: @"Example.py", @"value = '''# if\n42'''",
                                    @"'''# if\n42'''", @"stringColor", nil],
          [NSArray arrayWithObjects: @"Example.py", @"async def work(): pass",
                                    @"async", @"keywordColor", nil],
          [NSArray
              arrayWithObjects: @"GNUmakefile",
                               @"include $(GNUSTEP_MAKEFILES)/common.make",
                               @"include", @"keywordColor", nil],
          [NSArray
              arrayWithObjects: @"GNUmakefile",
                               @"include $(GNUSTEP_MAKEFILES)/common.make",
                               @"$(GNUSTEP_MAKEFILES)", @"constantColor", nil],
          [NSArray arrayWithObjects: @"GNUmakefile.postamble",
                                    @"after-all:\n\techo done",
                                    @"after-all:", @"typeColor", nil],
          [NSArray arrayWithObjects: @"Makefile", @"SOURCES += main.m",
                                    @"SOURCES", @"symbolColor", nil],
          [NSArray arrayWithObjects: @"CMakeLists.txt",
                                    @"add_executable(example main.c)",
                                    @"add_executable", @"keywordColor", nil],
          [NSArray arrayWithObjects: @"build.sh",
                                    @"if test $value; then echo yes; fi",
                                    @"$value", @"constantColor", nil],
          [NSArray arrayWithObjects: @"build.sh", @"# if $value 42",
                                    @"# if $value 42", @"commentColor", nil],
          [NSArray arrayWithObjects:
                       @"config.json",
                       @"{\"name\": \"https://example\", \"ok\": true}",
                       @"\"name\"", @"symbolColor", nil],
          [NSArray arrayWithObjects: @"config.json",
                                    @"{\"name\": \"https://example\"}",
                                    @"\"https://example\"", @"stringColor",
                                    nil],
          [NSArray arrayWithObjects: @"project.pbxproj",
                                    @"{ isa = PBXProject; /* 123 */ }", @"isa",
                                    @"symbolColor", nil],
          [NSArray arrayWithObjects: @"PC.project",
                                    @"{ \"name\" = \"Example\"; }",
                                    @"\"name\"", @"symbolColor", nil],
          [NSArray arrayWithObjects: @"Info.plist",
                                    @"<plist version=\"1.0\"><true/></plist>",
                                    @"<plist", @"typeColor", nil],
          [NSArray arrayWithObjects: @"Window.xib", @"<object id=\"42\"/>",
                                    @"id", @"symbolColor", nil],
          [NSArray arrayWithObjects: @"Window.xml", @"<!-- if \"text\" 42 -->",
                                    @"<!-- if \"text\" 42 -->",
                                    @"commentColor", nil],
          [NSArray arrayWithObjects: @"Example.c", @"#define FLAG 1\n",
                                    @"#define", @"preprocessorColor", nil],
          [NSArray arrayWithObjects: @"Example.c", @"int flags = SOME_FLAG;",
                                    @"SOME_FLAG", @"constantColor", nil],
          nil];
  {
    NSEnumerator *exampleEnumerator = [cases objectEnumerator];
    NSArray *example;
    while ((example = [exampleEnumerator nextObject]) != nil)
      {
        document = [[YCodeEditorDocument alloc]
            initWithFilePath: [example objectAtIndex: 0]
                     content: [example objectAtIndex: 1]];
        highlighter = [document syntaxHighlighter];
        NSColor *color = [highlighter
            performSelector: NSSelectorFromString ([example objectAtIndex: 3])];
        assertSyntaxColor (
            document, [example objectAtIndex: 2], color,
            [NSString stringWithFormat: @"%@ highlights %@",
                                       [example objectAtIndex: 0],
                                       [example objectAtIndex: 2]]);
        [document release];
      }
  }
}

/* Count automatic requests without entering the native popup's modal loop. */
@interface YCodeCompletionProbe : YCodeTextView
{
@public
  NSUInteger completionRequests;
}

@end

@implementation YCodeCompletionProbe
- (void) complete: (id)sender
{
  completionRequests++;
}

@end

static void
testAutomaticCompletion (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeDisableWordCompletion"] retain];
  [YCodePreferences setWordCompletionEnabled: YES];
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 400, 300)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [window setReleasedWhenClosed: NO];
  YCodeCompletionProbe *view =
      [[YCodeCompletionProbe alloc] initWithFrame: NSMakeRect (0, 0, 400, 300)];
  [view setFilePath: @"/tmp/Automatic.m"];
  [window setContentView: view];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: view];
  [view insertText: @"r"];
  [view insertText: @"e"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 0,
              @"Two characters do not trigger automatic completion");
  [view insertText: @"t"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.15]];
  testAssert (view->completionRequests == 0,
              @"Completion waits for a typing pause");
  [view insertText: @"u"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]];
  testAssert (view->completionRequests == 0,
              @"Continued typing restarts the completion delay");
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
  testAssert (view->completionRequests == 1,
              @"A pause opens completion once for the latest prefix");
  [view insertText: @"r"];
  [view setSelectedRange: NSMakeRange (0, 0)];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 1,
              @"Moving the caret cancels pending completion");
  [view setString: @"re"];
  [view setSelectedRange: NSMakeRange (2, 0)];
  [view insertText: @"t"];
  [YCodePreferences setWordCompletionEnabled: NO];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 1,
              @"Disabling completion suppresses a pending popup");
  [YCodePreferences setWordCompletionEnabled: YES];
  [view setString: @"re"];
  [view setSelectedRange: NSMakeRange (2, 0)];
  [view insertText: @"t"];
  [window makeFirstResponder: nil];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 1,
              @"Leaving the editor cancels pending completion");
  [window makeFirstResponder: view];
  [view setString: @""];
  [view insertText: @"ret"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 1,
              @"Inserting multiple characters does not trigger completion");
  [view setString: @"zzzz"];
  [view setSelectedRange: NSMakeRange (4, 0)];
  [view insertText: @"z"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.45]];
  testAssert (view->completionRequests == 1,
              @"No popup is requested when there are no matches");
  [window close];
  [view release];
  [window release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeDisableWordCompletion"];
  else
    [defaults removeObjectForKey: @"YCodeDisableWordCompletion"];
  [defaults synchronize];
  [saved release];
}

static void
testWordCompletion (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeDisableWordCompletion"] retain];
  [defaults removeObjectForKey: @"YCodeDisableWordCompletion"];
  testAssert ([YCodePreferences wordCompletionEnabled],
              @"Word completion defaults to enabled");
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
      initWithFilePath: @"/tmp/Completion.m"
               content: @"returnValue returnValue ReturnOther; call(ret"];
  YCodeTextView *view = (YCodeTextView *)[document textView];
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 400, 300)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [window setReleasedWhenClosed: NO];
  [window setContentView: [document editorView]];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: view];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  NSRange range = [view rangeForUserCompletion];
  NSInteger index = -1;
  NSArray *words = [view completionsForPartialWordRange: range
                                    indexOfSelectedItem: &index];
  testAssert (
      range.length == 3 && index == 0 &&
          [words isEqual: [NSArray arrayWithObjects: @"retain", @"return",
                                                   @"returnValue", nil]],
      @"Completion merges keywords and unsaved identifiers, sorted and deduplicated, with case-sensitive matching");
  [YCodePreferences setWordCompletionEnabled: NO];
  testAssert ([view rangeForUserCompletion].location == NSNotFound &&
                  [[view completionsForPartialWordRange: range
                                    indexOfSelectedItem: NULL] count]
                      == 0,
              @"Disabling completion takes effect in existing editors");
  [view complete: nil];
  [YCodePreferences setWordCompletionEnabled: YES];
  [document setContent: @"[@int"];
  [view setSelectedRange: NSMakeRange (5, 0)];
  range = [view rangeForUserCompletion];
  testAssert (NSEqualRanges (range, NSMakeRange (1, 4)) &&
                  [[view completionsForPartialWordRange: range
                                    indexOfSelectedItem: NULL]
                      containsObject: @"@interface"],
              @"Objective-C directives include their at sign");
  [view setSelectedRange: NSMakeRange (3, 0)];
  testAssert (
      [view rangeForUserCompletion].location == NSNotFound,
      @"Completion avoids duplicating a suffix in the middle of an identifier");
  [view setSelectedRange: NSMakeRange (1, 4)];
  testAssert ([view rangeForUserCompletion].location == NSNotFound,
              @"Completion leaves selected text alone");
  [view setFilePath: @"/tmp/Completion.py"];
  [document setContent: @"lam"];
  [view setSelectedRange: NSMakeRange (3, 0)];
  testAssert (
      [[view completionsForPartialWordRange: [view rangeForUserCompletion]
                        indexOfSelectedItem: NULL] containsObject: @"lambda"],
      @"Completion follows the active language bundle");
  [view setFilePath: @"/tmp/Completion.unknown"];
  [document setContent: @"localWord localWord loc"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  testAssert (
      [[view completionsForPartialWordRange: [view rangeForUserCompletion]
                        indexOfSelectedItem: NULL]
          isEqual: [NSArray arrayWithObject: @"localWord"]],
      @"Unknown languages still complete words from the current file");
  testAssert ([[view completionsForPartialWordRange: NSMakeRange (NSNotFound, 0)
                                indexOfSelectedItem: NULL] count]
                  == 0,
              @"Invalid completion ranges are harmless");
#ifdef GNUSTEP
  [view setFilePath: @"/tmp/Completion.m"];
  [document setContent: @"ret"];
  [document setModified: NO];
  [view setSelectedRange: NSMakeRange (3, 0)];
  range = [view rangeForUserCompletion];
  NSUndoManager *undo = [view undoManager];
  [undo removeAllActions];
  [view insertCompletion: @"return"
      forPartialWordRange: range
                 movement: NSDownTextMovement
                  isFinal: NO];
  [view insertCompletion: @"ret"
      forPartialWordRange: range
                 movement: NSCancelTextMovement
                  isFinal: NO];
  testAssert (
      [[view string] isEqual: @"ret"] && ![document isModified]
          && ![undo canUndo],
      @"Browsing and cancelling completion preserves text and undo history");
  [undo beginUndoGrouping];
  [view insertCompletion: @"return"
      forPartialWordRange: range
                 movement: NSOtherTextMovement
                  isFinal: YES];
  [undo endUndoGrouping];
  testAssert ([[view string] isEqual: @"return"] && [document isModified],
              @"Accepting completion edits and marks the document modified");
  [undo undo];
  testAssert ([[view string] isEqual: @"ret"],
              @"Completion is undone in one step");
  [undo redo];
  testAssert ([[view string] isEqual: @"return"], @"Completion supports redo");
  /* Exercise the actual suggestion window and its Return acceptance path. */
  [document setContent: @"ret"];
  [view setSelectedRange: NSMakeRange (3, 0)];
  [NSApp postEvent: [NSEvent keyEventWithType: NSKeyDown
                                          location: NSZeroPoint
                                     modifierFlags: 0
                                         timestamp: 0
                                      windowNumber: [window windowNumber]
                                           context: nil
                                        characters: @"\r"
                       charactersIgnoringModifiers: @"\r"
                                         isARepeat: NO
                                           keyCode: 0]
           atStart: YES];
  [view complete: nil];
  testAssert (
      [[view string] isEqual: @"retain"],
      @"The native suggestion list accepts its selected keyword with Return");
#endif
  AppController *app = [[AppController alloc] init];
  [app showPrefPanel: nil];
  NSButton *checkbox = [app valueForKey: @"_wordCompletionCheckbox"];
  testAssert ([checkbox state] == NSOnState,
              @"Editor preference displays enabled completion");
  [checkbox performClick: nil];
  testAssert (![YCodePreferences wordCompletionEnabled],
              @"Editor checkbox disables completion");
  [checkbox performClick: nil];
  testAssert ([YCodePreferences wordCompletionEnabled],
              @"Editor checkbox re-enables completion");
  [[app valueForKey: @"_preferencesPanel"] orderOut: nil];
  [app release];
  [document setModified: NO];
  [window close];
  [window release];
  [document release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeDisableWordCompletion"];
  else
    [defaults removeObjectForKey: @"YCodeDisableWordCompletion"];
  [defaults synchronize];
  [saved release];
}

static void
testEditorEditing (NSString *directory)
{
  id savedControlWidth = [[[NSUserDefaults standardUserDefaults]
      objectForKey: @"YCodeControlIndentWidth"] retain];
  [YCodePreferences setControlIndentWidth: 2];
  NSString *root = [directory stringByAppendingPathComponent: @"Editing Rules"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: root
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
      initWithFilePath: [root stringByAppendingPathComponent: @"Example.m"]
               content: @""];
  YCodeTextView *view = (YCodeTextView *)[document textView];
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect: NSMakeRect (0, 0, 400, 300)
                styleMask: NSTitledWindowMask | NSResizableWindowMask
                  backing: NSBackingStoreBuffered
                    defer: NO];
  [window setReleasedWhenClosed: NO];
  [window setContentView: [document editorView]];
  [window makeKeyAndOrderFront: nil];
  [window makeFirstResponder: view];
  testAssert ([view isKindOfClass: [YCodeTextView class]],
              @"Documents use ProjectCenter editing rules");
  testAssert ([view editorIndentWidth] == 2 && [view editorTabWidth] == 2
                  && ![view editorUsesTabs],
              @"Default to ProjectCenter's two-space indentation");
  [view insertTab: nil];
  testAssert ([[view string] isEqual: @"  "],
              @"Tab in an empty document inserts one tab stop");

  [document setContent: @"if (ready)"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert ([[view string] isEqual: @"if (ready)\n  "],
              @"Return indents control statement bodies");
  [view insertText: @"{"];
  [view insertNewline: nil];
  testAssert ([[view string] isEqual: @"if (ready)\n  {\n    "],
              @"Return indents inside an opening delimiter");
  [view insertText: @"}"];
  testAssert ([[view string] isEqual: @"if (ready)\n  {\n  }"],
              @"Closing delimiter aligns with its opening line");
  NSArray *newlineCases = [NSArray
      arrayWithObjects:
          [NSArray arrayWithObjects: @"  }", @"", nil],
          [NSArray arrayWithObjects: @"    }", @"  ", nil],
          [NSArray arrayWithObjects: @"}", @"", nil],
          [NSArray arrayWithObjects: @"  }   // finished", @"", nil],
          [NSArray arrayWithObjects: @"  };", @"", nil],
          [NSArray arrayWithObjects: @"{\n  {\n  }", @"", nil],
          [NSArray arrayWithObjects: @"if (ready) {}", @"", nil],
          [NSArray arrayWithObjects: @"while (ready) { work(); }", @"", nil],
          [NSArray arrayWithObjects: @"if (ready) work();", @"", nil],
          [NSArray arrayWithObjects: @"if (ready);", @"", nil],
          [NSArray arrayWithObjects: @"call(", @"", nil],
          [NSArray arrayWithObjects: @"[object call:", @"", nil],
          [NSArray arrayWithObjects: @"// {", @"", nil],
          [NSArray arrayWithObjects: @"/* { */", @"", nil],
          [NSArray arrayWithObjects: @"NSString *s = @\"{\";", @"", nil],
          [NSArray arrayWithObjects: @"{   ", @"  ", nil],
          [NSArray arrayWithObjects: @"{ // body", @"  ", nil],
          [NSArray arrayWithObjects: @"if (ready) // body", @"  ", nil],
          [NSArray arrayWithObjects: @"while (ready)", @"  ", nil],
          [NSArray arrayWithObjects: @"if (ready &&\n    other)", @"  ", nil],
          [NSArray arrayWithObjects: @"  while (ready &&\n         other)",
                                    @"    ", nil],
          [NSArray arrayWithObjects: @"for (i = 0; i < 3; i++)", @"  ", nil],
          [NSArray arrayWithObjects: @"else if (ready)", @"  ", nil],
          [NSArray arrayWithObjects: @"else", @"  ", nil],
          [NSArray arrayWithObjects: @"{\n  if (ready) {}", @"  ", nil],
          [NSArray
              arrayWithObjects: @"{\n  if (ready)\n    work();", @"  ", nil],
          [NSArray
              arrayWithObjects: @"{\n  if (ready)\n    {\n    }", @"  ", nil],
          [NSArray arrayWithObjects: @"{\n  // {\n  work();", @"  ", nil], nil];
  NSEnumerator *newlineEnumerator = [newlineCases objectEnumerator];
  NSArray *newlineCase;
  while ((newlineCase = [newlineEnumerator nextObject]) != nil)
    {
      NSString *input = [newlineCase objectAtIndex: 0];
      [document setContent: input];
      [view setSelectedRange: NSMakeRange ([input length], 0)];
      [view insertNewline: nil];
      testAssert (
          [[view string]
              isEqual: [NSString
                          stringWithFormat: @"%@\n%@", input,
                                           [newlineCase objectAtIndex: 1]]],
          [NSString stringWithFormat: @"Return indentation after %@", input]);
    }
  [document setContent: @"if (ready)\nwork();"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertTab: nil];
  testAssert (
      [[view string] isEqual: @"if (ready)\n  work();"],
      @"Tab reindentation agrees with Return for control statement bodies");
  [document setContent: @"{\n      value;\n}"];
  [view setSelectedRange: NSMakeRange (8, 0)];
  [view insertTab: nil];
  testAssert ([[view string] isEqual: @"{\n  value;\n}"],
              @"Tab reindents the current line");
  [document setContent: @"{\n"];
  [view setSelectedRange: NSMakeRange (2, 0)];
  [view insertTab: nil];
  testAssert ([[view string] isEqual: @"{\n  "],
              @"Tab handles the empty line at end of file");

  [document setContent: @"one\ntwo\nthree\n"];
  [document setModified: NO];
  [view setSelectedRange: NSMakeRange (0, 8)];
  NSUndoManager *undo = [view undoManager];
  [undo removeAllActions];
  [undo beginUndoGrouping];
  [view insertTab: nil];
  [undo endUndoGrouping];
  testAssert (
      [[view string] isEqual: @"  one\n  two\nthree\n"],
      @"Tab shifts selected lines without touching the following line");
  testAssert ([document isModified],
              @"Block indentation marks the document modified");
  [undo undo];
  testAssert ([[view string] isEqual: @"one\ntwo\nthree\n"],
              @"Block indentation is undoable");
  [view setSelectedRange: NSMakeRange (0, 8)];
  [view insertTab: nil];
  [view insertBacktab: nil];
  testAssert ([[view string] isEqual: @"one\ntwo\nthree\n"],
              @"Shift-Tab reverses block indentation");
  [view setSelectedRange: NSMakeRange (1, 0)];
  [view moveDownAndModifySelection: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (1, 4)),
              @"Shift-Down preserves the column and selection anchor");
  [view moveUpAndModifySelection: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (1, 0)),
              @"Reversing Shift-arrow contracts the selection");
  [view moveLeftAndModifySelection: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (0, 1)),
              @"Shift-Left extends backwards");
  [view moveRightAndModifySelection: nil];
  testAssert (NSEqualRanges ([view selectedRange], NSMakeRange (1, 0)),
              @"Shift-Right contracts a backward selection");
  [document setContent: @"last\n"];
  [view setSelectedRange: NSMakeRange (2, 0)];
  [view moveDownAndModifySelection: nil];
  testAssert (NSMaxRange ([view selectedRange]) == 5,
              @"Shift-Down can reach a trailing empty line");

  NSString *config = [root stringByAppendingPathComponent: @".clang-format"];
  [@"IndentWidth: 4\nTabWidth: 8\nUseTab: Never\n"
      writeToFile: config
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [document
      setFilePath: [root stringByAppendingPathComponent: @"Nested/Other.m"]];
  testAssert (
      [view editorIndentWidth] == 4 && [view editorTabWidth] == 8
          && ![view editorUsesTabs],
      @"Read indentation settings from the nearest parent .clang-format");
  [document setContent: @"\tvalue;\n  \tother;\n"];
  [view setSelectedRange: NSMakeRange (0, [[view string] length])];
  [view insertBacktab: nil];
  testAssert (
      [[view string] isEqual: @"    value;\n    other;\n"],
      @"Unindent removes one indentation level from mixed whitespace using visual columns");
  [view insertTab: nil];
  testAssert (
      [[view string] isEqual: @"        value;\n        other;\n"],
      @"Block indentation consistently emits the configured whitespace style");
  [view setSelectedRange: NSMakeRange (10, 0)];
  [view insertBacktab: nil];
  testAssert (
      [[view string] hasPrefix: @"    value;"] &&
          [view selectedRange].location == 6,
      @"Shift-Tab without a selection unindents the current line and preserves the text position");
  NSString *tabbed = @"\tvalue\tend\r\n  \tlast\t";
  [document setContent: tabbed];
  [document setModified: NO];
  [view setSelectedRange: NSMakeRange (1, 5)];
  [undo removeAllActions];
  [view convertTabsToSpaces: nil];
  testAssert (
      [[view string] isEqual: @"        value   end\r\n        last    "]
          && NSEqualRanges ([view selectedRange], NSMakeRange (8, 5)) &&
          [document isModified],
      @"File conversion expands all tabs to visual stops, preserving CRLF and selection");
  [undo undo];
  testAssert ([[view string] isEqual: tabbed] && ![document isModified],
              @"Tab conversion is one undoable edit");
  [undo redo];
  [document setModified: NO];
  [view convertTabsToSpaces: nil];
  testAssert (![document isModified],
              @"Converting a file without tabs leaves it unmodified");
  [document setContent: @"{"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"{\n  "],
      @"Return after an opening brace uses two spaces independently of project indentation");
  CGFloat cellWidth =
      [@"8" sizeWithAttributes: [NSDictionary
                                   dictionaryWithObject: [view font]
                                                 forKey: NSFontAttributeName]]
          .width;
  testAssert (
      fabs ([[view defaultParagraphStyle] defaultTabInterval] - 8 * cellWidth)
          < 0.01,
      @"Displayed tabs use the configured tab width");
  [@"IndentWidth: 4\nTabWidth: 4\nUseTab: Always\n"
      writeToFile: config
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [document setFilePath: [root stringByAppendingPathComponent: @"Tabs.m"]];
  [document setContent: @"{"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  [view insertNewline: nil];
  testAssert ([[view string] isEqual: @"{\n  "],
              @"Opening braces insert spaces even when UseTab is enabled");
  [view insertText: @"{"];
  [view insertNewline: nil];
  testAssert ([[view string] isEqual: @"{\n  {\n    "],
              @"Nested opening braces add two spaces");
  [view insertText: @"}"];
  testAssert ([[view string] isEqual: @"{\n  {\n  }"],
              @"Closing delimiters align with their opening braces");
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"{\n  {\n  }\n"],
      @"Return after a closing brace removes two spaces even with four-column project settings");
  [@"IndentWidth: 8\nTabWidth: 8\nUseTab: Always\n"
      writeToFile: config
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [document setFilePath: [root stringByAppendingPathComponent: @"WideTabs.m"]];
  [document setContent: @"\t}"];
  [view setSelectedRange: NSMakeRange (2, 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"\t}\n      "],
      @"An eight-column tab before a closing brace becomes six spaces after Return");
  [document setContent: @"        }"];
  [view setSelectedRange: NSMakeRange (9, 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"        }\n      "],
      @"Eight leading spaces decrease to six regardless of configured indentation width");
  [document setContent: @"if (ready)"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"if (ready)\n  "],
      @"Control statements add two literal spaces even with eight-column project tabs");
  [YCodePreferences setControlIndentWidth: 4];
  [document setContent: @"{"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"{\n    "],
      @"Auto indentation preference controls opening braces and inserts literal spaces");
  [document setContent: @"while (ready)"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"while (ready)\n    "],
      @"Changing control indentation applies immediately and still inserts spaces");
  [document setContent: @"        }"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"        }\n    "],
      @"Closing braces use the same configurable control indentation amount");
  if (savedControlWidth)
    [[NSUserDefaults standardUserDefaults]
        setObject: savedControlWidth
           forKey: @"YCodeControlIndentWidth"];
  else
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey: @"YCodeControlIndentWidth"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [savedControlWidth release];
  [document setFilePath: [directory
                            stringByAppendingPathComponent: @"Unconfigured.m"]];
  testAssert ([view editorIndentWidth] == 2 && ![view editorUsesTabs],
              @"Changing files resets indentation settings");

  [document setContent: @""];
  [window setContentSize: NSMakeSize (900, 650)];
  NSClipView *clip = [[document scrollView] contentView];
  testAssert (NSWidth ([view frame]) >= NSWidth ([clip bounds])
                  && NSHeight ([view frame]) >= NSHeight ([clip bounds]),
              @"Empty editable area grows with the window");
  [window setContentSize: NSMakeSize (350, 250)];
  testAssert (fabs (NSWidth ([view frame]) - NSWidth ([clip bounds])) < 1
                  && fabs (NSHeight ([view frame]) - NSHeight ([clip bounds]))
                         < 1,
              @"Empty editor shrinks without stale scrollable space");
  [document setContent: @"short"];
  [window setContentSize: NSMakeSize (1000, 700)];
  testAssert (NSWidth ([view frame]) >= NSWidth ([clip bounds])
                  && NSHeight ([view frame]) >= NSHeight ([clip bounds]),
              @"Short source files fill the enlarged editable area");
  [window close];
  [window release];
  [document release];

  YCEditorView *editor =
      [[YCEditorView alloc] initWithFrame: NSMakeRect (0, 0, 400, 300)];
  [editor setFrameSize: NSMakeSize (850, 600)];
  testAssert (NSWidth ([[editor textView] frame])
                  >= NSWidth ([[[editor scrollView] contentView] bounds]),
              @"Standalone editor uses the same viewport resizing");
  [[editor textView] insertTab: nil];
  testAssert ([[editor text] isEqual: @"  "],
              @"Standalone editor uses the same editing rules");
  [editor release];
}

static BOOL
modelViewContains (NSView *view, NSString *text)
{
  if ([view isKindOfClass: [NSTextField class]] &&
      [[(NSTextField *)view stringValue] rangeOfString: text].location
          != NSNotFound)
    return YES;
#ifdef GNUSTEP
  if ([view isKindOfClass: [NSMenuView class]])
    {
      NSEnumerator *items =
          [[[(NSMenuView *)view menu] itemArray] objectEnumerator];
      NSMenuItem *item;
      while ((item = [items nextObject]))
        if ([[item title] rangeOfString: text].location != NSNotFound)
          return YES;
    }
#endif
  NSEnumerator *e = [[view subviews] objectEnumerator];
  NSView *child;
  while ((child = [e nextObject]))
    if (modelViewContains (child, text))
      return YES;
  return NO;
}

static NSView *
modelWidget (NSView *view, Class widgetClass)
{
  if ([view isKindOfClass: widgetClass])
    return view;
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *child;
  while ((child = [enumerator nextObject]))
    {
      NSView *found = modelWidget (child, widgetClass);
      if (found)
        return found;
    }
  return nil;
}

static void
renderModelPreview (YCodeEditorDocument *document, NSString *path)
{
  if (![[[NSProcessInfo processInfo] arguments]
          containsObject: @"--model-preview-screenshot"])
    return;
  NSWindow *preview =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 800, 900)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [preview setReleasedWhenClosed: NO];
  [preview setContentView: [document editorView]];
  [preview orderFront: nil];
  [preview display];
  NSView *view = [preview contentView];
  NSBitmapImageRep *bitmap =
      [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
  [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
  [[bitmap representationUsingType: NSPNGFileType
                        properties: [NSDictionary dictionary]] writeToFile: path
                                                               atomically: YES];
  [preview close];
  [preview release];
}

static BOOL
modelHasConnection (YCodeEditorDocument *document, NSString *type,
                    NSString *source, NSString *label, NSString *destination)
{
  NSTableView *table = (NSTableView *)modelWidget ([document editorView],
                                                   [NSTableView class]);
  NSInteger row;
  for (row = 0; row < [table numberOfRows]; row++)
    {
      id dataSource = [table dataSource];
      NSString *actualType = [dataSource
                          tableView: table
          objectValueForTableColumn: [table tableColumnWithIdentifier: @"type"]
                                row: row];
      NSString *actualSource = [dataSource
                          tableView: table
          objectValueForTableColumn: [table tableColumnWithIdentifier: @"source"]
                                row: row];
      NSString *actualLabel = [dataSource
                          tableView: table
          objectValueForTableColumn: [table tableColumnWithIdentifier: @"label"]
                                row: row];
      NSString *actualDestination =
          [dataSource tableView: table
              objectValueForTableColumn:
                  [table tableColumnWithIdentifier: @"destination"]
                                    row: row];
      if ([actualType isEqual: type] && [actualLabel isEqual: label] &&
          [actualSource rangeOfString: source].location != NSNotFound &&
          [actualDestination rangeOfString: destination].location != NSNotFound)
        return YES;
    }
  return NO;
}

static void
captureModelScreen (NSString *path)
{
  if ([[[NSProcessInfo processInfo] arguments]
          containsObject: @"--model-preview-screenshot"]
      && [[NSFileManager defaultManager]
          isExecutableFileAtPath: @"/usr/bin/import"])
    {
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.1]];
      NSTask *capture = [NSTask
          launchedTaskWithLaunchPath: @"/usr/bin/import"
                           arguments: [NSArray arrayWithObjects: @"-window",
                                                               @"root", path,
                                                               nil]];
      [capture waitUntilExit];
    }
}

static BOOL
modelConnectionTagsVisible (YCodeEditorDocument *document, BOOL visible)
{
  NSArray *tags = [document valueForKey: @"_connectionTagWindows"];
  return [tags count] == 2 && [[tags objectAtIndex: 0] isVisible] == visible &&
         [[tags objectAtIndex: 1] isVisible] == visible;
}

static void
testModelConnectionEndpoints (YCodeEditorDocument *document, NSUInteger row)
{
  NSWindow *host =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (20, 20, 1000, 900)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [host setReleasedWhenClosed: NO];
  [host setContentView: [document editorView]];
  [host orderFront: nil];
  [host display];
  NSTableView *table = (NSTableView *)modelWidget ([document editorView],
                                                   [NSTableView class]);
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: row]
      byExtendingSelection: NO];
  NSArray *segments = [document valueForKey: @"_connectionLineWindows"];
  testAssert (
      [segments count] == 2 && [[segments objectAtIndex: 0] isVisible] &&
          [[segments objectAtIndex: 1] isVisible],
      @"Decoded connection endpoints map to visible NIB and XIB preview objects");
  testAssert (
      modelConnectionTagsVisible (document, YES),
      @"NIB and XIB connection endpoints show source and target markers");

  [document reloadFromFile];
  testAssert ([table selectedRow] == -1
                  && ([segments count] == 0
                      || ![[segments objectAtIndex: 0] isVisible]),
              @"Reloading a selected model clears its connection overlay");
  testAssert (modelConnectionTagsVisible (document, NO),
              @"Reloading a model hides both connection markers");

  [host close];
  [host release];
}

static NSEvent *
modelMouseEvent (NSView *canvas, NSEventType type, NSPoint point)
{
  return [NSEvent mouseEventWithType: type
                            location: [canvas convertPoint: point toView: nil]
                       modifierFlags: 0
                           timestamp: 0
                        windowNumber: [[canvas window] windowNumber]
                             context: nil
                         eventNumber: 0
                          clickCount: 1
                            pressure: 1];
}

static void
testModelViewer (NSString *directory)
{
#ifdef GNUSTEP
  NSString *path = [directory stringByAppendingPathComponent: @"Preview.gorm"];
  NSString *archive = [path stringByAppendingPathComponent: @"objects.gorm"];
  [[NSFileManager defaultManager] createDirectoryAtPath: path
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  GSNibContainer *container = [GSNibContainer new];
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect: NSMakeRect (0, 0, 360, 220)
                styleMask: NSTitledWindowMask | NSClosableWindowMask
                          | NSMiniaturizableWindowMask
                  backing: NSBackingStoreBuffered
                    defer: YES];
  [window setReleasedWhenClosed: NO];
  [window setTitle: @"Hidden preview window"];
  NSTextField *label =
      [[NSTextField alloc] initWithFrame: NSMakeRect (12, 20, 210, 24)];
  [label setStringValue: @"Archived label"];
  [[window contentView] addSubview: label];
  [label release];
  NSButton *button =
      [[NSButton alloc] initWithFrame: NSMakeRect (20, 160, 120, 32)];
  [button setTitle: @"Preview button"];
  [button setBezelStyle: NSRoundedBezelStyle];
  [[window contentView] addSubview: button];
  [button release];
  NSButton *check =
      [[NSButton alloc] initWithFrame: NSMakeRect (20, 110, 200, 24)];
  [check setButtonType: NSSwitchButton];
  [check setTitle: @"Enabled option"];
  [check setState: NSOnState];
  [[window contentView] addSubview: check];
  [check release];
  NSSlider *slider =
      [[NSSlider alloc] initWithFrame: NSMakeRect (20, 65, 200, 24)];
  [slider setMinValue: 0];
  [slider setMaxValue: 1];
  [slider setNumberOfTickMarks: 5];
  [slider setDoubleValue: 0.65];
  [[window contentView] addSubview: slider];
  [slider release];
  NSMenu *fixtureMenu = [[NSMenu alloc] initWithTitle: @"Preview menu"];
  [fixtureMenu setAutoenablesItems: NO];
  [fixtureMenu addItemWithTitle: @"Open" action: NULL keyEquivalent: @"o"];
  [fixtureMenu addItem: [NSMenuItem separatorItem]];
  [[fixtureMenu addItemWithTitle: @"Checked item" action: NULL
                   keyEquivalent: @""] setState: NSOnState];
  [[container topLevelObjects] addObject: fixtureMenu];
  [fixtureMenu release];
  [[container nameTable] setObject: window forKey: @"Window"];
  [[container topLevelObjects] addObject: window];
  [[container visibleWindows] addObject: window];
  NSWindow *customWindow =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 160, 80)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: YES];
  [customWindow setReleasedWhenClosed: NO];
  [customWindow setTitle: @"Custom class window"];
  GSWindowTemplate *custom = [[GSWindowTemplate alloc]
      initWithObject: customWindow
           className: @"YCodeMissingPreviewWindowClass"
      superClassName: @"NSWindow"];
  [[container nameTable] setObject: custom forKey: @"Custom window"];
  [[container topLevelObjects] addObject: custom];
  [[container nameTable] setObject: [fixtureMenu itemAtIndex: 0]
                            forKey: @"Menu entry"];
  [[container nameTable] setObject: [button cell] forKey: @"Button cell"];
  [[container nameTable] setObject: AUTORELEASE ([[NSTextFieldCell alloc]
                                       initTextCell: @"Cell contents"])
                            forKey: @"Text cell"];
  NSTableColumn *previewColumn =
      [[NSTableColumn alloc] initWithIdentifier: @"Preview column"];
  [[container nameTable] setObject: previewColumn forKey: @"Table column"];
  [[container nameTable] setObject: [previewColumn headerCell]
                            forKey: @"Table header cell"];
  [[container nameTable] setObject: [previewColumn dataCell]
                            forKey: @"Table data cell"];
  [previewColumn release];
  NSNibOutletConnector *outlet = [NSNibOutletConnector new];
  [outlet setSource: @"NSOwner"];
  [outlet setDestination: @"Window"];
  [outlet setLabel: @"mainWindow"];
  [[container connections] addObject: outlet];
  [outlet release];
  NSNibControlConnector *action = [NSNibControlConnector new];
  [action setSource: @"Button"];
  [action setDestination: @"NSFirst"];
  [action setLabel: @"performPreviewAction:"];
  [[container connections] addObject: action];
  [[container nameTable] setObject: button forKey: @"Button"];
  [action release];
  NSData *data = [NSArchiver archivedDataWithRootObject: container];
  [data writeToFile: archive atomically: YES];
  NSMenu *menu = [NSApp mainMenu];
  id delegate = [NSApp delegate];
  NSArray *windows = [[NSApp windows] copy];
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert ([[[document class] editorKind] isEqual: @"model"] &&
                  [document loadFromFile],
              @"Gorm packages select and load the model viewer");
  testAssert (
      modelViewContains ([document editorView], @"Hidden preview window")
          && modelViewContains ([document editorView], @"Archived label")
          && modelViewContains ([document editorView], @"Custom class window"),
      @"The embedded preview includes archived windows and their contents");
  testAssert (
      modelHasConnection (document, @"Outlet", @"File's Owner", @"mainWindow",
                          @"Window")
          && modelHasConnection (document, @"Action", @"Button",
                                 @"performPreviewAction:", @"First Responder"),
      @"Gorm inspector lists named outlets and responder actions");
  testAssert (![document isEditable] && ![document textView],
              @"Models have no text editing surface");
  NSButton *previewButton
      = (NSButton *)modelWidget ([document editorView], [NSButton class]);
  NSSlider *previewSlider
      = (NSSlider *)modelWidget ([document editorView], [NSSlider class]);
  NSMenuView *previewMenu
      = (NSMenuView *)modelWidget ([document editorView], [NSMenuView class]);
  testAssert ([[previewButton title] isEqual: @"Preview button"],
              @"Preview embeds a native button");
  testAssert (
      NSEqualRects ([previewButton frame], NSMakeRect (20, 160, 120, 32)),
      @"Preview preserves archived widget geometry");
  /* GNUstep's unkeyed slider archive stores bounds and ticks, but not value. */
  testAssert (previewSlider != nil && [previewSlider maxValue] == 1 &&
                  [previewSlider numberOfTickMarks] == 5,
              @"Preview renders archived slider bounds and tick marks");
  testAssert (
      previewMenu != nil &&
          [[previewMenu menuItemCellForItemAtIndex: 0]
              isKindOfClass: [NSMenuItemCell class]]
          && [[[previewMenu menu] itemAtIndex: 2] state] == NSOnState,
      @"Menus render native menu cells, separators and checked states instead of text outlines");
  testAssert (![previewButton acceptsFirstResponder]
                  && ![previewSlider acceptsFirstResponder],
              @"Rendered widgets stay out of keyboard traversal");
  NSScrollView *objectsPane =
      [[[document editorView] subviews] objectAtIndex: 0];
  NSView *objectsCanvas = [objectsPane documentView];
  testAssert (
      !modelViewContains (objectsCanvas, @"NSMenuItem")
          && !modelViewContains (objectsCanvas, @"NSButtonCell")
          && !modelViewContains (objectsCanvas, @"NSTextFieldCell")
          && !modelViewContains (objectsCanvas, @"NSTableColumn")
          && !modelViewContains (objectsCanvas, @"NSTableHeaderCell"),
      @"Menu items, table columns, and cell subclasses are excluded from nonvisual objects");
  testAssert (
      modelViewContains (objectsCanvas, @"File's Owner")
          && modelWidget (objectsCanvas, [NSMenuView class]) == nil,
      @"The left pane contains nonvisual objects separately from graphical previews");
  renderModelPreview (document, @"/tmp/ycode-model-widgets.png");
  NSView *canvas = [[document scrollView] documentView];
  testAssert ([canvas hitTest: NSMakePoint (30, 100)] == canvas,
              @"Preview controls cannot receive mouse input");
  NSWindow *dragHost =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 1000, 900)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [dragHost setReleasedWhenClosed: NO];
  [dragHost setContentView: [document editorView]];
  [dragHost display];
  [dragHost orderFront: nil];
  NSTableView *lineTable = (NSTableView *)modelWidget ([document editorView],
                                                       [NSTableView class]);
  [lineTable selectRowIndexes: [NSIndexSet indexSetWithIndex: 1]
         byExtendingSelection: NO];
  NSArray *segments = [document valueForKey: @"_connectionLineWindows"];
  testAssert (
      [segments count] == 2 && [[segments objectAtIndex: 0] isVisible] &&
          [[segments objectAtIndex: 1] isVisible],
      @"Selecting a Gorm action draws two rectilinear window segments");
  NSWindow *horizontal = [segments count] ? [segments objectAtIndex: 0] : nil;
  NSWindow *vertical = [segments count] > 1 ? [segments objectAtIndex: 1] : nil;
  testAssert (
      [horizontal parentWindow] == dragHost && [horizontal ignoresMouseEvents]
          && ![horizontal canBecomeKeyWindow]
          && ![vertical canBecomeMainWindow],
      @"Connection windows follow their host without intercepting input or focus");
  NSRect oldLineFrame = [horizontal frame];
  NSArray *tags = [document valueForKey: @"_connectionTagWindows"];
  testAssert (modelConnectionTagsVisible (document, YES),
              @"Selecting a Gorm connection shows S and T markers");
  NSUInteger tagIndex;
  for (tagIndex = 0; tagIndex < [tags count]; tagIndex++)
    {
      NSWindow *tag = [tags objectAtIndex: tagIndex];
      NSString *name = tagIndex == 0 ? @"GormSourceTag" : @"GormTargetTag";
      NSString *path =
          [[NSBundle bundleForClass: [document class]] pathForResource: name
                                                               ofType: @"tiff"];
      NSImage *expected = [[NSImage alloc] initWithContentsOfFile: path];
      NSImage *actual = [(NSImageView *)[tag contentView] image];
      testAssert (
          expected != nil &&
              [[actual TIFFRepresentation]
                  isEqual: [expected TIFFRepresentation]],
          @"Connection markers use the original images bundled with the Model editor");
      testAssert (
          [tag parentWindow] == dragHost && [tag ignoresMouseEvents]
              && ![tag canBecomeKeyWindow] && ![tag canBecomeMainWindow],
          @"Connection markers do not intercept mouse input or window focus");
      [expected release];
    }
  NSWindow *sourceTag = [tags count] ? [tags objectAtIndex: 0] : nil;
  NSRect oldTagFrame = [sourceTag frame];

  NSView *previewFrame = [[previewButton superview] superview];
  NSPoint titlePoint =
      [canvas convertPoint: NSMakePoint (NSMidX ([previewFrame bounds]),
                                        NSMaxY ([previewFrame bounds]) - 10)
                  fromView: previewFrame];
  NSRect initialFrame = [previewFrame frame];
  NSPoint destination = NSMakePoint (titlePoint.x + 15, titlePoint.y + 40);
  [canvas mouseDown: modelMouseEvent (canvas, NSLeftMouseDown, titlePoint)];
  [canvas
      mouseDragged: modelMouseEvent (canvas, NSLeftMouseDragged, destination)];
  [canvas mouseUp: modelMouseEvent (canvas, NSLeftMouseUp, destination)];
  testAssert (
      NSMinX ([previewFrame frame]) == NSMinX (initialFrame) + 15
          && NSMinY ([previewFrame frame]) == NSMinY (initialFrame) + 40,
      @"Dragging a simulated title bar moves its window on the canvas");
  testAssert (!NSEqualRects (oldLineFrame, [horizontal frame]),
              @"Connection overlay follows simulated window dragging");
  testAssert (
      NSMinX ([sourceTag frame]) == NSMinX (oldTagFrame) + 15
          && NSMinY ([sourceTag frame]) == NSMinY (oldTagFrame) - 40,
      @"The source marker tracks the dragged control in screen coordinates");

  NSUserDefaults *lineDefaults = [NSUserDefaults standardUserDefaults];
  id savedLineColor =
      [[lineDefaults objectForKey: @"YCodeConnectionLineColor"] retain];
  id savedLineWidth =
      [[lineDefaults objectForKey: @"YCodeConnectionLineWidth"] retain];
  AppController *preferences = [AppController new];
  [preferences showPrefPanel: nil];
  NSPopUpButton *groups = [preferences valueForKey: @"_preferencesGroup"];
  [groups selectItemWithTitle: @"Connection Line"];
  [groups sendAction: [groups action] to: [groups target]];
  testAssert (
      ![[preferences valueForKey: @"_connectionPreferencesView"] isHidden] &&
          [[preferences valueForKey: @"_terminalPreferencesView"] isHidden],
      @"Preferences includes a separate Connection Line section");
  NSColorWell *lineWell = [preferences valueForKey: @"_connectionColorWell"];
  NSPopUpButton *lineWidth =
      [preferences valueForKey: @"_connectionWidthChoice"];
  [lineWell setColor: [NSColor greenColor]];
  [lineWell sendAction: [lineWell action] to: [lineWell target]];
  [lineWidth selectItemAtIndex: 4];
  [lineWidth sendAction: [lineWidth action] to: [lineWidth target]];
  testAssert (
      [horizontal frame].size.height == 5 && [vertical frame].size.width == 5
          && colorMatches ([horizontal backgroundColor], 0, 1, 0) &&
          [YCodePreferences connectionLineWidth] == 5
          && colorMatches ([YCodePreferences connectionLineColor], 0, 1, 0),
      @"Connection color and width preferences persist and update visible segments immediately");
  [[preferences valueForKey: @"_preferencesPanel"] display];
  [dragHost display];
  captureModelScreen (@"/tmp/ycode-connection-preferences.png");
  if (savedLineColor)
    [lineDefaults setObject: savedLineColor forKey: @"YCodeConnectionLineColor"];
  else
    [lineDefaults removeObjectForKey: @"YCodeConnectionLineColor"];
  if (savedLineWidth)
    [lineDefaults setObject: savedLineWidth forKey: @"YCodeConnectionLineWidth"];
  else
    [lineDefaults removeObjectForKey: @"YCodeConnectionLineWidth"];
  [savedLineColor release];
  [savedLineWidth release];
  [lineDefaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeConnectionPreferencesDidChangeNotification
                    object: nil];
  [[preferences valueForKey: @"_preferencesPanel"] close];
  [preferences release];
  [[document editorView] setHidden: YES];
  testAssert (![horizontal isVisible] && ![vertical isVisible],
              @"Hiding the model viewer removes its connection windows");
  testAssert (modelConnectionTagsVisible (document, NO),
              @"Connection markers share the line visibility lifecycle");
  [[document editorView] setHidden: NO];
  testAssert ([horizontal isVisible] && [vertical isVisible],
              @"Showing the model viewer restores the selected connection");
  testAssert (modelConnectionTagsVisible (document, YES),
              @"Connection markers share the line visibility lifecycle");
  NSClipView *objectClip = [objectsPane contentView];
  NSSize objectCanvasSize = [objectsCanvas frame].size;
  [objectsCanvas setFrameSize: NSMakeSize (objectCanvasSize.width, 1400)];
  [objectClip scrollToPoint: NSMakePoint (0, 350)];
  testAssert (
      ![horizontal isVisible] && ![vertical isVisible],
      @"Connection lines hide when a scrolled endpoint leaves the visible canvas");
  testAssert (modelConnectionTagsVisible (document, NO),
              @"Connection markers share the line visibility lifecycle");
  [objectClip scrollToPoint: NSZeroPoint];
  [objectsCanvas setFrameSize: objectCanvasSize];
  testAssert (
      [horizontal isVisible] && [vertical isVisible],
      @"Connection lines reappear when their endpoints scroll back into view");
  testAssert (modelConnectionTagsVisible (document, YES),
              @"Connection markers share the line visibility lifecycle");
  [lineTable deselectAll: nil];
  testAssert (![horizontal isVisible] && ![vertical isVisible],
              @"Clearing connection selection hides the overlay");
  testAssert (modelConnectionTagsVisible (document, NO),
              @"Connection markers share the line visibility lifecycle");
  [lineTable selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
         byExtendingSelection: NO];
  testAssert (
      [horizontal isVisible] && [vertical isVisible],
      @"Selecting an outlet connects the owner icon to the window preview");
  captureModelScreen (@"/tmp/ycode-model-connection.png");
  NSRect movedFrame = [previewFrame frame];
  [canvas performSelector: @selector (layoutPreviews)];
  testAssert (NSEqualRects (movedFrame, [previewFrame frame]),
              @"Preview layout preserves manually positioned windows");
  NSPoint contentPoint = [canvas convertPoint: NSMakePoint (40, 40)
                                     fromView: previewFrame];
  [canvas mouseDown: modelMouseEvent (canvas, NSLeftMouseDown, contentPoint)];
  [canvas
      mouseDragged: modelMouseEvent (canvas, NSLeftMouseDragged, destination)];
  [canvas mouseUp: modelMouseEvent (canvas, NSLeftMouseUp, destination)];
  testAssert (
      NSEqualRects (movedFrame, [previewFrame frame])
          && NSEqualRects ([previewButton frame],
                           NSMakeRect (20, 160, 120, 32)),
      @"Dragging preview contents leaves windows and archived widgets unchanged");
  [dragHost close];
  testAssert (![horizontal isVisible] && ![vertical isVisible],
              @"Closing the viewer window hides all connection segments");
  testAssert (modelConnectionTagsVisible (document, NO),
              @"Connection markers share the line visibility lifecycle");

  [dragHost release];
  [document setModified: YES];
  testAssert (![document isModified] && [document saveToFile] &&
                  [data isEqual: [NSData dataWithContentsOfFile: archive]],
              @"Saving a preview leaves the archive untouched");
  testAssert (
      [document reloadFromFile]
          && modelViewContains ([document editorView], @"Archived label"),
      @"Repeated model loads retain the preview contents");
  [[container connections] removeAllObjects];
  [[NSArchiver archivedDataWithRootObject: container] writeToFile: archive
                                                      atomically: YES];
  testAssert ([document reloadFromFile] &&
                  [(NSTableView *)modelWidget (
                      [document editorView], [NSTableView class]) numberOfRows]
                      == 0
                  && modelViewContains ([document editorView],
                                        @"Connections — none in this model"),
              @"Reloading an unconnected model clears old inspector rows");

  NSEnumerator *e = [[NSApp windows] objectEnumerator];
  NSWindow *other;
  BOOL visible = NO;
  while ((other = [e nextObject]))
    if (![windows containsObject: other] && [other isVisible])
      visible = YES;
  testAssert (
      !visible && [NSApp mainMenu] == menu && [NSApp delegate] == delegate,
      @"Previewing does not show model windows or replace application state");
  [document release];
  [windows release];
  [container release];
  [window release];
  [custom release];
  [customWindow release];

  NSIBObjectData *nib = [NSIBObjectData new];
  NSWindowTemplate *nibWindow = [NSWindowTemplate new];
  NSView *nibContent =
      [[NSView alloc] initWithFrame: NSMakeRect (0, 0, 160, 100)];
  NSSlider *keyedSlider =
      [[NSSlider alloc] initWithFrame: NSMakeRect (10, 10, 120, 24)];
  [keyedSlider setMinValue: 0];
  [keyedSlider setMaxValue: 1];
  [keyedSlider setDoubleValue: 0.65];
  [nibContent addSubview: keyedSlider];
  [keyedSlider release];
  [nibWindow setView: nibContent];
  [nibWindow setTitle: @"Keyed NIB window"];
  outlet = [NSNibOutletConnector new];
  [outlet setSource: nibWindow];
  [outlet setDestination: keyedSlider];
  [outlet setLabel: @"valueSlider"];
  [[nib connections] addObject: outlet];
  [outlet release];
  NSMapInsert ([nib objects], nibWindow, nibWindow);
  NSMutableData *nibData = [NSMutableData data];
  NSKeyedArchiver *archiver =
      [[NSKeyedArchiver alloc] initForWritingWithMutableData: nibData];
  [archiver encodeObject: nib forKey: @"IB.objectdata"];
  [archiver finishEncoding];
  [archiver release];
  path = [directory stringByAppendingPathComponent: @"Preview.nib"];
  [[NSFileManager defaultManager] createDirectoryAtPath: path
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  [nibData
      writeToFile: [path stringByAppendingPathComponent: @"keyedobjects.nib"]
       atomically: YES];
  document = [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert (
      [document loadFromFile]
          && modelViewContains ([document editorView], @"Keyed NIB window"),
      @"Keyed NIB packages preview window templates without awakening the model");
  testAssert (modelHasConnection (document, @"Outlet", @"Keyed NIB window",
                                  @"valueSlider", @"NSSlider"),
              @"Keyed NIB inspector lists decoded object connections");
  previewSlider
      = (NSSlider *)modelWidget ([document editorView], [NSSlider class]);
  testAssert (previewSlider != nil
                  && fabs ([previewSlider doubleValue] - 0.65) < 0.001,
              @"Keyed NIB widget previews preserve archived values");
  testModelConnectionEndpoints (document, 0);
  [document release];
  [nib release];
  [nibWindow release];
  [nibContent release];

  path = [[NSBundle mainBundle] pathForResource: @"Ycode" ofType: @"gorm"];
  document = [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert (
      [document loadFromFile]
          && !modelViewContains ([document editorView], @"Unable to preview")
          && modelViewContains ([document editorView], @"AppController"),
      @"A real Gorm archive previews its application controller without constructing it");
  testAssert ([NSApp mainMenu] == menu && [NSApp delegate] == delegate,
              @"Real Gorm model previews leave application state intact");
  [document release];
  NSString *resources = [[NSBundle mainBundle] pathForResource: @"Templates"
                                                        ofType: nil];
  path =
      [resources stringByAppendingPathComponent: @"Application/MainMenu.xib"];
  document = [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert ([document loadFromFile]
                  && modelViewContains ([document editorView], @"Main Window")
                  && modelViewContains ([document editorView], @"Quit"),
              @"XIB previews include windows and nested menus");
  testAssert (
      [NSApp mainMenu] == menu && [NSApp delegate] == delegate
          && ![NSClassSwapper isInInterfaceBuilder],
      @"XIB loading restores decoder state without connecting outlets");
  testAssert (
      modelHasConnection (document, @"Outlet", @"File's Owner", @"delegate",
                          @"controller")
          && modelHasConnection (document, @"Action", @"Quit",
                                 @"terminate:", @"File's Owner"),
      @"XIB inspector displays outlets and actions in sender-to-receiver order");
  NSTableView *connectionTable = (NSTableView *)modelWidget (
      [document editorView], [NSTableView class]);
  testAssert ([connectionTable numberOfRows] == 5,
              @"XIB inspector shows every connection once");
  testModelConnectionEndpoints (document, 4);
  [document reloadFromFile];
  testAssert ([connectionTable numberOfRows] == 5,
              @"Reload replaces connection rows without duplicates");
  NSView *modelCanvas = [[document scrollView] documentView];
  objectsPane = [[[document editorView] subviews] objectAtIndex: 0];
  objectsCanvas = [objectsPane documentView];
  testAssert (objectsPane != [document scrollView]
                  && NSMaxX ([objectsPane frame])
                         <= NSMinX ([[document scrollView] frame]),
              @"Nonvisual objects have their own scrollable pane on the left");
  NSSize oldSize = [[document editorView] frame].size;
  CGFloat oldWidth = [[document scrollView] frame].size.width;
  [[document editorView]
      setFrameSize: NSMakeSize (oldSize.width + 120, oldSize.height + 80)];
  testAssert (
      [objectsPane frame].size.width == 140
          && fabs ([[document scrollView] frame].size.width - oldWidth - 120)
                 < 1
          && [objectsPane frame].size.height == oldSize.height + 80,
      @"Resizing keeps the object pane at the left and expands the preview");
  [[document editorView] setFrameSize: oldSize];
  NSEnumerator *tiles = [[objectsCanvas subviews] objectEnumerator];
  NSView *tile;
  NSUInteger iconCount = 0;
  CGFloat previousY = -1, iconX = -1;
  while ((tile = [tiles nextObject]))
    {
      NSImageView *iconView
          = (NSImageView *)modelWidget (tile, [NSImageView class]);
      if (!iconView)
        continue;
      NSString *name = [iconView toolTip];
      NSString *resource = @"GormUnknown";
      if ([name isEqual: @"File's Owner"])
        resource = @"GormFilesOwner";
      if ([name isEqual: @"First Responder"])
        resource = @"GormFirstResponder";
      NSString *resourcePath =
          [[NSBundle bundleForClass: [document class]] pathForResource: resource
                                                               ofType: @"tiff"];
      NSImage *expected =
          [[NSImage alloc] initWithContentsOfFile: resourcePath];
      testAssert (expected != nil &&
                      [[[iconView image] TIFFRepresentation]
                          isEqual: [expected TIFFRepresentation]],
                  @"Nonvisual objects use the matching bundled Gorm icons");
      [expected release];
      testAssert (NSMinY ([tile frame]) > previousY
                      && (iconX < 0 || NSMinX ([tile frame]) == iconX),
                  @"Object icons are stacked in the independent left pane");
      previousY = NSMinY ([tile frame]);
      iconX = NSMinX ([tile frame]);
      iconCount++;
    }
  testAssert (iconCount == 4
                  && modelViewContains (objectsCanvas, @"File's Owner")
                  && modelViewContains (objectsCanvas, @"First Responder"),
              @"XIB proxies and controllers all have labeled icons");
  NSMenuView *firstMenu
      = (NSMenuView *)modelWidget (modelCanvas, [NSMenuView class]);
  NSView *windowFrame
      = modelWidget (modelCanvas, NSClassFromString (@"YCModelWindowFrame"));
  NSSize naturalWindowSize = [windowFrame bounds].size;
  [[document editorView] setFrameSize: NSMakeSize (1800, 900)];
  testAssert (
      NSMinY ([firstMenu frame]) == NSMinY ([windowFrame frame])
          && NSMaxX ([firstMenu frame]) < NSMinX ([windowFrame frame]),
      @"Menus and windows share a row when the viewport is wide enough");
  [[document editorView] setFrameSize: NSMakeSize (800, 900)];
  testAssert (NSMinY ([windowFrame frame]) >= NSMaxY ([firstMenu frame]) + 24,
              @"Narrowing the viewport wraps windows below the menu row");
  testAssert (
      fabs ([modelCanvas frame].size.width -
            [[document scrollView] contentSize].width)
              < 1
          && ![[document scrollView] hasHorizontalScroller],
      @"Preview canvas fits the viewport without horizontal scrolling");
  [[document editorView] setFrameSize: NSMakeSize (400, 300)];
  testAssert (
      NSMaxX ([windowFrame frame]) <= [modelCanvas bounds].size.width &&
          [windowFrame frame].size.width < naturalWindowSize.width
          && NSEqualSizes ([windowFrame bounds].size, naturalWindowSize),
      @"Oversized windows fit narrow viewports while preserving archived coordinates");
  testAssert (NSMaxY ([windowFrame frame]) <= [modelCanvas bounds].size.height,
              @"Wrapped previews remain reachable by vertical scrolling");
  [[document editorView] setFrameSize: NSMakeSize (1800, 900)];
  testAssert (NSEqualSizes ([windowFrame frame].size, naturalWindowSize)
                  && NSMinY ([firstMenu frame])
                         == NSMinY ([windowFrame frame]),
              @"Widening restores natural preview sizes and the shared row");
  [[document editorView] setFrameSize: NSMakeSize (800, 900)];
  renderModelPreview (document, @"/tmp/ycode-model-preview.png");
  [document release];
  path = [directory stringByAppendingPathComponent: @"Broken.nib"];
  [@"invalid archive" writeToFile: path
                       atomically: YES
                         encoding: NSUTF8StringEncoding
                            error: NULL];
  document = [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert (
      [document loadFromFile]
          && modelViewContains ([document editorView], @"Unable to preview"),
      @"Unsupported models show an explanation inside the editor pane");
  testAssert (
      modelViewContains ([document editorView], @"Connections unavailable") &&
          [(NSTableView *)modelWidget ([document editorView],
                                       [NSTableView class]) numberOfRows]
              == 0,
      @"Unsupported models do not imply an empty but readable connection list");

  testAssert (![NSClassSwapper isInInterfaceBuilder],
              @"Failed model loading restores decoder state");
  [document release];
#endif
}

static void
testEditorBundles (void)
{
  NSString *resources = [[NSBundle mainBundle] pathForResource: @"Editors"
                                                        ofType: nil];
  testAssert (resources != nil, @"Editor bundles are packaged with the host");
  YCodeEditorRegistry *registry = [[YCodeEditorRegistry alloc]
      initWithSearchPaths: resources ? [NSArray arrayWithObject: resources]
                                    : [NSArray array]];
  testAssert ([[registry editorIdentifiers]
                  isEqual: [NSArray arrayWithObjects: @"image", @"model",
                                                    @"sound", @"text", nil]],
              @"Discover the independently loaded editor bundles");
  Class text = [registry editorClassForFilePath: @"Source.m"];
  Class image = [registry editorClassForFilePath: @"Picture.PNG"];
  Class sound = [registry editorClassForFilePath: @"Audio.WAV"];
  testAssert (
      [[text editorIdentifier] isEqual: @"text"] &&
          [[image editorIdentifier] isEqual: @"image"] &&
          [[sound editorIdentifier] isEqual: @"sound"],
      @"Specialized editors beat the text fallback, including uppercase extensions");
  testAssert ([registry editorClassForFilePath: @"Untitled-1"] == text &&
                  [registry editorClassForFilePath: @"README.unknown"] == text,
              @"Untitled and unrecognized files use the text editor");
  testAssert (
      [registry editorClassForFilePath: nil] == Nil
          && ![registry loadBundleAtPath: @"/nonexistent/YcodeEditor.bundle"],
      @"Missing paths and invalid bundles fail safely");
  testAssert (
      [[[NSBundle bundleForClass: text] bundlePath] hasSuffix: @"Text.bundle"] &&
          [[[NSBundle bundleForClass: image] bundlePath]
              hasSuffix: @"Image.bundle"]
          && [[[NSBundle bundleForClass: sound] bundlePath]
              hasSuffix: @"Sound.bundle"],
      @"Editor implementations reside in loadable bundles");
  YCodeEditorDocument *document =
      [[YCodeEditorDocument alloc] initWithFilePath: @"Picture.PNG"];
  testAssert (
      [document class] == image && [document textView] == nil
          && ![document isEditable] && [document editorView] != nil,
      @"The document factory creates a media view without a temporary text editor");
  [document setModified: YES];
  testAssert (![document isModified],
              @"Read-only editor documents never become dirty");
  [document release];
  [registry release];
  registry = [[YCodeEditorRegistry alloc] initWithSearchPaths: [NSArray array]];
  testAssert (
      [registry editorClassForFilePath: @"Source.m"] == Nil,
      @"An empty registry does not silently create a hard-coded editor");
  [registry release];
}

static void
testEditorBundleFiles (NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: directory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *path =
      [directory stringByAppendingPathComponent: @"Bundle Preview.PNG"];
  NSBitmapImageRep *bitmap =
      [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                              pixelsWide: 8
                                              pixelsHigh: 8
                                           bitsPerSample: 8
                                         samplesPerPixel: 4
                                                hasAlpha: YES
                                                isPlanar: NO
                                          colorSpaceName: NSDeviceRGBColorSpace
                                             bytesPerRow: 0
                                            bitsPerPixel: 0];
  memset ([bitmap bitmapData], 255,
          [bitmap bytesPerRow] * [bitmap pixelsHigh]);
  NSData *data = [bitmap representationUsingType: NSPNGFileType
                                      properties: [NSDictionary dictionary]];
  [data writeToFile: path atomically: YES];
  [bitmap release];
  YCodeEditorDocument *image =
      [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert (
      [image loadFromFile] && [image isImageDocument] && [image image] != nil
          && [image textView] == nil,
      @"The image bundle decodes images without exposing text editing");
  NSView *view = [image editorView];
  [image setContent: @"must not replace pixels"];
  [image insertText: @"text" atLocation: 0];
  [image setModified: YES];
  testAssert (![image isModified] && [image saveToFile] &&
                  [[NSData dataWithContentsOfFile: path] isEqual: data],
              @"Saving a preview preserves its bytes");
  testAssert ([image reloadFromFile] && [image editorView] == view,
              @"Image reload keeps the root view installed in its tab");
  [@"invalid" writeToFile: path
               atomically: YES
                 encoding: NSUTF8StringEncoding
                    error: NULL];
  testAssert (![image loadFromFile] && [image textView] == nil,
              @"Invalid images fail without falling back to a text editor");
  [image release];
  path = [directory stringByAppendingPathComponent: @"Bundle Text.txt"];
  [@"original" writeToFile: path
                atomically: YES
                  encoding: NSUTF8StringEncoding
                     error: NULL];
  YCodeEditorDocument *text =
      [[YCodeEditorDocument alloc] initWithFilePath: path];
  testAssert ([text loadFromFile] && [text isEditable] &&
                  [[text content] isEqual: @"original"],
              @"Text bundle loads UTF-8 files");
  [text setContent: @"changed"];
  [text setModified: YES];
  testAssert (
      [text isModified] && [text saveToFile] && ![text isModified] &&
          [[NSString stringWithContentsOfFile: path
                                     encoding: NSUTF8StringEncoding
                                        error: NULL] isEqual: @"changed"],
      @"Text bundle saves changes and clears its dirty state");
  [text release];
}

static void
testEditorFiles (NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *package =
      [directory stringByAppendingPathComponent: @"Nested.xcodeproj"];
  NSString *sources =
      [directory stringByAppendingPathComponent: @"Sources With Spaces/Nested"];
  NSString *first = [sources stringByAppendingPathComponent: @"Example.h"];
  NSString *second = [directory stringByAppendingPathComponent: @"Example.h"];
  NSString *contents
      = @"{ objects = {"
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
  [manager createDirectoryAtPath: package
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [manager createDirectoryAtPath: sources
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [contents
      writeToFile: [package stringByAppendingPathComponent: @"project.pbxproj"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [@"// nested source\n" writeToFile: first
                          atomically: YES
                            encoding: NSUTF8StringEncoding
                               error: NULL];
  [@"// root source\n" writeToFile: second
                        atomically: YES
                          encoding: NSUTF8StringEncoding
                             error: NULL];

  YCodeProject *document = [[YCodeProject alloc] init];
  NSError *error = nil;
  testAssert ([document readFromURL: [NSURL fileURLWithPath: package]
                             ofType: @"YCodeXcodeProjectType"
                              error: &error],
              @"Load nested file fixture");
  [document makeWindowControllers];
  [document showWindows];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  YCodeEditorController *editor = [document editorController];
  NSDictionary *objects = [[document container] objects];
  YCodeProjectNavigatorItem *nested =
      [navigator itemForObject: [objects objectForKey: @"FILE"]];
  YCodeProjectNavigatorItem *root =
      [navigator itemForObject: [objects objectForKey: @"ROOTFILE"]];
  testAssert (
      [[navigator resolvedFilePathForNavigatorItem: nested] isEqual: first],
      @"Resolve nested groups, spaces, and logical groups without paths");
  testAssert (
      [[navigator resolvedFilePathForNavigatorItem: root] isEqual: second],
      @"SOURCE_ROOT ignores parent group paths and duplicate basenames");
  testAssert (
      [[navigator
          resolvedFilePathForNavigatorItem:
              [navigator itemForObject: [objects objectForKey: @"ABSOLUTE"]]]
          isEqual: @"/tmp/Ycode-absolute.h"],
      @"Keep absolute file paths");
  testAssert (
      [navigator resolvedFilePathForNavigatorItem:
                     [navigator itemForObject: [objects objectForKey: @"SDK"]]]
          == nil,
      @"Do not open a project file for an unresolved SDK reference");

  // Repeated failed reads used to release the project's editor controller.
  NSUInteger index;
  for (index = 0; index < 3; index++)
    testAssert (
        ![editor
            openFile: [directory stringByAppendingPathComponent: @"Missing.h"]],
        @"Missing file returns failure without destroying the editor");
  testAssert ([[editor openDocuments] count] == 0,
              @"Failed reads create no tabs");
  [[navigator outlineView] expandItem: [[navigator rootItems] objectAtIndex: 0]
                       expandChildren: YES];
  testAssert ([[navigator outlineView] rowForItem: nested] >= 0,
              @"Nested file is visible for selection");
  [navigator selectItem: nested];
  testAssert (
      [[[editor currentDocument] content] isEqual: @"// nested source\n"],
      @"Selecting a nested source displays its contents");
  [navigator selectItem: root];
  testAssert ([[[editor currentDocument] content] isEqual: @"// root source\n"],
              @"Selecting another source displays its own contents");
  [navigator selectItem: nested];
  testAssert ([[editor openDocuments] count] == 2,
              @"Repeated selection reuses open tabs");
  NSMutableString *longText = [NSMutableString string];
  for (index = 0; index < 200; index++)
    [longText
        appendString:
            @"A long source line that must remain reachable when scrolling through the editor.\n"];
  [longText appendString: [@"wide " stringByPaddingToLength: 2000
                                                withString: @"wide "
                                           startingAtIndex: 0]];
  [[editor currentDocument] setContent: longText];
  NSTextView *scrollingText = [[editor currentDocument] textView];
  NSScrollView *editorScroll = [[editor currentDocument] scrollView];
  testAssert ([[editorScroll horizontalRulerView]
                  isKindOfClass: [YCEditorRulerView class]]
                  && [[editorScroll verticalRulerView]
                      isKindOfClass: [YCEditorRulerView class]],
              @"Both editor rulers use text coordinates");
  [[scrollingText window] display];
  [[scrollingText layoutManager]
      ensureLayoutForTextContainer: [scrollingText textContainer]];
  [[scrollingText window] display];
  testAssert (NSHeight ([scrollingText frame])
                  > NSHeight ([editorScroll documentVisibleRect]),
              @"Long files extend beyond the editor viewport");
  testAssert (
      NSWidth ([scrollingText frame])
          > NSWidth ([editorScroll documentVisibleRect]),
      @"Long source lines extend horizontally beyond the editor viewport");
  [scrollingText scrollRangeToVisible: NSMakeRange ([longText length], 0)];
  testAssert (NSMinY ([editorScroll documentVisibleRect]) > 0,
              @"Can scroll to the end of a long file");
  testAssert (NSMinX ([editorScroll documentVisibleRect]) > 0,
              @"Can scroll to the end of a long line");
  testAssert (
      NSEqualRects ([editorScroll frame], [[editor tabView] contentRect]),
      @"Editor scroll view fills the selected tab");
  NSWindow *editorWindow = [scrollingText window];
  [editorWindow setContentSize: NSMakeSize (1100, 760)];
  testAssert (
      NSEqualRects ([editorScroll frame], [[editor tabView] contentRect]),
      @"Editor scroll view fills the tab after resizing the window");
  [scrollingText scrollRangeToVisible: NSMakeRange (0, 0)];
  testAssert (NSMinY ([editorScroll documentVisibleRect]) == 0,
              @"Can scroll back to the start after resizing");
  [editor setEditorFont: [NSFont userFixedPitchFontOfSize: 18.0]];
  [[editor currentDocument]
      setContent:
          @"0123456789012345678901234567890123456789\r\n\r\nUnicode: é 漢字\nLast line\n"];
  [editorWindow display];
  [[editor currentDocument] setContent: @"short source\n"];
  [editorWindow setContentSize: NSMakeSize (1500, 900)];
  [editorWindow display];
  NSClipView *editorClip = [editorScroll contentView];
  testAssert (
      NSWidth ([scrollingText frame]) >= NSWidth ([editorClip bounds])
          && NSHeight ([scrollingText frame])
                 >= NSHeight ([editorClip bounds]),
      @"Actual project editor fills the viewport after enlarging the window");
  testAssert (
      NSEqualRects ([editorScroll frame], [[editor tabView] contentRect]),
      @"Actual project scroll view fills the enlarged tab");
  // Switching away and back must size the formerly hidden editor as well.
  [editor openFile: second];
  [editorWindow setContentSize: NSMakeSize (1700, 1000)];
  [editor openFile: first];
  testAssert (NSWidth ([scrollingText frame]) >= NSWidth ([editorClip bounds]),
              @"Reselected source tab fills the window's new width");
  [[editor currentDocument] setContent: @"int ordinary = 42;"];
  [editor setBackgroundColor: [NSColor colorWithDeviceRed: 0.2
                                                   green: 0.4
                                                    blue: 0.7
                                                   alpha: 1.0]];
  NSTextView *textView = [[editor currentDocument] textView];
  testAssert (colorMatches ([[textView textStorage]
                                     attribute: NSForegroundColorAttributeName
                                       atIndex: 4
                                effectiveRange: NULL],
                            0.8, 0.6, 0.3),
              @"Background updates open documents");
  [editor setSyntaxHighlighting: NO];
  testAssert (colorMatches ([[textView textStorage]
                                     attribute: NSForegroundColorAttributeName
                                       atIndex: 15
                                effectiveRange: NULL],
                            0.8, 0.6, 0.3),
              @"Disabling syntax restores inverse color");
  [editor setSyntaxHighlighting: YES];
  testAssert (
      [[[textView textStorage] attribute: NSForegroundColorAttributeName
                                 atIndex: 15
                          effectiveRange: NULL]
          isEqual: [[[editor currentDocument] syntaxHighlighter] numberColor]],
      @"Enabling syntax restores token colors");
  [[editor currentDocument] setModified: NO];
  [[editor tabView] display];
  YCodeEditorDocument *selectedDocument = [editor currentDocument];
  NSString *backgroundPath =
      [[selectedDocument filePath] isEqual: first] ? second : first;
  NSTabViewItem *backgroundTab =
      [editor tabForDocument: [editor documentForFilePath: backgroundPath]];
  NSButton *closeButton = [backgroundTab closeButton];
  testAssert ([closeButton superview] == [editor tabView]
                  && ![closeButton isHidden],
              @"File tabs display a close button beside the label");
  [closeButton performClick: nil];
  testAssert ([[editor openDocuments] count] == 1 &&
                  [editor currentDocument] == selectedDocument &&
                  [editor documentForFilePath: backgroundPath] == nil,
              @"Closing a background tab preserves the selected document");
  NSTabViewItem *selectedTab = [editor tabForDocument: selectedDocument];
  [selectedDocument insertText: @"// changed\n" atLocation: 0];
  answerCloseAlert (NSAlertThirdButtonReturn);
  [[selectedTab closeButton] performClick: nil];
  testAssert ([[editor openDocuments] count] == 1 &&
                  [selectedDocument isModified],
              @"Cancel keeps the modified tab open");
  answerCloseAlert (NSAlertSecondButtonReturn);
  [[selectedTab closeButton] performClick: nil];
  testAssert ([[editor openDocuments] count] == 0 &&
                  [editor currentDocument] == nil &&
                  [[editor tabView] numberOfTabViewItems] == 0,
              @"Discard closes the last tab and clears the active editor");
  testAssert ([editor openFile: first], @"Reopen source after closing tabs");
  [editor openFile: second];
  [editor openFile: first];
  [[editor currentDocument] insertText: @"// changed\n" atLocation: 0];
  answerCloseAlert (NSAlertFirstButtonReturn);
  [[[editor tabForDocument: [editor currentDocument]] closeButton]
      performClick: nil];
  testAssert ([editor documentForFilePath: first] == nil &&
                  [[[editor currentDocument] filePath] isEqual: second],
              @"Save closes the selected tab and activates a remaining file");
  [editor closeFile: second];
  [editor openFile: first];
  [document close];
  [document release];

  // New project/document instances exercise restoration, not existing tabs.
  document = [[YCodeProject alloc] init];
  [document readFromURL: [NSURL fileURLWithPath: package]
                 ofType: @"YCodeXcodeProjectType"
                  error: NULL];
  [document makeWindowControllers];
  editor = [document editorController];
  testAssert ([[[editor currentDocument] filePath] isEqual: first] &&
                  [[editor openDocuments] count] == 1,
              @"Reopening a project restores its last source file");
  [editor openFile: second];
  [[editor tabView]
      selectTabViewItem: [editor
                            tabForDocument: [editor
                                               documentForFilePath: first]]];
  [document close];
  [document release];

  NSString *otherPackage =
      [directory stringByAppendingPathComponent: @"Other.xcodeproj"];
  [manager copyItemAtPath: package toPath: otherPackage error: NULL];
  document = [[YCodeProject alloc] init];
  [document readFromURL: [NSURL fileURLWithPath: otherPackage]
                 ofType: @"YCodeXcodeProjectType"
                  error: NULL];
  [document makeWindowControllers];
  testAssert ([[[document editorController] openDocuments] count] == 0,
              @"Source restoration is isolated to each project");
  [document close];
  [document release];

  document = [[YCodeProject alloc] init];
  [document readFromURL: [NSURL fileURLWithPath: package]
                 ofType: @"YCodeXcodeProjectType"
                  error: NULL];
  [document makeWindowControllers];
  editor = [document editorController];
  testAssert (
      [[[editor currentDocument] filePath] isEqual: first],
      @"Restoration follows the selected tab rather than the last file opened");
  [editor closeFile: first];
  [document close];
  [document release];

  document = [[YCodeProject alloc] init];
  [document readFromURL: [NSURL fileURLWithPath: package]
                 ofType: @"YCodeXcodeProjectType"
                  error: NULL];
  [document makeWindowControllers];
  testAssert ([[[document editorController] openDocuments] count] == 0,
              @"Explicitly closing the last source tab clears restoration");
  [[document editorController] openFile: first];
  [document close];
  [document release];
  [manager removeItemAtPath: first error: NULL];

  document = [[YCodeProject alloc] init];
  [document readFromURL: [NSURL fileURLWithPath: package]
                 ofType: @"YCodeXcodeProjectType"
                  error: NULL];
  [document makeWindowControllers];
  testAssert (
      [[[document editorController] openDocuments] count] == 0,
      @"A deleted remembered source file does not create an empty tab or block project loading");
  [document close];
  [document release];
}

static void
waitForBuild (YCodeBuildSystem *build, BOOL running)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 10];
  while ([deadline timeIntervalSinceNow] > 0 && [build isBusy])
    {
      if (running && [build isRunning] &&
          [[build buildOutput] rangeOfString: @"application output"].location
              != NSNotFound
          && [[build buildErrors] rangeOfString: @"application-output"].location
                 != NSNotFound)
        break;
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
    }
}

static void
writeExecutable (NSString *path, NSString *contents)
{
  [contents writeToFile: path
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  [[NSFileManager defaultManager]
      setAttributes: [NSDictionary
                        dictionaryWithObject: [NSNumber numberWithInt: 0755]
                                      forKey: NSFilePosixPermissions]
       ofItemAtPath: path
              error: NULL];
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
- (id) init
{
  if ((self = [super init]))
    {
      commands = [NSMutableString new];
      output = [NSMutableString new];
    }
  return self;
}

- (void) dealloc
{
  [commands release];
  [output release];
  [file release];
  [super dealloc];
}

- (void) debugger: (YCodeDebugger *)debugger sendCommand: (NSString *)command
{
  [commands appendString: command];
}

- (void) debugger: (YCodeDebugger *)debugger output: (NSString *)text
{
  [output appendString: text];
}

- (void) debugger: (YCodeDebugger *)debugger
    stoppedAtFile: (NSString *)path
             line: (NSUInteger)number
{
  ASSIGN (file, path);
  line = number;
}

@end

@interface YCodeDebuggerChangeProbe : NSObject
{
@public
  id sender;
  NSUInteger count;
}

- (void) changed: (NSNotification *)notification;
@end
@implementation YCodeDebuggerChangeProbe
- (void) changed: (NSNotification *)notification
{
  sender = [notification object];
  count++;
}

@end

static void
testDebuggerBundles (NSString *directory)
{
  NSString *resources = [[NSBundle mainBundle] pathForResource: @"Debuggers"
                                                        ofType: nil];
  testAssert ([resources length] > 0,
              @"Debugger bundles are packaged as application resources");
  if (!resources)
    return;
  YCodeDebuggerRegistry *registry = [[YCodeDebuggerRegistry alloc]
      initWithSearchPaths: [NSArray arrayWithObject: resources]];
  testAssert ([[registry backendIdentifiers] containsObject: @"gdb"],
              @"Discover GDB by loading its executable bundle");
  id<YCodeDebuggerBackend> backend =
      [registry newBackendWithIdentifier: @"gdb"];
  testAssert (
      backend != nil &&
          [[NSBundle bundleForClass: [backend class]] bundlePath] != nil &&
          [[[NSBundle bundleForClass: [backend class]] bundlePath]
              hasSuffix: @"GDB.bundle"],
      @"GDB implementation lives in the bundle rather than the application executable");
  YCodeDebugger *first = [[YCodeDebugger alloc] initWithBackend: backend];
  [backend release];
  YCodeDebugger *second =
      [[YCodeDebugger alloc] initWithBackendIdentifier: @"gdb"];
  testAssert ([[first displayName] isEqual: @"GDB"] &&
                  [[first backendIdentifier] isEqual: @"gdb"],
              @"Facade exposes selected backend metadata");
  [first setSourceDirectory: @"/tmp/debugger-bundle-one"];
  [second setSourceDirectory: @"/tmp/debugger-bundle-two"];
  [first toggleBreakpointAtFile: @"Example.m" line: 8];
  testAssert (
      [first breakpointStateAtFile: @"Example.m" line: 8]
              == YCodeBreakpointEnabled
          && [second breakpointStateAtFile: @"Example.m" line: 8]
                 == YCodeBreakpointNone,
      @"Separate projects retain independent backend breakpoint state");
  testAssert ([first canSetBreakpointAtFile: @"Example.m"]
                  && ![first canSetBreakpointAtFile: @"Example.h"],
              @"Breakpoint eligibility comes from selected backend");
  NSString *executable = @"/tmp/Product With Spaces.app/Product With Spaces";
  testAssert (
      [[[first launchArgumentsForExecutable: executable] lastObject]
          isEqual: executable],
      @"Backend launch arguments preserve executable paths without shell splitting");
  YCodeDebuggerProbe *probe = [YCodeDebuggerProbe new];
  YCodeDebuggerChangeProbe *changes = [YCodeDebuggerChangeProbe new];
  [[NSNotificationCenter defaultCenter]
      addObserver: changes
         selector: @selector (changed:)
             name: YCodeDebuggerDidChangeNotification
           object: first];
  [first setDelegate: probe];
  testAssert (![first canPerformAction: YCodeDebuggerRun],
              @"Run is disabled until the backend is ready");
  [first receiveData: [@"(gdb) \n" dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [first isReady] && ![second isReady] && changes->sender == first
          && changes->count > 0,
      @"Backend events preserve facade notification identity and session isolation");
  [probe->commands setString: @""];
  [first performAction: YCodeDebuggerNext];
  [first performAction: YCodeDebuggerFrameUp];
  testAssert (
      [probe->commands rangeOfString: @"-exec-next\n"].location != NSNotFound &&
          [probe->commands rangeOfString: @"-interpreter-exec console \"up\"\n"]
                  .location
              != NSNotFound,
      @"Generic step and frame actions are translated inside the GDB backend");
  [first receiveData: [@"*running,thread-id=\"all\"\n"
                         dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([first canPerformAction: YCodeDebuggerPause]
                  && ![first canPerformAction: YCodeDebuggerNext],
              @"Backend capabilities reflect running state");
  [first performAction: YCodeDebuggerPause];
  testAssert (
      [probe->commands rangeOfString: @"-exec-interrupt --all\n"].location
          != NSNotFound,
      @"Generic pause reaches backend transport");
  [first reset];
  testAssert (![first isReady] && ![first isRunning] &&
                  [first breakpointStateAtFile: @"Example.m" line: 8]
                      == YCodeBreakpointEnabled,
              @"Reset clears session state and preserves source breakpoints");
  [[NSNotificationCenter defaultCenter] removeObserver: changes];
  [first setDelegate: nil];
  [first release];
  [second release];
  [probe release];
  [changes release];
  testAssert (
      [registry newBackendWithIdentifier: @"missing-backend"] == nil,
      @"Missing explicit backend does not silently launch a different debugger");
  id saved = [[[NSUserDefaults standardUserDefaults]
      objectForKey: @"YCodeDebuggerBackend"] retain];
  [[NSUserDefaults standardUserDefaults] setObject: @"missing-backend"
                                            forKey: @"YCodeDebuggerBackend"];
  YCodeDebugger *missing = [YCodeDebugger new];
  testAssert (missing == nil,
              @"Unavailable default backend fails session creation safely");
  [missing release];
  if (saved)
    [[NSUserDefaults standardUserDefaults] setObject: saved
                                              forKey: @"YCodeDebuggerBackend"];
  else
    [[NSUserDefaults standardUserDefaults]
        removeObjectForKey: @"YCodeDebuggerBackend"];
  [saved release];

  NSString *bad = [directory stringByAppendingPathComponent: @"Invalid.bundle"];
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSError *error = nil;
  BOOL copied = [[NSFileManager defaultManager]
      copyItemAtPath: [resources stringByAppendingPathComponent: @"GDB.bundle"]
              toPath: bad
               error: &error];
  testAssert (copied, @"Prepare incompatible debugger bundle fixture");
  if (copied)
    {
      NSString *manifest =
          [[NSBundle bundleWithPath: bad] pathForResource: @"Debugger"
                                                  ofType: @"plist"];
      NSMutableDictionary *info =
          [NSMutableDictionary dictionaryWithContentsOfFile: manifest];
      [info setObject: [NSNumber numberWithInt: 99] forKey: @"APIVersion"];
      [[NSPropertyListSerialization
          dataWithPropertyList: info
                        format: NSPropertyListXMLFormat_v1_0
                       options: 0
                         error: NULL] writeToFile: manifest atomically: YES];
      testAssert (
          ![registry loadBundleAtPath: bad] &&
              [[registry backendIdentifiers] containsObject: @"gdb"],
          @"Reject incompatible debugger API before loading code, preserving working registrations");
    }
  [registry release];
}

static NSString *
variableRequestToken (YCodeDebuggerProbe *probe, NSString *fragment)
{
  NSEnumerator *lines = [[probe->commands componentsSeparatedByString: @"\n"]
      reverseObjectEnumerator];
  NSString *line;
  while ((line = [lines nextObject]) != nil)
    {
      if ([line rangeOfString: fragment].location == NSNotFound)
        continue;
      NSRange dash = [line rangeOfString: @"-"];
      if (dash.location != NSNotFound)
        return [line substringToIndex: dash.location];
    }
  testAssert (
      NO, [@"Missing variable request: " stringByAppendingString: fragment]);
  return @"0";
}
static void
variableReply (YCodeDebugger *debugger, YCodeDebuggerProbe *probe,
               NSString *command, NSString *fields)
{
  NSString *reply = [NSString
      stringWithFormat: @"%@^done%@\n", variableRequestToken (probe, command),
                       fields];
  [debugger receiveData: [reply dataUsingEncoding: NSUTF8StringEncoding]];
}
static void
testDebuggerVariables (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id savedFraction =
      [[defaults objectForKey: @"YCodeDebuggerVariablesFraction"] retain];
  id savedHidden =
      [[defaults objectForKey: @"YCodeDebuggerVariablesHidden"] retain];
  [defaults removeObjectForKey: @"YCodeDebuggerVariablesFraction"];
  [defaults removeObjectForKey: @"YCodeDebuggerVariablesHidden"];
  YCodeDebugger *debugger = [YCodeDebugger new];
  YCodeDebuggerProbe *probe = [YCodeDebuggerProbe new];
  [debugger setDelegate: probe];
  id<YCodeDebuggerVariableSource> variables = [debugger variables];
  [variables setEnabled: YES];
  [debugger
      receiveData:
          [@"(gdb)\n*stopped,reason=\"breakpoint-hit\",frame={fullname=\"/tmp/vars.c\",line=\"5\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  variableReply (debugger, probe, @"-stack-info-frame",
                 @",frame={fullname=\"/tmp/vars.c\",line=\"5\"}");
  variableReply (
      debugger, probe, @"-stack-list-variables",
      @",variables=[{name=\"counter\",value=\"3\"},{name=\"pair\",value=\"{...}\"}]");
  variableReply (
      debugger, probe, @"\"counter\"",
      @",name=\"counterObject\",numchild=\"0\",value=\"3\",type=\"int\"");
  variableReply (
      debugger, probe, @"\"pair\"",
      @",name=\"pairObject\",numchild=\"2\",value=\"{...}\",type=\"struct Pair\"");
  variableReply (
      debugger, probe, @"-symbol-info-variables",
      @",symbols={debug=[{fullname=\"/tmp/vars.c\",symbols=[{name=\"counter\",type=\"int\"}]},{fullname=\"/tmp/other.c\",symbols=[{name=\"unrelated\",type=\"int\"}]}]}");
  variableReply (debugger, probe, @"'::counter",
                 @",numchild=\"0\",value=\"7\",type=\"int\"");
  NSArray *groups = [variables groups];
  testAssert (
      [groups count] == 2 &&
          [[[groups objectAtIndex: 0] objectForKey: @"children"] count] == 2 &&
          [[[groups objectAtIndex: 1] objectForKey: @"children"] count] == 1,
      @"Variables separate locals from current-file globals");
  NSMutableDictionary *counter =
      [[[groups objectAtIndex: 0] objectForKey: @"children"] objectAtIndex: 0];
  testAssert ([[counter objectForKey: @"value"] isEqual: @"3"] &&
                  [[counter objectForKey: @"type"] isEqual: @"int"],
              @"Token routing retains variable values and types");
  NSMutableDictionary *pair =
      [[[groups objectAtIndex: 0] objectForKey: @"children"] objectAtIndex: 1];
  [variables loadChildren: pair];
  variableReply (
      debugger, probe, @"-var-list-children",
      @",children=[child={name=\"p.x\",exp=\"x\",numchild=\"0\",value=\"11\",type=\"int\"},child={name=\"p.y\",exp=\"y\",numchild=\"0\",value=\"12\",type=\"int\"}]");
  testAssert ([[pair objectForKey: @"children"] count] == 2,
              @"Expanding a structured variable loads its children");
  NSScrollView *transcript = AUTORELEASE (
      [[NSScrollView alloc] initWithFrame: NSMakeRect (0, 0, 640, 320)]);
  YCodeVariablesView *split =
      [[YCodeVariablesView alloc] initWithFrame: NSMakeRect (0, 0, 640, 320)
                                     transcript: transcript];
  [split setDebugger: debugger];
  NSOutlineView *outline = [split valueForKey: @"_outline"];
  testAssert (
      [split isVertical] && [outline gridStyleMask] == NSTableViewGridNone &&
          [[outline tableColumns] count] == 3,
      @"Debugger uses a vertical split and a grid-free three-column outline");
  [outline expandItem: pair];
  NSString *screenshot = [[[NSProcessInfo processInfo] environment]
      objectForKey: @"YCODE_VARIABLES_IMAGE"];
  if ([screenshot length])
    {
      NSWindow *window =
          [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 640, 320)
                                      styleMask: NSTitledWindowMask
                                        backing: NSBackingStoreBuffered
                                          defer: NO];
      [window setReleasedWhenClosed: NO];
      [window setContentView: split];
      [window makeKeyAndOrderFront: nil];
      [window display];
      [split lockFocus];
      NSBitmapImageRep *bitmap =
          [[NSBitmapImageRep alloc] initWithFocusedViewRect: [split bounds]];
      [split unlockFocus];
      [[bitmap representationUsingType: NSPNGFileType
                            properties: [NSDictionary dictionary]]
          writeToFile: screenshot
           atomically: YES];
      [bitmap release];
      [window setContentView: AUTORELEASE ([NSView new])];
      [window close];
      [window release];
    }
  [split setPosition: 380 ofDividerAtIndex: 0];
  CGFloat fraction = [defaults doubleForKey: @"YCodeDebuggerVariablesFraction"];
  testAssert (fraction > 0.5 && fraction < 0.7,
              @"Dragging the debugger divider saves its fraction");
  NSButton *toggle = AUTORELEASE ([NSButton new]);
  [split toggleVariables: toggle];
  testAssert (
      ![split variablesVisible]
          && NSWidth ([transcript frame]) == NSWidth ([split bounds]) &&
          [defaults boolForKey: @"YCodeDebuggerVariablesHidden"],
      @"Collapsing variables fills the split with output and persists visibility");
  YCodeVariablesView *restored = [[YCodeVariablesView alloc]
      initWithFrame: NSMakeRect (0, 0, 640, 320)
         transcript: AUTORELEASE ([NSScrollView new])];
  testAssert (![restored variablesVisible],
              @"A new debugger view restores collapsed state");
  [restored toggleVariables: toggle];
  testAssert (fabs (NSWidth ([[[restored subviews] objectAtIndex: 0] frame])
                        / (640 - [restored dividerThickness])
                    - fraction)
                  < 0.01,
              @"Reopening the variables pane restores the saved divider size");
  [restored release];
  [split toggleVariables: toggle];
  [debugger receiveData: [@"^done\n" dataUsingEncoding: NSUTF8StringEncoding]];
  NSString *stale = [variableRequestToken (probe, @"-stack-info-frame") copy];
  [debugger receiveData: [@"*running,thread-id=\"all\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  NSString *late = [NSString
      stringWithFormat:
          @"%@^done,frame={fullname=\"/tmp/vars.c\",line=\"5\"}\n", stale];
  [debugger receiveData: [late dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [[variables groups] count] == 0,
      @"Resume clears values and ignores late replies from an earlier stopped frame");
  [debugger receiveData: [@"*stopped,reason=\"end-stepping-range\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  variableReply (debugger, probe, @"-stack-info-frame",
                 @",frame={fullname=\"/tmp/other.c\",line=\"20\"}");
  testAssert ([[debugger executionFile] isEqual: @"/tmp/other.c"] &&
                  [debugger executionLine] == 20,
              @"Variable refresh uses and reports the selected stack frame");
  variableReply (debugger, probe, @"-stack-list-variables",
                 @",variables=[{name=\"missing\",value=\"<optimized out>\"}]");
  NSString *errorReply = [NSString
      stringWithFormat: @"%@^error,msg=\"Unavailable in this frame\"\n",
                       variableRequestToken (probe, @"\"missing\"")];
  [debugger receiveData: [errorReply dataUsingEncoding: NSUTF8StringEncoding]];
  NSDictionary *missing = [[[[variables groups] objectAtIndex: 0]
      objectForKey: @"children"] objectAtIndex: 0];
  testAssert (
      [[missing objectForKey: @"value"] isEqual: @"Unavailable in this frame"],
      @"Unavailable variable values are reported in the outline");
  [stale release];
  [split setDebugger: nil];
  [split release];
  [debugger release];
  [probe release];
  if (savedFraction)
    [defaults setObject: savedFraction
                 forKey: @"YCodeDebuggerVariablesFraction"];
  else
    [defaults removeObjectForKey: @"YCodeDebuggerVariablesFraction"];
  if (savedHidden)
    [defaults setObject: savedHidden forKey: @"YCodeDebuggerVariablesHidden"];
  else
    [defaults removeObjectForKey: @"YCodeDebuggerVariablesHidden"];
  [defaults synchronize];
  [savedFraction release];
  [savedHidden release];
}

static void
testDebuggerRecords (void)
{
  YCodeDebugger *debugger = [YCodeDebugger new];
  YCodeDebuggerProbe *probe = [YCodeDebuggerProbe new];
  [debugger setDelegate: probe];
  NSString *storage = [@"YCodeDebuggerTest:"
      stringByAppendingString: [[NSProcessInfo processInfo]
                                  globallyUniqueString]];
  [debugger setBreakpointStorageKey: storage];
  [debugger toggleBreakpointAtFile: @"/tmp/A \"quoted\".m" line: 4];
  YCodeDebugger *restored = [YCodeDebugger new];
  [restored setBreakpointStorageKey: storage];
  [restored setDelegate: probe];
  [restored receiveData: [@"(gdb) \n" dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [probe->commands rangeOfString: @"-break-insert"].location != NSNotFound,
      @"A new session restores project source breakpoints from preferences");
  [restored release];
  [probe->commands setString: @""];
  NSString *records
      = @"(gdb) \r\n12^done,bkpt={number=\"3\",fullname=\"/tmp/A \\\"quoted\\\".m\",line=\"4\"}\n"
        @"*running,thread-id=\"all\"\n~\"café\\n\"\n"
        @"*stopped,reason=\"breakpoint-hit\",frame={fullname=\"/tmp/A \\\"quoted\\\".m\",line=\"4\",args=[{name=\"argc\",value=\"1\"}]}\n";
  NSData *bytes = [records dataUsingEncoding: NSUTF8StringEncoding];
  NSUInteger i;
  for (i = 0; i < [bytes length]; i++)
    [debugger receiveData: [bytes subdataWithRange: NSMakeRange (i, 1)]];
  testAssert ([debugger isReady] && ![debugger isRunning],
              @"Chunked MI records update ready/running/stopped state");
  testAssert ([probe->file isEqual: @"/tmp/A \"quoted\".m"] && probe->line == 4,
              @"Escaped source paths and nested frames navigate correctly");
  testAssert ([probe->output rangeOfString: @"café\n"].location != NSNotFound &&
                  [probe->output rangeOfString: @"thread-id"].location
                      == NSNotFound,
              @"Keep split UTF-8 stream output and hide MI bookkeeping");
  testAssert (
      [probe->commands
          rangeOfString: @"-break-insert -f \"/tmp/A \\\"quoted\\\".m:4\"\n"]
              .location
          != NSNotFound,
      @"Restore prelaunch breakpoints with MI quoting");
  testAssert (
      [[debugger executionFile] isEqual: probe->file] &&
          [debugger executionLine] == 4,
      @"Breakpoint stop records the execution arrow's source location");
  [debugger toggleBreakpointEnabledAtFile: probe->file line: 4];
  testAssert ([debugger breakpointStateAtFile: probe->file line: 4]
                      == YCodeBreakpointInactive
                  && [probe->commands hasSuffix: @"-break-disable 3\n"],
              @"Disable keeps a grey source breakpoint and tells GDB");
  YCodeDebugger *disabledSession = [YCodeDebugger new];
  [disabledSession setDelegate: probe];
  [disabledSession setBreakpointStorageKey: storage];
  [disabledSession
      receiveData: [@"(gdb)\n" dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [probe->commands rangeOfString: @"-break-insert -f -d"].location
          != NSNotFound,
      @"Disabled breakpoints remain disabled when restored in a new session");
  [disabledSession release];
  [debugger toggleBreakpointEnabledAtFile: probe->file line: 4];
  testAssert ([debugger breakpointStateAtFile: probe->file line: 4]
                      == YCodeBreakpointEnabled
                  && [probe->commands hasSuffix: @"-break-enable 3\n"],
              @"Re-enable makes the breakpoint red and tells GDB");
  [debugger toggleBreakpointAtFile: probe->file line: 4];
  testAssert ([probe->commands hasSuffix: @"-break-delete 3\n"],
              @"Delete breakpoint using debugger-assigned number");
  [debugger toggleBreakpointAtFile: @"/tmp/blank.m" line: 1];
  [debugger
      receiveData:
          [@"^done,bkpt={number=\"4\",fullname=\"/tmp/blank.m\",line=\"2\",original-location=\"/tmp/blank.m:1\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [[[debugger breakpointLinesForFile: @"/tmp/blank.m"]
          objectForKey: [NSNumber numberWithInt: 2]] intValue]
              == YCodeBreakpointEnabled
          && [[debugger breakpointLinesForFile: @"/tmp/blank.m"]
                 objectForKey: [NSNumber numberWithInt: 1]]
                 == nil,
      @"Draw relocated breakpoints at the executable line rather than the requested blank line");
  [debugger toggleBreakpointAtFile: @"/tmp/blank.m" line: 1];
  testAssert (
      [probe->commands hasSuffix: @"-break-delete 4\n"],
      @"Toggling the requested line removes a breakpoint relocated by GDB");
  [debugger receiveData: [@"*running,thread-id=\"all\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([debugger executionFile] == nil && [debugger executionLine] == 0,
              @"Resuming removes the old execution arrow");
  [debugger toggleBreakpointAtFile: @"/tmp/live.m" line: 5];
  testAssert (
      [debugger isRunning] &&
          [debugger breakpointStateAtFile: @"/tmp/live.m" line: 5]
              == YCodeBreakpointEnabled
          &&
          [probe->commands hasSuffix: @"-break-insert -f \"/tmp/live.m:5\"\n"],
      @"Running programs accept new source breakpoints without pausing first");
  [debugger
      receiveData:
          [@"^done,bkpt={number=\"9\",fullname=\"/tmp/live.m\",line=\"5\",enabled=\"y\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  [debugger toggleBreakpointEnabledAtFile: @"/tmp/live.m" line: 5];
  testAssert ([debugger isRunning] &&
                  [debugger breakpointStateAtFile: @"/tmp/live.m" line: 5]
                      == YCodeBreakpointInactive
                  && [probe->commands hasSuffix: @"-break-disable 9\n"],
              @"Running programs accept breakpoint disabling");
  [debugger toggleBreakpointEnabledAtFile: @"/tmp/live.m" line: 5];
  testAssert ([debugger breakpointStateAtFile: @"/tmp/live.m" line: 5]
                      == YCodeBreakpointEnabled
                  && [probe->commands hasSuffix: @"-break-enable 9\n"],
              @"Running programs accept breakpoint re-enabling");
  [debugger toggleBreakpointAtFile: @"/tmp/live.m" line: 5];
  testAssert ([debugger isRunning] &&
                  [debugger breakpointStateAtFile: @"/tmp/live.m" line: 5]
                      == YCodeBreakpointNone
                  && [probe->commands hasSuffix: @"-break-delete 9\n"],
              @"Running programs accept breakpoint removal");
  [debugger restart];
  testAssert ([probe->commands hasSuffix: @"-exec-interrupt --all\n"],
              @"Restart interrupts a running inferior first");
  [debugger receiveData: [@"*stopped,reason=\"signal-received\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([probe->commands hasSuffix: @"-exec-run\n"],
              @"Restart waits for the stopped event before running");
  [debugger receiveData: [@"*running,thread-id=\"all\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  [debugger performAction: YCodeDebuggerPause];
  [debugger
      receiveData:
          [@"*stopped,reason=\"signal-received\",signal-name=\"SIGINT\"\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([probe->commands hasSuffix: @"-exec-interrupt --all\n"],
              @"Pause keeps an interrupted debugger session resumable");
  [debugger receiveData: [@"*running,thread-id=\"all\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  [debugger
      receiveData:
          [@"*stopped,reason=\"signal-received\",signal-name=\"SIGINT\"\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([probe->commands hasSuffix: @"-gdb-exit\n"],
              @"Manual Control-C closes the debugger session");
  [debugger receiveData: [@"9^error,msg=\"No symbol\\n\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [probe->output rangeOfString: @"Debugger error: No symbol"].location
          != NSNotFound,
      @"Display MI command failures in the console");
  NSDictionary *parsed = [NSClassFromString (@"YCodeGDBDebugger")
      parseRecord: @"24^done,stack=[frame={level=\"0\"},frame={level=\"1\"}]"];
  testAssert ([[parsed objectForKey: @"stack"] count] == 2,
              @"Parse MI result lists as well as value lists");
  [debugger setSourceDirectory: @"/tmp/Source Folder"];
  [debugger
      receiveData:
          [@"=breakpoint-created,bkpt={number=\"7\",file=\"main.c\",line=\"3\",enabled=\"y\"}\n"
           @"=breakpoint-modified,bkpt={number=\"7\",file=\"main.c\",line=\"3\",enabled=\"n\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [debugger breakpointStateAtFile: @"/tmp/Source Folder/main.c" line: 3]
          == YCodeBreakpointInactive,
      @"GDB console breakpoint changes update the correct absolute source path");
  [debugger receiveData: [@"=breakpoint-deleted,id=\"7\"\n"
                            dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([debugger breakpointStateAtFile: @"/tmp/Source Folder/main.c"
                                         line: 3]
                  == YCodeBreakpointNone,
              @"GDB deletion removes its source marker");
  [debugger toggleBreakpointAtFile: @"/tmp/later.c" line: 5];
  testAssert (
      [debugger breakpointStateAtFile: @"/tmp/later.c" line: 5]
          == YCodeBreakpointEnabled,
      @"New enabled breakpoints stay red while awaiting GDB confirmation");
  [debugger
      receiveData:
          [@"^done,bkpt={number=\"8\",addr=\"<PENDING>\",pending=\"/tmp/later.c:5\",original-location=\"/tmp/later.c:5\",enabled=\"y\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert (
      [probe->output rangeOfString: @"GDB accepted it"].location != NSNotFound
          && [probe->output rangeOfString: @"library loads after Go"].location
                 != NSNotFound,
      @"Accepted pending breakpoints explain deferred shared-library symbol loading");
  testAssert ([debugger breakpointStateAtFile: @"/tmp/later.c" line: 5]
                  == YCodeBreakpointEnabled,
              @"Enabled unresolved breakpoints remain red");
  [debugger toggleBreakpointEnabledAtFile: @"/tmp/later.c" line: 5];
  testAssert ([debugger breakpointStateAtFile: @"/tmp/later.c" line: 5]
                  == YCodeBreakpointInactive,
              @"Disabling an unresolved breakpoint makes it grey");
  [debugger toggleBreakpointEnabledAtFile: @"/tmp/later.c" line: 5];
  testAssert ([debugger breakpointStateAtFile: @"/tmp/later.c" line: 5]
                  == YCodeBreakpointEnabled,
              @"Re-enabling an unresolved breakpoint makes it red again");
  [debugger
      receiveData:
          [@"=breakpoint-modified,bkpt={number=\"8\",fullname=\"/tmp/later.c\",line=\"5\",addr=\"0x1234\",enabled=\"y\"}\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  testAssert ([debugger breakpointStateAtFile: @"/tmp/later.c" line: 5]
                  == YCodeBreakpointEnabled,
              @"Resolved breakpoints become red");
  [NSClassFromString (@"YCodeGDBDebugger") parseRecord: @"^done,bad=[garbage"];
  [debugger reset];
  testAssert (![debugger isReady] && ![debugger isRunning],
              @"Reset session state after termination");
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: storage];
  [debugger release];
  [probe release];
}

static void
waitForDebugger (YCodeBuildSystem *build)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 10];
  while ([deadline timeIntervalSinceNow] > 0 && [build isBusy]
         && ![[build debugger] isReady])
    [[NSRunLoop currentRunLoop]
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
}

static void
testResultNavigation (NSString *temporaryDirectory)
{
  NSString *root =
      [temporaryDirectory stringByAppendingPathComponent: @"Test Sources"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: root
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [@"all:\n" writeToFile: [root stringByAppendingPathComponent: @"Makefile"]
              atomically: YES
                encoding: NSUTF8StringEncoding
                   error: NULL];
  NSString *path = [root stringByAppendingPathComponent: @"Several Tests.mm"];
  NSString *source
      = @"@implementation Other\n- (void)testOne {}\n@end\n// @implementation Example - (void)testOne {} @end\n@implementation Example\n/* - (void)testOne {} */\n- (void)\ntestOne\n{ NSString *s = @\"@end\"; }\n- (void)testTwo {}\n@end\n";
  NSString *padding = [@"" stringByPaddingToLength: 200
                                        withString: @"\n"
                                   startingAtIndex: 0];
  source = [NSString stringWithFormat: @"%@%@%@", padding, source, padding];
  [source writeToFile: path
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  NSString *swiftPath =
      [root stringByAppendingPathComponent: @"SwiftTests.swift"];
  [@"class SwiftTests: XCTestCase {\n func testSwift() { }\n}\n"
      writeToFile: swiftPath
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  YCodeProject *project = [YCodeProject new];
  testAssert ([project readFromURL: [NSURL fileURLWithPath: root]
                            ofType: @"YCodeMakeProjectType"
                             error: NULL],
              @"Open test navigation fixture");
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: project];
  YCodeBuildSystem *build = [project buildSystem];
  [window buildSystemDidStartTests: build];
  [window buildSystem: build
      didReceiveOutput:
          @"Test Case '-[Example testOne]' passed.\nXCTest: Example.testTwo FAILED\nTest Case 'Module.SwiftTests.testSwift()' passed.\nTest Case '-[Missing testOne]' failed.\n"];
  [window buildSystemDidFinishTests: build success: NO];
  NSTableView *table = [window valueForKey: @"_testResultsTable"];
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
      byExtendingSelection: NO];
  YCodeEditorDocument *document = [[window editorController] currentDocument];
  NSRange expected = [source rangeOfString: @"testOne\n{"];
  testAssert (
      [[document filePath] isEqual: path]
          && NSEqualRanges ([document selectedRange],
                            NSMakeRange (expected.location, 7)),
      @"Clicking a result opens the matching class implementation and method, ignoring comments and other classes");
  NSTextView *textView = [document textView];
  NSLayoutManager *layout = [textView layoutManager];
  NSRange glyphs = [layout glyphRangeForCharacterRange: [document selectedRange]
                                  actualCharacterRange: NULL];
  NSRect methodRect =
      [layout boundingRectForGlyphRange: glyphs
                        inTextContainer: [textView textContainer]];
  CGFloat methodY = NSMidY (methodRect) + [textView textContainerOrigin].y;
  testAssert (
      fabs (methodY - NSMidY ([textView visibleRect])) < 2,
      @"Test navigation centers the method vertically in the editor viewport");
  NSString *edited = [@"// unsaved lines\n\n" stringByAppendingString: source];
  [document setContent: edited];
  [document setModified: YES];
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 1]
      byExtendingSelection: NO];
  expected = [edited rangeOfString: @"testTwo"];
  testAssert (
      NSEqualRanges ([document selectedRange], expected) &&
          [document isModified],
      @"GNUstep XCTest results navigate using unsaved editor text without discarding edits");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 2]
      byExtendingSelection: NO];
  YCodeEditorDocument *swift = [[window editorController] currentDocument];
  testAssert ([[swift filePath] isEqual: swiftPath] &&
                  [[[swift content] substringWithRange: [swift selectedRange]]
                      isEqual: @"testSwift"],
              @"Module-qualified Swift results navigate to the test method");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 3]
      byExtendingSelection: NO];
  testAssert (
      [[window editorController] currentDocument] == swift,
      @"Unresolved tests do not navigate to a different class with the same method name");
  [document setModified: NO];
  [window close];
  [window release];
  [project release];
}

static void
testSearchAndTestNavigator (NSString *temporaryDirectory)
{
  NSString *root =
      [temporaryDirectory stringByAppendingPathComponent: @"Search And Tests"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: root
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  YCodeProject *document = [YCodeProject new];
  PBXProject *project = AUTORELEASE ([PBXProject new]);
  PBXGroup *group = AUTORELEASE ([PBXGroup new]);
  [group setSourceTree: @"<group>"];
  [project setMainGroup: group];
  [document setProject: project];
  [document
      setProjectPath: [root
                         stringByAppendingPathComponent: @"Search.xcodeproj"]];
  NSString *first = [root stringByAppendingPathComponent: @"First File.m"];
  NSString *second = [root stringByAppendingPathComponent: @"Second.txt"];
  [@"one\r\nneedle NEEDLE\n" writeToFile: first
                              atomically: YES
                                encoding: NSUTF8StringEncoding
                                   error: NULL];
  [@"needle" writeToFile: second
              atomically: YES
                encoding: NSUTF8StringEncoding
                   error: NULL];
  [document addFilesToProject: [NSArray arrayWithObjects: first, second, nil]];
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: document];
  [window showWindow: nil];
  NSSearchField *field = [window valueForKey: @"_projectSearchField"];
  [field setStringValue: @"needle"];
  [window searchProject: nil];
  NSArray *results = [window valueForKey: @"_searchResults"];
  testAssert ([results count] == 3,
              @"Search includes every occurrence in all project text files");
  NSTableView *table = [window valueForKey: @"_searchResultsTable"];
  NSTabView *navigatorTabs = [window valueForKey: @"_navigatorTabView"];
  [navigatorTabs selectTabViewItemWithIdentifier: @"search"];
  NSScrollView *resultsScroll = [table enclosingScrollView];
  NSView *searchView = [[navigatorTabs selectedTabViewItem] view];
  testAssert (
      fabs (NSMaxY ([resultsScroll frame])
            - (NSHeight ([searchView bounds]) - 62))
              < 2
          && NSHeight ([resultsScroll frame]) > 100,
      @"Search results viewport fills the area directly below the controls");
  NSRect firstRow = [table convertRect: [table rectOfRow: 0] toView: searchView];
  testAssert (fabs (NSMaxY (firstRow) - NSMaxY ([resultsScroll frame])) < 5,
              @"The first search result appears at the top of the viewport");
  testAssert ([table gridStyleMask] == NSTableViewGridNone,
              @"Search results have no grid");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
      byExtendingSelection: NO];
  YCodeEditorDocument *editorDocument =
      [[window editorController] currentDocument];
  testAssert (
      [[editorDocument filePath] isEqual: first]
          && NSEqualRanges ([editorDocument selectedRange],
                            NSMakeRange (5, 6)),
      @"Search selection opens the matching source range across CRLF lines");
  [editorDocument setContent: @"unsaved needle"];
  [window searchProject: nil];
  testAssert ([results count] == 2, @"Search uses unsaved editor contents");
  [field setStringValue: @""];
  [window searchProject: nil];
  testAssert ([results count] == 0,
              @"Clearing search removes previous matches");

  YCodeBuildSystem *build = [document buildSystem];
  [window buildSystemDidStartTests: build];
  [window buildSystem: build
      didReceiveOutput: @"Test Case '-[Example testOne]' sta"];
  [window buildSystem: build
      didReceiveOutput:
          @"rted.\nTest Case '-[Example testOne]' passed (0.1 seconds).\n"];
  [window buildSystem: build
      didReceiveError: @"Test Case '-[Example testTwo]' failed (0.2 seconds)."];
  [window buildSystemDidFinishTests: build success: NO];
  NSArray *tests = [window valueForKey: @"_testResults"];
  testAssert (
      [tests count] == 2 &&
          [[[tests objectAtIndex: 0] objectForKey: @"status"] isEqual: @"Passed"]
          &&
          [[[tests objectAtIndex: 1] objectForKey: @"status"] isEqual: @"Failed"],
      @"XCTest results merge start/finish and drain split output and unterminated stderr");

#ifdef GNUSTEP
  PBXNativeTarget *target = AUTORELEASE ([PBXNativeTarget new]);
  [target setName: @"Unit Tests"];
  [target setProductType: @"com.apple.product-type.bundle.unit-test"];
  [target setProductReference: AUTORELEASE ([[PBXFileReference alloc]
                                  initWithPath: @"Unit Tests.xctest"])];
  [project setTargets: [NSMutableArray arrayWithObject: target]];
  [build
      setEnvironmentVariable: [root stringByAppendingString: @":/usr/bin:/bin"]
                      forKey: @"PATH"];
  writeExecutable (
      [root stringByAppendingPathComponent: @"buildtool"],
      @"#!/bin/sh\nif [ \"$MODE\" = buildfail ]; then exit 1; fi\nexit 0\n");
  writeExecutable (
      [root stringByAppendingPathComponent: @"xctest"],
      @"#!/bin/sh\nprintf '%s\n' \"$@\"\necho \"XCTest:     Example.testRun PASSED\" >&2\n"
      @"if [ \"$MODE\" = testfail ]; then exit 1; fi\n");
  testAssert ([build test] && ![build test],
              @"Test runner rejects concurrent runs");
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusSuccess && [tests count] == 1,
      @"Test operation builds then runs XCTest and replaces previous results");
  testAssert (
      [[build buildOutput]
          rangeOfString: [NSString stringWithFormat:
                                      @"build/%@/Products/Unit Tests.xctest",
                                      [target name]]]
              .location
          != NSNotFound,
      @"XCTest receives the bundle path including spaces");
  [build setEnvironmentVariable: @"testfail" forKey: @"MODE"];
  [build test];
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusFailed,
              @"Runner exit failure is preserved");
  [build setEnvironmentVariable: @"buildfail" forKey: @"MODE"];
  [build test];
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusFailed && [tests count] == 1 &&
          [[[tests objectAtIndex: 0] objectForKey: @"name"] isEqual: @"Test run"],
      @"Build failure prevents test execution and displays a startup failure");

  PBXNativeTarget *host = AUTORELEASE ([PBXNativeTarget new]);
  [host setName: @"Host App"];
  [host setProductType: @"com.apple.product-type.application"];
  [host setProductReference: AUTORELEASE ([[PBXFileReference alloc]
                                initWithPath: @"Host App.app"])];
  PBXTargetDependency *dependency = AUTORELEASE ([PBXTargetDependency new]);
  [dependency setTarget: host];
  [target setDependencies: [NSMutableArray arrayWithObject: dependency]];
  XCBuildConfiguration *config = AUTORELEASE ([[XCBuildConfiguration alloc]
       initWithName: @"Debug"
      buildSettings: [NSMutableDictionary
                        dictionaryWithObject:
                            @"$(BUILT_PRODUCTS_DIR)/Host App.app/Host App"
                                      forKey: @"TEST_HOST"]]);
  [target setBuildConfigurationList:
              AUTORELEASE ([[XCConfigurationList alloc]
                  initWithConfigurations: [NSMutableArray
                                             arrayWithObject: config]])];
  [project setTargets: [NSMutableArray arrayWithObjects: host, target, nil]];
  NSString *hostDirectory =
      [root stringByAppendingPathComponent:
                [NSString stringWithFormat: @"build/%@/Products/Host App.app",
                                           [host name]]];
  [manager createDirectoryAtPath: hostDirectory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *hostExecutable =
      [hostDirectory stringByAppendingPathComponent: @"Host App"];
  writeExecutable (
      hostExecutable,
      @"#!/bin/sh\nprintf '%s\n' \"$@\"\necho \"XCTest:     Hosted.testRun PASSED\" >&2\n");
  [build setEnvironmentVariable: @"hosted" forKey: @"MODE"];
  [document updateChangeCount: NSChangeCleared];
  NSTabView *tabs = [window valueForKey: @"_navigatorTabView"];
  [tabs selectTabViewItemWithIdentifier: @"test"];
  NSEnumerator *controls =
      [[[[tabs selectedTabViewItem] view] subviews] objectEnumerator];
  NSView *control;
  while ((control = [controls nextObject]) != nil)
    if ([control isKindOfClass: [NSButton class]])
      [(NSButton *)control performClick: nil];
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusSuccess && [tests count] == 1 &&
          [[[tests objectAtIndex: 0] objectForKey: @"name"]
              isEqual: @"Hosted.testRun"],
      @"Run Tests button executes hosted tests inside the application");
  testAssert (
      [[build buildOutput] rangeOfString: @"-GSAppKitUserBundles"].location
              != NSNotFound
          &&
          [[build buildOutput] rangeOfString: @"YCodeTestHost.bundle"].location
              != NSNotFound
          && [[build buildOutput] rangeOfString: @"-YCodeTestBundle"].location
                 != NSNotFound,
      @"Hosted execution passes the embedded helper and test bundle as distinct arguments");
  [manager removeItemAtPath: hostExecutable error: NULL];
  [build test];
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusFailed && [tests count] == 1 &&
                  [[[tests objectAtIndex: 0] objectForKey: @"display"]
                      rangeOfString: @"host application"]
                          .location
                      != NSNotFound,
              @"Missing test hosts produce visible startup errors");
#endif
  [window setProject: nil];
  testAssert ([tests count] == 0 && [results count] == 0,
              @"Project changes clear navigator results");
  [window close];
  [window release];
  [document release];
}

static void
testArchitectureSelection (NSString *temporaryDirectory)
{
  NSString *directory = [temporaryDirectory
      stringByAppendingPathComponent: @"Architecture Project"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: directory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [@"ARCH = make-default\nall:\n\t@echo arch=$(ARCH) toolchain=$$YCODE_TOOLCHAIN_TEST\n"
      writeToFile: [directory stringByAppendingPathComponent: @"Makefile"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  YCodeProject *project = [YCodeProject new];
  [project readFromURL: [NSURL fileURLWithPath: directory]
                ofType: @"YCodeMakeProjectType"
                 error: NULL];
  YCodeWindowController *window = [YCodeWindowController new];
  [window setProject: project];
  NSToolbar *toolbar = [[window window] toolbar];
  NSArray *identifiers = [[toolbar items] valueForKey: @"itemIdentifier"];
  NSUInteger index = [identifiers indexOfObject: @"architecture"];
  testAssert (index != NSNotFound
                  && index == [identifiers indexOfObject: @"scheme"] + 1,
              @"Architecture selector is immediately after Target");
  if (index == NSNotFound)
    {
      [window close];
      [window release];
      [project release];
      return;
    }
  NSUInteger statusIndex = [identifiers indexOfObject: @"buildStatus"];
  testAssert (
      statusIndex == index + 1 && statusIndex + 1 < [identifiers count] &&
          [[identifiers objectAtIndex: statusIndex + 1]
              isEqual: NSToolbarSeparatorItemIdentifier],
      @"Project status follows Architecture with a separator after it");
  NSTextField *statusField = statusIndex == NSNotFound
                                 ? nil
                                 : (NSTextField *)[[[toolbar items]
                                       objectAtIndex: statusIndex] view];
  testAssert (
      [[statusField stringValue] isEqual: @"Architecture Project - Ready - —"],
      @"Status starts with the project name and Ready before any build");
  NSPopUpButton *selector
      = (NSPopUpButton *)[[[toolbar items] objectAtIndex: index] view];
  YCodeBuildSystem *build = [project buildSystem];
  testAssert ([build architecture] == nil &&
                  [selector indexOfSelectedItem] == 0,
              @"Architecture defaults to Native");
  NSString *native = [YCodeBuildSystem hostArchitecture];
  [selector selectItemWithTitle: native];
  [selector sendAction: [selector action] to: [selector target]];
  testAssert ([[build architecture] isEqual: native] && [build build],
              @"Toolbar architecture selection starts a native build");
  testAssert (
      [[statusField stringValue] rangeOfString: @" - Building - "].location
          != NSNotFound,
      @"Status changes immediately when a build starts");
  waitForBuild (build, NO);
  testAssert (
      [[statusField stringValue] hasPrefix: @"Architecture Project - Ready - "]
          && [[statusField stringValue] hasSuffix: @"s"],
      @"Completed build displays Ready and elapsed build seconds");
  NSString *completedStatus = [[statusField stringValue] copy];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
  testAssert ([[statusField stringValue] isEqual: completedStatus],
              @"Elapsed build time stops advancing when the build finishes");
  [completedStatus release];
  testAssert ([build status] == YCodeBuildStatusSuccess &&
                  [[build buildOutput]
                      rangeOfString: [@"arch=" stringByAppendingString: native]]
                          .location
                      != NSNotFound,
              @"Architecture reaches make as a command-line variable");
  NSString *foreign = [native isEqual: @"arm64"] ? @"x86_64" : @"arm64";
  [selector selectItemWithTitle: foreign];
  [selector sendAction: [selector action] to: [selector target]];
  testAssert (
      ![build build] && [build status] == YCodeBuildStatusFailed &&
          [[build buildErrors] rangeOfString: @"toolchain"].location
              != NSNotFound,
      @"An unconfigured cross-build fails instead of silently using the host toolchain");
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
  testAssert (
      [[statusField stringValue] rangeOfString: @" - Failed - "].location
          != NSNotFound,
      @"Failed build appears in the toolbar status");
  NSDictionary *environment =
      [NSDictionary dictionaryWithObject: @"selected"
                                  forKey: @"YCODE_TOOLCHAIN_TEST"];
  [[NSDictionary
      dictionaryWithObject: [NSDictionary dictionaryWithObject: environment
                                                       forKey: foreign]
                    forKey: @"ArchitectureEnvironments"]
      writeToFile: [directory stringByAppendingPathComponent: @".ycode.plist"]
       atomically: YES];
  testAssert ([build build],
              @"Configured architecture environment can launch make");
  waitForBuild (build, NO);
  testAssert (
      [[build buildOutput]
          rangeOfString: [NSString
                            stringWithFormat: @"arch=%@ toolchain=selected",
                                             foreign]]
              .location
          != NSNotFound,
      @"Selected architecture and its environment reach the build process");
  YCodeProject *reopened = [YCodeProject new];
  [reopened setProjectPath: directory];
  testAssert ([[[reopened buildSystem] architecture] isEqual: foreign],
              @"Architecture is persisted per project");
  [reopened release];
  [selector selectItemAtIndex: 0];
  [selector sendAction: [selector action] to: [selector target]];
  testAssert ([build build],
              @"Native remains available after a cross-toolchain selection");
  waitForBuild (build, NO);
  testAssert (
      [[build buildOutput] rangeOfString: @"arch=make-default toolchain=\n"]
                  .location
              != NSNotFound
          && [[build buildEnvironment] objectForKey: @"YCODE_TOOLCHAIN_TEST"]
                 == nil,
      @"Returning to Native restores original arguments and environment without leaking overrides");
  [@"all:\n\t@sleep 1\nclean:\n\t@echo cleaned\ntest:\n\t@echo tested\n"
      writeToFile: [directory stringByAppendingPathComponent: @"Makefile"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  testAssert ([build clean], @"Status fixture can start cleaning");
  testAssert (
      [[statusField stringValue] rangeOfString: @" - Cleaning - "].location
          != NSNotFound,
      @"Cleaning appears in toolbar status");
  waitForBuild (build, NO);
  testAssert ([build build], @"Status fixture can start a timed build");
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.25]];
  testAssert (
      [[statusField stringValue] rangeOfString: @" - Building - "].location
              != NSNotFound
          && ![[statusField stringValue] hasSuffix: @"0.0s"],
      @"Build elapsed time advances live");
  [build stop];
  testAssert (
      [[statusField stringValue] rangeOfString: @" - Cancelled - "].location
          != NSNotFound,
      @"Stopped builds show Cancelled");
  waitForBuild (build, NO);
  [window setProject: nil];
  testAssert ([[statusField stringValue] isEqual: @"No Project - Ready - —"],
              @"Closing a project clears its status and duration");
  [window close];
  [window release];
  [project release];
}

static void
testNavigatorFolderOrder (void)
{
  YCodeProject *document = [[YCodeProject alloc] init];
  PBXProject *project = AUTORELEASE ([PBXProject new]);
  PBXGroup *root = AUTORELEASE ([PBXGroup new]);
  PBXGroup *first = AUTORELEASE ([PBXGroup new]);
  PBXGroup *second = AUTORELEASE ([PBXGroup new]);
  PBXGroup *nested = AUTORELEASE ([PBXGroup new]);
  PBXFileReference *a
      = AUTORELEASE ([[PBXFileReference alloc] initWithPath: @"a.c"]);
  PBXFileReference *b
      = AUTORELEASE ([[PBXFileReference alloc] initWithPath: @"b.c"]);
  PBXFileReference *c
      = AUTORELEASE ([[PBXFileReference alloc] initWithPath: @"c.c"]);
  [first setName: @"Z Sources"];
  [second setName: @"Y Resources"];
  [nested setName: @"Nested"];
  NSMutableArray *original =
      [NSMutableArray arrayWithObjects: a, first, b, second, nil];
  [root setChildren: original];
  [first setChildren: [NSMutableArray arrayWithObjects: c, nested, nil]];
  [project setMainGroup: root];
  [document setProject: project];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  [navigator projectDidChange];
  NSArray *expected = [NSArray arrayWithObjects: first, second, a, b, nil];
  NSUInteger pass;
  for (pass = 0; pass < 2; pass++)
    {
      NSArray *items = [[navigator itemForObject: root] children];
      testAssert (
          [[items valueForKey: @"representedObject"] isEqual: expected],
          @"Navigator puts folders before files and preserves order within each kind");
      testAssert ([[[[navigator itemForObject: first] children]
                      valueForKey: @"representedObject"]
                      isEqual: [NSArray arrayWithObjects: nested, c, nil]],
                  @"Navigator puts folders first inside nested groups too");
      testAssert (
          [[root children]
              isEqual: [NSArray arrayWithObjects: a, first, b, second, nil]],
          @"Navigator sorting does not reorder the stored project");
      [navigator projectDidChange];
    }
  [navigator setProject: nil];
  [document release];
}

static void
testNavigatorContextMenu (YCodeProject *project)
{
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  NSMenu *menu = [[navigator outlineView] menu];
  BOOL current = menu != nil && menu == [navigator contextMenu];
  testAssert (current,
              @"Navigator context menu follows the project's controller");
  if (!current)
    return; // Do not message a stale menu's deallocated targets.
  NSEnumerator *items = [[menu itemArray] objectEnumerator];
  NSMenuItem *item;
  while ((item = [items nextObject]) != nil)
    {
      if (![item isSeparatorItem])
        testAssert ([item target] == navigator,
                    @"Navigator menu actions target the live controller");
    }
  [menu update];
  testAssert (
      [[menu itemAtIndex: 0] isEnabled] == [project isDirectoryProject],
      @"Context menu validates Refresh Folder against the current project");
}

static void
testMakefileOpening (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  NSEnumerator *names =
      [[NSArray arrayWithObjects: @"GNUmakefile", @"makefile", @"Makefile", nil]
          objectEnumerator];
  NSString *name;
  while ((name = [names nextObject]) != nil)
    {
      NSString *directory = [temporaryDirectory
          stringByAppendingPathComponent: [@"Direct Makefile With Spaces "
                                             stringByAppendingString: name]];
      [manager createDirectoryAtPath: directory
          withIntermediateDirectories: YES
                           attributes: nil
                                error: NULL];
      NSString *path = [directory stringByAppendingPathComponent: name];
      NSString *contents = @"all:\n\t@echo direct-makefile-build\n";
      [contents writeToFile: path
                 atomically: YES
                   encoding: NSUTF8StringEncoding
                      error: NULL];
      NSError *error = nil;
      NSURL *url = [NSURL fileURLWithPath: path];
      NSURL *folderURL = [NSURL fileURLWithPath: directory];
      YCodeProject *project =
          [controller openDocumentWithContentsOfURL: url
                                            display: YES
                                              error: &error];
      testAssert (project != nil && error == nil &&
                      [project isDirectoryProject],
                  @"Open a makefile directly as a directory project");
      if (project == nil)
        continue;
      testAssert (
          [[project fileURL] isEqual: folderURL] &&
              [[project projectDirectoryPath] isEqual: directory] &&
              [[project windowControllers] count] > 0,
          @"Direct makefile opening displays a window rooted at the containing folder");
      testAssert ([controller openDocumentWithContentsOfURL: folderURL
                                                    display: YES
                                                      error: &error]
                          == project
                      && [controller openDocumentWithContentsOfURL: url
                                                           display: YES
                                                             error: &error]
                             == project,
                  @"Opening the folder and makefile reuses the same project");
      YCodeBuildSystem *build = [project buildSystem];
      testAssert ([build build],
                  @"Start a build after opening a makefile directly");
      waitForBuild (build, NO);
      testAssert (
          [[build buildOutput] rangeOfString: @"direct-makefile-build"].location
              != NSNotFound,
          @"Direct makefile project builds in its containing directory");
      testAssert ([[NSString stringWithContentsOfFile: path
                                             encoding: NSUTF8StringEncoding
                                                error: NULL] isEqual: contents],
                  @"Opening and building preserves the original makefile");
      [project close];
    }
  NSString *unsupported =
      [temporaryDirectory stringByAppendingPathComponent: @"Not A Project.txt"];
  [@"plain text" writeToFile: unsupported
                  atomically: YES
                    encoding: NSUTF8StringEncoding
                       error: NULL];
  NSError *error = nil;
  testAssert (
      [controller
          openDocumentWithContentsOfURL: [NSURL fileURLWithPath: unsupported]
                                display: YES
                                  error: &error]
              == nil
          && error != nil,
      @"Unsupported project selections report an error");
}

static YCodeProjectNavigatorItem *
directoryItem (YCodeProjectNavigatorController *navigator,
               YCodeProjectNavigatorItem *parent, NSString *path)
{
  if ([[navigator resolvedPathForNavigatorItem: parent] isEqual: path])
    return parent;
  NSEnumerator *children = [[parent children] objectEnumerator];
  YCodeProjectNavigatorItem *child;
  while ((child = [children nextObject]) != nil)
    {
      YCodeProjectNavigatorItem *found
          = directoryItem (navigator, child, path);
      if (found)
        return found;
    }
  return nil;
}

static void
testSynchronizedNavigator (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root = [temporaryDirectory
      stringByAppendingPathComponent: @"Synchronized Project"];
  NSString *package =
      [root stringByAppendingPathComponent: @"Example.xcodeproj"];
  NSString *sources = [root stringByAppendingPathComponent: @"Sources/Nested"];
  [manager createDirectoryAtPath: package
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [manager createDirectoryAtPath: sources
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *source = [sources stringByAppendingPathComponent: @"Example.m"];
  [@"int example;\n" writeToFile: source
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
  NSString *projectFile =
      [package stringByAppendingPathComponent: @"project.pbxproj"];
  [@"{ archiveVersion = 1; objectVersion = 77; objects = { ROOT = { isa = PBXProject; mainGroup = MAIN; targets = (); }; MAIN = { isa = PBXGroup; children = (SYNC); sourceTree = \"<group>\"; }; SYNC = { isa = PBXFileSystemSynchronizedRootGroup; path = Sources; sourceTree = SOURCE_ROOT; }; }; rootObject = ROOT; }"
      writeToFile: projectFile
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  NSString *workingDirectory = [manager currentDirectoryPath];
  YCodeProject *document = [[YCodeProject alloc] init];
  testAssert (
      [document readFromURL: [NSURL fileURLWithPath: package]
                     ofType: @"YCodeXcodeProjectType"
                      error: NULL],
      @"Load filesystem-synchronized Xcode project from another working directory");
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  [navigator projectDidChange];
  YCodeProjectNavigatorItem *tree = [[navigator rootItems] objectAtIndex: 0];
  YCodeProjectNavigatorItem *item = directoryItem (navigator, tree, source);
  testAssert (
      item != nil &&
          [[item representedObject] isKindOfClass: [PBXFileReference class]],
      @"Synchronized folders expose nested source references in the navigator");
  testAssert ([[document editorController]
                  openFile: [navigator resolvedFilePathForNavigatorItem: item]],
              @"Synchronized source opens using its project-relative path");
  testAssert (
      [[manager currentDirectoryPath] isEqual: workingDirectory],
      @"Loading synchronized folders leaves the process working directory unchanged");
  PBXGroup *group =
      [[[[document project] mainGroup] children] objectAtIndex: 0];
  testAssert (
      [[[navigator itemForObject: group] displayName] isEqual: @"Sources"],
      @"Unnamed synchronized folder displays its directory name");
  testAssert (
      [[group children] count] == 0,
      @"Navigator discovery does not add references to the serialized group");
  NSString *added = [sources stringByAppendingPathComponent: @"Added.h"];
  [@"/* added */" writeToFile: added
                   atomically: YES
                     encoding: NSUTF8StringEncoding
                        error: NULL];
  [manager removeItemAtPath: source error: NULL];
  [navigator projectDidChange];
  tree = [[navigator rootItems] objectAtIndex: 0];
  testAssert (
      directoryItem (navigator, tree, added) != nil
          && directoryItem (navigator, tree, source) == nil,
      @"Refreshing synchronized navigator discovers additions and removals");
  testAssert ([document saveProjectToPath: package],
              @"Save synchronized project");
  NSDictionary *saved =
      [NSDictionary dictionaryWithContentsOfFile: projectFile];
  NSEnumerator *objects =
      [[[saved objectForKey: @"objects"] allValues] objectEnumerator];
  NSDictionary *object;
  BOOL found = NO;
  while ((object = [objects nextObject]) != nil)
    {
      if ([[object objectForKey: @"isa"]
              isEqual: @"PBXFileSystemSynchronizedRootGroup"])
        {
          found = YES;
          testAssert (
              [[object objectForKey: @"path"] isEqual: @"Sources"] &&
                  [[object objectForKey: @"children"] count] == 0,
              @"Saving preserves the dynamic folder and its relative path");
        }
      testAssert (![[object objectForKey: @"path"] isEqual: @"Added.h"],
                  @"Saving does not serialize discovered navigator files");
    }
  testAssert (found, @"Saved project retains its synchronized group type");
  [document close];
  [document release];
}

static YCodeProjectNavigatorItem *
waitForDirectoryItem (YCodeProject *project, NSString *path, BOOL present)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 3];
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  YCodeProjectNavigatorItem *item;
  do
    {
      item = directoryItem (navigator, [[navigator rootItems] objectAtIndex: 0],
                            path);
      if ((item != nil) == present)
        return item;
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
    }
  while ([deadline timeIntervalSinceNow] > 0);
  return item;
}

static void
testFileWatchingPreference (NSString *temporaryDirectory)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved = [[defaults objectForKey: @"YCodeFileWatchingEnabled"] retain];
  [defaults removeObjectForKey: @"YCodeFileWatchingEnabled"];
  testAssert ([YCodePreferences fileWatchingEnabled],
              @"File watching defaults to enabled");
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root = [temporaryDirectory
      stringByAppendingPathComponent: @"Watching Preference"];
  [manager createDirectoryAtPath: root
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *file = [root stringByAppendingPathComponent: @"existing.txt"];
  [@"original" writeToFile: file
                atomically: YES
                  encoding: NSUTF8StringEncoding
                     error: NULL];
  YCodeProject *project = [YCodeProject new];
  [project readFromURL: [NSURL fileURLWithPath: root]
                ofType: @"YCodeMakeProjectType"
                 error: NULL];
  YCodeEditorController *editor = [project editorController];
  [editor openFile: file];
  testAssert ([[project valueForKey: @"directoryWatchers"] count] > 0 &&
                  [[editor valueForKey: @"fileWatchers"] count] > 0,
              @"Default preference starts directory and editor watchers");
  AppController *app = [AppController new];
  [app showPrefPanel: nil];
  NSPopUpButton *groups = [app valueForKey: @"_preferencesGroup"];
  [groups selectItemAtIndex: 1];
  [groups sendAction: [groups action] to: [groups target]];
  NSButton *checkbox = [app valueForKey: @"_fileWatchingCheckbox"];
  testAssert ([checkbox state] == NSOnState
                  && ![[checkbox superview] isHidden],
              @"Editor preferences exposes file watching enabled by default");
  [checkbox performClick: nil];
  testAssert (
      ![YCodePreferences fileWatchingEnabled]
          && ![defaults boolForKey: @"YCodeFileWatchingEnabled"] &&
          [[project valueForKey: @"directoryWatchers"] count] == 0 &&
          [[editor valueForKey: @"fileWatchers"] count] == 0,
      @"Disabling file watching saves the setting and stops both kinds of watcher");
  NSString *added = [root stringByAppendingPathComponent: @"added.txt"];
  [@"new" writeToFile: added
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  [@"external" writeToFile: file
                atomically: YES
                  encoding: NSUTF8StringEncoding
                     error: NULL];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]];
  testAssert (
      waitForDirectoryItem (project, added, NO) == nil &&
          [[[editor currentDocument] content] isEqual: @"original"],
      @"Disabled watchers leave the navigator and open file unchanged");
  YCodeProject *disabledProject = [YCodeProject new];
  [disabledProject readFromURL: [NSURL fileURLWithPath: root]
                        ofType: @"YCodeMakeProjectType"
                         error: NULL];
  [[disabledProject editorController] openFile: file];
  testAssert (
      waitForDirectoryItem (disabledProject, added, YES) != nil &&
          [[disabledProject valueForKey: @"directoryWatchers"] count] == 0 &&
          [[[disabledProject editorController] valueForKey: @"fileWatchers"]
              count]
              == 0,
      @"Projects opened with watching disabled still load files without creating watchers");
  [disabledProject close];
  [checkbox performClick: nil];
  testAssert (
      waitForDirectoryItem (project, added, YES) != nil &&
          [[[editor currentDocument] content] isEqual: @"external"] &&
          [[project valueForKey: @"directoryWatchers"] count] > 0 &&
          [[editor valueForKey: @"fileWatchers"] count] > 0,
      @"Reenabling watching catches up folder and editor changes immediately");
  testAssert ([[disabledProject valueForKey: @"directoryWatchers"] count] == 0
                  && [[[disabledProject editorController]
                         valueForKey: @"fileWatchers"] count]
                         == 0,
              @"Changing the preference does not restart closed projects");
  [disabledProject release];
  [project close];
  [project release];
  [[app valueForKey: @"_preferencesPanel"] close];
  [app release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeFileWatchingEnabled"];
  else
    [defaults removeObjectForKey: @"YCodeFileWatchingEnabled"];
  [saved release];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeFileWatchingPreferencesDidChangeNotification
                    object: nil];
}

static void
testDirectoryWatching (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root =
      [temporaryDirectory stringByAppendingPathComponent: @"Watched Folder"];
  NSString *nested = [root stringByAppendingPathComponent: @"Nested"];
  [manager createDirectoryAtPath: nested
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *existing = [nested stringByAppendingPathComponent: @"existing.txt"];
  [@"existing" writeToFile: existing
                atomically: YES
                  encoding: NSUTF8StringEncoding
                     error: NULL];
  YCodeProject *project = [[YCodeProject alloc] init];
  testAssert ([project readFromURL: [NSURL fileURLWithPath: root]
                            ofType: @"YCodeMakeProjectType"
                             error: NULL],
              @"Open a directory without editor tabs for monitoring");
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  NSOutlineView *outline =
      [[NSOutlineView alloc] initWithFrame: NSMakeRect (0, 0, 300, 400)];
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: @"files"];
  [outline addTableColumn: column];
  [outline setOutlineTableColumn: column];
  [column release];
  [navigator setOutlineView: outline];
  [outline expandItem: [navigator itemForObject: [[project project] mainGroup]]];
  [outline expandItem: waitForDirectoryItem (project, nested, YES)];
  [navigator selectItem: waitForDirectoryItem (project, existing, YES)];
  NSString *added = [nested stringByAppendingPathComponent: @"added.txt"];
  [@"new" writeToFile: added
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  testAssert (
      waitForDirectoryItem (project, added, YES) != nil,
      @"Navigator automatically discovers additions in existing subfolders");
  testAssert (
      [outline isItemExpanded: waitForDirectoryItem (project, nested, YES)],
      @"Directory refresh preserves expanded folders");
  testAssert ([[navigator resolvedFilePathForNavigatorItem:
                              [outline itemAtRow: [outline selectedRow]]]
                  isEqual: existing],
              @"Directory refresh preserves the selected file");
  NSString *renamed = [nested stringByAppendingPathComponent: @"renamed.txt"];
  [manager moveItemAtPath: added toPath: renamed error: NULL];
  testAssert (waitForDirectoryItem (project, renamed, YES) != nil
                  && waitForDirectoryItem (project, added, NO) == nil,
              @"Navigator automatically reflects file renames");
  [manager removeItemAtPath: renamed error: NULL];
  testAssert (waitForDirectoryItem (project, renamed, NO) == nil,
              @"Navigator automatically removes deleted files");
  NSString *newFolder = [root stringByAppendingPathComponent: @"New Folder"];
  [manager createDirectoryAtPath: newFolder
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  testAssert (waitForDirectoryItem (project, newFolder, YES) != nil,
              @"Navigator discovers new folders");
  NSString *newFile = [newFolder stringByAppendingPathComponent: @"later.txt"];
  [@"later" writeToFile: newFile
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  testAssert (waitForDirectoryItem (project, newFile, YES) != nil,
              @"New folders are watched for subsequent additions");
  [manager removeItemAtPath: newFolder error: NULL];
  testAssert (waitForDirectoryItem (project, newFolder, NO) == nil,
              @"Navigator removes deleted folders");
  testAssert (![project isDocumentEdited],
              @"External directory changes do not dirty the project");
  [project close];
  testAssert ([[project valueForKey: @"directoryWatchers"] count] == 0,
              @"Closing a directory project stops all directory watchers");
  [navigator setOutlineView: nil];
  [outline release];
  [project release];
}

static void
testLargeDirectoryWatching (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root = [temporaryDirectory
      stringByAppendingPathComponent: @"Large Watched Folder"];
  NSUInteger index;
  for (index = 0; index < 160; index++)
    {
      NSString *folder = [root
          stringByAppendingPathComponent: [NSString
                                             stringWithFormat: @"folder-%03lu",
                                                              (unsigned long)
                                                                  index]];
      [manager createDirectoryAtPath: folder
          withIntermediateDirectories: YES
                           attributes: nil
                                error: NULL];
    }
  NSString *wide = [root stringByAppendingPathComponent: @"folder-000"];
  for (index = 0; index < 2000; index++)
    [manager
        createFileAtPath: [wide stringByAppendingPathComponent:
                                   [NSString
                                       stringWithFormat: @"file-%04lu.txt",
                                                        (unsigned long)index]]
                contents: [NSData data]
              attributes: nil];
  NSString *imagePath = [root stringByAppendingPathComponent: @"Preview.png"];
  NSBitmapImageRep *bitmap =
      [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                              pixelsWide: 1024
                                              pixelsHigh: 768
                                           bitsPerSample: 8
                                         samplesPerPixel: 4
                                                hasAlpha: YES
                                                isPlanar: NO
                                          colorSpaceName: NSDeviceRGBColorSpace
                                             bytesPerRow: 0
                                            bitsPerPixel: 0];
  memset ([bitmap bitmapData], 128,
          [bitmap bytesPerRow] * [bitmap pixelsHigh]);
  [[bitmap representationUsingType: NSPNGFileType
                        properties: [NSDictionary dictionary]]
      writeToFile: imagePath
       atomically: YES];
  [bitmap release];
  YCodeProject *project = [[YCodeProject alloc] init];
  testAssert (
      [project readFromURL: [NSURL fileURLWithPath: root]
                    ofType: @"YCodeMakeProjectType"
                     error: NULL],
      @"Open more directories than the usual Linux inotify instance limit");
#if defined(__linux__)
  NSDictionary *watchers = [project valueForKey: @"directoryWatchers"];
  testAssert ([watchers count] == 161 &&
                  [[NSSet setWithArray: [watchers allValues]] count] == 1,
              @"All project directories share a single Linux watcher");
#endif
  YCodeProjectNavigatorController *navigator = [project navigatorController];
  NSString *untouchedPath =
      [root stringByAppendingPathComponent: @"folder-000"];
  PBXGroup *untouched = [[waitForDirectoryItem (project, untouchedPath, YES)
      representedObject] retain];
  NSArray *listing = [[untouched children] retain];
  testAssert ([listing count] == 2000,
              @"Wide directories retain every file in the navigator");
  YCodeThumbnailTestNavigator *previews = [YCodeThumbnailTestNavigator new];
  [previews setProject: project];
  testAssert (
      [previews thumbnailRequests] == 0,
      @"Building a navigator does not load previews for undisplayed files");
  YCodeProjectNavigatorItem *preview = directoryItem (
      previews, [[previews rootItems] objectAtIndex: 0], imagePath);
  NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier: @"name"];
  NSCell *cell = [[NSCell alloc] initImageCell: nil];
  [previews outlineView: nil
        willDisplayCell: cell
         forTableColumn: column
                   item: preview];
  [previews outlineView: nil
        willDisplayCell: cell
         forTableColumn: column
                   item: preview];
  testAssert ([previews thumbnailRequests] == 1,
              @"Displaying a row loads its preview once per refresh");
  NSBitmapImageRep *pixels =
      [NSBitmapImageRep imageRepWithData: [[preview icon] TIFFRepresentation]];
  testAssert (
      [pixels pixelsWide] == 16 && [pixels pixelsHigh] == 12 &&
          [[pixels colorAtX: 8 y: 8] alphaComponent] > 0,
      @"Large previews retain only downsampled pixels with their original proportions");

  [cell release];
  [column release];
  [previews release];

  NSString *lastFolder = [root stringByAppendingPathComponent: @"folder-159"];
  NSString *added = [lastFolder stringByAppendingPathComponent: @"added.txt"];
  [@"new" writeToFile: added
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  testAssert (waitForDirectoryItem (project, added, YES) != nil,
              @"Directories beyond the old watcher limit receive updates");
  testAssert (
      [waitForDirectoryItem (project, untouchedPath, YES) representedObject]
              == untouched
          && [untouched children] == listing,
      @"A change in another folder preserves the unchanged directory listing");
  YCodeProjectNavigatorItem *fileItem =
      [waitForDirectoryItem (project, added, YES) retain];
  NSString *second = [lastFolder stringByAppendingPathComponent: @"second.txt"];
  [@"second" writeToFile: second
              atomically: YES
                encoding: NSUTF8StringEncoding
                   error: NULL];
  testAssert (waitForDirectoryItem (project, second, YES) != nil
                  && waitForDirectoryItem (project, added, YES) == fileItem,
              @"Directory updates reuse navigator items for unchanged files");
  NSString *renamed = [root stringByAppendingPathComponent: @"Renamed Folder"];
  [manager moveItemAtPath: lastFolder toPath: renamed error: NULL];
  testAssert (waitForDirectoryItem (
                  project,
                  [renamed stringByAppendingPathComponent: @"added.txt"],
                  YES) != nil
                  && waitForDirectoryItem (project, lastFolder, NO) == nil,
              @"Renaming a watched directory updates its subtree");
  NSString *later = [renamed stringByAppendingPathComponent: @"later.txt"];
  [@"later" writeToFile: later
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  testAssert (waitForDirectoryItem (project, later, YES) != nil,
              @"A renamed directory continues receiving notifications");
  [fileItem release];
  [listing release];
  [untouched release];
  [project close];
  [navigator setOutlineView: nil];
  [project release];
}

static void
testMakeDirectory (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *directory = [temporaryDirectory
      stringByAppendingPathComponent: @"Make Folder With Spaces"];
  [manager createDirectoryAtPath: [directory
                                     stringByAppendingPathComponent: @"Sources"]
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *makefile
      = @"all:\n\t@echo default-build\ncustom:\n\t@echo custom-build\nclean:\n\t@echo folder-clean\ntest:\n\t@echo folder-tests\n";
  NSString *makePath = [directory stringByAppendingPathComponent: @"makefile"];
  [makefile writeToFile: makePath
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
  [@"int main(void) { return 0; }"
      writeToFile: [directory stringByAppendingPathComponent: @"Sources/main.c"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [manager createSymbolicLinkAtPath: [directory
                                        stringByAppendingPathComponent: @"loop"]
                withDestinationPath: directory
                              error: NULL];
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  NSError *error = nil;
  NSURL *url = [NSURL fileURLWithPath: directory];
  testAssert ([[controller typeForContentsOfURL: url error: &error]
                  isEqual: @"YCodeMakeProjectType"],
              @"Detect a directory containing a lowercase makefile");
  YCodeProject *project = [controller openDocumentWithContentsOfURL: url
                                                            display: YES
                                                              error: &error];
  testAssert (project != nil && [project isDirectoryProject] && error == nil,
              @"Open a Makefile directory through the document controller");
  if (!project)
    return;
  testNavigatorContextMenu (project);
  YCodeWindowController *menuWindow = [[YCodeWindowController alloc] init];
  YCodeProject *otherProject = [[YCodeProject alloc] init];
  [menuWindow setProject: otherProject];
  testNavigatorContextMenu (otherProject);
  YCodeProject *nextProject = [[YCodeProject alloc] init];
  [menuWindow setProject: nextProject];
  testNavigatorContextMenu (nextProject);
  [menuWindow close];
  [menuWindow release];
  [otherProject release];
  [nextProject release];
  testAssert ([[project projectDirectoryPath] isEqual: directory],
              @"Make commands use the selected directory");
  PBXGroup *group = [[project project] mainGroup];
  testAssert (
      [[group children] count] == 3,
      @"Navigator includes files, subdirectories and non-recursive symlinks");
  testAssert ([[[[[project navigatorController] itemForObject: group] children]
                  objectAtIndex: 0] isGroup],
              @"Makefile navigator displays directories before files");
  testAssert (
      [project addGroupToProject: @"New Folder"] &&
          [manager fileExistsAtPath: [directory stringByAppendingPathComponent:
                                                   @"New Folder"]],
      @"Adding a directory-project group creates a real folder");
  [@"new" writeToFile: [directory stringByAppendingPathComponent: @"new.txt"]
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
  [project refreshDirectoryFiles];
  testAssert ([[[[project project] mainGroup] children] count] == 5,
              @"Refresh discovers externally added files");
  NSString *settingsPath =
      [directory stringByAppendingPathComponent: @".ycode.plist"];
  BOOL wasEdited = [project isDocumentEdited];
  AppController *app = AUTORELEASE ([[AppController alloc] init]);
  [app buildMainMenu];
  NSMenuItem *createItem
      = (NSMenuItem *)[[[[NSApp mainMenu] itemWithTitle: @"File"] submenu]
          itemWithTitle: @"Create .ycode.plist"];
  testAssert (createItem != nil &&
                  [createItem action] == @selector (createProjectSettings:) &&
                  [createItem target] == app,
              @"File menu contains the create-settings action");
  testAssert ([project canCreateSettingsFile],
              @"Makefile folder permits creating missing settings");
  [[project settings] setObject: @"preserved" forKey: @"CustomSetting"];
  NSString *appBundle =
      [directory stringByAppendingPathComponent: @"Applications/Example.app"];
  [manager createDirectoryAtPath:
               [appBundle stringByAppendingPathComponent: @"Resources"]
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [[NSDictionary dictionaryWithObject: @"ActualExecutable"
                               forKey: @"NSExecutable"]
      writeToFile: [appBundle stringByAppendingPathComponent:
                                 @"Resources/Info-gnustep.plist"]
       atomically: YES];
  writeExecutable (
      [appBundle stringByAppendingPathComponent: @"ActualExecutable"],
      @"#!/bin/sh\nexit 0\n");
  testAssert ([project createSettingsFile: &error],
              @"Create directory project settings");
  NSDictionary *createdSettings =
      [NSDictionary dictionaryWithContentsOfFile: settingsPath];
  testAssert (
      [[createdSettings objectForKey: @"Executable"]
          isEqual: @"Applications/Example.app/ActualExecutable"],
      @"Generated settings include the actual executable inside a nested application bundle");
  [[project settings] setObject: @"custom/path" forKey: @"Executable"];
  testAssert ([[project settingsExecutablePath] isEqual: @"custom/path"],
              @"Explicit executable settings are preserved");
  [[project settings] removeObjectForKey: @"Executable"];
  NSString *secondApp =
      [directory stringByAppendingPathComponent: @"Other.app"];
  [manager createDirectoryAtPath: secondApp
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  writeExecutable ([secondApp stringByAppendingPathComponent: @"Other"],
                   @"#!/bin/sh\nexit 0\n");
  testAssert ([project settingsExecutablePath] == nil,
              @"Multiple applications require an executable selection");
  [manager removeItemAtPath: secondApp error: NULL];
  [manager removeItemAtPath: appBundle error: NULL];
  NSString *toolDirectory = [directory stringByAppendingPathComponent: @"obj"];
  [manager createDirectoryAtPath: toolDirectory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  writeExecutable (
      [toolDirectory stringByAppendingPathComponent: @"ExampleTool"],
      @"#!/bin/sh\nexit 0\n");
  testAssert ([[project settingsExecutablePath] isEqual: @"obj/ExampleTool"],
              @"Discover a compiled directory-project tool");
  testAssert (
      [[createdSettings objectForKey: @"CleanTarget"] isEqual: @"clean"] &&
          [[createdSettings objectForKey: @"TestTarget"] isEqual: @"test"] &&
          [[createdSettings objectForKey: @"CustomSetting"]
              isEqual: @"preserved"],
      @"Created settings preserve current values and make target defaults");
  NSData *originalSettings = [NSData dataWithContentsOfFile: settingsPath];
  testAssert (![project canCreateSettingsFile]
                  && ![project createSettingsFile: NULL] &&
                  [[NSData dataWithContentsOfFile: settingsPath]
                      isEqual: originalSettings],
              @"Creating settings never replaces an existing file");
  testAssert ([project isDocumentEdited] == wasEdited,
              @"Creating settings preserves document change state");
  YCodeProject *nativeProject = [[YCodeProject alloc] init];
  [nativeProject
      setProjectPath: [directory
                         stringByAppendingPathComponent: @"Native.xcodeproj"]];
  testAssert (
      ![nativeProject canCreateSettingsFile]
          && ![nativeProject createSettingsFile: NULL],
      @"Native projects do not offer directory project settings creation");
  [nativeProject release];
  NSString *pcDirectory =
      [temporaryDirectory stringByAppendingPathComponent: @"PC Settings"];
  [manager createDirectoryAtPath: pcDirectory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  YCodeProject *pcProject = [[YCodeProject alloc] init];
  NSString *pcSettingsPath =
      [pcDirectory stringByAppendingPathComponent: @".ycode.plist"];
  NSString *pcPath =
      [pcDirectory stringByAppendingPathComponent: @"Example.pcproj"];
  [manager createDirectoryAtPath: pcPath
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [pcProject setProjectPath: pcPath];
  PBXProject *pcModel = AUTORELEASE ([[PBXProject alloc] init]);
  PBXNativeTarget *pcTarget = AUTORELEASE ([[PBXNativeTarget alloc] init]);
  [pcTarget setName: @"Example"];
  [pcTarget setProductType: @"com.apple.product-type.application"];
  [pcTarget setProductReference: AUTORELEASE ([[PBXFileReference alloc]
                                    initWithPath: @"Example.app"])];
  [pcModel setTargets: [NSMutableArray arrayWithObject: pcTarget]];
  [pcProject setProject: pcModel];
  [[pcProject settings]
      setObject: [NSDictionary dictionaryWithObject: @"Example"
                                            forKey: @"PROJECTNAME"]
         forKey: @"ProjectCenterMetadata"];
  testAssert (
      [pcProject canCreateSettingsFile] &&
          [pcProject createSettingsFile: &error] &&
          [manager fileExistsAtPath: pcSettingsPath]
          && ![manager fileExistsAtPath: [pcPath stringByAppendingPathComponent:
                                                    @".ycode.plist"]],
      @"ProjectCenter settings are created beside the package");
  testAssert (
      [[[NSDictionary dictionaryWithContentsOfFile: pcSettingsPath]
          objectForKey: @"Executable"] isEqual: @"Example.app/Example"],
      @"An unbuilt ProjectCenter application supplies its expected executable path");
  testAssert (
      [[NSDictionary dictionaryWithContentsOfFile: pcSettingsPath]
          objectForKey: @"ProjectCenterMetadata"]
              == nil
          &&
          [[pcProject settings] objectForKey: @"ProjectCenterMetadata"] != nil,
      @"Settings omit internal import metadata while preserving it in the project");
  testAssert (![pcProject canCreateSettingsFile],
              @"Existing ProjectCenter settings disable creation");
  [manager removeItemAtPath: pcSettingsPath error: NULL];
  NSString *flatPath =
      [pcDirectory stringByAppendingPathComponent: @"Flat.pcproj"];
  [@"{}" writeToFile: flatPath
          atomically: YES
            encoding: NSUTF8StringEncoding
               error: NULL];
  [pcProject setProjectPath: flatPath];
  testAssert ([pcProject canCreateSettingsFile] &&
                  [pcProject createSettingsFile: &error] &&
                  [manager fileExistsAtPath: pcSettingsPath],
              @"Flat ProjectCenter projects also support settings creation");
  [pcProject release];
  YCodeBuildSystem *build = [project buildSystem];
  testAssert ([build build], @"Start a directory make build");
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusSuccess &&
                  [[build buildOutput] rangeOfString: @"default-build"].location
                      != NSNotFound,
              @"Directory default make target runs successfully");
  [build setTargetName: @"custom"];
  testAssert ([build build], @"Start a selected make target");
  waitForBuild (build, NO);
  testAssert ([[build buildOutput] rangeOfString: @"custom-build"].location
                  != NSNotFound,
              @"Make honors the target selector");
  testAssert ([build clean], @"Start make clean");
  waitForBuild (build, NO);
  testAssert ([[build buildOutput] rangeOfString: @"folder-clean"].location
                  != NSNotFound,
              @"Make clean runs in the folder");
  testAssert ([build test], @"Start make tests");
  waitForBuild (build, NO);
  testAssert ([[build buildOutput] rangeOfString: @"folder-tests"].location
                  != NSNotFound,
              @"Make test runs in the folder");
  writeExecutable ([directory stringByAppendingPathComponent: @"run tool"],
                   @"#!/bin/sh\necho folder-run\n");
  [[project settings] setObject: @"run tool" forKey: @"Executable"];
  [[project settings]
      setObject: [NSArray arrayWithObjects: @"all", @"custom", nil]
         forKey: @"MakeTargets"];
  [[project settings] setObject: @"custom" forKey: @"BuildTarget"];
  testAssert ([build run], @"Run a configured make executable");
  waitForBuild (build, NO);
  testAssert ([[build buildOutput] rangeOfString: @"folder-run"].location
                  != NSNotFound,
              @"Configured executable runs after building");
  testAssert ([project writeSafelyToURL: url
                                 ofType: @"YCodeMakeProjectType"
                       forSaveOperation: NSSaveOperation
                                  error: &error],
              @"Saving folder settings does not replace the source directory");
  testAssert (
      [[NSString stringWithContentsOfFile: makePath
                                 encoding: NSUTF8StringEncoding
                                    error: NULL] isEqual: makefile]
          && ![manager
              fileExistsAtPath:
                  [directory stringByAppendingPathExtension: @"xcodeproj"]],
      @"Makefiles remain unchanged and no Xcode project is generated");
  [project close];
  project = [controller openDocumentWithContentsOfURL: url
                                              display: NO
                                                error: &error];
  testAssert (
      [[[project settings] objectForKey: @"Executable"] isEqual: @"run tool"] &&
          [[[project project] targets] count] == 2,
      @"Reopening restores make targets and executable settings");
  [project close];
  NSString *gnuPath =
      [directory stringByAppendingPathComponent: @"GNUmakefile"];
  [@"all:\n\t@echo gnu-build\ncheck:\n\t@echo gnu-tests\n"
      writeToFile: gnuPath
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  [manager removeItemAtPath: settingsPath error: NULL];
  project = [controller openDocumentWithContentsOfURL: url
                                              display: NO
                                                error: &error];
  testAssert (
      [project createSettingsFile: &error] &&
          [[[project settings] objectForKey: @"TestTarget"] isEqual: @"check"],
      @"GNUmakefile settings default to the check target");
  build = [project buildSystem];
  testAssert ([[build detectedBuildSystem] isEqual: @"gnumake"] && [build test],
              @"GNUmakefile selects the GNUstep check target");
  waitForBuild (build, NO);
  testAssert ([[build buildOutput] rangeOfString: @"gnu-tests"].location
                  != NSNotFound,
              @"GNUmakefile tests run with make check");
  [project close];
  testAssert (![YCodeProject
                  isMakeProjectDirectory:
                      [directory stringByAppendingPathComponent: @"Sources"]],
              @"Reject folders without a makefile");
}

static void
testBuildAndRun (NSString *temporaryDirectory)
{
  NSString *root =
      [temporaryDirectory stringByAppendingPathComponent: @"Build With Spaces"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: root
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  YCodeProject *document = [[YCodeProject alloc] init];
  PBXProject *project = AUTORELEASE ([[PBXProject alloc] init]);
  PBXNativeTarget *target = AUTORELEASE ([[PBXNativeTarget alloc] init]);
  [target setName: @"RunTarget"];
  [target setProductType: @"com.apple.product-type.application"];
  [target setProductReference: AUTORELEASE ([[PBXFileReference alloc]
                                  initWithPath: @"Run Product.app"])];
  PBXNativeTarget *otherTarget = AUTORELEASE ([PBXNativeTarget new]);
  [otherTarget setName: @"OtherTarget"];
  [otherTarget setProductType: @"com.apple.product-type.tool"];
  [project
      setTargets: [NSMutableArray arrayWithObjects: target, otherTarget, nil]];
  [document setProject: project];
  [document setProjectPath: [root stringByAppendingPathComponent:
                                     @"Run Project.xcodeproj"]];
  YCodeBuildSystem *build = [document buildSystem];
  [build
      setEnvironmentVariable: [root stringByAppendingString: @":/usr/bin:/bin"]
                      forKey: @"PATH"];
#ifdef GNUSTEP
  NSString *tool = [root stringByAppendingPathComponent: @"buildtool"];
#else
  NSString *tool = [root stringByAppendingPathComponent: @"xcodebuild"];
#endif
  writeExecutable (
      tool,
      @"#!/bin/sh\nprintf '%s\\n' \"$@\"\necho build-error >&2\n"
      @"if [ \"$MODE\" = fail ]; then exit 3; fi\n"
      @"if [ \"$MODE\" = slow ]; then echo waiting; sleep 30; touch unwanted; fi\n"
      @"mkdir -p 'build/RunTarget/Products/Run Product.app'\n"
      @"cp runner 'build/RunTarget/Products/Run Product.app/Run Product'\n");
  writeExecutable (
      [root stringByAppendingPathComponent: @"runner"],
      @"#!/bin/sh\necho application-output >&2\necho 'application output'\n"
      @"if [ \"$MODE\" = interrupt ]; then kill -INT $$; fi\n"
      @"if [ \"$MODE\" = run-fail ]; then exit 2; fi\n"
      @"if [ \"$MODE\" = exit ]; then exit 0; fi\nexec sleep 30\n");
  // An executable in the source directory must never be mistaken for the product.
  writeExecutable ([root stringByAppendingPathComponent: @"unrelated"],
                   @"#!/bin/sh\ntouch unwanted\n");
  YCodeWindowController *window = [[YCodeWindowController alloc] init];
  [window setProject: document];
  [window showWindow: nil];
  NSToolbar *toolbar = [[window window] toolbar];
  NSToolbarItem *targetItem = nil;
  NSEnumerator *items = [[toolbar items] objectEnumerator];
  NSToolbarItem *candidate;
  while ((candidate = [items nextObject]) != nil)
    if ([[candidate itemIdentifier] isEqual: @"scheme"])
      targetItem = candidate;
  NSPopUpButton *selector = (NSPopUpButton *)[targetItem view];
  NSArray *toolbarIdentifiers =
      [[toolbar items] valueForKey: @"itemIdentifier"];
  NSUInteger targetPosition = [toolbarIdentifiers indexOfObject: @"scheme"];
  testAssert (
      targetPosition != NSNotFound && targetPosition > 0 &&
          [[toolbarIdentifiers objectAtIndex: targetPosition - 1]
              isEqual: NSToolbarSeparatorItemIdentifier],
      @"Target selector follows the toolbar separator after restoring the layout");
  testAssert ([selector isKindOfClass: [NSPopUpButton class]] &&
                  [selector numberOfItems] == 3,
              @"Toolbar offers Automatic and each project target");
  [selector selectItemAtIndex: 1];
  [selector sendAction: [selector action] to: [selector target]];
  testAssert ([[build targetName] isEqual: @"RunTarget"],
              @"Target dropdown selects the build and run target");
  [window runProject: nil];
  testAssert ([build isBuilding], @"Play starts an asynchronous build");
  testAssert (![selector isEnabled],
              @"Target selection is disabled during a build");
  testAssert (![build run] && ![build build],
              @"Reject duplicate operations while busy");
  waitForBuild (build, YES);
  testAssert ([build isRunning],
              @"Successful build launches the named application product");
  testAssert (
      [[build buildOutput] rangeOfString: [document projectPath]].location
          != NSNotFound,
      @"Build arguments preserve project paths containing spaces");
  testAssert ([[build buildOutput] rangeOfString: @"RunTarget"].location
                  != NSNotFound,
              @"Build selects the runnable target");
  testAssert (
      [[build buildErrors] rangeOfString: @"build-error"].location != NSNotFound
          && [[build buildErrors] rangeOfString: @"application-output"].location
                 != NSNotFound,
      @"Drain stderr from both the build and application");
  NSTextView *console = [window valueForKey: @"_consoleTextView"];
  testAssert ([[console string] rangeOfString: @"application output"].location
                  != NSNotFound,
              @"Window console receives live process output");
  [window stopProject: nil];
  waitForBuild (build, NO);
  testAssert (![build isBusy] && [build status] == YCodeBuildStatusIdle,
              @"Stop finishes the application session like a normal exit");
  testAssert (
      [selector isEnabled],
      @"Completion enables target selection without another UI action");
  testAssert ([[console string] hasSuffix: @"Project exited.\n"],
              @"Stop reports normal run completion after draining output");
  [build setEnvironmentVariable: @"interrupt" forKey: @"MODE"];
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert (![build isBusy] && [build status] == YCodeBuildStatusIdle &&
                  [selector isEnabled] &&
                  [[console string] hasSuffix: @"Project exited.\n"],
              @"Control-C finishes a run and restores the controls");
  [build setEnvironmentVariable: @"run-fail" forKey: @"MODE"];
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusFailed,
              @"Other nonzero application exits still report failure");
  [build setEnvironmentVariable: @"" forKey: @"MODE"];
  [selector selectItemAtIndex: 2];
  [selector sendAction: [selector action] to: [selector target]];
  [window buildProject: nil];
  waitForBuild (build, NO);
  testAssert (
      [[build buildOutput] rangeOfString: @"OtherTarget"].location != NSNotFound
          && [[build buildOutput] rangeOfString: @"application output"].location
                 == NSNotFound,
      @"Build-only uses the target chosen in the toolbar without launching a product");
  [selector selectItemAtIndex: 0];
  [selector sendAction: [selector action] to: [selector target]];
  testAssert ([build targetName] == nil && [build scheme] == nil,
              @"Automatic restores the default target selection");
  if ([[[NSProcessInfo processInfo] arguments]
          containsObject: @"--check-target-toolbar"])
    {
      [window close];
      [window release];
      [document close];
      [document release];
      return;
    }
  [build setEnvironmentVariable: @"fail" forKey: @"MODE"];
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusFailed &&
          [[build buildOutput] rangeOfString: @"application output"].location
              == NSNotFound,
      @"Failed build never launches a stale product");
  [build setEnvironmentVariable: @"slow" forKey: @"MODE"];
  [window runProject: nil];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 5];
  while ([deadline timeIntervalSinceNow] > 0 &&
         [[build buildOutput] rangeOfString: @"waiting"].location == NSNotFound)
    [[NSRunLoop currentRunLoop]
        runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
  [window stopProject: nil];
  waitForBuild (build, NO);
  testAssert (![build isBusy] && [build status] == YCodeBuildStatusCancelled,
              @"Stop cancels an active build including its child process");
  testAssert (
      ![manager
          fileExistsAtPath: [root stringByAppendingPathComponent: @"unwanted"]],
      @"Cancellation prevents remaining build steps and unrelated scripts never run");
  [build setEnvironmentVariable: @"exit" forKey: @"MODE"];
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusIdle &&
          [[build buildOutput] rangeOfString: @"application output"].location
              != NSNotFound,
      @"Play works again after cancellation and drains output before finishing");
  [window buildProject: nil];
  waitForBuild (build, NO);
  testAssert (
      [build status] == YCodeBuildStatusSuccess &&
          [[build buildOutput] rangeOfString: @"application output"].location
              == NSNotFound,
      @"Build alone does not run the application");
  [build setEnvironmentVariable: @"/nonexistent" forKey: @"PATH"];
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusFailed &&
                  [[build buildErrors] length] > 0,
              @"Missing build tools fail with console diagnostics");
  [build
      setEnvironmentVariable: [root stringByAppendingString: @":/usr/bin:/bin"]
                      forKey: @"PATH"];
  [document setProjectPath:
                [root stringByAppendingPathComponent: @"Run Project.pcproj"]];
  [@"# fixture"
      writeToFile: [root stringByAppendingPathComponent: @"CMakeLists.txt"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  writeExecutable (
      [root stringByAppendingPathComponent: @"cmake"],
      @"#!/bin/sh\nif [ \"$1\" = -S ]; then sleep 0.1; touch build/CMakeCache.txt; echo configured; "
      @"else test -f build/CMakeCache.txt || exit 4; echo compiled; fi\n");
  [window runProject: nil];
  waitForBuild (build, NO);
  testAssert ([build status] == YCodeBuildStatusIdle &&
                  [[build buildOutput] rangeOfString: @"configured"].location
                      != NSNotFound
                  && [[build buildOutput] rangeOfString: @"compiled"].location
                         != NSNotFound,
              @"CMake configuration finishes before building and running");
  // Exercise the actual asynchronous build/MI transport without requiring GDB on CI.
  id savedDebuggerPath = [[[NSUserDefaults standardUserDefaults]
      objectForKey: @"DebuggerPath"] retain];
  NSString *fakeGDB = [root stringByAppendingPathComponent: @"fake gdb"];
  writeExecutable (
      fakeGDB,
      @"#!/bin/sh\nprintf '%s\\n' \"$@\" > debugger-arguments\n"
      @"printf '(gdb) \\n'\nwhile IFS= read -r command; do\n"
      @"printf '%s\\n' \"$command\" >> debugger-commands\n"
      @"case \"$command\" in\n-exec-run) printf '*running,thread-id=\"all\"\\n*stopped,reason=\"exited-normally\"\\n';;\n"
      @"-gdb-exit) exit 0;;\n*) printf '^done\\n';;\nesac\ndone\n");
  [[NSUserDefaults standardUserDefaults] setObject: fakeGDB
                                            forKey: @"DebuggerPath"];
  NSString *breakpointStorage =
      [@"YCodeDebuggerUITest:" stringByAppendingString: root];
  [[build debugger] setBreakpointStorageKey: breakpointStorage];
  NSUInteger session;
  for (session = 0; session < 2; session++)
    {
      [window debugProject: nil];
      waitForDebugger (build);
      testAssert ([build isDebugging] && [[build debugger] isReady],
                  @"Build and start a fresh debugger session");
      NSTabView *bottomTabs = [window valueForKey: @"_bottomTabView"];
      testAssert (
          [[[bottomTabs selectedTabViewItem] identifier] isEqual: @"debugger"],
          @"Starting GDB selects its dedicated tab");
      NSTextView *debugOutput = [window valueForKey: @"_debuggerTextView"];
      testAssert (
          [[debugOutput string] rangeOfString: @"Debugger ready"].location
                  != NSNotFound
              && [[console string] rangeOfString: @"Debugger ready"].location
                     == NSNotFound,
          @"Debugger output goes to its own transcript instead of the program console");
      NSString *source = [root stringByAppendingPathComponent: @"gutter.c"];
      [@"// first\nint main(void) {\n  return 0;\n}\n"
          writeToFile: source
           atomically: YES
             encoding: NSUTF8StringEncoding
                error: NULL];
      [[window editorController] openFile: source];
      YCodeEditorDocument *editorDocument =
          [[window editorController] currentDocument];
      YCEditorRulerView *ruler
          = (YCEditorRulerView *)[[editorDocument scrollView]
              verticalRulerView];
      testAssert (
          [ruler debugGutterVisible] && [ruler ruleThickness] == 72,
          @"Active debugger adds a clickable gutter to a newly opened source file");
      NSTextView *sourceView = [editorDocument textView];
      NSLayoutManager *layout = [sourceView layoutManager];
      NSUInteger glyph = [layout glyphRangeForCharacterRange: NSMakeRange (9, 1)
                                        actualCharacterRange: NULL]
                             .location;
      NSRect fragment = [layout lineFragmentRectForGlyphAtIndex: glyph
                                                 effectiveRange: NULL];
      NSPoint point = [ruler
          convertPoint: NSMakePoint (0, [sourceView textContainerOrigin].y
                                           + NSMidY (fragment))
              fromView: sourceView];
      point.x = 10;
      testAssert ([ruler sourceLineAtPoint: point] == 2,
                  @"Gutter hit testing uses source line layout");
      NSPoint clickPoint = [ruler convertPoint: point toView: nil];
      NSEvent *click =
          [NSEvent mouseEventWithType: NSLeftMouseDown
                             location: clickPoint
                        modifierFlags: 0
                            timestamp: 0
                         windowNumber: [[window window] windowNumber]
                              context: nil
                          eventNumber: 0
                           clickCount: 1
                             pressure: 1];
      [ruler mouseDown: click];
      testAssert ([[build debugger] breakpointStateAtFile: source line: 2]
                      != YCodeBreakpointNone,
                  @"Clicking the gutter creates a breakpoint in that file");
      NSString *response = [NSString
          stringWithFormat:
              @"^done,bkpt={number=\"9\",fullname=%@,line=\"2\",enabled=\"y\"}\n"
              @"*stopped,reason=\"breakpoint-hit\",frame={fullname=%@,line=\"2\"}\n",
              [NSClassFromString (@"YCodeGDBDebugger") quote: source],
              [NSClassFromString (@"YCodeGDBDebugger") quote: source]];
      [[build debugger]
          receiveData: [response dataUsingEncoding: NSUTF8StringEncoding]];
      testAssert ([[build debugger] executionLine] == 2 &&
                      [[[build debugger] executionFile] isEqual: source],
                  @"Stopped source and breakpoint share the gutter line");
      click = [NSEvent mouseEventWithType: NSLeftMouseDown
                                 location: clickPoint
                            modifierFlags: NSShiftKeyMask
                                timestamp: 0
                             windowNumber: [[window window] windowNumber]
                                  context: nil
                              eventNumber: 0
                               clickCount: 1
                                 pressure: 1];
      [ruler mouseDown: click];
      testAssert ([[build debugger] breakpointStateAtFile: source line: 2]
                      == YCodeBreakpointInactive,
                  @"Shift-click disables the breakpoint without deleting it");
      [[build debugger] toggleBreakpointAtFile: source line: 2];
      testAssert (![build debug] && ![build run],
                  @"Debug session excludes competing builds and runs");
      [[build debugger] performAction: YCodeDebuggerRun];
      [[build debugger] performAction: YCodeDebuggerStop];
      waitForBuild (build, NO);
      testAssert (![build isBusy] && ![build isDebugging]
                      && ![[build debugger] isReady],
                  @"Debugger exit drains pipes and permits another session");
      testAssert (
          [[build buildOutput] rangeOfString: @"exited-normally"].location
              != NSNotFound,
          @"MI transport reports inferior exit");
    }
  NSString *arguments =
      [NSString stringWithContentsOfFile:
                    [root stringByAppendingPathComponent: @"debugger-arguments"]
                                encoding: NSUTF8StringEncoding
                                   error: NULL];
  testAssert (
      [arguments rangeOfString: @"--interpreter=mi2\n"].location != NSNotFound
          &&
          [arguments rangeOfString: @"Run Product.app/Run Product\n"].location
              != NSNotFound,
      @"Launch GDB in MI mode with the resolved bundle executable as one argument");
  [window debugProject: nil];
  waitForDebugger (build);
  [window stopProject: nil];
  waitForBuild (build, NO);
  testAssert (![build isBusy] && [build status] == YCodeBuildStatusIdle &&
                  [selector isEnabled] &&
                  [[console string] hasSuffix: @"Project exited.\n"],
              @"Stop closes a debugger session");
  [window debugProject: nil];
  waitForDebugger (build);
  [[build debugger]
      receiveData:
          [@"*stopped,reason=\"signal-received\",signal-name=\"SIGINT\"\n"
              dataUsingEncoding: NSUTF8StringEncoding]];
  waitForBuild (build, NO);
  testAssert (
      ![build isBusy] && ![build isDebugging] &&
          [build status] == YCodeBuildStatusIdle && [selector isEnabled],
      @"Manual debugger interrupt finishes the session and restores controls");
  [[NSUserDefaults standardUserDefaults] setObject: @"/missing/ycode-gdb"
                                            forKey: @"DebuggerPath"];
  [window debugProject: nil];
  waitForBuild (build, NO);
  testAssert (
      ![build isDebugging] && [build status] == YCodeBuildStatusFailed,
      @"Missing debugger reports failure and releases session resources");
  if (savedDebuggerPath)
    [[NSUserDefaults standardUserDefaults] setObject: savedDebuggerPath
                                              forKey: @"DebuggerPath"];
  else
    [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"DebuggerPath"];
  [savedDebuggerPath release];
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: breakpointStorage];
  [build setTargetName: @"MissingTarget"];
  testAssert (
      ![build run] && ![build isBusy],
      @"Missing runnable targets fail without launching another product");
  [build setTargetName: nil];
  [document setProjectPath: nil];
  testAssert (![build build] && ![build isBusy],
              @"Missing project paths do not leave the build busy");
  [window setProject: nil];
  [window close];
  [window release];
  [document close];
  [document release];
}

static void
testBuildIssuesPane (NSString *temporaryDirectory)
{
  [[NSFileManager defaultManager] createDirectoryAtPath: temporaryDirectory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id savedIssueColors = [[defaults objectForKey: @"YCodeIssueColors"] retain];
  [YCodePreferences resetIssueColors];
  testAssert (
      colorMatches ([YCodePreferences issueColorForSeverity: @"error"], 1, 0, 0)
          && colorMatches (
              [YCodePreferences issueColorForSeverity: @"fatal error"], 1, 0, 0)
          && colorMatches ([YCodePreferences issueColorForSeverity: @"warning"],
                           1, 1, 0)
          && colorMatches ([YCodePreferences issueColorForSeverity: @"note"], 1,
                           1, 1),
      @"Issues default to red errors, yellow warnings, and white notes");

  YCodeProject *project = [[YCodeProject alloc] init];
  [project
      setProjectPath: [temporaryDirectory
                         stringByAppendingPathComponent: @"Issues.xcodeproj"]];
  YCodeWindowController *controller = [[YCodeWindowController alloc] init];
  [controller setProject: project];
  [controller showWindow: nil];
  [controller setBottomPanelVisible: YES];
  NSSplitView *split = [controller valueForKey: @"_editorSplitView"];
  NSTabView *editor = [controller valueForKey: @"_editorTabView"];
  NSView *results = [controller valueForKey: @"_bottomView"];
  NSTabView *tabs = [controller valueForKey: @"_bottomTabView"];
  NSOutlineView *table = [controller valueForKey: @"_issuesOutlineView"];
  testAssert (![split isVertical] && [editor superview] == split &&
                  [results superview] == split,
              @"Source and build results share a horizontal split view");
  testAssert (!NSIntersectsRect ([editor frame], [results frame])
                  && NSHeight ([editor frame]) > 0
                  && NSHeight ([results frame]) > 0
                  && NSMaxY ([editor frame]) <= NSMinY ([results frame]),
              @"Build results resize the source instead of covering it");
  [split setPosition: NSHeight ([split bounds]) * 0.6 ofDividerAtIndex: 0];
  [[controller window] setContentSize: NSMakeSize (1200, 780)];
  testAssert (!NSIntersectsRect ([editor frame], [results frame])
                  && NSContainsRect ([split bounds], [results frame]),
              @"Dragging and resizing keeps panes separate");
  [controller setBottomPanelVisible: NO];
  testAssert (
      [results superview] == nil
          && fabs (NSHeight ([editor frame]) - NSHeight ([split bounds])) < 1,
      @"Hiding build results restores the editor's full height");
  [controller setBottomPanelVisible: YES];
  testAssert ([[split subviews] count] == 2
                  && !NSIntersectsRect ([editor frame], [results frame]),
              @"Showing results restores the split without duplicate panes");

  NSView *consolePane = [[tabs tabViewItemAtIndex: 0] view];
  testAssert (
      [consolePane isKindOfClass: [NSScrollView class]],
      @"Console is a full-height transcript without a debugger command field");
  [tabs selectTabViewItemWithIdentifier: @"debugger"];
  NSView *debuggerPane = [[tabs selectedTabViewItem] view];
  NSTextField *commandField =
      [controller valueForKey: @"_debuggerCommandField"];
  NSView *debuggerScroll = [[debuggerPane subviews] objectAtIndex: 1];
  testAssert (
      [commandField action] == @selector (debugConsoleCommand:)
          && !NSIntersectsRect ([commandField frame], [debuggerScroll frame])
          && NSContainsRect ([debuggerPane bounds], [commandField frame])
          && NSContainsRect ([debuggerPane bounds], [debuggerScroll frame]),
      @"Debugger command field and transcript remain separate and visible after resizing");
  NSString *source =
      [temporaryDirectory stringByAppendingPathComponent: @"Issue Source.m"];
  NSString *text = @"first line\n  invalidSymbol();\nlast line\n";
  [text writeToFile: source
         atomically: YES
           encoding: NSUTF8StringEncoding
              error: NULL];
  YCodeBuildSystem *build = [project buildSystem];
  [controller buildSystemDidStartBuild: build];
  NSTextView *consoleText = [controller valueForKey: @"_consoleTextView"];
  NSTextView *debuggerText = [controller valueForKey: @"_debuggerTextView"];
  [consoleText setString: @""];
  [controller buildSystem: build didReceiveOutput: @"\033[3"];
  [controller buildSystem: build didReceiveError: @"stderr"];
  [controller buildSystem: build
         didReceiveOutput: @"1mred\033[0m plain\033]0;title"];
  [controller buildSystem: build didReceiveOutput: @"\007 end\n"];
  testAssert (
      [[consoleText string] isEqual: @"stderrred plain end\n"],
      @"Console consumes split ANSI and OSC sequences independently for stdout and stderr");
  NSColor *red =
      [[consoleText textStorage] attribute: NSForegroundColorAttributeName
                                   atIndex: 6
                            effectiveRange: NULL];
  NSColor *normal =
      [[consoleText textStorage] attribute: NSForegroundColorAttributeName
                                   atIndex: 9
                            effectiveRange: NULL];
  testAssert (
      ![red isEqual: normal] && [normal isEqual: [NSColor textColor]],
      @"Console applies foreground color and resets it without leaking to other streams");
  [debuggerText setString: @""];
  [controller buildSystem: build didReceiveDebuggerOutput: @"\033[38;2;12;34;"];
  [controller buildSystem: build
      didReceiveDebuggerOutput: @"56mRGB\033[48;5;196mBG\033[0mplain\033[K"];
  NSColor *rgb = [[[debuggerText textStorage]
           attribute: NSForegroundColorAttributeName
             atIndex: 0
      effectiveRange: NULL] colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  testAssert (
      [[debuggerText string] isEqual: @"RGBBGplain"]
          && fabs ([rgb redComponent] - 12.0 / 255) < 0.001
          && fabs ([rgb greenComponent] - 34.0 / 255) < 0.001
          && fabs ([rgb blueComponent] - 56.0 / 255) < 0.001 &&
          [[debuggerText textStorage] attribute: NSBackgroundColorAttributeName
                                        atIndex: 3
                                 effectiveRange: NULL]
              != nil
          &&
          [[debuggerText textStorage] attribute: NSBackgroundColorAttributeName
                                        atIndex: 5
                                 effectiveRange: NULL]
              == nil,
      @"Debugger decodes split truecolor, indexed background colors, reset and cursor controls");
  [controller buildSystemDidStartBuild: build];
  [controller buildSystem: build didReceiveOutput: @"ordinary build progress\n"];
  [controller buildSystem: build didReceiveError: @"\033[1mIssue Source.m:2:"];
  testAssert ([table numberOfRows] == 0,
              @"Incomplete diagnostic waits for its remaining output");
  [controller
          buildSystem: build
      didReceiveError: @"3: \033[32m\033[44merror: unknown symbol\033[0m\n"];
  [controller buildSystem: build
         didReceiveOutput:
             [NSString stringWithFormat: @"%@:3: warning: unused expression\n",
                                        source]];
  [controller buildSystem: build
          didReceiveError: @"Issue Source.m:1: note: declared here"];
  [controller buildSystemDidFinishBuild: build success: NO];
  testAssert (
      [table numberOfRows] == 7,
      @"Collect chunked, colored, stdout and unterminated diagnostics");
  id sourceGroup = [table itemAtRow: 0];
  testAssert (
      [table isKindOfClass: [NSOutlineView class]] &&
          [[table dataSource] outlineView: table numberOfChildrenOfItem: nil]
              == 1
          && [[table dataSource] outlineView: table
                      numberOfChildrenOfItem: sourceGroup]
                 == 3
          && [table isItemExpanded: sourceGroup],
      @"Issue severity groups appear beneath an automatically expanded source file");
  NSArray *severityTitles =
      [NSArray arrayWithObjects: @"Errors (1 issue)", @"Warnings (1 issue)",
                                @"Notes (1 issue)", nil];
  NSUInteger severityIndex;
  for (severityIndex = 0; severityIndex < 3; severityIndex++)
    {
      id category = [[table dataSource] outlineView: table
                                              child: severityIndex
                                             ofItem: sourceGroup];
      NSAttributedString *title =
          [[table dataSource] outlineView: table
                objectValueForTableColumn: [table outlineTableColumn]
                                   byItem: category];
      testAssert (
          [[title string] isEqual: [severityTitles objectAtIndex: severityIndex]]
              && [[table dataSource] outlineView: table
                          numberOfChildrenOfItem: category]
                     == 1
              && [table isItemExpanded: category],
          @"Each severity has a counted, expanded category beneath the file");
    }
  NSAttributedString *groupDisplay =
      [[table dataSource] outlineView: table
            objectValueForTableColumn: [table outlineTableColumn]
                               byItem: sourceGroup];
  testAssert ([[groupDisplay string] isEqual: @"Issue Source.m (3 issues)"],
              @"File headers show an identifiable path and diagnostic count");

  testAssert ([[[tabs selectedTabViewItem] identifier] isEqual: @"issues"],
              @"Build completion selects issues when diagnostics exist");
  testAssert (fabs ([[[table tableColumns] objectAtIndex: 0] width] -
                    [[table enclosingScrollView] contentSize].width)
                  < 4,
              @"Issues column fills the results pane");
  NSArray *issues = [controller valueForKey: @"_buildIssues"];
  testAssert (
      [[[issues objectAtIndex: 0] objectForKey: @"message"]
          isEqual: @"unknown symbol"]
          && [[[issues objectAtIndex: 0] objectForKey: @"path"] isEqual: source],
      @"Remove ANSI colors and resolve relative diagnostic paths");
  NSAttributedString *issueDisplay =
      [[issues objectAtIndex: 0] objectForKey: @"display"];
  testAssert (
      [[issueDisplay string]
          isEqual: @"error: Issue Source.m:2:3\nunknown symbol"]
          && colorMatches ([issueDisplay
                                    attribute: NSForegroundColorAttributeName
                                      atIndex: 0
                               effectiveRange: NULL],
                           1, 0, 0)
          && colorMatches ([issueDisplay
                                    attribute: NSForegroundColorAttributeName
                                      atIndex: [issueDisplay length] - 1
                               effectiveRange: NULL],
                           1, 0, 0),
      @"Issue severity preferences override compiler ANSI colors without changing navigation metadata");
  testAssert (
      [issueDisplay attribute: NSBackgroundColorAttributeName
                      atIndex: [issueDisplay length] - 1
               effectiveRange: NULL]
          == nil,
      @"Compiler background colors do not obscure configured issue colors");
  NSAttributedString *warning =
      [[issues objectAtIndex: 1] objectForKey: @"display"];
  NSAttributedString *note =
      [[issues objectAtIndex: 2] objectForKey: @"display"];
  testAssert (
      colorMatches ([warning attribute: NSForegroundColorAttributeName
                               atIndex: 0
                        effectiveRange: NULL],
                    1, 1, 0)
          && colorMatches ([note attribute: NSForegroundColorAttributeName
                                      atIndex: 0
                               effectiveRange: NULL],
                           1, 1, 1)
          && colorMatches ([table backgroundColor], 0, 0, 0),
      @"Uncolored compiler warnings and notes use readable severity defaults");
  AppController *preferences = [AppController new];
  [preferences showPrefPanel: nil];
  NSPopUpButton *groups = [preferences valueForKey: @"_preferencesGroup"];
  [groups selectItemWithTitle: @"Issues"];
  [groups sendAction: [groups action] to: [groups target]];
  NSArray *wells = [preferences valueForKey: @"_issueColorWells"];
  testAssert (
      [wells count] == 3
          && ![[preferences valueForKey: @"_issuePreferencesView"] isHidden],
      @"Preferences exposes three issue severity color controls");
  NSArray *colors =
      [NSArray arrayWithObjects: [NSColor greenColor], [NSColor cyanColor],
                                [NSColor magentaColor], nil];
  NSUInteger index;
  for (index = 0; index < 3; index++)
    {
      NSColorWell *well = [wells objectAtIndex: index];
      [well setColor: [colors objectAtIndex: index]];
      [well sendAction: [well action] to: [well target]];
      NSAttributedString *display =
          [[issues objectAtIndex: index] objectForKey: @"display"];
      testAssert (
          colorMatches ([display attribute: NSForegroundColorAttributeName
                                   atIndex: 0
                            effectiveRange: NULL],
                        index == 2 ? 1 : 0, index == 2 ? 0 : 1,
                        index == 0 ? 0 : 1),
          @"Changing an issue color immediately recolors existing rows");
    }
  testAssert ([[defaults dictionaryForKey: @"YCodeIssueColors"] count] == 3,
              @"All issue colors are saved independently");
  [controller buildSystem: build
          didReceiveError: @"clang: error: outside build\n"];
  [preferences performSelector: @selector (resetIssueColors:) withObject: nil];
  testAssert (
      colorMatches ([issueDisplay attribute: NSForegroundColorAttributeName
                                    atIndex: 0
                             effectiveRange: NULL],
                    1, 0, 0)
          && colorMatches ([[wells objectAtIndex: 1] color], 1, 1, 0)
          && colorMatches ([[wells objectAtIndex: 2] color], 1, 1, 1),
      @"Restore Defaults updates existing issues and preference controls");
  [[preferences valueForKey: @"_preferencesPanel"] close];
  [preferences release];
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 0]
      byExtendingSelection: NO];
  testAssert (
      [[[controller editorController] openDocuments] count] == 0,
      @"Selecting a file header does not navigate as if it were a diagnostic");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 2]
      byExtendingSelection: NO];
  YCodeEditorDocument *document =
      [[controller editorController] currentDocument];
  testAssert (
      [[document filePath] isEqual: source] &&
          [document selectedRange].location == 13,
      @"Selecting an issue opens the source at its reported line and column");
  [document setSelectedRange: NSMakeRange (0, 0)];
  [table sendAction: [table action] to: [table target]];
  testAssert ([document selectedRange].location == 13,
              @"Clicking the already selected issue returns to its location");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 4]
      byExtendingSelection: NO];
  testAssert ([[document selectedText] isEqual: @"last line"],
              @"Diagnostics without columns select their source line");
  testAssert ([[[controller editorController] openDocuments] count] == 1,
              @"Navigating another issue reuses the open source tab");

  [YCodePreferences setIssueColor: [NSColor greenColor] forSeverity: @"error"];
  [controller buildSystemDidStartBuild: build];
  testAssert ([table numberOfRows] == 0, @"A new build clears stale issues");
  [controller buildSystem: build
         didReceiveOutput:
             [NSString stringWithFormat: @"make[1]: Entering directory '%@'\n",
                                        temporaryDirectory]];
  [controller
          buildSystem: build
      didReceiveError: @"Issue Source.m:999:999: warning: stale location\n"];
  [controller buildSystem: build
          didReceiveError: @"clang: error: linker command failed\n"];
  [controller buildSystemDidFinishBuild: build success: YES];
  testAssert ([table numberOfRows] == 6,
              @"Include tool errors without a source location");
  id toolGroup = [table itemAtRow: 3];
  testAssert (
      [[table dataSource] outlineView: table numberOfChildrenOfItem: nil] == 2 &&
          [[[[table dataSource] outlineView: table
                  objectValueForTableColumn: [table outlineTableColumn]
                                     byItem: toolGroup] string]
              isEqual: @"Build tools (1 issue)"],
      @"Tool messages without a source file have their own group");

  NSAttributedString *toolDisplay = [[[controller valueForKey: @"_buildIssues"]
      objectAtIndex: 1] objectForKey: @"display"];
  testAssert (
      colorMatches ([toolDisplay attribute: NSForegroundColorAttributeName
                                   atIndex: 0
                            effectiveRange: NULL],
                    0, 1, 0),
      @"New tool errors use the configured severity color");

  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 2]
      byExtendingSelection: NO];
  testAssert (NSMaxRange ([document selectedRange]) <=
                  [[document content] length],
              @"Outdated diagnostic positions are clamped to the source");
  [controller buildSystem: build
         didReceiveOutput: @"Issue Source.m:2:3: error: runtime text\n"];
  testAssert ([table numberOfRows] == 6,
              @"Runtime output does not become a build issue");
  [controller buildSystem: build stoppedAtFile: source line: 2];
  testAssert (
      [[document selectedText] isEqual: @"  invalidSymbol();"],
      @"Debugger stop selects the source line in the existing editor tab");
  [controller buildSystemDidStartBuild: build];
  [controller
          buildSystem: build
      didReceiveError:
          @"Issue Source.m:2:3: error: repeated\nIssue Source.m:2:3: error: repeated\n"];
  sourceGroup = [table itemAtRow: 0];
  testAssert ([table numberOfRows] == 4 &&
                  [table itemAtRow: 2] != [table itemAtRow: 3],
              @"Identical diagnostics remain distinct outline items");
  [table selectRowIndexes: [NSIndexSet indexSetWithIndex: 3]
      byExtendingSelection: NO];
  id selectedIssue = [table itemAtRow: 3];
  [document setSelectedRange: NSMakeRange (0, 0)];
  [controller buildSystem: build
          didReceiveError: @"Other/Issue Source.m:1: warning: another file\n"];
  testAssert (
      [[table dataSource] outlineView: table numberOfChildrenOfItem: nil] == 2 &&
          [table itemAtRow: [table selectedRow]] == selectedIssue &&
          [document selectedRange].location == 0,
      @"Streaming output separates equal basenames and preserves selection without renavigating");
  [table collapseItem: sourceGroup];
  [controller buildSystem: build
          didReceiveError: @"Issue Source.m:1: note: later note\n"];
  testAssert (![table isItemExpanded: sourceGroup] &&
                  [[table dataSource] outlineView: table
                           numberOfChildrenOfItem: sourceGroup]
                      == 2,
              @"New diagnostics preserve the user's collapsed file groups");
  [YCodePreferences setIssueColor: [NSColor cyanColor] forSeverity: @"note"];
  testAssert (![table isItemExpanded: sourceGroup],
              @"Changing issue colors preserves collapsed groups");
  [table expandItem: sourceGroup];
  testAssert (
      [table numberOfRows] == 9,
      @"Expanding a group reveals diagnostics received while collapsed");
  [controller buildSystemDidFinishBuild: build success: NO];
  [controller buildSystemDidStartBuild: build];
  [controller
          buildSystem: build
      didReceiveError:
          @"Issue Source.m:1: remark: detail\nIssue Source.m:1: warning: caution\nIssue Source.m:1: fatal error: fatal\n"];
  sourceGroup = [table itemAtRow: 0];
  id errorsGroup = [[table dataSource] outlineView: table
                                             child: 0
                                            ofItem: sourceGroup];
  id notesGroup = [[table dataSource] outlineView: table
                                            child: 2
                                           ofItem: sourceGroup];
  testAssert (
      [[[[table dataSource] outlineView: table
              objectValueForTableColumn: [table outlineTableColumn]
                                 byItem: errorsGroup] string]
          isEqual: @"Errors (1 issue)"]
          && [[[[table dataSource] outlineView: table
                     objectValueForTableColumn: [table outlineTableColumn]
                                        byItem: notesGroup] string]
              isEqual: @"Notes (1 issue)"],
      @"Severity order is independent of arrival order; fatal errors and remarks use their matching categories");
  [table collapseItem: errorsGroup];
  [controller buildSystem: build
          didReceiveError: @"Issue Source.m:1: error: another error\n"];
  testAssert (
      ![table isItemExpanded: errorsGroup] && [table isItemExpanded: sourceGroup]
          && [[table dataSource] outlineView: table
                      numberOfChildrenOfItem: errorsGroup]
                 == 2,
      @"Collapsed severity groups stay collapsed as matching diagnostics arrive");
  [table collapseItem: sourceGroup];
  [YCodePreferences setIssueColor: [NSColor magentaColor] forSeverity: @"error"];
  [table expandItem: sourceGroup];
  NSAttributedString *errorTitle =
      [[table dataSource] outlineView: table
            objectValueForTableColumn: [table outlineTableColumn]
                               byItem: errorsGroup];
  testAssert (
      ![table isItemExpanded: errorsGroup] && [table isItemExpanded: notesGroup]
          && colorMatches ([errorTitle attribute: NSForegroundColorAttributeName
                                         atIndex: 0
                                  effectiveRange: NULL],
                           1, 0, 1),
      @"Severity collapse state survives parent collapse and preference changes, and headings use configured colors");
  [controller buildSystemDidFinishBuild: build success: NO];
  [controller setProject: nil];
  testAssert ([table numberOfRows] == 0,
              @"Switching projects clears all outline groups");
  [controller close];
  [controller release];
  [project close];
  [project release];
  if (savedIssueColors)
    [defaults setObject: savedIssueColors forKey: @"YCodeIssueColors"];
  else
    [defaults removeObjectForKey: @"YCodeIssueColors"];
  [savedIssueColors release];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeIssueColorsDidChangeNotification
                    object: nil];
}

static void
testProjectCenterImport (NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *package =
      [directory stringByAppendingPathComponent: @"Imported Project.pcproj"];
  [manager createDirectoryAtPath: package
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *projectFile =
      [package stringByAppendingPathComponent: @"PC.project"];
  NSString *sourcePath =
      [directory stringByAppendingPathComponent: @"Imported Source.m"];
  [@"int main(void) { return 0; }\n" writeToFile: sourcePath
                                      atomically: YES
                                        encoding: NSUTF8StringEncoding
                                           error: NULL];
  NSMutableDictionary *contents = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:
          @"Imported Tool", @"PROJECT_NAME", @"Tool", @"PROJECT_TYPE",
          [NSArray arrayWithObject: @"Imported Source.m"], @"CLASS_FILES",
          [NSArray arrayWithObject: @"Imported Source.m"], @"OTHER_SOURCES",
          [NSArray arrayWithObject: @"Public.h"], @"HEADER_FILES",
          [NSArray arrayWithObject: @"Public.h"], @"PUBLIC_HEADERS",
          [NSArray arrayWithObject: @"Images/Icon.png"], @"IMAGES",
          [NSArray arrayWithObject: @"English.lproj/Main.gorm"], @"INTERFACES",
          [NSArray arrayWithObject: @"English.lproj/Localizable.strings"],
          @"LOCALIZED_RESOURCES", [NSArray arrayWithObject: @"data.txt"],
          @"OTHER_RESOURCES", [NSArray arrayWithObject: @"ImportedInfo.plist"],
          @"SUPPORTING_FILES", [NSArray arrayWithObject: @"README"],
          @"DOCU_FILES", [NSArray arrayWithObject: @"Foundation"],
          @"FRAMEWORKS", [NSArray arrayWithObject: @"gnustep-base"],
          @"LIBRARIES", [NSArray arrayWithObject: @"Include Files"],
          @"SEARCH_HEADER_DIRS", [NSArray arrayWithObject: @"Library Files"],
          @"SEARCH_LIB_DIRS", @"-DIMPORT_TEST=1", @"COMPILEROPTIONS",
          @"-Wl,--as-needed", @"LINKEROPTIONS", nil];
  [contents writeToFile: projectFile atomically: YES];
  NSData *original = [NSData dataWithContentsOfFile: projectFile];
  YCodeProject *document = [[YCodeProject alloc] init];
  NSError *error = nil;
  testAssert ([document readFromURL: [NSURL fileURLWithPath: package]
                             ofType: @"YCodeProjectCenterProjectType"
                              error: &error],
              @"Import a ProjectCenter package");
  PBXProject *project = [document project];
  PBXNativeTarget *target = [[project targets] lastObject];
  testAssert ([[target productType] isEqual: @"com.apple.product-type.tool"] &&
                  [[[target productReference] path] isEqual: @"Imported Tool"],
              @"Import preserves the ProjectCenter product type and name");
  PBXFileReference *source = nil;
  NSUInteger sources = 0, headers = 0, resources = 0, frameworks = 0;
  {
    NSEnumerator *phaseEnumerator = [[target buildPhases] objectEnumerator];
    PBXBuildPhase *phase;
    while ((phase = [phaseEnumerator nextObject]) != nil)
      {
        if ([phase isKindOfClass: [PBXSourcesBuildPhase class]])
          {
            sources = [[phase files] count];
            source = [[[phase files] lastObject] fileRef];
          }
        else if ([phase isKindOfClass: [PBXHeadersBuildPhase class]])
          {
            headers = [[phase files] count];
            testAssert (
                [[[[[phase files] lastObject] settings]
                    objectForKey: @"ATTRIBUTES"] containsObject: @"Public"],
                @"Imported public headers retain their visibility");
          }
        else if ([phase isKindOfClass: [PBXResourcesBuildPhase class]])
          resources = [[phase files] count];
        else if ([phase isKindOfClass: [PBXFrameworksBuildPhase class]])
          frameworks = [[phase files] count];
      }
  }
  testAssert (sources == 1 && headers == 1 && resources == 4
                  && frameworks == 1,
              @"Import separates build phases and removes duplicate entries");
  [document makeWindowControllers];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  YCodeProjectNavigatorItem *item = [navigator itemForObject: source];
  testAssert (
      item != nil &&
          [[navigator resolvedFilePathForNavigatorItem: item]
              isEqual: sourcePath],
      @"Imported navigator references resolve outside the pcproj package, including spaces");
  testAssert (
      [[navigator outlineView] rowForItem: item] >= 0,
      @"Imported source files are visible immediately without expanding hidden groups");
  testAssert ([[document editorController]
                  openFile: [navigator resolvedFilePathForNavigatorItem: item]],
              @"Imported source opens in the editor");
  NSDictionary *settings =
      [[[target buildConfigurationList] defaultConfiguration] buildSettings];
  testAssert (
      [[settings objectForKey: @"HEADER_SEARCH_PATHS"]
          isEqual: [contents objectForKey: @"SEARCH_HEADER_DIRS"]]
          &&
          [[settings objectForKey: @"OTHER_CFLAGS"] isEqual: @"-DIMPORT_TEST=1"]
          && [[settings objectForKey: @"OTHER_LDFLAGS"]
              isEqual: @"-Wl,--as-needed -lgnustep-base"]
          && [[settings objectForKey: @"INFOPLIST_FILE"]
              isEqual: @"ImportedInfo.plist"],
      @"Import retains search paths, compiler and linker flags, libraries, and Info.plist");
  testAssert ([document saveProjectToPath: package],
              @"Save imported project as Xcode format");
  NSString *converted = [[package stringByDeletingPathExtension]
      stringByAppendingPathExtension: @"xcodeproj"];
  testAssert (
      [[document projectPath] isEqual: converted] &&
          [[[document fileURL] path] isEqual: converted] &&
          [[NSData dataWithContentsOfFile: projectFile] isEqual: original] &&
          [[manager contentsOfDirectoryAtPath: package error: NULL] count] == 1,
      @"Conversion saves beside the original package without changing PC.project");
  YCodeProject *reopened = [[YCodeProject alloc] init];
  testAssert ([reopened readFromURL: [NSURL fileURLWithPath: converted]
                             ofType: @"YCodeXcodeProjectType"
                              error: NULL]
                  && [[reopened projectDirectoryPath] isEqual: directory],
              @"Reopen the saved import with the same source root");
  PBXNativeTarget *reopenedTarget = [[[reopened project] targets] lastObject];
  testAssert ([[reopenedTarget productType] isEqual: [target productType]] &&
                  [[reopenedTarget buildPhases] count] == 4,
              @"Imported target survives serialization");
  [reopened close];
  [reopened release];
  YCodeProject *relocated = [[YCodeProject alloc] init];
  [relocated readFromURL: [NSURL fileURLWithPath: package]
                  ofType: @"YCodeProjectCenterProjectType"
                   error: NULL];
  NSString *relocatedPath = [directory
      stringByAppendingPathComponent: @"Elsewhere/Imported.xcodeproj"];
  testAssert ([relocated saveProjectToPath: relocatedPath],
              @"Save an import in another directory");
  [relocated close];
  [relocated release];
  relocated = [[YCodeProject alloc] init];
  testAssert ([relocated readFromURL: [NSURL fileURLWithPath: relocatedPath]
                              ofType: @"YCodeXcodeProjectType"
                               error: NULL],
              @"Reopen a relocated import");
  [relocated makeWindowControllers];
  PBXNativeTarget *relocatedTarget =
      [[[relocated project] targets] lastObject];
  PBXFileReference *relocatedSource =
      [[[[[relocatedTarget buildPhases] objectAtIndex: 0] files] lastObject]
          fileRef];
  YCodeProjectNavigatorController *relocatedNavigator =
      [relocated navigatorController];
  testAssert (
      [[relocatedNavigator
          resolvedFilePathForNavigatorItem: [relocatedNavigator
                                               itemForObject: relocatedSource]]
          isEqual: sourcePath],
      @"Relocated import still points to its original source files");
  testAssert (
      [[[[[relocatedTarget buildConfigurationList] defaultConfiguration]
          buildSettings] objectForKey: @"HEADER_SEARCH_PATHS"]
          isEqual: [NSArray arrayWithObject: [directory
                                               stringByAppendingPathComponent:
                                                   @"Include Files"]]],
      @"Relocated import retains its header search directory");
  [relocated close];
  [relocated release];
  NSArray *types = [NSArray arrayWithObjects: @"Application", @"Framework",
                                             @"Library", @"Bundle", nil];
  {
    NSEnumerator *typeEnumerator = [types objectEnumerator];
    NSString *type;
    while ((type = [typeEnumerator nextObject]) != nil)
      {
        [contents setObject: type forKey: @"PROJECT_TYPE"];
        [contents writeToFile: projectFile atomically: YES];
        YCodeProject *variant = [[YCodeProject alloc] init];
        testAssert (
            [variant readFromURL: [NSURL fileURLWithPath: package]
                          ofType: @"YCodeProjectCenterProjectType"
                           error: NULL],
            [NSString
                stringWithFormat: @"Import ProjectCenter %@ target", type]);
        [variant close];
        [variant release];
      }
  }
  {
    NSEnumerator *invalidEnumerator = [[NSArray
        arrayWithObjects: [NSDictionary dictionary],
                         [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"Bad", @"PROJECT_NAME", @"Tool",
                                           @"PROJECT_TYPE",
                                           [NSNumber numberWithInt: 42],
                                           @"CLASS_FILES", nil],
                         nil] objectEnumerator];
    id invalid;
    while ((invalid = [invalidEnumerator nextObject]) != nil)
      {
        [invalid writeToFile: projectFile atomically: YES];
        error = nil;
        testAssert (
            ![document readFromURL: [NSURL fileURLWithPath: package]
                            ofType: @"YCodeProjectCenterProjectType"
                             error: &error]
                && error != nil && [document project] == project &&
                [[[document fileURL] path] isEqual: converted],
            @"Malformed imports fail without replacing the loaded project");
      }
  }
  [document close];
  [document release];
}

static void
testProjectCenterExport (NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root =
      [directory stringByAppendingPathComponent: @"ProjectCenter Export"];
  [manager createDirectoryAtPath:
               [root stringByAppendingPathComponent: @"Resources"]
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [manager createDirectoryAtPath:
               [root stringByAppendingPathComponent: @"English.lproj/Main.gorm"]
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  {
    NSEnumerator *nameEnumerator = [[NSArray
        arrayWithObjects: @"Main.m", @"Public.h", @"Resources/Icon.png",
                         @"Notes.txt", nil] objectEnumerator];
    NSString *name;
    while ((name = [nameEnumerator nextObject]) != nil)
      [@"fixture" writeToFile: [root stringByAppendingPathComponent: name]
                   atomically: YES
                     encoding: NSUTF8StringEncoding
                        error: NULL];
  }
  NSString *legacyPath =
      [root stringByAppendingPathComponent: @"Legacy.pcproj"];
  NSDictionary *metadata = [NSDictionary
      dictionaryWithObjectsAndKeys: @"Legacy", @"PROJECT_NAME", @"PCAppProject",
                                   @"PROJECT_TYPE", @"Main.m", @"CLASS_FILES",
                                   @"Public.h", @"HEADER_FILES", @"Public.h",
                                   @"PUBLIC_HEADERS", @"Icon.png", @"IMAGES",
                                   @"Main.gorm", @"INTERFACES", @"Main.gorm",
                                   @"LOCALIZED_RESOURCES", @"Notes.txt",
                                   @"OTHER_FILES", @"English", @"LANGUAGE",
                                   @"-lgnustep-base -lgnustep-gui",
                                   @"LINKEROPTIONS", @"Preserve this metadata",
                                   @"PROJECT_COPYRIGHT", nil];
  [metadata writeToFile: legacyPath atomically: YES];
  YCodeProject *document = [[YCodeProject alloc] init];
  testAssert (
      [document readFromURL: [NSURL fileURLWithPath: legacyPath]
                     ofType: @"YCodeProjectCenterProjectType"
                      error: NULL],
      @"Read a legacy flat pcproj with singleton file lists and legacy product type");
  [document makeWindowControllers];
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  NSMutableArray *expectedPaths = [NSMutableArray array];
  {
    NSEnumerator *groupEnumerator =
        [[[[document project] mainGroup] children] objectEnumerator];
    PBXGroup *group;
    while ((group = [groupEnumerator nextObject]) != nil)
      {
        {
          NSEnumerator *referenceEnumerator =
              [[group children] objectEnumerator];
          PBXFileReference *reference;
          while ((reference = [referenceEnumerator nextObject]) != nil)
            {
              if ([[reference sourceTree] isEqual: @"BUILT_PRODUCTS_DIR"])
                continue;
              YCodeProjectNavigatorItem *item =
                  [navigator itemForObject: reference];
              NSString *path =
                  [navigator resolvedFilePathForNavigatorItem: item];
              testAssert (
                  [[navigator outlineView] rowForItem: item] >= 0,
                  @"Imported sources, headers, resources, and supporting files are visible");
              testAssert (
                  [manager fileExistsAtPath: path],
                  @"ProjectCenter category paths locate the actual files");
              if (path)
                [expectedPaths addObject: path];
            }
        }
      }
  }
  testAssert (
      [expectedPaths count] == 5 &&
          [expectedPaths containsObject: [root stringByAppendingPathComponent:
                                                  @"Resources/Icon.png"]]
          &&
          [expectedPaths containsObject: [root stringByAppendingPathComponent:
                                                  @"English.lproj/Main.gorm"]],
      @"Import resolves Resources and localized interface files without duplicates");
  [document updateChangeCount: NSChangeDone];
  NSString *exportPath =
      [root stringByAppendingPathComponent: @"Exports/Exported.pcproj"];
  NSError *error = nil;
  testAssert ([document exportProjectCenterToPath: exportPath error: &error]
                  && error == nil,
              @"Export a ProjectCenter package to another directory");
  testAssert (
      [[document projectPath] isEqual: legacyPath] &&
          [document isDocumentEdited],
      @"Export leaves the current project identity and unsaved state intact");
  NSDictionary *exported = [NSDictionary
      dictionaryWithContentsOfFile:
          [exportPath stringByAppendingPathComponent: @"PC.project"]];
  testAssert (
      [[exported objectForKey: @"PROJECT_COPYRIGHT"]
          isEqual: @"Preserve this metadata"]
          && [[exported objectForKey: @"CLASS_FILES"] count] == 1 &&
          [[exported objectForKey: @"PUBLIC_HEADERS"] count] == 1 &&
          [[exported objectForKey: @"LIBRARIES"] count] == 2,
      @"Export retains file membership, public headers, libraries, and ProjectCenter metadata");
  YCodeProject *reopened = [[YCodeProject alloc] init];
  testAssert ([reopened readFromURL: [NSURL fileURLWithPath: exportPath]
                             ofType: @"YCodeProjectCenterProjectType"
                              error: NULL],
              @"Reimport the exported ProjectCenter package");
  [reopened makeWindowControllers];
  NSMutableArray *actualPaths = [NSMutableArray array];
  {
    NSEnumerator *groupEnumerator =
        [[[[reopened project] mainGroup] children] objectEnumerator];
    PBXGroup *group;
    while ((group = [groupEnumerator nextObject]) != nil)
      {
        {
          NSEnumerator *referenceEnumerator =
              [[group children] objectEnumerator];
          PBXFileReference *reference;
          while ((reference = [referenceEnumerator nextObject]) != nil)
            {
              NSString *path = [[reopened navigatorController]
                  resolvedFilePathForNavigatorItem:
                      [[reopened navigatorController]
                          itemForObject: reference]];
              if (path)
                [actualPaths addObject: path];
            }
        }
      }
  }
  testAssert ([[actualPaths sortedArrayUsingSelector: @selector (compare:)]
                  isEqual: [expectedPaths
                              sortedArrayUsingSelector: @selector (compare:)]],
              @"Export and reimport preserve every original file location");
  [reopened close];
  [reopened release];
  NSString *blocked =
      [root stringByAppendingPathComponent: @"Notes.txt/Blocked.pcproj"];
  error = nil;
  testAssert (![document exportProjectCenterToPath: blocked error: &error]
                  && error != nil,
              @"Export reports an unwritable destination");
  NSMenu *fileMenu = [[[NSApp mainMenu] itemWithTitle: @"File"] submenu];
  testAssert (
      [[fileMenu itemWithTitle: @"Export ProjectCenter Project..."] action] ==
          @selector (exportProjectCenter:),
      @"File menu exposes ProjectCenter export");
  [document updateChangeCount: NSChangeCleared];
  [document close];
  [document release];
}

@interface AppController (NewProjectTesting)
- (NSView *) newProjectAccessoryView;
- (void) createNewProjectAtURL: (NSURL *)url
                       format: (NSString *)format
                  productType: (NSString *)productType;
@end

@interface YCodeNewProjectPanelTest : NSObject
+ (void) cancelPanel: (NSTimer *)timer;
@end
@implementation YCodeNewProjectPanelTest
+ (void) cancelPanel: (NSTimer *)timer
{
  NSSavePanel *panel = (NSSavePanel *)[NSApp modalWindow];
  if (!panel)
    return;
  testAssert (
      [panel isKindOfClass: [NSSavePanel class]]
          && ![panel isKindOfClass: [NSOpenPanel class]],
      @"New Project accepts a new folder name instead of requiring an existing folder");
  testAssert ([[panel nameFieldLabel] isEqual: @"Project name:"] &&
                  [[panel nameFieldStringValue] isEqual: @"MyProject"] &&
                  [[panel defaultButtonCell] isEnabled],
              @"Project name field has a default value and Create is enabled");
  NSView *accessory = [panel accessoryView];
  NSPopUpButton *types = (NSPopUpButton *)[accessory viewWithTag: 100];
  testAssert (types != nil && [types window] == panel && ![types isHidden],
              @"Project type selector is visible in the location panel");
  [types selectItemAtIndex: 2];
  testAssert ([[[types selectedItem] representedObject] isEqual: @"Bundle"],
              @"Project type selector can choose a bundle target");
  if ([timer userInfo])
    {
      [panel setDirectoryURL: [NSURL fileURLWithPath: [timer userInfo]]];
      [panel setNameFieldStringValue: @"Named New App"];
      [panel ok: nil];
    }
  else
    [panel cancel: nil];
  [timer invalidate];
  // Wake the modal event wait after the timer accepts or cancels the panel.
  [NSApp postEvent: [NSEvent otherEventWithType: NSApplicationDefined
                                      location: NSZeroPoint
                                 modifierFlags: 0
                                     timestamp: 0
                                  windowNumber: [panel windowNumber]
                                       context: nil
                                       subtype: 0
                                         data1: 0
                                         data2: 0]
           atStart: NO];
}

@end

@interface YCodeProject (FrameworkDiscoveryTesting)
+ (BOOL) framework: (NSString *)name
    availableInDirectories: (NSArray *)directories;
+ (BOOL) uiKitAvailableWithHeaders: (NSArray *)headers
                        libraries: (NSArray *)libraries;
+ (NSString *) uiKitSimulatorSDKPath;
@end

static void
testFrameworkDiscovery (NSString *directory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *root = [directory
      stringByAppendingPathComponent: @"Framework paths with spaces"];
  NSString *sdk = [root stringByAppendingPathComponent: @"SDK Root"];
  NSString *frameworks =
      [sdk stringByAppendingPathComponent: @"System/Library/Frameworks"];
  NSString *framework =
      [frameworks stringByAppendingPathComponent: @"UIKit.framework"];
  NSString *headers = [framework stringByAppendingPathComponent: @"Headers"];
  [manager createDirectoryAtPath: headers
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [@"/* SDK header */"
      writeToFile: [headers stringByAppendingPathComponent: @"UIKit.h"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  NSArray *roots = [NSArray arrayWithObject: frameworks];
  testAssert (![YCodeProject framework: @"UIKit" availableInDirectories: roots],
              @"Framework headers alone do not enable UIKit");
  [@"SDK linker stub"
      writeToFile: [framework stringByAppendingPathComponent: @"UIKit.tbd"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  testAssert (
      [YCodeProject framework: @"UIKit" availableInDirectories: roots],
      @"SDK frameworks resolve relative to paths containing spaces and accept linker stubs");
  NSString *flatHeaders =
      [root stringByAppendingPathComponent: @"Flat Headers"];
  NSString *flatLibraries =
      [root stringByAppendingPathComponent: @"Flat Libraries"];
  [manager createDirectoryAtPath: [flatHeaders
                                     stringByAppendingPathComponent: @"UIKit"]
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [manager createDirectoryAtPath: flatLibraries
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [@"/* UIKit */"
      writeToFile: [flatHeaders stringByAppendingPathComponent: @"UIKit/UIKit.h"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  testAssert (
      ![YCodeProject
          uiKitAvailableWithHeaders: [NSArray arrayWithObject: flatHeaders]
                          libraries: [NSArray arrayWithObject: flatLibraries]],
      @"Flat installations require a library as well as headers");
  [@"library"
      writeToFile: [flatLibraries stringByAppendingPathComponent: @"libUIKit.so"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  testAssert (
      [YCodeProject
          uiKitAvailableWithHeaders: [NSArray arrayWithObject: flatHeaders]
                          libraries: [NSArray arrayWithObject: flatLibraries]],
      @"Flat GNUstep header and library directories may be separate");
#ifndef _WIN32
  NSString *tool = [root stringByAppendingPathComponent: @"xcrun"];
  writeExecutable (
      tool,
      @"#!/bin/sh\n[ \"$1\" = --sdk ] && [ \"$2\" = iphonesimulator ] && [ \"$3\" = --show-sdk-path ] || exit 1\nprintf '%s\\n' \"$DEVELOPER_DIR/SDK Root\"\n");
  NSMutableDictionary *environment = [NSMutableDictionary
      dictionaryWithDictionary: [[NSProcessInfo processInfo] environment]];
  [environment setObject: [root stringByAppendingString: @":/usr/bin:/bin"]
                  forKey: @"PATH"];
  [environment setObject: root forKey: @"DEVELOPER_DIR"];
  NSUInteger i;
  for (i = 0; i < 2; i++)
    {
      NSTask *task = AUTORELEASE ([[NSTask alloc] init]);
      [task setLaunchPath: [[[NSProcessInfo processInfo] arguments]
                              objectAtIndex: 0]];
      [task setArguments: [NSArray arrayWithObjects: @"--check-uikit-sdk-path",
                                                   i == 0 ? sdk : @"", nil]];
      [task setEnvironment: environment];
      [task launch];
      [task waitUntilExit];
      testAssert (
          [task terminationStatus] == 0,
          @"SDK discovery respects PATH and DEVELOPER_DIR and handles unavailable SDKs");
      writeExecutable (tool, @"#!/bin/sh\nexit 1\n");
    }
#endif
}

static void
testUIKitProjectTemplates (NSString *directory)
{
  AppController *controller = AUTORELEASE ([[AppController alloc] init]);
  NSView *accessory = [controller newProjectAccessoryView];
  NSPopUpButton *frameworks = (NSPopUpButton *)[accessory viewWithTag: 102];
  NSPopUpButton *types = (NSPopUpButton *)[accessory viewWithTag: 100];
  testAssert (
      [frameworks numberOfItems] == 2 &&
          [[[frameworks selectedItem] representedObject] isEqual: @"AppKit"],
      @"New applications offer AppKit and UIKit and default to AppKit");
  testAssert ([[frameworks itemAtIndex: 1] isEnabled] ==
                  [YCodeProject supportsUIKitApplications],
              @"UIKit choice reflects installed GNUstep development support");
  [types selectItemAtIndex: 1];
  [NSApp sendAction: [types action] to: [types target] from: types];
  testAssert (![frameworks isEnabled],
              @"Non-application targets disable the app framework choice");
  [types selectItemAtIndex: 0];
  [NSApp sendAction: [types action] to: [types target] from: types];
  testAssert ([frameworks isEnabled],
              @"Application targets enable the framework choice");
  if (![YCodeProject supportsUIKitApplications])
    {
      testAssert (
          [YCodeProject
              createNewProjectAtPath: [directory stringByAppendingPathComponent:
                                                    @"UnavailableUIKit"]
                                name: @"UnavailableUIKit"
                                type: @"Xcode"
                         productType: @"Application"
                applicationFramework: @"UIKit"]
              == nil,
          @"Unavailable UIKit templates fail before writing a project");
      return;
    }
  NSArray *formats = [NSArray
      arrayWithObjects: @"Xcode", @"ProjectCenter", @"GNUmakefile", nil];
  NSUInteger i;
  for (i = 0; i < [formats count]; i++)
    {
      NSString *appKitName =
          [NSString stringWithFormat: @"AppKitStarter%lu", (unsigned long)i];
      NSString *appKitRoot =
          [directory stringByAppendingPathComponent: appKitName];
      YCodeProject *appKitProject =
          [YCodeProject createNewProjectAtPath: appKitRoot
                                          name: appKitName
                                          type: [formats objectAtIndex: i]
                                   productType: @"Application"];
      NSDictionary *appKitInfo = [NSDictionary
          dictionaryWithContentsOfFile:
              [appKitRoot
                  stringByAppendingPathComponent:
                      [appKitName stringByAppendingString: @"Info.plist"]]];
      testAssert (
          appKitProject != nil &&
              [[appKitInfo objectForKey: @"NSPrincipalClass"]
                  isEqual: @"NSApplication"]
              &&
              [[appKitInfo objectForKey: @"NSMainNibFile"] isEqual: @"MainMenu"],
          @"Existing creation API keeps AppKit applications as the default in all formats");
      NSString *name =
          [NSString stringWithFormat: @"UIKitStarter%lu", (unsigned long)i];
      NSString *root = [directory stringByAppendingPathComponent: name];
      YCodeProject *project =
          [YCodeProject createNewProjectAtPath: root
                                          name: name
                                          type: [formats objectAtIndex: i]
                                   productType: @"Application"
                          applicationFramework: @"UIKit"];
#ifndef GNUSTEP
      if (i != 0)
        {
          testAssert (
              project == nil
                  && ![[NSFileManager defaultManager] fileExistsAtPath: root],
              @"Apple UIKit rejects GNUstep-only formats before creating files");
          continue;
        }
#endif
      testAssert (project != nil,
                  @"Create UIKit applications in supported formats");
      NSDictionary *info = [NSDictionary
          dictionaryWithContentsOfFile:
              [root stringByAppendingPathComponent:
                        [name stringByAppendingString: @"Info.plist"]]];
      testAssert (
          [[info objectForKey: @"NSPrincipalClass"] isEqual: @"UIApplication"]
              && ![info objectForKey: @"NSMainNibFile"]
              && ![[NSFileManager defaultManager]
                  fileExistsAtPath:
                      [root stringByAppendingPathComponent: @"MainMenu.xib"]],
          @"UIKit metadata has no AppKit main nib");
      NSString *main =
          [NSString stringWithContentsOfFile:
                        [root stringByAppendingPathComponent: @"main.m"]
                                    encoding: NSUTF8StringEncoding
                                       error: NULL];
      testAssert (
          [main rangeOfString: @"UIApplicationMain"].location != NSNotFound,
          @"UIKit starters launch the application delegate through UIApplicationMain");
      if (i != 2)
        {
          PBXTarget *target = [[[project project] targets] objectAtIndex: 0];
          if (i == 0)
            {
              NSEnumerator *configurations = [[[target buildConfigurationList]
                  buildConfigurations] objectEnumerator];
              XCBuildConfiguration *configuration;
              while ((configuration = [configurations nextObject]) != nil)
                {
                  NSDictionary *settings = [configuration buildSettings];
                  testAssert (
                      [[settings objectForKey: @"SDKROOT"]
                          isEqual: @"iphonesimulator"]
                          && [[settings objectForKey: @"SUPPORTED_PLATFORMS"]
                              isEqual: @"iphoneos iphonesimulator"]
                          && [[settings objectForKey: @"TARGETED_DEVICE_FAMILY"]
                              isEqual: @"1,2"]
                          &&
                          [[settings objectForKey: @"PRODUCT_BUNDLE_IDENTIFIER"]
                              isEqual: [info
                                          objectForKey: @"CFBundleIdentifier"]],
                      @"UIKit Xcode configurations select an Apple SDK and matching app identity without absolute host paths");
                }
            }
          NSEnumerator *phases = [[target buildPhases] objectEnumerator];
          PBXBuildPhase *phase;
          BOOL linked = NO;
          while ((phase = [phases nextObject]) != nil)
            if ([phase isKindOfClass: [PBXFrameworksBuildPhase class]])
              {
                NSEnumerator *files = [[phase files] objectEnumerator];
                PBXBuildFile *file;
                while ((file = [files nextObject]) != nil)
                  if ([[[[file fileRef] path] lastPathComponent]
                          isEqual: @"UIKit.framework"])
                    {
                      linked = YES;
                      testAssert (
                          [[[file fileRef] lastKnownFileType]
                              isEqual: @"wrapper.framework"],
                          @"UIKit is serialized as a framework so Apple Xcode links it");
                      testAssert (
                          [[[file fileRef] sourceTree] isEqual: @"SDKROOT"]
                              && ![[[file fileRef] path] isAbsolutePath],
                          @"UIKit framework references are SDK-relative on every host");
                    }
              }
          testAssert (
              linked,
              @"UIKit projects link UIKit through the framework phase");
        }
      if (i != 0)
        {
          NSString *makefile = [NSString
              stringWithContentsOfFile:
                  [root stringByAppendingPathComponent: @"GNUmakefile"]
                              encoding: NSUTF8StringEncoding
                                 error: NULL];
          testAssert ([makefile rangeOfString: @"_GUI_LIBS += -lUIKit"].location
                              != NSNotFound
                          &&
                          [makefile rangeOfString: @"MAIN_MODEL_FILE"].location
                              == NSNotFound,
                      @"UIKit makefiles link UIKit without an AppKit model");
        }
    }
}

static void
testAppKitResourceTypes (NSString *directory)
{
  NSString *root =
      [directory stringByAppendingPathComponent: @"AppKit Resource Types"];
  YCodeProject *project = [YCodeProject createNewProjectAtPath: root
                                                          name: @"AppKitStarter"
                                                          type: @"Xcode"
                                                   productType: @"Application"];
  testAssert (project != nil,
              @"Create an AppKit project for native resource validation");
  YCodeProject *reopened = AUTORELEASE ([[YCodeProject alloc] init]);
  testAssert ([reopened
                  readFromURL: [NSURL fileURLWithPath: [project projectPath]]
                       ofType: @"YCodeXcodeProjectType"
                        error: NULL],
              @"Reopen the serialized AppKit project");
  PBXTarget *target = [[[reopened project] targets] lastObject];
  testAssert (
      [[[target productReference] explicitFileType]
          isEqual: @"wrapper.application"],
      @"Serialized AppKit product is an application bundle, not a XIB");
  BOOL found = NO;
  NSEnumerator *phases = [[target buildPhases] objectEnumerator];
  PBXBuildPhase *phase;
  while ((phase = [phases nextObject]) != nil)
    if ([phase isKindOfClass: [PBXResourcesBuildPhase class]])
      {
        NSEnumerator *files = [[phase files] objectEnumerator];
        PBXBuildFile *file;
        while ((file = [files nextObject]) != nil)
          if ([[[file fileRef] path] isEqual: @"MainMenu.xib"])
            {
              found = YES;
              testAssert (
                  [[[file fileRef] lastKnownFileType] isEqual: @"file.xib"],
                  @"Xcode's Resources phase recognizes MainMenu.xib as a compilable interface");
            }
      }
  testAssert (found, @"MainMenu.xib is included in the Resources build phase");
  NSDictionary *info = [NSDictionary
      dictionaryWithContentsOfFile:
          [root stringByAppendingPathComponent: @"AppKitStarterInfo.plist"]];
  testAssert ([[info objectForKey: @"NSMainNibFile"] isEqual: @"MainMenu"],
              @"The app loads the compiled MainMenu nib on macOS");
}

static void
testNewProjectTemplates (NSString *temporaryDirectory)
{
  AppController *controller = AUTORELEASE ([AppController new]);
  NSView *accessory = [controller newProjectAccessoryView];
  NSPopUpButton *types = (NSPopUpButton *)[accessory viewWithTag: 100];
  NSPopUpButton *formats = (NSPopUpButton *)[accessory viewWithTag: 101];
  testAssert (
      [types numberOfItems] == 6 && [formats numberOfItems] == 3,
      @"New-project accessory offers six target kinds and all three project formats");
  testAssert (
      [[[types selectedItem] representedObject] isEqual: @"Application"],
      @"New projects default to the application template");
  NSUInteger originalDocumentCount =
      [[[NSDocumentController sharedDocumentController] documents] count];
  NSTimer *timer =
      [NSTimer timerWithTimeInterval: 0.1
                              target: [YCodeNewProjectPanelTest class]
                            selector: @selector (cancelPanel:)
                            userInfo: nil
                             repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
  [controller newProject: nil];
  [timer invalidate];
  testAssert (
      [[[NSDocumentController sharedDocumentController] documents] count]
          == originalDocumentCount,
      @"Cancelling the location panel does not create a project");
  timer = [NSTimer timerWithTimeInterval: 0.1
                                  target: [YCodeNewProjectPanelTest class]
                                selector: @selector (cancelPanel:)
                                userInfo: temporaryDirectory
                                 repeats: YES];
  [[NSRunLoop currentRunLoop] addTimer: timer forMode: NSModalPanelRunLoopMode];
  [controller newProject: nil];
  [timer invalidate];
  NSString *createdRoot =
      [temporaryDirectory stringByAppendingPathComponent: @"Named New App"];
  NSString *createdPackage =
      [createdRoot stringByAppendingPathComponent: @"Named New App.xcodeproj"];
  testAssert (
      [[NSFileManager defaultManager] fileExistsAtPath: createdPackage] &&
          [[NSFileManager defaultManager]
              fileExistsAtPath: [createdRoot stringByAppendingPathComponent:
                                                @"ProjectObject.m"]],
      @"Create uses the typed name for a new project folder and the selected Bundle template");
  NSEnumerator *createdDocuments =
      [[NSArray arrayWithArray: [[NSDocumentController sharedDocumentController]
                                   documents]] objectEnumerator];
  YCodeProject *createdDocument;
  while ((createdDocument = [createdDocuments nextObject]) != nil)
    if ([[createdDocument projectPath] isEqual: createdPackage])
      [createdDocument close];
  NSArray *kinds = [YCodeProject newProjectTypes];
  NSArray *products = [NSArray
      arrayWithObjects: @"application", @"tool", @"bundle", @"framework",
                       @"library.dynamic", @"library.static", nil];
  NSUInteger format, index;
  for (format = 0; format < 3; format++)
    {
      for (index = 0; index < [kinds count]; index++)
        {
          NSString *kind = [kinds objectAtIndex: index];
          NSString *name = [NSString
              stringWithFormat: @"Starter%lu%@", (unsigned long)format, kind];
          NSString *root =
              [temporaryDirectory stringByAppendingPathComponent: name];
          NSString *projectFormat = format == 0   ? @"Xcode"
                                    : format == 1 ? @"ProjectCenter"
                                                  : @"GNUmakefile";
          YCodeProject *document =
              [YCodeProject createNewProjectAtPath: root
                                              name: name
                                              type: projectFormat
                                       productType: kind];
          testAssert (document != nil,
                      [NSString stringWithFormat: @"Create %@ %@ project",
                                                 projectFormat, kind]);
          if (!document)
            continue;
          PBXTarget *target
              = format == 2 ? nil
                            : [[[document project] targets] objectAtIndex: 0];
          if (format != 2)
            testAssert ([[target productType]
                            isEqual: [@"com.apple.product-type."
                                        stringByAppendingString:
                                            [products objectAtIndex: index]]],
                        @"Selected project kind determines the product type");
          YCodeProject *reopened = AUTORELEASE ([YCodeProject new]);
          testAssert (
              [reopened readFromURL: [document fileURL]
                             ofType: [document fileType]
                              error: NULL],
              @"Created project can be reopened in its selected format");
          if (format == 2)
            {
              testAssert (
                  [document isDirectoryProject] &&
                      [reopened isDirectoryProject] &&
                      [[document projectPath] isEqual: root] &&
                      [[document fileType] isEqual: @"YCodeMakeProjectType"],
                  @"GNUmakefile creation and reopening use the directory project workflow");
              NSFileManager *manager = [NSFileManager defaultManager];
              testAssert (
                  [manager
                      fileExistsAtPath:
                          [root stringByAppendingPathComponent: @"GNUmakefile"]]
                      && ![manager
                          fileExistsAtPath:
                              [root stringByAppendingPathComponent:
                                        [name stringByAppendingPathExtension:
                                                  @"pcproj"]]]
                      && ![manager
                          fileExistsAtPath:
                              [root stringByAppendingPathComponent:
                                        [name stringByAppendingPathExtension:
                                                  @"xcodeproj"]]],
                  @"GNUmakefile format creates a makefile without either project package");
            }
          if ([kind isEqual: @"Application"])
            {
              NSDictionary *info = [NSDictionary
                  dictionaryWithContentsOfFile:
                      [root stringByAppendingPathComponent:
                                [name stringByAppendingString: @"Info.plist"]]];
              testAssert (
                  [[info objectForKey: @"NSMainNibFile"] isEqual: @"MainMenu"],
                  @"Application metadata loads the starter interface");
              NSString *xib = [NSString
                  stringWithContentsOfFile:
                      [root stringByAppendingPathComponent: @"MainMenu.xib"]
                                  encoding: NSUTF8StringEncoding
                                     error: NULL];
              testAssert (
                  [xib rangeOfString: @"customClass=\"AppController\""].location
                          != NSNotFound
                      && [xib rangeOfString: @"property=\"window\""].location
                             != NSNotFound
                      &&
                      [xib rangeOfString: @"selector=\"terminate:\""].location
                          != NSNotFound,
                  @"Starter XIB connects AppController, window, and Quit action");
              testAssert (
                  [[NSFileManager defaultManager]
                      fileExistsAtPath: [root stringByAppendingPathComponent:
                                                 @"AppController.m"]],
                  @"Application includes AppController implementation");
              BOOL sourceFound = NO, resourceFound = NO;
              NSEnumerator *phases = [[target buildPhases] objectEnumerator];
              PBXBuildPhase *phase;
              while ((phase = [phases nextObject]) != nil)
                {
                  NSEnumerator *files = [[phase files] objectEnumerator];
                  PBXBuildFile *file;
                  while ((file = [files nextObject]) != nil)
                    {
                      if ([phase isKindOfClass: [PBXSourcesBuildPhase class]] &&
                          [[[file fileRef] path] isEqual: @"AppController.m"])
                        sourceFound = YES;
                      if ([phase isKindOfClass: [PBXResourcesBuildPhase class]]
                          && [[[file fileRef] path] isEqual: @"MainMenu.xib"])
                        resourceFound = YES;
                    }
                }
              if (format != 2)
                testAssert (
                    sourceFound && resourceFound,
                    @"Application source and XIB participate in the build");
            }
          else
            {
              testAssert (
                  ![[NSFileManager defaultManager]
                      fileExistsAtPath: [root stringByAppendingPathComponent:
                                                 @"MainMenu.xib"]],
                  @"Non-application templates do not include an application interface");
            }
          testAssert (
              [YCodeProject createNewProjectAtPath: root
                                              name: name
                                              type: projectFormat
                                       productType: kind]
                  == nil,
              @"New-project creation does not overwrite an existing project");
        }
    }
  testAssert ([YCodeProject
                  createNewProjectAtPath:
                      [temporaryDirectory
                          stringByAppendingPathComponent: @"Unsupported"]
                                    name: @"Unsupported"
                                    type: @"Xcode"
                             productType: @"Unknown"]
                  == nil,
              @"Unsupported project kinds are rejected");
}

static void
testProjectCreationInSelectedDirectory (NSString *temporaryDirectory)
{
  AppController *controller = AUTORELEASE ([AppController new]);
  NSUInteger format;
  for (format = 0; format < 3; format++)
    {
      NSString *name = format == 0   ? @"Selected App Folder"
                       : format == 1 ? @"Selected Tool Folder"
                                     : @"Selected Make Folder";
      NSString *directory =
          [temporaryDirectory stringByAppendingPathComponent: name];
      [[NSFileManager defaultManager] createDirectoryAtPath: directory
                                withIntermediateDirectories: YES
                                                 attributes: nil
                                                      error: NULL];
      [controller
          createNewProjectAtURL: [NSURL fileURLWithPath: directory]
                         format: format == 0   ? @"Xcode"
                                : format == 1 ? @"ProjectCenter"
                                              : @"GNUmakefile"
                    productType: format == 0 ? @"Application" : @"Tool"];
      NSString *package
          = format == 2
                ? directory
                : [directory
                      stringByAppendingPathComponent:
                          [name
                              stringByAppendingPathExtension: format == 0
                                                                 ? @"xcodeproj"
                                                                 : @"pcproj"]];
      testAssert (
          [[NSFileManager defaultManager] fileExistsAtPath: package],
          @"Selected directory supplies the project name and contains the project");
      testAssert (
          [[NSFileManager defaultManager]
              fileExistsAtPath: [directory
                                   stringByAppendingPathComponent: @"main.m"]]
              && ![[NSFileManager defaultManager]
                  fileExistsAtPath: [directory
                                       stringByAppendingPathComponent: name]],
          @"Create writes source directly into the selected folder, without another directory");
      NSEnumerator *documents = [[NSArray
          arrayWithArray: [[NSDocumentController sharedDocumentController]
                             documents]] objectEnumerator];
      YCodeProject *document;
      BOOL opened = NO;
      while ((document = [documents nextObject]) != nil)
        {
          if ([[document projectPath] isEqual: package])
            {
              opened = YES;
              [document close];
            }
        }
      testAssert (opened,
                  @"Created project opens immediately without a name prompt");
    }
}

static void
testPanelVisibilityPersistence (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id navigator = [[defaults objectForKey: @"YCodeNavigatorHidden"] retain];
  id inspector = [[defaults objectForKey: @"YCodeInspectorHidden"] retain];
  [defaults removeObjectForKey: @"YCodeNavigatorHidden"];
  [defaults removeObjectForKey: @"YCodeInspectorHidden"];
  YCodeWindowController *window = [YCodeWindowController new];
  testAssert ([window isNavigatorVisible] && [window isInspectorVisible],
              @"Navigator and inspector are visible by default");
  NSUInteger combination;
  for (combination = 0; combination < 4; combination++)
    {
      BOOL showNavigator = (combination & 1) != 0;
      BOOL showInspector = (combination & 2) != 0;
      [window setNavigatorVisible: showNavigator];
      [window setInspectorVisible: showInspector];
      NSTask *reader = [NSTask new];
      [reader setLaunchPath: [[[NSProcessInfo processInfo] arguments]
                                objectAtIndex: 0]];
      [reader setArguments: [NSArray
                               arrayWithObjects: @"--check-panel-state",
                                                showNavigator ? @"YES" : @"NO",
                                                showInspector ? @"YES" : @"NO",
                                                nil]];
      [reader launch];
      [reader waitUntilExit];
      testAssert (
          [reader terminationStatus] == 0,
          @"Fresh application windows restore each combination of navigator and inspector visibility");
      [reader release];
    }
  [window close];
  [window release];
  if (navigator)
    [defaults setObject: navigator forKey: @"YCodeNavigatorHidden"];
  else
    [defaults removeObjectForKey: @"YCodeNavigatorHidden"];
  if (inspector)
    [defaults setObject: inspector forKey: @"YCodeInspectorHidden"];
  else
    [defaults removeObjectForKey: @"YCodeInspectorHidden"];
  [navigator release];
  [inspector release];
  [defaults synchronize];
}

static void
testWindowFramePersistence (void)
{
  YCodeWindowController *first = [[YCodeWindowController alloc] init];
  NSRect firstFrame = [[first window] frame];
  NSRect frame = NSMakeRect (80, 70, 760, 480);
  [[first window] setFrame: frame display: NO];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSWindowDidMoveNotification
                    object: [first window]];
  YCodeWindowController *second = [[YCodeWindowController alloc] init];
  NSRect secondFrame = [[second window] frame];
  testAssert (NSEqualSizes (secondFrame.size, frame.size),
              @"New project windows restore the last main-window size");
  testAssert (NSMinX (secondFrame) > NSMinX (firstFrame)
                  && NSMaxY (secondFrame) < NSMaxY (firstFrame),
              @"Successive project windows cascade down and to the right");
  testAssert (![second shouldCascadeWindows],
              @"Automatic cascading does not override explicit placement");
  frame.origin = NSMakePoint (120, 100);
  frame.size = NSMakeSize (800, 500);
  [[second window] setFrame: frame display: NO];
  [second close];
  [second release];
  YCodeWindowController *reopened = [[YCodeWindowController alloc] init];
  testAssert (
      NSEqualSizes ([[reopened window] frame].size, frame.size),
      @"Closing a second project saves its size while another window remains open");
  testAssert (NSMinX ([[reopened window] frame]) > NSMinX (secondFrame)
                  && NSMaxY ([[reopened window] frame]) < NSMaxY (secondFrame),
              @"A third project continues the window cascade");
  [reopened close];
  [reopened release];
  [first close];
  [first release];
}

static void
testApplicationIcons (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *appPath = [temporaryDirectory
      stringByAppendingPathComponent: @"build/Icon Test.app"];
  NSString *resources = [appPath stringByAppendingPathComponent: @"Resources"];
  [manager createDirectoryAtPath: resources
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  [[NSDictionary dictionaryWithObject: @"AppIcon.png" forKey: @"NSIcon"]
      writeToFile: [resources
                      stringByAppendingPathComponent: @"Info-gnustep.plist"]
       atomically: YES];
  NSBitmapImageRep *bitmap =
      [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                              pixelsWide: 32
                                              pixelsHigh: 32
                                           bitsPerSample: 8
                                         samplesPerPixel: 4
                                                hasAlpha: YES
                                                isPlanar: NO
                                          colorSpaceName: NSDeviceRGBColorSpace
                                             bytesPerRow: 0
                                            bitsPerPixel: 0];
  NSInteger x, y;
  for (y = 0; y < 32; y++)
    for (x = 0; x < 32; x++)
      [bitmap setColor: [NSColor redColor] atX: x y: y];
  [[bitmap representationUsingType: NSPNGFileType
                        properties: [NSDictionary dictionary]]
      writeToFile: [resources stringByAppendingPathComponent: @"AppIcon.png"]
       atomically: YES];
  [bitmap release];

  YCodeProject *project = [[YCodeProject alloc] init];
  [project
      setProjectPath: [temporaryDirectory
                         stringByAppendingPathComponent: @"Icons.xcodeproj"]];
  YCodeProjectNavigatorController *navigator =
      [[YCodeProjectNavigatorController alloc] init];
  [navigator setProject: project];
  PBXFileReference *file = [[PBXFileReference alloc] init];
  [file setPath: appPath];
  YCodeProjectNavigatorItem *item = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject: file
                           type: YCodeNavigatorItemTypeFile];
  [navigator updateThumbnailForItem: item];
  NSBitmapImageRep *pixels =
      [NSBitmapImageRep imageRepWithData: [[item icon] TIFFRepresentation]];
  NSColor *color =
      [[pixels colorAtX: 8 y: 8] colorUsingColorSpaceName: NSDeviceRGBColorSpace];
  testAssert (color != nil && [color redComponent] > 0.9 &&
                  [color greenComponent] < 0.1,
              @"Navigator uses the application bundle's own icon");
  testAssert (NSEqualSizes ([[item icon] size], NSMakeSize (16, 16)),
              @"Application icon fits the navigator row");
  [file setPath: @"Icon Test.app"];
  [file setSourceTree: @"BUILT_PRODUCTS_DIR"];
  testAssert (
      [[navigator resolvedFilePathForNavigatorItem: item] isEqual: appPath],
      @"Products references resolve an existing compiled application");
  [file setPath: @"Missing.app"];
  testAssert ([navigator resolvedFilePathForNavigatorItem: item] == nil,
              @"An unbuilt application has no resolved product path");
  [item release];
  [file release];
  [navigator release];
  [project release];
}

static void
testWorkspaceFileOpening (NSString *temporaryDirectory)
{
  NSFileManager *manager = [NSFileManager defaultManager];
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  NSString *root =
      [temporaryDirectory stringByAppendingPathComponent: @"Workspace Files"];
  NSString *sources = [root stringByAppendingPathComponent: @"Sources"];
  [manager createDirectoryAtPath: sources
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *source = [sources stringByAppendingPathComponent: @"Example.m"];
  [@"int example;\n" writeToFile: source
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
  NSError *error = nil;
  testAssert ([controller openWorkspaceFile: source error: &error],
              @"Workspace opens a source without a project or Makefile");
  YCodeProject *project =
      [controller documentForURL: [NSURL fileURLWithPath: sources]];
  testAssert (
      [project isDirectoryProject] &&
          [[[[project editorController] currentDocument] filePath]
              isEqual: source],
      @"Plain-folder fallback opens the requested source in the editor");
  NSUInteger count = [[controller documents] count];
  testAssert ([controller openWorkspaceFile: source error: &error] &&
                  [[controller documents] count] == count,
              @"Repeated workspace opens reuse the existing project window");
  NSString *otherDirectory = [sources stringByAppendingString: @"-Other"];
  [manager createDirectoryAtPath: otherDirectory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *otherSource =
      [otherDirectory stringByAppendingPathComponent: @"Example.m"];
  [@"int other;\n" writeToFile: otherSource
                    atomically: YES
                      encoding: NSUTF8StringEncoding
                         error: NULL];
  testAssert (
      [controller openWorkspaceFile: otherSource error: &error] &&
          [[controller documents] count] == count + 1,
      @"A file outside all open projects opens its own directory document");
  YCodeProject *otherProject =
      [controller documentForURL: [NSURL fileURLWithPath: otherDirectory]];
  testAssert (
      otherProject != nil &&
          [[[[otherProject editorController] currentDocument] filePath]
              isEqual: otherSource]
          && [[[[project editorController] currentDocument] filePath]
              isEqual: source]
          &&
          [[project editorController] documentForFilePath: otherSource] == nil,
      @"Opening another project's file leaves the original project's tabs unchanged");
  NSString *nested = [sources stringByAppendingPathComponent: @"Nested"];
  [manager createDirectoryAtPath: nested
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *nestedSource =
      [nested stringByAppendingPathComponent: @"Example.m"];
  [@"int nested;\n" writeToFile: nestedSource
                     atomically: YES
                       encoding: NSUTF8StringEncoding
                          error: NULL];
  testAssert (
      [controller openWorkspaceFile: nestedSource error: &error] &&
          [[controller documents] count] == count + 1 &&
          [[[[project editorController] currentDocument] filePath]
              isEqual: nestedSource]
          && [[[[otherProject editorController] currentDocument] filePath]
              isEqual: otherSource],
      @"Nested source reuses its open parent directory rather than the active unrelated project");
  testAssert ([[[[project editorController] currentDocument] content]
                  isEqual: @"int nested;\n"],
              @"Same-named files are opened from the correct directory");
  YCodeProject *nestedProject =
      [controller openDocumentWithContentsOfURL: [NSURL fileURLWithPath: nested]
                                        display: YES
                                          error: &error];
  testAssert ([controller openWorkspaceFile: nestedSource error: &error] &&
                  [[[[nestedProject editorController] currentDocument]
                      filePath] isEqual: nestedSource],
              @"The most specific open directory receives the file");
  [nestedProject close];
  NSString *alias = [root stringByAppendingPathComponent: @"SourceAlias"];
  [manager createSymbolicLinkAtPath: alias
                withDestinationPath: sources
                              error: NULL];
  testAssert (
      [controller
          openWorkspaceFile: [alias stringByAppendingPathComponent: @"Example.m"]
                      error: &error]
          && [[controller documents] count] == count + 1 &&
          [[[[project editorController] currentDocument] filePath]
              isEqual: source],
      @"Symlink paths reuse the matching open directory and canonical source path");
  [otherProject close];
  [project close];
  NSString *package =
      [root stringByAppendingPathComponent: @"Example.xcodeproj"];
  [manager copyItemAtPath: @"../Ycode.xcodeproj" toPath: package error: NULL];
  testAssert ([controller openWorkspaceFile: source error: &error],
              @"Workspace finds a project above a source subdirectory");
  project = [controller documentForURL: [NSURL fileURLWithPath: package]];
  testAssert (
      project != nil && ![project isDirectoryProject] &&
          [[[[project editorController] currentDocument] filePath]
              isEqual: source],
      @"Existing Xcode project opens with the requested source selected");
  [project close];
  [manager removeItemAtPath: package error: NULL];
  package = [root stringByAppendingPathComponent: @"Example.pcproj"];
  [[NSDictionary dictionaryWithObjectsAndKeys: @"Example", @"PROJECT_NAME",
                                              @"Application", @"PROJECT_TYPE",
                                              nil] writeToFile: package
                                                    atomically: YES];
  testAssert ([controller openWorkspaceFile: source error: &error],
              @"Workspace finds a ProjectCenter project");
  project = [controller documentForURL: [NSURL fileURLWithPath: package]];
  testAssert (project != nil &&
                  [[[[project editorController] currentDocument] filePath]
                      isEqual: source],
              @"ProjectCenter workspace open selects the requested source");
  [project close];
  [manager removeItemAtPath: package error: NULL];
  [@"all:\n\t@true\n"
      writeToFile: [root stringByAppendingPathComponent: @"GNUmakefile"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  testAssert ([controller openWorkspaceFile: source error: &error],
              @"Workspace finds a parent Makefile folder");
  project = [controller documentForURL: [NSURL fileURLWithPath: root]];
  testAssert ([project isDirectoryProject] &&
                  [[project projectDirectoryPath] isEqual: root],
              @"Makefile folder becomes the directory project root");
  [project close];
  testAssert (
      ![controller
          openWorkspaceFile: [root stringByAppendingPathComponent: @"Missing.m"]
                      error: &error],
      @"Missing workspace files are rejected");
}

static void
waitForExternalFile (YCodeEditorDocument *document, NSString *content,
                     BOOL conflict)
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow: 3];
  while ([deadline timeIntervalSinceNow] > 0)
    {
      if ([[document content] isEqual: content] &&
          [document hasExternalChanges] == conflict)
        return;
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
    }
}

static void
testExternalFileChanges (NSString *temporaryDirectory)
{
  [NSApp finishLaunching];
  [NSApp activateIgnoringOtherApps: YES];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *directory =
      [temporaryDirectory stringByAppendingPathComponent: @"Watched Files"];
  [manager createDirectoryAtPath: directory
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *path = [directory stringByAppendingPathComponent: @"Example.m"];
  [@"original\n" writeToFile: path
                  atomically: YES
                    encoding: NSUTF8StringEncoding
                       error: NULL];
  YCodeEditorController *editor = [YCodeEditorController new];
  [editor setTabView: AUTORELEASE ([[YCodeEditorTabView alloc]
                         initWithFrame: NSMakeRect (0, 0, 600, 400)])];
  testAssert ([editor openFile: path],
              @"Open text file for event-driven reload");
  YCodeEditorDocument *document = [editor currentDocument];
  [[document textView] setSelectedRange: NSMakeRange (2, 2)];
  [@"external in-place\n" writeToFile: path
                           atomically: NO
                             encoding: NSUTF8StringEncoding
                                error: NULL];
  waitForExternalFile (document, @"external in-place\n", NO);
  testAssert (
      [[document content] isEqual: @"external in-place\n"]
          && ![document isModified],
      @"OS notification reloads an in-place edit without dirtying the file");
  testAssert (
      NSEqualRanges ([[document textView] selectedRange], NSMakeRange (2, 2)),
      @"External reload preserves selection");
  [@"atomic replacement\n" writeToFile: path
                            atomically: YES
                              encoding: NSUTF8StringEncoding
                                 error: NULL];
  waitForExternalFile (document, @"atomic replacement\n", NO);
  testAssert ([[document content] isEqual: @"atomic replacement\n"],
              @"Watch survives atomic replacement");
  [@"another replacement\n" writeToFile: path
                             atomically: YES
                               encoding: NSUTF8StringEncoding
                                  error: NULL];
  waitForExternalFile (document, @"another replacement\n", NO);
  testAssert ([[document content] isEqual: @"another replacement\n"],
              @"Replacement remains watched for subsequent changes");
  [document setContent: @"local edit\n"];
  [document setModified: YES];
  [@"conflicting edit\n" writeToFile: path
                          atomically: YES
                            encoding: NSUTF8StringEncoding
                               error: NULL];
  waitForExternalFile (document, @"local edit\n", YES);
  testAssert (
      [document hasExternalChanges] && [document isModified] &&
          [[document content] isEqual: @"local edit\n"],
      @"External changes preserve unsaved local edits and flag a conflict");
  testAssert (
      [[[[editor tabView] selectedTabViewItem] label] hasPrefix: @"! * "],
      @"Conflicted tab identifies both disk and local changes");
  answerCloseAlert (NSAlertThirdButtonReturn);
  testAssert (![document saveToFile] &&
                  [[NSString stringWithContentsOfFile: path
                                             encoding: NSUTF8StringEncoding
                                                error: NULL]
                      isEqual: @"conflicting edit\n"],
              @"Cancel saving does not overwrite an external change");
  answerCloseAlert (NSAlertSecondButtonReturn);
  testAssert ([document saveToFile] && ![document isModified] &&
                  [[document content] isEqual: @"conflicting edit\n"],
              @"Reload conflict resolution uses the disk version");
  [document setContent: @"keep local\n"];
  [document setModified: YES];
  [@"second conflict\n" writeToFile: path
                         atomically: YES
                           encoding: NSUTF8StringEncoding
                              error: NULL];
  // Save checks again even before an asynchronous notification has arrived.
  answerCloseAlert (NSAlertFirstButtonReturn);
  testAssert (
      [document saveToFile] &&
          [[NSString stringWithContentsOfFile: path
                                     encoding: NSUTF8StringEncoding
                                        error: NULL] isEqual: @"keep local\n"],
      @"Explicit overwrite resolves an external conflict");
  [manager removeItemAtPath: path error: NULL];
  waitForExternalFile (document, @"keep local\n", YES);
  testAssert ([document hasExternalChanges] &&
                  [[document content] isEqual: @"keep local\n"],
              @"Deletion preserves the editor contents");
  [@"recreated\n" writeToFile: path
                   atomically: YES
                     encoding: NSUTF8StringEncoding
                        error: NULL];
  waitForExternalFile (document, @"recreated\n", NO);
  testAssert ([[document content] isEqual: @"recreated\n"]
                  && ![document hasExternalChanges],
              @"Recreated file is still watched");
  NSString *secondPath =
      [directory stringByAppendingPathComponent: @"Supporting.md"];
  [@"supporting\n" writeToFile: secondPath
                    atomically: YES
                      encoding: NSUTF8StringEncoding
                         error: NULL];
  testAssert ([editor openFile: secondPath],
              @"Open another file in the watched directory");
  testAssert ([[editor valueForKey: @"_fileWatchers"] count] == 1,
              @"One watcher covers the open directory");
  [@"inactive tab\n" writeToFile: path
                      atomically: YES
                        encoding: NSUTF8StringEncoding
                           error: NULL];
  waitForExternalFile (document, @"inactive tab\n", NO);
  testAssert ([[document content] isEqual: @"inactive tab\n"],
              @"Inactive tabs remain watched after adding a file");
  [editor closeFile: path];
  testAssert ([[editor valueForKey: @"_fileWatchers"] count] == 1,
              @"Closing one tab keeps the other file watched");
  [editor closeFile: secondPath];
  testAssert ([[editor valueForKey: @"_fileWatchers"] count] == 0,
              @"Closing the last tab stops its directory watcher");
  [editor release];
}

static BOOL
delimiterHighlighted (YCodeTextView *view, NSUInteger index)
{
  return [[[view layoutManager] temporaryAttributesAtCharacterIndex: index
                                                     effectiveRange: NULL]
             objectForKey: NSBackgroundColorAttributeName]
         != nil;
}

static void
testMatchingDelimiters (void)
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id saved =
      [[defaults objectForKey: @"YCodeDisableMatchingDelimiters"] retain];
  [defaults removeObjectForKey: @"YCodeDisableMatchingDelimiters"];
  testAssert ([YCodePreferences highlightMatchingDelimiters],
              @"Matching delimiters default to enabled");
  YCodeTextView *view =
      [[YCodeTextView alloc] initWithFrame: NSMakeRect (0, 0, 500, 300)];
  NSArray *pairs =
      [NSArray arrayWithObjects: @"{ nested {} }", @"( nested () )",
                                @"[ nested [] ]", nil];
  NSEnumerator *enumerator = [pairs objectEnumerator];
  NSString *text;
  while ((text = [enumerator nextObject]) != nil)
    {
      [view setString: text];
      [view setSelectedRange: NSMakeRange (1, 0)];
      testAssert (
          delimiterHighlighted (view, [text length] - 1),
          @"Caret after opening delimiter highlights its nested match");
      [view setSelectedRange: NSMakeRange ([text length], 0)];
      testAssert (
          delimiterHighlighted (view, 0),
          @"Caret after closing delimiter highlights its opening match");
      [view setSelectedRange: NSMakeRange (0, 0)];
      testAssert (delimiterHighlighted (view, [text length] - 1),
                  @"Caret before opening delimiter highlights its match");
      [view setSelectedRange: NSMakeRange ([text length] - 1, 0)];
      testAssert (delimiterHighlighted (view, 0),
                  @"Caret before closing delimiter highlights its match");
      [view setSelectedRange: NSMakeRange (3, 0)];
      testAssert (!delimiterHighlighted (view, 0),
                  @"Moving away removes the highlight");
    }
  [view setString: @"{ /* } */ \"}\" }"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  testAssert (delimiterHighlighted (view, [[view string] length] - 1),
              @"Comments and quoted delimiters are ignored");
  [YCodePreferences setHighlightMatchingDelimiters: NO];
  testAssert (!delimiterHighlighted (view, [[view string] length] - 1),
              @"Disabling the preference clears existing highlights");
  [YCodePreferences setHighlightMatchingDelimiters: YES];
  testAssert (delimiterHighlighted (view, [[view string] length] - 1),
              @"Enabling the preference updates existing editors");
  [view setSelectedRange: NSMakeRange (0, 1)];
  testAssert (!delimiterHighlighted (view, [[view string] length] - 1),
              @"A text selection suppresses matching highlights");
  [view setString: @"{ unmatched"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  testAssert (!delimiterHighlighted (view, 0),
              @"Unmatched delimiters do not produce highlights");
  testAssert ([[view textStorage] attribute: NSBackgroundColorAttributeName
                                    atIndex: 0
                             effectiveRange: NULL]
                  == nil,
              @"Highlight does not modify stored text attributes");
  [view setString: @"{([])}"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  testAssert (delimiterHighlighted (view, 5),
              @"Mixed nested delimiter types match correctly");
  [view setString: @"{ more text }"];
  [[NSRunLoop currentRunLoop]
      runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
  testAssert (
      delimiterHighlighted (view, 0),
      @"Programmatic replacement refreshes matching at the updated caret");
  AppController *app = AUTORELEASE ([AppController new]);
  [app showPrefPanel: nil];
  NSButton *choice = [app valueForKey: @"_matchingDelimitersCheckbox"];
  testAssert (
      [choice isKindOfClass: [NSButton class]] && [choice state] == NSOnState,
      @"Editor preferences provide an enabled-by-default matching checkbox");
  [choice setState: NSOffState];
  [NSApp sendAction: [choice action] to: [choice target] from: choice];
  testAssert (![YCodePreferences highlightMatchingDelimiters]
                  && !delimiterHighlighted (view, 0),
              @"Preference checkbox disables highlighting immediately");
  [[app valueForKey: @"_preferencesPanel"] orderOut: nil];
  [YCodePreferences setHighlightMatchingDelimiters: YES];
  [view setBackgroundColor: [NSColor whiteColor]];
  [view setTextColor: [NSColor blackColor]];
  [view setFont: [NSFont userFixedPitchFontOfSize: 18]];
  [view setString: @"{  }"];
  [view setSelectedRange: NSMakeRange (1, 0)];
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 500, 300)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [window setReleasedWhenClosed: NO];
  [window setContentView: view];
  [window orderFront: nil];
  [view display];
  NSBitmapImageRep *bitmap =
      [view bitmapImageRepForCachingDisplayInRect: [view bounds]];
  [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
  NSUInteger yellowPixels = 0;
  NSInteger x, y;
  for (y = 0; y < [bitmap pixelsHigh]; y++)
    for (x = 0; x < [bitmap pixelsWide]; x++)
      {
        NSColor *pixel = [[bitmap colorAtX: x y: y]
            colorUsingColorSpaceName: NSDeviceRGBColorSpace];
        if ([pixel redComponent] > 0.9 && [pixel greenComponent] > 0.6 &&
            [pixel blueComponent] < 0.7)
          yellowPixels++;
      }
  testAssert (
      yellowPixels > 10,
      @"Matching delimiter highlight is visibly painted behind the glyph");
  NSString *imagePath = [[[NSProcessInfo processInfo] environment]
      objectForKey: @"YCODE_DELIMITER_IMAGE"];
  if (imagePath)[[bitmap representationUsingType: NSPNGFileType
                                      properties: [NSDictionary dictionary]]
      writeToFile: imagePath
       atomically: YES]
    ;
  [YCodePreferences setHighlightMatchingDelimiters: NO];
  [view display];
  [view cacheDisplayInRect: [view bounds] toBitmapImageRep: bitmap];
  yellowPixels = 0;
  for (y = 0; y < [bitmap pixelsHigh]; y++)
    for (x = 0; x < [bitmap pixelsWide]; x++)
      {
        NSColor *pixel = [[bitmap colorAtX: x y: y]
            colorUsingColorSpaceName: NSDeviceRGBColorSpace];
        if ([pixel redComponent] > 0.9 && [pixel greenComponent] > 0.6 &&
            [pixel blueComponent] < 0.7)
          yellowPixels++;
      }
  testAssert (yellowPixels == 0,
              @"Disabling matching removes the rendered highlight");
  [window close];
  [window release];
  [NSObject cancelPreviousPerformRequestsWithTarget: view];
  [view release];
  if (saved)
    [defaults setObject: saved forKey: @"YCodeDisableMatchingDelimiters"];
  else
    [defaults removeObjectForKey: @"YCodeDisableMatchingDelimiters"];
  [saved release];
}

static void
testLanguageBundles (NSString *directory)
{
  NSString *resources = [[NSBundle mainBundle] pathForResource: @"Languages"
                                                        ofType: nil];
  YCodeLanguageRegistry *registry = [[YCodeLanguageRegistry alloc]
      initWithSearchPaths: [NSArray arrayWithObject: resources]];
  testAssert (
      [[[registry languageForFile: @"Example.m"] identifier] isEqual: @"objc"],
      @"Load Objective-C from bundled definitions");
  testAssert (
      [[[registry languageForFile: @"Example.C"] identifier] isEqual: @"cpp"] &&
          [[[registry languageForFile: @"Example.c"] identifier] isEqual: @"c"],
      @"Preserve uppercase C distinction");
  testAssert ([[[registry languageForFile: @"GNUmakefile.postamble"] identifier]
                  isEqual: @"make"]
                  && [[[registry languageForFile: @"CMakeLists.txt"] identifier]
                      isEqual: @"cmake"],
              @"Match language filename rules");
  testAssert ([registry languageForFile: @"Unknown.unrecognized"] == nil,
              @"Unknown extension has plain-text fallback");
  testAssert (
      [[[registry languageForFile: @"Example.java"] identifier] isEqual: @"java"]
          && [[[registry languageForFile: @"Example.rb"] identifier]
              isEqual: @"ruby"]
          &&
          [[[registry languageForFile: @"Gemfile"] identifier] isEqual: @"ruby"],
      @"Discover Java and Ruby bundles including Ruby build files");
  YCodeLanguage *python = [registry languageForFile: @"example.py"];
  NSString *source = @"if ready: # }\n  value = \"\"\"[\n)\"\"\"\n  call()";
  NSString *code = [python codeByMaskingLiterals: source];
  testAssert (
      [code length] == [source length] &&
          [code rangeOfString: @"}"].location == NSNotFound &&
          [code rangeOfString: @"["].location == NSNotFound &&
          [code hasSuffix: @"call()"],
      @"Python comments and multiline strings share offset-preserving masking");

  NSString *bundle =
      [directory stringByAppendingPathComponent: @"Custom.ycode-language"];
  NSString *bundleResources =
      [bundle stringByAppendingPathComponent: @"Resources"];
  [[NSFileManager defaultManager] createDirectoryAtPath: bundleResources
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSString *manifest =
      [bundleResources stringByAppendingPathComponent: @"Language.plist"];
  NSMutableDictionary *definition = [NSMutableDictionary
      dictionaryWithObjectsAndKeys: @"custom", @"Identifier",
                                   [NSArray
                                       arrayWithObjects: @"demo", @"m", nil],
                                   @"Extensions",
                                   [NSDictionary
                                       dictionaryWithObject: @"\\bhello\\b"
                                                     forKey: @"keyword"],
                                   @"Patterns", @"preserve", @"Indentation",
                                   nil];
  NSMutableDictionary *info = [NSMutableDictionary
      dictionaryWithObjectsAndKeys: [NSNumber numberWithInt: 1], @"APIVersion",
                                   [NSArray arrayWithObject: definition],
                                   @"Languages", nil];
  [[NSPropertyListSerialization
      dataWithPropertyList: info
                    format: NSPropertyListXMLFormat_v1_0
                   options: 0
                     error: NULL] writeToFile: manifest atomically: YES];
  testAssert (
      [registry loadBundleAtPath: bundle] &&
          [[[registry languageForFile: @"file.demo"] identifier]
              isEqual: @"custom"]
          && [[[registry languageForFile: @"file.m"] identifier]
              isEqual: @"custom"],
      @"Install a new language and override an existing extension without editor changes");
  [info setObject: [NSNumber numberWithInt: 99] forKey: @"APIVersion"];
  [[NSPropertyListSerialization
      dataWithPropertyList: info
                    format: NSPropertyListXMLFormat_v1_0
                   options: 0
                     error: NULL] writeToFile: manifest atomically: YES];
  testAssert (![registry loadBundleAtPath: bundle],
              @"Reject unsupported bundle API version");
  [info setObject: [NSNumber numberWithInt: 1] forKey: @"APIVersion"];
  [definition setObject: [NSDictionary dictionaryWithObject: @"("
                                                    forKey: @"keyword"]
                 forKey: @"Patterns"];
  [[NSPropertyListSerialization
      dataWithPropertyList: info
                    format: NSPropertyListXMLFormat_v1_0
                   options: 0
                     error: NULL] writeToFile: manifest atomically: YES];
  testAssert (![registry loadBundleAtPath: bundle] &&
                  [[[registry languageForFile: @"file.demo"] identifier]
                      isEqual: @"custom"],
              @"Reject malformed patterns without replacing working language");
  [registry release];

  YCodeEditorDocument *document = [[YCodeEditorDocument alloc]
      initWithFilePath: [directory stringByAppendingPathComponent: @"example.py"]
               content: @"if ready: # comment"];
  YCodeTextView *view = (YCodeTextView *)[document textView];
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect: NSMakeRect (0, 0, 400, 300)
                                  styleMask: NSTitledWindowMask
                                    backing: NSBackingStoreBuffered
                                      defer: NO];
  [window setReleasedWhenClosed: NO];
  [window setContentView: [document editorView]];
  [window makeFirstResponder: view];
  NSUInteger width = [YCodePreferences controlIndentWidth];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  NSString *spaces = [@"" stringByPaddingToLength: width
                                       withString: @" "
                                  startingAtIndex: 0];
  testAssert ([[view string] hasSuffix: [@"\n" stringByAppendingString: spaces]],
              @"Python suite indentation uses configured spaces after colon");
  [document setContent: @"value = 'if ready:'"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert ([[view string] hasSuffix: @"'\n"],
              @"A colon inside a Python string does not indent");
  [document setContent: @"  first()\r\n\r\n  second()\r\nthird()"];
  [view setSelectedRange: NSMakeRange (
                             0,
                             [[view string] rangeOfString: @"third"].location)];
  NSString *original = [[view string] copy];
  NSUndoManager *undo = [view undoManager];
  [undo removeAllActions];
  [undo beginUndoGrouping];
  [view toggleLineComment: nil];
  [undo endUndoGrouping];
  testAssert (
      [[view string] isEqual: @"  # first()\r\n\r\n  # second()\r\nthird()"] &&
          [document isModified],
      @"Comment selection uses provider marker, preserves CRLF and marks document modified");
  [undo undo];
  testAssert ([[view string] isEqual: original],
              @"Commenting lines is one undoable edit");
  [undo redo];
  [view setSelectedRange: NSMakeRange (
                             0,
                             [[view string] rangeOfString: @"third"].location)];
  [view toggleLineComment: nil];
  testAssert ([[view string] isEqual: original],
              @"Uncomment restores selected lines");
  [original release];
  [view setFilePath: @"Example.java"];
  [document setContent: @"if (ready)"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert ([[view string] hasSuffix: [@"\n" stringByAppendingString: spaces]],
              @"Java control statements use configured indentation");
  [document setContent: @"class Example {"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  [view insertText: @"}"];
  testAssert ([[view string] isEqual: @"class Example {\n}"],
              @"Java closing brace aligns with its opening line");
  [view setFilePath: @"Example.rb"];
  [document setContent: @"class Example"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  [view insertText: @"def work"];
  [view insertNewline: nil];
  testAssert (
      [[view string] hasSuffix: [spaces stringByAppendingString: spaces]],
      @"Ruby nested blocks indent by configured spaces");
  [view insertText: @"end"];
  testAssert (
      [[view string] hasSuffix: [spaces stringByAppendingString: @"end"]],
      @"Ruby end aligns with def");
  [view insertNewline: nil];
  [view insertText: @"end"];
  testAssert ([[view string] hasSuffix: @"\nend"],
              @"Ruby outer end aligns with class");
  [view insertNewline: nil];
  testAssert ([[view string] hasSuffix: @"end\n"],
              @"Ruby does not indent after end");
  [document setContent: @"if ready"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  [view insertText: @"else"];
  testAssert ([[view string] isEqual: @"if ready\nelse"],
              @"Ruby else aligns with if");
  [view insertNewline: nil];
  testAssert ([[view string] hasSuffix: [@"\n" stringByAppendingString: spaces]],
              @"Ruby else body indents again");
  [document setContent: @"items.each do |item|"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert ([[view string] hasSuffix: spaces], @"Ruby do block indents");
  [view setFilePath: @"notes.unknown"];
  [document setContent: @"  if (ready)"];
  [view setSelectedRange: NSMakeRange ([[view string] length], 0)];
  [view insertNewline: nil];
  testAssert (
      [[view string] isEqual: @"  if (ready)\n  "],
      @"Plain text preserves indentation without applying C control rules");
  [window close];
  [window release];
  [document release];
}

static void
testProjectDocumentOpening (NSString *directory)
{
  NSString *package =
      [directory stringByAppendingPathComponent: @"Document.xcodeproj"];
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager createDirectoryAtPath: package
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSString *contents
      = @"{ objects = { ROOT = { isa = PBXProject; mainGroup = MAIN; }; MAIN = { isa = PBXGroup; children = (); sourceTree = \"<group>\"; }; }; rootObject = ROOT; }";
  [contents
      writeToFile: [package stringByAppendingPathComponent: @"project.pbxproj"]
       atomically: YES
         encoding: NSUTF8StringEncoding
            error: NULL];
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  NSURL *url = [NSURL fileURLWithPath: package];
  NSError *error = nil;
  testAssert (
      [[controller typeForContentsOfURL: url error: &error]
          isEqual: @"YCodeXcodeProjectType"],
      @"Xcode packages resolve to the project's internal document type");
  testAssert (
      [[controller
          typeForContentsOfURL:
              [NSURL fileURLWithPath: [directory stringByAppendingPathComponent:
                                                    @"Legacy.pcproj"]]
                         error: NULL] isEqual: @"YCodeProjectCenterProjectType"],
      @"ProjectCenter packages resolve to their internal document type");
  YCodeProject *project = [controller openDocumentWithContentsOfURL: url
                                                            display: NO
                                                              error: &error];
  testAssert ([project isKindOfClass: [YCodeProject class]] &&
                  [project project] != nil && error == nil,
              @"Open an Xcode package through NSDocumentController");
  testAssert ([controller openDocumentWithContentsOfURL: url
                                                display: NO
                                                  error: NULL]
                  == project,
              @"Opening the same Xcode package reuses its document");
  [project close];
}

static void
testWindowResizing (NSString *directory)
{
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  id savedFrame =
      [[defaults objectForKey: @"NSWindow Frame YCodeMainWindow"] retain];
  NSArray *sidebarKeys =
      [NSArray arrayWithObjects: @"YCodeNavigatorWidth", @"YCodeInspectorWidth",
                                @"YCodeInspectorHidden", nil];
  NSMutableDictionary *savedSidebars = [NSMutableDictionary dictionary];
  NSEnumerator *keys = [sidebarKeys objectEnumerator];
  NSString *key;
  while ((key = [keys nextObject]) != nil)
    if ([defaults objectForKey: key])
      [savedSidebars setObject: [defaults objectForKey: key] forKey: key];
  NSString *source = [directory stringByAppendingPathComponent: @"Resize.m"];
  [@"int main(void) { return 0; }\n" writeToFile: source
                                      atomically: YES
                                        encoding: NSUTF8StringEncoding
                                           error: NULL];
  YCodeProject *project = [YCodeProject new];
  testAssert ([project readFromURL: [NSURL fileURLWithPath: directory]
                            ofType: @"YCodeMakeProjectType"
                             error: NULL],
              @"Load a directory project for resize checks");
  YCodeWindowController *controller = [YCodeWindowController new];
  [controller setProject: project];
  NSOutlineView *outline = [[project navigatorController] outlineView];
  NSInteger sourceRow;
  for (sourceRow = 0; sourceRow < [outline numberOfRows]; sourceRow++)
    if ([[[project navigatorController]
            resolvedFilePathForNavigatorItem: [outline itemAtRow: sourceRow]]
            isEqual: source])
      break;
  testAssert (sourceRow < [outline numberOfRows],
              @"Source is visible in the navigator");
  if (sourceRow < [outline numberOfRows])
    [outline selectRowIndexes: [NSIndexSet indexSetWithIndex: sourceRow]
         byExtendingSelection: NO];
  testAssert (
      [[[[project editorController] currentDocument] filePath] isEqual: source],
      @"Selecting a navigator source opens its editor document");
  [[project editorController] closeFile: source];
  testAssert ([[project editorController] currentDocument] == nil,
              @"Closing the tab leaves the navigator selection intact");
  testAssert ([outline action] != NULL &&
                  [outline target] == [project navigatorController],
              @"Navigator has an explicit single-click action");
  if ([outline action])
    [[outline target] performSelector: [outline action] withObject: outline];
  testAssert (
      [[[[project editorController] currentDocument] filePath] isEqual: source],
      @"Clicking the selected navigator source reopens its editor");
  NSTabView *tabs = [[project editorController] tabView];
  testAssert (
      [[tabs selectedTabViewItem] view] ==
              [[[project editorController] currentDocument] editorView]
          && [[[[project editorController] currentDocument] textView] string]
                 != nil,
      @"Selected source has a visible editor tab and text contents");
  testAssert (
      ![[outline delegate] respondsToSelector: @selector (outlineView:
                                                  viewForTableColumn:item:)],
      @"Navigator uses its icon/text cells instead of empty row views");
  testAssert ([outline numberOfRows] > 0,
              @"Navigator keeps project rows visible");
  [[controller window] makeKeyAndOrderFront: nil];
  [controller setInspectorVisible: NO];
  NSUInteger index;
  for (index = 0; index < 8; index++)
    {
      [[controller window]
          setContentSize: NSMakeSize (800 + index * 70, 500 + index * 35)];
      [[controller window] displayIfNeeded];
      [[NSRunLoop currentRunLoop]
          runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02]];
    }
  testAssert ([[[[project editorController] currentDocument] content]
                  isEqual: @"int main(void) { return 0; }\n"],
              @"Repeated resizing preserves the open editor");
#ifndef GNUSTEP
  NSView *inspector = [controller valueForKey: @"_inspectorView"];
  testAssert (NSWidth ([inspector frame]) == 0,
              @"Resizing keeps the hidden inspector collapsed");
#endif
  [controller setInspectorVisible: YES];
  testAssert (NSWidth ([[controller valueForKey: @"_inspectorView"] frame]) > 0,
              @"Inspector can be restored after enlarging the window");
  [project close];
  [controller close];
  [controller release];
  [project release];
  if (savedFrame)
    [defaults setObject: savedFrame forKey: @"NSWindow Frame YCodeMainWindow"];
  else
    [defaults removeObjectForKey: @"NSWindow Frame YCodeMainWindow"];
  [savedFrame release];
  keys = [sidebarKeys objectEnumerator];
  while ((key = [keys nextObject]) != nil)
    if ([savedSidebars objectForKey: key])
      [defaults setObject: [savedSidebars objectForKey: key] forKey: key];
    else
      [defaults removeObjectForKey: key];
}

int
main (void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSFileManager *manager = [NSFileManager defaultManager];
  NSString *temporaryDirectory = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[NSProcessInfo processInfo]
                                         globallyUniqueString]];
  NSString *package = [temporaryDirectory
      stringByAppendingPathComponent: @"Sample Project.xcodeproj"];
  NSError *error = nil;
  YCodeDocumentController *controller =
      [YCodeDocumentController sharedDocumentController];
  YCodeProject *document;
  NSURL *url;

  [NSApplication sharedApplication];
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  if ([arguments containsObject: @"--check-project-documents"])
    {
      testProjectDocumentOpening (temporaryDirectory);
      if ([arguments count] == 3)
        {
          NSError *error = nil;
          YCodeProject *opened =
              [[YCodeDocumentController sharedDocumentController]
                  openDocumentWithContentsOfURL:
                      [NSURL fileURLWithPath: [arguments objectAtIndex: 2]]
                                        display: NO
                                          error: &error];
          testAssert (
              opened != nil && [opened project] != nil && error == nil,
              @"Open the supplied Xcode project through the document controller");
          [opened close];
        }
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode project document checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-window-resize"])
    {
      testWindowResizing (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode resize checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-editor-bundles"])
    {
      testEditorBundles ();
      testEditorBundleFiles (temporaryDirectory);
      testModelViewer (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode editor bundle checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-terminal-preferences"])
    {
      testTerminalPreferences (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode terminal preference checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-terminal"])
    {
      testTerminal (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode terminal checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-help"])
    {
      testHelp ();
      NSLog (@"Ycode help checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-debugger-bundles"])
    {
      testDebuggerBundles (temporaryDirectory);
      testDebuggerRecords ();
      testDebuggerVariables ();
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode debugger bundle checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-languages"])
    {
      testLanguageBundles (temporaryDirectory);
      testSyntaxHighlighting ();
      [[NSFileManager defaultManager] removeItemAtPath: temporaryDirectory
                                                 error: NULL];
      NSLog (@"Ycode language checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-colors"])
    {
      testEditorColorPreferences ();
      testEditorColors ();
      NSLog (@"Ycode editor color checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-delimiters"])
    {
      testMatchingDelimiters ();
      NSLog (@"Ycode delimiter checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-external-files"])
    {
      testExternalFileChanges (temporaryDirectory);
      testDirectoryWatching (temporaryDirectory);
      testLargeDirectoryWatching (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode external file checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-workspace-files"])
    {
      testWorkspaceFileOpening (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode workspace file checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-app-icons"])
    {
      testApplicationIcons (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode application icon checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-makefile-projects"])
    {
      testMakefileOpening (temporaryDirectory);
      testMakeDirectory (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode makefile project checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-find-replace"])
    {
      testFindReplace (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode find/replace checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }

  if ([arguments containsObject: @"--check-close-files"])
    {
      testCloseModifiedFiles (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode close-file checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-variables"])
    {
      testDebuggerVariables ();
      NSLog (@"Ycode debugger variable checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-completion"])
    {
      testWordCompletion ();
      testAutomaticCompletion ();
      NSLog (@"Ycode completion checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-editing"])
    {
      testEditorEditing (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode editing checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-file-modification"])
    {
      testFileWatchingPreference (temporaryDirectory);
      testFileModificationTracking (temporaryDirectory);
      testDirectoryWatching (temporaryDirectory);
      testLargeDirectoryWatching (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode file modification checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-output"])
    {
      testTranscriptCopy ();
      testDebuggerRecords ();
      NSLog (@"Ycode transcript and breakpoint checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-sound"])
    {
      testSoundInspector (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode sound inspector checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--read-tab-preferences"])
    {
      BOOL passed = [YCodePreferences tabWidth] == 4
                    && ![YCodePreferences useSpacesForTabs];
      [pool drain];
      return passed ? 0 : 1;
    }
  if ([arguments containsObject: @"--check-tabs"])
    {
      testTabPreferences (temporaryDirectory);
      testEditorColorPreferences ();
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode tab preference checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-test-navigation"])
    {
      testResultNavigation (temporaryDirectory);
      testSearchAndTestNavigator (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode test navigation checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-architecture"])
    {
      testArchitectureSelection (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode architecture checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments count] == 3 &&
      [arguments containsObject: @"--check-uikit-sdk-path"])
    {
      NSString *sdk = [YCodeProject uiKitSimulatorSDKPath];
      NSString *expected = [arguments objectAtIndex: 2];
      BOOL passed = [expected length] ? [sdk isEqual: expected] : sdk == nil;
      [pool drain];
      return passed ? 0 : 1;
    }
  if ([arguments containsObject: @"--check-uikit-projects"])
    {
      NSString *directory = [arguments count] == 3
                                ? [arguments objectAtIndex: 2]
                                : temporaryDirectory;
      testFrameworkDiscovery (directory);
      testUIKitProjectTemplates (directory);
      NSLog (@"Ycode UIKit template checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-appkit-resources"])
    {
      testAppKitResourceTypes (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode AppKit resource checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-new-project"])
    {
      testProjectCreationInSelectedDirectory (temporaryDirectory);
      testNewProjectTemplates (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode new-project checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-make-directory"])
    {
      testNavigatorFolderOrder ();
      testSynchronizedNavigator (temporaryDirectory);
      testMakeDirectory (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode Makefile directory checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--read-font-layout"])
    {
      NSUInteger i;
      BOOL passed = YES;
      for (i = 0; i < 4; i++)
        passed
            = passed &&
              [[YCodePreferences fontForPane: [[YCodePreferences fontPanes]
                                                 objectAtIndex: i]] pointSize]
                  == 18 + i;
      YCodeWindowController *window = [YCodeWindowController new];
      passed
          = passed
            && fabs (NSWidth ([[window valueForKey: @"_navigatorView"] frame])
                     - 280)
                   < 2
            && fabs (NSWidth ([[window valueForKey: @"_inspectorView"] frame])
                     - 210)
                   < 2;
      [window close];
      [window release];
      [pool drain];
      return passed ? 0 : 1;
    }
  if ([arguments containsObject: @"--check-font-layout"])
    {
      [NSApp finishLaunching];
      [NSApp activateIgnoringOtherApps: YES];
      testFontAndSidebarPreferences ();
      NSLog (@"Ycode font and sidebar checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments count] == 2 &&
      [[arguments objectAtIndex: 1] isEqual: @"--check-debug-gutter"])
    {
      testBreakpointFileTypes ();
      testHiddenRulersDebugGutter ();
      testDebuggerRecords ();
      NSLog (@"Ycode debugger gutter checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-issues"])
    {
      testBuildIssuesPane (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode issue checks: %lu failures", (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments containsObject: @"--check-build-run"])
    {
      testDebuggerRecords ();
      testBuildAndRun (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode build and run checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments count] == 2 &&
      [[arguments objectAtIndex: 1] isEqual: @"--check-target-toolbar"])
    {
      testBuildAndRun (temporaryDirectory);
      [manager removeItemAtPath: temporaryDirectory error: NULL];
      NSLog (@"Ycode target toolbar checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  if ([arguments count] == 4 &&
      [[arguments objectAtIndex: 1] isEqual: @"--check-panel-state"])
    {
      YCodeWindowController *window = [YCodeWindowController new];
      BOOL navigator = [[arguments objectAtIndex: 2] boolValue];
      BOOL inspector = [[arguments objectAtIndex: 3] boolValue];
      BOOL passed =
          [window isNavigatorVisible] == navigator &&
          [window isInspectorVisible] == inspector &&
          [[window valueForKey: @"_navigatorView"] isHidden] == !navigator &&
          [[window valueForKey: @"_inspectorView"] isHidden] == !inspector;
      [window close];
      [window release];
      [pool drain];
      return passed ? 0 : 1;
    }
  if ([arguments count] == 3 &&
      [[arguments objectAtIndex: 1] isEqual: @"--check-editor-preferences"])
    {
      YCodeEditorController *editor = [YCodeEditorController new];
      BOOL opened = [editor openFile: [arguments objectAtIndex: 2]];
      YCodeEditorDocument *source = [editor currentDocument];
      BOOL passed
          = opened
            && colorMatches ([[source textView] backgroundColor], 0.1, 0.2,
                             0.3)
            && colorMatches ([[source syntaxHighlighter] keywordColor], 0.18,
                             0.2, 0.3)
            && colorMatches ([[[source textView] textStorage]
                                      attribute: NSForegroundColorAttributeName
                                        atIndex: 4
                                 effectiveRange: NULL],
                             0.14, 0.2, 0.3)
            && ![[source scrollView] rulersVisible]
            && ![editor showLineNumbers];
      [editor closeFile: [arguments objectAtIndex: 2]];
      [editor release];
      [pool drain];
      return passed ? 0 : 1;
    }
  id savedWindowFrame = [[[NSUserDefaults standardUserDefaults]
      objectForKey: @"NSWindow Frame YCodeMainWindow"] retain];
  if ([arguments containsObject: @"--check-window-placement"])
    {
      testWindowFramePersistence ();
      if (savedWindowFrame)
        [[NSUserDefaults standardUserDefaults]
            setObject: savedWindowFrame
               forKey: @"NSWindow Frame YCodeMainWindow"];
      else
        [[NSUserDefaults standardUserDefaults]
            removeObjectForKey: @"NSWindow Frame YCodeMainWindow"];
      [savedWindowFrame release];
      NSLog (@"Ycode window placement checks: %lu failures",
             (unsigned long)failures);
      [pool drain];
      return failures ? 1 : 0;
    }
  testWordCompletion ();
  testAutomaticCompletion ();
  testPanelVisibilityPersistence ();
  testNavigatorFolderOrder ();
  testWindowFramePersistence ();
  testProjectCreationInSelectedDirectory (temporaryDirectory);
  testNewProjectTemplates (temporaryDirectory);
  testAppKitResourceTypes (temporaryDirectory);
  testFrameworkDiscovery (temporaryDirectory);
  testUIKitProjectTemplates (temporaryDirectory);
  testApplicationStartup ();
  testHelp ();
  testTerminal (temporaryDirectory);
  testTerminalPreferences (temporaryDirectory);
  testMatchingDelimiters ();
  testExternalFileChanges (temporaryDirectory);
  testWorkspaceFileOpening (temporaryDirectory);
  testProjectDocumentOpening (temporaryDirectory);
  testFontAndSidebarPreferences ();
  testSoundInspector (
      [temporaryDirectory stringByAppendingPathComponent: @"Sound Inspector"]);
  testTabPreferences (
      [temporaryDirectory stringByAppendingPathComponent: @"Tab Preferences"]);
  testEditorColorPreferences ();
  testEditorColors ();
  testApplicationIcons (temporaryDirectory);
  testHiddenRulersDebugGutter ();
  testBreakpointFileTypes ();
  testLanguageBundles (temporaryDirectory);
  testSyntaxHighlighting ();
  testDebuggerBundles (temporaryDirectory);
  testDebuggerVariables ();
  testCloseModifiedFiles (temporaryDirectory);
  testFindReplace (temporaryDirectory);
  testFileWatchingPreference (temporaryDirectory);
  testFileModificationTracking (temporaryDirectory);
  testDirectoryWatching (temporaryDirectory);
  testLargeDirectoryWatching (temporaryDirectory);
  testTranscriptCopy ();
  testDebuggerRecords ();
  testAssert ([manager createDirectoryAtPath: temporaryDirectory
                  withIntermediateDirectories: YES
                                   attributes: nil
                                        error: &error],
              @"Create test directory");
  testAssert ([manager copyItemAtPath: @"../Ycode.xcodeproj"
                               toPath: package
                                error: &error],
              @"Copy project fixture to a path with spaces");
  url = [NSURL fileURLWithPath: package];
  document = [controller openDocumentWithContentsOfURL: url
                                               display: NO
                                                 error: &error];
  testAssert (document != nil && error == nil,
              @"Open xcodeproj through document controller");
  testAssert ([[document project] isKindOfClass: [PBXProject class]],
              @"Decode PBXProject root");
  testAssert ([[[document project] targets] count] > 0, @"Load targets");
  testAssert ([[[[document project] mainGroup] children] count] > 0,
              @"Load groups and files");
  testAssert ([[document project] container] == [document container],
              @"Associate project with container");
  testAssert ([[[document container] filename]
                  isEqualToString: [package stringByAppendingPathComponent:
                                               @"project.pbxproj"]],
              @"Use package contents path");
  testAssert (
      [[document projectDirectoryPath] isEqualToString: temporaryDirectory],
      @"Resolve project directory");
  testAssert ([controller openDocumentWithContentsOfURL: url
                                                display: NO
                                                  error: &error]
                  == document,
              @"Reuse already open project document");

  [document makeWindowControllers];
  [document showWindows];
  testRecentDocuments (document, temporaryDirectory);
  YCodeProjectNavigatorController *navigator = [document navigatorController];
  testAssert ([[navigator rootItems] count] == 1,
              @"Populate project navigator");
  testNavigatorContextMenu (document);
  testAssert ([[navigator outlineView] numberOfRows] > 1,
              @"Display and expand project in window");
  testAssert ([[document windowControllers] count] == 1,
              @"Create project window");
  NSOutlineView *outline = [navigator outlineView];
  NSScrollView *navigatorScroll = [outline enclosingScrollView];
  testAssert ([outline gridStyleMask] == NSTableViewGridNone,
              @"Navigator has no grid lines");
  testAssert (NSContainsRect ([[navigatorScroll superview] bounds],
                              [navigatorScroll frame]),
              @"Navigator scroll view stays inside its section");
  testAssert (fabs (NSWidth ([navigatorScroll frame])
                    - NSWidth ([[navigatorScroll superview] bounds]))
                  < 1,
              @"Navigator scroll view fills the section width");
  testAssert (fabs ([[outline outlineTableColumn] width] -
                    [navigatorScroll contentSize].width)
                  < 3,
              @"Navigator column fits the available viewport");
  testAssert (NSMinX ([outline frame]) == 0
                  && NSMinX ([navigatorScroll documentVisibleRect]) == 0,
              @"Navigator rows start at the left of the viewport");
  NSWindow *projectWindow =
      [[[document windowControllers] objectAtIndex: 0] window];
  [projectWindow setContentSize: NSMakeSize (1100, 760)];
  testAssert (fabs ([[outline outlineTableColumn] width] -
                    [navigatorScroll contentSize].width)
                  < 3,
              @"Navigator column follows the viewport after resizing");
  testAssert (NSContainsRect ([[navigatorScroll superview] bounds],
                              [navigatorScroll frame]),
              @"Resized navigator stays inside its section");
  YCodeWindowController *windowController =
      [[document windowControllers] objectAtIndex: 0];
  NSSplitView *navigatorSplit =
      [windowController valueForKey: @"_mainSplitView"];
  [navigatorSplit setPosition: 300 ofDividerAtIndex: 0];
  testAssert (fabs ([[outline outlineTableColumn] width] -
                    [navigatorScroll contentSize].width)
                      < 3
                  && NSMinX ([outline frame]) == 0,
              @"Navigator remains fully visible after moving the divider");

  NSTabView *navigatorTabs =
      [windowController valueForKey: @"_navigatorTabView"];
  NSCell *navigatorCell = [[outline outlineTableColumn] dataCell];
  testAssert (
      [navigatorCell isKindOfClass: NSClassFromString (@"YCodeNavigatorCell")],
      @"Navigator cell draws an icon alongside the filename");
  NSArray *extensions =
      [NSArray arrayWithObjects: @"m", @"mm", @"c", @"C", @"cc", @"cp", @"cpp",
                                @"cxx", @"c++", @"h", @"hh", @"hpp", @"hxx",
                                @"h++", @"swift", @"plist", @"png", @"xib",
                                @"gorm", @"unknown", @"", nil];
  {
    NSEnumerator *extensionEnumerator = [extensions objectEnumerator];
    NSString *extension;
    while ((extension = [extensionEnumerator nextObject]) != nil)
      {
        PBXFileReference *file = [[PBXFileReference alloc]
            initWithPath: [@"Example"
                             stringByAppendingPathExtension: extension]];
        YCodeProjectNavigatorItem *item = [[YCodeProjectNavigatorItem alloc]
            initWithRepresentedObject: file
                                 type: YCodeNavigatorItemTypeFile];
        testAssert (
            [item icon] != nil
                && NSEqualSizes ([[item icon] size], NSMakeSize (16, 16)),
            [NSString stringWithFormat: @"Navigator has a small icon for '%@'",
                                       extension]);
        [[outline delegate] outlineView: outline
                        willDisplayCell: navigatorCell
                         forTableColumn: [outline outlineTableColumn]
                                   item: item];
        testAssert ([navigatorCell image] == [item icon],
                    @"Reused row receives its file icon");
        [item release];
        [file release];
      }
  }
  {
    NSEnumerator *nameEnumerator =
        [[NSArray arrayWithObjects: @"FileM", @"FileMM", @"FileC", @"FileH",
                                   @"FileProject", nil] objectEnumerator];
    NSString *name;
    while ((name = [nameEnumerator nextObject]) != nil)
      {
        NSString *path =
            [[NSBundle mainBundle] pathForResource: name
                                            ofType: @"tiff"
                                       inDirectory: @"ProjectCenterIcons"];
        NSImage *image
            = path ? [[NSImage alloc] initWithContentsOfFile: path] : nil;
        testAssert (image != nil,
                    @"ProjectCenter icon resources are bundled and readable");
        [image release];
      }
  }
  NSTabView *inspectorTabs =
      [windowController valueForKey: @"_inspectorTabView"];
  testAssert ([navigatorTabs isKindOfClass: [NSTabView class]] &&
                  [navigatorTabs numberOfTabViewItems] == 3,
              @"Navigator uses three native tabs");
  {
    NSEnumerator *itemEnumerator =
        [[navigatorTabs tabViewItems] objectEnumerator];
    NSTabViewItem *item;
    while ((item = [itemEnumerator nextObject]) != nil)
      testAssert (![[item label] isEqual: @"Issues"],
                  @"No Issues navigator tab");
  }
  [navigatorTabs selectTabViewItemWithIdentifier: @"search"];
  testAssert (
      [[[navigatorTabs selectedTabViewItem] identifier] isEqual: @"search"],
      @"Native navigator switches pages");
  [navigatorTabs selectTabViewItemWithIdentifier: @"project"];
  [windowController setupInspectorArea];
  [windowController setupNavigatorArea];
  testAssert (
      [inspectorTabs numberOfTabViewItems] == 3,
      @"Repeated setup keeps File, Image and Sound inspectors without duplicates");
  YCInspectorView *extra = [[YCInspectorView alloc] initWithFrame: NSZeroRect];
  [windowController registerInspectorView: extra];
  [windowController registerInspectorView: extra];
  testAssert ([inspectorTabs numberOfTabViewItems] == 4,
              @"Inspectors register uniquely");
  [extra release];
  NSString *inspectedPath =
      [temporaryDirectory stringByAppendingPathComponent: @"Inspector.m"];
  [@"int main(void) { return 0; }" writeToFile: inspectedPath
                                    atomically: YES
                                      encoding: NSUTF8StringEncoding
                                         error: NULL];
  YCodeEditorController *editor = [windowController editorController];
  [editor openFile: inspectedPath];
  NSView *fileInspector = [[inspectorTabs tabViewItemAtIndex: 0] view];
  NSTextView *details = [fileInspector valueForKey: @"_details"];
  testAssert (
      [[details string] rangeOfString: inspectedPath].location != NSNotFound &&
          [[details string] rangeOfString: @"Objective-C source"].location
              != NSNotFound,
      @"File inspector follows the active source file");
  NSString *imagePath =
      [temporaryDirectory stringByAppendingPathComponent: @"Preview.PNG"];
  NSBitmapImageRep *bitmap =
      [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                              pixelsWide: 32
                                              pixelsHigh: 24
                                           bitsPerSample: 8
                                         samplesPerPixel: 4
                                                hasAlpha: YES
                                                isPlanar: NO
                                          colorSpaceName: NSDeviceRGBColorSpace
                                             bytesPerRow: 0
                                            bitsPerPixel: 0];
  memset ([bitmap bitmapData], 128,
          [bitmap bytesPerRow] * [bitmap pixelsHigh]);
  NSData *imageData =
      [bitmap representationUsingType: NSPNGFileType
                           properties: [NSDictionary dictionary]];
  [imageData writeToFile: imagePath atomically: YES];
  [bitmap release];
  testAssert ([editor openFile: imagePath],
              @"Open image through the ordinary file selection path");
  YCodeEditorDocument *imageDocument = [editor currentDocument];
  testAssert ([imageDocument isImageDocument] &&
                  [imageDocument textView] == nil &&
                  [[[imageDocument scrollView] documentView]
                      isKindOfClass: [NSImageView class]]
                  && ![[imageDocument scrollView] rulersVisible],
              @"Image editor displays a preview without text or rulers");
  NSClipView *imageClip = [[imageDocument scrollView] contentView];
  NSRect imageFrame = [[[imageDocument scrollView] documentView] frame];
  testAssert (fabs (NSMidX ([imageClip bounds]) - NSMidX (imageFrame)) < 1
                  && fabs (NSMidY ([imageClip bounds]) - NSMidY (imageFrame))
                         < 1,
              @"Small image is centered in both axes");
  NSSize originalClipSize = [imageClip frame].size;
  [imageClip setFrameSize: NSMakeSize (180, 140)];
  testAssert (fabs (NSMidX ([imageClip bounds]) - NSMidX (imageFrame)) < 1
                  && fabs (NSMidY ([imageClip bounds]) - NSMidY (imageFrame))
                         < 1,
              @"Image stays centered when the viewport resizes");
  [[imageClip documentView] setFrameSize: NSMakeSize (10000, 10000)];
  [imageClip scrollToPoint: NSMakePoint (100, 100)];
  testAssert (NSMinX ([imageClip bounds]) == 100
                  && NSMinY ([imageClip bounds]) == 100,
              @"Images larger than the viewport remain scrollable");
  [[imageClip documentView] setFrameSize: imageFrame.size];
  [imageClip setFrameSize: originalClipSize];
  PBXFileReference *previewFile = [[PBXFileReference alloc] init];
  [previewFile setPath: imagePath];
  YCodeProjectNavigatorItem *previewItem = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject: previewFile
                           type: YCodeNavigatorItemTypeFile];
  NSImage *fallbackIcon = [[previewItem icon] retain];
  [navigator updateThumbnailForItem: previewItem];
  testAssert (
      [previewItem icon] != fallbackIcon
          && NSEqualSizes ([[previewItem icon] size], NSMakeSize (16, 12)),
      @"Readable image gets a miniature navigator thumbnail");
  NSBitmapImageRep *thumbnailPixels = [NSBitmapImageRep
      imageRepWithData: [[previewItem icon] TIFFRepresentation]];
  testAssert (
      [thumbnailPixels pixelsWide] <= 16 && [thumbnailPixels pixelsHigh] <= 16,
      @"Navigator stores downsampled pixels instead of the original image");
  testAssert ([[thumbnailPixels colorAtX: 8 y: 8] alphaComponent] > 0,
              @"Thumbnail retains decoded image pixels");
  navigatorCell = [[[navigator outlineView] outlineTableColumn] dataCell];
  [navigatorCell setImage: [previewItem icon]];
  NSRect thumbnailRect =
      [navigatorCell imageRectForBounds: NSMakeRect (0, 0, 100, 20)];
  testAssert (
      NSEqualSizes (thumbnailRect.size, NSMakeSize (16, 12))
          && NSMidY (thumbnailRect) == 10,
      @"Navigator centers the thumbnail without stretching its proportions");
  [fallbackIcon release];
  [previewItem release];
  [previewFile release];
  testAssert (
      [[[inspectorTabs selectedTabViewItem] identifier] isEqual: @"image"],
      @"Selecting an image shows its inspector");
  NSTextView *imageDetails =
      [[[inspectorTabs selectedTabViewItem] view] valueForKey: @"_details"];
  testAssert (
      [[imageDetails string] rangeOfString: @"32 × 24 pixels"].location
              != NSNotFound
          &&
          [[imageDetails string] rangeOfString: @"Transparency\nYes"].location
              != NSNotFound,
      @"Image inspector reports decoded dimensions and transparency");
  [imageDocument setContent: @"Do not overwrite image bytes"];
  [imageDocument insertText: @"text" atLocation: 0];
  testAssert (
      ![imageDocument isModified] && [editor saveCurrentFile] &&
          [[NSData dataWithContentsOfFile: imagePath] isEqual: imageData],
      @"Text editing and saving cannot corrupt an image");
  NSUInteger openCount = [[editor openDocuments] count];
  testAssert ([editor openFile: imagePath] &&
                  [[editor openDocuments] count] == openCount,
              @"Repeated image selection reuses its tab");
  testAssert ([imageDocument reloadFromFile], @"Reload image preview");
  [editor openFile: inspectedPath];
  testAssert (
      ![[editor currentDocument] isImageDocument] &&
          [[editor currentDocument] textView] != nil &&
          [[[inspectorTabs selectedTabViewItem] identifier] isEqual: @"file"] &&
          [[imageDetails string] isEqual: @"No image selected."],
      @"Switching back to source restores text editing and clears image details");
  NSString *invalidImage =
      [temporaryDirectory stringByAppendingPathComponent: @"Broken.png"];
  [@"not an image" writeToFile: invalidImage
                    atomically: YES
                      encoding: NSUTF8StringEncoding
                         error: NULL];
  PBXFileReference *brokenFile = [[PBXFileReference alloc] init];
  [brokenFile setPath: invalidImage];
  YCodeProjectNavigatorItem *brokenItem = [[YCodeProjectNavigatorItem alloc]
      initWithRepresentedObject: brokenFile
                           type: YCodeNavigatorItemTypeFile];
  NSImage *brokenIcon = [brokenItem icon];
  [navigator updateThumbnailForItem: brokenItem];
  testAssert ([brokenItem icon] == brokenIcon,
              @"Unreadable image retains the normal navigator file icon");
  [brokenItem release];
  [brokenFile release];
  testAssert (![editor openFile: invalidImage] &&
                  [[editor openDocuments] count] == openCount,
              @"Invalid images do not open as editable text");
  {
    NSEnumerator *openDocumentEnumerator =
        [[NSArray arrayWithArray: [editor openDocuments]] objectEnumerator];
    YCodeEditorDocument *openDocument;
    while ((openDocument = [openDocumentEnumerator nextObject]) != nil)
      [[[editor tabForDocument: openDocument] closeButton] performClick: nil];
  }
  testAssert ([[editor openDocuments] count] == 0,
              @"Close buttons remove both source and image tabs");
  testAssert ([[details string] isEqual: @"No source file selected."],
              @"Closing the final editor clears File inspector");

  testSaveActiveFile (document, temporaryDirectory);
  testProjectFileMembership (document, temporaryDirectory);

  // A failed read must report an error and preserve an already loaded project.
  PBXProject *originalProject = [document project];
  NSArray *invalidContents = [NSArray
      arrayWithObjects:
          @"", @"not a property list", @"{ objects = {}; }",
          @"{ objects = { ROOT = { isa = PBXGroup; }; }; rootObject = ROOT; }",
          nil];
  NSString *invalidPackage =
      [temporaryDirectory stringByAppendingPathComponent: @"Invalid.xcodeproj"];
  [manager createDirectoryAtPath: invalidPackage
      withIntermediateDirectories: YES
                       attributes: nil
                            error: NULL];
  NSUInteger index;
  for (index = 0; index < [invalidContents count]; index++)
    {
      if (index > 0)
        [[invalidContents objectAtIndex: index]
            writeToFile: [invalidPackage
                            stringByAppendingPathComponent: @"project.pbxproj"]
             atomically: YES
               encoding: NSUTF8StringEncoding
                  error: NULL];
      error = nil;
      testAssert (![document readFromURL: [NSURL fileURLWithPath: invalidPackage]
                                  ofType: @"YCodeXcodeProjectType"
                                   error: &error]
                      && error != nil,
                  @"Reject missing, malformed, or invalid project root");
      testAssert ([document project] == originalProject &&
                      [[document fileURL] isEqual: url],
                  @"Keep loaded document intact after failed read");
    }
  [document close];
  testWindowResizing (temporaryDirectory);
  testEditorEditing (temporaryDirectory);
  testEditorBundles ();
  testEditorBundleFiles (temporaryDirectory);
  testModelViewer (temporaryDirectory);
  testEditorFiles (temporaryDirectory);
  testProjectCenterImport (temporaryDirectory);
  testProjectCenterExport (temporaryDirectory);
  testResultNavigation (temporaryDirectory);
  testSearchAndTestNavigator (temporaryDirectory);
  testArchitectureSelection (temporaryDirectory);
  testMakefileOpening (temporaryDirectory);
  testMakeDirectory (temporaryDirectory);
  testSynchronizedNavigator (temporaryDirectory);
  testBuildAndRun (temporaryDirectory);
  testBuildIssuesPane (temporaryDirectory);
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  {
    NSEnumerator *keyEnumerator =
        [[[defaults dictionaryRepresentation] allKeys] objectEnumerator];
    NSString *key;
    while ((key = [keyEnumerator nextObject]) != nil)
      {
        if ([key hasPrefix: @"YCodeLastSourceFile:"] &&
            [key rangeOfString: temporaryDirectory].location != NSNotFound)
          [defaults removeObjectForKey: key];
      }
  }
  if (savedWindowFrame)
    [defaults setObject: savedWindowFrame
                 forKey: @"NSWindow Frame YCodeMainWindow"];
  else
    [defaults removeObjectForKey: @"NSWindow Frame YCodeMainWindow"];
  [savedWindowFrame release];
  [defaults synchronize];
  [manager removeItemAtPath: temporaryDirectory error: NULL];
  NSLog (@"Ycode project loading checks: %lu failures",
         (unsigned long)failures);
  [pool drain];
  return failures ? 1 : 0;
}
