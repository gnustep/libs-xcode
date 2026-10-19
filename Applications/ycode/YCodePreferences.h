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

#ifndef _YCODEPREFERENCES_H_
#define _YCODEPREFERENCES_H_
#import <AppKit/AppKit.h>
extern NSString *YCodeTerminalPreferencesDidChangeNotification;
extern NSString *YCodeConnectionPreferencesDidChangeNotification;
@interface YCodePreferences : NSObject
/** Appearance of the model viewer's rectilinear connection overlay. */
+ (NSColor *) connectionLineColor;
+ (NSUInteger) connectionLineWidth;
+ (void) setConnectionLineColor: (NSColor *)color;
+ (void) setConnectionLineWidth: (NSUInteger)width;
/** Font names and point sizes are saved separately for each text pane. */
+ (NSArray *) fontPanes;
+ (NSFont *) fontForPane: (NSString *)pane;
+ (void) setFont: (NSFont *)font forPane: (NSString *)pane;
+ (void) resetFonts;
/** Terminal preferences apply to all project terminals, independently of editor fonts. */
+ (NSFont *) terminalFont;

+ (void) setTerminalFont: (NSFont *)font;
+ (NSColor *) terminalForegroundColor;
+ (NSColor *) terminalBackgroundColor;
+ (void) setTerminalForegroundColor: (NSColor *)foreground
                   backgroundColor: (NSColor *)background;
+ (NSColor *) terminalCursorColor;
+ (void) setTerminalCursorColor: (NSColor *)color;
/** Cursor shape: 0 program controlled, 1 block, 2 outline, 3 line, 4 underline. */
+ (NSInteger) terminalCursorShape;
+ (void) setTerminalCursorShape: (NSInteger)shape;
+ (NSUInteger) terminalScrollbackLines;
+ (void) setTerminalScrollbackLines: (NSUInteger)lines;
+ (BOOL) terminalAudibleBell;
+ (void) setTerminalAudibleBell: (BOOL)enabled;
+ (BOOL) terminalCursorBlink;
+ (void) setTerminalCursorBlink: (BOOL)enabled;
+ (void) resetTerminalPreferences;
/** Saved indentation defaults, used when project formatting does not override them. */
+ (BOOL) highlightMatchingDelimiters;
+ (void) setHighlightMatchingDelimiters: (BOOL)enabled;
+ (NSUInteger) tabWidth;
+ (NSUInteger) controlIndentWidth;
+ (void) setControlIndentWidth: (NSUInteger)width;
+ (BOOL) useSpacesForTabs;
+ (BOOL) useProjectIndentation;
+ (void) setTabWidth: (NSUInteger)width
             useSpaces: (BOOL)spaces
    useProjectSettings: (BOOL)project;

/** Change the base font while retaining ANSI bold and italic traits. */
+ (void) applyFont: (NSFont *)font toText: (NSMutableAttributedString *)text;
@end
#endif
