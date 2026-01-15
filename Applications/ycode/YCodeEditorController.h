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

#ifndef _YCODEEDITORCONTROLLER_H_
#define _YCODEEDITORCONTROLLER_H_

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class YCodeProject;
@class YCodeEditorDocument;

@interface YCodeEditorController : NSObject <NSTabViewDelegate>
{
    YCodeProject *_project;
    
    NSTabView *_tabView;
    NSMutableArray *_openDocuments;
    NSMutableDictionary *_documentTabs;
    
    YCodeEditorDocument *_currentDocument;
    
    // Editor settings
    NSFont *_editorFont;
    NSColor *_backgroundColor;
    NSColor *_textColor;
    BOOL _showLineNumbers;
    BOOL _syntaxHighlighting;
}

/**
 * Project association
 */
- (YCodeProject *)project;
- (void)setProject:(YCodeProject *)project;

/**
 * Tab view association
 */
- (NSTabView *)tabView;
- (void)setTabView:(NSTabView *)tabView;

/**
 * Document management
 */
- (NSArray *)openDocuments;
- (YCodeEditorDocument *)currentDocument;
- (void)setCurrentDocument:(YCodeEditorDocument *)document;

/**
 * File operations
 */
- (BOOL)openFile:(NSString *)filePath;
- (BOOL)closeFile:(NSString *)filePath;
- (BOOL)saveCurrentFile;
- (BOOL)saveAllFiles;

/**
 * Document operations
 */
- (YCodeEditorDocument *)documentForFilePath:(NSString *)filePath;
- (NSTabViewItem *)tabForDocument:(YCodeEditorDocument *)document;

/**
 * Editor settings
 */
- (NSFont *)editorFont;
- (void)setEditorFont:(NSFont *)font;
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)color;
- (NSColor *)textColor;
- (void)setTextColor:(NSColor *)color;
- (BOOL)showLineNumbers;
- (void)setShowLineNumbers:(BOOL)show;
- (BOOL)syntaxHighlighting;
- (void)setSyntaxHighlighting:(BOOL)highlighting;

/**
 * Editor actions
 */
- (IBAction)newFile:(id)sender;
- (IBAction)saveFile:(id)sender;
- (IBAction)closeCurrentFile:(id)sender;
- (IBAction)findInFile:(id)sender;
- (IBAction)replaceInFile:(id)sender;

@end

#endif // _YCODEEDITORCONTROLLER_H_