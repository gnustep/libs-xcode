/*
   Project: Ycode

   Copyright (C) 2018 Free Software Foundation

   Author: Gregory John Casamento,,,

   Created: 2018-12-17 20:02:20 -0500 by heron

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

#ifndef _YCEDITORVIEW_H_
#define _YCEDITORVIEW_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeEditorDocument;
@class YCodeSyntaxHighlighter;
@class YCEditorLineNumberView;

@interface YCEditorView : NSView <NSTextViewDelegate>
{
    NSScrollView *_scrollView;
    NSTextView *_textView;
    YCEditorLineNumberView *_lineNumberView;
    
    YCodeEditorDocument *_document;
    YCodeSyntaxHighlighter *_syntaxHighlighter;
    
    // Editor settings
    NSFont *_font;
    NSColor *_textColor;
    NSColor *_backgroundColor;
    NSColor *_selectionColor;
    NSColor *_currentLineColor;
    
    BOOL _showLineNumbers;
    BOOL _highlightCurrentLine;
    BOOL _autoIndent;
    BOOL _syntaxHighlighting;
    
    NSInteger _tabWidth;
    BOOL _useSpacesForTabs;
    
    // Find and replace
    NSString *_findString;
    NSString *_replaceString;
    BOOL _caseSensitive;
    BOOL _useRegex;
}

/**
 * Document association
 */
- (YCodeEditorDocument *)document;
- (void)setDocument:(YCodeEditorDocument *)document;

/**
 * Text view access
 */
- (NSTextView *)textView;
- (NSScrollView *)scrollView;

/**
 * Content management
 */
- (NSString *)text;
- (void)setText:(NSString *)text;
- (BOOL)hasSelection;
- (NSString *)selectedText;
- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;

/**
 * Editor settings
 */
- (NSFont *)font;
- (void)setFont:(NSFont *)font;
- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)color;
- (BOOL)showLineNumbers;
- (void)setShowLineNumbers:(BOOL)show;
- (BOOL)highlightCurrentLine;
- (void)setHighlightCurrentLine:(BOOL)highlight;
- (NSInteger)tabWidth;
- (void)setTabWidth:(NSInteger)width;
- (BOOL)useSpacesForTabs;
- (void)setUseSpacesForTabs:(BOOL)useSpaces;

/**
 * Syntax highlighting
 */
- (BOOL)syntaxHighlighting;
- (void)setSyntaxHighlighting:(BOOL)highlighting;
- (YCodeSyntaxHighlighter *)syntaxHighlighter;
- (void)applySyntaxHighlighting;

/**
 * Text operations
 */
- (void)insertText:(NSString *)text;
- (void)insertText:(NSString *)text atLocation:(NSUInteger)location;
- (void)deleteSelectedText;
- (void)selectAll;
- (void)copy;
- (void)cut;
- (void)paste;

/**
 * Line operations
 */
- (NSUInteger)currentLineNumber;
- (NSUInteger)totalLineCount;
- (NSRange)rangeOfLine:(NSUInteger)lineNumber;
- (void)goToLine:(NSUInteger)lineNumber;
- (void)selectLine:(NSUInteger)lineNumber;

/**
 * Find and replace
 */
- (void)findText:(NSString *)searchText options:(NSStringCompareOptions)options;
- (void)replaceText:(NSString *)searchText withText:(NSString *)replaceText options:(NSStringCompareOptions)options;
- (void)findNext;
- (void)findPrevious;

/**
 * Indentation
 */
- (void)indentSelectedLines;
- (void)unindentSelectedLines;
- (void)commentSelectedLines;
- (void)uncommentSelectedLines;

/**
 * Folding (basic support)
 */
- (BOOL)canFoldAtLine:(NSUInteger)lineNumber;
- (void)foldAtLine:(NSUInteger)lineNumber;
- (void)unfoldAtLine:(NSUInteger)lineNumber;

@end

/**
 * Line number view
 */
@interface YCEditorLineNumberView : NSRulerView
{
    YCEditorView *_editorView;
    NSColor *_backgroundColor;
    NSColor *_textColor;
    NSFont *_font;
}

- (instancetype)initWithEditorView:(YCEditorView *)editorView;
- (YCEditorView *)editorView;
- (void)setEditorView:(YCEditorView *)editorView;

@end

#endif // _YCEDITORVIEW_H_

