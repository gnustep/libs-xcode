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
    {
      NSEnumerator *itemEnumerator = [[self tabViewItems] objectEnumerator];
      NSTabViewItem *item;
      while ((item = [itemEnumerator nextObject]) != nil)
        if ([item isKindOfClass:[YCodeEditorTabItem class]])
              [(YCodeEditorTabItem *)item prepareToDrawLabel];
    }
    [super drawRect:rect];
    {
      NSEnumerator *itemEnumerator = [[self tabViewItems] objectEnumerator];
      NSTabViewItem *item;
      while ((item = [itemEnumerator nextObject]) != nil)
        if ([item isKindOfClass:[YCodeEditorTabItem class]])
              [(YCodeEditorTabItem *)item updateCloseButtonVisibility];
    }
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

@interface YCodeEditorController (FindPanel)
- (void)updateFindPanel;
@end

NSString * const YCodeCurrentDocumentDidChangeNotification = @"YCodeCurrentDocumentDidChangeNotification";

@implementation YCodeEditorController

- (id)init
{
    self = [super init];
    if (self) {
        _openDocuments = [[NSMutableArray alloc] init];
        _documentTabs = [[NSMutableDictionary alloc] init];
        
        // Default editor settings
        _editorFont = [[YCodePreferences fontForPane:@"Editor"] retain];
        _backgroundColor = [[YCodeSyntaxHighlighter preferredColorForKey:@"background"] retain];
        _textColor = [[YCodeSyntaxHighlighter plainTextColorForBackground:_backgroundColor] retain];
        _showLineNumbers = ![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeHideEditorRulers"];
        _syntaxHighlighting = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorPreferencesChanged:)
            name:@"YCodeEditorColorsDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorPreferencesChanged:)
            name:@"YCodeEditorRulersDidChange" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(editorFontsChanged:)
            name:@"YCodeFontsDidChange" object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self closeFindPanel];
    RELEASE(_findPanel);
    RELEASE(_findButtons);
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

- (void)editorFontsChanged:(NSNotification *)notification
{
    [self setEditorFont:[YCodePreferences fontForPane:@"Editor"]];
}

- (void)editorPreferencesChanged:(NSNotification *)notification
{
    // Keep the settings applied by openFile: in sync with the saved preferences.
    ASSIGN(_backgroundColor, [YCodeSyntaxHighlighter preferredColorForKey:@"background"]);
    ASSIGN(_textColor, [YCodeSyntaxHighlighter preferredColorForKey:@"text"]);
    _showLineNumbers = ![[NSUserDefaults standardUserDefaults] boolForKey:@"YCodeHideEditorRulers"];
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
        [self updateFindPanel];
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

- (BOOL)confirmClosingDocument:(YCodeEditorDocument *)document
{
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
    
    return YES;
}

- (BOOL)canCloseFiles
{
    NSEnumerator *documents = [[self openDocuments] objectEnumerator];
    YCodeEditorDocument *document;
    while ((document = [documents nextObject]) != nil)
        if (![self confirmClosingDocument:document]) return NO;
    return YES;
}

- (BOOL)closeFile:(NSString *)filePath
{
    YCodeEditorDocument *document = [self documentForFilePath:filePath];
    if (!document) {
        return NO;
    }

    if (![self confirmClosingDocument:document]) return NO;

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

- (void)updateFindPanel
{
    if (!_findPanel) return;
    BOOL enabled = [_currentDocument textView] != nil;
    [_findPanel setTitle:enabled ? [NSString stringWithFormat:@"Find / Replace — %@",
        [_currentDocument fileName]] : @"Find / Replace"];
    [_findStatus setStringValue:enabled ? @"" : @"Open a text file to find or replace."];
    NSEnumerator *buttons = [_findButtons objectEnumerator];
    NSButton *button;
    while ((button = [buttons nextObject]) != nil) [button setEnabled:enabled];
}

- (void)createFindPanel
{
    if (_findPanel) return;
    _findPanel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 560, 224)
        styleMask:NSTitledWindowMask | NSClosableWindowMask
        backing:NSBackingStoreBuffered defer:NO];
    [_findPanel setReleasedWhenClosed:NO];
    [_findPanel setFloatingPanel:YES];
    [_findPanel setHidesOnDeactivate:YES];
    NSView *content = [_findPanel contentView];
    NSArray *labels = [NSArray arrayWithObjects:@"Find:", @"Replace:", nil];
    NSUInteger i;
    for (i = 0; i < 2; i++) {
        CGFloat y = 182 - i * 36;
        NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 76, 24)];
        [label setStringValue:[labels objectAtIndex:i]];
        [label setEditable:NO]; [label setSelectable:NO];
        [label setBezeled:NO]; [label setDrawsBackground:NO];
        [content addSubview:label]; RELEASE(label);
        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(96, y, 448, 26)];
        [field setTarget:self]; [field setAction:@selector(findNext:)];
        [content addSubview:field];
        if (i == 0) _findField = field; else _replaceField = field;
        RELEASE(field);
    }
    _findCaseSensitive = [[NSButton alloc] initWithFrame:NSMakeRect(96, 112, 170, 24)];
    [_findCaseSensitive setButtonType:NSSwitchButton];
    [_findCaseSensitive setTitle:@"Case sensitive"];
    [content addSubview:_findCaseSensitive]; RELEASE(_findCaseSensitive);
    _findWrap = [[NSButton alloc] initWithFrame:NSMakeRect(290, 112, 180, 24)];
    [_findWrap setButtonType:NSSwitchButton]; [_findWrap setTitle:@"Wrap around"];
    [_findWrap setState:NSOnState];
    [content addSubview:_findWrap]; RELEASE(_findWrap);
    NSArray *titles = [NSArray arrayWithObjects:@"Previous", @"Next", @"Replace",
        @"Replace & Find", @"Replace All", nil];
    NSArray *actions = [NSArray arrayWithObjects:@"findPrevious:", @"findNext:",
        @"replaceMatch:", @"replaceAndFind:", @"replaceAll:", nil];
    _findButtons = [[NSMutableArray alloc] init];
    CGFloat x = 12;
    for (i = 0; i < [titles count]; i++) {
        CGFloat width = i == 3 ? 136 : 100;
        NSButton *button = [[NSButton alloc] initWithFrame:NSMakeRect(x, 64, width, 32)];
        [button setTitle:[titles objectAtIndex:i]];
        [button setBezelStyle:NSRoundedBezelStyle];
        [button setTarget:self]; [button setAction:NSSelectorFromString([actions objectAtIndex:i])];
        [content addSubview:button]; [_findButtons addObject:button]; RELEASE(button);
        x += width;
    }
    _findStatus = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 16, 528, 32)];
    [_findStatus setEditable:NO]; [_findStatus setSelectable:YES];
    [_findStatus setBezeled:NO]; [_findStatus setDrawsBackground:NO];
    [content addSubview:_findStatus]; RELEASE(_findStatus);
    [_findField setNextKeyView:_replaceField];
    [_replaceField setNextKeyView:_findCaseSensitive];
    [_findCaseSensitive setNextKeyView:_findWrap];
    [_findWrap setNextKeyView:_findField];
    [_findPanel center];
}

