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

#import "YCodeEditorController.h"
#import "YCodeEditorDocument.h"
#import "YCodeProject.h"

@implementation YCodeEditorController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _openDocuments = [[NSMutableArray alloc] init];
        _documentTabs = [[NSMutableDictionary alloc] init];
        
        // Default editor settings
        _editorFont = [[NSFont fontWithName:@"Menlo" size:12.0] retain];
        _backgroundColor = [[NSColor colorWithDeviceWhite:0.95 alpha:1.0] retain];
        _textColor = [[NSColor blackColor] retain];
        _showLineNumbers = YES;
        _syntaxHighlighting = YES;
    }
    return self;
}

- (void)dealloc
{
    RELEASE(_project);
    RELEASE(_tabView);
    RELEASE(_openDocuments);
    RELEASE(_documentTabs);
    RELEASE(_currentDocument);
    RELEASE(_editorFont);
    RELEASE(_backgroundColor);
    RELEASE(_textColor);
    [super dealloc];
}

#pragma mark - Project Association

- (YCodeProject *)project
{
    return _project;
}

- (void)setProject:(YCodeProject *)project
{
    ASSIGN(_project, project);
}

#pragma mark - Tab View Association

- (NSTabView *)tabView
{
    return _tabView;
}

- (void)setTabView:(NSTabView *)tabView
{
    ASSIGN(_tabView, tabView);
    [_tabView setDelegate:self];
    [_tabView setTabViewType:NSTopTabsBezelBorder];
}

#pragma mark - Document Management

- (NSArray *)openDocuments
{
    return _openDocuments;
}

- (YCodeEditorDocument *)currentDocument
{
    return _currentDocument;
}

- (void)setCurrentDocument:(YCodeEditorDocument *)document
{
    if (_currentDocument != document) {
        ASSIGN(_currentDocument, document);
        
        // Update tab view selection
        if (document && _tabView) {
            NSTabViewItem *tab = [self tabForDocument:document];
            if (tab) {
                [_tabView selectTabViewItem:tab];
            }
        }
    }
}

#pragma mark - File Operations

- (BOOL)openFile:(NSString *)filePath
{
    if (!filePath || [filePath length] == 0) {
        return NO;
    }
    
    // Check if file is already open
    YCodeEditorDocument *existingDoc = [self documentForFilePath:filePath];
    if (existingDoc) {
        [self setCurrentDocument:existingDoc];
        return YES;
    }
    
    // Create new document
    YCodeEditorDocument *document = [[YCodeEditorDocument alloc] initWithFilePath:filePath];
    [document setEditorController:self];
    
    // Apply editor settings
    NSTextView *textView = [document textView];
    if (textView) {
        [textView setFont:_editorFont];
        [textView setBackgroundColor:_backgroundColor];
        [textView setTextColor:_textColor];
    }
    
    // Load file content
    if ([document loadFromFile]) {
        [_openDocuments addObject:document];
        
        // Create tab
        NSTabViewItem *tabItem = [[NSTabViewItem alloc] initWithIdentifier:filePath];
        [tabItem setLabel:[filePath lastPathComponent]];
        [tabItem setView:[document editorView]];
        [tabItem setToolTip:filePath];
        
        if (_tabView) {
            [_tabView addTabViewItem:tabItem];
        }
        
        [_documentTabs setObject:tabItem forKey:filePath];
        [self setCurrentDocument:document];
        
        RELEASE(tabItem);
        RELEASE(document);
        return YES;
    } else {
        RELEASE(document);
        return NO;
    }
}

- (BOOL)closeFile:(NSString *)filePath
{
    YCodeEditorDocument *document = [self documentForFilePath:filePath];
    if (!document) {
        return NO;
    }
    
    // Check for unsaved changes
    if ([document isModified]) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:[NSString stringWithFormat:@"Do you want to save the changes to \"%@\"?", [document fileName]]];
        [alert setInformativeText:@"Your changes will be lost if you don't save them."];
        [alert addButtonWithTitle:@"Save"];
        [alert addButtonWithTitle:@"Don't Save"];
        [alert addButtonWithTitle:@"Cancel"];
        
        NSInteger result = [alert runModal];
        RELEASE(alert);
        
        if (result == NSAlertThirdButtonReturn) {
            return NO; // Cancel
        } else if (result == NSAlertFirstButtonReturn) {
            if (![document saveToFile]) {
                return NO; // Save failed
            }
        }
    }
    
    // Remove tab
    NSTabViewItem *tabItem = [_documentTabs objectForKey:filePath];
    if (tabItem && _tabView) {
        [_tabView removeTabViewItem:tabItem];
    }
    [_documentTabs removeObjectForKey:filePath];
    
    // Remove document
    [_openDocuments removeObject:document];
    
    // Update current document
    if (_currentDocument == document) {
        if ([_openDocuments count] > 0) {
            [self setCurrentDocument:[_openDocuments lastObject]];
        } else {
            [self setCurrentDocument:nil];
        }
    }
    
    return YES;
}

