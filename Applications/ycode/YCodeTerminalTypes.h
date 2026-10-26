/*
 * This file is part of Terminal.app.
 * Copyright (C) 2026 Terminal contributors.
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License, version 3 or later.
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See <https://www.gnu.org/licenses/> for a copy of the license.
 */

/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#ifndef YCodeTerminalTypes_h
#define YCodeTerminalTypes_h

#import <Foundation/Foundation.h>
#include <stdint.h>

@class NSEvent;

/* Application-owned terminal data. No external emulator ABI is exposed. */
typedef enum
{
  YCodeTerminalColorRGB,
  YCodeTerminalColorIndexed,
  YCodeTerminalColorDefaultForeground,
  YCodeTerminalColorDefaultBackground
} YCodeTerminalColorKind;

typedef struct
{
  YCodeTerminalColorKind kind;
  unsigned char index;
  struct
  {
    unsigned char red, green, blue;
  } rgb;
} YCodeTerminalColor;

typedef struct
{
  uint32_t chars[6];
  unsigned char width;
  unsigned short attributes;
  YCodeTerminalColor fg, bg;
} YCodeTerminalGlyph;

enum
{
  YCodeTerminalBold = 1,
  YCodeTerminalUnderline = 2,
  YCodeTerminalReverse = 4,
  YCodeTerminalBlink = 8,
  YCodeTerminalConceal = 16,
  YCodeTerminalItalic = 32,
  YCodeTerminalStrike = 64,
  YCodeTerminalProtected = 128,
  YCodeTerminalDim = 256,
  YCodeTerminalDoubleUnderline = 512
};

typedef struct
{
  /* Preserve full cells when history is restored after a resize. */
  YCodeTerminalGlyph originalCell;
  /* Resolved display colors; original palette indices stay in history. */
  YCodeTerminalColor foreground, background;
  unichar ch;
  unsigned char color;
  unsigned char attr;
  /*
bits
0,1   intensity, 0-2
2     underline
3     reverse
4     blink
5     unused
6     used as a selected flag internally
7     used as a dirty flag internally
*/
} YCodeTerminalCell;

/* Used as a marker. */
#define MULTI_CELL_GLYPH 0xfffe

@protocol YCodeTerminalScreen
- (void) ts_sendCString: (const char *)bytes length: (int)length;
- (void) ts_goto: (int)column row: (int)row;
- (void) ts_damageRow: (int)row;
- (void) ts_setTitle: (NSString *)title type: (int)type;
- (void) ts_setCursorVisible: (BOOL)visible;
- (void) ts_setCursorShape: (int)shape blink: (BOOL)blink;
- (void) ts_setAlternateScreen: (BOOL)alternate;
- (void) ts_setMouseReporting: (BOOL)enabled;
- (void) ts_bell;
- (void) ts_clearScrollback;
- (void) ts_appendScrollback: (const YCodeTerminalCell *)cells count: (int)count;
- (BOOL) ts_popScrollback: (YCodeTerminalCell *)cells count: (int)count;
@end
#endif
