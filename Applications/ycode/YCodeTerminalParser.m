/*
 * This file is part of Terminal.app.
 * Copyright (C) 2026 Terminal contributors.
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License, version 3 or later.
 * This program is distributed WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See <https://www.gnu.org/licenses/> for a copy of the license.
 */

#import "YCodeTerminalParser.h"
#import <AppKit/NSGraphics.h>
#import <AppKit/NSText.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>

/* Parser states are deliberately bounded, including discarded control strings.
 */
enum
{
  Ground,
  Escape,
  CSI,
  OSC,
  DCS,
  IgnoredString,
  StringEscape,
  DesignateCharset,
  EscapeIntermediate
};

@interface YCodeTerminalParser (Implementation)

- (void) reset: (BOOL)hard;
- (void) flush;
- (void) consume: (unsigned char)byte;
- (void) writeCharacter: (uint32_t)code;
- (void) control: (unsigned char)byte;
- (void) executeCSI: (unsigned char)command;
- (void) finishString;
- (void) saveCursor;
- (void) restoreCursor;
- (void) lineFeed;
- (void) scroll: (int)count from: (int)first to: (int)last;
- (YCodeTerminalCell) blankCell;
- (YCodeTerminalCell) displayGlyph: (YCodeTerminalGlyph)glyph;
- (void) eraseRow: (int)row
            from: (int)first
              to: (int)last
       selective: (BOOL)selective;
- (void) repairRow: (int)row;
- (void) resetPen;
- (void) resetPalette;
- (void) applySGR;
- (void) setMode: (int)mode enabled: (BOOL)enabled private: (BOOL)privateMode;
- (int) modeValue: (int)mode private: (BOOL)privateMode;
- (void) useAlternate: (BOOL)enabled clear: (BOOL)clear;
- (void) send: (NSString *)string;
- (void) sendCodepoint: (uint32_t)code;
- (int) parameter: (int)index fallback: (int)value;
- (void) beginCSI;
- (void) beginString: (int)state;
- (void) moveToX: (int)column y: (int)row;
- (void) refreshColors;
- (YCodeTerminalColor) resolvedColor: (YCodeTerminalColor)color;
- (BOOL) parseColor: (NSString *)text into: (YCodeTerminalColor *)color;

@end

@implementation YCodeTerminalParser

- (id) initWithTerminalScreen: (id<YCodeTerminalScreen>)screen
                       width: (int)w
                      height: (int)h
{
  if ((self = [super init]))
    {
      ts = screen;
      width = MAX (1, w);
      height = MAX (1, h);
      primaryCells
          = calloc ((size_t)width * height, sizeof (YCodeTerminalCell));
      alternateCells
          = calloc ((size_t)width * height, sizeof (YCodeTerminalCell));
      tabs = calloc (width, 1);
      dirtyRows = calloc (height, 1);
      controlString = [[NSMutableData alloc] init];
      if (!primaryCells || !alternateCells || !tabs || !dirtyRows)
        {
          RELEASE (self);
          return nil;
        }
      cells = primaryCells;
      [self reset: YES];
      [self flush];
    }
  return self;
}

- (void) dealloc
{
  free (primaryCells);
  free (alternateCells);
  free (tabs);
  free (dirtyRows);
  DESTROY (controlString);
  DEALLOC;
}

- (void) resetPalette
{
  int i;
  for (i = 0; i < 256; i++)
    {
      YCodeTerminalColor color;
      memset (&color, 0, sizeof (color));
      color.kind = YCodeTerminalColorRGB;
      if (i < 16)
        {
          int level = i < 8 ? 224 : 255;
          int low = i < 8 ? 0 : 64;
          color.rgb.red = (i & 1) ? level : low;
          color.rgb.green = (i & 2) ? level : low;
          color.rgb.blue = (i & 4) ? level : low;
          if (i == 8)
            color.rgb.red = color.rgb.green = color.rgb.blue = 128;
        }
      else if (i < 232)
        {
          int cube = i - 16;
          int r = cube / 36, g = (cube / 6) % 6, b = cube % 6;
          color.rgb.red = r ? 55 + 40 * r : 0;
          color.rgb.green = g ? 55 + 40 * g : 0;
          color.rgb.blue = b ? 55 + 40 * b : 0;
        }
      else
        color.rgb.red = color.rgb.green = color.rgb.blue = 8 + 10 * (i - 232);
      palette[i] = color;
    }
}

- (void) resetPen
{
  memset (&pen, 0, sizeof (pen));
  pen.width = 1;
  pen.fg.kind = YCodeTerminalColorDefaultForeground;
  pen.bg.kind = YCodeTerminalColorDefaultBackground;
}

- (void) reset: (BOOL)hard
{
  int i;
  [self resetPen];
  top = left = 0;
  bottom = height - 1;
  right = width - 1;
  autoWrap = cursorVisible = YES;
  wrapPending = originMode = insertMode = newlineMode = NO;
  applicationCursor = applicationKeypad = bracketedPaste = NO;
  leftRightMode = screenReverse = NO;
  cursorShape = 1;
  cursorBlink = YES;
  focusReporting = mouseSGR = mouseUTF8 = NO;
  mouseMode = mouseButton = 0;
  mouseRow = mouseColumn = -1;
  [ts ts_setMouseReporting: NO];
  [ts ts_setCursorShape: cursorShape blink: cursorBlink];
  memset (charset, 0, sizeof (charset));
  shift = 0;
  singleShift = 4;
  if (hard)
    {
      alternate = NO;
      [ts ts_setAlternateScreen: NO];
      cells = primaryCells;
      x = y = 0;
      parseState = Ground;
      utfRemaining = 0;
      lastCharacter = 0;
      [controlString setLength: 0];
      [self resetPalette];
      for (i = 0; i < width; i++)
        tabs[i] = i && i % 8 == 0;
      for (i = 0; i < 2; i++)
        {
          savedX[i] = savedY[i] = 0;
          savedWrap[i] = savedOrigin[i] = NO;
          savedPen[i] = pen;
          savedShift[i] = 0;
          memset (savedCharset[i], 0, 4);
        }
      YCodeTerminalCell blank = [self blankCell];
      size_t n, count = (size_t)width * height;
      for (n = 0; n < count; n++)
        primaryCells[n] = alternateCells[n] = blank;
    }
  memset (dirtyRows, 1, height);
}

- (YCodeTerminalColor) resolvedColor: (YCodeTerminalColor)color
{
  if (color.kind == YCodeTerminalColorIndexed)
    return palette[color.index];
  return color;
}

