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
@implementation YCodePreferences
+ (NSUInteger)tabWidth
{
    NSInteger width = [[NSUserDefaults standardUserDefaults] integerForKey:@"YCodeTabWidth"];
    return width >= 1 && width <= 16 ? width : 2;
}

+ (BOOL)useSpacesForTabs
{
    return ![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeUseTabCharacters"];
}

+ (BOOL)useProjectIndentation
{
    return ![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeIgnoreProjectIndentation"];
}

+ (void)setTabWidth:(NSUInteger)width useSpaces:(BOOL)spaces useProjectSettings:(BOOL)project
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:MAX(1, MIN(16, width)) forKey:@"YCodeTabWidth"];
    [defaults setBool:!spaces forKey:@"YCodeUseTabCharacters"];
    [defaults setBool:!project forKey:@"YCodeIgnoreProjectIndentation"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeTabsDidChange" object:nil];
}

+ (NSArray *)fontPanes
{
    return [NSArray arrayWithObjects:@"Editor", @"Console", @"Issues", @"Debugger", nil];
}
+ (NSFont *)fontForPane:(NSString *)pane
{
    id entry = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YCodeFonts"] objectForKey:pane];
    if ([entry isKindOfClass:[NSDictionary class]]) {
        id name = [entry objectForKey:@"name"], size = [entry objectForKey:@"size"];
        if ([name isKindOfClass:[NSString class]] && [size isKindOfClass:[NSNumber class]] &&
            isfinite([size doubleValue]) && [size doubleValue] >= 6 && [size doubleValue] <= 144) {
            NSFont *font = [NSFont fontWithName:name size:[size doubleValue]];
            if (font) return font;
        }
    }
    return [NSFont userFixedPitchFontOfSize:12];
}
+ (void)setFont:(NSFont *)font forPane:(NSString *)pane
{
    if (!font || ![[self fontPanes] containsObject:pane]) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *fonts = [NSMutableDictionary dictionaryWithDictionary:
        [defaults dictionaryForKey:@"YCodeFonts"] ?: [NSDictionary dictionary]];
    [fonts setObject:[NSDictionary dictionaryWithObjectsAndKeys:[font fontName], @"name",
        [NSNumber numberWithDouble:[font pointSize]], @"size", nil] forKey:pane];
    [defaults setObject:fonts forKey:@"YCodeFonts"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeFontsDidChange" object:nil];
}
+ (void)resetFonts
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"YCodeFonts"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeFontsDidChange" object:nil];
}
+ (void)applyFont:(NSFont *)font toText:(NSMutableAttributedString *)text
{
    NSUInteger index = 0;
    NSFontManager *manager = [NSFontManager sharedFontManager];
    [text beginEditing];
    while (index < [text length]) {
        NSRange range;
        NSFont *old = [text attribute:NSFontAttributeName atIndex:index effectiveRange:&range];
        NSFontTraitMask traits = old ? [manager traitsOfFont:old] & (NSBoldFontMask | NSItalicFontMask) : 0;
        NSFont *replacement = traits ? [manager convertFont:font toHaveTrait:traits] : font;
        [text addAttribute:NSFontAttributeName value:replacement ?: font range:range];
        index = NSMaxRange(range);
    }
    [text endEditing];
}
@end
