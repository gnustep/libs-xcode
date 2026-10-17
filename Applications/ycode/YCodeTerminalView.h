/*
   Copyright (C) 2026 Free Software Foundation

   This file is part of Ycode and is distributed under the GNU General
   Public License, version 2 or (at your option) any later version.
   See COPYING for details. There is no warranty.
*/

#ifndef _YCODETERMINALVIEW_H_
#define _YCODETERMINALVIEW_H_

#import <AppKit/AppKit.h>
#include "Terminal/libvterm/include/vterm.h"

/** A project-local interactive terminal. All screen and PTY I/O is on the main thread. */
@interface YCodeTerminalView : NSView
{
  VTerm *_terminal;
  VTermScreen *_screen;
  NSMutableArray *_history;
  NSMutableData *_pendingInput;
  NSString *_directory;
  NSFont *_font;
  NSFont *_boldFont;
  NSTimer *_timer;
  int _master;
  int _child;
  int _rows, _columns;
  CGFloat _cellWidth, _cellHeight;
  NSInteger _scrollOffset;
  NSInteger _selectionStart, _selectionEnd;
  BOOL _cursorVisible, _alternateScreen, _mouseReporting;
  BOOL _ended;
  BOOL _blinkOn, _cursorBlink;
  int _cursorShape;
  NSTimeInterval _lastBlink;
}
/** Starts an interactive shell in directory. Repeated calls preserve a running shell. */
- (BOOL)startInDirectory:(NSString *)directory error:(NSError **)error;
/** Hangs up the terminal and reaps its shell, without blocking the UI. */
- (void)stop;
- (BOOL)isRunning;
- (void)restart:(id)sender;
- (void)copy:(id)sender;
- (void)paste:(id)sender;
- (void)selectAll:(id)sender;
/** Feed terminal bytes, preserving parser state across partial sequences. */
- (void)consumeData:(NSData *)data;
/** Queue input for the PTY without blocking on a slow reader. */
- (void)sendData:(NSData *)data;
- (NSString *)screenText;
@end
#endif
