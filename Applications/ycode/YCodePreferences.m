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

#import "YCodePreferences.h"
#include <math.h>
NSString *YCodeTerminalPreferencesDidChangeNotification
    = @"YCodeTerminalPreferencesDidChange";
@implementation YCodePreferences
+ (NSDictionary *) terminalSettings
{
  return [[NSUserDefaults standardUserDefaults]
             dictionaryForKey: @"YCodeTerminalPreferences"]
             ?: [NSDictionary dictionary];
}
+ (void) saveTerminalSettings: (NSDictionary *)settings
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject: settings forKey: @"YCodeTerminalPreferences"];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeTerminalPreferencesDidChangeNotification
                    object: nil];
}
+ (void) setTerminalValue: (id)value forKey: (NSString *)key
{
  NSMutableDictionary *settings =
      [NSMutableDictionary dictionaryWithDictionary: [self terminalSettings]];
  [settings setObject: value forKey: key];
  [self saveTerminalSettings: settings];
}
+ (BOOL) isTerminalFont: (NSFont *)font
{
  if (!font)
    return NO;
  if ([font isFixedPitch]
      || ([[NSFontManager sharedFontManager] traitsOfFont: font]
          & NSFixedPitchFontMask))
    return YES;
  // Some GNUstep font backends omit the fixed-pitch flag even for the
  // system's default monospace face. Check its advances in that case.
  NSDictionary *attributes =
      [NSDictionary dictionaryWithObject: font forKey: NSFontAttributeName];
  CGFloat width = [@"M" sizeWithAttributes: attributes].width;
  return width > 0
         && fabs ([@"i" sizeWithAttributes: attributes].width - width) < 0.01
         && fabs ([@"W" sizeWithAttributes: attributes].width - width) < 0.01
         && fabs ([@" " sizeWithAttributes: attributes].width - width) < 0.01;
}
+ (NSFont *) terminalFont
{
  NSDictionary *settings = [self terminalSettings];
  id name = [settings objectForKey: @"fontName"],
     size = [settings objectForKey: @"fontSize"];
  if ([name isKindOfClass: [NSString class]] &&
      [size isKindOfClass: [NSNumber class]] && isfinite ([size doubleValue]) &&
      [size doubleValue] >= 6 && [size doubleValue] <= 72)
    {
      NSFont *font = [NSFont fontWithName: name size: [size doubleValue]];
      if ([self isTerminalFont: font])
        return font;
    }
  return [NSFont userFixedPitchFontOfSize: 13];
}
+ (void) setTerminalFont: (NSFont *)font
{
  if (![self isTerminalFont: font] || !isfinite ([font pointSize]) ||
      [font pointSize] < 6 || [font pointSize] > 72)
    return;
  NSMutableDictionary *settings =
      [NSMutableDictionary dictionaryWithDictionary: [self terminalSettings]];
  [settings setObject: [font fontName] forKey: @"fontName"];
  [settings setObject: [NSNumber numberWithDouble: [font pointSize]]
               forKey: @"fontSize"];
  [self saveTerminalSettings: settings];
}
+ (NSColor *) terminalColorForKey: (NSString *)key
                    defaultColor: (NSColor *)fallback
{
  id rgb = [[self terminalSettings] objectForKey: key];
  if ([rgb isKindOfClass: [NSArray class]] && [rgb count] == 3)
    {
      NSUInteger i;
      for (i = 0; i < 3; i++)
        {
          id component = [rgb objectAtIndex: i];
          if (![component isKindOfClass: [NSNumber class]]
              || !isfinite ([component doubleValue]) ||
              [component doubleValue] < 0 || [component doubleValue] > 1)
            break;
        }
      if (i == 3)
        return
            [NSColor colorWithCalibratedRed: [[rgb objectAtIndex: 0] doubleValue]
                                      green: [[rgb objectAtIndex: 1] doubleValue]
                                       blue: [[rgb objectAtIndex: 2] doubleValue]
                                      alpha: 1];
    }
  return fallback;
}
+ (NSColor *) terminalForegroundColor
{
  return
      [self terminalColorForKey: @"foreground"
                   defaultColor: [NSColor colorWithCalibratedWhite: 230.0 / 255.0
                                                            alpha: 1]];
}
+ (NSColor *) terminalBackgroundColor
{
  return
      [self terminalColorForKey: @"background"
                   defaultColor: [NSColor colorWithCalibratedWhite: 24.0 / 255.0
                                                            alpha: 1]];
}
+ (void) setTerminalForegroundColor: (NSColor *)foreground
                   backgroundColor: (NSColor *)background
{
  NSMutableDictionary *settings =
      [NSMutableDictionary dictionaryWithDictionary: [self terminalSettings]];
  NSArray *colors = [NSArray arrayWithObjects: foreground, background, nil];
  NSArray *keys = [NSArray arrayWithObjects: @"foreground", @"background", nil];
  if ([colors count] != 2)
    return;
  NSUInteger i;
  for (i = 0; i < 2; i++)
    {
      NSColor *color = [[colors objectAtIndex: i]
          colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
      if (!color)
        return;
      [settings
          setObject: [NSArray
                        arrayWithObjects:
                            [NSNumber numberWithDouble: [color redComponent]],
                            [NSNumber numberWithDouble: [color greenComponent]],
                            [NSNumber numberWithDouble: [color blueComponent]],
                            nil]
             forKey: [keys objectAtIndex: i]];
    }
  [self saveTerminalSettings: settings];
}
+ (NSColor *) terminalCursorColor
{
  return [self terminalColorForKey: @"cursorColor"
                      defaultColor: [NSColor redColor]];
}
+ (void) setTerminalCursorColor: (NSColor *)color
{
  color = [color colorUsingColorSpaceName: NSCalibratedRGBColorSpace];
  if (!color)
    return;
  [self setTerminalValue:
            [NSArray
                arrayWithObjects: [NSNumber
                                     numberWithDouble: [color redComponent]],
                                 [NSNumber
                                     numberWithDouble: [color greenComponent]],
                                 [NSNumber
                                     numberWithDouble: [color blueComponent]],
                                 nil]
                  forKey: @"cursorColor"];
}
+ (NSInteger) terminalCursorShape
{
  id value = [[self terminalSettings] objectForKey: @"cursorShape"];
  return [value isKindOfClass: [NSNumber class]] && [value integerValue] >= 0 &&
                 [value integerValue] <= 4
             ? [value integerValue]
             : 0;
}
+ (void) setTerminalCursorShape: (NSInteger)shape
{
  if (shape >= 0 && shape <= 4)
    [self setTerminalValue: [NSNumber numberWithInteger: shape]
                    forKey: @"cursorShape"];
}
+ (NSUInteger) terminalScrollbackLines
{
  id lines = [[self terminalSettings] objectForKey: @"scrollbackLines"];
  return [lines isKindOfClass: [NSNumber class]] && [lines integerValue] >= 0 &&
                 [lines integerValue] <= 50000
             ? [lines unsignedIntegerValue]
             : 5000;
}
+ (void) setTerminalScrollbackLines: (NSUInteger)lines
{
  [self
      setTerminalValue: [NSNumber numberWithUnsignedInteger: MIN (50000, lines)]
                forKey: @"scrollbackLines"];
}
+ (BOOL) terminalBooleanForKey: (NSString *)key
{
  id value = [[self terminalSettings] objectForKey: key];
  return [value isKindOfClass: [NSNumber class]] ? [value boolValue] : YES;
}
+ (BOOL) terminalAudibleBell
{
  return [self terminalBooleanForKey: @"audibleBell"];
}
+ (BOOL) terminalCursorBlink
{
  return [self terminalBooleanForKey: @"cursorBlink"];
}
+ (void) setTerminalAudibleBell: (BOOL)enabled
{
  [self setTerminalValue: [NSNumber numberWithBool: enabled]
                  forKey: @"audibleBell"];
}
+ (void) setTerminalCursorBlink: (BOOL)enabled
{
  [self setTerminalValue: [NSNumber numberWithBool: enabled]
                  forKey: @"cursorBlink"];
}
+ (void) resetTerminalPreferences
{
  [[NSUserDefaults standardUserDefaults]
      removeObjectForKey: @"YCodeTerminalPreferences"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: YCodeTerminalPreferencesDidChangeNotification
                    object: nil];
}
+ (BOOL) highlightMatchingDelimiters
{
  return ![[NSUserDefaults standardUserDefaults]
      boolForKey: @"YCodeDisableMatchingDelimiters"];
}
+ (void) setHighlightMatchingDelimiters: (BOOL)enabled
{
  [[NSUserDefaults standardUserDefaults]
      setBool: !enabled
       forKey: @"YCodeDisableMatchingDelimiters"];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeMatchingDelimitersDidChange"
                    object: nil];
}

