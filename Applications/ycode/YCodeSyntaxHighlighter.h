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

#ifndef _YCODESYNTAXHIGHLIGHTER_H_
#define _YCODESYNTAXHIGHLIGHTER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface YCodeSyntaxHighlighter : NSObject
{
    NSString *_fileExtension;
    NSTextView *_textView;
    
    // Color schemes
    NSColor *_keywordColor;
    NSColor *_stringColor;
    NSColor *_commentColor;
    NSColor *_numberColor;
    NSColor *_preprocessorColor;
    NSColor *_typeColor;
    
    // Language patterns
    NSArray *_keywords;
    NSArray *_types;
    NSRegularExpression *_stringPattern;
    NSRegularExpression *_commentPattern;
    NSRegularExpression *_numberPattern;
    NSRegularExpression *_preprocessorPattern;
}

/**
 * Initialization
 */
- (instancetype)initWithFileExtension:(NSString *)extension;

/**
 * File extension and language
 */
- (NSString *)fileExtension;
- (void)setFileExtension:(NSString *)extension;
- (NSString *)language;

/**
 * Text view association
 */
- (NSTextView *)textView;
- (void)setTextView:(NSTextView *)textView;

/**
 * Color scheme
 */
- (NSColor *)keywordColor;
- (void)setKeywordColor:(NSColor *)color;
- (NSColor *)stringColor;
- (void)setStringColor:(NSColor *)color;
- (NSColor *)commentColor;
- (void)setCommentColor:(NSColor *)color;
- (NSColor *)numberColor;
- (void)setNumberColor:(NSColor *)color;
- (NSColor *)preprocessorColor;
- (void)setPreprocessorColor:(NSColor *)color;
- (NSColor *)typeColor;
- (void)setTypeColor:(NSColor *)color;

/**
 * Highlighting operations
 */
- (void)highlightText;
- (void)highlightRange:(NSRange)range;
- (void)removeHighlighting;

/**
 * Language-specific setup
 */
- (void)setupForLanguage:(NSString *)language;
- (void)setupObjectiveC;
- (void)setupC;
- (void)setupCPlusPlus;
- (void)setupJavaScript;
- (void)setupPython;
- (void)setupSwift;

@end

#endif // _YCODESYNTAXHIGHLIGHTER_H_