- (YCodeTerminalCell) displayGlyph: (YCodeTerminalGlyph)glyph
{
  YCodeTerminalCell cell;
  int fg
      = glyph.fg.kind == YCodeTerminalColorIndexed ? glyph.fg.index & 15 : 7;
  int bg
      = glyph.bg.kind == YCodeTerminalColorIndexed ? glyph.bg.index & 15 : 0;
  memset (&cell, 0, sizeof (cell));
  cell.originalCell = glyph;
  cell.foreground = [self resolvedColor: glyph.fg];
  cell.background = [self resolvedColor: glyph.bg];
  cell.ch = glyph.width == 0 ? MULTI_CELL_GLYPH
                             : (glyph.chars[0] > 0xffff
                                    ? 0xfffd
                                    : (glyph.chars[0] ? glyph.chars[0] : ' '));
  if (glyph.attributes & YCodeTerminalConceal)
    cell.ch = ' ';
  /* The old display's packed color field uses BGR bit ordering. */
  fg = (fg & 10) | ((fg & 1) << 2) | ((fg & 4) >> 2);
  bg = (bg & 10) | ((bg & 1) << 2) | ((bg & 4) >> 2);
  cell.color = fg | (bg << 4);
  cell.attr = (glyph.attributes & YCodeTerminalBold ? 2 : 1)
              | (glyph.attributes & YCodeTerminalUnderline ? 4 : 0)
              | (glyph.attributes & YCodeTerminalReverse ? 8 : 0)
              | (glyph.attributes & YCodeTerminalBlink ? 16 : 0);
  return cell;
}

- (YCodeTerminalCell) blankCell
{
  YCodeTerminalGlyph glyph = pen;
  memset (glyph.chars, 0, sizeof (glyph.chars));
  glyph.width = 1;
  /* Erased space inherits colors, but not protected or concealed text. */
  glyph.attributes = 0;
  return [self displayGlyph: glyph];
}

- (void) flush
{
  int row;
  for (row = 0; row < height; row++)
    if (dirtyRows[row])
      {
        [ts ts_damageRow: row];
        dirtyRows[row] = 0;
      }
  [ts ts_goto: x row: y];
  [ts ts_setCursorVisible: cursorVisible];
}

- (BOOL) getGlyph: (YCodeTerminalGlyph *)glyph row: (int)row column: (int)column
{
  if (row < 0 || row >= height || column < 0 || column >= width)
    return NO;
  *glyph = cells[row * width + column].originalCell;
  if (screenReverse)
    glyph->attributes ^= YCodeTerminalReverse;
  return YES;
}

- (void) refreshColors
{
  size_t i, count = (size_t)width * height;
  for (i = 0; i < count; i++)
    {
      primaryCells[i] = [self displayGlyph: primaryCells[i].originalCell];
      alternateCells[i] = [self displayGlyph: alternateCells[i].originalCell];
    }
  memset (dirtyRows, 1, height);
}

- (void) saveCursor
{
  int slot = alternate ? 1 : 0;
  savedX[slot] = x;
  savedY[slot] = y;
  savedWrap[slot] = wrapPending;
  savedOrigin[slot] = originMode;
  savedPen[slot] = pen;
  savedShift[slot] = shift;
  memcpy (savedCharset[slot], charset, 4);
}

- (void) restoreCursor
{
  int slot = alternate ? 1 : 0;
  originMode = savedOrigin[slot];
  pen = savedPen[slot];
  shift = savedShift[slot];
  memcpy (charset, savedCharset[slot], 4);
  [self moveToX: savedX[slot] y: savedY[slot]];
  wrapPending = savedWrap[slot] && x == right;
}

- (void) moveToX: (int)column y: (int)row
{
  x = MAX (originMode && leftRightMode ? left : 0,
           MIN (originMode && leftRightMode ? right : width - 1, column));
  y = MAX (originMode ? top : 0, MIN (originMode ? bottom : height - 1, row));
  wrapPending = NO;
}

- (void) repairRow: (int)row
{
  int column;
  YCodeTerminalCell blank = [self blankCell];
  for (column = 0; column < width; column++)
    {
      YCodeTerminalCell *cell = &cells[row * width + column];
      if (cell->originalCell.width == 2)
        {
          if (column + 1 >= width
              || cells[row * width + column + 1].originalCell.width != 0)
            *cell = blank;
        }
      else if (cell->originalCell.width == 0
               && (column == 0
                   || cells[row * width + column - 1].originalCell.width != 2))
        *cell = blank;
    }
  dirtyRows[row] = 1;
}

- (void) eraseRow: (int)row
            from: (int)first
              to: (int)last
       selective: (BOOL)selective
{
  int column;
  YCodeTerminalCell blank = [self blankCell];
  first = MAX (0, first);
  last = MIN (width - 1, last);
  for (column = first; column <= last; column++)
    if (!selective
        || !(cells[row * width + column].originalCell.attributes
             & YCodeTerminalProtected))
      cells[row * width + column] = blank;
  [self repairRow: row];
}

- (void) scroll: (int)count from: (int)first to: (int)last
{
  int row, column, n = MIN (abs (count), last - first + 1);
  int l = leftRightMode ? left : 0, r = leftRightMode ? right : width - 1;
  if (!n || first < 0 || last >= height || first > last)
    return;
  if (count > 0)
    {
      if (!alternate && first == 0 && last == height - 1 && l == 0
          && r == width - 1)
        for (row = 0; row < n; row++)
          [ts ts_appendScrollback: &cells[row * width] count: width];
      for (row = first; row <= last - n; row++)
        memmove (&cells[row * width + l], &cells[(row + n) * width + l],
                 (r - l + 1) * sizeof (YCodeTerminalCell));
    }
  else
    for (row = last; row >= first + n; row--)
      memmove (&cells[row * width + l], &cells[(row - n) * width + l],
               (r - l + 1) * sizeof (YCodeTerminalCell));
  YCodeTerminalCell blank = [self blankCell];
  for (row = count > 0 ? last - n + 1 : first;
       row <= (count > 0 ? last : first + n - 1); row++)
    for (column = l; column <= r; column++)
      cells[row * width + column] = blank;
  for (row = first; row <= last; row++)
    [self repairRow: row];
}

- (void) lineFeed
{
  if (y == bottom && x >= left && x <= right)
    [self scroll: 1 from: top to: bottom];
  else if (y < height - 1)
    y++;
  if (newlineMode)
    x = leftRightMode ? left : 0;
  wrapPending = NO;
}

