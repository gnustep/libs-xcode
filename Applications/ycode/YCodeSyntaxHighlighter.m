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

#import "YCodeSyntaxHighlighter.h"
#import "YCodeLanguage.h"
#include <math.h>

@implementation YCodeSyntaxHighlighter

// Store RGB components as property-list values, without archiving AppKit objects.
+ (NSArray *)colorPreferenceKeys
{
    return [NSArray arrayWithObjects:@"background", @"text", @"keyword", @"string",
        @"comment", @"number", @"preprocessor", @"type", @"symbol", @"constant", @"cursor", nil];
}

+ (NSColor *)savedColorForKey:(NSString *)key
{
    id components = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YCodeEditorColors"] objectForKey:key];
    if (![components isKindOfClass:[NSArray class]] || [components count] != 3) return nil;
    NSUInteger i;
    for (i = 0; i < 3; i++) {
        id value = [components objectAtIndex:i];
        if (![value isKindOfClass:[NSNumber class]] || !isfinite([value doubleValue]) ||
            [value doubleValue] < 0 || [value doubleValue] > 1) return nil;
    }
    return [NSColor colorWithDeviceRed:[[components objectAtIndex:0] doubleValue]
        green:[[components objectAtIndex:1] doubleValue]
        blue:[[components objectAtIndex:2] doubleValue] alpha:1];
}

+ (NSColor *)preferredColorForKey:(NSString *)key
{
    NSColor *saved = [self savedColorForKey:key];
    if (saved) return saved;
    if ([key isEqual:@"cursor"]) return [NSColor redColor];
    if ([key isEqual:@"background"]) return [NSColor blackColor];
    if ([key isEqual:@"text"]) return [self plainTextColorForBackground:[self preferredColorForKey:@"background"]];
    static const CGFloat defaults[8][3] = {
        {0.67, 0.20, 0.89}, {0.77, 0.10, 0.08}, {0.42, 0.48, 0.53},
        {0.11, 0.28, 0.80}, {0.64, 0.45, 0.14}, {0.15, 0.54, 0.61},
        {0.12, 0.40, 0.64}, {0.60, 0.32, 0.12}
    };
    NSUInteger index = [[self colorPreferenceKeys] indexOfObject:key];
    if (index == NSNotFound || index < 2) return nil;
    return [NSColor colorWithDeviceRed:defaults[index - 2][0]
        green:defaults[index - 2][1] blue:defaults[index - 2][2] alpha:1];
}

+ (void)setPreferredColor:(NSColor *)color forKey:(NSString *)key
{
    if (![[self colorPreferenceKeys] containsObject:key]) return;
    NSColor *rgb = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgb) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *colors = [NSMutableDictionary dictionaryWithDictionary:
        [defaults dictionaryForKey:@"YCodeEditorColors"] ?: [NSDictionary dictionary]];
    [colors setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:[rgb redComponent]],
        [NSNumber numberWithDouble:[rgb greenComponent]], [NSNumber numberWithDouble:[rgb blueComponent]], nil] forKey:key];
    [defaults setObject:colors forKey:@"YCodeEditorColors"];
    [defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeEditorColorsDidChange" object:nil];
}

+ (void)resetColorPreferences
{
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"YCodeEditorColors"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YCodeEditorColorsDidChange" object:nil];
}

- (void)loadPreferredColors
{
    ASSIGN(_keywordColor, [[self class] preferredColorForKey:@"keyword"]);
    ASSIGN(_stringColor, [[self class] preferredColorForKey:@"string"]);
    ASSIGN(_commentColor, [[self class] preferredColorForKey:@"comment"]);
    ASSIGN(_numberColor, [[self class] preferredColorForKey:@"number"]);
    ASSIGN(_preprocessorColor, [[self class] preferredColorForKey:@"preprocessor"]);
    ASSIGN(_typeColor, [[self class] preferredColorForKey:@"type"]);
    ASSIGN(_symbolColor, [[self class] preferredColorForKey:@"symbol"]);
    ASSIGN(_constantColor, [[self class] preferredColorForKey:@"constant"]);
}