- (BOOL)saveCurrentFile
{
    if (_currentDocument) {
        return [_currentDocument saveToFile];
    }
    return NO;
}

- (BOOL)saveAllFiles
{
    BOOL allSaved = YES;
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        if ([document isModified]) {
            if (![document saveToFile]) {
                allSaved = NO;
            }
        }
    }
    
    return allSaved;
}

#pragma mark - Document Operations

- (YCodeEditorDocument *)documentForFilePath:(NSString *)filePath
{
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        if ([[document filePath] isEqualToString:filePath]) {
            return document;
        }
    }
    
    return nil;
}

- (NSTabViewItem *)tabForDocument:(YCodeEditorDocument *)document
{
    if (document) {
        return [_documentTabs objectForKey:[document filePath]];
    }
    return nil;
}

#pragma mark - Editor Settings

- (NSFont *)editorFont
{
    return _editorFont;
}

- (void)setEditorFont:(NSFont *)font
{
    ASSIGN(_editorFont, font);
    
    // Apply to all open documents
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        [[document textView] setFont:font];
    }
}

- (NSColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)color
{
    ASSIGN(_backgroundColor, color);
    
    // Apply to all open documents
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        [[document textView] setBackgroundColor:color];
    }
}

- (NSColor *)textColor
{
    return _textColor;
}

- (void)setTextColor:(NSColor *)color
{
    ASSIGN(_textColor, color);
    
    // Apply to all open documents
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        [[document textView] setTextColor:color];
    }
}

- (BOOL)showLineNumbers
{
    return _showLineNumbers;
}

- (void)setShowLineNumbers:(BOOL)show
{
    _showLineNumbers = show;
    // TODO: Update line number display in all documents
}

- (BOOL)syntaxHighlighting
{
    return _syntaxHighlighting;
}

- (void)setSyntaxHighlighting:(BOOL)highlighting
{
    _syntaxHighlighting = highlighting;
    
    // Apply to all open documents
    if (highlighting) {
        NSEnumerator *enumerator = [_openDocuments objectEnumerator];
        YCodeEditorDocument *document;
        
        while ((document = [enumerator nextObject]) != nil) {
            [document applySyntaxHighlighting];
        }
    }
}

#pragma mark - Editor Actions

- (IBAction)newFile:(id)sender
{
    // Create new untitled document
    static NSInteger untitledCounter = 1;
    NSString *fileName = [NSString stringWithFormat:@"Untitled-%ld", (long)untitledCounter++];
    
    YCodeEditorDocument *document = [[YCodeEditorDocument alloc] initWithFilePath:fileName content:@""];
    [document setEditorController:self];
    [_openDocuments addObject:document];
    
    // Create tab
    NSTabViewItem *tabItem = [[NSTabViewItem alloc] initWithIdentifier:fileName];
    [tabItem setLabel:fileName];
    [tabItem setView:[document editorView]];
    
    if (_tabView) {
        [_tabView addTabViewItem:tabItem];
    }
    
    [_documentTabs setObject:tabItem forKey:fileName];
    [self setCurrentDocument:document];
    
    RELEASE(tabItem);
    RELEASE(document);
}

- (IBAction)saveFile:(id)sender
{
    [self saveCurrentFile];
}

- (IBAction)closeCurrentFile:(id)sender
{
    if (_currentDocument) {
        [self closeFile:[_currentDocument filePath]];
    }
}

- (IBAction)findInFile:(id)sender
{
    // TODO: Implement find dialog
    NSLog(@"Find in file not yet implemented");
}

- (IBAction)replaceInFile:(id)sender
{
    // TODO: Implement find/replace dialog
    NSLog(@"Replace in file not yet implemented");
}

#pragma mark - NSTabViewDelegate

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    NSString *filePath = [tabViewItem identifier];
    YCodeEditorDocument *document = [self documentForFilePath:filePath];
    if (document) {
        [self setCurrentDocument:document];
    }
}

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    return YES;
}

@end