- (void) writeCharacter: (uint32_t)code
{
  int size, i, active = singleShift < 4 ? singleShift : shift;
  singleShift = 4;
  if (code < 128 && charset[active] == 1 && code >= 0x60 && code <= 0x7e)
    {
      /* DEC Special Graphics, in character-code order. */
      static const uint32_t graphics[]
          = { 0x25c6, 0x2592, 0x2409, 0x240c, 0x240d, 0x240a, 0x00b0, 0x00b1,
              0x2424, 0x240b, 0x2518, 0x2510, 0x250c, 0x2514, 0x253c, 0x23ba,
              0x23bb, 0x2500, 0x23bc, 0x23bd, 0x251c, 0x2524, 0x2534, 0x252c,
              0x2502, 0x2264, 0x2265, 0x03c0, 0x2260, 0x00a3, 0x00b7 };
      code = graphics[code - 0x60];
    }
  else if (code == '#' && charset[active] == 2)
    code = 0x00a3;
  size = 1;
  if ([[NSCharacterSet nonBaseCharacterSet] longCharacterIsMember: code]
      || code == 0x200b || code == 0x200c || code == 0x200d || code == 0xfeff)
    size = 0;
  else if (code >= 0x1100
           && (code <= 0x115f || code == 0x2329 || code == 0x232a
               || (code >= 0x2e80 && code <= 0xa4cf && code != 0x303f)
               || (code >= 0xac00 && code <= 0xd7a3)
               || (code >= 0xf900 && code <= 0xfaff)
               || (code >= 0xfe10 && code <= 0xfe19)
               || (code >= 0xfe30 && code <= 0xfe6f)
               || (code >= 0xff01 && code <= 0xff60)
               || (code >= 0xffe0 && code <= 0xffe6)
               || (code >= 0x1f300 && code <= 0x1faff)
               || (code >= 0x20000 && code <= 0x3fffd)))
    size = 2;
  if (!size)
    {
      int previous = wrapPending ? x : x - 1;
      if (previous < 0)
        return;
      if (cells[y * width + previous].originalCell.width == 0 && previous > 0)
        previous--;
      YCodeTerminalGlyph glyph = cells[y * width + previous].originalCell;
      for (i = 1; i < 6 && glyph.chars[i]; i++)
        ;
      if (i < 6)
        glyph.chars[i] = code;
      cells[y * width + previous] = [self displayGlyph: glyph];
      dirtyRows[y] = 1;
      return;
    }
  int edge = leftRightMode && x <= right ? right : width - 1;
  if (wrapPending || x + size - 1 > edge)
    {
      if (autoWrap)
        {
          [self lineFeed];
          x = leftRightMode ? left : 0;
        }
      else if (size == 2 && x == edge)
        return;
      wrapPending = NO;
    }
  if (width < 2)
    size = 1;
  edge = leftRightMode && x <= right ? right : width - 1;
  if (insertMode)
    {
      int moved = MAX (0, edge - x + 1 - size);
      memmove (&cells[y * width + x + size], &cells[y * width + x],
               moved * sizeof (YCodeTerminalCell));
    }
  [self eraseRow: y from: x to: x + size - 1 selective: NO];
  YCodeTerminalGlyph glyph = pen;
  memset (glyph.chars, 0, sizeof (glyph.chars));
  glyph.chars[0] = code;
  glyph.width = size;
  cells[y * width + x] = [self displayGlyph: glyph];
  if (size == 2)
    {
      glyph.width = 0;
      glyph.chars[0] = 0;
      cells[y * width + x + 1] = [self displayGlyph: glyph];
    }
  [self repairRow: y];
  lastCharacter = code;
  if (x + size > edge)
    {
      x = edge;
      wrapPending = autoWrap;
    }
  else
    x += size;
}

- (void) useAlternate: (BOOL)enabled clear: (BOOL)clear
{
  if (enabled == alternate)
    return;
  alternate = enabled;
  [ts ts_setAlternateScreen: enabled];
  cells = enabled ? alternateCells : primaryCells;
  if (enabled && clear)
    {
      YCodeTerminalCell blank = [self blankCell];
      size_t i;
      for (i = 0; i < (size_t)width * height; i++)
        cells[i] = blank;
    }
  wrapPending = NO;
  /* Resizing may have clipped a wide glyph in the inactive buffer. */
  int row;
  for (row = 0; row < height; row++)
    [self repairRow: row];
}

- (void) setMode: (int)mode enabled: (BOOL)enabled private: (BOOL)privateMode
{
  if (!privateMode)
    {
      if (mode == 4)
        insertMode = enabled;
      if (mode == 20)
        newlineMode = enabled;
      return;
    }
  switch (mode)
    {
    case 1:
      applicationCursor = enabled;
      break;
    case 5:
      screenReverse = enabled;
      memset (dirtyRows, 1, height);
      break;
    case 6:
      originMode = enabled;
      [self moveToX: left y: top];
      if (!enabled)
        [self moveToX: 0 y: 0];
      break;
    case 7:
      autoWrap = enabled;
      wrapPending = NO;
      break;
    case 12:
      cursorBlink = enabled;
      [ts ts_setCursorShape: cursorShape blink: cursorBlink];
      break;
    case 1000:
    case 1002:
    case 1003:
      mouseMode = enabled ? mode : 0;
      mouseButton = 0;
      [ts ts_setMouseReporting: mouseMode != 0];
      break;
    case 1004:
      focusReporting = enabled;
      break;
    case 1005:
      mouseUTF8 = enabled;
      break;
    case 1006:
      mouseSGR = enabled;
      break;
    case 25:
      cursorVisible = enabled;
      break;
    case 47:
      [self useAlternate: enabled clear: NO];
      break;
    case 66:
      applicationKeypad = enabled;
      break;
    case 69:
      leftRightMode = enabled;
      if (!enabled)
        {
          left = 0;
          right = width - 1;
        }
      break;
    case 1047:
      [self useAlternate: enabled clear: enabled];
      break;
    case 1048:
      if (enabled)
        [self saveCursor];
      else
        [self restoreCursor];
      break;
    case 1049:
      if (enabled && !alternate)
        {
          [self saveCursor];
          [self useAlternate: YES clear: YES];
          [self moveToX: 0 y: 0];
        }
      else if (!enabled && alternate)
        {
          [self useAlternate: NO clear: NO];
          [self restoreCursor];
        }
      break;
    case 2004:
      bracketedPaste = enabled;
      break;
    }
}

- (int) modeValue: (int)mode private: (BOOL)privateMode
{
  BOOL value;
  if (!privateMode)
    {
      if (mode == 4)
        value = insertMode;
      else if (mode == 20)
        value = newlineMode;
      else
        return 0;
    }
  else
    switch (mode)
      {
      case 1:
        value = applicationCursor;
        break;
      case 5:
        value = screenReverse;
        break;
      case 6:
        value = originMode;
        break;
      case 7:
        value = autoWrap;
        break;
      case 12:
        value = cursorBlink;
        break;
      case 1000:
      case 1002:
      case 1003:
        value = mouseMode == mode;
        break;
      case 1004:
        value = focusReporting;
        break;
      case 1005:
        value = mouseUTF8;
        break;
      case 1006:
        value = mouseSGR;
        break;
      case 25:
        value = cursorVisible;
        break;
      case 47:
      case 1047:
      case 1049:
        value = alternate;
        break;
      case 66:
        value = applicationKeypad;
        break;
      case 69:
        value = leftRightMode;
        break;
      case 2004:
        value = bracketedPaste;
        break;
      default:
        return 0;
      }
  return value ? 1 : 2;
}

- (void) send: (NSString *)string
{
  NSData *data = [string dataUsingEncoding: NSUTF8StringEncoding];
  [ts ts_sendCString: [data bytes] length: [data length]];
}

- (void) sendCodepoint: (uint32_t)code
{
  unichar units[2];
  int length = 1;
  if (code > 0xffff)
    {
      code -= 0x10000;
      units[0] = 0xd800 + (code >> 10);
      units[1] = 0xdc00 + (code & 1023);
      length = 2;
    }
  else
    units[0] = code;
  [self send: [NSString stringWithCharacters: units length: length]];
}

- (int) parameter: (int)index fallback: (int)value
{
  return index < parameterCount && parameters[index] >= 0 ? parameters[index]
                                                          : value;
}