- (id)initWithFileExtension:(NSString *)extension
{
    self = [super init];
    if (self) {
        [self loadPreferredColors];
        [self setFileExtension:extension];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_fileExtension);
    RELEASE(_textView);
    RELEASE(_keywordColor);
    RELEASE(_stringColor);
    RELEASE(_commentColor);
    RELEASE(_numberColor);
    RELEASE(_preprocessorColor);
    RELEASE(_typeColor);
    RELEASE(_symbolColor);
    RELEASE(_constantColor);
    RELEASE(_keywordPattern);
    RELEASE(_typePattern);
    RELEASE(_symbolPattern);
    RELEASE(_constantPattern);
    RELEASE(_literalPattern);
    RELEASE(_numberPattern);
    RELEASE(_annotationPattern);
    RELEASE(_preprocessorPattern);
    [super dealloc];
}

#pragma mark - File Extension and Language

- (NSString *)fileExtension
{
    return _fileExtension;
}

- (void)setFileExtension:(NSString *)extension
{
    ASSIGN(_fileExtension, extension);
    [self setupLanguagePatterns];
}

- (NSString *)language
{
    NSString *identifier = [[[YCodeLanguageRegistry sharedRegistry] languageForFile:_fileExtension] identifier];
    return identifier ? identifier : @"plain";
}

#pragma mark - Text View Association

- (NSTextView *)textView
{
    return _textView;
}

- (void)setTextView:(NSTextView *)textView
{
    ASSIGN(_textView, textView);
    [_textView setBackgroundColor:[[self class] preferredColorForKey:@"background"]];
    [_textView setInsertionPointColor:[[self class] preferredColorForKey:@"cursor"]];
}

#pragma mark - Color Scheme

- (NSColor *)keywordColor
{
    return _keywordColor;
}

- (void)setKeywordColor:(NSColor *)color
{
    ASSIGN(_keywordColor, color);
}

- (NSColor *)stringColor
{
    return _stringColor;
}

- (void)setStringColor:(NSColor *)color
{
    ASSIGN(_stringColor, color);
}

- (NSColor *)commentColor
{
    return _commentColor;
}

- (void)setCommentColor:(NSColor *)color
{
    ASSIGN(_commentColor, color);
}

- (NSColor *)numberColor
{
    return _numberColor;
}

- (void)setNumberColor:(NSColor *)color
{
    ASSIGN(_numberColor, color);
}

- (NSColor *)preprocessorColor
{
    return _preprocessorColor;
}

- (void)setPreprocessorColor:(NSColor *)color
{
    ASSIGN(_preprocessorColor, color);
}

- (NSColor *)typeColor
{
    return _typeColor;
}

- (void)setTypeColor:(NSColor *)color
{
    ASSIGN(_typeColor, color);
}

- (NSColor *)symbolColor { return _symbolColor; }
- (NSColor *)constantColor { return _constantColor; }

#pragma mark - Highlighting Operations

+ (NSColor *)plainTextColorForBackground:(NSColor *)background
{
    NSColor *saved = [self savedColorForKey:@"text"];
    if (saved) return saved;
    NSColor *rgb = [background colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    if (!rgb) {
        rgb = [[NSColor textBackgroundColor] colorUsingColorSpaceName:NSDeviceRGBColorSpace];
    }
    return [NSColor colorWithDeviceRed:1.0 - [rgb redComponent]
                                green:1.0 - [rgb greenComponent]
                                 blue:1.0 - [rgb blueComponent]
                                alpha:1.0];
}

- (void)applyPlainTextColorInRange:(NSRange)range
{
    NSColor *color = [[self class] plainTextColorForBackground:[_textView backgroundColor]];
    [[_textView textStorage] addAttribute:NSForegroundColorAttributeName value:color range:range];
    NSMutableDictionary *attributes = [[_textView typingAttributes] mutableCopy];
    [attributes setObject:color forKey:NSForegroundColorAttributeName];
    [_textView setTypingAttributes:attributes];
    RELEASE(attributes);
    [_textView setInsertionPointColor:[[self class] preferredColorForKey:@"cursor"]];
}

- (void)highlightText
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    
    [self highlightRange:fullRange];
}