- (void)showFindPanelForReplacement:(BOOL)replacement
{
    [self createFindPanel];
    [self updateFindPanel];
    NSString *selected = [_currentDocument selectedText];
    if ([selected length] && [selected rangeOfCharacterFromSet:
        [NSCharacterSet newlineCharacterSet]].location == NSNotFound)
        [_findField setStringValue:selected];
    [_findPanel makeKeyAndOrderFront:nil];
    NSTextField *focus = replacement && [[_findField stringValue] length] ? _replaceField : _findField;
    [_findPanel makeFirstResponder:focus];
    [focus selectText:nil];
}

- (void)closeFindPanel
{
    [_findPanel orderOut:nil];
}

- (IBAction)findInFile:(id)sender
{
    [self showFindPanelForReplacement:NO];
}

- (IBAction)replaceInFile:(id)sender
{
    [self showFindPanelForReplacement:YES];
}

- (NSUInteger)findOptions
{
    return [_findCaseSensitive state] == NSOnState ? 0 : NSCaseInsensitiveSearch;
}

- (BOOL)findBackwards:(BOOL)backwards
{
    NSTextView *view = [_currentDocument textView];
    NSString *needle = [_findField stringValue];
    if (!view || ![needle length]) {
        [_findStatus setStringValue:view ? @"Enter text to find." : @"Open a text file to find or replace."];
        return NO;
    }
    NSString *text = [view string];
    NSRange selection = [view selectedRange];
    NSUInteger start = MIN(backwards ? selection.location : NSMaxRange(selection), [text length]);
    NSUInteger options = [self findOptions] | (backwards ? NSBackwardsSearch : 0);
    NSRange range = backwards ? NSMakeRange(0, start) : NSMakeRange(start, [text length] - start);
    NSRange found = [text rangeOfString:needle options:options range:range];
    BOOL wrapped = NO;
    if (found.location == NSNotFound && [_findWrap state] == NSOnState) {
        range = backwards ? NSMakeRange(start, [text length] - start) : NSMakeRange(0, start);
        found = [text rangeOfString:needle options:options range:range];
        wrapped = found.location != NSNotFound;
    }
    if (found.location == NSNotFound) {
        [_findStatus setStringValue:@"No match found."];
        return NO;
    }
    [view setSelectedRange:found];
    [view scrollRangeToVisible:found];
    [_findStatus setStringValue:wrapped ? @"Match found (wrapped around)." : @"Match found."];
    return YES;
}