- (void) applySGR
{
  int i;
  for (i = 0; i < parameterCount; i++)
    {
      int value = MAX (0, parameters[i]);
      if (value == 0)
        [self resetPen];
      else if (value == 1)
        pen.attributes |= YCodeTerminalBold;
      else if (value == 2)
        pen.attributes |= YCodeTerminalDim;
      else if (value == 3)
        pen.attributes |= YCodeTerminalItalic;
      else if (value == 4 || value == 21)
        {
          pen.attributes |= YCodeTerminalUnderline;
          pen.attributes &= ~YCodeTerminalDoubleUnderline;
          if (value == 21)
            pen.attributes |= YCodeTerminalDoubleUnderline;
        }
      else if (value == 5 || value == 6)
        pen.attributes |= YCodeTerminalBlink;
      else if (value == 7)
        pen.attributes |= YCodeTerminalReverse;
      else if (value == 8)
        pen.attributes |= YCodeTerminalConceal;
      else if (value == 9)
        pen.attributes |= YCodeTerminalStrike;
      else if (value == 22)
        pen.attributes &= ~(YCodeTerminalBold | YCodeTerminalDim);
      else if (value == 23)
        pen.attributes &= ~YCodeTerminalItalic;
      else if (value == 24)
        pen.attributes
            &= ~(YCodeTerminalUnderline | YCodeTerminalDoubleUnderline);
      else if (value == 25)
        pen.attributes &= ~YCodeTerminalBlink;
      else if (value == 27)
        pen.attributes &= ~YCodeTerminalReverse;
      else if (value == 28)
        pen.attributes &= ~YCodeTerminalConceal;
      else if (value == 29)
        pen.attributes &= ~YCodeTerminalStrike;
      else if (value == 39)
        pen.fg.kind = YCodeTerminalColorDefaultForeground;
      else if (value == 49)
        pen.bg.kind = YCodeTerminalColorDefaultBackground;
      else if ((value >= 30 && value <= 37) || (value >= 90 && value <= 97))
        {
          pen.fg.kind = YCodeTerminalColorIndexed;
          pen.fg.index = value >= 90 ? value - 90 + 8 : value - 30;
        }
      else if ((value >= 40 && value <= 47) || (value >= 100 && value <= 107))
        {
          pen.bg.kind = YCodeTerminalColorIndexed;
          pen.bg.index = value >= 100 ? value - 100 + 8 : value - 40;
        }
      else if (value == 38 || value == 48)
        {
          YCodeTerminalColor *color = value == 38 ? &pen.fg : &pen.bg;
          int mode = [self parameter: ++i fallback: 0];
          if (mode == 5 && i + 1 < parameterCount)
            {
              int index = parameters[++i];
              if (index >= 0 && index < 256)
                {
                  color->kind = YCodeTerminalColorIndexed;
                  color->index = index;
                }
            }
          else if (mode == 2)
            {
              /* Colon form may include an empty/zero colorspace identifier. */
              if (i + 4 < parameterCount && colonParameter[i + 1]
                  && colonParameter[i + 4])
                i++;
              if (i + 3 < parameterCount)
                {
                  int r = parameters[i + 1], g = parameters[i + 2],
                      b = parameters[i + 3];
                  if (r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0
                      && b <= 255)
                    {
                      color->kind = YCodeTerminalColorRGB;
                      color->rgb.red = r;
                      color->rgb.green = g;
                      color->rgb.blue = b;
                    }
                  i += 3;
                }
              else
                i = parameterCount;
            }
        }
      if (value == 4 && i + 1 < parameterCount && colonParameter[i + 1])
        {
          if (parameters[++i] == 0)
            pen.attributes
                &= ~(YCodeTerminalUnderline | YCodeTerminalDoubleUnderline);
          else if (parameters[i] == 2)
            pen.attributes |= YCodeTerminalDoubleUnderline;
        }
    }
}

