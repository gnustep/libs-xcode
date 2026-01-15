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

#ifndef _YCODEEDITORDOCUMENT_H_
#define _YCODEEDITORDOCUMENT_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeEditorController;
@class YCodeSyntaxHighlighter;

@interface YCodeEditorDocument : NSObject
{
    NSString *_filePath;
    NSString *_content;
    BOOL _modified;
    NSDate *_lastModified;
    
    // UI Components
    NSScrollView *_scrollView;
    NSTextView *_textView;
    NSRulerView *_lineNumberRuler;
    
    // Syntax highlighting
    YCodeSyntaxHighlighter *_syntaxHighlighter;
    
    // Editor controller reference
    YCodeEditorController *_editorController;
}

/**
 * Initialization
 */
- (instancetype)initWithFilePath:(NSString *)filePath;
- (instancetype)initWithFilePath:(NSString *)filePath content:(NSString *)content;

/**
 * File properties
 */
- (NSString *)filePath;
- (void)setFilePath:(NSString *)filePath;
- (NSString *)fileName;
- (NSString *)fileExtension;

/**
 * Content management
 */
- (NSString *)content;
- (void)setContent:(NSString *)content;
- (BOOL)isModified;
- (void)setModified:(BOOL)modified;
- (NSDate *)lastModified;

/**
 * UI Components
 */
- (NSView *)editorView;
- (NSTextView *)textView;
- (NSScrollView *)scrollView;

/**
 * File operations
 */
- (BOOL)loadFromFile;
- (BOOL)saveToFile;
- (BOOL)reloadFromFile;

/**
 * Text operations
 */
- (void)insertText:(NSString *)text atLocation:(NSUInteger)location;
- (NSString *)selectedText;
- (NSRange)selectedRange;
- (void)setSelectedRange:(NSRange)range;

/**
 * Syntax highlighting
 */
- (YCodeSyntaxHighlighter *)syntaxHighlighter;
- (void)applySyntaxHighlighting;

/**
 * Editor controller
 */
- (YCodeEditorController *)editorController;
- (void)setEditorController:(YCodeEditorController *)controller;

@end

#endif // _YCODEEDITORDOCUMENT_H_