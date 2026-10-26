/*
 * This file is part of Terminal.app.
 * Copyright (C) 2026 Terminal contributors.
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License, version 3 or later.
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See <https://www.gnu.org/licenses/> for a copy of the license.
 */

#ifndef YCodeTerminalParser_h
#define YCodeTerminalParser_h

#import "YCodeTerminalTypes.h"
#import <AppKit/NSEvent.h>
#import <Foundation/Foundation.h>

/* UTF-8 VT100/ANSI terminal with the xterm extensions used by text programs.
   All state belongs to this instance; the screen is a non-owning delegate. */
@interface YCodeTerminalParser : NSObject
{
  id<YCodeTerminalScreen> ts;
  int width, height, x, y, top, bottom, left, right;
  YCodeTerminalCell *primaryCells, *alternateCells, *cells;
  unsigned char *tabs, *dirtyRows;
  int cursorShape, mouseMode, mouseButton, mouseRow, mouseColumn;
  BOOL cursorBlink, focusReporting, mouseSGR, mouseUTF8;
  BOOL alternate, wrapPending, autoWrap, originMode, insertMode, newlineMode;
  BOOL cursorVisible, applicationCursor, applicationKeypad, bracketedPaste;
  BOOL leftRightMode, screenReverse;
  int savedX[2], savedY[2];
  BOOL savedWrap[2], savedOrigin[2];
  unsigned char savedCharset[2][4], savedShift[2];
  YCodeTerminalGlyph pen, savedPen[2];
  YCodeTerminalColor palette[256];
  unsigned char charset[4], shift, singleShift;
  uint32_t lastCharacter, utfValue, utfMinimum;
  int utfRemaining;
  int parseState, stringState, charsetSlot;
  char leader, intermediate;
  int parameters[32], parameterCount;
  BOOL colonParameter[32], invalidSequence, stringOverflow;
  NSMutableData *controlString;
}

- (id) initWithTerminalScreen: (id<YCodeTerminalScreen>)screen
                       width: (int)width
                      height: (int)height;
- (void) processBytes: (const char *)bytes length: (NSUInteger)length;
- (void) setTerminalScreenWidth: (int)width height: (int)height;
- (void) handleKeyEvent: (NSEvent *)event;
- (void) sendString: (NSString *)text;
- (void) reset: (BOOL)hard;
- (BOOL) getGlyph: (YCodeTerminalGlyph *)glyph row: (int)row column: (int)column;
- (YCodeTerminalColor) resolvedColor: (YCodeTerminalColor)color;
- (void) focusChanged: (BOOL)focused;
- (void) mouseAtRow: (int)row
            column: (int)column
            button: (int)button
           pressed: (BOOL)pressed
         modifiers: (NSUInteger)flags;
@end

#endif