- (void) executeCSI: (unsigned char)command
{
  int n = MAX (1, [self parameter: 0 fallback: 1]);
  int mode = [self parameter: 0 fallback: 0];
  int row, i, l = leftRightMode ? left : 0,
              r = leftRightMode ? right : width - 1;
  BOOL privateMode = leader == '?';
  if (invalidSequence)
    return;
  if (intermediate == ' ' && command == 'q' && !leader)
    {
      if (mode >= 0 && mode <= 6)
        {
          cursorShape = mode <= 2 ? 1 : (mode <= 4 ? 2 : 3);
          cursorBlink = mode == 0 || (mode & 1);
          [ts ts_setCursorShape: cursorShape blink: cursorBlink];
        }
      return;
    }
  if (intermediate == '$' && command == 'p')
    {
      [self send: [NSString stringWithFormat: @"\033[%@%d;%d$y",
                                            privateMode ? @"?" : @"", mode,
                                            [self modeValue: mode
                                                    private: privateMode]]];
      return;
    }
  if (intermediate == '!' && command == 'p')
    {
      [self reset: NO];
      return;
    }
  if (intermediate == '"' && command == 'q')
    {
      if (mode == 1)
        pen.attributes |= YCodeTerminalProtected;
      else
        pen.attributes &= ~YCodeTerminalProtected;
      return;
    }
  if (intermediate)
    return;
  if (leader && !privateMode
      && !(leader == '>' && (command == 'c' || command == 'q')))
    return;
  if (privateMode && command != 'h' && command != 'l' && command != 'J'
      && command != 'K' && command != 'n')
    return;
  switch (command)
    {
    case 'A':
      [self moveToX: x y: MAX (y >= top ? top : 0, y - n)];
      break;
    case 'B':
    case 'e':
      [self moveToX: x y: MIN (y <= bottom ? bottom : height - 1, y + n)];
      break;
    case 'C':
    case 'a':
      [self moveToX: MIN (x <= r ? r : width - 1, x + n) y: y];
      break;
    case 'D':
      [self moveToX: MAX (x >= l ? l : 0, x - n) y: y];
      break;
    case 'E':
      [self moveToX: l y: y + n];
      break;
    case 'F':
      [self moveToX: l y: y - n];
      break;
    case 'G':
    case '`':
      [self moveToX: n - 1 + (originMode ? l : 0) y: y];
      break;
    case 'd':
      [self moveToX: x y: n - 1 + (originMode ? top : 0)];
      break;
    case 'H':
    case 'f':
      [self moveToX: MAX (1, [self parameter: 1 fallback: 1]) - 1
                    + (originMode ? l : 0)
                  y: n - 1 + (originMode ? top : 0)];
      break;
    case 'I':
      for (i = 0; i < MIN (n, width); i++)
        {
          do
            {
              if (x < r)
                x++;
              else
                break;
            }
          while (!tabs[x]);
        }
      wrapPending = NO;
      break;
    case 'Z':
      for (i = 0; i < MIN (n, width); i++)
        {
          do
            {
              if (x > l)
                x--;
              else
                break;
            }
          while (!tabs[x]);
        }
      wrapPending = NO;
      break;
    case 'g':
      if (mode == 0)
        tabs[x] = 0;
      else if (mode == 3)
        memset (tabs, 0, width);
      break;
    case 'J':
      if (mode == 3)
        [ts ts_clearScrollback];
      else if (mode <= 2)
        for (row = mode == 0 ? y : 0; row <= (mode == 1 ? y : height - 1);
             row++)
          [self eraseRow: row
                    from: mode == 0 && row == y ? x : 0
                      to: mode == 1 && row == y ? x : width - 1
               selective: privateMode];
      wrapPending = NO;
      break;
    case 'K':
      if (mode <= 2)
        [self eraseRow: y
                  from: mode == 0 ? x : 0
                    to: mode == 1 ? x : width - 1
             selective: privateMode];
      wrapPending = NO;
      break;
    case 'X':
      [self eraseRow: y from: x to: MIN (r, x + n - 1) selective: NO];
      break;
    case '@':
    case 'P':
      if (x < l || x > r)
        break;
      n = MIN (n, r - x + 1);
      if (command == '@')
        {
          memmove (&cells[y * width + x + n], &cells[y * width + x],
                   (r - x + 1 - n) * sizeof (YCodeTerminalCell));
          [self eraseRow: y from: x to: x + n - 1 selective: NO];
        }
      else
        {
          memmove (&cells[y * width + x], &cells[y * width + x + n],
                   (r - x + 1 - n) * sizeof (YCodeTerminalCell));
          [self eraseRow: y from: r - n + 1 to: r selective: NO];
        }
      [self repairRow: y];
      wrapPending = NO;
      break;
    case 'L':
    case 'M':
      if (y >= top && y <= bottom && x >= l && x <= r)
        [self scroll: command == 'M' ? n : -n from: y to: bottom];
      wrapPending = NO;
      break;
    case 'S':
    case 'T':
      [self scroll: command == 'S' ? n : -n from: top to: bottom];
      break;
    case 'b':
      if (lastCharacter)
        for (i = 0; i < MIN (n, width * height); i++)
          [self writeCharacter: lastCharacter];
      break;
    case 'r':
      {
        int first = n - 1,
            last = MAX (1, [self parameter: 1 fallback: height]) - 1;
        if (first >= 0 && first < last && last < height)
          {
            top = first;
            bottom = last;
            [self moveToX: originMode ? l : 0 y: originMode ? top : 0];
          }
      }
      break;
    case 's':
      if (!leftRightMode)
        [self saveCursor];
      else
        {
          int first = n - 1,
              last = MAX (1, [self parameter: 1 fallback: width]) - 1;
          if (first >= 0 && first < last && last < width)
            {
              left = first;
              right = last;
              [self moveToX: originMode ? left : 0 y: originMode ? top : 0];
            }
        }
      break;
    case 'u':
      [self restoreCursor];
      break;
    case 'm':
      [self applySGR];
      break;
    case 'h':
    case 'l':
      for (i = 0; i < parameterCount; i++)
        [self setMode: parameters[i]
              enabled: command == 'h'
              private: privateMode];
      break;
    case 'n':
      if (mode == 5 && !privateMode)
        [self send: @"\033[0n"];
      else if (mode == 6)
        [self send: [NSString stringWithFormat: @"\033[%@%d;%dR",
                                              privateMode ? @"?" : @"",
                                              y + 1 - (originMode ? top : 0),
                                              x + 1 - (originMode ? l : 0)]];
      break;
    case 'c':
      if (leader == '>')
        [self send: @"\033[>0;100;0c"];
      else if (mode == 0)
        [self send: @"\033[?1;2c"];
      break;
    case 'q':
      if (leader == '>')
        [self send: @"\033P>|GNUstep Terminal\033\\"];
      break;
    case 't':
      if (mode == 18 || mode == 19)
        [self send: [NSString stringWithFormat: @"\033[%d;%d;%dt",
                                              mode == 18 ? 8 : 9, height,
                                              width]];
      break;
    }
}

- (BOOL) parseColor: (NSString *)text into: (YCodeTerminalColor *)color
{
  NSArray *parts;
  unsigned int values[3];
  int i;
  if ([text hasPrefix: @"#"] && [text length] == 7)
    parts = [NSArray
        arrayWithObjects: [text substringWithRange: NSMakeRange (1, 2)],
                         [text substringWithRange: NSMakeRange (3, 2)],
                         [text substringWithRange: NSMakeRange (5, 2)], nil];
  else if ([text hasPrefix: @"rgb:"])
    parts = [[text substringFromIndex: 4] componentsSeparatedByString: @"/"];
  else
    return NO;
  if ([parts count] != 3)
    return NO;
  for (i = 0; i < 3; i++)
    {
      NSString *part = [parts objectAtIndex: i];
      NSScanner *scanner = [NSScanner scannerWithString: part];
      if (![part length] || [part length] > 4
          || ![scanner scanHexInt: &values[i]] || ![scanner isAtEnd])
        return NO;
      values[i] = values[i] * 255 / ((1U << (4 * [part length])) - 1);
    }
  memset (color, 0, sizeof (*color));
  color->kind = YCodeTerminalColorRGB;
  color->rgb.red = values[0];
  color->rgb.green = values[1];
  color->rgb.blue = values[2];
  return YES;
}

- (void) finishString
{
  if (stringOverflow)
    return;
  NSString *text
      = AUTORELEASE ([[NSString alloc] initWithData: controlString
                                           encoding: NSUTF8StringEncoding]);
  if (!text)
    return;
  if (stringState == OSC)
    {
      NSRange delimiter = [text rangeOfString: @";"];
      if (delimiter.location == NSNotFound)
        return;
      NSString *number = [text substringToIndex: delimiter.location];
      NSScanner *scanner = [NSScanner scannerWithString: number];
      int command;
      if (![scanner scanInt: &command] || ![scanner isAtEnd])
        return;
      NSString *value = [text substringFromIndex: delimiter.location + 1];
      if (command == 0 || command == 1 || command == 2)
        [ts ts_setTitle: value type: command];
      else if (command == 4)
        {
          NSArray *parts = [value componentsSeparatedByString: @";"];
          NSUInteger i;
          for (i = 0; i + 1 < [parts count]; i += 2)
            {
              int index;
              NSScanner *indexScanner =
                  [NSScanner scannerWithString: [parts objectAtIndex: i]];
              if (![indexScanner scanInt: &index] || ![indexScanner isAtEnd]
                  || index < 0 || index > 255)
                continue;
              NSString *color = [parts objectAtIndex: i + 1];
              if ([color isEqual: @"?"])
                [self send: [NSString stringWithFormat:
                                         @"\033]4;%d;rgb:%04x/%04x/%04x\033\\",
                                         index, palette[index].rgb.red * 257,
                                         palette[index].rgb.green * 257,
                                         palette[index].rgb.blue * 257]];
              else if ([self parseColor: color into: &palette[index]])
                [self refreshColors];
            }
        }
    }
  else if (stringState == DCS && [text hasPrefix: @"$q"])
    {
      NSString *query = [text substringFromIndex: 2];
      if ([query isEqual: @"r"])
        [self send: [NSString stringWithFormat: @"\033P1$r%d;%dr\033\\", top + 1,
                                              bottom + 1]];
      else if ([query isEqual: @"m"])
        {
          NSMutableString *reply =
              [NSMutableString stringWithString: @"\033P1$r0"];
          int bit;
          static const int masks[]
              = { YCodeTerminalBold,    YCodeTerminalDim,
                  YCodeTerminalItalic,  YCodeTerminalUnderline,
                  YCodeTerminalBlink,   YCodeTerminalReverse,
                  YCodeTerminalConceal, YCodeTerminalStrike };
          static const int codes[] = { 1, 2, 3, 4, 5, 7, 8, 9 };
          for (bit = 0; bit < 8; bit++)
            if (pen.attributes & masks[bit])
              [reply appendFormat: @";%d", codes[bit]];
          YCodeTerminalColor colors[2];
          colors[0] = pen.fg;
          colors[1] = pen.bg;
          for (bit = 0; bit < 2; bit++)
            {
              YCodeTerminalColor color = colors[bit];
              if (color.kind == YCodeTerminalColorIndexed)
                [reply appendFormat: @";%d;5;%d", bit ? 48 : 38, color.index];
              else if (color.kind == YCodeTerminalColorRGB)
                [reply appendFormat: @";%d;2;%d;%d;%d", bit ? 48 : 38,
                                    color.rgb.red, color.rgb.green,
                                    color.rgb.blue];
            }
          [reply appendString: @"m\033\\"];
          [self send: reply];
        }
      else
        [self send: @"\033P0$r\033\\"];
    }
}