+ (NSUInteger) controlIndentWidth
{
  NSInteger width = [[NSUserDefaults standardUserDefaults]
      integerForKey: @"YCodeControlIndentWidth"];
  return width >= 1 && width <= 16 ? width : 2;
}

+ (void) setControlIndentWidth: (NSUInteger)width
{
  [[NSUserDefaults standardUserDefaults]
      setInteger: MAX (1, MIN (16, width))
          forKey: @"YCodeControlIndentWidth"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeTabsDidChange"
                    object: nil];
}

+ (NSUInteger) tabWidth
{
  NSInteger width =
      [[NSUserDefaults standardUserDefaults] integerForKey: @"YCodeTabWidth"];
  return width >= 1 && width <= 16 ? width : 2;
}

+ (BOOL) useSpacesForTabs
{
  return ![[NSUserDefaults standardUserDefaults]
      boolForKey: @"YCodeUseTabCharacters"];
}

+ (BOOL) useProjectIndentation
{
  return ![[NSUserDefaults standardUserDefaults]
      boolForKey: @"YCodeIgnoreProjectIndentation"];
}

+ (void) setTabWidth: (NSUInteger)width
             useSpaces: (BOOL)spaces
    useProjectSettings: (BOOL)project
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setInteger: MAX (1, MIN (16, width)) forKey: @"YCodeTabWidth"];
  [defaults setBool: !spaces forKey: @"YCodeUseTabCharacters"];
  [defaults setBool: !project forKey: @"YCodeIgnoreProjectIndentation"];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeTabsDidChange"
                    object: nil];
}