- (void)applyPattern:(NSRegularExpression *)pattern color:(NSColor *)color
                text:(NSString *)text range:(NSRange)range
{
    // Match with full lexical context, but only change the requested characters.
    {
      NSEnumerator *matchEnumerator = [[pattern matchesInString:text options:0
        range:NSMakeRange(0, [text length])] objectEnumerator];
      NSTextCheckingResult *match;
      while ((match = [matchEnumerator nextObject]) != nil)
        {
          NSRange painted = NSIntersectionRange([match range], range);
          if (painted.length)
              [[_textView textStorage] addAttribute:NSForegroundColorAttributeName value:color range:painted];
        }
    }
}

- (void)highlightRange:(NSRange)range
{
    if (!_textView) return;
    NSString *text = [_textView string];
    if (range.location > [text length] || range.length > [text length] - range.location) return;

    NSTextStorage *storage = [_textView textStorage];
    [storage beginEditing];
    @try {
        [self applyPlainTextColorInRange:range];
        [self applyPattern:_preprocessorPattern color:_preprocessorColor text:text range:range];
        [self applyPattern:_symbolPattern color:_symbolColor text:text range:range];
        [self applyPattern:_constantPattern color:_constantColor text:text range:range];
        [self applyPattern:_typePattern color:_typeColor text:text range:range];
        [self applyPattern:_numberPattern color:_numberColor text:text range:range];
        [self applyPattern:_keywordPattern color:_keywordColor text:text range:range];
        [self applyPattern:_annotationPattern color:_preprocessorColor text:text range:range];
        // One left-to-right lexical pass prevents comment markers in strings,
        // or strings inside comments, from winning over their enclosing token.
        {
          NSEnumerator *matchEnumerator = [[_literalPattern matchesInString:text options:0
            range:NSMakeRange(0, [text length])] objectEnumerator];
          NSTextCheckingResult *match;
          while ((match = [matchEnumerator nextObject]) != nil)
            {
              NSRange token = [match range];
              NSRange painted = NSIntersectionRange(token, range);
              if (!painted.length) continue;
              BOOL comment = [match rangeAtIndex:1].location != NSNotFound;
              NSColor *color = comment ? _commentColor : _stringColor;
              if (!comment && _highlightStringKeys) {
                  NSUInteger next = NSMaxRange(token);
                  while (next < [text length] && [[NSCharacterSet whitespaceAndNewlineCharacterSet]
                      characterIsMember:[text characterAtIndex:next]]) next++;
                  if (next < [text length] && ([text characterAtIndex:next] == ':' || [text characterAtIndex:next] == '='))
                      color = _symbolColor;
              }
              [storage addAttribute:NSForegroundColorAttributeName value:color range:painted];
            }
        }
    }
    @finally { [storage endEditing]; }
}

- (void)removeHighlighting
{
    if (!_textView) {
        return;
    }
    
    NSString *text = [_textView string];
    NSRange fullRange = NSMakeRange(0, [text length]);
    [self applyPlainTextColorInRange:fullRange];
}

#pragma mark - Language-Specific Setup

- (void)setupLanguagePatterns
{
    YCodeLanguage *provider = [[YCodeLanguageRegistry sharedRegistry] languageForFile:_fileExtension];
    _highlightStringKeys = [provider highlightStringKeys];
    ASSIGN(_annotationPattern, [provider patternForToken:@"annotation"]);
    ASSIGN(_numberPattern, [provider patternForToken:@"number"]);
    ASSIGN(_preprocessorPattern, [provider patternForToken:@"preprocessor"]);
    ASSIGN(_keywordPattern, [provider patternForToken:@"keyword"]);
    ASSIGN(_typePattern, [provider patternForToken:@"type"]);
    ASSIGN(_symbolPattern, [provider patternForToken:@"symbol"]);
    ASSIGN(_constantPattern, [provider patternForToken:@"constant"]);
    ASSIGN(_literalPattern, [provider patternForToken:@"literal"]);
}

@end