- (void) beginCSI
{
  int i;
  parseState = CSI;
  leader = intermediate = 0;
  invalidSequence = NO;
  parameterCount = 1;
  for (i = 0; i < 32; i++)
    {
      parameters[i] = -1;
      colonParameter[i] = NO;
    }
}

- (void) beginString: (int)state
{
  parseState = stringState = state;
  utfRemaining = 0;
  stringOverflow = NO;
  [controlString setLength: 0];
}

- (void) control: (unsigned char)byte
{
  switch (byte)
    {
    case 7:
      [ts ts_bell];
      break;
    case 8:
      if (x > 0)
        x--;
      wrapPending = NO;
      break;
    case 9:
      do
        {
          if (x < width - 1)
            x++;
          else
            break;
        }
      while (!tabs[x]);
      wrapPending = NO;
      break;
    case 10:
    case 11:
    case 12:
      [self lineFeed];
      break;
    case 13:
      x = leftRightMode ? left : 0;
      wrapPending = NO;
      break;
    case 14:
      shift = 1;
      break;
    case 15:
      shift = 0;
      break;
    }
}

- (void) consume: (unsigned char)byte
{
  if (byte == 0x18 || byte == 0x1a)
    {
      parseState = Ground;
      utfRemaining = 0;
      [controlString setLength: 0];
      return;
    }
  if (parseState == StringEscape)
    {
      if (byte == '\\')
        {
          [self finishString];
          parseState = Ground;
          [controlString setLength: 0];
          return;
        }
      /* An ESC not followed by ST starts a new escape sequence. */
      parseState = Escape;
      [controlString setLength: 0];
    }
  if (parseState == OSC || parseState == DCS || parseState == IgnoredString)
    {
      if (byte == 0x1b)
        {
          parseState = StringEscape;
          utfRemaining = 0;
          return;
        }
      if ((byte == 7 && parseState == OSC) || (byte == 0x9c && !utfRemaining))
        {
          [self finishString];
          parseState = Ground;
          utfRemaining = 0;
          [controlString setLength: 0];
          return;
        }
      /* Do not mistake a UTF-8 continuation byte for an eight-bit ST. */
      if (utfRemaining && (byte & 0xc0) == 0x80)
        utfRemaining--;
      else if (byte >= 0xc2 && byte <= 0xdf)
        utfRemaining = 1;
      else if (byte >= 0xe0 && byte <= 0xef)
        utfRemaining = 2;
      else if (byte >= 0xf0 && byte <= 0xf4)
        utfRemaining = 3;
      else
        utfRemaining = 0;
      if (parseState != IgnoredString && !stringOverflow)
        {
          if ([controlString length] < 65536)
            [controlString appendBytes: &byte length: 1];
          else
            {
              stringOverflow = YES;
              [controlString setLength: 0];
            }
        }
      return;
    }
  if (byte == 0x1b)
    {
      if (utfRemaining)
        {
          [self writeCharacter: 0xfffd];
          utfRemaining = 0;
        }
      parseState = Escape;
      return;
    }
  if (byte < 0x20)
    {
      if (utfRemaining)
        {
          [self writeCharacter: 0xfffd];
          utfRemaining = 0;
        }
      [self control: byte];
      return;
    }
  if (byte == 0x7f)
    return;
  if (parseState == Escape)
    {
      parseState = Ground;
      switch (byte)
        {
        case '[':
          [self beginCSI];
          break;
        case ']':
          [self beginString: OSC];
          break;
        case 'P':
          [self beginString: DCS];
          break;
        case 'X':
        case '^':
        case '_':
          [self beginString: IgnoredString];
          break;
        case '(':
        case ')':
        case '*':
        case '+':
          charsetSlot = byte - '(';
          parseState = DesignateCharset;
          break;
        case '#':
        case '%':
        case ' ':
          intermediate = byte;
          parseState = EscapeIntermediate;
          break;
        case '7':
          [self saveCursor];
          break;
        case '8':
          [self restoreCursor];
          break;
        case 'D':
          [self lineFeed];
          break;
        case 'E':
          [self lineFeed];
          x = leftRightMode ? left : 0;
          break;
        case 'M':
          if (y == top)
            [self scroll: -1 from: top to: bottom];
          else if (y > 0)
            y--;
          wrapPending = NO;
          break;
        case 'H':
          tabs[x] = 1;
          break;
        case 'N':
          singleShift = 2;
          break;
        case 'O':
          singleShift = 3;
          break;
        case 'n':
          shift = 2;
          break;
        case 'o':
          shift = 3;
          break;
        case '=':
          applicationKeypad = YES;
          break;
        case '>':
          applicationKeypad = NO;
          break;
        case 'c':
          [self reset: YES];
          break;
        case 'Z':
          [self send: @"\033[?1;2c"];
          break;
        }
      return;
    }
  if (parseState == DesignateCharset)
    {
      charset[charsetSlot] = byte == '0' ? 1 : (byte == 'A' ? 2 : 0);
      parseState = Ground;
      return;
    }
  if (parseState == EscapeIntermediate)
    {
      if (intermediate == '#' && byte == '8')
        {
          int row, column;
          YCodeTerminalGlyph glyph = pen;
          memset (glyph.chars, 0, sizeof (glyph.chars));
          glyph.chars[0] = 'E';
          glyph.width = 1;
          YCodeTerminalCell cell = [self displayGlyph: glyph];
          for (row = 0; row < height; row++)
            for (column = 0; column < width; column++)
              cells[row * width + column] = cell;
          memset (dirtyRows, 1, height);
        }
      parseState = Ground;
      return;
    }
  if (parseState == CSI)
    {
      if (byte >= '0' && byte <= '9')
        {
          if (intermediate)
            invalidSequence = YES;
          int *value = &parameters[parameterCount - 1];
          if (*value < 0)
            *value = 0;
          if (*value > 1000000)
            invalidSequence = YES;
          else
            *value = *value * 10 + byte - '0';
        }
      else if (byte == ';' || byte == ':')
        {
          if (parameterCount >= 32 || intermediate)
            invalidSequence = YES;
          else
            {
              colonParameter[parameterCount] = byte == ':';
              parameterCount++;
            }
        }
      else if (byte >= 0x3c && byte <= 0x3f)
        {
          if (leader || parameterCount != 1 || parameters[0] >= 0
              || intermediate)
            invalidSequence = YES;
          else
            leader = byte;
        }
      else if (byte >= 0x20 && byte <= 0x2f)
        {
          if (intermediate)
            invalidSequence = YES;
          intermediate = byte;
        }
      else if (byte >= 0x40 && byte <= 0x7e)
        {
          parseState = Ground;
          [self executeCSI: byte];
        }
      else
        {
          parseState = Ground;
        }
      return;
    }
  if (utfRemaining)
    {
      if ((byte & 0xc0) == 0x80)
        {
          utfValue = (utfValue << 6) | (byte & 63);
          if (!--utfRemaining)
            [self writeCharacter: utfValue < utfMinimum || utfValue > 0x10ffff
                                         || (utfValue >= 0xd800
                                             && utfValue <= 0xdfff)
                                     ? 0xfffd
                                     : utfValue];
          return;
        }
      utfRemaining = 0;
      [self writeCharacter: 0xfffd];
    }
  if (byte >= 0x80 && byte <= 0x9f)
    {
      switch (byte)
        {
        case 0x84:
          [self lineFeed];
          break;
        case 0x85:
          [self lineFeed];
          x = leftRightMode ? left : 0;
          break;
        case 0x88:
          tabs[x] = 1;
          break;
        case 0x8d:
          if (y == top)
            [self scroll: -1 from: top to: bottom];
          else if (y > 0)
            y--;
          wrapPending = NO;
          break;
        case 0x8e:
          singleShift = 2;
          break;
        case 0x8f:
          singleShift = 3;
          break;
        case 0x90:
          [self beginString: DCS];
          break;
        case 0x98:
        case 0x9e:
        case 0x9f:
          [self beginString: IgnoredString];
          break;
        case 0x9b:
          [self beginCSI];
          break;
        case 0x9d:
          [self beginString: OSC];
          break;
        }
      return;
    }
  if (byte < 128)
    [self writeCharacter: byte];
  else if (byte >= 0xc2 && byte <= 0xdf)
    {
      utfRemaining = 1;
      utfValue = byte & 31;
      utfMinimum = 0x80;
    }
  else if (byte >= 0xe0 && byte <= 0xef)
    {
      utfRemaining = 2;
      utfValue = byte & 15;
      utfMinimum = 0x800;
    }
  else if (byte >= 0xf0 && byte <= 0xf4)
    {
      utfRemaining = 3;
      utfValue = byte & 7;
      utfMinimum = 0x10000;
    }
  else
    [self writeCharacter: 0xfffd];
}