+ (NSArray *) fontPanes
{
  return [NSArray
      arrayWithObjects: @"Editor", @"Console", @"Issues", @"Debugger", nil];
}
+ (NSFont *) fontForPane: (NSString *)pane
{
  id entry = [[[NSUserDefaults standardUserDefaults]
      dictionaryForKey: @"YCodeFonts"] objectForKey: pane];
  if ([entry isKindOfClass: [NSDictionary class]])
    {
      id name = [entry objectForKey: @"name"],
         size = [entry objectForKey: @"size"];
      if ([name isKindOfClass: [NSString class]] &&
          [size isKindOfClass: [NSNumber class]]
          && isfinite ([size doubleValue]) && [size doubleValue] >= 6 &&
          [size doubleValue] <= 144)
        {
          NSFont *font = [NSFont fontWithName: name size: [size doubleValue]];
          if (font)
            return font;
        }
    }
  return [NSFont userFixedPitchFontOfSize: 12];
}
+ (void) setFont: (NSFont *)font forPane: (NSString *)pane
{
  if (!font || ![[self fontPanes] containsObject: pane])
    return;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSMutableDictionary *fonts = [NSMutableDictionary
      dictionaryWithDictionary: [defaults dictionaryForKey: @"YCodeFonts"]
                                   ?: [NSDictionary dictionary]];
  [fonts
      setObject: [NSDictionary dictionaryWithObjectsAndKeys:
                                  [font fontName], @"name",
                                  [NSNumber numberWithDouble: [font pointSize]],
                                  @"size", nil]
         forKey: pane];
  [defaults setObject: fonts forKey: @"YCodeFonts"];
  [defaults synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeFontsDidChange"
                    object: nil];
}
+ (void) resetFonts
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"YCodeFonts"];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: @"YCodeFontsDidChange"
                    object: nil];
}
+ (void) applyFont: (NSFont *)font toText: (NSMutableAttributedString *)text
{
  NSUInteger index = 0;
  NSFontManager *manager = [NSFontManager sharedFontManager];
  [text beginEditing];
  while (index < [text length])
    {
      NSRange range;
      NSFont *old = [text attribute: NSFontAttributeName
                            atIndex: index
                     effectiveRange: &range];
      NSFontTraitMask traits = old ? [manager traitsOfFont: old]
                                         & (NSBoldFontMask | NSItalicFontMask)
                                   : 0;
      NSFont *replacement
          = traits ? [manager convertFont: font toHaveTrait: traits] : font;
      [text addAttribute: NSFontAttributeName
                   value: replacement ?: font
                   range: range];
      index = NSMaxRange (range);
    }
  [text endEditing];
}
@end
