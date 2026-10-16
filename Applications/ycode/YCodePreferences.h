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
@interface YCodePreferences : NSObject
/** Font names and point sizes are saved separately for each text pane. */
+ (NSArray *)fontPanes;
+ (NSFont *)fontForPane:(NSString *)pane;
+ (void)setFont:(NSFont *)font forPane:(NSString *)pane;
+ (void)resetFonts;
/** Saved indentation defaults, used when project formatting does not override them. */
+ (BOOL)highlightMatchingDelimiters;
+ (void)setHighlightMatchingDelimiters:(BOOL)enabled;
+ (NSUInteger)tabWidth;
+ (NSUInteger)controlIndentWidth;
+ (void)setControlIndentWidth:(NSUInteger)width;
+ (BOOL)useSpacesForTabs;
+ (BOOL)useProjectIndentation;
+ (void)setTabWidth:(NSUInteger)width useSpaces:(BOOL)spaces useProjectSettings:(BOOL)project;

/** Change the base font while retaining ANSI bold and italic traits. */
+ (void)applyFont:(NSFont *)font toText:(NSMutableAttributedString *)text;
@end
#endif