- (void) processByte: (unsigned char)byte
{
  [self processBytes: (const char *)&byte length: 1];
}

- (void) processBytes: (const char *)bytes length: (NSUInteger)length
{
  NSUInteger i;
  for (i = 0; i < length; i++)
    [self consume: (unsigned char)bytes[i]];
  [self flush];
}

- (void) setTerminalScreenWidth: (int)w height: (int)h
{
  int row, column, shiftRows, pulled = 0;
  YCodeTerminalCell *newPrimary, *newAlternate, *line;
  unsigned char *newTabs, *newDirty;
  w = MAX (1, w);
  h = MAX (1, h);
  if (w == width && h == height)
    {
      memset (dirtyRows, 1, height);
      [self flush];
      return;
    }
  newPrimary = calloc ((size_t)w * h, sizeof (YCodeTerminalCell));
  newAlternate = calloc ((size_t)w * h, sizeof (YCodeTerminalCell));
  line = calloc (w, sizeof (YCodeTerminalCell));
  newTabs = calloc (w, 1);
  newDirty = calloc (h, 1);
  if (!newPrimary || !newAlternate || !line || !newTabs || !newDirty)
    {
      free (newPrimary);
      free (newAlternate);
      free (line);
      free (newTabs);
      free (newDirty);
      return;
    }
  YCodeTerminalCell blank = [self blankCell];
  size_t i;
  for (i = 0; i < (size_t)w * h; i++)
    newPrimary[i] = newAlternate[i] = blank;
  shiftRows = h < height ? MIN (height - h,
                                MAX (0, (alternate ? savedY[0] : y) - h + 1))
                         : 0;
  /* History is managed by the view, whose line width is already the new width.
   */
  for (row = 0; row < shiftRows; row++)
    {
      for (column = 0; column < w; column++)
        line[column]
            = column < width ? primaryCells[row * width + column] : blank;
      if (!alternate)
        [ts ts_appendScrollback: line count: w];
    }
  for (row = 0; row < h && row + shiftRows < height; row++)
    memcpy (&newPrimary[row * w], &primaryCells[(row + shiftRows) * width],
            MIN (w, width) * sizeof (YCodeTerminalCell));
  for (row = 0; row < MIN (h, height); row++)
    memcpy (&newAlternate[row * w], &alternateCells[row * width],
            MIN (w, width) * sizeof (YCodeTerminalCell));
  if (!alternate && h > height)
    while (pulled < h - height && [ts ts_popScrollback: line count: w])
      {
        memmove (newPrimary + w, newPrimary,
                 (h - 1) * w * sizeof (YCodeTerminalCell));
        for (column = 0; column < w; column++)
          newPrimary[column] = line[column].originalCell.width
                                       || line[column].ch == MULTI_CELL_GLYPH
                                   ? line[column]
                                   : blank;
        pulled++;
      }
  for (column = 0; column < w; column++)
    newTabs[column] = column < width ? tabs[column] : column % 8 == 0;
  free (primaryCells);
  free (alternateCells);
  free (tabs);
  free (dirtyRows);
  free (line);
  primaryCells = newPrimary;
  alternateCells = newAlternate;
  cells = alternate ? alternateCells : primaryCells;
  tabs = newTabs;
  dirtyRows = newDirty;
  if (!alternate)
    y = y - shiftRows + pulled;
  savedY[0] = MAX (0, MIN (h - 1, savedY[0] - shiftRows + pulled));
  savedY[1] = MIN (h - 1, savedY[1]);
  savedX[0] = MIN (w - 1, savedX[0]);
  savedX[1] = MIN (w - 1, savedX[1]);
  width = w;
  height = h;
  top = left = 0;
  bottom = h - 1;
  right = w - 1;
  [self moveToX: x y: y];
  for (row = 0; row < h; row++)
    [self repairRow: row];
  [self flush];
}

- (void) sendString: (NSString *)text
{
  if (bracketedPaste)
    [self send: @"\033[200~"];
  [self send: [text stringByReplacingOccurrencesOfString: @"\n"
                                             withString: @"\r"]];
  if (bracketedPaste)
    [self send: @"\033[201~"];
}

