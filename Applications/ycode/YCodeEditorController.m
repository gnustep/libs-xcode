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
#import "YCodeSyntaxHighlighter.h"

@interface YCodeEditorTabItem : NSTabViewItem
{
    NSButton *_closeButton;
    BOOL _labelDrawn;
}
- (NSButton *)closeButton;
- (void)closeTab:(id)sender;
- (void)prepareToDrawLabel;
- (void)updateCloseButtonVisibility;
@end

@implementation YCodeEditorTabItem
- (id)initWithIdentifier:(id)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _closeButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        [_closeButton setTitle:@"×"];
        [_closeButton setFont:[NSFont systemFontOfSize:14]];
        [_closeButton setBordered:NO];
        [_closeButton setButtonType:NSMomentaryChangeButton];
        [_closeButton setToolTip:@"Close file"];
        [_closeButton setTarget:self];
        [_closeButton setAction:@selector(closeTab:)];
    }
    return self;
}
- (void)dealloc
{
    [_closeButton removeFromSuperview];
    RELEASE(_closeButton);
    [super dealloc];
}
- (NSButton *)closeButton { return _closeButton; }
- (void)prepareToDrawLabel { _labelDrawn = NO; }
- (void)updateCloseButtonVisibility { [_closeButton setHidden:!_labelDrawn]; }
- (NSSize)sizeOfLabel:(BOOL)truncate
{
    NSSize size = [super sizeOfLabel:truncate];
    size.width += 22;
    size.height = MAX(size.height, 16);
    return size;
}
- (void)drawLabel:(BOOL)truncate inRect:(NSRect)rect
{
    NSRect labelRect = rect;
    labelRect.size.width = MAX(0, rect.size.width - 22);
    [super drawLabel:truncate inRect:labelRect];
    if (rect.size.width >= 22) {
        if ([_closeButton superview] != [self tabView])
            [[self tabView] addSubview:_closeButton];
        [_closeButton setFrame:NSMakeRect(NSMaxX(rect) - 18,
            NSMidY(rect) - 8, 16, 16)];
        _labelDrawn = YES;
    }
}
- (void)closeTab:(id)sender
{
    // Closing may release this item and its button during the action.
    AUTORELEASE(RETAIN(self));
    id controller = [[self tabView] delegate];
    if ([controller respondsToSelector:@selector(closeFile:)])
        [controller closeFile:[self identifier]];
}
@end

@implementation YCodeEditorTabView
- (void)drawRect:(NSRect)rect
{
    // A theme may omit tabs that no longer fit after resizing.
    for (NSTabViewItem *item in [self tabViewItems])
        if ([item isKindOfClass:[YCodeEditorTabItem class]])
            [(YCodeEditorTabItem *)item prepareToDrawLabel];
    [super drawRect:rect];
    for (NSTabViewItem *item in [self tabViewItems])
        if ([item isKindOfClass:[YCodeEditorTabItem class]])
            [(YCodeEditorTabItem *)item updateCloseButtonVisibility];
}
- (void)removeTabViewItem:(NSTabViewItem *)item
{
    if ([item isKindOfClass:[YCodeEditorTabItem class]])
        [[(YCodeEditorTabItem *)item closeButton] removeFromSuperview];
    [super removeTabViewItem:item];
}
@end

@interface YCodeEditorController (Session)
- (NSString *)lastSourceFileDefaultsKey;
- (void)rememberCurrentSourceFile;
- (void)restoreLastSourceFile;
@end

NSString * const YCodeCurrentDocumentDidChangeNotification = @"YCodeCurrentDocumentDidChangeNotification";

@implementation YCodeEditorController