- (IBAction)findNext:(id)sender { [self findBackwards:NO]; }
- (IBAction)findPrevious:(id)sender { [self findBackwards:YES]; }

- (BOOL)replaceRange:(NSRange)range withString:(NSString *)replacement actionName:(NSString *)name
{
    NSTextView *view = [_currentDocument textView];
    if (!view || ![view isEditable]) return NO;
    if ([[[view string] substringWithRange:range] isEqual:replacement]) return YES;
    NSUndoManager *undo = [view undoManager];
    [undo beginUndoGrouping];
    BOOL allowed = [view shouldChangeTextInRange:range replacementString:replacement];
    if (allowed) {
        [[view textStorage] replaceCharactersInRange:range withString:replacement];
        [view setSelectedRange:NSMakeRange(range.location, [replacement length])];
        [view didChangeText];
        [undo setActionName:name];
    }
    [undo endUndoGrouping];
    return allowed;
}

- (BOOL)replaceSelectedMatch
{
    NSTextView *view = [_currentDocument textView];
    NSString *needle = [_findField stringValue];
    if (!view || ![needle length]) return NO;
    NSRange selection = [view selectedRange];
    NSRange match = [[view string] rangeOfString:needle options:[self findOptions] range:selection];
    if (!selection.length || !NSEqualRanges(match, selection)) return NO;
    return [self replaceRange:selection withString:[_replaceField stringValue] actionName:@"Replace"];
}

- (IBAction)replaceMatch:(id)sender
{
    if ([self replaceSelectedMatch]) [_findStatus setStringValue:@"Replaced one match."];
    else [self findNext:sender];
}

- (IBAction)replaceAndFind:(id)sender
{
    [self replaceSelectedMatch];
    [self findNext:sender];
}

- (IBAction)replaceAll:(id)sender
{
    NSTextView *view = [_currentDocument textView];
    NSString *needle = [_findField stringValue];
    if (!view || ![needle length]) {
        [self findNext:sender];
        return;
    }
    NSString *text = [view string];
    NSString *replacement = [_replaceField stringValue];
    NSMutableString *result = [NSMutableString string];
    NSUInteger position = 0, count = 0;
    while (position < [text length]) {
        NSRange match = [text rangeOfString:needle options:[self findOptions]
            range:NSMakeRange(position, [text length] - position)];
        if (match.location == NSNotFound) break;
        [result appendString:[text substringWithRange:NSMakeRange(position, match.location - position)]];
        [result appendString:replacement];
        position = NSMaxRange(match);
        count++;
    }
    [result appendString:[text substringFromIndex:position]];
    if (count && ![self replaceRange:NSMakeRange(0, [text length]) withString:result actionName:@"Replace All"])
        [_findStatus setStringValue:@"Unable to replace matches."];
    else
        [_findStatus setStringValue:[NSString stringWithFormat:@"Replaced %lu match%@.",
            (unsigned long)count, count == 1 ? @"" : @"es"]];
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