- (void) handleKeyEvent: (NSEvent *)event
{
  NSString *characters = [event characters];
  NSString *plain = [event charactersIgnoringModifiers];
  NSUInteger flags = [event modifierFlags], i;
  BOOL meta = (flags & NSAlternateKeyMask) != 0;
  BOOL control = (flags & NSControlKeyMask) != 0,
       shifted = (flags & NSShiftKeyMask) != 0;
  int modifier = 1 + (shifted ? 1 : 0) + (meta ? 2 : 0) + (control ? 4 : 0);
  int tilde = 0;
  char final = 0;
  BOOL ss3 = NO;
  if ([plain length] > 1 && [plain characterAtIndex: 0] == NSHelpFunctionKey)
    plain = [plain substringFromIndex: 1];
  if ([characters length] > 1 &&
      [characters characterAtIndex: 0] == NSHelpFunctionKey)
    characters = [characters substringFromIndex: 1];
  if (![plain length])
    return;
  unichar code = [plain characterAtIndex: 0];
  if (code >= NSF13FunctionKey && code <= NSF35FunctionKey)
    return;
  if (code == NSEnterCharacter && applicationKeypad)
    {
      final = 'M';
      ss3 = YES;
    }
  if ((flags & NSNumericPadKeyMask) && applicationKeypad && !final)
    {
      NSString *keys = @"0123456789*+,-./\r=";
      NSString *encoded = @"pqrstuvwxyjklmnoMX";
      NSRange range = [keys rangeOfString: [NSString stringWithCharacters: &code
                                                                  length: 1]];
      if (range.location != NSNotFound)
        {
          final = [encoded characterAtIndex: range.location];
          ss3 = YES;
        }
    }
  if (!final)
    switch (code)
      {
      case NSUpArrowFunctionKey:
        final = 'A';
        ss3 = applicationCursor;
        break;
      case NSDownArrowFunctionKey:
        final = 'B';
        ss3 = applicationCursor;
        break;
      case NSRightArrowFunctionKey:
        final = 'C';
        ss3 = applicationCursor;
        break;
      case NSLeftArrowFunctionKey:
        final = 'D';
        ss3 = applicationCursor;
        break;
      case NSHomeFunctionKey:
        final = 'H';
        ss3 = applicationCursor;
        break;
      case NSEndFunctionKey:
        final = 'F';
        ss3 = applicationCursor;
        break;
      case NSInsertFunctionKey:
        tilde = 2;
        break;
      case NSDeleteFunctionKey:
        tilde = 3;
        break;
      case NSPageUpFunctionKey:
        tilde = 5;
        break;
      case NSPageDownFunctionKey:
        tilde = 6;
        break;
      }
  if (code >= NSF1FunctionKey && code <= NSF4FunctionKey)
    {
      final = 'P' + code - NSF1FunctionKey;
      ss3 = YES;
    }
  else if (code >= NSF5FunctionKey && code <= NSF12FunctionKey)
    {
      static const int functionCodes[] = { 15, 17, 18, 19, 20, 21, 23, 24 };
      tilde = functionCodes[code - NSF5FunctionKey];
    }
  if (final)
    {
      if (modifier == 1)
        [self send: [NSString
                       stringWithFormat: @"\033%c%c", ss3 ? 'O' : '[', final]];
      else
        [self
            send: [NSString stringWithFormat: @"\033[1;%d%c", modifier, final]];
      return;
    }
  if (tilde)
    {
      if (modifier == 1)
        [self send: [NSString stringWithFormat: @"\033[%d~", tilde]];
      else
        [self
            send: [NSString stringWithFormat: @"\033[%d;%d~", tilde, modifier]];
      return;
    }
  if (code == NSBackTabCharacter || (code == '\t' && shifted))
    {
      [self send: @"\033[Z"];
      return;
    }
  if (code == '\r' || code == '\n' || code == NSEnterCharacter)
    {
      if (meta)
        [self send: @"\033"];
      [self send: newlineMode ? @"\r\n" : @"\r"];
      return;
    }
  if (code == 0x7f || code == '\b')
    {
      if (meta)
        [self send: @"\033"];
      [self send: control ? @"\b" : @"\177"];
      return;
    }
  if (code == 0x1b)
    {
      [self send: @"\033"];
      if (meta)
        [self send: @"\033"];
      return;
    }
  if (control || meta)
    characters = plain;
  if (meta)
    [self send: @"\033"];
  for (i = 0; i < [characters length]; i++)
    {
      uint32_t value = [characters characterAtIndex: i];
      if (value >= 0xd800 && value <= 0xdbff && i + 1 < [characters length])
        {
          unichar tail = [characters characterAtIndex: i + 1];
          if (tail >= 0xdc00 && tail <= 0xdfff)
            {
              value = 0x10000 + ((value - 0xd800) << 10) + tail - 0xdc00;
              i++;
            }
        }
      if (control)
        {
          if (value == ' ' || value == '2' || value == '@')
            value = 0;
          else if (value == '?' || value == '8')
            value = 127;
          else if (value >= '3' && value <= '7')
            value = value - '3' + 27;
          else if ((value >= 'A' && value <= '_')
                   || (value >= 'a' && value <= 'z'))
            value &= 31;
        }
      [self sendCodepoint: value];
    }
}

- (void) focusChanged: (BOOL)focused
{
  if (focusReporting)
    [self send: focused ? @"\033[I" : @"\033[O"];
}

- (void) mouseAtRow: (int)row
            column: (int)column
            button: (int)button
           pressed: (BOOL)pressed
         modifiers: (NSUInteger)flags
{
  if (!mouseMode)
    return;
  BOOL motion = button == 0;
  if (motion
      && (mouseMode == 1000 || (mouseMode == 1002 && !mouseButton)
          || (row == mouseRow && column == mouseColumn)))
    return;
  mouseRow = row;
  mouseColumn = column;
  if (button >= 4 && !pressed)
    return;
  int code = motion ? (mouseButton ? mouseButton - 1 : 3) + 32
                    : (button >= 4 ? button - 4 + 64 : button - 1);
  if (!motion && button < 4)
    mouseButton = pressed ? button : 0;
  if (flags & NSShiftKeyMask)
    code |= 4;
  if (flags & NSAlternateKeyMask)
    code |= 8;
  if (flags & NSControlKeyMask)
    code |= 16;
  if (mouseSGR)
    [self send: [NSString stringWithFormat: @"\033[<%d;%d;%d%c", code,
                                          column + 1, row + 1,
                                          !motion && !pressed ? 'm' : 'M']];
  else
    {
      if (!motion && !pressed)
        code = (code & ~3) | 3;
      [self send: @"\033[M"];
      if (mouseUTF8)
        {
          [self sendCodepoint: code + 32];
          [self sendCodepoint: MIN (column + 33, 2047)];
          [self sendCodepoint: MIN (row + 33, 2047)];
        }
      else
        {
          unsigned char bytes[3]
              = { code + 32, MIN (column + 33, 255), MIN (row + 33, 255) };
          [ts ts_sendCString: (const char *)bytes length: 3];
        }
    }
}

@end