- (instancetype)init
{
    self = [super init];
    if (self) {
        _openDocuments = [[NSMutableArray alloc] init];
        _documentTabs = [[NSMutableDictionary alloc] init];
        
        // Default editor settings
        _editorFont = [[NSFont userFixedPitchFontOfSize:12.0] retain];
        _backgroundColor = [[NSColor colorWithDeviceWhite:0.95 alpha:1.0] retain];
        _textColor = [[YCodeSyntaxHighlighter plainTextColorForBackground:_backgroundColor] retain];
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
    [self restoreLastSourceFile];
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
    [self restoreLastSourceFile];
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
        [self rememberCurrentSourceFile];
        [[NSNotificationCenter defaultCenter] postNotificationName:
            YCodeCurrentDocumentDidChangeNotification object:self];
        
        // Update tab view selection
        if (document && _tabView) {
            NSTabViewItem *tab = [self tabForDocument:document];
            if (tab) {
                [_tabView selectTabViewItem:tab];
            }
        }
    }
}

#pragma mark - Project Editor Session

- (NSString *)lastSourceFileDefaultsKey
{
    NSString *path = [_project projectPath];
    if (![path length]) return nil;
    if (![path isAbsolutePath]) {
        path = [[[NSFileManager defaultManager] currentDirectoryPath]
            stringByAppendingPathComponent:path];
    }
    path = [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
    return [@"YCodeLastSourceFile:" stringByAppendingString:path];
}

- (void)rememberCurrentSourceFile
{
    NSString *key = [self lastSourceFileDefaultsKey];
    if (!key) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *path = [_currentDocument filePath];
    BOOL isDirectory = NO;
    if (!_currentDocument) {
        [defaults removeObjectForKey:key];
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]
               && !isDirectory) {
        if (![path isAbsolutePath]) {
            path = [[[NSFileManager defaultManager] currentDirectoryPath]
                stringByAppendingPathComponent:path];
        }
        [defaults setObject:[path stringByStandardizingPath] forKey:key];
    }
    [defaults synchronize];
}

- (void)restoreLastSourceFile
{
    if (!_tabView || _currentDocument) return;
    NSString *key = [self lastSourceFileDefaultsKey];
    if (!key) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id path = [defaults objectForKey:key];
    if (!path) return;
    BOOL isDirectory = NO;
    if (![path isKindOfClass:[NSString class]] ||
        ![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] ||
        isDirectory || ![self openFile:path]) {
        // Deleted or unreadable files must not interfere with opening the project.
        [defaults removeObjectForKey:key];
        [defaults synchronize];
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
        NSTabViewItem *tabItem = [[YCodeEditorTabItem alloc] initWithIdentifier:filePath];
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
        [[document textView] sizeToFit];
        [[[document scrollView] horizontalRulerView] setNeedsDisplay:YES];
        [[[document scrollView] verticalRulerView] setNeedsDisplay:YES];
    }
}

- (NSColor *)backgroundColor
{
    return _backgroundColor;
}

- (void)setBackgroundColor:(NSColor *)color
{
    ASSIGN(_backgroundColor, color);
    ASSIGN(_textColor, [YCodeSyntaxHighlighter plainTextColorForBackground:color]);
    
    // Apply to all open documents
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        [[document textView] setBackgroundColor:color];
        [[document textView] setTextColor:_textColor];
        [document applySyntaxHighlighting];
    }
}

- (NSColor *)textColor
{
    return _textColor;
}

- (void)setTextColor:(NSColor *)color
{
    color = [YCodeSyntaxHighlighter plainTextColorForBackground:_backgroundColor];
    ASSIGN(_textColor, color);
    
    // Apply to all open documents
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;
    
    while ((document = [enumerator nextObject]) != nil) {
        [[document textView] setTextColor:color];
        [document applySyntaxHighlighting];
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
    NSEnumerator *enumerator = [_openDocuments objectEnumerator];
    YCodeEditorDocument *document;

    while ((document = [enumerator nextObject]) != nil) {
        [document applySyntaxHighlighting];
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
    NSTabViewItem *tabItem = [[YCodeEditorTabItem alloc] initWithIdentifier:fileName];
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
